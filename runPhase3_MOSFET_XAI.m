
clear; clc; close all;
rng(42, 'twister');

root = 'C:\Internship Project';

modelFile = fullfile(root, 'models', 'Common_Source', ...
    'Phase2_MOSFET', 'MOSFET_GainModel_Phase2.mat');

dataFile = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'training_ready', ...
    'MOSFET_TrainingReady_GainAt1kHz.csv');

outDir = fullfile(root, 'results', 'Phase3_MOSFET_XAI');

if ~isfile(modelFile)
    error('Saved Phase 2 model not found: %s', modelFile);
end
if ~isfile(dataFile)
    error('Training-ready dataset not found: %s', dataFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 1. Load saved model bundle
S = load(modelFile);

if isfield(S, 'bundle')
    bundle = S.bundle;
else
    names = fieldnames(S);
    bundle = [];
    for k = 1:numel(names)
        candidate = S.(names{k});
        if isstruct(candidate) && isfield(candidate, 'Model')
            bundle = candidate;
            break;
        end
    end
    if isempty(bundle)
        error('Could not locate the saved model bundle or its Model field.');
    end
end

if ~isfield(bundle, 'Model')
    error('Saved bundle has no Model field.');
end

model = bundle.Model;

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F'};
target = 'GainAt1kHz_dB';

if isfield(bundle, 'ModelName')
    modelName = string(bundle.ModelName);
else
    modelName = "Unknown";
end

fprintf('\n===== PHASE 3 MOSFET XAI =====\n');
fprintf('Loaded model: %s\n', modelName);

%% 2. Load development data and check feature columns
T = readtable(dataFile);

required = [features, {target}];
for k = 1:numel(required)
    if ~ismember(required{k}, T.Properties.VariableNames)
        error('Dataset is missing column: %s', required{k});
    end
end

X = T{:, features};
Y = T{:, target};

valid = all(isfinite(X), 2) & isfinite(Y);
X = X(valid,:);
Y = Y(valid);

if size(X,2) ~= numel(features)
    error('Unexpected feature count.');
end

%% 3. Prediction helper, including Ridge scaling when available
predictModel = @(Xin) predictSavedModel(model, bundle, modelName, Xin);

Yhat = predictModel(X);

fprintf('Rows used for explanations: %d\n', size(X,1));
fprintf('Features: %s\n', strjoin(features, ', '));
fprintf('Development-data RMSE (descriptive): %.4f dB\n', ...
    sqrt(mean((Y-Yhat).^2)));
fprintf(['Note: these are development-data predictions, not ' ...
    'independent validation results.\n']);

%% 4. Permutation importance
% Increase in RMSE after shuffling one feature.
% Larger increase means the fitted model relies more on that feature.
baseRMSE = sqrt(mean((Y-Yhat).^2));

nRepeats = 30;
importance = zeros(numel(features),1);
importanceSD = zeros(numel(features),1);

for j = 1:numel(features)
    increases = zeros(nRepeats,1);

    for r = 1:nRepeats
        Xperm = X;
        order = randperm(size(X,1));
        Xperm(:,j) = X(order,j);

        yp = predictModel(Xperm);
        permRMSE = sqrt(mean((Y-yp).^2));
        increases(r) = permRMSE - baseRMSE;
    end

    importance(j) = mean(increases);
    importanceSD(j) = std(increases);
end

Importance = table(string(features(:)), importance, importanceSD, ...
    'VariableNames', {'Feature','MeanRMSEIncrease_dB','StdRMSEIncrease_dB'});

Importance = sortrows(Importance, 'MeanRMSEIncrease_dB', 'descend');
writetable(Importance, fullfile(outDir, ...
    'Phase3_PermutationImportance.csv'));

fprintf('\n===== PERMUTATION IMPORTANCE =====\n');
disp(Importance);

figure('Color','w');
bar(Importance.MeanRMSEIncrease_dB);
xticks(1:height(Importance));
xticklabels(Importance.Feature);
xtickangle(30);
ylabel('Increase in RMSE (dB)');
title('MOSFET model permutation importance');
grid on;
saveas(gcf, fullfile(outDir, ...
    'Phase3_PermutationImportance.png'));

%% 5. Partial dependence plots
% For each feature, vary it over its observed range while averaging
% predictions over the other observed feature values.
% This may evaluate combinations that do not correspond to realizable
% or correctly biased amplifier circuits.

nGrid = 25;
PDP = table;

figure('Color','w');
tiledlayout(2,3,'TileSpacing','compact');

for j = 1:numel(features)
    lo = min(X(:,j));
    hi = max(X(:,j));

    gridValues = linspace(lo, hi, nGrid)';
    meanPred = zeros(nGrid,1);

    for g = 1:nGrid
        Xg = X;
        Xg(:,j) = gridValues(g);
        yg = predictModel(Xg);
        meanPred(g) = mean(yg);
    end

    featureCol = repmat(string(features{j}), nGrid, 1);
    pdpTable = table(featureCol, gridValues, meanPred, ...
        'VariableNames', {'Feature','FeatureValue','MeanPredictedGain_dB'});

    PDP = [PDP; pdpTable]; %#ok<AGROW>

    nexttile;
    plot(gridValues, meanPred, '-o', 'LineWidth', 1.3, ...
        'MarkerSize', 3);
    xlabel(features{j}, 'Interpreter','none');
    ylabel('Mean predicted gain (dB)');
    title(features{j}, 'Interpreter','none');
    grid on;
end

nexttile;
axis off;
text(0, 0.8, 'Partial dependence', 'FontWeight','bold');
text(0, 0.6, 'Model behavior, not causal proof.');
text(0, 0.4, 'Check bias and operating region in SPICE.');

writetable(PDP, fullfile(outDir, 'Phase3_PartialDependence.csv'));
saveas(gcf, fullfile(outDir, 'Phase3_PartialDependence.png'));

%% 6. Local one-feature sensitivity for a representative circuit
% Select the development-data row nearest the median of each feature.
% This is a representative parameter vector, not necessarily a valid
% physical operating point.

xRef = median(X, 1);
[~, rowIdx] = min(sum(((X-xRef) ./ max(std(X,0,1), eps)).^2, 2));
xRef = X(rowIdx,:);

referencePrediction = predictModel(xRef);

localRows = cell(0,4);

for j = 1:numel(features)
    lo = min(X(:,j));
    hi = max(X(:,j));
    values = linspace(lo, hi, 21)';

    Xlocal = repmat(xRef, numel(values), 1);
    Xlocal(:,j) = values;
    predictions = predictModel(Xlocal);

    for k = 1:numel(values)
        localRows(end+1,:) = {features{j}, values(k), ...
            predictions(k), predictions(k)-referencePrediction}; %#ok<AGROW>
    end
end

Local = cell2table(localRows, 'VariableNames', ...
    {'Feature','FeatureValue','PredictedGain_dB','ChangeFromReference_dB'});

writetable(Local, fullfile(outDir, 'Phase3_LocalSensitivity.csv'));

Reference = table(string(features(:)), xRef(:), ...
    'VariableNames', {'Feature','ReferenceValue'});
writetable(Reference, fullfile(outDir, 'Phase3_ReferenceCircuit.csv'));

fprintf('\nReference prediction: %.4f dB\n', referencePrediction);
disp(Reference);

%% 7. Save explanation metadata
fid = fopen(fullfile(outDir, 'Phase3_XAI_Summary.txt'), 'w');
if fid >= 0
    fprintf(fid, 'PHASE 3 - MOSFET XAI\n');
    fprintf(fid, 'Model: %s\n', modelName);
    fprintf(fid, 'Target: %s (dB)\n', target);
    fprintf(fid, 'Rows explained: %d\n', size(X,1));
    fprintf(fid, 'Features: %s\n', strjoin(features, ', '));
    fprintf(fid, 'Base development RMSE: %.6f dB\n', baseRMSE);
    fprintf(fid, 'Reference prediction: %.6f dB\n', referencePrediction);
    fprintf(fid, ['Interpretation: explanations describe fitted model ' ...
        'behavior and do not establish causation or circuit validity.\n']);
    fclose(fid);
end

fprintf('\nPhase 3 XAI complete.\nOutputs saved to:\n%s\n', outDir);

%% Local function
function y = predictSavedModel(model, bundle, modelName, X)
    % Apply saved standardization if the selected model is Ridge.
    if contains(lower(modelName), 'ridge')
        mu = [];
        sigma = [];

        if isfield(bundle, 'RidgeMu')
            mu = bundle.RidgeMu;
        elseif isfield(bundle, 'Mu')
            mu = bundle.Mu;
        end

        if isfield(bundle, 'RidgeSigma')
            sigma = bundle.RidgeSigma;
        elseif isfield(bundle, 'Sigma')
            sigma = bundle.Sigma;
        end

        if isempty(mu) || isempty(sigma)
            error(['Ridge model selected, but scaling metadata fields ' ...
                'were not found. Inspect bundle field names first.']);
        end

        sigma(sigma == 0) = 1;
        X = (X-mu)./sigma;
    end

    y = predict(model, X);
    y = y(:);
end

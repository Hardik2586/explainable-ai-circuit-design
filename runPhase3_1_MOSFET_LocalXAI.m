clear; clc; close all;
rng(42, 'twister');

root = 'C:\Internship Project';

modelFile = fullfile(root, 'models', 'Common_Source', ...
    'Phase2_MOSFET', 'MOSFET_GainModel_Phase2.mat');

dataFile = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'training_ready', ...
    'MOSFET_TrainingReady_GainAt1kHz.csv');

outDir = fullfile(root, 'results', 'Phase3_1_MOSFET_LocalXAI');

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F'};
target = 'GainAt1kHz_dB';

if ~isfile(modelFile)
    error('Model not found: %s', modelFile);
end
if ~isfile(dataFile)
    error('Training data not found: %s', dataFile);
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
        error('Could not find a model bundle containing Model.');
    end
end

if ~isfield(bundle, 'Model')
    error('Bundle does not contain Model.');
end

model = bundle.Model;

if isfield(bundle, 'ModelName')
    modelName = string(bundle.ModelName);
else
    error('Bundle does not contain ModelName.');
end

fprintf('\n===== PHASE 3.1 LOCAL MOSFET XAI =====\n');
fprintf('Model: %s\n', modelName);

%% 2. Load valid development circuits
T = readtable(dataFile);

required = [features, {target}];
for k = 1:numel(required)
    if ~ismember(required{k}, T.Properties.VariableNames)
        error('Missing dataset column: %s', required{k});
    end
end

Xall = T{:,features};
Yall = T{:,target};

valid = all(isfinite(Xall),2) & isfinite(Yall);
Xall = Xall(valid,:);
Yall = Yall(valid);

if isempty(Xall)
    error('No valid rows found.');
end

%% 3. Select the representative circuit nearest the median inputs
% Standardize distances so large-valued resistor/capacitor columns
% do not dominate the selection purely due to their numerical scale.

muX = mean(Xall,1);
sdX = std(Xall,0,1);
sdX(sdX == 0 | ~isfinite(sdX)) = 1;

zX = (Xall-muX)./sdX;
medianZ = median(zX,1);

[~, refIdx] = min(sum((zX-medianZ).^2,2));

xRef = Xall(refIdx,:);
actualDevelopmentGain = Yall(refIdx);

%% 4. Prediction helper with Ridge scaling if needed
predictLocal = @(Xin) localPredict(model, bundle, modelName, Xin);

referencePrediction = predictLocal(xRef);

fprintf('Selected development row: %d\n', refIdx);
fprintf('Actual simulated gain: %.4f dB\n', actualDevelopmentGain);
fprintf('Model predicted gain: %.4f dB\n', referencePrediction);

%% 5. Save reference circuit inputs
ReferenceCircuit = table(string(features(:)), xRef(:), ...
    'VariableNames', {'Feature','Value'});

ReferenceCircuit.TargetName = repmat(string(target),numel(features),1);
ReferenceCircuit.ActualGain_dB = repmat(actualDevelopmentGain,numel(features),1);
ReferenceCircuit.PredictedGain_dB = repmat(referencePrediction,numel(features),1);

writetable(ReferenceCircuit, ...
    fullfile(outDir,'Phase3_1_ReferenceCircuit.csv'));

%% 6. One-at-a-time local sensitivity
% Change one input at a time over its observed development-data range.
% Other inputs remain fixed at the reference values.
% This measures model sensitivity, not physical causation.

nGrid = 31;
localData = cell(0,5);

figure('Color','w','Name','Local MOSFET sensitivity');
tiledlayout(2,3,'TileSpacing','compact');

for j = 1:numel(features)

    lo = min(Xall(:,j));
    hi = max(Xall(:,j));

    if lo == hi
        values = lo;
    else
        values = linspace(lo,hi,nGrid)';
    end

    Xlocal = repmat(xRef,numel(values),1);
    Xlocal(:,j) = values;

    predictions = predictLocal(Xlocal);
    changes = predictions-referencePrediction;

    for k = 1:numel(values)
        localData(end+1,:) = {features{j}, values(k), ...
            predictions(k), changes(k), j}; %#ok<AGROW>
    end

    nexttile;
    plot(values,predictions,'-o','LineWidth',1.3,'MarkerSize',3);
    hold on;
    yline(referencePrediction,'--k','Reference prediction');
    xlabel(features{j},'Interpreter','none');
    ylabel('Predicted gain (dB)');
    title(features{j},'Interpreter','none');
    grid on;
end

nexttile;
axis off;
text(0,0.8,sprintf('Reference prediction: %.3f dB', ...
    referencePrediction),'FontWeight','bold');
text(0,0.6,'One input changes at a time.');
text(0,0.4,'Predictions are not SPICE verification.');

LocalSensitivity = cell2table(localData, ...
    'VariableNames',{'Feature','FeatureValue', ...
    'PredictedGain_dB','ChangeFromReference_dB','FeatureIndex'});

writetable(LocalSensitivity, ...
    fullfile(outDir,'Phase3_1_LocalSensitivity.csv'));

saveas(gcf,fullfile(outDir,'Phase3_1_LocalSensitivity.png'));

%% 7. Rank local sensitivity by prediction range
featureNames = string(features(:));
predictionRange = zeros(numel(features),1);
maxAbsChange = zeros(numel(features),1);

for j = 1:numel(features)
    idx = LocalSensitivity.FeatureIndex == j;
    p = LocalSensitivity.PredictedGain_dB(idx);
    c = LocalSensitivity.ChangeFromReference_dB(idx);

    predictionRange(j) = max(p)-min(p);
    maxAbsChange(j) = max(abs(c));
end

SensitivityRanking = table(featureNames,predictionRange,maxAbsChange, ...
    'VariableNames',{'Feature','PredictionRange_dB', ...
    'MaxAbsoluteChangeFromReference_dB'});

SensitivityRanking = sortrows(SensitivityRanking, ...
    'PredictionRange_dB','descend');

writetable(SensitivityRanking, ...
    fullfile(outDir,'Phase3_1_SensitivityRanking.csv'));

fprintf('\n===== LOCAL SENSITIVITY RANKING =====\n');
disp(SensitivityRanking);

%% 8. Save summary
fid = fopen(fullfile(outDir,'Phase3_1_Summary.txt'),'w');

if fid >= 0
    fprintf(fid,'PHASE 3.1 - LOCAL MOSFET XAI\n');
    fprintf(fid,'Model: %s\n',modelName);
    fprintf(fid,'Target: %s (dB)\n',target);
    fprintf(fid,'Reference development row: %d\n',refIdx);
    fprintf(fid,'Actual simulated gain: %.6f dB\n',actualDevelopmentGain);
    fprintf(fid,'Predicted gain: %.6f dB\n',referencePrediction);
    fprintf(fid,'\nReference circuit parameters:\n');

    for j = 1:numel(features)
        fprintf(fid,'%s = %.10g\n',features{j},xRef(j));
    end

    fprintf(fid,['\nInterpretation: results describe model sensitivity. ' ...
        'They do not establish causation or circuit validity.\n']);
    fclose(fid);
end

fprintf('\nPhase 3.1 complete.\nOutputs saved to:\n%s\n',outDir);

%% Local prediction function
function y = localPredict(model,bundle,modelName,X)

    if contains(lower(modelName),'ridge')
        mu = [];
        sigma = [];

        if isfield(bundle,'RidgeMu')
            mu = bundle.RidgeMu;
        elseif isfield(bundle,'Mu')
            mu = bundle.Mu;
        end

        if isfield(bundle,'RidgeSigma')
            sigma = bundle.RidgeSigma;
        elseif isfield(bundle,'Sigma')
            sigma = bundle.Sigma;
        end

        if isempty(mu) || isempty(sigma)
            error(['Ridge selected but saved scaling fields were not ' ...
                'found. Inspect the saved bundle fields.']);
        end

        sigma(sigma == 0) = 1;
        X = (X-mu)./sigma;
    end

    y = predict(model,X);
    y = y(:);
end

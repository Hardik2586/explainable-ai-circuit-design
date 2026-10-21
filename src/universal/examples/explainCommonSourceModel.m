
% Common-Source XAI: Feature Importance and Sensitivity
clear; clc; close all;

projectRoot = 'C:\Internship Project';

modelFile = fullfile(projectRoot, 'models', 'Common_Source', ...
    '20261013_022802', 'CommonSourceModel.mat');

dataFile = fullfile(projectRoot, 'data', 'universal', ...
    'Common_Source', 'v2_100', '20261013_020826', ...
    'CS_Dataset_v2_100.csv');

assert(isfile(modelFile), 'Saved model not found: %s', modelFile);
assert(isfile(dataFile), 'Dataset not found: %s', dataFile);

S = load(modelFile);
T = readtable(dataFile, 'VariableNamingRule', 'preserve');

model = S.selectedModel;
features = S.featureColumns;
target = S.targetColumn;
modelName = string(S.modelInfo.SelectedModelName);

X = T{:, cellstr(features)};
Y = T{:, target};

valid = all(isfinite(X), 2) & isfinite(Y);

% Match the original simulation-validity filter.
names = lower(regexprep(T.Properties.VariableNames, ...
    '[^a-zA-Z0-9]', ''));
flagIdx = find(strcmp(names, 'simulationvalid'), 1);

if ~isempty(flagIdx)
    flag = T{:, flagIdx};
    if islogical(flag) || isnumeric(flag)
        valid = valid & flag ~= 0;
    else
        valid = valid & strcmpi(string(flag), "true");
    end
end

X = X(valid, :);
Y = Y(valid);

% Handle the scaling used by the linear model.
predictModel = @(Z) predictWithScaling( ...
    model, modelName, Z, S);

%% 1. Global feature importance
if modelName == "BoostedTrees"
    importance = predictorImportance(model);
elseif modelName == "RidgeLinear"
    importance = abs(model.Beta(:))';
else
    error('Unsupported model type: %s', modelName);
end

importance = importance(:);
importance = importance ./ max(sum(importance), eps) * 100;

importanceTable = table( ...
    features(:), importance, ...
    'VariableNames', {'Feature', 'RelativeImportance_pct'});

importanceTable = sortrows(importanceTable, ...
    'RelativeImportance_pct', 'descend');

disp('=== MODEL FEATURE IMPORTANCE ===');
disp(importanceTable);

%% 2. Global one-feature-at-a-time sensitivity
% For each component, vary it while averaging predictions over
% all valid dataset rows. This is partial dependence, not causation.

nFeatures = numel(features);
nGrid = 25;

figure('Name', 'Common-Source XAI Sensitivity');
tiledlayout(2, 3, 'TileSpacing', 'compact');

sensitivity = cell(nFeatures, 1);

for j = 1:nFeatures
    gridValues = linspace( ...
        prctile(X(:, j), 5), prctile(X(:, j), 95), nGrid)';

    meanPrediction = zeros(nGrid, 1);

    for g = 1:nGrid
        Xvaried = X;
        Xvaried(:, j) = gridValues(g);

        predictions = predictModel(Xvaried);
        meanPrediction(g) = mean(predictions, 'omitnan');
    end

    sensitivity{j} = table( ...
        repmat(features(j), nGrid, 1), ...
        gridValues, meanPrediction, ...
        'VariableNames', ...
        {'Feature', 'ComponentValue', 'MeanPredictedGain_dB'});

    nexttile;
    plot(gridValues, meanPrediction, '-o', ...
        'LineWidth', 1.2, 'MarkerSize', 3);
    xlabel(features(j), 'Interpreter', 'none');
    ylabel('Mean predicted peak gain (dB)');
    title("Sensitivity: " + features(j), 'Interpreter', 'none');
    grid on;
end

%% 3. Save explanation outputs separately
timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

outputFolder = fullfile(projectRoot, 'results', ...
    'XAI', 'Common_Source', timestamp);

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

writetable(importanceTable, ...
    fullfile(outputFolder, 'feature_importance.csv'));

sensitivityTable = vertcat(sensitivity{:});
writetable(sensitivityTable, ...
    fullfile(outputFolder, 'sensitivity_curves.csv'));

exportgraphics(gcf, ...
    fullfile(outputFolder, 'sensitivity_plots.png'), ...
    'Resolution', 150);

save(fullfile(outputFolder, 'XAI_Results.mat'), ...
    'importanceTable', 'sensitivityTable', ...
    'modelName', 'features', 'target');

fprintf('\nXAI analysis complete.\nSaved to:\n%s\n', outputFolder);

%% Local helper
function y = predictWithScaling(model, modelName, X, S)
    if modelName == "RidgeLinear"
        X = (X - S.muX) ./ S.sigmaX;
    end
    y = predict(model, X);
end

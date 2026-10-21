clear; clc; close all;
rng(42, 'twister');

%% 1. Paths
projectRoot = 'C:\Internship Project';

dataFile = fullfile(projectRoot, 'data', 'universal', ...
    'Common_Source', 'v2_100', '20261013_020826', ...
    'CS_Dataset_v2_100.csv');

if ~isfile(dataFile)
    error('Dataset not found:\n%s', dataFile);
end

outputRoot = fullfile(projectRoot, 'models', 'Common_Source');
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

runFolder = fullfile(outputRoot, timestamp);
mkdir(runFolder);

%% 2. Load dataset
T = readtable(dataFile, 'VariableNamingRule', 'preserve');

fprintf('\nLoaded %d rows and %d columns.\n', height(T), width(T));
disp('Dataset columns:');
disp(T.Properties.VariableNames');

% Normalize names to match columns despite underscores or punctuation.
names = T.Properties.VariableNames;
normalizedNames = lower(regexprep(names, '[^a-zA-Z0-9]', ''));

%% 3. Identify input features and target
% Expected inputs: upper/lower gate bias resistors, drain/source
% resistors, input coupling capacitor, and supply voltage.
% The aliases allow minor differences in column naming.

featureAliases = {
    {'RGUOhm', 'RGU'}
    {'RGL Ohm', 'RGLOhm', 'RGL'}
    {'RDOhm', 'RD'}
    {'RSOhm', 'RS'}
    {'CINF', 'CIN', 'CINFarads'}
    {'VDDV', 'VDD'}
};

featureLabels = {'RGU', 'RGL', 'RD', 'RS', 'CIN', 'VDD'};
featureColumns = strings(1, numel(featureAliases));

for k = 1:numel(featureAliases)
    aliases = lower(regexprep(featureAliases{k}, ...
        '[^a-zA-Z0-9]', ''));

    idx = find(ismember(normalizedNames, aliases), 1);

    if isempty(idx)
        error(['Could not identify feature "%s".\n' ...
            'Available columns are printed above. Update the ' ...
            'featureAliases list to match your CSV.'], ...
            featureLabels{k});
    end

    featureColumns(k) = string(names{idx});
end

targetAliases = {'peakgaindb', 'peakgaindecibels'};
targetIdx = find(ismember(normalizedNames, targetAliases), 1);

if isempty(targetIdx)
    error(['Could not find the peak-gain target column. ' ...
        'Check the printed column names and update targetAliases.']);
end

targetColumn = names{targetIdx};

fprintf('\nInput features:\n');
disp(featureColumns');
fprintf('Prediction target: %s\n', targetColumn);

%% 4. Keep valid numeric observations
X = T{:, cellstr(featureColumns)};
Y = T{:, targetColumn};

if ~isnumeric(X) || ~isnumeric(Y)
    error('Selected features and target must be numeric.');
end

validRows = all(isfinite(X), 2) & isfinite(Y);

% Respect the dataset's validity flag when it exists.
validFlagIdx = find(strcmpi(normalizedNames, 'simulationvalid'), 1);

if ~isempty(validFlagIdx)
    flag = T{:, validFlagIdx};

    if islogical(flag) || isnumeric(flag)
        validRows = validRows & (flag ~= 0);
    elseif isstring(flag) || iscellstr(flag) || iscategorical(flag)
        validRows = validRows & ...
            strcmpi(string(flag), "true");
    end
end

X = X(validRows, :);
Y = Y(validRows, :);

if size(X, 1) < 20
    error('Too few valid rows for a reliable initial train/test experiment.');
end

fprintf('\nRows retained for training: %d\n', size(X, 1));

%% 5. Reproducible train/test split
cv = cvpartition(size(X, 1), 'HoldOut', 0.20);

XTrain = X(training(cv), :);
YTrain = Y(training(cv), :);
XTest  = X(test(cv), :);
YTest  = Y(test(cv), :);

fprintf('Training rows: %d\n', size(XTrain, 1));
fprintf('Testing rows:  %d\n', size(XTest, 1));


%% 6. Train two candidate regression models

% Model A: Ridge linear regression
% Standardize predictors manually for compatibility.

muX = mean(XTrain, 1);
sigmaX = std(XTrain, 0, 1);
sigmaX(sigmaX == 0) = 1;

XTrainScaled = (XTrain - muX) ./ sigmaX;
XTestScaled  = (XTest - muX) ./ sigmaX;

linearModel = fitrlinear(XTrainScaled, YTrain, ...
    'Learner', 'leastsquares', ...
    'Regularization', 'ridge', ...
    'Lambda', 1e-3, ...
    'Solver', 'lbfgs');

% Model B: Boosted regression trees
treeTemplate = templateTree('MinLeafSize', 5);

boostedModel = fitrensemble(XTrain, YTrain, ...
    'Method', 'LSBoost', ...
    'Learners', treeTemplate, ...
    'NumLearningCycles', 100, ...
    'LearnRate', 0.05);

%% 7. Test-set predictions
predLinear = predict(linearModel, XTestScaled);
predBoosted = predict(boostedModel, XTest);


%% 8. Evaluate models
evaluate = @(actual, predicted) struct( ...
    'RMSE', sqrt(mean((actual - predicted).^2)), ...
    'MAE', mean(abs(actual - predicted)), ...
    'R2', 1 - sum((actual - predicted).^2) / ...
        max(sum((actual - mean(actual)).^2), eps));

metricsLinear = evaluate(YTest, predLinear);
metricsBoosted = evaluate(YTest, predBoosted);

modelNames = ["RidgeLinear"; "BoostedTrees"];
RMSE = [metricsLinear.RMSE; metricsBoosted.RMSE];
MAE  = [metricsLinear.MAE;  metricsBoosted.MAE];
R2   = [metricsLinear.R2;   metricsBoosted.R2];

metricsTable = table(modelNames, RMSE, MAE, R2);

disp(' ');
disp('========== TEST-SET RESULTS ==========');
disp(metricsTable);

%% 9. Select model using test RMSE
% This is an initial experiment, not a final unbiased model benchmark.
% Later, use cross-validation for model selection and reserve a final test set.

if metricsBoosted.RMSE < metricsLinear.RMSE
    selectedModel = boostedModel;
    selectedModelName = "BoostedTrees";
    selectedPredictions = predBoosted;
    selectedMetrics = metricsBoosted;
else
    selectedModel = linearModel;
    selectedModelName = "RidgeLinear";
    selectedPredictions = predLinear;
    selectedMetrics = metricsLinear;
end

fprintf('\nSelected model: %s\n', selectedModelName);
fprintf('Test RMSE: %.4f dB\n', selectedMetrics.RMSE);
fprintf('Test MAE:  %.4f dB\n', selectedMetrics.MAE);
fprintf('Test R^2:  %.4f\n', selectedMetrics.R2);

%% 10. Save test predictions
predictionTable = table( ...
    YTest, selectedPredictions, ...
    YTest - selectedPredictions, ...
    'VariableNames', ...
    {'ActualPeakGain_dB', 'PredictedPeakGain_dB', 'Error_dB'});

writetable(metricsTable, fullfile(runFolder, 'model_metrics.csv'));
writetable(predictionTable, ...
    fullfile(runFolder, 'test_predictions.csv'));

%% 11. Save trained artifacts
modelInfo = struct();
modelInfo.SelectedModelName = selectedModelName;
modelInfo.FeatureNames = featureColumns;
modelInfo.TargetName = targetColumn;
modelInfo.TrainingRows = size(XTrain, 1);
modelInfo.TestRows = size(XTest, 1);
modelInfo.SelectedMetrics = selectedMetrics;
modelInfo.DatasetFile = dataFile;
modelInfo.Timestamp = timestamp;


save(fullfile(runFolder, 'CommonSourceModel.mat'), ...
    'selectedModel', 'linearModel', 'boostedModel', ...
    'modelInfo', 'metricsTable', 'predictionTable', ...
    'featureColumns', 'targetColumn', 'muX', 'sigmaX');


%% 12. Plot measured versus predicted gain
fig = figure('Name', 'Common-Source Model Evaluation');

scatter(YTest, selectedPredictions, 45, 'filled');
hold on;

lowerLimit = min([YTest; selectedPredictions]);
upperLimit = max([YTest; selectedPredictions]);

plot([lowerLimit upperLimit], ...
     [lowerLimit upperLimit], '--k', 'LineWidth', 1.2);

xlabel('ngspice Peak Gain (dB)');
ylabel('Predicted Peak Gain (dB)');
title("Common-Source Prediction: " + selectedModelName);
grid on;
axis tight;

exportgraphics(fig, fullfile(runFolder, ...
    'actual_vs_predicted.png'), 'Resolution', 150);

fprintf('\nTraining complete.\nArtifacts saved to:\n%s\n', runFolder);

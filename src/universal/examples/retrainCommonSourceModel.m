clear; clc;
rng(42, 'twister');

projectRoot = 'C:\Internship Project';

%% 1. Load exhaustive simulation dataset

dataFile = fullfile(projectRoot, 'results', ...
    'Optimization', 'Common_Source_Exhaustive', ...
    '20261013_030513', 'all_1215_candidate_results.csv');

originalModelFile = fullfile(projectRoot, 'models', ...
    'Common_Source', '20261013_022802', ...
    'CommonSourceModel.mat');

assert(isfile(dataFile), ...
    'Exhaustive dataset not found: %s', dataFile);

assert(isfile(originalModelFile), ...
    'Original model not found: %s', originalModelFile);

T = readtable(dataFile);
S = load(originalModelFile);

requiredColumns = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VDD_V','PeakGain_dB','SimulationValid'};

for i = 1:numel(requiredColumns)
    assert(ismember(requiredColumns{i}, T.Properties.VariableNames), ...
        'Required dataset column missing: %s', requiredColumns{i});
end

%% 2. Filter valid, finite simulation results

validMask = T.SimulationValid & ...
    isfinite(T.PeakGain_dB) & ...
    isfinite(T.RGU_Ohm) & ...
    isfinite(T.RGL_Ohm) & ...
    isfinite(T.RD_Ohm) & ...
    isfinite(T.RS_Ohm) & ...
    isfinite(T.CIN_F) & ...
    isfinite(T.VDD_V);

D = T(validMask, :);

featureColumns = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

targetColumn = 'PeakGain_dB';

X = D{:, featureColumns};
Y = D.(targetColumn);

fprintf('\n========================================\n');
fprintf('COMMON-SOURCE MODEL RETRAINING\n');
fprintf('========================================\n');
fprintf('Valid rows loaded: %d\n', height(D));
fprintf('Input features: %d\n', size(X,2));

if height(D) < 50
    error('Not enough valid rows to train and evaluate the model.');
end

%% 3. Create grouped train/test split
groupTable = D(:, { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V'});

[~, ~, groupID] = unique(groupTable, 'rows');

uniqueGroups = unique(groupID);
uniqueGroups = uniqueGroups(randperm(numel(uniqueGroups)));

nTestGroups = max(1, round(0.20 * numel(uniqueGroups)));
testGroupIDs = uniqueGroups(1:nTestGroups);

isTest = ismember(groupID, testGroupIDs);
isTrain = ~isTest;

XTrain = X(isTrain,:);
YTrain = Y(isTrain);

XTest = X(isTest,:);
YTest = Y(isTest);

fprintf('Training rows: %d\n', sum(isTrain));
fprintf('Test rows: %d\n', sum(isTest));
fprintf('Held-out configuration groups: %d\n', nTestGroups);

if isempty(YTrain) || isempty(YTest)
    error('Train/test split produced an empty partition.');
end

%% 4. Train a new BoostedTrees model

fprintf('\nTraining new BoostedTrees model...\n');

treeTemplate = templateTree('MinLeafSize', 5);

newModel = fitrensemble( ...
    XTrain, YTrain, ...
    'Method', 'LSBoost', ...
    'NumLearningCycles', 150, ...
    'Learners', treeTemplate);

fprintf('New model training complete.\n');

%% 5. Evaluate original model on the same test set

originalModel = S.selectedModel;
originalModelName = string(S.modelInfo.SelectedModelName);

XOriginalTest = XTest;

% The original RidgeLinear model was trained on standardized inputs.
if originalModelName == "RidgeLinear"

    assert(isfield(S,'muX') && isfield(S,'sigmaX'), ...
        'Original RidgeLinear model lacks scaling parameters.');

    sigmaOriginal = S.sigmaX;
    sigmaOriginal(sigmaOriginal == 0 | ...
        ~isfinite(sigmaOriginal)) = 1;

    XOriginalTest = ...
        (XOriginalTest - S.muX) ./ sigmaOriginal;
end

originalPred = predict(originalModel, XOriginalTest);
newPred = predict(newModel, XTest);

%% 6. Calculate performance metrics

originalMetrics = calculateMetrics(YTest, originalPred);
newMetrics = calculateMetrics(YTest, newPred);

ModelMetrics = table( ...
    ["Original_" + originalModelName; "Retrained_BoostedTrees"], ...
    [originalMetrics.RMSE; newMetrics.RMSE], ...
    [originalMetrics.MAE; newMetrics.MAE], ...
    [originalMetrics.R2; newMetrics.R2], ...
    'VariableNames', {'Model','RMSE_dB','MAE_dB','R2'});

fprintf('\n========================================\n');
fprintf('HELD-OUT MODEL COMPARISON\n');
fprintf('========================================\n');

disp(ModelMetrics);

%% 7. Also evaluate the 12 V test subset

% The original training dataset used VDD fixed at 12 V.
% This subset provides a more comparable supply-voltage evaluation.

testTable = D(isTest,:);
is12V = abs(testTable.VDD_V - 12) < 1e-9;

if any(is12V)

    metricsOriginal12V = calculateMetrics( ...
        YTest(is12V), originalPred(is12V));

    metricsNew12V = calculateMetrics( ...
        YTest(is12V), newPred(is12V));

    Metrics12V = table( ...
        ["Original_" + originalModelName; "Retrained_BoostedTrees"], ...
        [metricsOriginal12V.RMSE; metricsNew12V.RMSE], ...
        [metricsOriginal12V.MAE; metricsNew12V.MAE], ...
        [metricsOriginal12V.R2; metricsNew12V.R2], ...
        'VariableNames', {'Model','RMSE_dB','MAE_dB','R2'});

    fprintf('\n========================================\n');
    fprintf('HELD-OUT TEST RESULTS AT VDD = 12 V\n');
    fprintf('========================================\n');

    disp(Metrics12V);

else
    Metrics12V = table();
    fprintf('\nNo held-out 12 V samples were available.\n');
end

%% 8. Build test prediction table

PredictionResults = testTable(:, featureColumns);

PredictionResults.ActualGain_dB = YTest;
PredictionResults.OriginalPredictedGain_dB = originalPred;
PredictionResults.NewPredictedGain_dB = newPred;

PredictionResults.OriginalAbsoluteError_dB = ...
    abs(YTest - originalPred);

PredictionResults.NewAbsoluteError_dB = ...
    abs(YTest - newPred);

%% 9. Save the new model separately

timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

modelOutputFolder = fullfile(projectRoot, 'models', ...
    'Common_Source', 'Exhaustive_Retrain', timestamp);

resultsOutputFolder = fullfile(projectRoot, 'results', ...
    'Model_Evaluation', 'Common_Source', timestamp);

if ~exist(modelOutputFolder, 'dir')
    mkdir(modelOutputFolder);
end

if ~exist(resultsOutputFolder, 'dir')
    mkdir(resultsOutputFolder);
end

% Save the retrained model and metadata.
selectedModel = newModel;

modelInfo = struct();
modelInfo.SelectedModelName = "BoostedTrees";
modelInfo.Dataset = dataFile;
modelInfo.TrainingRows = sum(isTrain);
modelInfo.TestRows = sum(isTest);
modelInfo.FeatureColumns = featureColumns;
modelInfo.TargetColumn = targetColumn;
modelInfo.TrainingTimestamp = timestamp;
modelInfo.SplitMethod = ...
    "Grouped holdout by resistor configuration and supply voltage";

save(fullfile(modelOutputFolder, 'CommonSourceModel_Retrained.mat'), ...
    'selectedModel', 'modelInfo', 'featureColumns', ...
    'targetColumn', 'ModelMetrics', 'newMetrics', ...
    'originalMetrics', 'dataFile');

writetable(ModelMetrics, fullfile(resultsOutputFolder, ...
    'model_comparison.csv'));

writetable(PredictionResults, fullfile(resultsOutputFolder, ...
    'test_predictions.csv'));

if ~isempty(Metrics12V)
    writetable(Metrics12V, fullfile(resultsOutputFolder, ...
        'model_comparison_12V.csv'));
end

%% 10. Plot actual versus predicted gain

fig = figure('Visible','off');

scatter(YTest, originalPred, 28, 'filled');
hold on;
scatter(YTest, newPred, 28, 'filled');

minValue = min([YTest; originalPred; newPred]);
maxValue = max([YTest; originalPred; newPred]);

plot([minValue maxValue], [minValue maxValue], 'k--', ...
    'LineWidth', 1.5);

xlabel('Actual SPICE Peak Gain (dB)');
ylabel('Predicted Peak Gain (dB)');

title('Original vs Retrained Common-Source Model');
legend('Original Model','Retrained BoostedTrees','Ideal Prediction', ...
    'Location','best');

grid on;
axis tight;

saveas(fig, fullfile(resultsOutputFolder, ...
    'actual_vs_predicted.png'));

close(fig);

%% 11. Final report

fprintf('\n========================================\n');
fprintf('RETRAINING COMPLETE\n');
fprintf('========================================\n');

fprintf('Original model: %s\n', originalModelName);
fprintf('New model: BoostedTrees\n');

fprintf('\nOriginal RMSE: %.4f dB\n', originalMetrics.RMSE);
fprintf('New RMSE: %.4f dB\n', newMetrics.RMSE);

fprintf('Original MAE: %.4f dB\n', originalMetrics.MAE);
fprintf('New MAE: %.4f dB\n', newMetrics.MAE);

fprintf('Original R2: %.4f\n', originalMetrics.R2);
fprintf('New R2: %.4f\n', newMetrics.R2);

if newMetrics.RMSE < originalMetrics.RMSE
    fprintf('\nThe retrained model has lower held-out RMSE.\n');
else
    fprintf('\nThe retrained model did not improve held-out RMSE.\n');
end

fprintf('\nNew model saved to:\n%s\n', modelOutputFolder);
fprintf('\nEvaluation results saved to:\n%s\n', resultsOutputFolder);

%% Local helper: calculate regression metrics

function M = calculateMetrics(actual, predicted)

    actual = actual(:);
    predicted = predicted(:);

    valid = isfinite(actual) & isfinite(predicted);

    actual = actual(valid);
    predicted = predicted(valid);

    if isempty(actual)
        M = struct('RMSE',NaN,'MAE',NaN,'R2',NaN);
        return;
    end

    residual = actual - predicted;

    M.RMSE = sqrt(mean(residual.^2));
    M.MAE = mean(abs(residual));

    totalSumSquares = sum((actual - mean(actual)).^2);
    residualSumSquares = sum(residual.^2);

    if totalSumSquares > 0
        M.R2 = 1 - residualSumSquares / totalSumSquares;
    else
        M.R2 = NaN;
    end
end

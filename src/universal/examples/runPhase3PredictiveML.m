
%% PHASE 3: UNIVERSAL CIRCUIT-XAI
% Predictive ML baseline for common-source 2N7000 circuits
% MATLAB only. Does not modify the original dataset.

clc;
clear;
close all;

rng(42, 'twister');

%% 1. Paths

root = 'C:\Internship Project';

baseDir = fullfile(root, ...
    'data', 'universal', 'Common_Source', ...
    'external_model_validation', '20261020_000113');

matFile = fullfile(baseDir, 'CS_Dataset_v2_100.mat');

assert(isfile(matFile), ...
    'Dataset not found: %s', matFile);

% Separate output directory for this experiment
experimentID = ['Phase3_ML_' datestr(now, 'yyyymmdd_HHMMSS')];

resultsDir = fullfile(root, 'results', experimentID);
if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

fprintf('\n========================================\n');
fprintf(' UNIVERSAL CIRCUIT-XAI: PHASE 3 ML\n');
fprintf('========================================\n');

%% 2. Load and validate data

S = load(matFile);
T = S.rows;

fprintf('Dataset rows: %d\n', height(T));

assert(height(T) >= 30, ...
    'Too few rows for this pilot experiment.');

targetName = 'GainAt1kHz_dB';

predictorNames = { ...
    'RGU_Ohm', ...
    'RGL_Ohm', ...
    'RD_Ohm', ...
    'RS_Ohm', ...
    'CIN_F'};

requiredNames = [predictorNames, {targetName}];

assert(all(ismember(requiredNames, ...
    T.Properties.VariableNames)), ...
    'One or more required columns are missing.');

% Target-leakage guard: output-derived variables are not predictors.
forbiddenPredictors = { ...
    'GainAt1kHz_dB', ...
    'PeakGain_dB', ...
    'PeakGainFrequency_Hz', ...
    'GainVariation_1k_10k_dB', ...
    'HighFrequency3dB_Hz'};

assert(isempty(intersect(predictorNames, ...
    forbiddenPredictors)), ...
    'Target leakage detected in predictor list.');

X = T{:, predictorNames};
Y = T.(targetName);

% Keep only rows with complete, finite input and target values.
validRows = all(isfinite(X), 2) & isfinite(Y);

if any(~validRows)
    warning('Excluding %d rows with invalid inputs or targets.', ...
        sum(~validRows));
end

T = T(validRows, :);
X = X(validRows, :);
Y = Y(validRows);

if ismember('CircuitID', T.Properties.VariableNames)
    circuitIDs = T.CircuitID;
else
    circuitIDs = (1:height(T))';
end

n = numel(Y);

assert(n >= 30, ...
    'Insufficient valid rows after filtering.');

fprintf('Valid rows used: %d\n', n);
fprintf('Predictors: %d\n', size(X, 2));
fprintf('Target: %s\n', targetName);

%% 3. Create shared five-fold cross-validation

K = 5;
cv = cvpartition(n, 'KFold', K);

% Each model uses exactly the same training/test folds.
oofLinear = nan(n, 1);
oofEnsemble = nan(n, 1);

foldMetrics = table( ...
    (1:K)', ...
    nan(K,1), nan(K,1), nan(K,1), ...
    nan(K,1), nan(K,1), nan(K,1), ...
    'VariableNames', { ...
    'Fold', ...
    'Linear_MAE', 'Linear_RMSE', 'Linear_R2', ...
    'Ensemble_MAE', 'Ensemble_RMSE', 'Ensemble_R2'});

fprintf('\nRunning %d-fold cross-validation...\n', K);

%% 4. Train and evaluate each fold

for k = 1:K

    trainIdx = training(cv, k);
    testIdx = test(cv, k);

    Xtrain = X(trainIdx, :);
    Ytrain = Y(trainIdx);

    Xtest = X(testIdx, :);
    Ytest = Y(testIdx);

    % Model A: linear regression
    mdlLinear = fitlm(Xtrain, Ytrain);

    predLinear = predict(mdlLinear, Xtest);

    % Model B: nonlinear bagged regression trees
    treeTemplate = templateTree( ...
        'MinLeafSize', 5);

    mdlEnsemble = fitrensemble( ...
        Xtrain, Ytrain, ...
        'Method', 'Bag', ...
        'NumLearningCycles', 100, ...
        'Learners', treeTemplate);

    predEnsemble = predict(mdlEnsemble, Xtest);

    % Save out-of-fold predictions in original row order.
    oofLinear(testIdx) = predLinear;
    oofEnsemble(testIdx) = predEnsemble;

    % Fold-level metrics
    foldMetrics.Linear_MAE(k) = ...
        mean(abs(Ytest - predLinear));

    foldMetrics.Linear_RMSE(k) = ...
        sqrt(mean((Ytest - predLinear).^2));

    foldMetrics.Linear_R2(k) = ...
        calculateR2(Ytest, predLinear);

    foldMetrics.Ensemble_MAE(k) = ...
        mean(abs(Ytest - predEnsemble));

    foldMetrics.Ensemble_RMSE(k) = ...
        sqrt(mean((Ytest - predEnsemble).^2));

    foldMetrics.Ensemble_R2(k) = ...
        calculateR2(Ytest, predEnsemble);

    fprintf('Completed fold %d of %d\n', k, K);
end

assert(all(isfinite(oofLinear)), ...
    'Linear model has missing out-of-fold predictions.');

assert(all(isfinite(oofEnsemble)), ...
    'Ensemble model has missing out-of-fold predictions.');

%% 5. Overall out-of-fold metrics

modelNames = ["Linear Regression"; "Bagged Trees"];

MAE = [ ...
    mean(abs(Y - oofLinear)); ...
    mean(abs(Y - oofEnsemble))];

RMSE = [ ...
    sqrt(mean((Y - oofLinear).^2)); ...
    sqrt(mean((Y - oofEnsemble).^2))];

R2 = [ ...
    calculateR2(Y, oofLinear); ...
    calculateR2(Y, oofEnsemble)];

summaryMetrics = table(modelNames, MAE, RMSE, R2, ...
    'VariableNames', {'Model', 'MAE_dB', 'RMSE_dB', 'R2'});

fprintf('\n========================================\n');
fprintf(' OVERALL OUT-OF-FOLD RESULTS\n');
fprintf('========================================\n');

disp(summaryMetrics);

fprintf('Mean fold-level metrics:\n');
disp(array2table( ...
    [mean(foldMetrics.Linear_MAE), ...
     mean(foldMetrics.Linear_RMSE), ...
     mean(foldMetrics.Linear_R2), ...
     mean(foldMetrics.Ensemble_MAE), ...
     mean(foldMetrics.Ensemble_RMSE), ...
     mean(foldMetrics.Ensemble_R2)], ...
    'VariableNames', { ...
     'Linear_MAE', 'Linear_RMSE', 'Linear_R2', ...
     'Ensemble_MAE', 'Ensemble_RMSE', 'Ensemble_R2'}));

%% 6. Save predictions and metrics

predictionTable = table( ...
    circuitIDs, Y, oofLinear, oofEnsemble, ...
    abs(Y-oofLinear), abs(Y-oofEnsemble), ...
    'VariableNames', { ...
    'CircuitID', 'ActualGain_dB', ...
    'LinearPredictedGain_dB', ...
    'EnsemblePredictedGain_dB', ...
    'LinearAbsoluteError_dB', ...
    'EnsembleAbsoluteError_dB'});

writetable(summaryMetrics, ...
    fullfile(resultsDir, 'Phase3_Model_Summary.csv'));

writetable(foldMetrics, ...
    fullfile(resultsDir, 'Phase3_Fold_Metrics.csv'));

writetable(predictionTable, ...
    fullfile(resultsDir, 'Phase3_OutOfFold_Predictions.csv'));

%% 7. Fit final models on all valid rows

% These models are for future inference.
% Their training fit is NOT an independent performance estimate.
finalLinear = fitlm(X, Y);

finalEnsemble = fitrensemble( ...
    X, Y, ...
    'Method', 'Bag', ...
    'NumLearningCycles', 100, ...
    'Learners', templateTree('MinLeafSize', 5));

save(fullfile(resultsDir, 'Phase3_Trained_Models.mat'), ...
    'finalLinear', 'finalEnsemble', ...
    'predictorNames', 'targetName', ...
    'summaryMetrics', 'foldMetrics', ...
    'predictionTable', 'experimentID');

%% 8. Plot out-of-fold predictions

figure('Name', 'Phase 3: ML Model Comparison');

tiledlayout(1,2);

nexttile;
scatter(Y, oofLinear, 'filled');
hold on;
limits = [min(Y), max(Y)];
plot(limits, limits, '--');
xlabel('Actual gain at 1 kHz (dB)');
ylabel('Predicted gain (dB)');
title('Linear Regression');
grid on;
axis square;

nexttile;
scatter(Y, oofEnsemble, 'filled');
hold on;
plot(limits, limits, '--');
xlabel('Actual gain at 1 kHz (dB)');
ylabel('Predicted gain (dB)');
title('Bagged Trees');
grid on;
axis square;

saveas(gcf, fullfile(resultsDir, ...
    'Phase3_Actual_vs_Predicted.png'));

save(fullfile(resultsDir, 'Phase3_Experiment_Data.mat'), ...
    'X', 'Y', 'predictorNames', 'targetName', ...
    'oofLinear', 'oofEnsemble', 'validRows');

fprintf('\n========================================\n');
fprintf(' PHASE 3 BASELINE COMPLETE\n');
fprintf('========================================\n');
fprintf('Results saved in:\n%s\n', resultsDir);
fprintf('Original dataset was not modified.\n');

%% Local helper function

function r2 = calculateR2(actual, predicted)

    ssRes = sum((actual - predicted).^2);
    ssTot = sum((actual - mean(actual)).^2);

    if ssTot <= eps
        r2 = NaN;
    else
        r2 = 1 - ssRes / ssTot;
    end
end

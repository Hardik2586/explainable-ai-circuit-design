%% evaluate_dl_model.m
% Evaluate trained Deep Learning CE amplifier regression model
%
% MATLAB R2025b
%
% This script performs an independent evaluation of the already-trained
% model on the locked final test set.
%
% No retraining is performed here.

clear;
clc;
close all;

fprintf('=============================================\n');
fprintf('   CE AMPLIFIER - DL MODEL EVALUATION\n');
fprintf('=============================================\n\n');


%% ============================================================
% 1. PROJECT PATHS
% =============================================================

scriptDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(fileparts(scriptDir));

modelFile = fullfile( ...
    projectRoot, ...
    'models', ...
    'deep_learning', ...
    'CE_Gain_DL_Model.mat');

resultFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Training_Results.mat');

plotDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'evaluation_plots');


if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end


%% ============================================================
% 2. CHECK FILES
% =============================================================

if ~isfile(modelFile)

    error( ...
        'Trained DL model not found:\n%s', ...
        modelFile);

end


if ~isfile(resultFile)

    error( ...
        'DL training results not found:\n%s', ...
        resultFile);

end


%% ============================================================
% 3. LOAD MODEL AND RESULTS
% =============================================================

fprintf('Loading trained model...\n');

load(modelFile, ...
    'net', ...
    'featureNames', ...
    'targetName');


fprintf('Loading test predictions...\n');

load(resultFile, ...
    'YPredTest', ...
    'YTest');


fprintf('Files loaded successfully.\n\n');


%% ============================================================
% 4. VERIFY TEST DATA
% =============================================================

YTest = double(YTest);
YPredTest = double(YPredTest);

if numel(YTest) ~= numel(YPredTest)

    error( ...
        'Test target and prediction sizes do not match.');

end


YTest = YTest(:);
YPredTest = YPredTest(:);


fprintf('Number of test samples: %d\n\n', ...
    numel(YTest));


%% ============================================================
% 5. CALCULATE ERROR
% =============================================================

% Prediction error
%
% Positive error means:
% predicted > actual
%
% Negative error means:
% predicted < actual

residuals = YPredTest - YTest;

absoluteError = abs(residuals);


%% ============================================================
% 6. CALCULATE PERFORMANCE METRICS
% =============================================================

MAE = mean(absoluteError);

RMSE = sqrt(mean(residuals.^2));

MeanError = mean(residuals);

StdError = std(residuals);

MaxAbsoluteError = max(absoluteError);

MedianAbsoluteError = median(absoluteError);


% R^2

SSres = sum(residuals.^2);

SStot = sum( ...
    (YTest - mean(YTest)).^2);

R2 = 1 - SSres / SStot;


%% ============================================================
% 7. CORRELATION
% =============================================================

PearsonR = corr(YTest, YPredTest, ...
    'Type', 'Pearson');

SpearmanR = corr(YTest, YPredTest, ...
    'Type', 'Spearman');


%% ============================================================
% 8. DISPLAY RESULTS
% =============================================================

fprintf('=============================================\n');
fprintf('          FINAL TEST PERFORMANCE\n');
fprintf('=============================================\n\n');

fprintf('R^2                  = %.6f\n', R2);

fprintf('RMSE                 = %.6f dB\n', RMSE);

fprintf('MAE                  = %.6f dB\n', MAE);

fprintf('Mean Error           = %.6f dB\n', MeanError);

fprintf('Std Error            = %.6f dB\n', StdError);

fprintf('Median Absolute Error= %.6f dB\n', ...
    MedianAbsoluteError);

fprintf('Maximum Absolute Error = %.6f dB\n', ...
    MaxAbsoluteError);

fprintf('Pearson correlation  = %.6f\n', PearsonR);

fprintf('Spearman correlation = %.6f\n\n', SpearmanR);


%% ============================================================
% 9. ACTUAL VS PREDICTED
% =============================================================

figure( ...
    'Name', ...
    'DL Actual vs Predicted', ...
    'Color', 'w');

scatter( ...
    YTest, ...
    YPredTest, ...
    35, ...
    'filled');

hold on;


% Identity line

minValue = min([YTest; YPredTest]);

maxValue = max([YTest; YPredTest]);

plot( ...
    [minValue maxValue], ...
    [minValue maxValue], ...
    'k--', ...
    'LineWidth', 1.5);


xlabel('Actual Gain (dB)');

ylabel('Predicted Gain (dB)');

title( ...
    sprintf( ...
    'DL Model: Actual vs Predicted (R^2 = %.4f)', ...
    R2));

grid on;

axis square;

xlim([minValue maxValue]);
ylim([minValue maxValue]);

legend( ...
    'Test samples', ...
    'Ideal y = x', ...
    'Location', 'best');

hold off;


saveas( ...
    gcf, ...
    fullfile( ...
    plotDir, ...
    'DL_Actual_vs_Predicted.png'));


%% ============================================================
% 10. RESIDUAL VS PREDICTED
% =============================================================

figure( ...
    'Name', ...
    'DL Residual Analysis', ...
    'Color', 'w');

scatter( ...
    YPredTest, ...
    residuals, ...
    35, ...
    'filled');

hold on;

yline( ...
    0, ...
    'k--', ...
    'LineWidth', 1.5);


xlabel('Predicted Gain (dB)');

ylabel('Residual (Predicted - Actual) (dB)');

title('DL Model Residuals');

grid on;

hold off;


saveas( ...
    gcf, ...
    fullfile( ...
    plotDir, ...
    'DL_Residual_vs_Predicted.png'));


%% ============================================================
% 11. RESIDUAL DISTRIBUTION
% =============================================================

figure( ...
    'Name', ...
    'DL Residual Distribution', ...
    'Color', 'w');

histogram( ...
    residuals, ...
    20);

hold on;

xline( ...
    0, ...
    'k--', ...
    'LineWidth', 1.5);


xlabel('Residual (dB)');

ylabel('Number of Samples');

title('DL Model Residual Distribution');

grid on;

hold off;


saveas( ...
    gcf, ...
    fullfile( ...
    plotDir, ...
    'DL_Residual_Distribution.png'));


%% ============================================================
% 12. ERROR VS ACTUAL GAIN
% =============================================================

figure( ...
    'Name', ...
    'DL Error vs Actual Gain', ...
    'Color', 'w');

scatter( ...
    YTest, ...
    absoluteError, ...
    35, ...
    'filled');


xlabel('Actual Gain (dB)');

ylabel('|Prediction Error| (dB)');

title('DL Absolute Error vs Actual Gain');

grid on;


saveas( ...
    gcf, ...
    fullfile( ...
    plotDir, ...
    'DL_Absolute_Error_vs_Actual.png'));


%% ============================================================
% 13. IDENTIFY LARGEST ERRORS
% =============================================================

[sortedErrors, sortedIndex] = ...
    sort(absoluteError, 'descend');

numLargest = min(10, numel(sortedErrors));

fprintf('=============================================\n');
fprintf('       10 LARGEST TEST ERRORS\n');
fprintf('=============================================\n\n');

fprintf( ...
    '%5s %15s %15s %15s\n', ...
    'Rank', ...
    'Actual(dB)', ...
    'Predicted(dB)', ...
    'Abs Error(dB)');


for i = 1:numLargest

    idx = sortedIndex(i);

    fprintf( ...
        '%5d %15.4f %15.4f %15.4f\n', ...
        i, ...
        YTest(idx), ...
        YPredTest(idx), ...
        absoluteError(idx));

end


%% ============================================================
% 14. SAVE EVALUATION RESULTS
% =============================================================

evaluationFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Evaluation_Results.mat');


save( ...
    evaluationFile, ...
    'R2', ...
    'RMSE', ...
    'MAE', ...
    'MeanError', ...
    'StdError', ...
    'MedianAbsoluteError', ...
    'MaxAbsoluteError', ...
    'PearsonR', ...
    'SpearmanR', ...
    'YTest', ...
    'YPredTest', ...
    'residuals', ...
    'absoluteError', ...
    'featureNames', ...
    'targetName');


%% ============================================================
% 15. FINAL MESSAGE
% =============================================================

fprintf('\n=============================================\n');
fprintf('       DL EVALUATION COMPLETED\n');
fprintf('=============================================\n\n');

fprintf('Evaluation results saved to:\n%s\n\n', ...
    evaluationFile);

fprintf('Plots saved to:\n%s\n\n', ...
    plotDir);

fprintf('Final test metrics:\n');

fprintf('R^2   = %.4f\n', R2);

fprintf('RMSE  = %.4f dB\n', RMSE);

fprintf('MAE   = %.4f dB\n', MAE);

fprintf('\n=============================================\n');
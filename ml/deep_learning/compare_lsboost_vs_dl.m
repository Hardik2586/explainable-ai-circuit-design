%% compare_lsboost_vs_dl.m
% Formal comparison between:
%   1. Classical LSBoost regression model
%   2. Deep Learning regression model
%
% Both models are evaluated on the SAME locked test set.
%
% MATLAB R2025b

clear;
clc;
close all;

fprintf('=============================================\n');
fprintf('     LSBOOST vs DEEP LEARNING COMPARISON\n');
fprintf('=============================================\n\n');


%% ============================================================
% 1. PROJECT PATHS
% =============================================================

scriptDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(fileparts(scriptDir));

datasetFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Dataset.mat');

dlResultFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Training_Results.mat');

resultDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'model_comparison');

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end


%% ============================================================
% 2. LOAD DL DATASET
% =============================================================

if ~isfile(datasetFile)
    error('DL dataset not found:\n%s', datasetFile);
end

load(datasetFile);

fprintf('DL dataset loaded.\n');


%% ============================================================
% 3. LOAD DL PREDICTIONS
% =============================================================

if ~isfile(dlResultFile)
    error('DL training results not found:\n%s', dlResultFile);
end

load(dlResultFile, ...
    'YPredTest', ...
    'YTest');

fprintf('DL predictions loaded.\n');


%% ============================================================
% 4. CONVERT TEST MASK TO ROW INDICES
% ============================================================

% testIdx is a logical 660x1 vector.
% Convert it to the actual 132 row indices.

if islogical(testIdx)

    testIdxDL = find(testIdx);

else

    testIdxDL = testIdx(:);

end


fprintf('\nNumber of locked test samples: %d\n', ...
    numel(testIdxDL));


%% ============================================================
% 5. VERIFY TEST SAMPLE COUNT
% ============================================================

if numel(testIdxDL) ~= numel(YTest)

    error([ ...
        'Mismatch between test indices and DL test predictions.\n' ...
        'Test indices : %d\n' ...
        'Test targets : %d'], ...
        numel(testIdxDL), ...
        numel(YTest));

end


%% ============================================================
% 6. LOAD CANONICAL DATASET
% ============================================================

canonicalFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

if ~isfile(canonicalFile)

    error( ...
        'Canonical dataset not found:\n%s', ...
        canonicalFile);

end

data = readtable(canonicalFile);

fprintf('Canonical dataset loaded.\n');


%% ============================================================
% 7. DEFINE FEATURES
% =============================================================

featureNames = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};


%% ============================================================
% 8. EXTRACT COMPLETE DATASET
% =============================================================

XRaw = data{:, featureNames};

YAll = data.Gain_dB;


%% ============================================================
% 9. EXTRACT SAME 132 TEST CIRCUITS
% =============================================================

XTestRaw = XRaw(testIdxDL, :);

YTestCanonical = YAll(testIdxDL);

YTest = double(YTest(:));
YPredDL = double(YPredTest(:));


%% ============================================================
% 10. VERIFY TARGET CONSISTENCY
% =============================================================

targetDifference = ...
    max(abs(YTestCanonical - YTest));


% Small floating-point differences can occur because the
% prepared MAT dataset and CSV may use different numeric
% storage precision.

targetTolerance = 1e-5;


if targetDifference > targetTolerance

    error([ ...
        'DL test targets do not match canonical dataset.\n' ...
        'Maximum difference = %.12g dB\n' ...
        'Allowed tolerance = %.12g dB'], ...
        targetDifference, ...
        targetTolerance);

end


fprintf( ...
    'Test target consistency verified.\n');

fprintf( ...
    'Maximum target difference = %.12g dB\n', ...
    targetDifference);

fprintf( ...
    'Tolerance                = %.12g dB\n\n', ...
    targetTolerance);


fprintf('Same 132 test circuits confirmed.\n');


%% ============================================================
% 11. LOAD CANONICAL LSBOOST MODEL
% =============================================================

lsboostFile = fullfile( ...
    projectRoot, ...
    'ml', ...
    'models', ...
    'Gain_Boosted_Model.mat');


if ~isfile(lsboostFile)

    error( ...
        'Canonical LSBoost model not found:\n%s', ...
        lsboostFile);

end


fprintf('\nLSBoost model:\n%s\n', ...
    lsboostFile);


S = load(lsboostFile);


%% ============================================================
% 12. VERIFY LSBOOST MODEL VARIABLE
% =============================================================

if ~isfield(S, 'model')

    fprintf('\nVariables found in LSBoost MAT file:\n');
    disp(fieldnames(S));

    error( ...
        'Variable "model" was not found in Gain_Boosted_Model.mat.');

end


model = S.model;


fprintf('LSBoost model loaded successfully.\n');

fprintf('Model class: %s\n\n', ...
    class(model));


%% ============================================================
% 13. PREPARE LSBOOST INPUT
% =============================================================

% Existing LSBoost preprocessing:
%
% R1,R2,RC,RE,RL,Cin,Cout,Ce -> log10
% VCC -> linear

XTestLSBoost = XTestRaw;

XTestLSBoost(:,1:8) = ...
    log10(XTestLSBoost(:,1:8));


%% ============================================================
% 14. LSBOOST PREDICTIONS
% =============================================================

fprintf('Generating LSBoost predictions...\n');

YPredLSBoost = predict( ...
    model, ...
    XTestLSBoost);

YPredLSBoost = double(YPredLSBoost(:));


%% ============================================================
% 15. LSBOOST METRICS
% =============================================================

errorLSBoost = ...
    YPredLSBoost - YTest;


MAE_LSBoost = ...
    mean(abs(errorLSBoost));


RMSE_LSBoost = ...
    sqrt(mean(errorLSBoost.^2));


R2_LSBoost = ...
    1 - ...
    sum(errorLSBoost.^2) / ...
    sum((YTest - mean(YTest)).^2);


Pearson_LSBoost = ...
    corr(YTest, YPredLSBoost, ...
    'Type','Pearson');


Spearman_LSBoost = ...
    corr(YTest, YPredLSBoost, ...
    'Type','Spearman');


%% ============================================================
% 16. DEEP LEARNING METRICS
% =============================================================

errorDL = ...
    YPredDL - YTest;


MAE_DL = ...
    mean(abs(errorDL));


RMSE_DL = ...
    sqrt(mean(errorDL.^2));


R2_DL = ...
    1 - ...
    sum(errorDL.^2) / ...
    sum((YTest - mean(YTest)).^2);


Pearson_DL = ...
    corr(YTest, YPredDL, ...
    'Type','Pearson');


Spearman_DL = ...
    corr(YTest, YPredDL, ...
    'Type','Spearman');


%% ============================================================
% 17. IMPROVEMENT
% =============================================================

R2Improvement = ...
    R2_DL - R2_LSBoost;


RMSEImprovementPercent = ...
    100 * ...
    (RMSE_LSBoost - RMSE_DL) / ...
    RMSE_LSBoost;


MAEImprovementPercent = ...
    100 * ...
    (MAE_LSBoost - MAE_DL) / ...
    MAE_LSBoost;


%% ============================================================
% 18. DISPLAY RESULTS
% =============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('          MODEL COMPARISON RESULTS\n');
fprintf('=============================================\n\n');


fprintf('%-20s %12s %12s %12s\n', ...
    'Model', ...
    'R^2', ...
    'RMSE (dB)', ...
    'MAE (dB)');


fprintf('%-20s %12.4f %12.4f %12.4f\n', ...
    'LSBoost', ...
    R2_LSBoost, ...
    RMSE_LSBoost, ...
    MAE_LSBoost);


fprintf('%-20s %12.4f %12.4f %12.4f\n\n', ...
    'Deep Learning', ...
    R2_DL, ...
    RMSE_DL, ...
    MAE_DL);


fprintf('Pearson correlation:\n');

fprintf('LSBoost       = %.4f\n', ...
    Pearson_LSBoost);

fprintf('Deep Learning = %.4f\n\n', ...
    Pearson_DL);


fprintf('Spearman correlation:\n');

fprintf('LSBoost       = %.4f\n', ...
    Spearman_LSBoost);

fprintf('Deep Learning = %.4f\n\n', ...
    Spearman_DL);


fprintf('=============================================\n');
fprintf('       DL IMPROVEMENT OVER LSBOOST\n');
fprintf('=============================================\n\n');

fprintf('R^2 improvement  = %+0.4f\n', ...
    R2Improvement);

fprintf('RMSE improvement = %.2f %%\n', ...
    RMSEImprovementPercent);

fprintf('MAE improvement  = %.2f %%\n', ...
    MAEImprovementPercent);


%% ============================================================
% 19. PREDICTION COMPARISON
% =============================================================

figure( ...
    'Name', ...
    'LSBoost vs Deep Learning', ...
    'Color', ...
    'w');


scatter( ...
    YTest, ...
    YPredLSBoost, ...
    35, ...
    'filled');

hold on;


scatter( ...
    YTest, ...
    YPredDL, ...
    35, ...
    'filled');


minValue = min([ ...
    YTest; ...
    YPredLSBoost; ...
    YPredDL]);


maxValue = max([ ...
    YTest; ...
    YPredLSBoost; ...
    YPredDL]);


plot( ...
    [minValue maxValue], ...
    [minValue maxValue], ...
    'k--', ...
    'LineWidth', ...
    1.5);


xlabel('Actual Gain (dB)');

ylabel('Predicted Gain (dB)');

title('LSBoost vs Deep Learning');

legend( ...
    'LSBoost', ...
    'Deep Learning', ...
    'Ideal y = x', ...
    'Location', ...
    'best');

grid on;

axis square;

xlim([minValue maxValue]);

ylim([minValue maxValue]);

hold off;


saveas( ...
    gcf, ...
    fullfile( ...
    resultDir, ...
    'LSBoost_vs_DL_Predictions.png'));


%% ============================================================
% 20. METRIC COMPARISON
% =============================================================

figure( ...
    'Name', ...
    'LSBoost vs DL Metrics', ...
    'Color', ...
    'w');


metricValues = [ ...
    R2_LSBoost, R2_DL; ...
    RMSE_LSBoost, RMSE_DL; ...
    MAE_LSBoost, MAE_DL];


bar(metricValues);


set(gca, ...
    'XTickLabel', ...
    {'R^2','RMSE (dB)','MAE (dB)'});


ylabel('Metric Value');

title('LSBoost vs Deep Learning Performance');

legend( ...
    'LSBoost', ...
    'Deep Learning', ...
    'Location', ...
    'best');

grid on;


saveas( ...
    gcf, ...
    fullfile( ...
    resultDir, ...
    'LSBoost_vs_DL_Metrics.png'));


%% ============================================================
% 21. SAVE RESULTS
% =============================================================

comparisonFile = fullfile( ...
    resultDir, ...
    'LSBoost_vs_DL_Comparison.mat');


save( ...
    comparisonFile, ...
    'R2_LSBoost', ...
    'RMSE_LSBoost', ...
    'MAE_LSBoost', ...
    'Pearson_LSBoost', ...
    'Spearman_LSBoost', ...
    'R2_DL', ...
    'RMSE_DL', ...
    'MAE_DL', ...
    'Pearson_DL', ...
    'Spearman_DL', ...
    'R2Improvement', ...
    'RMSEImprovementPercent', ...
    'MAEImprovementPercent', ...
    'YTest', ...
    'YPredLSBoost', ...
    'YPredDL', ...
    'errorLSBoost', ...
    'errorDL', ...
    'testIdxDL', ...
    'featureNames');


%% ============================================================
% 22. FINAL MESSAGE
% =============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       COMPARISON COMPLETED\n');
fprintf('=============================================\n\n');

fprintf('Results saved to:\n%s\n\n', ...
    comparisonFile);

fprintf('Plots saved to:\n%s\n\n', ...
    resultDir);


if R2_DL > R2_LSBoost && ...
        RMSE_DL < RMSE_LSBoost && ...
        MAE_DL < MAE_LSBoost

    fprintf(['Deep Learning outperforms LSBoost on all three ' ...
        'primary metrics for this locked test set.\n']);

else

    fprintf(['Deep Learning does not outperform LSBoost on all ' ...
        'three primary metrics.\n']);

end

fprintf('\n=============================================\n');
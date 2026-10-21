%% cross_validate_models.m
% 5-Fold Cross-Validation:
% LSBoost vs Deep Learning
%
% CE Amplifier Gain Prediction
%
% MATLAB R2025b
%
% Outer CV:
%   5 folds
%
% Inner DL split:
%   80% training
%   20% validation
%
% IMPORTANT:
% Preprocessing statistics are calculated independently
% inside every fold using training data only.

clear;
clc;
close all;

fprintf('=============================================\n');
fprintf('  5-FOLD CV: LSBOOST vs DEEP LEARNING\n');
fprintf('=============================================\n\n');


%% ============================================================
% 1. PROJECT PATHS
% ============================================================

scriptDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(fileparts(scriptDir));

datasetFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

resultDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'cross_validation');

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end


%% ============================================================
% 2. LOAD CANONICAL DATASET
% ============================================================

if ~isfile(datasetFile)

    error( ...
        'Canonical dataset not found:\n%s', ...
        datasetFile);

end

data = readtable(datasetFile);

fprintf('Dataset loaded successfully.\n');

fprintf('Rows    : %d\n', height(data));

fprintf('Columns : %d\n\n', width(data));


%% ============================================================
% 3. FEATURES AND TARGET
% ============================================================

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

XRaw = data{:, featureNames};

Y = data.Gain_dB;

Y = double(Y(:));

N = size(XRaw, 1);

numFeatures = size(XRaw, 2);


fprintf('Features : %d\n', numFeatures);

fprintf('Samples  : %d\n\n', N);


%% ============================================================
% 4. CROSS-VALIDATION SETTINGS
% ============================================================

numFolds = 5;

baseSeed = 42;

rng(baseSeed, 'twister');

outerCV = cvpartition(N, 'KFold', numFolds);


%% ============================================================
% 5. PREALLOCATE RESULTS
% ============================================================

R2_DL = zeros(numFolds,1);
RMSE_DL = zeros(numFolds,1);
MAE_DL = zeros(numFolds,1);

R2_LSBoost = zeros(numFolds,1);
RMSE_LSBoost = zeros(numFolds,1);
MAE_LSBoost = zeros(numFolds,1);

Pearson_DL = zeros(numFolds,1);
Spearman_DL = zeros(numFolds,1);

Pearson_LSBoost = zeros(numFolds,1);
Spearman_LSBoost = zeros(numFolds,1);


%% ============================================================
% 6. OUTER 5-FOLD LOOP
% ============================================================

for fold = 1:numFolds

    fprintf('\n');
    fprintf('=============================================\n');
    fprintf('                FOLD %d / %d\n', ...
        fold, numFolds);
    fprintf('=============================================\n');


    %% --------------------------------------------------------
    % Outer train/test indices
    % ---------------------------------------------------------

    idxTrainOuter = training(outerCV, fold);

    idxTestOuter = test(outerCV, fold);


    XOuterTrain = XRaw(idxTrainOuter,:);

    YOuterTrain = Y(idxTrainOuter);

    XOuterTest = XRaw(idxTestOuter,:);

    YOuterTest = Y(idxTestOuter);


    fprintf('Outer training samples : %d\n', ...
        sum(idxTrainOuter));

    fprintf('Outer test samples     : %d\n', ...
        sum(idxTestOuter));


    %% ========================================================
    % 7. INNER TRAIN / VALIDATION SPLIT FOR DL
    % ========================================================

    rng(baseSeed + fold);

    NOuterTrain = size(XOuterTrain,1);

    innerCV = cvpartition( ...
        NOuterTrain, ...
        'HoldOut', ...
        0.20);


    idxInnerTrain = training(innerCV);

    idxValidation = test(innerCV);


    XTrain = XOuterTrain(idxInnerTrain,:);

    YTrain = YOuterTrain(idxInnerTrain);

    XValidation = XOuterTrain(idxValidation,:);

    YValidation = YOuterTrain(idxValidation);


    fprintf('DL training samples    : %d\n', ...
        size(XTrain,1));

    fprintf('DL validation samples  : %d\n', ...
        size(XValidation,1));


    %% ========================================================
    % 8. DL PREPROCESSING
    % ========================================================
    %
    % First 8 features:
    %     log10 transformation
    %
    % VCC:
    %     remains linear
    %
    % Then:
    %     z-score normalization
    %
    % Statistics are calculated ONLY from inner training data.

    XTrainTransformed = XTrain;

    XValidationTransformed = XValidation;

    XTestTransformed = XOuterTest;


    % Log transform first 8 component features

    XTrainTransformed(:,1:8) = ...
        log10(XTrainTransformed(:,1:8));

    XValidationTransformed(:,1:8) = ...
        log10(XValidationTransformed(:,1:8));

    XTestTransformed(:,1:8) = ...
        log10(XTestTransformed(:,1:8));


    % Calculate normalization statistics from training only

    mu = mean(XTrainTransformed,1);

    sigma = std(XTrainTransformed,0,1);


    % Safety check

    if any(sigma == 0)

        error( ...
            'Zero standard deviation encountered in fold %d.', ...
            fold);

    end


    % Normalize all three sets using training statistics

    XTrainDL = ...
        (XTrainTransformed - mu) ./ sigma;

    XValidationDL = ...
        (XValidationTransformed - mu) ./ sigma;

    XTestDL = ...
        (XTestTransformed - mu) ./ sigma;


    %% ========================================================
    % 9. CONVERT DL DATA TO SINGLE
    % ========================================================

    XTrainDL = single(XTrainDL);

    YTrainDL = single(YTrain);

    XValidationDL = single(XValidationDL);

    YValidationDL = single(YValidation);

    XTestDL = single(XTestDL);


    %% ========================================================
    % 10. DEFINE DL NETWORK
    % ========================================================

    layers = [

        featureInputLayer( ...
            numFeatures, ...
            Normalization="none", ...
            Name="input")

        fullyConnectedLayer( ...
            64, ...
            Name="fc1")

        reluLayer( ...
            Name="relu1")

        fullyConnectedLayer( ...
            32, ...
            Name="fc2")

        reluLayer( ...
            Name="relu2")

        fullyConnectedLayer( ...
            16, ...
            Name="fc3")

        reluLayer( ...
            Name="relu3")

        fullyConnectedLayer( ...
            1, ...
            Name="output")

    ];


    %% ========================================================
    % 11. DL TRAINING OPTIONS
    % ========================================================

    options = trainingOptions( ...
        "adam", ...
        MaxEpochs=300, ...
        MiniBatchSize=32, ...
        InitialLearnRate=1e-3, ...
        Shuffle="every-epoch", ...
        ValidationData={ ...
            XValidationDL, ...
            single(YValidation)}, ...
        ValidationFrequency=10, ...
        ValidationPatience=30, ...
        Verbose=false, ...
        Plots="none");


    %% ========================================================
    % 12. TRAIN DL MODEL
    % ========================================================

    fprintf('\nTraining Deep Learning model...\n');


    rng(baseSeed + fold);

    [net, trainInfo] = trainnet( ...
        XTrainDL, ...
        YTrainDL, ...
        layers, ...
        "mse", ...
        options);


    %% ========================================================
    % 13. DL TEST PREDICTION
    % ========================================================

    YPredDL = predict( ...
        net, ...
        XTestDL);


    YPredDL = double(YPredDL(:));


    %% ========================================================
    % 14. DL METRICS
    % ========================================================

    errorDL = ...
        YPredDL - YOuterTest;


    MAE_DL(fold) = ...
        mean(abs(errorDL));


    RMSE_DL(fold) = ...
        sqrt(mean(errorDL.^2));


    R2_DL(fold) = ...
        1 - ...
        sum(errorDL.^2) / ...
        sum((YOuterTest - ...
        mean(YOuterTest)).^2);


    Pearson_DL(fold) = ...
        corr( ...
        YOuterTest, ...
        YPredDL, ...
        'Type','Pearson');


    Spearman_DL(fold) = ...
        corr( ...
        YOuterTest, ...
        YPredDL, ...
        'Type','Spearman');


    %% ========================================================
    % 15. TRAIN LSBOOST
    % ========================================================

    fprintf('Training LSBoost model...\n');


    % LSBoost uses the OUTER training data.
    %
    % It does not require the DL normalization.
    %
    % Only log10 transformation is applied.

    XLSOuterTrain = XOuterTrain;

    XLSOuterTest = XOuterTest;


    XLSOuterTrain(:,1:8) = ...
        log10(XLSOuterTrain(:,1:8));

    XLSOuterTest(:,1:8) = ...
        log10(XLSOuterTest(:,1:8));


    % Same LSBoost configuration as the established
    % classical ML baseline.

    treeTemplate = templateTree( ...
        'MaxNumSplits',20, ...
        'MinLeafSize',8);


    lsboostModel = fitrensemble( ...
        XLSOuterTrain, ...
        YOuterTrain, ...
        'Method','LSBoost', ...
        'NumLearningCycles',300, ...
        'Learners',treeTemplate, ...
        'LearnRate',0.03);


    %% ========================================================
    % 16. LSBOOST TEST PREDICTION
    % ========================================================

    YPredLSBoost = predict( ...
        lsboostModel, ...
        XLSOuterTest);


    YPredLSBoost = double(YPredLSBoost(:));


    %% ========================================================
    % 17. LSBOOST METRICS
    % ========================================================

    errorLSBoost = ...
        YPredLSBoost - YOuterTest;


    MAE_LSBoost(fold) = ...
        mean(abs(errorLSBoost));


    RMSE_LSBoost(fold) = ...
        sqrt(mean(errorLSBoost.^2));


    R2_LSBoost(fold) = ...
        1 - ...
        sum(errorLSBoost.^2) / ...
        sum((YOuterTest - ...
        mean(YOuterTest)).^2);


    Pearson_LSBoost(fold) = ...
        corr( ...
        YOuterTest, ...
        YPredLSBoost, ...
        'Type','Pearson');


    Spearman_LSBoost(fold) = ...
        corr( ...
        YOuterTest, ...
        YPredLSBoost, ...
        'Type','Spearman');


    %% ========================================================
    % 18. FOLD RESULTS
    % ========================================================

    fprintf('\n');

    fprintf('Fold %d results:\n', fold);

    fprintf('\nDeep Learning:\n');

    fprintf('R^2   = %.4f\n', ...
        R2_DL(fold));

    fprintf('RMSE  = %.4f dB\n', ...
        RMSE_DL(fold));

    fprintf('MAE   = %.4f dB\n', ...
        MAE_DL(fold));


    fprintf('\nLSBoost:\n');

    fprintf('R^2   = %.4f\n', ...
        R2_LSBoost(fold));

    fprintf('RMSE  = %.4f dB\n', ...
        RMSE_LSBoost(fold));

    fprintf('MAE   = %.4f dB\n', ...
        MAE_LSBoost(fold));

end


%% ============================================================
% 19. CALCULATE MEAN AND STANDARD DEVIATION
% =============================================================

mean_R2_DL = mean(R2_DL);

std_R2_DL = std(R2_DL);

mean_RMSE_DL = mean(RMSE_DL);

std_RMSE_DL = std(RMSE_DL);

mean_MAE_DL = mean(MAE_DL);

std_MAE_DL = std(MAE_DL);


mean_R2_LSBoost = mean(R2_LSBoost);

std_R2_LSBoost = std(R2_LSBoost);

mean_RMSE_LSBoost = mean(RMSE_LSBoost);

std_RMSE_LSBoost = std(RMSE_LSBoost);

mean_MAE_LSBoost = mean(MAE_LSBoost);

std_MAE_LSBoost = std(MAE_LSBoost);


%% ============================================================
% 20. MEAN CORRELATIONS
% =============================================================

mean_Pearson_DL = mean(Pearson_DL);

std_Pearson_DL = std(Pearson_DL);

mean_Spearman_DL = mean(Spearman_DL);

std_Spearman_DL = std(Spearman_DL);


mean_Pearson_LSBoost = mean(Pearson_LSBoost);

std_Pearson_LSBoost = std(Pearson_LSBoost);

mean_Spearman_LSBoost = mean(Spearman_LSBoost);

std_Spearman_LSBoost = std(Spearman_LSBoost);


%% ============================================================
% 21. DISPLAY FINAL RESULTS
% =============================================================

fprintf('\n\n');
fprintf('=============================================\n');
fprintf('       5-FOLD CROSS-VALIDATION RESULTS\n');
fprintf('=============================================\n\n');


fprintf('DEEP LEARNING\n');
fprintf('-------------\n');

fprintf('R^2   = %.4f +/- %.4f\n', ...
    mean_R2_DL, ...
    std_R2_DL);

fprintf('RMSE  = %.4f +/- %.4f dB\n', ...
    mean_RMSE_DL, ...
    std_RMSE_DL);

fprintf('MAE   = %.4f +/- %.4f dB\n', ...
    mean_MAE_DL, ...
    std_MAE_DL);


fprintf('\nLSBOOST\n');
fprintf('-------\n');

fprintf('R^2   = %.4f +/- %.4f\n', ...
    mean_R2_LSBoost, ...
    std_R2_LSBoost);

fprintf('RMSE  = %.4f +/- %.4f dB\n', ...
    mean_RMSE_LSBoost, ...
    std_RMSE_LSBoost);

fprintf('MAE   = %.4f +/- %.4f dB\n', ...
    mean_MAE_LSBoost, ...
    std_MAE_LSBoost);


%% ============================================================
% 22. DL WIN COUNT
% =============================================================

dlR2Wins = sum(R2_DL > R2_LSBoost);

dlRMSEWins = sum(RMSE_DL < RMSE_LSBoost);

dlMAEWins = sum(MAE_DL < MAE_LSBoost);


fprintf('\n');
fprintf('=============================================\n');
fprintf('        DL WIN COUNT ACROSS FOLDS\n');
fprintf('=============================================\n\n');

fprintf('R^2   : %d / %d folds\n', ...
    dlR2Wins, numFolds);

fprintf('RMSE  : %d / %d folds\n', ...
    dlRMSEWins, numFolds);

fprintf('MAE   : %d / %d folds\n', ...
    dlMAEWins, numFolds);


%% ============================================================
% 23. FOLD-BY-FOLD TABLE
% =============================================================

foldResults = table( ...
    (1:numFolds)', ...
    R2_LSBoost, ...
    RMSE_LSBoost, ...
    MAE_LSBoost, ...
    R2_DL, ...
    RMSE_DL, ...
    MAE_DL, ...
    'VariableNames', { ...
    'Fold', ...
    'R2_LSBoost', ...
    'RMSE_LSBoost', ...
    'MAE_LSBoost', ...
    'R2_DL', ...
    'RMSE_DL', ...
    'MAE_DL'});


disp(foldResults);


%% ============================================================
% 24. MODEL COMPARISON PLOT
% =============================================================

figure( ...
    'Name', ...
    '5-Fold CV Model Comparison', ...
    'Color', ...
    'w');


subplot(1,3,1);

bar([R2_LSBoost R2_DL]);

xlabel('Fold');

ylabel('R^2');

title('R^2 Across Folds');

legend( ...
    'LSBoost', ...
    'Deep Learning', ...
    'Location','best');

grid on;


subplot(1,3,2);

bar([RMSE_LSBoost RMSE_DL]);

xlabel('Fold');

ylabel('RMSE (dB)');

title('RMSE Across Folds');

legend( ...
    'LSBoost', ...
    'Deep Learning', ...
    'Location','best');

grid on;


subplot(1,3,3);

bar([MAE_LSBoost MAE_DL]);

xlabel('Fold');

ylabel('MAE (dB)');

title('MAE Across Folds');

legend( ...
    'LSBoost', ...
    'Deep Learning', ...
    'Location','best');

grid on;


saveas( ...
    gcf, ...
    fullfile( ...
    resultDir, ...
    '5Fold_CV_Model_Comparison.png'));


%% ============================================================
% 25. SAVE RESULTS
% =============================================================

resultFile = fullfile( ...
    resultDir, ...
    '5Fold_CV_Results.mat');


save( ...
    resultFile, ...
    'foldResults', ...
    'R2_DL', ...
    'RMSE_DL', ...
    'MAE_DL', ...
    'R2_LSBoost', ...
    'RMSE_LSBoost', ...
    'MAE_LSBoost', ...
    'Pearson_DL', ...
    'Spearman_DL', ...
    'Pearson_LSBoost', ...
    'Spearman_LSBoost', ...
    'mean_R2_DL', ...
    'std_R2_DL', ...
    'mean_RMSE_DL', ...
    'std_RMSE_DL', ...
    'mean_MAE_DL', ...
    'std_MAE_DL', ...
    'mean_R2_LSBoost', ...
    'std_R2_LSBoost', ...
    'mean_RMSE_LSBoost', ...
    'std_RMSE_LSBoost', ...
    'mean_MAE_LSBoost', ...
    'std_MAE_LSBoost');


%% ============================================================
% 26. FINAL MESSAGE
% =============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       5-FOLD CV COMPLETED\n');
fprintf('=============================================\n\n');

fprintf('Results saved to:\n%s\n\n', ...
    resultFile);

fprintf('Plot saved to:\n%s\n\n', ...
    fullfile( ...
    resultDir, ...
    '5Fold_CV_Model_Comparison.png'));

fprintf('Final DL result:\n');

fprintf('R^2   = %.4f +/- %.4f\n', ...
    mean_R2_DL, std_R2_DL);

fprintf('RMSE  = %.4f +/- %.4f dB\n', ...
    mean_RMSE_DL, std_RMSE_DL);

fprintf('MAE   = %.4f +/- %.4f dB\n', ...
    mean_MAE_DL, std_MAE_DL);

fprintf('\nFinal LSBoost result:\n');

fprintf('R^2   = %.4f +/- %.4f\n', ...
    mean_R2_LSBoost, std_R2_LSBoost);

fprintf('RMSE  = %.4f +/- %.4f dB\n', ...
    mean_RMSE_LSBoost, std_RMSE_LSBoost);

fprintf('MAE   = %.4f +/- %.4f dB\n', ...
    mean_MAE_LSBoost, std_MAE_LSBoost);

fprintf('\n=============================================\n');
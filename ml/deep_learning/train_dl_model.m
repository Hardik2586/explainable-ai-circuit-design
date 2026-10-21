%% train_dl_model.m
% CE Amplifier Deep Learning Regression Model
% MATLAB R2025b
% Deep Learning Toolbox
%
% Architecture:
% 9 -> 64 -> 32 -> 16 -> 1
%
% Dataset:
% 660 valid CE amplifier circuits
%
% Split:
% 422 training
% 106 validation
% 132 final test

clear;
clc;
close all;

fprintf('=============================================\n');
fprintf('   CE AMPLIFIER - DL MODEL TRAINING\n');
fprintf('=============================================\n\n');


%% ============================================================
% 1. PROJECT PATHS
% ============================================================

scriptDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(fileparts(scriptDir));

dataFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Dataset.mat');

modelDir = fullfile( ...
    projectRoot, ...
    'models', ...
    'deep_learning');

resultDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning');

if ~exist(modelDir, 'dir')
    mkdir(modelDir);
end

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end


%% ============================================================
% 2. LOAD PREPARED DATA
% ============================================================

if ~isfile(dataFile)
    error(['DL_Dataset.mat was not found.\n\n' ...
        'Run prepare_dl_data.m first.']);
end

fprintf('Loading prepared dataset:\n%s\n\n', dataFile);

load(dataFile);

fprintf('Prepared dataset loaded successfully.\n\n');


%% ============================================================
% 3. VERIFY DATA
% ============================================================

requiredVariables = { ...
    'X_train_norm', ...
    'X_test_norm', ...
    'Y_train', ...
    'Y_test', ...
    'featureNames', ...
    'targetName'};

for k = 1:numel(requiredVariables)

    if ~exist(requiredVariables{k}, 'var')

        error( ...
            'Variable "%s" is missing from DL_Dataset.mat.', ...
            requiredVariables{k});

    end

end


fprintf('Development input size : %d x %d\n', ...
    size(X_train_norm,1), size(X_train_norm,2));

fprintf('Development target size: %d x %d\n', ...
    size(Y_train,1), size(Y_train,2));

fprintf('Final test input size  : %d x %d\n', ...
    size(X_test_norm,1), size(X_test_norm,2));

fprintf('Final test target size : %d x %d\n\n', ...
    size(Y_test,1), size(Y_test,2));


%% ============================================================
% 4. TRAIN / VALIDATION SPLIT
% ============================================================

rng(42, 'twister');

NDevelopment = size(X_train_norm,1);

cv = cvpartition(NDevelopment, ...
    'HoldOut',0.20);

idxTrain = training(cv);
idxValidation = test(cv);


XTrain = X_train_norm(idxTrain,:);
YTrain = Y_train(idxTrain);

XValidation = X_train_norm(idxValidation,:);
YValidation = Y_train(idxValidation);

XTest = X_test_norm;
YTest = Y_test;


fprintf('=============================================\n');
fprintf('DL DATA SPLIT\n');
fprintf('=============================================\n');

fprintf('Training samples   : %d\n', size(XTrain,1));
fprintf('Validation samples : %d\n', size(XValidation,1));
fprintf('Final test samples : %d\n\n', size(XTest,1));


%% ============================================================
% 5. CONVERT TO SINGLE PRECISION
% ============================================================

XTrain = single(XTrain);
YTrain = single(YTrain);

XValidation = single(XValidation);
YValidation = single(YValidation);

XTest = single(XTest);
YTest = single(YTest);


%% ============================================================
% 6. DEFINE NETWORK
% ============================================================

numFeatures = size(XTrain,2);

fprintf('=============================================\n');
fprintf('NETWORK ARCHITECTURE\n');
fprintf('=============================================\n');

fprintf('%d -> 64 -> 32 -> 16 -> 1\n\n', numFeatures);


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

fprintf('Network initialized successfully.\n\n');

%% ============================================================
% 8. TRAINING OPTIONS
% ============================================================

options = trainingOptions( ...
    "adam", ...
    MaxEpochs=300, ...
    MiniBatchSize=32, ...
    InitialLearnRate=1e-3, ...
    Shuffle="every-epoch", ...
    ValidationData={XValidation,YValidation}, ...
    ValidationFrequency=10, ...
    ValidationPatience=30, ...
    Verbose=true, ...
    Plots="training-progress");


%% ============================================================
% 9. TRAIN NETWORK
% ============================================================

fprintf('=============================================\n');
fprintf('STARTING DEEP LEARNING TRAINING\n');
fprintf('=============================================\n\n');

[net, trainInfo] = trainnet( ...
    XTrain, ...
    YTrain, ...
    layers, ...
    "mse", ...
    options);


fprintf('\nTraining completed successfully.\n\n');


%% ============================================================
% 10. PREDICTIONS
% ============================================================

fprintf('Generating predictions...\n');

YPredTrain = predict(net,XTrain);

YPredValidation = predict(net,XValidation);

YPredTest = predict(net,XTest);


%% ============================================================
% 11. CONVERT TO DOUBLE
% ============================================================

YPredTrain = double(YPredTrain);
YPredValidation = double(YPredValidation);
YPredTest = double(YPredTest);

YTrain = double(YTrain);
YValidation = double(YValidation);
YTest = double(YTest);


%% ============================================================
% 12. TRAINING METRICS
% ============================================================

errorTrain = YPredTrain - YTrain;

MAE_train = mean(abs(errorTrain));

RMSE_train = sqrt(mean(errorTrain.^2));

R2_train = 1 - ...
    sum(errorTrain.^2) / ...
    sum((YTrain - mean(YTrain)).^2);


%% ============================================================
% 13. VALIDATION METRICS
% ============================================================

errorValidation = ...
    YPredValidation - YValidation;

MAE_validation = ...
    mean(abs(errorValidation));

RMSE_validation = ...
    sqrt(mean(errorValidation.^2));

R2_validation = 1 - ...
    sum(errorValidation.^2) / ...
    sum((YValidation - mean(YValidation)).^2);


%% ============================================================
% 14. FINAL TEST METRICS
% ============================================================

errorTest = YPredTest - YTest;

MAE_test = mean(abs(errorTest));

RMSE_test = sqrt(mean(errorTest.^2));

R2_test = 1 - ...
    sum(errorTest.^2) / ...
    sum((YTest - mean(YTest)).^2);


%% ============================================================
% 15. DISPLAY RESULTS
% ============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       DL MODEL PERFORMANCE\n');
fprintf('=============================================\n\n');

fprintf('TRAINING SET\n');
fprintf('R^2   = %.4f\n',R2_train);
fprintf('RMSE  = %.4f dB\n',RMSE_train);
fprintf('MAE   = %.4f dB\n\n',MAE_train);

fprintf('VALIDATION SET\n');
fprintf('R^2   = %.4f\n',R2_validation);
fprintf('RMSE  = %.4f dB\n',RMSE_validation);
fprintf('MAE   = %.4f dB\n\n',MAE_validation);

fprintf('FINAL TEST SET\n');
fprintf('R^2   = %.4f\n',R2_test);
fprintf('RMSE  = %.4f dB\n',RMSE_test);
fprintf('MAE   = %.4f dB\n\n',MAE_test);


%% ============================================================
% 16. SAVE MODEL
% ============================================================

modelFile = fullfile( ...
    modelDir, ...
    'CE_Gain_DL_Model.mat');

save(modelFile, ...
    'net', ...
    'trainInfo', ...
    'featureNames', ...
    'targetName', ...
    'R2_train', ...
    'RMSE_train', ...
    'MAE_train', ...
    'R2_validation', ...
    'RMSE_validation', ...
    'MAE_validation', ...
    'R2_test', ...
    'RMSE_test', ...
    'MAE_test');


%% ============================================================
% 17. SAVE RESULTS
% ============================================================

resultFile = fullfile( ...
    resultDir, ...
    'DL_Training_Results.mat');

save(resultFile, ...
    'YPredTrain', ...
    'YPredValidation', ...
    'YPredTest', ...
    'YTrain', ...
    'YValidation', ...
    'YTest', ...
    'R2_train', ...
    'RMSE_train', ...
    'MAE_train', ...
    'R2_validation', ...
    'RMSE_validation', ...
    'MAE_validation', ...
    'R2_test', ...
    'RMSE_test', ...
    'MAE_test', ...
    'trainInfo');


%% ============================================================
% 18. SAVE DATA SPLIT
% ============================================================

splitFile = fullfile( ...
    resultDir, ...
    'DL_Data_Split.mat');

save(splitFile, ...
    'idxTrain', ...
    'idxValidation');


%% ============================================================
% 19. FINAL MESSAGE
% ============================================================

fprintf('=============================================\n');
fprintf('       DL TRAINING COMPLETED\n');
fprintf('=============================================\n\n');

fprintf('Model saved:\n%s\n\n',modelFile);

fprintf('Results saved:\n%s\n\n',resultFile);

fprintf('Final TEST performance:\n');
fprintf('R^2   = %.4f\n',R2_test);
fprintf('RMSE  = %.4f dB\n',RMSE_test);
fprintf('MAE   = %.4f dB\n',MAE_test);

fprintf('\n=============================================\n');
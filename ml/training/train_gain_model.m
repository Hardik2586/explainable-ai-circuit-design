%% train_gain_model_log.m
% Gain surrogate using logarithmic transformation of
% positive circuit component values.

clear;
clc;
close all;

%% Paths
project_dir = fileparts(fileparts(mfilename('fullpath')));

data_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');

%% Load data
Dataset = readtable(data_file);

fprintf('Samples: %d\n', height(Dataset));

%% Original parameters
Features = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};

%% Construct transformed feature matrix
X = zeros(height(Dataset), numel(Features));

% Log-transform all resistance/capacitance parameters
LogFeatures = { ...
    'R1','R2','RC','RE','RL','Cin','Cout','Ce'};

for k = 1:numel(LogFeatures)
    X(:,k) = log10(Dataset.(LogFeatures{k}));
end

% Keep supply voltage linear
X(:,9) = Dataset.VCC;

Y = Dataset.Gain_dB;

%% Reproducibility
rng(42);

%% Train/test split
cv = cvpartition(height(Dataset), ...
    'HoldOut', 0.20);

train_idx = training(cv);
test_idx  = test(cv);

X_train = X(train_idx,:);
Y_train = Y(train_idx);

X_test = X(test_idx,:);
Y_test = Y(test_idx);

fprintf('\nTraining samples: %d\n', size(X_train,1));
fprintf('Testing samples : %d\n', size(X_test,1));

%% Train ensemble
fprintf('\nTraining log-feature Random Forest...\n');

NumTrees = 500;

model = TreeBagger( ...
    NumTrees, ...
    X_train, ...
    Y_train, ...
    'Method','regression', ...
    'OOBPrediction','On', ...
    'OOBPredictorImportance','On', ...
    'MinLeafSize',2);

fprintf('Training complete.\n');

%% Predictions
Y_pred_train = double(predict(model,X_train));
Y_pred_test  = double(predict(model,X_test));

%% Metrics
R2_train = 1 - ...
    sum((Y_train-Y_pred_train).^2) / ...
    sum((Y_train-mean(Y_train)).^2);

R2_test = 1 - ...
    sum((Y_test-Y_pred_test).^2) / ...
    sum((Y_test-mean(Y_test)).^2);

MAE_train = mean(abs(Y_train-Y_pred_train));
MAE_test  = mean(abs(Y_test-Y_pred_test));

RMSE_train = sqrt(mean((Y_train-Y_pred_train).^2));
RMSE_test  = sqrt(mean((Y_test-Y_pred_test).^2));

%% Results
fprintf('\n====================================\n');
fprintf('LOG-FEATURE GAIN MODEL\n');
fprintf('====================================\n');

fprintf('\nTraining:\n');
fprintf('R2   = %.4f\n',R2_train);
fprintf('MAE  = %.4f dB\n',MAE_train);
fprintf('RMSE = %.4f dB\n',RMSE_train);

fprintf('\nTesting:\n');
fprintf('R2   = %.4f\n',R2_test);
fprintf('MAE  = %.4f dB\n',MAE_test);
fprintf('RMSE = %.4f dB\n',RMSE_test);

%% Feature importance
Importance = model.OOBPermutedPredictorDeltaError;

figure;

bar(Importance);

xticks(1:numel(Features));
xticklabels(Features);
xtickangle(45);

ylabel('Permutation Importance');
title('Feature Importance - Log-Feature Gain Model');

grid on;

%% Actual vs predicted
figure;

scatter(Y_test,Y_pred_test,35,'filled');
hold on;

min_val = min([Y_test;Y_pred_test]);
max_val = max([Y_test;Y_pred_test]);

plot( ...
    [min_val max_val], ...
    [min_val max_val], ...
    'k--', ...
    'LineWidth',1.5);

xlabel('SPICE Gain (dB)');
ylabel('Predicted Gain (dB)');

title(sprintf( ...
    'Log-Feature Gain Model: R^2 = %.3f, RMSE = %.3f dB', ...
    R2_test,RMSE_test));

grid on;

%% Residual plot
Residuals = Y_test-Y_pred_test;

figure;

scatter(Y_pred_test,Residuals,35,'filled');
hold on;

yline(0,'k--','LineWidth',1.5);

xlabel('Predicted Gain (dB)');
ylabel('Residual (SPICE - Prediction) (dB)');

title('Log-Feature Gain Model Residuals');

grid on;

%% Save model
model_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_RF_Log_Model.mat');

save(model_file, ...
    'model', ...
    'Features', ...
    'R2_train', ...
    'R2_test', ...
    'MAE_train', ...
    'MAE_test', ...
    'RMSE_train', ...
    'RMSE_test');

fprintf('\nModel saved:\n%s\n',model_file);
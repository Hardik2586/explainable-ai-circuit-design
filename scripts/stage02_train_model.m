%% stage02_train_model.m
% Stage 2: Train the canonical gradient boosted ensemble model.
%
% Algorithm: fitrensemble with LSBoost, 300 trees
% Features:  log10(R1,R2,RC,RE,RL,Cin,Cout,Ce), VCC (linear)
% Target:    Gain_dB
%
% This script:
%   1. Loads the canonical 660-row dataset
%   2. Constructs log-transformed feature matrix
%   3. Creates a reproducible 80/20 train/test split (rng 42)
%   4. Trains an LSBoost ensemble with 300 trees
%   5. Reports separate training vs test metrics
%   6. Saves the model to models/ml/Gain_Boosted_Model.mat

clear; clc; close all;
fprintf('\n============================================================\n');
fprintf('  STAGE 2: ML MODEL TRAINING\n');
fprintf('============================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load dataset
dataset_path = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
T = readtable(dataset_path);
fprintf('Dataset: %d samples\n', height(T));

%% 2. Feature engineering
Features = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
LogFeatures = {'R1','R2','RC','RE','RL','Cin','Cout','Ce'};

X = zeros(height(T), 9);
for k = 1:numel(LogFeatures)
    X(:,k) = log10(T.(LogFeatures{k}));
end
X(:,9) = T.VCC;
Y = T.Gain_dB;

%% 3. Reproducible train/test split
rng(42);
cv = cvpartition(height(T), 'HoldOut', 0.20);
train_idx = training(cv);
test_idx  = test(cv);

X_train = X(train_idx,:);  Y_train = Y(train_idx);
X_test  = X(test_idx,:);   Y_test  = Y(test_idx);

fprintf('Training samples: %d\n', sum(train_idx));
fprintf('Testing samples:  %d\n', sum(test_idx));

%% 4. Train gradient boosted ensemble
fprintf('\nTraining LSBoost ensemble (300 trees)...\n');

TreeTemplate = templateTree('MaxNumSplits', 20, 'MinLeafSize', 8);

model = fitrensemble(X_train, Y_train, ...
    'Method',             'LSBoost', ...
    'NumLearningCycles',  300, ...
    'Learners',           TreeTemplate, ...
    'LearnRate',          0.03);

fprintf('Training complete.\n');

%% 5. Evaluate
Y_pred_train = predict(model, X_train);
Y_pred_test  = predict(model, X_test);
Y_pred_all   = predict(model, X);

% Training metrics
R2_train   = 1 - sum((Y_train - Y_pred_train).^2) / sum((Y_train - mean(Y_train)).^2);
RMSE_train = sqrt(mean((Y_train - Y_pred_train).^2));
MAE_train  = mean(abs(Y_train - Y_pred_train));

% Test metrics (generalization)
R2_test   = 1 - sum((Y_test - Y_pred_test).^2) / sum((Y_test - mean(Y_test)).^2);
RMSE_test = sqrt(mean((Y_test - Y_pred_test).^2));
MAE_test  = mean(abs(Y_test - Y_pred_test));

% Full-dataset fit (apparent fit, NOT generalization)
R2_full   = 1 - sum((Y - Y_pred_all).^2) / sum((Y - mean(Y)).^2);
RMSE_full = sqrt(mean((Y - Y_pred_all).^2));
MAE_full  = mean(abs(Y - Y_pred_all));

fprintf('\n--- Training Metrics ---\n');
fprintf('  R2   = %.4f\n', R2_train);
fprintf('  RMSE = %.4f dB\n', RMSE_train);
fprintf('  MAE  = %.4f dB\n', MAE_train);

fprintf('\n--- Held-out Test Metrics (GENERALIZATION) ---\n');
fprintf('  R2   = %.4f\n', R2_test);
fprintf('  RMSE = %.4f dB\n', RMSE_test);
fprintf('  MAE  = %.4f dB\n', MAE_test);

fprintf('\n--- Full-Dataset Apparent Fit (NOT generalization) ---\n');
fprintf('  R2   = %.4f\n', R2_full);
fprintf('  RMSE = %.4f dB\n', RMSE_full);
fprintf('  MAE  = %.4f dB\n', MAE_full);

%% 6. Save model
model_path = fullfile(root_dir, 'models', 'ml', 'Gain_Boosted_Model.mat');
save(model_path, 'model', 'Features', 'LogFeatures', ...
    'R2_train', 'RMSE_train', 'MAE_train', ...
    'R2_test',  'RMSE_test',  'MAE_test', ...
    'R2_full',  'RMSE_full',  'MAE_full');

fprintf('\nModel saved: %s\n', model_path);
fprintf('\n>>> MODEL TRAINING COMPLETE <<<\n');

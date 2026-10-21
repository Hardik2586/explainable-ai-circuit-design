%% test_ml_model.m
% Verification script for ML model loading and predictions
% clear; clc;

root_dir = setup_project_paths();
model_path = fullfile(root_dir, 'ml', 'models', 'Gain_Boosted_Model.mat');
dataset_path = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');

fprintf('========================================\n');
fprintf('ML MODEL VERIFICATION TEST\n');
fprintf('========================================\n');

assert(isfile(model_path), 'Canonical model file not found at: %s', model_path);
assert(isfile(dataset_path), 'Dataset file not found at: %s', dataset_path);

M = load(model_path);
assert(isfield(M, 'model'), 'Loaded MAT file does not contain variable "model"');
model = M.model;

fprintf('Model Class: %s\n', class(model));
assert(isa(model, 'classreg.learning.regr.RegressionEnsemble'), 'Unexpected model type');

% Load dataset and create test sample
tbl = readtable(dataset_path);
X = zeros(height(tbl), 9);
LogFeatures = {'R1','R2','RC','RE','RL','Cin','Cout','Ce'};
for k = 1:numel(LogFeatures)
    X(:,k) = log10(tbl.(LogFeatures{k}));
end
X(:,9) = tbl.VCC;
Y_actual = tbl.Gain_dB;

% Predict
Y_pred = predict(model, X);

assert(length(Y_pred) == height(tbl), 'Prediction output dimension mismatch');
assert(all(isfinite(Y_pred)), 'Predictions contain non-finite values');

% Evaluate metrics
ss_tot = sum((Y_actual - mean(Y_actual)).^2);
ss_res = sum((Y_actual - Y_pred).^2);
R2_full = 1 - (ss_res / ss_tot);
RMSE_full = sqrt(mean((Y_actual - Y_pred).^2));
MAE_full = mean(abs(Y_actual - Y_pred));

fprintf('Full Dataset Fit Metrics:\n');
fprintf('  R2   = %.4f (Expected ~0.9597)\n', R2_full);
fprintf('  RMSE = %.4f dB (Expected ~1.4431 dB)\n', RMSE_full);
fprintf('  MAE  = %.4f dB (Expected ~0.8086 dB)\n', MAE_full);

if isfield(M, 'R2_test') && isfield(M, 'RMSE_test')
    fprintf('Saved Generalization Metrics:\n');
    fprintf('  Held-out Test R2   = %.4f\n', M.R2_test);
    fprintf('  Held-out Test RMSE = %.4f dB\n', M.RMSE_test);
end

fprintf('>>> ML MODEL VERIFICATION PASSED SUCCESSFULLY! <<<\n\n');

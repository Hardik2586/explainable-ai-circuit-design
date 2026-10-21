%% stage03_evaluate_model.m
% Stage 3: 5-fold cross-validation of the trained model.
%
% Uses MATLAB built-in fitrensemble with KFold to compute
% cross-validated predictions and generalization metrics.

clear; clc; close all;
fprintf('\n============================================================\n');
fprintf('  STAGE 3: MODEL EVALUATION (5-FOLD CV)\n');
fprintf('============================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load dataset
T = readtable(fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv'));

LogFeatures = {'R1','R2','RC','RE','RL','Cin','Cout','Ce'};
X = zeros(height(T), 9);
for k = 1:numel(LogFeatures)
    X(:,k) = log10(T.(LogFeatures{k}));
end
X(:,9) = T.VCC;
Y = T.Gain_dB;

%% 2. 5-fold cross-validation
rng(42);
fprintf('Training 5-fold cross-validated model...\n');

TreeTemplate = templateTree('MaxNumSplits', 20, 'MinLeafSize', 8);
CVModel = fitrensemble(X, Y, ...
    'Method',            'LSBoost', ...
    'NumLearningCycles', 300, ...
    'Learners',          TreeTemplate, ...
    'LearnRate',         0.03, ...
    'KFold',             5);

%% 3. Compute CV metrics
Y_CV    = kfoldPredict(CVModel);
CV_MSE  = kfoldLoss(CVModel);
CV_RMSE = sqrt(CV_MSE);
R2_CV   = 1 - sum((Y - Y_CV).^2) / sum((Y - mean(Y)).^2);
MAE_CV  = mean(abs(Y - Y_CV));

fprintf('\n--- 5-Fold Cross-Validation Results ---\n');
fprintf('  R2   = %.4f\n', R2_CV);
fprintf('  RMSE = %.4f dB\n', CV_RMSE);
fprintf('  MAE  = %.4f dB\n', MAE_CV);

%% 4. Save
results_file = fullfile(root_dir, 'results', 'ml', 'CV_Results.mat');
save(results_file, 'CVModel', 'R2_CV', 'CV_RMSE', 'MAE_CV', 'Y', 'Y_CV');
fprintf('\nSaved: %s\n', results_file);
fprintf('\n>>> MODEL EVALUATION COMPLETE <<<\n');

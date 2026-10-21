%% validate_gain_model.m
% 5-fold cross-validation for the CE amplifier gain surrogate

clear;
clc;
close all;

%% Paths
project_dir = fileparts(fileparts(mfilename('fullpath')));

data_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');

Dataset = readtable(data_file);

%% Features
LogFeatures = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce'};

X = zeros(height(Dataset),9);

for k = 1:numel(LogFeatures)
    X(:,k) = log10(Dataset.(LogFeatures{k}));
end

X(:,9) = Dataset.VCC;

Y = Dataset.Gain_dB;

%% Reproducibility
rng(42);

%% Tree configuration
TreeTemplate = templateTree( ...
    'MaxNumSplits',20, ...
    'MinLeafSize',8);

%% 5-fold cross-validation
fprintf('Training 5-fold cross-validated model...\n');

CVModel = fitrensemble( ...
    X, ...
    Y, ...
    'Method','LSBoost', ...
    'NumLearningCycles',300, ...
    'Learners',TreeTemplate, ...
    'LearnRate',0.03, ...
    'KFold',5);

fprintf('Cross-validation complete.\n');

%% Cross-validated loss
CV_MSE = kfoldLoss(CVModel);

CV_RMSE = sqrt(CV_MSE);

fprintf('\n====================================\n');
fprintf('5-FOLD CROSS-VALIDATION\n');
fprintf('====================================\n');

fprintf('Cross-validated MSE  = %.4f\n',CV_MSE);
fprintf('Cross-validated RMSE = %.4f dB\n',CV_RMSE);

%% Cross-validated predictions
Y_CV = kfoldPredict(CVModel);

%% Overall R2
R2_CV = 1 - ...
    sum((Y-Y_CV).^2) / ...
    sum((Y-mean(Y)).^2);

MAE_CV = mean(abs(Y-Y_CV));

fprintf('Cross-validated R2   = %.4f\n',R2_CV);
fprintf('Cross-validated MAE  = %.4f dB\n',MAE_CV);

%% Prediction plot
figure;

scatter(Y,Y_CV,35,'filled');
hold on;

min_val = min([Y;Y_CV]);
max_val = max([Y;Y_CV]);

plot( ...
    [min_val max_val], ...
    [min_val max_val], ...
    'k--', ...
    'LineWidth',1.5);

xlabel('SPICE Gain (dB)');
ylabel('Cross-validated Predicted Gain (dB)');

title(sprintf( ...
    '5-Fold Cross-Validation: R^2 = %.3f, RMSE = %.3f dB', ...
    R2_CV,CV_RMSE));

grid on;

%% Residuals
Residuals = Y-Y_CV;

figure;

scatter(Y_CV,Residuals,35,'filled');
hold on;

yline(0,'k--','LineWidth',1.5);

xlabel('Cross-validated Predicted Gain (dB)');
ylabel('Residual (SPICE - Prediction) (dB)');

title('5-Fold Cross-Validated Residuals');

grid on;

%% Save validation results
results_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_Model_CV_Results.mat');

save(results_file, ...
    'CVModel', ...
    'R2_CV', ...
    'CV_RMSE', ...
    'MAE_CV', ...
    'Y', ...
    'Y_CV');

fprintf('\nResults saved:\n%s\n',results_file);
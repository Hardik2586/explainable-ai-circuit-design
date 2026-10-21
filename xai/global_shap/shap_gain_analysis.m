
clear;
clc;
close all;

%% Paths
project_dir = fileparts(fileparts(mfilename('fullpath')));

data_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');

model_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_Boosted_Model.mat');

%% Load data
Dataset = readtable(data_file);

%% Feature definitions
Features = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

LogFeatures = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce'};

%% Construct transformed input matrix
X = zeros(height(Dataset),9);

for k = 1:numel(LogFeatures)
    X(:,k) = log10(Dataset.(LogFeatures{k}));
end

X(:,9) = Dataset.VCC;

Y = Dataset.Gain_dB;

%% Recreate exactly the same train/test split
rng(42);

cv = cvpartition(height(Dataset),'HoldOut',0.20);

train_idx = training(cv);
test_idx  = test(cv);

X_train = X(train_idx,:);
Y_train = Y(train_idx);

X_test = X(test_idx,:);
Y_test = Y(test_idx);

fprintf('Training samples: %d\n',size(X_train,1));
fprintf('Testing samples : %d\n',size(X_test,1));

%% Load trained model
S = load(model_file);

model = S.model;

fprintf('\nLoaded model:\n');
disp(model);

%% Verify test predictions
Y_pred_test = predict(model,X_test);

R2_test = 1 - ...
    sum((Y_test-Y_pred_test).^2) / ...
    sum((Y_test-mean(Y_test)).^2);

RMSE_test = sqrt(mean((Y_test-Y_pred_test).^2));

fprintf('\nModel verification:\n');
fprintf('Test R2   = %.4f\n',R2_test);
fprintf('Test RMSE = %.4f dB\n',RMSE_test);

%% ============================================================
% SHAP
% =============================================================

fprintf('\nCreating SHAP explainer...\n');

explainer = shapley( ...
    model, ...
    X_train, ...
    QueryPoints=X_test, ...
    NumObservationsToSample="all");

fprintf('SHAP calculation complete.\n');

%% Display global SHAP importance
fprintf('\n====================================\n');
fprintf('GLOBAL SHAP IMPORTANCE\n');
fprintf('====================================\n');

MeanAbsSHAP = explainer.MeanAbsoluteShapley;

disp(MeanAbsSHAP);

%% Extract values
PredictorNames = string(MeanAbsSHAP.Predictor);
SHAPValues = MeanAbsSHAP{:,2};

%% Sort descending
[SHAPValuesSorted,idx] = sort(SHAPValues,'descend');

PredictorNamesSorted = PredictorNames(idx);

%% Display ranking
fprintf('\nSHAP Ranking:\n');

for k = 1:numel(PredictorNamesSorted)

    fprintf( ...
        '%d. %-5s : %.4f dB\n', ...
        k, ...
        PredictorNamesSorted(k), ...
        SHAPValuesSorted(k));

end

%% ============================================================
% Global SHAP bar chart
% =============================================================

figure;

barh(SHAPValuesSorted);

yticks(1:numel(PredictorNamesSorted));
yticklabels(PredictorNamesSorted);

set(gca,'YDir','reverse');

xlabel('Mean Absolute SHAP Value (dB)');
ylabel('Circuit Parameter');

title('Global SHAP Importance - CE Amplifier Gain');

grid on;

%% ============================================================
% MATLAB built-in SHAP plot
% =============================================================

figure;

plot(explainer);

title('SHAP Explanation - CE Amplifier Gain');

%% ============================================================
% Save SHAP results
% =============================================================

SHAPResults = table( ...
    PredictorNamesSorted, ...
    SHAPValuesSorted, ...
    'VariableNames', ...
    {'Parameter','MeanAbsoluteSHAP'});

output_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_SHAP_Results.mat');

csv_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_SHAP_Importance.csv');

save(output_file, ...
    'explainer', ...
    'SHAPResults', ...
    'PredictorNamesSorted', ...
    'SHAPValuesSorted');

writetable(SHAPResults,csv_file);

fprintf('\nSHAP results saved:\n');
fprintf('%s\n',output_file);
fprintf('%s\n',csv_file);
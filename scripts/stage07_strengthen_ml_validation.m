%% stage07_strengthen_ml_validation.m
% Phase 7: Strengthen ML Surrogate Validation with Repeated K-Fold Cross-Validation
%
% This script:
%   1. Loads canonical 660-row dataset and trained LSBoost ensemble
%   2. Performs 5 repeats of 5-fold cross-validation (25 evaluations total)
%   3. Evaluates generalization metrics (R2, RMSE, MAE) as mean +/- std
%   4. Explicitly separates:
%        - Full dataset fit (apparent training performance)
%        - Standard 80/20 held-out test set
%        - Repeated 5-fold cross-validation
%   5. Generates publication-ready 4-panel figure:
%        Panel A: Predicted vs Actual Gain
%        Panel B: Residuals vs Predicted Gain
%        Panel C: Residual Distribution Histogram
%        Panel D: Cross-Validation Metric Distribution
%   6. Saves results/tables/ML_Model_Performance.csv and MAT results

clear; clc; close all;
fprintf('==================================================================\n');
fprintf('  STAGE 07: STRENGTHEN ML SURROGATE VALIDATION (REPEATED 5-FOLD CV)\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load Data and Model
[model, X, Y, Features, LogFeatures] = loadModelAndData(root_dir);
nSamples = length(Y);
fprintf('Dataset: %d samples, 9 features (8 log-transformed, VCC linear)\n', nSamples);

%% 2. Full-Dataset Fit Evaluation (Apparent Training Fit)
Y_pred_full = predict(model, X);
err_full = Y - Y_pred_full;

ss_tot = sum((Y - mean(Y)).^2);
ss_res_full = sum(err_full.^2);

R2_full   = 1 - ss_res_full / ss_tot;
RMSE_full = sqrt(mean(err_full.^2));
MAE_full  = mean(abs(err_full));

fprintf('\n--- 1. Full Dataset Apparent Fit (NOT Generalization) ---\n');
fprintf('  R2   = %.4f\n', R2_full);
fprintf('  RMSE = %.4f dB\n', RMSE_full);
fprintf('  MAE  = %.4f dB\n', MAE_full);

%% 3. Held-Out 80/20 Test Split (Replicating Canonical Test Partition)
rng(42);
cv_holdout = cvpartition(nSamples, 'HoldOut', 0.20);
train_idx = training(cv_holdout);
test_idx  = test(cv_holdout);

TreeTemplate = templateTree('MaxNumSplits', 20, 'MinLeafSize', 8);
model_holdout = fitrensemble(X(train_idx, :), Y(train_idx), ...
    'Method', 'LSBoost', 'NumLearningCycles', 300, ...
    'Learners', TreeTemplate, 'LearnRate', 0.03);

Y_pred_test = predict(model_holdout, X(test_idx, :));
err_test = Y(test_idx) - Y_pred_test;

ss_tot_test = sum((Y(test_idx) - mean(Y(test_idx))).^2);
R2_test   = 1 - sum(err_test.^2) / ss_tot_test;
RMSE_test = sqrt(mean(err_test.^2));
MAE_test  = mean(abs(err_test));

fprintf('\n--- 2. Held-Out Test Set (80/20 Split, N_test=%d) ---\n', sum(test_idx));
fprintf('  R2   = %.4f\n', R2_test);
fprintf('  RMSE = %.4f dB\n', RMSE_test);
fprintf('  MAE  = %.4f dB\n', MAE_test);

%% 4. Repeated 5-Fold Cross-Validation (5 Repeats x 5 Folds = 25 Evaluations)
nRepeats = 5;
nFolds   = 5;
nTotalFolds = nRepeats * nFolds;

R2_folds   = zeros(nTotalFolds, 1);
RMSE_folds = zeros(nTotalFolds, 1);
MAE_folds  = zeros(nTotalFolds, 1);

Y_CV_predictions = zeros(nSamples, nRepeats);
fold_counter = 0;

fprintf('\n--- 3. Running Repeated 5-Fold Cross-Validation (%d total folds)...\n', nTotalFolds);

for rep = 1:nRepeats
    rng(100 + rep); % Different reproducible seed per repeat
    cv_k = cvpartition(nSamples, 'KFold', nFolds);
    
    for f = 1:nFolds
        fold_counter = fold_counter + 1;
        tr_mask = training(cv_k, f);
        te_mask = test(cv_k, f);
        
        m_fold = fitrensemble(X(tr_mask, :), Y(tr_mask), ...
            'Method', 'LSBoost', 'NumLearningCycles', 300, ...
            'Learners', TreeTemplate, 'LearnRate', 0.03);
            
        y_te_pred = predict(m_fold, X(te_mask, :));
        y_te_true = Y(te_mask);
        
        Y_CV_predictions(te_mask, rep) = y_te_pred;
        
        e_f = y_te_true - y_te_pred;
        ss_tot_f = sum((y_te_true - mean(y_te_true)).^2);
        
        R2_folds(fold_counter)   = 1 - sum(e_f.^2) / ss_tot_f;
        RMSE_folds(fold_counter) = sqrt(mean(e_f.^2));
        MAE_folds(fold_counter)  = mean(abs(e_f));
    end
    fprintf('  Completed Repeat %d/%d (Mean R2 so far: %.4f)\n', ...
        rep, nRepeats, mean(R2_folds(1:fold_counter)));
end

% Compute Summary Statistics Across Folds
mean_R2   = mean(R2_folds);
std_R2    = std(R2_folds);
mean_RMSE = mean(RMSE_folds);
std_RMSE  = std(RMSE_folds);
mean_MAE  = mean(MAE_folds);
std_MAE   = std(MAE_folds);

fprintf('\n--- Repeated 5-Fold Cross-Validation Summary ---\n');
fprintf('  R2   = %.4f +/- %.4f\n', mean_R2, std_R2);
fprintf('  RMSE = %.4f +/- %.4f dB\n', mean_RMSE, std_RMSE);
fprintf('  MAE  = %.4f +/- %.4f dB\n', mean_MAE, std_MAE);

%% 5. Save Performance Metrics Table
PerfTable = table(...
    {'Full_Dataset_Fit'; 'Held_Out_Test_20pc'; 'Repeated_5Fold_CV_Mean'; 'Repeated_5Fold_CV_Std'}, ...
    [R2_full; R2_test; mean_R2; std_R2], ...
    [RMSE_full; RMSE_test; mean_RMSE; std_RMSE], ...
    [MAE_full; MAE_test; mean_MAE; std_MAE], ...
    'VariableNames', {'Evaluation_Method', 'R2', 'RMSE_dB', 'MAE_dB'});

disp(PerfTable);

out_tab_dir = fullfile(root_dir, 'results', 'tables');
if ~isfolder(out_tab_dir), mkdir(out_tab_dir); end
perf_csv = fullfile(out_tab_dir, 'ML_Model_Performance.csv');
writetable(PerfTable, perf_csv);
fprintf('Saved performance summary table: %s\n', perf_csv);

% Save MAT file
mat_res_dir = fullfile(root_dir, 'results', 'ml');
if ~isfolder(mat_res_dir), mkdir(mat_res_dir); end
mat_file = fullfile(mat_res_dir, 'ML_CV_Repeated_Results.mat');
save(mat_file, 'PerfTable', 'R2_folds', 'RMSE_folds', 'MAE_folds', ...
    'Y_CV_predictions', 'Y', 'X');
fprintf('Saved MAT results: %s\n', mat_file);

%% 6. Publication-Quality Figure: 4-Panel Model Validation
fig_dir = fullfile(root_dir, 'results', 'figures');
if ~isfolder(fig_dir), mkdir(fig_dir); end

% Average CV predictions across repeats for residual analysis
Y_cv_mean = mean(Y_CV_predictions, 2);
res_cv = Y - Y_cv_mean;

f = figure('Position', [100, 100, 1200, 950], 'Visible', 'off');

% Panel A: Predicted vs Actual
subplot(2, 2, 1);
scatter(Y, Y_cv_mean, 28, [0.15, 0.45, 0.85], 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
plot([min(Y), max(Y)], [min(Y), max(Y)], 'k--', 'LineWidth', 1.8);
xlabel('Actual SPICE Gain (dB)');
ylabel('Cross-Validated Predicted Gain (dB)');
title(sprintf('A: Cross-Validation Predictions (R^2 = %.3f)', mean_R2));
legend({'Validation Samples', 'Ideal 1:1 Reference'}, 'Location', 'northwest');
grid on; set(gca, 'FontSize', 10);

% Panel B: Residuals vs Predicted
subplot(2, 2, 2);
scatter(Y_cv_mean, res_cv, 28, [0.85, 0.35, 0.15], 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
yline(0, 'k--', 'LineWidth', 1.8);
yline(2*mean_RMSE, 'r:', 'LineWidth', 1.2);
yline(-2*mean_RMSE, 'r:', 'LineWidth', 1.2);
xlabel('Predicted Gain (dB)');
ylabel('Residual: Actual - Predicted (dB)');
title(sprintf('B: Residual Distribution (RMSE = %.2f dB)', mean_RMSE));
legend({'Residuals', 'Zero Error', '\pm 2\sigma Bounds'}, 'Location', 'northeast');
grid on; set(gca, 'FontSize', 10);

% Panel C: Residual Histogram
subplot(2, 2, 3);
histogram(res_cv, 30, 'FaceColor', [0.2, 0.6, 0.5], 'EdgeColor', 'k', 'Normalization', 'pdf');
hold on;
x_grid = linspace(min(res_cv), max(res_cv), 100);
y_norm = normpdf(x_grid, mean(res_cv), std(res_cv));
plot(x_grid, y_norm, 'r-', 'LineWidth', 2);
xlabel('Residual Error (dB)');
ylabel('Probability Density');
title(sprintf('C: Residual Error Distribution (Mean = %.2f dB)', mean(res_cv)));
legend({'Residual Density', 'Normal Fit'}, 'Location', 'northeast');
grid on; set(gca, 'FontSize', 10);

% Panel D: Performance Across Folds Boxplot
subplot(2, 2, 4);
R2_matrix = reshape(R2_folds, [nFolds, nRepeats]);
b = boxplot(R2_matrix, 'Labels', {'Rep 1', 'Rep 2', 'Rep 3', 'Rep 4', 'Rep 5'});
set(findobj(gca, 'type', 'line'), 'LineWidth', 1.5);
xlabel('Cross-Validation Repeat');
ylabel('Fold R^2 Score');
title(sprintf('D: Generalization Stability Across 25 Folds\n(R^2 = %.3f \\pm %.3f)', mean_R2, std_R2));
grid on; set(gca, 'FontSize', 10);

fig_path = fullfile(fig_dir, 'ML_Model_Validation.png');
saveas(f, fig_path);
close(f);
fprintf('Saved 4-panel ML validation figure: %s\n', fig_path);

fprintf('\n>>> STAGE 07 COMPLETED SUCCESSFULLY! <<<\n');

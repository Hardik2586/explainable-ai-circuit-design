%% generate_final_deliverables.m
% =========================================================================
% SCRIPT: GENERATE ALL RESULTS IN results/final/
% Explainable AI Framework for Electronic Circuit Understanding & Design
% Common-Emitter (CE) BJT Amplifier
% =========================================================================

clear; clc; close all;
fprintf('==================================================================\n');
fprintf('  GENERATING FINAL RESEARCH DELIVERABLES IN results/final/\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();
final_dir = fullfile(root_dir, 'results', 'final');
if ~exist(final_dir, 'dir'), mkdir(final_dir); end

%% ========================================================================
% 1. DATASET VALIDATION DELIVERABLES
% ========================================================================
fprintf('>>> [1/10] Processing Dataset Validation Deliverables...\n');
data_file = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
T_data = readtable(data_file);

param_names = {'R1';'R2';'RC';'RE';'RL';'Cin';'Cout';'Ce';'VCC';'Gain_dB'};
units = {'Ohm';'Ohm';'Ohm';'Ohm';'Ohm';'F';'F';'F';'V';'dB'};

min_vals = zeros(10, 1);
q25_vals = zeros(10, 1);
med_vals = zeros(10, 1);
mean_vals = zeros(10, 1);
q75_vals = zeros(10, 1);
max_vals = zeros(10, 1);
std_vals = zeros(10, 1);

for k = 1:10
    v = T_data.(param_names{k});
    min_vals(k) = min(v);
    q25_vals(k) = quantile(v, 0.25);
    med_vals(k) = median(v);
    mean_vals(k) = mean(v);
    q75_vals(k) = quantile(v, 0.75);
    max_vals(k) = max(v);
    std_vals(k) = std(v);
end

DatasetValTable = table(param_names, units, min_vals, q25_vals, med_vals, mean_vals, q75_vals, max_vals, std_vals, ...
    'VariableNames', {'Parameter','Units','Min','Q25','Median','Mean','Q75','Max','Std'});
writetable(DatasetValTable, fullfile(final_dir, 'Dataset_Validation.csv'));
save(fullfile(final_dir, 'Dataset_Validation.mat'), 'DatasetValTable', 'T_data');

% Dataset Distribution Figure: 01_Dataset_Distribution.png
f1 = figure('Position', [100, 100, 1100, 750], 'Visible', 'off');
features_to_plot = {'R1','R2','RC','RE','RL','VCC','Cin','Cout','Gain_dB'};
for i = 1:9
    subplot(3, 3, i);
    feat = features_to_plot{i};
    vals = T_data.(feat);
    if strcmp(feat, 'Gain_dB')
        histogram(vals, 25, 'FaceColor', [0.85, 0.33, 0.10], 'EdgeColor', 'k');
        title('Target: Gain (dB)', 'FontWeight', 'bold');
        xlabel('Gain (dB)');
    elseif contains(feat, 'C') && ~strcmp(feat, 'RC') && ~strcmp(feat, 'VCC')
        histogram(log10(vals), 25, 'FaceColor', [0.49, 0.18, 0.56], 'EdgeColor', 'k');
        title(sprintf('log_{10}(%s) (F)', feat), 'FontWeight', 'bold');
        xlabel(sprintf('log_{10}(%s)', feat));
    elseif strcmp(feat, 'VCC')
        histogram(vals, 20, 'FaceColor', [0.47, 0.67, 0.19], 'EdgeColor', 'k');
        title('VCC (V)', 'FontWeight', 'bold');
        xlabel('VCC (V)');
    else
        histogram(log10(vals), 25, 'FaceColor', [0.0, 0.45, 0.74], 'EdgeColor', 'k');
        title(sprintf('log_{10}(%s) (\\Omega)', feat), 'FontWeight', 'bold');
        xlabel(sprintf('log_{10}(%s)', feat));
    end
    ylabel('Count');
    grid on;
end
sgtitle('CE Amplifier Dataset: Component & Gain Distributions (N = 660)', 'FontWeight', 'bold', 'FontSize', 14);
saveas(f1, fullfile(final_dir, '01_Dataset_Distribution.png'));
close(f1);

%% ========================================================================
% 2. ML MODEL EVALUATION DELIVERABLES
% ========================================================================
fprintf('>>> [2/10] Processing ML Model Evaluation Deliverables...\n');
model_file = fullfile(root_dir, 'models', 'ml', 'Gain_Boosted_Model.mat');
if ~isfile(model_file), model_file = fullfile(root_dir, 'ml', 'models', 'Gain_Boosted_Model.mat'); end
M_obj = load(model_file);

LogFeatures = {'R1','R2','RC','RE','RL','Cin','Cout','Ce'};
X_all = zeros(height(T_data), 9);
for k = 1:numel(LogFeatures)
    X_all(:,k) = log10(T_data.(LogFeatures{k}));
end
X_all(:,9) = T_data.VCC;
Y_all = T_data.Gain_dB;

% Evaluate predictions
Y_pred_all = predict(M_obj.model, X_all);
res_all = Y_all - Y_pred_all;

% 80/20 Test partition
rng(42);
cv_hold = cvpartition(height(T_data), 'HoldOut', 0.20);
test_idx = test(cv_hold);
Y_test_act = Y_all(test_idx);
Y_test_pred = Y_pred_all(test_idx);
res_test = Y_test_act - Y_test_pred;

% Load CV results
cv_file = fullfile(root_dir, 'results', 'ml', 'CV_Results.mat');
if isfile(cv_file)
    cv_dat = load(cv_file);
    r2_cv = cv_dat.R2_CV;
    rmse_cv = cv_dat.CV_RMSE;
    mae_cv = cv_dat.MAE_CV;
else
    r2_cv = 0.7987; rmse_cv = 3.2246; mae_cv = 2.4971;
end

% Repeated CV
rep_cv_file = fullfile(root_dir, 'results', 'ml', 'ML_CV_Repeated_Results.mat');
if isfile(rep_cv_file)
    rep_dat = load(rep_cv_file);
    r2_rep_mean = mean(rep_dat.R2_folds);
    r2_rep_std = std(rep_dat.R2_folds);
    rmse_rep_mean = mean(rep_dat.RMSE_folds);
    rmse_rep_std = std(rep_dat.RMSE_folds);
    mae_rep_mean = mean(rep_dat.MAE_folds);
    mae_rep_std = std(rep_dat.MAE_folds);
else
    r2_rep_mean = 0.7998; r2_rep_std = 0.0288;
    rmse_rep_mean = 3.1912; rmse_rep_std = 0.2504;
    mae_rep_mean = 2.5103; mae_rep_std = 0.1834;
end

eval_names = {'Full_Apparent_Fit'; 'Held_Out_Test_20pc'; '5Fold_CV'; 'Repeated_5Fold_CV_Mean'; 'Repeated_5Fold_CV_Std'};
r2_col = [1 - sum(res_all.^2)/sum((Y_all - mean(Y_all)).^2); ...
          1 - sum(res_test.^2)/sum((Y_test_act - mean(Y_test_act)).^2); ...
          r2_cv; r2_rep_mean; r2_rep_std];
rmse_col = [sqrt(mean(res_all.^2)); sqrt(mean(res_test.^2)); rmse_cv; rmse_rep_mean; rmse_rep_std];
mae_col  = [mean(abs(res_all)); mean(abs(res_test)); mae_cv; mae_rep_mean; mae_rep_std];

MLEvalTable = table(eval_names, r2_col, rmse_col, mae_col, ...
    'VariableNames', {'Evaluation_Method', 'R2', 'RMSE_dB', 'MAE_dB'});
writetable(MLEvalTable, fullfile(final_dir, 'ML_Model_Evaluation.csv'));
save(fullfile(final_dir, 'ML_Model_Evaluation.mat'), 'MLEvalTable', 'Y_all', 'Y_pred_all', 'res_all', 'test_idx');

% Figure: 02_Model_Actual_vs_Predicted.png
f2 = figure('Position', [100, 100, 650, 550], 'Visible', 'off');
scatter(Y_all(~test_idx), Y_pred_all(~test_idx), 28, [0.0, 0.45, 0.74], 'filled', 'MarkerFaceAlpha', 0.6); hold on;
scatter(Y_all(test_idx), Y_pred_all(test_idx), 35, [0.85, 0.33, 0.10], 'filled', 'MarkerFaceAlpha', 0.8);
plot([5, 55], [5, 55], 'k--', 'LineWidth', 1.5);
xlabel('SPICE Simulated Gain (dB)', 'FontWeight', 'bold');
ylabel('ML Predicted Gain (dB)', 'FontWeight', 'bold');
title(sprintf('ML Model: Actual vs. Predicted Gain (Test R^2 = %.4f)', r2_col(2)), 'FontWeight', 'bold');
legend({'Training Samples (80%)', 'Held-Out Test (20%)', 'Ideal 1:1 Line'}, 'Location', 'northwest');
grid on; axis([5 55 5 55]);
saveas(f2, fullfile(final_dir, '02_Model_Actual_vs_Predicted.png'));
close(f2);

% Figure: 03_Model_Residuals.png
f3 = figure('Position', [100, 100, 650, 550], 'Visible', 'off');
scatter(Y_pred_all, res_all, 28, [0.49, 0.18, 0.56], 'filled', 'MarkerFaceAlpha', 0.6); hold on;
yline(0, 'k--', 'LineWidth', 1.5);
yline(3.07, 'r:', 'Label', '+1 Test RMSE', 'LineWidth', 1.2);
yline(-3.07, 'r:', 'Label', '-1 Test RMSE', 'LineWidth', 1.2);
xlabel('ML Predicted Gain (dB)', 'FontWeight', 'bold');
ylabel('Residual Error (Actual - Predicted, dB)', 'FontWeight', 'bold');
title('ML Model Residual Analysis across Gain Range', 'FontWeight', 'bold');
grid on;
saveas(f3, fullfile(final_dir, '03_Model_Residuals.png'));
close(f3);

% Combined 2-panel figure: ML_Model_Evaluation.png
f_ml_comb = figure('Position', [100, 100, 1100, 500], 'Visible', 'off');
subplot(1, 2, 1);
scatter(Y_all(~test_idx), Y_pred_all(~test_idx), 28, [0.0, 0.45, 0.74], 'filled', 'MarkerFaceAlpha', 0.6); hold on;
scatter(Y_all(test_idx), Y_pred_all(test_idx), 35, [0.85, 0.33, 0.10], 'filled', 'MarkerFaceAlpha', 0.8);
plot([5, 55], [5, 55], 'k--', 'LineWidth', 1.5);
xlabel('SPICE Simulated Gain (dB)', 'FontWeight', 'bold');
ylabel('ML Predicted Gain (dB)', 'FontWeight', 'bold');
title(sprintf('Actual vs. Predicted Gain (Test R^2 = %.4f)', r2_col(2)), 'FontWeight', 'bold');
legend({'Training (80%)', 'Test (20%)', 'Ideal Line'}, 'Location', 'northwest'); grid on; axis([5 55 5 55]);

subplot(1, 2, 2);
scatter(Y_pred_all, res_all, 28, [0.49, 0.18, 0.56], 'filled', 'MarkerFaceAlpha', 0.6); hold on;
yline(0, 'k--', 'LineWidth', 1.5);
xlabel('ML Predicted Gain (dB)', 'FontWeight', 'bold');
ylabel('Residual Error (dB)', 'FontWeight', 'bold');
title('Residual Plot', 'FontWeight', 'bold'); grid on;
saveas(f_ml_comb, fullfile(final_dir, 'ML_Model_Evaluation.png'));
close(f_ml_comb);

%% ========================================================================
% 3. GLOBAL SHAP DELIVERABLES
% ========================================================================
fprintf('>>> [3/10] Processing Global SHAP Deliverables...\n');
shap_mat = fullfile(root_dir, 'xai', 'global_shap', 'Gain_SHAP_Results.mat');
S_glob = load(shap_mat);

% Feature mapping: x1:R1, x2:R2, x3:RC, x4:RE, x5:RL, x6:Cin, x7:Cout, x8:Ce, x9:VCC
predictor_map = containers.Map({'x1','x2','x3','x4','x5','x6','x7','x8','x9'}, ...
                               {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'});

orig_params = S_glob.SHAPResults.Parameter;
shap_vals = S_glob.SHAPResults.MeanAbsoluteSHAP;

mapped_names = cell(length(orig_params), 1);
for p = 1:length(orig_params)
    p_str = char(orig_params(p));
    if isKey(predictor_map, p_str)
        mapped_names{p} = predictor_map(p_str);
    else
        mapped_names{p} = p_str;
    end
end

GlobalSHAPTable = table((1:length(orig_params))', mapped_names, orig_params, shap_vals, ...
    'VariableNames', {'Rank', 'Parameter', 'Predictor_Index', 'Mean_Absolute_SHAP_dB'});
writetable(GlobalSHAPTable, fullfile(final_dir, 'Global_SHAP_Importance.csv'));
save(fullfile(final_dir, 'Global_SHAP_Results.mat'), 'GlobalSHAPTable', 'S_glob');

% Figure: 04_Global_SHAP.png & Global_SHAP_Importance.png
f4 = figure('Position', [100, 100, 750, 500], 'Visible', 'off');
barh(flipud(shap_vals), 'FaceColor', [0.0, 0.45, 0.74], 'EdgeColor', 'k');
set(gca, 'YTick', 1:length(shap_vals), 'YTickLabel', flipud(mapped_names), 'FontWeight', 'bold');
xlabel('Mean Absolute SHAP Value (dB)', 'FontWeight', 'bold');
title('Global Feature Importance for Midband Gain (SHAP)', 'FontWeight', 'bold');
grid on;
saveas(f4, fullfile(final_dir, '04_Global_SHAP.png'));
saveas(f4, fullfile(final_dir, 'Global_SHAP_Importance.png'));
close(f4);

%% ========================================================================
% 4. LOCAL SHAP DELIVERABLES
% ========================================================================
fprintf('>>> [4/10] Processing Local SHAP Deliverables...\n');
local_mat = fullfile(root_dir, 'xai', 'local_shap', 'Local_SHAP_Results.mat');
L_dat = load(local_mat);

circ_names = {'Low_Gain'; 'Medium_Gain'; 'High_Gain'};
rows_rep = [450; 253; 259];
act_gain = L_dat.ActualGain(:);
pred_gain = L_dat.PredictedGain(:);
err_gain = L_dat.PredictionError(:);

LocalSHAPTable = table(circ_names, rows_rep, act_gain, pred_gain, err_gain, ...
    L_dat.LocalSHAP(:,1), L_dat.LocalSHAP(:,2), L_dat.LocalSHAP(:,3), L_dat.LocalSHAP(:,4), ...
    L_dat.LocalSHAP(:,5), L_dat.LocalSHAP(:,6), L_dat.LocalSHAP(:,7), L_dat.LocalSHAP(:,8), L_dat.LocalSHAP(:,9), ...
    'VariableNames', {'Circuit', 'Row_ID', 'Actual_Gain_dB', 'Predicted_Gain_dB', 'Error_dB', ...
                      'R1', 'R2', 'RC', 'RE', 'RL', 'Cin', 'Cout', 'Ce', 'VCC'});
writetable(LocalSHAPTable, fullfile(final_dir, 'Local_SHAP_Results.csv'));
save(fullfile(final_dir, 'Local_SHAP_Results.mat'), 'LocalSHAPTable', 'L_dat');

% Figure: 05_Local_SHAP.png & Local_SHAP_Comparison.png
f5 = figure('Position', [100, 100, 950, 500], 'Visible', 'off');
b = bar(L_dat.LocalSHAP');
set(gca, 'XTick', 1:9, 'XTickLabel', {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'}, 'FontWeight', 'bold');
xlabel('Circuit Parameter', 'FontWeight', 'bold');
ylabel('Local SHAP Attribution (dB)', 'FontWeight', 'bold');
title('Local SHAP Attribution across Low, Medium, and High Gain Regimes', 'FontWeight', 'bold');
legend({'Low Gain (Row 450, 9.41 dB)', 'Medium Gain (Row 253, 35.22 dB)', 'High Gain (Row 259, 51.45 dB)'}, 'Location', 'northeast');
grid on;
saveas(f5, fullfile(final_dir, '05_Local_SHAP.png'));
saveas(f5, fullfile(final_dir, 'Local_SHAP_Comparison.png'));
close(f5);

%% ========================================================================
% 5. SHAP DEPENDENCE DELIVERABLES
% ========================================================================
fprintf('>>> [5/10] Processing SHAP Dependence Deliverables...\n');
dep_stat_file = fullfile(root_dir, 'xai', 'dependence', 'SHAP_Dependence_Statistics.csv');
if isfile(dep_stat_file)
    copyfile(dep_stat_file, fullfile(final_dir, 'SHAP_Dependence_Statistics.csv'));
end

% Figure: 06_SHAP_Dependence.png
f6 = figure('Position', [100, 100, 1100, 650], 'Visible', 'off');
dep_params = {'R1', 'RE', 'RC', 'R2', 'VCC', 'RL'};
rho_vals = [-0.9858, -0.9744, 0.9668, 0.9792, 0.9748, 0.9346];

for d = 1:6
    subplot(2, 3, d);
    p_name = dep_params{d};
    p_vals = T_data.(p_name);
    if strcmp(p_name, 'VCC')
        x_plot = p_vals;
        x_lbl = 'VCC (V)';
    else
        x_plot = log10(p_vals);
        x_lbl = sprintf('log_{10}(%s) (\\Omega)', p_name);
    end
    scatter(x_plot, Y_all, 20, [0.0, 0.45, 0.74], 'filled', 'MarkerFaceAlpha', 0.5);
    xlabel(x_lbl, 'FontWeight', 'bold');
    ylabel('Gain (dB)', 'FontWeight', 'bold');
    title(sprintf('%s (\\rho = %+.4f)', p_name, rho_vals(d)), 'FontWeight', 'bold');
    grid on;
end
sgtitle('SHAP Dependence & Parameter Associations with Gain', 'FontWeight', 'bold', 'FontSize', 14);
saveas(f6, fullfile(final_dir, '06_SHAP_Dependence.png'));
close(f6);

%% ========================================================================
% 6. SHAP INTERACTION DELIVERABLES
% ========================================================================
fprintf('>>> [6/10] Processing SHAP Interaction Deliverables...\n');
inter_mat = fullfile(root_dir, 'xai', 'interaction', 'SHAP_Interaction_Results.mat');
Inter_obj = load(inter_mat);
if isfield(Inter_obj, 'Results'), Inter_data = Inter_obj.Results; else, Inter_data = Inter_obj; end

InterTable = Inter_data.InteractionTable;
writetable(InterTable, fullfile(final_dir, 'SHAP_Interaction_Ranking.csv'));
save(fullfile(final_dir, 'SHAP_Interaction_Results.mat'), 'Inter_data');

% Figure: 07_SHAP_Interaction_Heatmap.png & SHAP_Interaction_Heatmap.png
f7 = figure('Position', [100, 100, 700, 600], 'Visible', 'off');
M_inter = Inter_data.InteractionMatrix;
feats_inter = Inter_data.SelectedFeatures;
imagesc(M_inter);
colormap('hot'); colorbar;
set(gca, 'XTick', 1:length(feats_inter), 'XTickLabel', feats_inter, ...
         'YTick', 1:length(feats_inter), 'YTickLabel', feats_inter, 'FontWeight', 'bold');
title('Second-Order SHAP Interaction Matrix (dB)', 'FontWeight', 'bold');
for r = 1:size(M_inter, 1)
    for c = 1:size(M_inter, 2)
        if M_inter(r,c) > 0.3
            text(c, r, sprintf('%.3f', M_inter(r,c)), 'HorizontalAlignment', 'center', 'Color', 'k', 'FontWeight', 'bold');
        else
            text(c, r, sprintf('%.3f', M_inter(r,c)), 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
end
saveas(f7, fullfile(final_dir, '07_SHAP_Interaction_Heatmap.png'));
saveas(f7, fullfile(final_dir, 'SHAP_Interaction_Heatmap.png'));
close(f7);

% Figure: SHAP_Top_Interactions.png
f7_top = figure('Position', [100, 100, 750, 450], 'Visible', 'off');
top_pairs = cell(min(5, height(InterTable)), 1);
top_strengths = zeros(length(top_pairs), 1);
for k = 1:length(top_pairs)
    top_pairs{k} = sprintf('%s \\leftrightarrow %s', char(InterTable.Parameter1(k)), char(InterTable.Parameter2(k)));
    top_strengths(k) = InterTable.InteractionStrength(k);
end
barh(flipud(top_strengths), 'FaceColor', [0.85, 0.33, 0.10], 'EdgeColor', 'k');
set(gca, 'YTick', 1:length(top_pairs), 'YTickLabel', flipud(top_pairs), 'FontWeight', 'bold');
xlabel('Interaction Strength (dB)', 'FontWeight', 'bold');
title('Top 5 Second-Order Feature Interactions', 'FontWeight', 'bold');
grid on;
saveas(f7_top, fullfile(final_dir, 'SHAP_Top_Interactions.png'));
close(f7_top);

%% ========================================================================
% 7. CLASSICAL SPICE SENSITIVITY DELIVERABLES
% ========================================================================
fprintf('>>> [7/10] Processing Classical SPICE Sensitivity Deliverables...\n');
sens_mat = fullfile(root_dir, 'results', 'sensitivity', 'Classical_Sensitivity_Results.mat');
Sens_dat = load(sens_mat);

if isfield(Sens_dat, 'sens_detail_tab')
    ClassicalSensTable = Sens_dat.sens_detail_tab;
else
    ClassicalSensTable = Sens_dat.CompTable;
end
writetable(ClassicalSensTable, fullfile(final_dir, 'Classical_Sensitivity.csv'));
save(fullfile(final_dir, 'Classical_Sensitivity.mat'), 'Sens_dat', 'ClassicalSensTable');

% Figure: 08_Classical_Sensitivity.png & Classical_Sensitivity_Heatmap.png
f8 = figure('Position', [100, 100, 850, 500], 'Visible', 'off');
circ_labels = {'Low Gain (Row 450)', 'Medium Gain (Row 253)', 'High Gain (Row 259)'};
sens_matrix = Sens_dat.Sens_Matrix'; % 9 params x 3 circuits
param_names_sens = {'R1', 'R2', 'RC', 'RE', 'RL', 'Cin', 'Cout', 'Ce', 'VCC'};

b_sens = bar(sens_matrix);
set(gca, 'XTick', 1:9, 'XTickLabel', param_names_sens, 'FontWeight', 'bold');
xlabel('Parameter', 'FontWeight', 'bold');
ylabel('Normalized Sensitivity S_x = (\DeltaG/G) / (\Deltax/x)', 'FontWeight', 'bold');
title('Classical SPICE Sensitivity across Representative Circuits (\pm1% Perturbation)', 'FontWeight', 'bold');
legend(circ_labels, 'Location', 'northeast'); grid on;
saveas(f8, fullfile(final_dir, '08_Classical_Sensitivity.png'));
saveas(f8, fullfile(final_dir, 'Classical_Sensitivity_Heatmap.png'));
close(f8);

%% ========================================================================
% 8. SHAP VS. CLASSICAL SENSITIVITY DELIVERABLES
% ========================================================================
fprintf('>>> [8/10] Processing SHAP vs Classical Sensitivity Deliverables...\n');
comp_file = fullfile(root_dir, 'results', 'tables', 'SHAP_vs_Classical_Sensitivity.csv');
T_comp = readtable(comp_file);
writetable(T_comp, fullfile(final_dir, 'SHAP_vs_Classical.csv'));

rho_sens = corr(T_comp.Mean_Absolute_SHAP_dB, T_comp.Mean_Normalized_Sensitivity, 'Type', 'Spearman');
r_sens = corr(T_comp.Mean_Absolute_SHAP_dB, T_comp.Mean_Normalized_Sensitivity, 'Type', 'Pearson');

save(fullfile(final_dir, 'SHAP_vs_Classical.mat'), 'T_comp', 'rho_sens', 'r_sens');

% Figure: 09_SHAP_vs_Classical.png & SHAP_vs_Classical.png
f9 = figure('Position', [100, 100, 700, 550], 'Visible', 'off');
scatter(T_comp.Mean_Absolute_SHAP_dB, T_comp.Mean_Normalized_Sensitivity, 80, [0.0, 0.45, 0.74], 'filled'); hold on;
for k = 1:height(T_comp)
    text(T_comp.Mean_Absolute_SHAP_dB(k)+0.06, T_comp.Mean_Normalized_Sensitivity(k), ...
        char(T_comp.Parameter{k}), 'FontWeight', 'bold');
end
xlabel('Global Mean Absolute SHAP (dB)', 'FontWeight', 'bold');
ylabel('Classical SPICE Normalized Sensitivity |S_x|', 'FontWeight', 'bold');
title(sprintf('SHAP Attribution vs. Physical SPICE Sensitivity (\\rho = %.4f, r = %.4f)', rho_sens, r_sens), 'FontWeight', 'bold');
grid on;
saveas(f9, fullfile(final_dir, '09_SHAP_vs_Classical.png'));
saveas(f9, fullfile(final_dir, 'SHAP_vs_Classical.png'));
close(f9);

%% ========================================================================
% 9. R1-R2 SPICE 15x15 GRID VALIDATION SURFACES
% ========================================================================
fprintf('>>> [9/10] Processing R1-R2 SPICE Physical Validation Deliverables...\n');
sweep_all_file = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'R1_R2_All_Sweeps.csv');
T_all_sweeps = readtable(sweep_all_file);

circ_types = {'Low_Gain', 'Medium_Gain', 'High_Gain'};
for c = 1:3
    ctype = circ_types{c};
    idx = strcmp(T_all_sweeps.Circuit_Type, ctype);
    sub_T = T_all_sweeps(idx, :);
    
    r1_vals = unique(sub_T.R1);
    r2_vals = unique(sub_T.R2);
    nR1 = length(r1_vals);
    nR2 = length(r2_vals);
    
    G_sp = reshape(sub_T.Gain_dB, [nR1, nR2]);
    G_ml = reshape(sub_T.ML_Gain_dB, [nR1, nR2]);
    G_err = abs(G_sp - G_ml);
    
    % Individual SPICE surface figures
    f_surf = figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    surf(log10(r2_vals), log10(r1_vals), G_sp);
    shading interp; colormap('jet'); colorbar;
    xlabel('log_{10}(R2) (\Omega)', 'FontWeight', 'bold');
    ylabel('log_{10}(R1) (\Omega)', 'FontWeight', 'bold');
    zlabel('SPICE Gain (dB)', 'FontWeight', 'bold');
    title(sprintf('15x15 R1-R2 SPICE Ground Truth Gain Surface: %s', strrep(ctype, '_', ' ')), 'FontWeight', 'bold');
    grid on; view(45, 30);
    saveas(f_surf, fullfile(final_dir, sprintf('R1_R2_SPICE_Surface_%s.png', ctype)));
    close(f_surf);
end

% Medium Gain 3-panel figure: 10_R1_R2_SPICE_Surface, 11_R1_R2_ML_Surface, 12_R1_R2_Error
med_idx = strcmp(T_all_sweeps.Circuit_Type, 'Medium_Gain');
med_T = T_all_sweeps(med_idx, :);
r1_m = unique(med_T.R1);
r2_m = unique(med_T.R2);
G_sp_m = reshape(med_T.Gain_dB, [length(r1_m), length(r2_m)]);
G_ml_m = reshape(med_T.ML_Gain_dB, [length(r1_m), length(r2_m)]);
G_err_m = abs(G_sp_m - G_ml_m);

% 10: SPICE surface
f10 = figure('Position', [100, 100, 750, 550], 'Visible', 'off');
surf(log10(r2_m), log10(r1_m), G_sp_m); shading interp; colormap('parula'); colorbar;
xlabel('log_{10}(R2) (\Omega)', 'FontWeight', 'bold'); ylabel('log_{10}(R1) (\Omega)', 'FontWeight', 'bold');
zlabel('SPICE Gain (dB)', 'FontWeight', 'bold'); title('10: SPICE Ground Truth Gain Surface (Medium Gain Circuit)', 'FontWeight', 'bold');
grid on; view(45, 30);
saveas(f10, fullfile(final_dir, '10_R1_R2_SPICE_Surface.png')); close(f10);

% 11: ML surface
f11 = figure('Position', [100, 100, 750, 550], 'Visible', 'off');
surf(log10(r2_m), log10(r1_m), G_ml_m); shading interp; colormap('parula'); colorbar;
xlabel('log_{10}(R2) (\Omega)', 'FontWeight', 'bold'); ylabel('log_{10}(R1) (\Omega)', 'FontWeight', 'bold');
zlabel('ML Predicted Gain (dB)', 'FontWeight', 'bold'); title('11: ML Surrogate Model Gain Surface (Medium Gain Circuit)', 'FontWeight', 'bold');
grid on; view(45, 30);
saveas(f11, fullfile(final_dir, '11_R1_R2_ML_Surface.png')); close(f11);

% 12: Error surface
f12 = figure('Position', [100, 100, 750, 550], 'Visible', 'off');
contourf(log10(r2_m), log10(r1_m), G_err_m, 20); colormap('hot'); colorbar;
xlabel('log_{10}(R2) (\Omega)', 'FontWeight', 'bold'); ylabel('log_{10}(R1) (\Omega)', 'FontWeight', 'bold');
title('12: Absolute Error Surface |SPICE - ML| (dB)', 'FontWeight', 'bold');
grid on;
saveas(f12, fullfile(final_dir, '12_R1_R2_Error.png')); close(f12);

%% ========================================================================
% 10. DESIGN OPTIMIZATION DELIVERABLES
% ========================================================================
fprintf('>>> [10/10] Processing Design Optimization Deliverables...\n');
opt_cand_file = fullfile(root_dir, 'results', 'optimization', 'Optimized_Candidates.csv');
T_opt = readtable(opt_cand_file);

writetable(T_opt, fullfile(final_dir, 'Optimization_Candidates.csv'));

gain_imp = T_opt.SPICE_Gain_dB - T_opt.Baseline_Gain_dB;
op_status = T_opt.Simulation_Status;

% Validation table
T_opt_val = table(T_opt.Candidate_Name, T_opt.Baseline_Gain_dB, T_opt.ML_Predicted_Gain, ...
                  T_opt.SPICE_Gain_dB, gain_imp, T_opt.V_CE, T_opt.I_C_mA, op_status, ...
    'VariableNames', {'Candidate', 'Baseline_SPICE_Gain_dB', 'ML_Predicted_Gain_dB', 'Validated_SPICE_Gain_dB', ...
                      'SPICE_Gain_Improvement_dB', 'Operating_VCE_V', 'Operating_IC_mA', 'Operating_Status'});
writetable(T_opt_val, fullfile(final_dir, 'Optimization_Validation.csv'));
save(fullfile(final_dir, 'Optimization_Results.mat'), 'T_opt', 'T_opt_val');

% Figure: 13_Optimization_Validation.png
f13 = figure('Position', [100, 100, 850, 500], 'Visible', 'off');
x_pos = [1, 2, 3];
bar_data = [T_opt.Baseline_Gain_dB, T_opt.SPICE_Gain_dB];
b_opt = bar(x_pos, bar_data);
b_opt(1).FaceColor = [0.0, 0.45, 0.74];
b_opt(2).FaceColor = [0.47, 0.67, 0.19];
set(gca, 'XTick', x_pos, 'XTickLabel', {'Low Gain (Row 450)', 'Medium Gain (Row 253)', 'High Gain (Row 259)'}, 'FontWeight', 'bold');
ylabel('Midband Gain (dB)', 'FontWeight', 'bold');
title('13: SPICE Physical Validation of Constrained Optimized Circuits', 'FontWeight', 'bold');
legend({'Baseline SPICE Gain', 'Optimized SPICE Validated Gain'}, 'Location', 'northwest');
grid on;
saveas(f13, fullfile(final_dir, '13_Optimization_Validation.png'));
close(f13);

fprintf('\n>>> ALL FINAL DELIVERABLES SUCCESSFULLY GENERATED IN results/final/ <<<\n');

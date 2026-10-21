%% stage11_generate_publication_figures_and_tables.m
% Phase 11 & 12: Generate Final Publication-Quality Figures (1-10) and Tables (1-10)
%
% This script consolidates all research outputs into:
%   - results/figures/publication/Fig01..Fig10.png
%   - results/tables/publication/Table01..Table10.csv

clear; clc; close all;
fprintf('==================================================================\n');
fprintf('  STAGE 11 & 12: PUBLICATION FIGURES (1-10) & TABLES (1-10)\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();

pub_fig_dir = fullfile(root_dir, 'results', 'figures', 'publication');
pub_tab_dir = fullfile(root_dir, 'results', 'tables', 'publication');
if ~isfolder(pub_fig_dir), mkdir(pub_fig_dir); end
if ~isfolder(pub_tab_dir), mkdir(pub_tab_dir); end

%% ========================================================================
%  PART 1: GENERATE ALL 10 CANONICAL TABLES
%  ========================================================================
fprintf('--- Compiling 10 Publication Tables ---\n');

% -------------------------------------------------------------------------
% Table 1: Dataset Statistics
% -------------------------------------------------------------------------
T_data = readtable(fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv'));
vars = T_data.Properties.VariableNames;
units = {'\Omega', '\Omega', '\Omega', '\Omega', '\Omega', 'F', 'F', 'F', 'V', 'dB'};
t1_rows = {};
for i = 1:numel(vars)
    vals = T_data.(vars{i});
    t1_rows{end+1} = struct('Variable', vars{i}, 'Units', units{i}, ...
        'Min', min(vals), 'Max', max(vals), 'Mean', mean(vals), ...
        'Median', median(vals), 'StdDev', std(vals)); %#ok<AGROW>
end
Table01 = struct2table(cell2mat(t1_rows));
writetable(Table01, fullfile(pub_tab_dir, 'Table01_Dataset_Statistics.csv'));
fprintf('  Table 1: Dataset Statistics saved\n');

% -------------------------------------------------------------------------
% Table 2: ML Performance
% -------------------------------------------------------------------------
Table02 = readtable(fullfile(root_dir, 'results', 'tables', 'ML_Model_Performance.csv'));
writetable(Table02, fullfile(pub_tab_dir, 'Table02_ML_Performance.csv'));
fprintf('  Table 2: ML Performance saved\n');

% -------------------------------------------------------------------------
% Table 3: Global SHAP Importance
% -------------------------------------------------------------------------
T_shap = readtable(fullfile(root_dir, 'results', 'tables', 'SHAP_vs_Classical_Sensitivity.csv'));
T_shap_sorted = sortrows(T_shap, 'SHAP_Rank');
total_shap = sum(T_shap_sorted.Mean_Absolute_SHAP_dB);
Table03 = table(T_shap_sorted.SHAP_Rank, T_shap_sorted.Parameter, ...
    T_shap_sorted.Mean_Absolute_SHAP_dB, ...
    100 * T_shap_sorted.Mean_Absolute_SHAP_dB / total_shap, ...
    'VariableNames', {'Rank', 'Parameter', 'Mean_Absolute_SHAP_dB', 'Relative_Attribution_Percent'});
writetable(Table03, fullfile(pub_tab_dir, 'Table03_Global_SHAP_Importance.csv'));
fprintf('  Table 3: Global SHAP Importance saved\n');

% -------------------------------------------------------------------------
% Table 4: Local SHAP Results
% -------------------------------------------------------------------------
L = load(fullfile(root_dir, 'xai', 'local_shap', 'Local_SHAP_Results.mat'));
ParamNames = {'R1';'R2';'RC';'RE';'RL';'Cin';'Cout';'Ce';'VCC'};
Table04 = table(ParamNames, L.LocalSHAP(1,:)', L.LocalSHAP(2,:)', L.LocalSHAP(3,:)', ...
    'VariableNames', {'Parameter', 'Low_Gain_Row450_SHAP', 'Medium_Gain_Row253_SHAP', 'High_Gain_Row259_SHAP'});
writetable(Table04, fullfile(pub_tab_dir, 'Table04_Local_SHAP_Results.csv'));
fprintf('  Table 4: Local SHAP Results saved\n');

% -------------------------------------------------------------------------
% Table 5: SHAP Interaction Ranking
% -------------------------------------------------------------------------
inter_csv = fullfile(root_dir, 'xai', 'interaction', 'SHAP_Interaction_Ranking.csv');
T_inter = readtable(inter_csv);
Table05 = T_inter(1:10, :); % Top 10 interactions
writetable(Table05, fullfile(pub_tab_dir, 'Table05_SHAP_Interaction_Ranking.csv'));
fprintf('  Table 5: SHAP Interaction Ranking saved\n');

% -------------------------------------------------------------------------
% Table 6: Classical Sensitivity
% -------------------------------------------------------------------------
sens_detail = readtable(fullfile(root_dir, 'results', 'tables', 'Classical_Sensitivity_By_Circuit.csv'));
p_list = unique(sens_detail.Parameter, 'stable');
t6_rows = {};
for p = 1:numel(p_list)
    pname = p_list{p};
    sub = sens_detail(strcmp(sens_detail.Parameter, pname), :);
    s_low = sub.Sensitivity(strcmp(sub.Circuit, 'Low_Gain'));
    s_med = sub.Sensitivity(strcmp(sub.Circuit, 'Medium_Gain'));
    s_hig = sub.Sensitivity(strcmp(sub.Circuit, 'High_Gain'));
    s_mean = mean(sub.Sensitivity);
    t6_rows{end+1} = struct('Parameter', pname, 'Low_Gain_Sens', s_low, ...
        'Medium_Gain_Sens', s_med, 'High_Gain_Sens', s_hig, 'Mean_Sensitivity', s_mean); %#ok<AGROW>
end
Table06 = struct2table(cell2mat(t6_rows));
writetable(Table06, fullfile(pub_tab_dir, 'Table06_Classical_Sensitivity.csv'));
fprintf('  Table 6: Classical Sensitivity saved\n');

% -------------------------------------------------------------------------
% Table 7: SHAP vs Classical Sensitivity
% -------------------------------------------------------------------------
Table07 = readtable(fullfile(root_dir, 'results', 'tables', 'SHAP_vs_Classical_Sensitivity.csv'));
writetable(Table07, fullfile(pub_tab_dir, 'Table07_SHAP_vs_Classical_Sensitivity.csv'));
fprintf('  Table 7: SHAP vs Classical Sensitivity saved\n');

% -------------------------------------------------------------------------
% Table 8: SPICE vs ML Validation
% -------------------------------------------------------------------------
Table08 = readtable(fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'ML_vs_SPICE_Metrics.csv'));
writetable(Table08, fullfile(pub_tab_dir, 'Table08_SPICE_vs_ML_Validation.csv'));
fprintf('  Table 8: SPICE vs ML Validation saved\n');

% -------------------------------------------------------------------------
% Table 9: Optimized Circuit Candidates
% -------------------------------------------------------------------------
Table09 = readtable(fullfile(root_dir, 'results', 'optimization', 'Optimized_Candidates.csv'));
Table09_params = Table09(:, {'Candidate_Name', 'Baseline_Circuit', 'R1', 'R2', 'RC', 'RE', 'RL', 'Cin', 'Cout', 'Ce', 'VCC'});
writetable(Table09_params, fullfile(pub_tab_dir, 'Table09_Optimized_Circuit_Candidates.csv'));
fprintf('  Table 9: Optimized Circuit Candidates saved\n');

% -------------------------------------------------------------------------
% Table 10: Baseline vs Optimized SPICE Results
% -------------------------------------------------------------------------
Table10 = Table09(:, {'Candidate_Name', 'Baseline_Circuit', 'Baseline_Gain_dB', ...
    'ML_Predicted_Gain', 'SPICE_Gain_dB', 'Prediction_Error', 'Gain_Improvement_dB', ...
    'Linear_Gain_Ratio', 'V_B', 'V_CE', 'I_C_mA', 'Bandwidth_Hz', 'Simulation_Status'});
writetable(Table10, fullfile(pub_tab_dir, 'Table10_Baseline_vs_Optimized_SPICE.csv'));
fprintf('  Table 10: Baseline vs Optimized SPICE Results saved\n');


%% ========================================================================
%  PART 2: GENERATE ALL 10 PUBLICATION FIGURES
%  ========================================================================
fprintf('\n--- Generating 10 Publication Figures ---\n');

% -------------------------------------------------------------------------
% Figure 1: Overall Framework Architecture
% -------------------------------------------------------------------------
f1 = figure('Position', [100, 100, 1200, 480], 'Visible', 'off');
ax = axes('Position', [0.02, 0.02, 0.96, 0.96]); hold on; axis off;
xlim([0, 100]); ylim([0, 40]);

% Draw pipeline blocks
block_x = [4, 24, 44, 64, 84];
block_w = 14; block_h = 18;
titles = {'SPICE Simulation Deck', 'Gradient Boosting Surrogate', 'Explainable AI (SHAP)', ...
          'Physical Validation (SPICE)', 'Constrained Optimization'};
descs  = {'- LHS sampling (2000 circuits)\n- 660 valid operating points\n- AC gain, bandwidth, bias', ...
          '- LSBoost (300 trees)\n- Log-transformed features\n- R^2 = 0.80 +/- 0.03 (5-fold)', ...
          '- Global attribution ranking\n- Local SHAP operating regimes\n- R1-R2 interaction = 0.61 dB', ...
          '- 15x15 sweeps (675 sims)\n- 100% SPICE execution\n- DC operating-point physics', ...
          '- fminsearch / bayesopt\n- Active region constraints\n- Verified +28 dB gain boost'};
colors = {[0.2, 0.5, 0.8], [0.85, 0.45, 0.15], [0.55, 0.35, 0.75], [0.2, 0.65, 0.4], [0.8, 0.2, 0.2]};

for b = 1:5
    rectangle('Position', [block_x(b), 10, block_w, block_h], 'Curvature', 0.2, ...
        'FaceColor', colors{b}, 'EdgeColor', 'k', 'LineWidth', 1.5);
    text(block_x(b) + block_w/2, 25, titles{b}, 'Color', 'w', 'FontWeight', 'bold', ...
        'FontSize', 9.5, 'HorizontalAlignment', 'center');
    text(block_x(b) + block_w/2, 17, sprintf(descs{b}), 'Color', 'w', ...
        'FontSize', 7.5, 'HorizontalAlignment', 'center');
        
    % Draw arrows between blocks
    if b < 5
        arrow_x = block_x(b) + block_w;
        arrow_w = block_x(b+1) - arrow_x;
        annotation('arrow', [(arrow_x+1)/100, (arrow_x+arrow_w-1)/100], [0.48, 0.48], ...
            'LineWidth', 2.5, 'Color', [0.2, 0.2, 0.2]);
    end
end
title('Figure 1: Explainable AI Framework for Electronic Circuit Understanding and Design Optimization', ...
    'FontSize', 12, 'FontWeight', 'bold');
saveas(f1, fullfile(pub_fig_dir, 'Fig01_Framework_Architecture.png'));
close(f1);
fprintf('  Fig 01: Framework Architecture saved\n');

% -------------------------------------------------------------------------
% Figure 2: ML Model Performance
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'results', 'figures', 'ML_Model_Validation.png'), ...
         fullfile(pub_fig_dir, 'Fig02_ML_Model_Performance.png'));
fprintf('  Fig 02: ML Model Performance saved\n');

% -------------------------------------------------------------------------
% Figure 3: Global SHAP Importance
% -------------------------------------------------------------------------
f3 = figure('Position', [100, 100, 800, 480], 'Visible', 'off');
barh(categorical(Table03.Parameter(end:-1:1)), Table03.Mean_Absolute_SHAP_dB(end:-1:1), ...
    'FaceColor', [0.2, 0.5, 0.85]);
xlabel('Mean Absolute SHAP Value (dB)');
ylabel('Circuit Parameter');
title('Figure 3: Global Parameter Importance (MATLAB shapley Explainer)');
grid on; set(gca, 'FontSize', 10);
for i = 1:height(Table03)
    text(Table03.Mean_Absolute_SHAP_dB(height(Table03)-i+1) + 0.08, i, ...
        sprintf('%.3f dB (%.1f%%)', Table03.Mean_Absolute_SHAP_dB(height(Table03)-i+1), ...
        Table03.Relative_Attribution_Percent(height(Table03)-i+1)), 'FontSize', 9);
end
xlim([0, 4.5]);
saveas(f3, fullfile(pub_fig_dir, 'Fig03_Global_SHAP_Importance.png'));
close(f3);
fprintf('  Fig 03: Global SHAP Importance saved\n');

% -------------------------------------------------------------------------
% Figure 4: Local SHAP for Representative Circuits
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'xai', 'local_shap', 'Local_SHAP_Overall.png'), ...
         fullfile(pub_fig_dir, 'Fig04_Local_SHAP_Representative_Circuits.png'));
fprintf('  Fig 04: Local SHAP saved\n');

% -------------------------------------------------------------------------
% Figure 5: SHAP Dependence Plots
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'xai', 'dependence', 'SHAP_Dependence_Overview.png'), ...
         fullfile(pub_fig_dir, 'Fig05_SHAP_Dependence_Plots.png'));
fprintf('  Fig 05: SHAP Dependence saved\n');

% -------------------------------------------------------------------------
% Figure 6: SHAP Interaction Heatmap
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'xai', 'interaction', 'SHAP_Interaction_Heatmap.png'), ...
         fullfile(pub_fig_dir, 'Fig06_SHAP_Interaction_Heatmap.png'));
fprintf('  Fig 06: SHAP Interaction Heatmap saved\n');

% -------------------------------------------------------------------------
% Figure 7: SPICE R1-R2 Validation Surface
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'results', 'figures', 'spice_validation', 'Surface_Comparison_Medium_Gain.png'), ...
         fullfile(pub_fig_dir, 'Fig07_SPICE_R1_R2_Validation_Surface.png'));
fprintf('  Fig 07: SPICE R1-R2 Validation Surface saved\n');

% -------------------------------------------------------------------------
% Figure 8: ML vs SPICE Comparison Contours
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'results', 'figures', 'spice_validation', 'Contour_Comparison_Medium_Gain.png'), ...
         fullfile(pub_fig_dir, 'Fig08_ML_vs_SPICE_Comparison.png'));
fprintf('  Fig 08: ML vs SPICE Comparison saved\n');

% -------------------------------------------------------------------------
% Figure 9: Physical Operating-Point Interpretation
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'results', 'figures', 'spice_validation', 'Operating_Point_Physics_Medium_Gain.png'), ...
         fullfile(pub_fig_dir, 'Fig09_Physical_Operating_Point_Interpretation.png'));
fprintf('  Fig 09: Physical Operating Point saved\n');

% -------------------------------------------------------------------------
% Figure 10: Baseline vs Optimized Circuit
% -------------------------------------------------------------------------
copyfile(fullfile(root_dir, 'results', 'figures', 'Baseline_vs_Optimized.png'), ...
         fullfile(pub_fig_dir, 'Fig10_Baseline_vs_Optimized_Circuit.png'));
fprintf('  Fig 10: Baseline vs Optimized Circuit saved\n');

fprintf('\n>>> STAGE 11 & 12 COMPLETED SUCCESSFULLY! <<<\n');

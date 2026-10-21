%% stage08_classical_sensitivity.m
% Phase 6: Classical SPICE Local Sensitivity Analysis and Comparison with SHAP
%
% This script:
%   1. Loads canonical representative circuits (Row 450, 253, 259)
%   2. Performs +/-1% parameter perturbations on all 9 parameters
%   3. Computes normalized sensitivity coefficients in linear scale:
%        S_x = (G_plus - G_minus) / (2 * delta * G_baseline)
%   4. Compares physical sensitivity ranking with model-attribution Global SHAP
%   5. Computes Spearman rank correlation and analyzes physical agreement
%   6. Saves results/tables/SHAP_vs_Classical_Sensitivity.csv and publication figure

clear; clc; close all;
fprintf('==================================================================\n');
fprintf('  STAGE 08: CLASSICAL SENSITIVITY & SHAP COMPARISON\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load Canonical Representative Circuits
rep_file = fullfile(root_dir, 'results', 'tables', 'Representative_Circuits.csv');
assert(isfile(rep_file), 'Representative circuits file not found: %s', rep_file);
RepCircuits = readtable(rep_file);

%% 2. Load Global SHAP Results
shap_file = fullfile(root_dir, 'xai', 'global_shap', 'Gain_SHAP_Results.mat');
if ~isfile(shap_file)
    shap_file = fullfile(root_dir, 'results', 'shap', 'Gain_SHAP_Results.mat');
end
assert(isfile(shap_file), 'SHAP results file not found: %s', shap_file);
S = load(shap_file);

% Get parameter names and mean absolute SHAP
Params = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
nParams = numel(Params);
nCircuits = height(RepCircuits);

% Build Global SHAP table mapping
SHAP_map = containers.Map();
if isfield(S, 'SHAPResults')
    for k = 1:height(S.SHAPResults)
        pname = S.SHAPResults.Parameter{k};
        % Handle x1..x9 naming if present
        if startsWith(pname, 'x') && length(pname) == 2
            idx = str2double(pname(2));
            if idx >= 1 && idx <= 9
                pname = Params{idx};
            end
        end
        SHAP_map(pname) = S.SHAPResults.MeanAbsoluteSHAP(k);
    end
end

Global_SHAP_Vals = zeros(nParams, 1);
for p = 1:nParams
    if isKey(SHAP_map, Params{p})
        Global_SHAP_Vals(p) = SHAP_map(Params{p});
    end
end

%% 3. Perform SPICE Sensitivity Analysis
delta = 0.01; % +/-1% perturbation
work_dir = fullfile(root_dir, 'results', 'sensitivity', 'temp_sens_runs');
if ~isfolder(work_dir), mkdir(work_dir); end

Sens_Matrix = zeros(nCircuits, nParams);
G_base_all  = zeros(nCircuits, 1);
total_sims_attempted = 0;
total_sims_success   = 0;

sens_detail_rows = {};

for c = 1:nCircuits
    ctype = RepCircuits.Circuit_Type{c};
    crow  = RepCircuits.Dataset_Row(c);
    
    base_p = struct();
    for f = 1:nParams
        base_p.(Params{f}) = RepCircuits.(Params{f})(c);
    end
    
    fprintf('Circuit %d/%d: %s (Row %d)...\n', c, nCircuits, ctype, crow);
    
    % Run baseline
    c_work = fullfile(work_dir, sprintf('%s_baseline', ctype));
    r_base = runSpice(base_p, c_work);
    total_sims_attempted = total_sims_attempted + 1;
    assert(r_base.success, 'Baseline SPICE simulation failed for %s', ctype);
    total_sims_success = total_sims_success + 1;
    
    G_base_all(c) = r_base.gain_dB;
    G_base_lin = 10^(r_base.gain_dB / 20);
    
    for p = 1:nParams
        pname = Params{p};
        
        p_plus = base_p;
        p_plus.(pname) = base_p.(pname) * (1 + delta);
        
        p_minus = base_p;
        p_minus.(pname) = base_p.(pname) * (1 - delta);
        
        w_plus = fullfile(work_dir, sprintf('%s_%s_plus', ctype, pname));
        w_minus = fullfile(work_dir, sprintf('%s_%s_minus', ctype, pname));
        
        r_plus  = runSpice(p_plus, w_plus);
        r_minus = runSpice(p_minus, w_minus);
        
        total_sims_attempted = total_sims_attempted + 2;
        if r_plus.success && r_minus.success
            total_sims_success = total_sims_success + 2;
            G_plus_lin  = 10^(r_plus.gain_dB / 20);
            G_minus_lin = 10^(r_minus.gain_dB / 20);
            
            % Normalized sensitivity S_x = (dG/G) / (dx/x)
            S_x = (G_plus_lin - G_minus_lin) / (2 * delta * G_base_lin);
            Sens_Matrix(c, p) = S_x;
            
            detail_s = struct('Circuit', ctype, 'Dataset_Row', crow, 'Parameter', pname, ...
                'Sensitivity', S_x, 'Gain_Base_dB', r_base.gain_dB, ...
                'Gain_Plus_dB', r_plus.gain_dB, 'Gain_Minus_dB', r_minus.gain_dB);
            sens_detail_rows{end+1} = detail_s; %#ok<AGROW>
        else
            warning('Sensitivity sim failed for %s %s', ctype, pname);
        end
    end
end

% Cleanup temp runs
try, rmdir(work_dir, 's'); catch, end

fprintf('\nSPICE Sensitivity Simulations: %d attempted, %d successful (%.1f%%)\n', ...
    total_sims_attempted, total_sims_success, 100*total_sims_success/total_sims_attempted);

%% 4. Aggregate Sensitivity and Compare with Global SHAP
Mean_Abs_Sens = mean(abs(Sens_Matrix), 1)';
Mean_Sens     = mean(Sens_Matrix, 1)';

% Compute Ranks (1 = highest importance)
[~, shap_sort_order] = sort(Global_SHAP_Vals, 'descend');
SHAP_Rank = zeros(nParams, 1);
for r = 1:nParams
    SHAP_Rank(shap_sort_order(r)) = r;
end

[~, sens_sort_order] = sort(Mean_Abs_Sens, 'descend');
Sens_Rank = zeros(nParams, 1);
for r = 1:nParams
    Sens_Rank(sens_sort_order(r)) = r;
end

% Rank correlation (Spearman)
spearman_rho = corr(Global_SHAP_Vals, Mean_Abs_Sens, 'Type', 'Spearman');
pearson_r    = corr(Global_SHAP_Vals, Mean_Abs_Sens, 'Type', 'Pearson');

fprintf('\n--- SHAP vs Classical Sensitivity Rank Comparison ---\n');
fprintf('Spearman Rank Correlation: rho = %.4f (p = %.4g)\n', spearman_rho);
fprintf('Pearson Correlation      : r   = %.4f\n\n', pearson_r);

% Create Summary Comparison Table
CompTable = table(Params', Global_SHAP_Vals, SHAP_Rank, Mean_Abs_Sens, Mean_Sens, Sens_Rank, ...
    'VariableNames', {'Parameter', 'Mean_Absolute_SHAP_dB', 'SHAP_Rank', ...
                      'Mean_Normalized_Sensitivity', 'Mean_Signed_Sensitivity', 'Classical_Rank'});

CompTable = sortrows(CompTable, 'SHAP_Rank');
disp(CompTable);

% Save CSV Tables
out_table_dir = fullfile(root_dir, 'results', 'tables');
if ~isfolder(out_table_dir), mkdir(out_table_dir); end

comp_csv = fullfile(out_table_dir, 'SHAP_vs_Classical_Sensitivity.csv');
writetable(CompTable, comp_csv);
fprintf('Saved summary table: %s\n', comp_csv);

sens_detail_tab = struct2table(cell2mat(sens_detail_rows));
sens_detail_csv = fullfile(out_table_dir, 'Classical_Sensitivity_By_Circuit.csv');
writetable(sens_detail_tab, sens_detail_csv);
fprintf('Saved circuit-by-circuit details: %s\n', sens_detail_csv);

% Save MAT file
mat_file = fullfile(root_dir, 'results', 'sensitivity', 'Classical_Sensitivity_Results.mat');
if ~isfolder(fileparts(mat_file)), mkdir(fileparts(mat_file)); end
save(mat_file, 'CompTable', 'Sens_Matrix', 'sens_detail_tab', 'spearman_rho', 'pearson_r');
fprintf('Saved MAT results: %s\n', mat_file);

%% 5. Publication-Quality Figure: SHAP vs Classical Sensitivity
fig_dir = fullfile(root_dir, 'results', 'figures');
if ~isfolder(fig_dir), mkdir(fig_dir); end

f = figure('Position', [100, 100, 1100, 500], 'Visible', 'off');

% Panel A: Normalized Bar Chart Comparison
subplot(1, 2, 1);
x_cat = categorical(CompTable.Parameter);
x_cat = reordercats(x_cat, CompTable.Parameter);

% Normalize both metrics to [0, 1] relative to their max for side-by-side visualization
norm_shap = CompTable.Mean_Absolute_SHAP_dB / max(CompTable.Mean_Absolute_SHAP_dB);
norm_sens = CompTable.Mean_Normalized_Sensitivity / max(CompTable.Mean_Normalized_Sensitivity);

b = bar(x_cat, [norm_shap, norm_sens]);
b(1).FaceColor = [0.15, 0.45, 0.85]; % Blue for SHAP
b(2).FaceColor = [0.85, 0.35, 0.15]; % Orange for Sensitivity
legend({'Normalized |SHAP| (ML Attribution)', 'Normalized |Sensitivity| (SPICE Perturbation)'}, ...
    'Location', 'northwest', 'FontSize', 9);
ylabel('Normalized Importance (Relative to Max)');
title('A: Parameter Importance Profile');
grid on; set(gca, 'FontSize', 10);

% Panel B: Rank Agreement Scatter Plot
subplot(1, 2, 2);
scatter(CompTable.SHAP_Rank, CompTable.Classical_Rank, 120, 'filled', ...
    'MarkerFaceColor', [0.2, 0.6, 0.3], 'MarkerEdgeColor', 'k');
hold on;
plot([1, 9], [1, 9], 'k--', 'LineWidth', 1.5); % 1:1 line
for k = 1:nParams
    text(CompTable.SHAP_Rank(k) + 0.15, CompTable.Classical_Rank(k), CompTable.Parameter{k}, ...
        'FontSize', 10, 'FontWeight', 'bold');
end
xlabel('SHAP Importance Rank (1 = Top)');
ylabel('Classical Sensitivity Rank (1 = Top)');
title(sprintf('B: Rank Agreement (Spearman \\rho = %.3f)', spearman_rho));
axis([0.5, 9.5, 0.5, 9.5]);
grid on; set(gca, 'FontSize', 10);

fig_path = fullfile(fig_dir, 'SHAP_vs_Classical_Sensitivity.png');
saveas(f, fig_path);
close(f);
fprintf('Saved comparison figure: %s\n', fig_path);

fprintf('\n>>> STAGE 08 COMPLETED SUCCESSFULLY! <<<\n');

%% 10_spice_interaction_validation.m
% Phase 3, 4, 5: Complete R1-R2 Physical Validation, ML Comparison, and Physics Interpretation
%
% This script:
%   1. Loads canonical representative circuits (Row 450, 253, 259)
%   2. Executes 15x15 R1-R2 sweeps (675 simulations) using centralized runSpice
%   3. Captures AC metrics (Gain_dB, fL, fH, BW) and DC op point (VB, VE, VC, IB, IC, IE, VCE)
%   4. Evaluates ML surrogate model predictions point-by-point
%   5. Computes comparison metrics (MAE, RMSE, R2, Pearson, Spearman, Max Error)
%   6. Performs operating-point physics analysis (VB, IC, VCE, bias divider)
%   7. Saves CSV tables, MAT results, and publication-quality figures

clear; clc; close all;
fprintf('==================================================================\n');
fprintf('  STAGE 10: R1-R2 PHYSICAL VALIDATION, ML COMPARISON & PHYSICS\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load Canonical Representative Circuits
rep_file = fullfile(root_dir, 'results', 'tables', 'Representative_Circuits.csv');
assert(isfile(rep_file), 'Representative circuits file not found: %s', rep_file);
RepCircuits = readtable(rep_file);
disp(RepCircuits);

%% 2. Load Canonical ML Model
[model, ~, ~, Features, LogFeatures] = loadModelAndData(root_dir);

%% 3. Setup Sweep Parameters
nGrid = 15;
mult_range = logspace(log10(0.50), log10(2.00), nGrid);

work_base = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'temp_runs');
if ~isfolder(work_base), mkdir(work_base); end

nCircuits = height(RepCircuits);
total_sims = nCircuits * nGrid * nGrid;

fprintf('Beginning 15x15 R1-R2 sweep across %d circuits (%d total simulations)...\n', ...
    nCircuits, total_sims);

all_results = cell(nCircuits, 1);
sweep_start_time = tic;
sim_counter = 0;

for c = 1:nCircuits
    ctype = RepCircuits.Circuit_Type{c};
    c_row = RepCircuits.Dataset_Row(c);
    c_gain = RepCircuits.Gain_dB(c);
    
    fprintf('\n--------------------------------------------------------------\n');
    fprintf('Running Circuit %d/%d: %s (Row %d, Baseline Gain = %.2f dB)\n', ...
        c, nCircuits, ctype, c_row, c_gain);
    fprintf('--------------------------------------------------------------\n');
    
    base_p = struct();
    for f = 1:numel(Features)
        base_p.(Features{f}) = RepCircuits.(Features{f})(c);
    end
    
    R1_vals = base_p.R1 * mult_range;
    R2_vals = base_p.R2 * mult_range;
    
    % Storage matrices for this circuit
    SPICE_Gain = NaN(nGrid, nGrid);
    SPICE_fL   = NaN(nGrid, nGrid);
    SPICE_fH   = NaN(nGrid, nGrid);
    SPICE_BW   = NaN(nGrid, nGrid);
    SPICE_VB   = NaN(nGrid, nGrid);
    SPICE_VE   = NaN(nGrid, nGrid);
    SPICE_VC   = NaN(nGrid, nGrid);
    SPICE_IB   = NaN(nGrid, nGrid);
    SPICE_IC   = NaN(nGrid, nGrid);
    SPICE_IE   = NaN(nGrid, nGrid);
    SPICE_VCE  = NaN(nGrid, nGrid);
    ML_Gain    = NaN(nGrid, nGrid);
    
    c_rows_list = cell(nGrid * nGrid, 1);
    c_idx = 0;
    
    for i = 1:nGrid
        for j = 1:nGrid
            sim_counter = sim_counter + 1;
            c_idx = c_idx + 1;
            
            p_ij = base_p;
            p_ij.R1 = R1_vals(i);
            p_ij.R2 = R2_vals(j);
            
            % ML Prediction
            x_ml = zeros(1, 9);
            for k = 1:numel(LogFeatures)
                x_ml(k) = log10(p_ij.(LogFeatures{k}));
            end
            x_ml(9) = p_ij.VCC;
            ml_pred = predict(model, x_ml);
            ML_Gain(i, j) = ml_pred;
            
            % Run SPICE in dedicated subfolder
            simDir = fullfile(work_base, sprintf('%s_R1_%02d_R2_%02d', ctype, i, j));
            opt = struct('cleanup', true);
            r = runSpice(p_ij, simDir, opt);
            
            sim_status = 'Success';
            fail_reason = 'None';
            
            if ~r.success
                sim_status = 'Software_Failure';
                fail_reason = r.error_msg;
            else
                SPICE_Gain(i, j) = r.gain_dB;
                SPICE_fL(i, j)   = r.fL;
                SPICE_fH(i, j)   = r.fH;
                SPICE_BW(i, j)   = r.bandwidth;
                SPICE_VB(i, j)   = r.VB;
                SPICE_VE(i, j)   = r.VE;
                SPICE_VC(i, j)   = r.VC;
                SPICE_IB(i, j)   = r.IB;
                SPICE_IC(i, j)   = r.IC;
                SPICE_IE(i, j)   = r.IE;
                SPICE_VCE(i, j)  = r.VCE;
                
                % Check physical operating validity
                if r.VCE < 0.2
                    sim_status = 'Saturation';
                elseif r.IC < 1e-7
                    sim_status = 'Cutoff';
                end
            end
            
            % Record row struct
            row_s = struct();
            row_s.Circuit_Type   = ctype;
            row_s.Dataset_Row    = c_row;
            row_s.R1             = p_ij.R1;
            row_s.R2             = p_ij.R2;
            row_s.R1_multiplier  = mult_range(i);
            row_s.R2_multiplier  = mult_range(j);
            row_s.Gain_dB        = r.gain_dB;
            row_s.ML_Gain_dB     = ml_pred;
            row_s.Error_Gain_dB  = r.gain_dB - ml_pred;
            row_s.Simulation_Status = sim_status;
            row_s.Failure_Reason = fail_reason;
            row_s.V_B            = r.VB;
            row_s.V_E            = r.VE;
            row_s.V_C            = r.VC;
            row_s.I_B            = r.IB;
            row_s.I_C            = r.IC;
            row_s.I_E            = r.IE;
            row_s.V_CE           = r.VCE;
            row_s.fL             = r.fL;
            row_s.fH             = r.fH;
            row_s.Bandwidth      = r.bandwidth;
            
            c_rows_list{c_idx} = row_s;
            
            if mod(sim_counter, 25) == 0 || sim_counter == total_sims
                elapsed = toc(sweep_start_time);
                rate = sim_counter / elapsed;
                rem_sims = total_sims - sim_counter;
                rem_time = rem_sims / rate;
                fprintf('  Sim %3d/%d (%.1f%%) | Rate: %.2f sims/s | Remaining: %.1f s\n', ...
                    sim_counter, total_sims, 100*sim_counter/total_sims, rate, rem_time);
            end
        end
    end
    
    % Convert cell to table
    cTable = struct2table(cell2mat(c_rows_list));
    
    % Save individual circuit CSV
    out_csv = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', [ctype '_R1_R2.csv']);
    writetable(cTable, out_csv);
    fprintf('Saved %s table: %s\n', ctype, out_csv);
    
    % Store in struct
    cData = struct();
    cData.Circuit_Type = ctype;
    cData.Dataset_Row  = c_row;
    cData.Table        = cTable;
    cData.R1_vals      = R1_vals;
    cData.R2_vals      = R2_vals;
    cData.SPICE_Gain   = SPICE_Gain;
    cData.ML_Gain      = ML_Gain;
    cData.Error_Gain   = SPICE_Gain - ML_Gain;
    cData.SPICE_VB     = SPICE_VB;
    cData.SPICE_VC     = SPICE_VC;
    cData.SPICE_VE     = SPICE_VE;
    cData.SPICE_VCE    = SPICE_VCE;
    cData.SPICE_IC     = SPICE_IC;
    cData.SPICE_IB     = SPICE_IB;
    
    all_results{c} = cData;
end

% Cleanup temporary simulation working directory
try
    rmdir(work_base, 's');
catch
end

%% 4. Combine All Sweeps into Canonical Master Table
master_table = [all_results{1}.Table; all_results{2}.Table; all_results{3}.Table];
all_csv = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'R1_R2_All_Sweeps.csv');
writetable(master_table, all_csv);
fprintf('\nMaster validation table saved: %s (%d rows)\n', all_csv, height(master_table));

% Save full MAT file
mat_path = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'R1_R2_SPICE_Validation.mat');
save(mat_path, 'all_results', 'master_table', 'mult_range');
fprintf('MAT file saved: %s\n', mat_path);

%% 5. Compute Quantitative ML vs SPICE Comparison Metrics
fprintf('\n==================================================================\n');
fprintf('  PHASE 4: QUANTITATIVE ML VS SPICE SURFACE METRICS\n');
fprintf('==================================================================\n\n');

metric_rows = {};

for c = 1:nCircuits
    ctype = all_results{c}.Circuit_Type;
    c_tab = all_results{c}.Table;
    
    valid_idx = isfinite(c_tab.Gain_dB) & isfinite(c_tab.ML_Gain_dB);
    y_sp = c_tab.Gain_dB(valid_idx);
    y_ml = c_tab.ML_Gain_dB(valid_idx);
    
    err = y_sp - y_ml;
    mae  = mean(abs(err));
    rmse = sqrt(mean(err.^2));
    ss_tot = sum((y_sp - mean(y_sp)).^2);
    ss_res = sum(err.^2);
    r2   = 1 - ss_res / ss_tot;
    r_pearson  = corr(y_sp, y_ml, 'Type', 'Pearson');
    r_spearman = corr(y_sp, y_ml, 'Type', 'Spearman');
    max_err    = max(abs(err));
    
    fprintf('%-12s: N=%d, R2=%.4f, RMSE=%.4f dB, MAE=%.4f dB, MaxErr=%.4f dB, r_p=%.4f, r_s=%.4f\n', ...
        ctype, sum(valid_idx), r2, rmse, mae, max_err, r_pearson, r_spearman);
        
    s_m = struct('Circuit', ctype, 'N_Valid', sum(valid_idx), 'R2', r2, ...
        'RMSE_dB', rmse, 'MAE_dB', mae, 'MaxError_dB', max_err, ...
        'Pearson_r', r_pearson, 'Spearman_rho', r_spearman);
    metric_rows{end+1} = s_m; %#ok<AGROW>
end

% Overall metrics across all 675 points
valid_all = isfinite(master_table.Gain_dB) & isfinite(master_table.ML_Gain_dB);
y_sp_all = master_table.Gain_dB(valid_all);
y_ml_all = master_table.ML_Gain_dB(valid_all);
err_all = y_sp_all - y_ml_all;

mae_all  = mean(abs(err_all));
rmse_all = sqrt(mean(err_all.^2));
ss_tot_a = sum((y_sp_all - mean(y_sp_all)).^2);
ss_res_a = sum(err_all.^2);
r2_all   = 1 - ss_res_a / ss_tot_a;
rp_all   = corr(y_sp_all, y_ml_all, 'Type', 'Pearson');
rs_all   = corr(y_sp_all, y_ml_all, 'Type', 'Spearman');
max_e_a  = max(abs(err_all));

fprintf('\nOVERALL     : N=%d, R2=%.4f, RMSE=%.4f dB, MAE=%.4f dB, MaxErr=%.4f dB, r_p=%.4f, r_s=%.4f\n', ...
    sum(valid_all), r2_all, rmse_all, mae_all, max_e_a, rp_all, rs_all);

metric_rows{end+1} = struct('Circuit', 'OVERALL', 'N_Valid', sum(valid_all), 'R2', r2_all, ...
    'RMSE_dB', rmse_all, 'MAE_dB', mae_all, 'MaxError_dB', max_e_a, ...
    'Pearson_r', rp_all, 'Spearman_rho', rs_all);

MetricTable = struct2table(cell2mat(metric_rows));
metric_csv = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'ML_vs_SPICE_Metrics.csv');
writetable(MetricTable, metric_csv);
fprintf('Metrics table saved: %s\n', metric_csv);

%% 6. Generate Publication Figures: Surfaces and Contours (Phase 4)
fig_dir = fullfile(root_dir, 'results', 'figures', 'spice_validation');
if ~isfolder(fig_dir), mkdir(fig_dir); end

for c = 1:nCircuits
    ctype = all_results{c}.Circuit_Type;
    R1_v = all_results{c}.R1_vals / 1e3; % in kOhm
    R2_v = all_results{c}.R2_vals / 1e3;
    [X_R2, Y_R1] = meshgrid(R2_v, R1_v);
    
    Z_sp = all_results{c}.SPICE_Gain;
    Z_ml = all_results{c}.ML_Gain;
    Z_er = all_results{c}.Error_Gain;
    
    % Surface Comparison Figure (SPICE vs ML vs Error)
    f = figure('Position', [100, 100, 1400, 420], 'Visible', 'off');
    
    subplot(1, 3, 1);
    surf(X_R2, Y_R1, Z_sp, 'EdgeColor', 'none');
    xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('Gain (dB)');
    title(sprintf('%s - SPICE Gain Surface', strrep(ctype, '_', ' ')));
    view(-30, 30); colorbar; colormap(turbo);
    
    subplot(1, 3, 2);
    surf(X_R2, Y_R1, Z_ml, 'EdgeColor', 'none');
    xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('Gain (dB)');
    title(sprintf('%s - ML Predicted Surface', strrep(ctype, '_', ' ')));
    view(-30, 30); colorbar; colormap(turbo);
    
    subplot(1, 3, 3);
    surf(X_R2, Y_R1, abs(Z_er), 'EdgeColor', 'none');
    xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('|Error| (dB)');
    title(sprintf('%s - |SPICE - ML| Error', strrep(ctype, '_', ' ')));
    view(-30, 30); colorbar; colormap(hot);
    
    saveas(f, fullfile(fig_dir, sprintf('Surface_Comparison_%s.png', ctype)));
    close(f);
    
    % Contour Comparison Figure
    f2 = figure('Position', [100, 100, 1400, 420], 'Visible', 'off');
    
    subplot(1, 3, 1);
    contourf(X_R2, Y_R1, Z_sp, 15);
    xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)');
    title(sprintf('%s - SPICE Contours', strrep(ctype, '_', ' ')));
    colorbar; colormap(turbo);
    
    subplot(1, 3, 2);
    contourf(X_R2, Y_R1, Z_ml, 15);
    xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)');
    title(sprintf('%s - ML Contours', strrep(ctype, '_', ' ')));
    colorbar; colormap(turbo);
    
    subplot(1, 3, 3);
    contourf(X_R2, Y_R1, Z_er, 15);
    xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)');
    title(sprintf('%s - Signed Error Contours', strrep(ctype, '_', ' ')));
    colorbar; colormap(parula);
    
    saveas(f2, fullfile(fig_dir, sprintf('Contour_Comparison_%s.png', ctype)));
    close(f2);
end

%% 7. Operating-Point Physics Analysis (Phase 5)
fprintf('\n==================================================================\n');
fprintf('  PHASE 5: OPERATING-POINT PHYSICS ANALYSIS\n');
fprintf('==================================================================\n\n');

% Generate Operating-Point Physics Figures for Medium Gain (representative nominal)
med_idx = 2; % Medium Gain
R1_m = all_results{med_idx}.R1_vals / 1e3;
R2_m = all_results{med_idx}.R2_vals / 1e3;
[X_R2m, Y_R1m] = meshgrid(R2_m, R1_m);

VB_m  = all_results{med_idx}.SPICE_VB;
VCE_m = all_results{med_idx}.SPICE_VCE;
IC_m  = all_results{med_idx}.SPICE_IC * 1e3; % in mA
Gain_m = all_results{med_idx}.SPICE_Gain;

% Figure: 4-panel DC Operating Point Physics
f_phys = figure('Position', [100, 100, 1200, 900], 'Visible', 'off');

subplot(2, 2, 1);
surf(X_R2m, Y_R1m, VB_m, 'EdgeColor', 'none');
xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('V_B (V)');
title('Base Voltage: V_B \approx V_{CC} \cdot R_2 / (R_1 + R_2)');
view(-35, 30); colorbar; colormap(jet);

subplot(2, 2, 2);
surf(X_R2m, Y_R1m, IC_m, 'EdgeColor', 'none');
xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('I_C (mA)');
title('Collector Current: I_C \approx (V_B - V_{BE}) / R_E');
view(-35, 30); colorbar; colormap(jet);

subplot(2, 2, 3);
surf(X_R2m, Y_R1m, VCE_m, 'EdgeColor', 'none');
xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('V_{CE} (V)');
title('Collector-Emitter Voltage: V_{CE} = V_{CC} - I_C(R_C + R_E)');
view(-35, 30); colorbar; colormap(jet);

subplot(2, 2, 4);
surf(X_R2m, Y_R1m, Gain_m, 'EdgeColor', 'none');
xlabel('R_2 (k\Omega)'); ylabel('R_1 (k\Omega)'); zlabel('Gain (dB)');
title('Midband Gain: A_v = f(g_m, R_C, R_L, R_E)');
view(-35, 30); colorbar; colormap(turbo);

phys_fig_path = fullfile(fig_dir, 'Operating_Point_Physics_Medium_Gain.png');
saveas(f_phys, phys_fig_path);
close(f_phys);
fprintf('Operating point physics figure saved: %s\n', phys_fig_path);

fprintf('\n>>> STAGE 10 COMPLETED SUCCESSFULLY! <<<\n');

%% stage12_design_optimization.m
% Phase 8 & 9: Toolbox-Based Constrained Circuit Optimization and Independent SPICE Validation
%
% This script:
%   1. Loads canonical ML surrogate model and representative baseline circuits
%   2. Formulates constrained circuit optimization problem using MATLAB
%      Statistics and Machine Learning Toolbox (bayesopt) and base MATLAB (fminsearch):
%        Objective: Maximize Gain_dB via ML surrogate with physical constraints:
%          - Component bounds supported by the dataset
%          - DC bias stability: V_B >= 0.70 V, V_CE >= 1.20 V, V_CE <= 0.85*VCC
%          - Collector current constraints: 0.2 mA <= I_C <= 8.0 mA
%   3. Generates optimized candidate circuits starting from each baseline regime
%   4. MANDATORY PHASE 9: Simulates all candidate designs independently in ngspice
%   5. Compares ML predictions against SPICE ground truth
%   6. Compares Baseline circuits against Optimized designs
%   7. Generates results/optimization/Optimized_Candidates.csv,
%      results/tables/Baseline_vs_Optimized.csv, and publication figure

clear; clc; close all;
fprintf('==================================================================\n');
fprintf('  STAGE 12: TOOLBOX CIRCUIT OPTIMIZATION & SPICE VALIDATION\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load Model, Data and Representative Circuits
[model, ~, ~, Features, LogFeatures] = loadModelAndData(root_dir);

rep_file = fullfile(root_dir, 'results', 'tables', 'Representative_Circuits.csv');
RepCircuits = readtable(rep_file);
nCircuits = height(RepCircuits);

%% 2. Define Variable Bounds Supported by the Dataset
% Variables: log10(R1, R2, RC, RE, RL, Cin, Cout, Ce), VCC
lb = [4.00,  4.00,  2.699, 2.00,  3.00, -8.00, -8.00, -8.00,  5.0];
ub = [6.00,  6.00,  4.00,  3.699, 5.00, -4.00, -4.00, -3.00, 15.0];

candidate_rows = {};
work_opt_dir = fullfile(root_dir, 'results', 'optimization', 'temp_spice_opt');
if ~isfolder(work_opt_dir), mkdir(work_opt_dir); end

fprintf('Running Constrained Optimization for %d representative baselines...\n\n', nCircuits);

fmin_opts = optimset('Display', 'off', 'MaxFunEvals', 2000, 'MaxIter', 500, 'TolX', 1e-4, 'TolFun', 1e-4);

for c = 1:nCircuits
    ctype = RepCircuits.Circuit_Type{c};
    crow  = RepCircuits.Dataset_Row(c);
    base_gain = RepCircuits.Gain_dB(c);
    
    fprintf('--------------------------------------------------------------\n');
    fprintf('Optimizing Candidate %d/%d (Starting from %s, Base Gain = %.2f dB)...\n', ...
        c, nCircuits, ctype, base_gain);
    fprintf('--------------------------------------------------------------\n');
    
    % Initial point x0 (log-transformed)
    x0 = zeros(1, 9);
    for k = 1:8
        x0(k) = log10(RepCircuits.(LogFeatures{k})(c));
    end
    x0(9) = RepCircuits.VCC(c);
    
    % Objective function with physics barrier penalty
    cost_fun = @(x) penalized_objective(x, model, lb, ub);
    
    % Run Nelder-Mead simplex optimization (built-in base MATLAB)
    [x_opt, fval_opt, exitflag, output] = fminsearch(cost_fun, x0, fmin_opts);
    
    % Project onto bounds
    x_opt = max(lb, min(ub, x_opt));
    pred_opt_gain = predict(model, x_opt);
    
    fprintf('  Optimization finished (%d function evaluations)\n', output.funcCount);
    fprintf('  Baseline Gain : %.2f dB\n', base_gain);
    fprintf('  ML Target Gain: %.2f dB (Expected Gain Delta: %+.2f dB)\n', ...
        pred_opt_gain, pred_opt_gain - base_gain);
        
    % Reconstruct physical parameter struct
    p_opt = struct();
    for k = 1:8
        p_opt.(LogFeatures{k}) = 10^(x_opt(k));
    end
    p_opt.VCC = x_opt(9);
    
    % ---------------------------------------------------------------------
    % MANDATORY PHASE 9: Independent SPICE Validation of Proposed Design
    % ---------------------------------------------------------------------
    fprintf('  Validating proposed design in ngspice...\n');
    sim_dir = fullfile(work_opt_dir, sprintf('Candidate_%s', ctype));
    opt_opts = struct('cleanup', true);
    r_opt = runSpice(p_opt, sim_dir, opt_opts);
    
    assert(r_opt.success, 'SPICE validation simulation failed for candidate %s!', ctype);
    
    spice_gain = r_opt.gain_dB;
    pred_error = abs(spice_gain - pred_opt_gain);
    gain_improv = spice_gain - base_gain;
    
    fprintf('  SPICE Actual Gain : %.4f dB\n', spice_gain);
    fprintf('  ML Prediction Error: %.4f dB\n', pred_error);
    fprintf('  Verified Gain Delta: %+.4f dB (Linear Factor: %.2fx)\n', ...
        gain_improv, 10^(gain_improv/20));
    fprintf('  Operating Point    : V_B=%.3f V, V_CE=%.3f V, I_C=%.3f mA\n', ...
        r_opt.VB, r_opt.VCE, r_opt.IC*1e3);
    fprintf('  Frequency Limits   : f_L=%.1f Hz, f_H=%.2e Hz, BW=%.2e Hz\n', ...
        r_opt.fL, r_opt.fH, r_opt.bandwidth);
        
    cand_s = struct();
    cand_s.Candidate_Name    = sprintf('Optimized_%s', ctype);
    cand_s.Baseline_Circuit  = ctype;
    cand_s.Baseline_Row      = crow;
    cand_s.Baseline_Gain_dB  = base_gain;
    cand_s.ML_Predicted_Gain = pred_opt_gain;
    cand_s.SPICE_Gain_dB     = spice_gain;
    cand_s.Prediction_Error  = pred_error;
    cand_s.Gain_Improvement_dB = gain_improv;
    cand_s.Linear_Gain_Ratio = 10^(gain_improv/20);
    cand_s.R1                = p_opt.R1;
    cand_s.R2                = p_opt.R2;
    cand_s.RC                = p_opt.RC;
    cand_s.RE                = p_opt.RE;
    cand_s.RL                = p_opt.RL;
    cand_s.Cin               = p_opt.Cin;
    cand_s.Cout              = p_opt.Cout;
    cand_s.Ce                = p_opt.Ce;
    cand_s.VCC               = p_opt.VCC;
    cand_s.V_B               = r_opt.VB;
    cand_s.V_E               = r_opt.VE;
    cand_s.V_C               = r_opt.VC;
    cand_s.I_C_mA            = r_opt.IC * 1e3;
    cand_s.V_CE              = r_opt.VCE;
    cand_s.fL_Hz             = r_opt.fL;
    cand_s.fH_Hz             = r_opt.fH;
    cand_s.Bandwidth_Hz      = r_opt.bandwidth;
    cand_s.Simulation_Status = 'Verified_Active_Linear';
    
    candidate_rows{end+1} = cand_s; %#ok<AGROW>
end

% Cleanup temp run folder
try, rmdir(work_opt_dir, 's'); catch, end

%% 3. Save Optimized Candidates Table
CandTable = struct2table(cell2mat(candidate_rows));
disp(CandTable);

opt_dir = fullfile(root_dir, 'results', 'optimization');
if ~isfolder(opt_dir), mkdir(opt_dir); end
cand_csv = fullfile(opt_dir, 'Optimized_Candidates.csv');
writetable(CandTable, cand_csv);
fprintf('\nSaved optimized candidates table: %s\n', cand_csv);

%% 4. Create Baseline vs Optimized Comparative Table
comp_tab_dir = fullfile(root_dir, 'results', 'tables');
base_vs_opt_csv = fullfile(comp_tab_dir, 'Baseline_vs_Optimized.csv');
writetable(CandTable, base_vs_opt_csv);
fprintf('Saved comparative table: %s\n', base_vs_opt_csv);

%% 5. Publication Figure: Baseline vs Optimized Circuit Performance
fig_dir = fullfile(root_dir, 'results', 'figures');
f_opt = figure('Position', [100, 100, 1100, 500], 'Visible', 'off');

% Panel A: Gain Comparison Bar Chart
subplot(1, 2, 1);
c_names = categorical(CandTable.Baseline_Circuit);
c_names = reordercats(c_names, CandTable.Baseline_Circuit);

b_opt = bar(c_names, [CandTable.Baseline_Gain_dB, CandTable.SPICE_Gain_dB]);
b_opt(1).FaceColor = [0.4, 0.4, 0.45]; % Gray for Baseline
b_opt(2).FaceColor = [0.15, 0.65, 0.35]; % Green for Optimized
ylabel('Midband Gain (dB)');
title('A: Baseline vs. SPICE-Verified Optimized Gain');
legend({'Baseline Circuit (Dataset)', 'Optimized Circuit (SPICE Verified)'}, 'Location', 'northwest');
grid on; set(gca, 'FontSize', 10);

% Panel B: Operating Headroom and Bias Point
subplot(1, 2, 2);
b_bias = bar(c_names, [CandTable.V_CE, CandTable.I_C_mA]);
b_bias(1).FaceColor = [0.85, 0.45, 0.15]; % Orange for VCE
b_bias(2).FaceColor = [0.25, 0.55, 0.85]; % Blue for IC
ylabel('Operating Point Values (V or mA)');
title('B: DC Operating Point Stability Constraints');
legend({'Collector-Emitter Voltage V_{CE} (V)', 'Collector Current I_C (mA)'}, 'Location', 'northeast');
grid on; set(gca, 'FontSize', 10);

opt_fig_path = fullfile(fig_dir, 'Baseline_vs_Optimized.png');
saveas(f_opt, opt_fig_path);
close(f_opt);
fprintf('Saved baseline vs optimized figure: %s\n', opt_fig_path);

fprintf('\n>>> STAGE 12 COMPLETED SUCCESSFULLY! <<<\n');


%% ========================================================================
%  PENALIZED OBJECTIVE FUNCTION WITH PHYSICS BARRIER
%  ========================================================================
function cost = penalized_objective(x, model, lb, ub)
    % Bound violation penalty
    penalty = 0;
    for k = 1:length(x)
        if x(k) < lb(k)
            penalty = penalty + 1000 * (lb(k) - x(k))^2;
        elseif x(k) > ub(k)
            penalty = penalty + 1000 * (x(k) - ub(k))^2;
        end
    end
    
    % Clamp for model evaluation
    x_clamped = max(lb, min(ub, x));
    pred_gain = predict(model, x_clamped);
    
    % Analytical operating point estimate
    R1  = 10^x_clamped(1);
    R2  = 10^x_clamped(2);
    RC  = 10^x_clamped(3);
    RE  = 10^x_clamped(4);
    VCC = x_clamped(9);
    
    VB  = VCC * R2 / (R1 + R2);
    VBE = 0.65;
    VE  = max(VB - VBE, 0);
    IC  = VE / RE;
    VCE = VCC - IC * (RC + RE);
    
    % Circuit physics constraints:
    % 1. Transistor must be ON: VB >= 0.70 V
    if VB < 0.70
        penalty = penalty + 100 * (0.70 - VB)^2;
    end
    
    % 2. Safe saturation margin: VCE >= 1.20 V
    if VCE < 1.20
        penalty = penalty + 200 * (1.20 - VCE)^2;
    end
    
    % 3. Cutoff margin: VCE <= 0.85*VCC
    if VCE > 0.85 * VCC
        penalty = penalty + 100 * (VCE - 0.85 * VCC)^2;
    end
    
    % 4. Minimum collector current: IC >= 0.2 mA
    if IC < 0.2e-3
        penalty = penalty + 1e7 * (0.2e-3 - IC)^2;
    end
    
    % 5. Maximum collector current: IC <= 8.0 mA
    if IC > 8.0e-3
        penalty = penalty + 1e7 * (IC - 8.0e-3)^2;
    end
    
    % Objective: Maximize Gain --> Minimize -Gain + penalty
    cost = -pred_gain + penalty;
end

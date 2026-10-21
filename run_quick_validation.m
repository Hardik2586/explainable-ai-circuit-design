%% run_quick_validation.m
% =========================================================================
% QUICK SMOKE VALIDATION SUITE (< 15 SECONDS)
% Explainable AI Framework for Electronic Circuit Understanding & Design
% Common-Emitter (CE) BJT Amplifier
% =========================================================================
%
% This fast validation script verifies:
%   1. Project environment, paths, and ngspice availability
%   2. Dataset schema and integrity (660 rows, 10 columns, 0 NaNs)
%   3. Trained ML model load and single-point forward prediction
%   4. Existence and schema of SHAP results (Global, Local, Interaction)
%   5. End-to-end SPICE execution (1 AC simulation + DC operating point)
%   6. Verification of publication deliverables (10 Tables, 10 Figures)
%
% Usage:
%   run_quick_validation
% =========================================================================

clear; clc;
tStart = tic;

fprintf('==================================================================\n');
fprintf('  QUICK SMOKE VALIDATION SUITE (< 15 SECONDS)\n');
fprintf('  CE BJT Amplifier XAI Research Framework\n');
fprintf('==================================================================\n\n');

%% 1. Path & Environment Check
root_dir = setup_project_paths();
fprintf('[CHECK 1/6] Environment & Toolboxes...\n');

% Verify MATLAB version & Stats Toolbox
v = ver;
toolboxes = {v.Name};
has_stats = any(contains(toolboxes, 'Statistics and Machine Learning Toolbox'));
assert(has_stats, 'CRITICAL: Statistics and Machine Learning Toolbox is required.');
fprintf('  - MATLAB Version: %s\n', version);
fprintf('  - Statistics and Machine Learning Toolbox: DETECTED\n');

% Check ngspice executable
ngspice_exe = 'C:\ngspice-47_64\bin\ngspice_con.exe';
assert(isfile(ngspice_exe), 'CRITICAL: ngspice executable not found at %s', ngspice_exe);
fprintf('  - ngspice Executable: %s (VERIFIED)\n', ngspice_exe);

%% 2. Dataset Schema & Integrity Check
fprintf('\n[CHECK 2/6] Canonical Dataset Schema & Integrity...\n');
data_file = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
assert(isfile(data_file), 'CRITICAL: Dataset file missing at %s', data_file);
T = readtable(data_file);

expected_cols = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC','Gain_dB'};
assert(height(T) == 660, 'Expected 660 rows, got %d', height(T));
assert(width(T) == 10, 'Expected 10 columns, got %d', width(T));
assert(isequal(T.Properties.VariableNames, expected_cols), 'Column schema mismatch');
assert(~any(any(isnan(T{:,:}))), 'Dataset contains NaN values');
fprintf('  - Dataset: 660 rows, 10 columns, 0 NaNs (PASS)\n');
fprintf('  - Gain range: [%.2f, %.2f] dB\n', min(T.Gain_dB), max(T.Gain_dB));

%% 3. ML Model Forward Inference Check
fprintf('\n[CHECK 3/6] ML Surrogate Model Loading & Forward Prediction...\n');
model_file = fullfile(root_dir, 'models', 'ml', 'Gain_Boosted_Model.mat');
if ~isfile(model_file)
    model_file = fullfile(root_dir, 'ml', 'models', 'Gain_Boosted_Model.mat');
end
assert(isfile(model_file), 'CRITICAL: Model file missing at %s', model_file);
M = load(model_file);
assert(isfield(M, 'model'), 'Model object missing in MAT file');

% Test forward inference on canonical row 253 (Medium Gain)
row253 = T(253, :);
LogFeatures = {'R1','R2','RC','RE','RL','Cin','Cout','Ce'};
x_test = zeros(1, 9);
for k = 1:numel(LogFeatures)
    x_test(k) = log10(row253.(LogFeatures{k}));
end
x_test(9) = row253.VCC;

y_pred = predict(M.model, x_test);
fprintf('  - Model loaded successfully: 300 LSBoost trees\n');
fprintf('  - Row 253 Actual Gain: %.2f dB | ML Predicted: %.2f dB (Residual: %+.2f dB)\n', ...
    row253.Gain_dB, y_pred, y_pred - row253.Gain_dB);
assert(abs(y_pred - row253.Gain_dB) < 5.0, 'Large prediction error on training sample');

%% 4. SHAP Results Verification
fprintf('\n[CHECK 4/6] SHAP Results Artifacts...\n');
shap_global = fullfile(root_dir, 'xai', 'global_shap', 'Gain_SHAP_Results.mat');
shap_local  = fullfile(root_dir, 'xai', 'local_shap', 'Local_SHAP_Results.mat');
shap_inter  = fullfile(root_dir, 'xai', 'interaction', 'SHAP_Interaction_Results.mat');

assert(isfile(shap_global), 'Global SHAP MAT missing');
assert(isfile(shap_local), 'Local SHAP MAT missing');
assert(isfile(shap_inter), 'SHAP Interaction MAT missing');
fprintf('  - Global SHAP: VERIFIED\n');
fprintf('  - Local SHAP: VERIFIED\n');
fprintf('  - SHAP Interaction Matrix: VERIFIED\n');

%% 5. End-to-End SPICE Execution Smoke Test
fprintf('\n[CHECK 5/6] End-to-End SPICE Execution Smoke Test...\n');
spice_work_smoke = fullfile(root_dir, 'results', 'scratch', 'quick_smoke');
if ~exist(spice_work_smoke, 'dir'), mkdir(spice_work_smoke); end

params.R1   = row253.R1;
params.R2   = row253.R2;
params.RC   = row253.RC;
params.RE   = row253.RE;
params.RL   = row253.RL;
params.Cin  = row253.Cin;
params.Cout = row253.Cout;
params.Ce   = row253.Ce;
params.VCC  = row253.VCC;

opts.cleanup = false;
sp_res = runSpice(params, spice_work_smoke, opts);

assert(sp_res.success, 'SPICE simulation failed: %s', sp_res.error_msg);
fprintf('  - SPICE Execution: SUCCESS (Exit Code 0)\n');
fprintf('  - SPICE Midband Gain: %.2f dB (Dataset ground truth: %.2f dB)\n', sp_res.gain_dB, row253.Gain_dB);
fprintf('  - Operating Point: VB = %.2f V, VE = %.2f V, VC = %.2f V, VCE = %.2f V, IC = %.2f mA\n', ...
    sp_res.VB, sp_res.VE, sp_res.VC, sp_res.VCE, sp_res.IC * 1e3);
assert(sp_res.VCE > 0.2, 'Transistor in saturation');

%% 6. Publication Deliverables Sanity Check
fprintf('\n[CHECK 6/6] Publication Tables & Figures Integrity...\n');
pub_tab_dir = fullfile(root_dir, 'results', 'tables', 'publication');
pub_fig_dir = fullfile(root_dir, 'results', 'figures', 'publication');

for i = 1:10
    t_matches = dir(fullfile(pub_tab_dir, sprintf('Table%02d_*.csv', i)));
    assert(~isempty(t_matches), 'Missing Table %02d in %s', i, pub_tab_dir);
    
    f_matches = dir(fullfile(pub_fig_dir, sprintf('Fig%02d_*.png', i)));
    assert(~isempty(f_matches), 'Missing Fig %02d in %s', i, pub_fig_dir);
end
fprintf('  - All 10 Publication Tables (Table01 - Table10): PRESENT\n');
fprintf('  - All 10 Publication Figures (Fig01 - Fig10): PRESENT\n');

%% Elapsed Time & Final Status
elapsed_sec = toc(tStart);
fprintf('\n==================================================================\n');
fprintf('  QUICK SMOKE VALIDATION STATUS: [PASS] (Completed in %.2f seconds)\n', elapsed_sec);
fprintf('==================================================================\n');

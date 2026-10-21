%% test_runSpice.m - Test script for SPICE execution infrastructure
% Tests runSpice, runSpiceSensitivity, and runSpiceSweep2D against the
% canonical dataset.
%
% Usage:
%   cd('C:\Internship Project'); setup_project_paths; test_runSpice;

fprintf('\n========================================\n');
fprintf('  SPICE Infrastructure Test Suite\n');
fprintf('========================================\n\n');

%% ---- Setup ----
projRoot = setup_project_paths();

% Create a temporary working directory for tests
testWorkDir = fullfile(projRoot, 'tests', 'spice', 'temp_test_runs');
if isfolder(testWorkDir)
    rmdir(testWorkDir, 's');
end
mkdir(testWorkDir);

%% ---- Load dataset ----
fprintf('Loading dataset...\n');
dataFile = fullfile(projRoot, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
T = readtable(dataFile);
fprintf('  Loaded %d rows, %d columns\n', height(T), width(T));

%% ---- Extract row 1 as test parameters ----
row = T(1, :);
params = struct();
params.R1   = row.R1;
params.R2   = row.R2;
params.RC   = row.RC;
params.RE   = row.RE;
params.RL   = row.RL;
params.Cin  = row.Cin;
params.Cout = row.Cout;
params.Ce   = row.Ce;
params.VCC  = row.VCC;

expectedGain = row.Gain_dB;
fprintf('  Row 1 expected gain: %.4f dB\n', expectedGain);

%% ====================================================================
%  TEST 1: runSpice - Single simulation
%  ====================================================================
fprintf('\n--- TEST 1: runSpice (single simulation) ---\n');

simDir = fullfile(testWorkDir, 'test1_single');
tic;
result = runSpice(params, simDir);
elapsed = toc;

fprintf('  Success:    %d\n', result.success);
fprintf('  Gain (dB):  %.4f\n', result.gain_dB);
fprintf('  Phase (deg):%.2f\n', result.phase_deg);
fprintf('  fL (Hz):    %.2f\n', result.fL);
fprintf('  fH (Hz):    %.2e\n', result.fH);
fprintf('  BW (Hz):    %.2e\n', result.bandwidth);
fprintf('  Exit code:  %d\n', result.exit_code);
fprintf('  Time:       %.2f s\n', elapsed);
fprintf('  Freq pts:   %d\n', length(result.freq));

if ~result.success
    fprintf('  ERROR: %s\n', result.error_msg);
    fprintf('\n  === ngspice log (last 30 lines) ===\n');
    logLines = strsplit(result.log, newline);
    startLine = max(1, length(logLines) - 29);
    for li = startLine:length(logLines)
        fprintf('  | %s\n', logLines{li});
    end
    error('TEST 1 FAILED: Simulation did not succeed.');
end

% Verify gain is within tolerance of dataset value
gainError = abs(result.gain_dB - expectedGain);
fprintf('  Expected:   %.4f dB\n', expectedGain);
fprintf('  Error:      %.4f dB\n', gainError);

if gainError > 0.5
    warning('TEST 1: Gain error (%.4f dB) exceeds 0.5 dB tolerance!', gainError);
else
    fprintf('  PASS: Gain within 0.5 dB tolerance\n');
end

%% ====================================================================
%  TEST 2: runSpiceSensitivity - Sensitivity analysis
%  ====================================================================
fprintf('\n--- TEST 2: runSpiceSensitivity (R1, +/-1%%) ---\n');

sensDir = fullfile(testWorkDir, 'test2_sensitivity');
tic;
sensResult = runSpiceSensitivity(params, 'R1', 0.01, sensDir);
elapsed = toc;

fprintf('  All succeeded: %d\n', sensResult.success);
fprintf('  Baseline gain: %.4f dB\n', sensResult.baseline.gain_dB);
fprintf('  +1%% gain:      %.4f dB\n', sensResult.plus.gain_dB);
fprintf('  -1%% gain:      %.4f dB\n', sensResult.minus.gain_dB);
fprintf('  Sensitivity:   %.6f\n', sensResult.sensitivity);
fprintf('  Time:          %.2f s\n', elapsed);

if ~sensResult.success
    fprintf('  Baseline error: %s\n', sensResult.baseline.error_msg);
    fprintf('  Plus error:     %s\n', sensResult.plus.error_msg);
    fprintf('  Minus error:    %s\n', sensResult.minus.error_msg);
    error('TEST 2 FAILED: Not all sensitivity simulations succeeded.');
end
fprintf('  PASS: All 3 sensitivity simulations succeeded\n');

%% ====================================================================
%  TEST 3: runSpiceSweep2D - 2D parameter sweep (3x3)
%  ====================================================================
fprintf('\n--- TEST 3: runSpiceSweep2D (R1 x R2, 3x3) ---\n');

sweepDir = fullfile(testWorkDir, 'test3_sweep2d');

% Create 3 values for R1 and R2 around the baseline (0.8x, 1.0x, 1.2x)
r1_vals = params.R1 * [0.8, 1.0, 1.2];
r2_vals = params.R2 * [0.8, 1.0, 1.2];

tic;
sweepResult = runSpiceSweep2D(params, 'R1', r1_vals, 'R2', r2_vals, sweepDir);
elapsed = toc;

fprintf('\n  Gain surface (dB):\n');
for i = 1:3
    fprintf('    R1=%.0f: ', r1_vals(i));
    for j = 1:3
        fprintf('%.2f  ', sweepResult.gain_surface(i, j));
    end
    fprintf('\n');
end

fprintf('  Attempted: %d\n', sweepResult.n_attempted);
fprintf('  Success:   %d\n', sweepResult.n_success);
fprintf('  Failed:    %d\n', sweepResult.n_failed);
fprintf('  Rate:      %.1f%%\n', 100 * sweepResult.success_rate);
fprintf('  Time:      %.2f s\n', elapsed);

if sweepResult.n_success < 9
    warning('TEST 3: Only %d/9 simulations succeeded!', sweepResult.n_success);
else
    fprintf('  PASS: All 9 sweep simulations succeeded\n');
end

%% ====================================================================
%  SUMMARY
%  ====================================================================
fprintf('\n========================================\n');
fprintf('  TEST SUMMARY\n');
fprintf('========================================\n');
fprintf('  Test 1 (runSpice):            %s\n', iif(result.success, 'PASS', 'FAIL'));
fprintf('  Test 2 (runSpiceSensitivity): %s\n', iif(sensResult.success, 'PASS', 'FAIL'));
fprintf('  Test 3 (runSpiceSweep2D):     %s (%.0f%% success rate)\n', ...
    iif(sweepResult.n_success == 9, 'PASS', 'PARTIAL'), sweepResult.success_rate * 100);
fprintf('========================================\n\n');

%% ---- Cleanup temp directory ----
% Leave it for inspection; user can delete manually
fprintf('Test artifacts saved in: %s\n', testWorkDir);
fprintf('Delete manually if not needed.\n\n');


%% ---- Helper function ----
function s = iif(condition, trueStr, falseStr)
    if condition
        s = trueStr;
    else
        s = falseStr;
    end
end

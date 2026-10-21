%% 01_validate_dataset.m
% Stage 1: Validate the canonical CE amplifier dataset.
%
% Verifies:
%   - File exists and loads correctly
%   - Correct dimensions (660 rows x 10 columns)
%   - Expected column names (R1,R2,RC,RE,RL,Cin,Cout,Ce,VCC,Gain_dB)
%   - No missing values
%   - Physically meaningful component ranges
%   - Valid gain range
%
% Dataset: data/final/CE_Amplifier_ML_Valid.csv
%   660 valid CE amplifier configurations
%   9 input parameters + 1 target (Gain_dB)
%   Generated from 2000 Latin Hypercube samples, filtered for DC bias
%   stability and AC convergence.

clear; clc; close all;
fprintf('\n============================================================\n');
fprintf('  STAGE 1: DATASET VALIDATION\n');
fprintf('============================================================\n\n');

root_dir = setup_project_paths();

%% 1. Load dataset
dataset_path = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
assert(isfile(dataset_path), 'Canonical dataset not found:\n%s', dataset_path);

T = readtable(dataset_path);
[nRows, nCols] = size(T);

fprintf('Dataset: %s\n', dataset_path);
fprintf('Dimensions: %d rows x %d columns\n', nRows, nCols);

%% 2. Check dimensions
assert(nRows == 660, 'Expected 660 rows, found %d', nRows);
assert(nCols == 10,  'Expected 10 columns, found %d', nCols);

%% 3. Check column names
expected_features = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
expected_target   = 'Gain_dB';
expected_cols     = [expected_features, {expected_target}];

actual_cols = T.Properties.VariableNames;
assert(isequal(actual_cols, expected_cols), ...
    'Column names do not match.\nExpected: %s\nActual:   %s', ...
    strjoin(expected_cols, ', '), strjoin(actual_cols, ', '));
fprintf('Columns: %s\n', strjoin(actual_cols, ', '));

%% 4. Check missing values
nMissing = sum(sum(ismissing(T)));
fprintf('Missing values: %d\n', nMissing);
assert(nMissing == 0, 'Dataset contains %d missing values!', nMissing);

%% 5. Check value ranges
fprintf('\n--- Feature Ranges ---\n');
for i = 1:numel(expected_features)
    fname = expected_features{i};
    vals  = T.(fname);
    assert(all(isfinite(vals)), '%s contains non-finite values', fname);
    assert(all(vals > 0),       '%s contains non-positive values', fname);
    fprintf('  %-5s: [%12.4e, %12.4e]\n', fname, min(vals), max(vals));
end

%% 6. Check target
gain = T.Gain_dB;
assert(all(isfinite(gain)), 'Target contains non-finite values');
assert(min(gain) > -50 && max(gain) < 100, ...
    'Gain range [%.2f, %.2f] dB outside physically realistic bounds', ...
    min(gain), max(gain));

fprintf('\n--- Target Statistics ---\n');
fprintf('  Gain_dB range : [%.4f, %.4f] dB\n', min(gain), max(gain));
fprintf('  Gain_dB mean  : %.4f dB\n', mean(gain));
fprintf('  Gain_dB median: %.4f dB\n', median(gain));
fprintf('  Gain_dB std   : %.4f dB\n', std(gain));

%% 7. Identify representative circuits
[~, sort_idx] = sort(gain);
idx_low    = sort_idx(1);
idx_medium = sort_idx(round((nRows+1)/2));  % rank 331 -> Row 253
idx_high   = sort_idx(end);

fprintf('\n--- Representative Circuits ---\n');
fprintf('  Low Gain:    Row %3d  (Gain = %.4f dB)\n', idx_low,    gain(idx_low));
fprintf('  Medium Gain: Row %3d  (Gain = %.4f dB)\n', idx_medium, gain(idx_medium));
fprintf('  High Gain:   Row %3d  (Gain = %.4f dB)\n', idx_high,   gain(idx_high));

fprintf('\n>>> DATASET VALIDATION PASSED <<<\n');

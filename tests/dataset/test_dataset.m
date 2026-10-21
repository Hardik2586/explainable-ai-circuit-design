%% test_dataset.m
% Verification script for canonical dataset integrity
% clear; clc;

root_dir = setup_project_paths();
dataset_path = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');

fprintf('========================================\n');
fprintf('DATASET VERIFICATION TEST\n');
fprintf('========================================\n');

assert(isfile(dataset_path), 'Canonical dataset file not found at: %s', dataset_path);

tbl = readtable(dataset_path);
[nRows, nCols] = size(tbl);

fprintf('Dataset location : %s\n', dataset_path);
fprintf('Dataset dimensions: %d rows x %d columns\n', nRows, nCols);

% Check row count (660 valid samples expected)
assert(nRows == 660, 'Expected 660 rows, found %d', nRows);

% Check column names
expected_features = {'R1', 'R2', 'RC', 'RE', 'RL', 'Cin', 'Cout', 'Ce', 'VCC'};
expected_target = 'Gain_dB';
expected_cols = [expected_features, {expected_target}];

assert(isequal(tbl.Properties.VariableNames, expected_cols), 'Column names do not match canonical schema');

% Check missing values
nMissing = sum(sum(ismissing(tbl)));
fprintf('Missing values count: %d\n', nMissing);
assert(nMissing == 0, 'Dataset contains missing values!');

% Check target validity
gain = tbl.Gain_dB;
assert(all(isfinite(gain)), 'Target contains non-finite values (NaN/Inf)');
assert(min(gain) > -100 && max(gain) < 120, 'Gain values out of realistic range');

fprintf('Target Gain_dB Range: [%.4f dB, %.4f dB], Mean: %.4f dB\n', min(gain), max(gain), mean(gain));
fprintf('>>> DATASET VERIFICATION PASSED SUCCESSFULLY! <<<\n\n');

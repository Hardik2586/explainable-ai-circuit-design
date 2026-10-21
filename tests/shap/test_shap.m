%% test_shap.m
% Verification script for global SHAP results integrity
% clear; clc;

root_dir = setup_project_paths();
shap_mat_path = fullfile(root_dir, 'xai', 'global_shap', 'Gain_SHAP_Results.mat');
shap_csv_path = fullfile(root_dir, 'xai', 'global_shap', 'Gain_SHAP_Importance.csv');
shap_dep_ranking_path = fullfile(root_dir, 'xai', 'dependence', 'SHAP_Dependence_Ranking.csv');

fprintf('========================================\n');
fprintf('SHAP RESULTS VERIFICATION TEST\n');
fprintf('========================================\n');

assert(isfile(shap_mat_path), 'SHAP MAT file not found at: %s', shap_mat_path);
assert(isfile(shap_csv_path), 'SHAP CSV file not found at: %s', shap_csv_path);

% 1. Check raw shapley output table
tbl_shap = readtable(shap_csv_path);
[nRows, nCols] = size(tbl_shap);

fprintf('SHAP Raw Table dimensions: %d features x %d columns\n', nRows, nCols);
assert(nRows == 9, 'Expected 9 features in SHAP ranking');

% Check feature mapping (x1=R1, x2=R2, x3=RC, x4=RE, x5=RL, x6=Cin, x7=Cout, x8=Ce, x9=VCC)
feature_map = containers.Map(...
    {'x1','x2','x3','x4','x5','x6','x7','x8','x9'}, ...
    {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'});

% 2. Check canonical named SHAP dependence ranking
if isfile(shap_dep_ranking_path)
    tbl_named = readtable(shap_dep_ranking_path);
    fprintf('\nNamed Global SHAP Ranking (from SHAP_Dependence_Ranking.csv):\n');
    for i = 1:height(tbl_named)
        fprintf('  %d. %-5s: %.6f dB\n', tbl_named.Rank(i), tbl_named.Parameter{i}, tbl_named.MeanAbsoluteSHAP(i));
    end
    assert(strcmp(tbl_named.Parameter{1}, 'R1'), 'Expected R1 to be top feature in named ranking');
    assert(strcmp(tbl_named.Parameter{2}, 'RE'), 'Expected RE to be second feature in named ranking');
end

% Verify all values are positive and finite
assert(all(isfinite(tbl_shap.MeanAbsoluteSHAP)), 'Non-finite values found in SHAP results');
assert(all(tbl_shap.MeanAbsoluteSHAP >= 0), 'Negative mean absolute SHAP values found');

fprintf('>>> SHAP VERIFICATION PASSED SUCCESSFULLY! <<<\n\n');

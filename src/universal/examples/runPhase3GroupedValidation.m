
%% PHASE 3.5: GROUPED CROSS-VALIDATION
% MATLAB only. Does not modify the original dataset.
% Grouping is based on rounded DC operating points.

clc;
clear;
close all;

rng(42, 'twister');

root = 'C:\Internship Project';

baseDir = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'external_model_validation', ...
    '20261020_000113');

S = load(fullfile(baseDir, 'CS_Dataset_v2_100.mat'));
T = S.rows;

target = 'GainAt1kHz_dB';

componentFeatures = { ...
    'RGU_Ohm', 'RGL_Ohm', 'RD_Ohm', ...
    'RS_Ohm', 'CIN_F'};

dcFeatures = {'VGS_V', 'VDS_V', 'ID_A'};

required = [componentFeatures, dcFeatures, {target}];

assert(all(ismember(required, T.Properties.VariableNames)), ...
    'Required columns are missing.');

X1 = T{:, componentFeatures};
X2 = T{:, [componentFeatures, dcFeatures]};
Y = T.(target);

valid = all(isfinite(X1),2) & ...
        all(isfinite(X2),2) & isfinite(Y);

T = T(valid,:);
X1 = X1(valid,:);
X2 = X2(valid,:);
Y = Y(valid);

%% 1. Create groups from rounded DC operating points

% Rounding precision defines which operating points are considered
% equivalent for this diagnostic. These are grouping tolerances,
% not claims about physical measurement uncertainty.
groupFeatures = [T.VGS_V, T.VDS_V, T.ID_A];

groupPrecision = [3, 3, 5];

groupRounded = round(groupFeatures .* ...
    (10.^groupPrecision)) ./ (10.^groupPrecision);

[~, ~, groupID] = unique(groupRounded, 'rows');

numGroups = numel(unique(groupID));

fprintf('Valid circuits: %d\n', height(T));
fprintf('Unique DC groups: %d\n', numGroups);

groupCounts = accumarray(groupID, 1);
fprintf('Largest group size: %d\n', max(groupCounts));

if numGroups < 5
    error(['Fewer than five DC groups. ' ...
        'Use fewer folds or revise grouping precision.']);
end

%% 2. Assign whole groups to folds

% Randomly assign groups, not individual circuits.
% Greedy balancing tries to keep fold sizes similar.
groupOrder = randperm(numGroups);
foldForGroup = zeros(numGroups, 1);
foldSizes = zeros(5, 1);

% Process largest groups first to improve balance.
[~, orderBySize] = sort(groupCounts, 'descend');
groupOrder = orderBySize(randperm(numGroups));

for j = 1:numGroups
    g = groupOrder(j);
    [~, fold] = min(foldSizes);

    foldForGroup(g) = fold;
    foldSizes(fold) = foldSizes(fold) + groupCounts(g);
end

foldID = foldForGroup(groupID);

fprintf('Fold sizes: ');
fprintf('%d ', foldSizes);
fprintf('\n');

%% 3. Run grouped out-of-fold predictions

n = numel(Y);

pred1 = nan(n,1);
pred2 = nan(n,1);

foldMetrics = table((1:5)', nan(5,1), nan(5,1), ...
    nan(5,1), nan(5,1), ...
    'VariableNames', {'Fold', ...
    'ComponentOnly_MAE', 'ComponentOnly_RMSE', ...
    'ComponentDC_MAE', 'ComponentDC_RMSE'});

for k = 1:5

    te = foldID == k;
    tr = ~te;

    assert(~isempty(find(te,1)), 'Empty test fold.');
    assert(~isempty(find(tr,1)), 'Empty training fold.');

    % Ensure no DC group appears in both partitions.
    assert(isempty(intersect(unique(groupID(tr)), ...
        unique(groupID(te)))), ...
        'Group leakage detected.');

    % Component-only model
    model1 = fitrensemble(X1(tr,:), Y(tr), ...
        'Method', 'Bag', ...
        'NumLearningCycles', 100, ...
        'Learners', templateTree('MinLeafSize', 5));

    pred1(te) = predict(model1, X1(te,:));

    % Component + DC model
    model2 = fitrensemble(X2(tr,:), Y(tr), ...
        'Method', 'Bag', ...
        'NumLearningCycles', 100, ...
        'Learners', templateTree('MinLeafSize', 5));

    pred2(te) = predict(model2, X2(te,:));

    foldMetrics.ComponentOnly_MAE(k) = ...
        mean(abs(Y(te)-pred1(te)));

    foldMetrics.ComponentOnly_RMSE(k) = ...
        sqrt(mean((Y(te)-pred1(te)).^2));

    foldMetrics.ComponentDC_MAE(k) = ...
        mean(abs(Y(te)-pred2(te)));

    foldMetrics.ComponentDC_RMSE(k) = ...
        sqrt(mean((Y(te)-pred2(te)).^2));

    fprintf('Completed grouped fold %d/5\n', k);
end

%% 4. Overall grouped-validation metrics

predictions = {pred1, pred2};
modelNames = ["Component only"; "Component + DC"];

MAE = zeros(2,1);
RMSE = zeros(2,1);
R2 = zeros(2,1);

for j = 1:2
    e = Y - predictions{j};

    MAE(j) = mean(abs(e));
    RMSE(j) = sqrt(mean(e.^2));
    R2(j) = 1 - sum(e.^2) / sum((Y-mean(Y)).^2);
end

summary = table(modelNames, MAE, RMSE, R2);

disp('===== GROUPED VALIDATION RESULTS =====');
disp(summary);

%% 5. Save results separately

resultsDir = fullfile(root, 'results', ...
    ['Phase3_Grouped_' datestr(now,'yyyymmdd_HHMMSS')]);

mkdir(resultsDir);

writetable(summary, fullfile(resultsDir, ...
    'Grouped_Model_Summary.csv'));

writetable(foldMetrics, fullfile(resultsDir, ...
    'Grouped_Fold_Metrics.csv'));

predTable = table(T.CircuitID, Y, groupID, foldID, ...
    pred1, pred2, ...
    'VariableNames', {'CircuitID', 'ActualGain_dB', ...
    'DCGroup', 'Fold', 'ComponentOnlyPrediction_dB', ...
    'ComponentDCPrediction_dB'});

writetable(predTable, fullfile(resultsDir, ...
    'Grouped_OutOfFold_Predictions.csv'));

save(fullfile(resultsDir, 'Grouped_Experiment.mat'), ...
    'summary', 'foldMetrics', 'predTable', ...
    'groupPrecision', 'componentFeatures', 'dcFeatures');

fprintf('\nResults saved to:\n%s\n', resultsDir);

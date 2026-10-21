
%% GROUPED CROSS-VALIDATION: SATURATION-ONLY GAIN MODEL
clear; clc; close all;
rng(42,'twister');

%% 1. Paths and configuration

root = 'C:\Internship Project';

dataFile = fullfile(root,'results','Optimization', ...
    'Common_Source_Exhaustive','20261013_030513', ...
    'all_1215_candidate_results.csv');

assert(isfile(dataFile),'Dataset not found: %s',dataFile);

VTO = 2.0;
K = 5;

T = readtable(dataFile);

required = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VDD_V','VGS_V','VDS_V','PeakGain_dB'};

for i = 1:numel(required)
    assert(ismember(required{i},T.Properties.VariableNames), ...
        'Missing column: %s',required{i});
end

%% 2. Filter valid numerical simulations

valid = true(height(T),1);

for i = 1:numel(required)
    valid = valid & isfinite(T.(required{i}));
end

if ismember('SimulationValid',T.Properties.VariableNames)
    valid = valid & logical(T.SimulationValid);
end

D = T(valid,:);

%% 3. Derive the same operating-region labels

VGS = D.VGS_V;
VDS = D.VDS_V;

isSaturation = VGS > VTO & VDS >= (VGS-VTO);

S = D(isSaturation,:);

fprintf('\n===== SATURATION DATA =====\n');
fprintf('All valid simulations: %d\n',height(D));
fprintf('Saturation simulations: %d\n',height(S));

%% 4. Create groups excluding CIN

% CIN variants of the same resistor/supply configuration must remain
% together in one fold.

groupTable = S(:, ...
    {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V'});

[~,~,groupID] = unique(groupTable,'rows');

nGroups = max(groupID);

fprintf('Unique saturation configuration groups: %d\n',nGroups);

if nGroups < K
    error('Not enough groups for the requested cross-validation.');
end

%% 5. Assign entire groups to five folds

groupOrder = randperm(nGroups);

groupFold = zeros(nGroups,1);

for i = 1:nGroups
    groupFold(groupOrder(i)) = mod(i-1,K)+1;
end

rowFold = groupFold(groupID);

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

X = S{:,features};
Y = S.PeakGain_dB;

%% 6. Train/evaluate each fold

treeTemplate = templateTree('MinLeafSize',5);

Fold = zeros(K,1);
TrainRows = zeros(K,1);
TestRows = zeros(K,1);
TrainGroups = zeros(K,1);
TestGroups = zeros(K,1);
RMSE = zeros(K,1);
MAE = zeros(K,1);
R2 = zeros(K,1);
MeanBaselineRMSE = zeros(K,1);
MeanBaselineMAE = zeros(K,1);
MeanBaselineR2 = zeros(K,1);

allActual = nan(height(S),1);
allPredicted = nan(height(S),1);
allBaseline = nan(height(S),1);

for f = 1:K

    testMask = rowFold == f;
    trainMask = ~testMask;

    XTrain = X(trainMask,:);
    YTrain = Y(trainMask);

    XTest = X(testMask,:);
    YTest = Y(testMask);

    fprintf('\nTraining fold %d/%d...\n',f,K);

    model = fitrensemble( ...
        XTrain,YTrain, ...
        'Method','LSBoost', ...
        'NumLearningCycles',150, ...
        'Learners',treeTemplate);

    predicted = predict(model,XTest);

    % Baseline: predict the training-fold mean for every test circuit.
    baselinePredicted = repmat(mean(YTrain),sum(testMask),1);

    m = calcMetrics(YTest,predicted);
    b = calcMetrics(YTest,baselinePredicted);

    Fold(f) = f;
    TrainRows(f) = sum(trainMask);
    TestRows(f) = sum(testMask);
    TrainGroups(f) = numel(unique(groupID(trainMask)));
    TestGroups(f) = numel(unique(groupID(testMask)));

    RMSE(f) = m.RMSE;
    MAE(f) = m.MAE;
    R2(f) = m.R2;

    MeanBaselineRMSE(f) = b.RMSE;
    MeanBaselineMAE(f) = b.MAE;
    MeanBaselineR2(f) = b.R2;

    allActual(testMask) = YTest;
    allPredicted(testMask) = predicted;
    allBaseline(testMask) = baselinePredicted;

    fprintf('Fold %d: RMSE %.6f dB, MAE %.6f dB, R2 %.6f\n', ...
        f,m.RMSE,m.MAE,m.R2);
end

%% 7. Cross-validation summary

FoldResults = table(Fold,TrainRows,TestRows, ...
    TrainGroups,TestGroups,RMSE,MAE,R2, ...
    MeanBaselineRMSE,MeanBaselineMAE,MeanBaselineR2);

fprintf('\n===== RESULTS BY FOLD =====\n');
disp(FoldResults);

pooledModel = calcMetrics(Y,allPredicted);
pooledBaseline = calcMetrics(Y,allBaseline);

fprintf('\n===== POOLED OUT-OF-FOLD RESULTS =====\n');

fprintf('BoostedTrees RMSE: %.6f dB\n',pooledModel.RMSE);
fprintf('BoostedTrees MAE:  %.6f dB\n',pooledModel.MAE);
fprintf('BoostedTrees R2:   %.6f\n',pooledModel.R2);

fprintf('\nMean baseline RMSE: %.6f dB\n',pooledBaseline.RMSE);
fprintf('Mean baseline MAE:  %.6f dB\n',pooledBaseline.MAE);
fprintf('Mean baseline R2:   %.6f\n',pooledBaseline.R2);

fprintf('\nFold RMSE mean: %.6f dB\n',mean(RMSE));
fprintf('Fold RMSE std:  %.6f dB\n',std(RMSE));
fprintf('Fold MAE mean:  %.6f dB\n',mean(MAE));
fprintf('Fold R2 mean:   %.6f\n',mean(R2));

%% 8. Save out-of-fold predictions

PredictionTable = S(:,features);
PredictionTable.ActualGain_dB = Y;
PredictionTable.Fold = rowFold;
PredictionTable.PredictedGain_dB = allPredicted;
PredictionTable.MeanBaseline_dB = allBaseline;
PredictionTable.AbsoluteError_dB = abs(Y-allPredicted);

%% 9. Save outputs in a new folder

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outDir = fullfile(root,'results','Model_Evaluation', ...
    'Common_Source','Saturation_CV',stamp);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

writetable(FoldResults,fullfile(outDir,'fold_results.csv'));

writetable(PredictionTable, ...
    fullfile(outDir,'out_of_fold_predictions.csv'));

Summary = table( ...
    pooledModel.RMSE,pooledModel.MAE,pooledModel.R2, ...
    pooledBaseline.RMSE,pooledBaseline.MAE,pooledBaseline.R2, ...
    mean(RMSE),std(RMSE),mean(MAE),mean(R2), ...
    'VariableNames',{'PooledRMSE_dB','PooledMAE_dB','PooledR2', ...
    'BaselinePooledRMSE_dB','BaselinePooledMAE_dB', ...
    'BaselinePooledR2','MeanFoldRMSE_dB','StdFoldRMSE_dB', ...
    'MeanFoldMAE_dB','MeanFoldR2'});

writetable(Summary,fullfile(outDir,'cv_summary.csv'));

fig = figure('Visible','off');

scatter(Y,allPredicted,25,'filled');
hold on;

lo = min([Y;allPredicted]);
hi = max([Y;allPredicted]);

plot([lo hi],[lo hi],'k--','LineWidth',1.5);

xlabel('Actual SPICE Peak Gain (dB)');
ylabel('Out-of-fold Predicted Gain (dB)');
title('Grouped 5-Fold Saturation Model Validation');
grid on;

exportgraphics(fig,fullfile(outDir,'cv_actual_vs_predicted.png'));
close(fig);

fprintf('\nValidation complete.\nResults saved to:\n%s\n',outDir);

%% Local metrics function

function M = calcMetrics(actual,predicted)

    actual = actual(:);
    predicted = predicted(:);

    valid = isfinite(actual) & isfinite(predicted);

    actual = actual(valid);
    predicted = predicted(valid);

    e = actual-predicted;

    M.RMSE = sqrt(mean(e.^2));
    M.MAE = mean(abs(e));

    ssTot = sum((actual-mean(actual)).^2);

    if ssTot > 0
        M.R2 = 1-sum(e.^2)/ssTot;
    else
        M.R2 = NaN;
    end
end

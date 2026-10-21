clear; clc; close all;
rng(42,'twister');

%% 1. Paths and configuration

root = 'C:\Internship Project';

dataFile = fullfile(root,'results','Optimization', ...
    'Common_Source_Exhaustive','20261013_030513', ...
    'all_1215_candidate_results.csv');

assert(isfile(dataFile),'Dataset not found: %s',dataFile);

K = 5;
VTO = 2.0;

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

required = [features, ...
    {'VGS_V','VDS_V','PeakGain_dB','SimulationValid'}];

T = readtable(dataFile);

for k = 1:numel(required)
    assert(ismember(required{k},T.Properties.VariableNames), ...
        'Missing column: %s',required{k});
end

%% 2. Filter valid rows and select saturation circuits

valid = true(height(T),1);

for k = 1:numel(features)
    valid = valid & isfinite(T.(features{k}));
end

valid = valid & isfinite(T.VGS_V) ...
              & isfinite(T.VDS_V) ...
              & isfinite(T.PeakGain_dB) ...
              & logical(T.SimulationValid);

D = T(valid,:);

satMask = D.VGS_V > VTO & ...
          D.VDS_V >= (D.VGS_V - VTO);

S = D(satMask,:);

fprintf('\nValid simulations: %d\n',height(D));
fprintf('Saturation circuits: %d\n',height(S));

X = S{:,features};
Y = S.PeakGain_dB;

%% 3. Group related capacitor variants together

% Same resistor and supply configuration = same group.
% CIN variants cannot cross between training and test folds.

groupTable = S(:, ...
    {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V'});

[~,~,groupID] = unique(groupTable,'rows');
nGroups = max(groupID);

assert(nGroups >= K,'Not enough groups for cross-validation.');

groupOrder = randperm(nGroups);
groupFold = zeros(nGroups,1);

for k = 1:nGroups
    groupFold(groupOrder(k)) = mod(k-1,K)+1;
end

rowFold = groupFold(groupID);

fprintf('Unique configuration groups: %d\n',nGroups);
fprintf('Cross-validation folds: %d\n',K);

%% 4. Prepare out-of-fold prediction storage

n = height(S);

predLinear = nan(n,1);
predBoosted = nan(n,1);
predMLP = nan(n,1);

Fold = zeros(K,1);
TrainRows = zeros(K,1);
TestRows = zeros(K,1);

RMSE_Linear = nan(K,1);
MAE_Linear = nan(K,1);
R2_Linear = nan(K,1);

RMSE_Boosted = nan(K,1);
MAE_Boosted = nan(K,1);
R2_Boosted = nan(K,1);

RMSE_MLP = nan(K,1);
MAE_MLP = nan(K,1);
R2_MLP = nan(K,1);

%% 5. Train and evaluate each fold

for f = 1:K

    fprintf('\n===== FOLD %d/%d =====\n',f,K);

    testMask = rowFold == f;
    trainMask = ~testMask;

    XTrain = X(trainMask,:);
    YTrain = Y(trainMask);

    XTest = X(testMask,:);
    YTest = Y(testMask);

    % Standardize inputs using training data only.
    muX = mean(XTrain,1);
    sigmaX = std(XTrain,0,1);
    sigmaX(sigmaX == 0) = 1;

    XTrainZ = (XTrain-muX)./sigmaX;
    XTestZ = (XTest-muX)./sigmaX;

    %% Model A: Linear regression

    modelLinear = fitlm(XTrainZ,YTrain);

    pLinear = predict(modelLinear,XTestZ);

    %% Model B: Boosted regression trees

    modelBoosted = fitrensemble( ...
        XTrain,YTrain, ...
        'Method','LSBoost', ...
        'NumLearningCycles',150, ...
        'Learners',templateTree('MinLeafSize',5));

    pBoosted = predict(modelBoosted,XTest);

    %% Model C: Multilayer perceptron

    % Standardization is done above using training data only.
    % The MLP receives standardized inputs.
    modelMLP = fitrnet( ...
        XTrainZ,YTrain, ...
        'LayerSizes',[16 8], ...
        'Activations','relu', ...
        'Lambda',1e-4, ...
        'IterationLimit',500, ...
        'Standardize',false, ...
        'Verbose',0);

    pMLP = predict(modelMLP,XTestZ);

    %% Store predictions

    predLinear(testMask) = pLinear;
    predBoosted(testMask) = pBoosted;
    predMLP(testMask) = pMLP;

    %% Fold metrics

    mA = calcMetrics(YTest,pLinear);
    mB = calcMetrics(YTest,pBoosted);
    mC = calcMetrics(YTest,pMLP);

    Fold(f) = f;
    TrainRows(f) = sum(trainMask);
    TestRows(f) = sum(testMask);

    RMSE_Linear(f) = mA.RMSE;
    MAE_Linear(f) = mA.MAE;
    R2_Linear(f) = mA.R2;

    RMSE_Boosted(f) = mB.RMSE;
    MAE_Boosted(f) = mB.MAE;
    R2_Boosted(f) = mB.R2;

    RMSE_MLP(f) = mC.RMSE;
    MAE_MLP(f) = mC.MAE;
    R2_MLP(f) = mC.R2;

    fprintf('Linear:       RMSE %.6f | MAE %.6f | R2 %.6f\n', ...
        mA.RMSE,mA.MAE,mA.R2);

    fprintf('BoostedTrees: RMSE %.6f | MAE %.6f | R2 %.6f\n', ...
        mB.RMSE,mB.MAE,mB.R2);

    fprintf('MLP:          RMSE %.6f | MAE %.6f | R2 %.6f\n', ...
        mC.RMSE,mC.MAE,mC.R2);
end

%% 6. Fold-by-fold results

FoldResults = table(Fold,TrainRows,TestRows, ...
    RMSE_Linear,MAE_Linear,R2_Linear, ...
    RMSE_Boosted,MAE_Boosted,R2_Boosted, ...
    RMSE_MLP,MAE_MLP,R2_MLP);

fprintf('\n===== RESULTS BY FOLD =====\n');
disp(FoldResults);

%% 7. Pooled out-of-fold results

mLinear = calcMetrics(Y,predLinear);
mBoosted = calcMetrics(Y,predBoosted);
mMLP = calcMetrics(Y,predMLP);

Model = ["LinearRegression";"BoostedTrees";"MLP_16_8"];

PooledRMSE_dB = [mLinear.RMSE;mBoosted.RMSE;mMLP.RMSE];
PooledMAE_dB = [mLinear.MAE;mBoosted.MAE;mMLP.MAE];
PooledR2 = [mLinear.R2;mBoosted.R2;mMLP.R2];

MeanFoldRMSE_dB = [mean(RMSE_Linear); ...
    mean(RMSE_Boosted);mean(RMSE_MLP)];

StdFoldRMSE_dB = [std(RMSE_Linear); ...
    std(RMSE_Boosted);std(RMSE_MLP)];

Summary = table(Model,PooledRMSE_dB,PooledMAE_dB,PooledR2, ...
    MeanFoldRMSE_dB,StdFoldRMSE_dB);

fprintf('\n===== POOLED OUT-OF-FOLD COMPARISON =====\n');
disp(Summary);

%% 8. Save results

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outDir = fullfile(root,'results','Model_Evaluation', ...
    'Common_Source','Model_Benchmark',stamp);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

PredictionTable = S(:,features);
PredictionTable.ActualGain_dB = Y;
PredictionTable.Fold = rowFold;
PredictionTable.LinearPrediction_dB = predLinear;
PredictionTable.BoostedPrediction_dB = predBoosted;
PredictionTable.MLPPrediction_dB = predMLP;

PredictionTable.LinearAbsoluteError_dB = abs(Y-predLinear);
PredictionTable.BoostedAbsoluteError_dB = abs(Y-predBoosted);
PredictionTable.MLPAbsoluteError_dB = abs(Y-predMLP);

writetable(FoldResults,fullfile(outDir,'fold_results.csv'));
writetable(Summary,fullfile(outDir,'benchmark_summary.csv'));
writetable(PredictionTable,fullfile(outDir,'out_of_fold_predictions.csv'));

%% 9. Plot actual versus predicted gain

fig = figure('Visible','off');

scatter(Y,predLinear,20,'filled');
hold on;
scatter(Y,predBoosted,20,'filled');
scatter(Y,predMLP,20,'filled');

lo = min([Y;predLinear;predBoosted;predMLP]);
hi = max([Y;predLinear;predBoosted;predMLP]);

plot([lo hi],[lo hi],'k--','LineWidth',1.5);

xlabel('Actual SPICE Peak Gain (dB)');
ylabel('Out-of-fold Predicted Gain (dB)');
title('Linear vs BoostedTrees vs MLP');
legend('Linear','BoostedTrees','MLP','Ideal', ...
    'Location','best');
grid on;

exportgraphics(fig,fullfile(outDir,'model_comparison.png'));
close(fig);

fprintf('\nBenchmark completed.\nResults saved to:\n%s\n',outDir);

%% Local helper
function M = calcMetrics(actual,predicted)

    actual = actual(:);
    predicted = predicted(:);

    valid = isfinite(actual) & isfinite(predicted);
    actual = actual(valid);
    predicted = predicted(valid);

    err = actual-predicted;

    M.RMSE = sqrt(mean(err.^2));
    M.MAE = mean(abs(err));

    ssTot = sum((actual-mean(actual)).^2);

    if ssTot > 0
        M.R2 = 1-sum(err.^2)/ssTot;
    else
        M.R2 = NaN;
    end
end

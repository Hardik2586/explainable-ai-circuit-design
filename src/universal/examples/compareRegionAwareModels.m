clear; clc; close all;
rng(42,'twister');

%% 1. Paths

root = 'C:\Internship Project';

dataFile = fullfile(root,'results', ...
    'Optimization','Common_Source_Exhaustive', ...
    '20261013_030513','all_1215_candidate_results.csv');

oldModelFile = fullfile(root,'models', ...
    'Common_Source','20261013_022802', ...
    'CommonSourceModel.mat');

assert(isfile(dataFile),'Dataset not found: %s',dataFile);
assert(isfile(oldModelFile),'Original model not found: %s',oldModelFile);

T = readtable(dataFile);
S = load(oldModelFile);

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

required = [features, {'VGS_V','VDS_V','ID_A','PeakGain_dB'}];

for k = 1:numel(required)
    assert(ismember(required{k},T.Properties.VariableNames), ...
        'Missing column: %s',required{k});
end

%% 2. Filter valid numerical rows

valid = true(height(T),1);

for k = 1:numel(required)
    valid = valid & isfinite(T.(required{k}));
end

if ismemberSimulationValid',T.Properties.VariableNames)
    valid = valid & logical(T.SimulationValid);
end

D = T(valid,:);

fprintf('\nValid dataset rows: %d\n',height(D));

%% 3. Derive operating-region labels

VTO = 2.0; 

VGS = D.VGS_V;
VDS = D.VDS_V;

region = strings(height(D),1);

isCutoff = VGS <= VTO;
isSaturation = VGS > VTO & VDS >= (VGS - VTO);
isTriode = VGS > VTO & VDS < (VGS - VTO);

region(isCutoff) = "Cutoff";
region(isTriode) = "Triode";
region(isSaturation) = "Saturation";

% These categories are based on the simplified simulation model.
D.BiasRegionDerived = categorical(region, ...
    {'Cutoff','Triode','Saturation'});

fprintf('\nDerived region counts:\n');
disp(countcats(D.BiasRegionDerived));

%% 4. Grouped train/test split

groupTable = D(:, ...
    {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V'});

[~,~,groupID] = unique(groupTable,'rows');

uniqueGroups = unique(groupID);
uniqueGroups = uniqueGroups(randperm(numel(uniqueGroups)));

nTestGroups = max(1,round(0.20*numel(uniqueGroups)));
testGroups = uniqueGroups(1:nTestGroups);

isTest = ismember(groupID,testGroups);
isTrain = ~isTest;

X = D{:,features};
Y = D.PeakGain_dB;
R = D.BiasRegionDerived;

XTrain = X(isTrain,:);
XTest = X(isTest,:);

YTrain = Y(isTrain);
YTest = Y(isTest);

RTrain = R(isTrain);
RTest = R(isTest);

fprintf('\nTraining rows: %d\n',sum(isTrain));
fprintf('Test rows: %d\n',sum(isTest));
fprintf('Training groups: %d\n',numel(unique(groupID(isTrain))));
fprintf('Test groups: %d\n',numel(unique(groupID(isTest))));

%% 5. Model A: Original model

originalModel = S.selectedModel;
originalName = string(S.modelInfo.SelectedModelName);

XOriginalTest = XTest;

% Standardization is needed for the saved RidgeLinear model only.
if originalName == "RidgeLinear"

    assert(isfield(S,'muX') && isfield(S,'sigmaX'), ...
        'Scaling metadata missing from original RidgeLinear model.');

    sigma = S.sigmaX;
    sigma(sigma == 0 | ~isfinite(sigma)) = 1;

    XOriginalTest = (XTest - S.muX) ./ sigma;
end

predA = predict(originalModel,XOriginalTest);

%% 6. Model B: Saturation-only regression

trainSat = RTrain == 'Saturation';
testSat = RTest == 'Saturation';

if sum(trainSat) < 20 || sum(testSat) == 0
    error('Insufficient saturation samples in train or test partition.');
end

modelSat = fitrensemble( ...
    XTrain(trainSat,:),YTrain(trainSat), ...
    'Method','LSBoost', ...
    'NumLearningCycles',150, ...
    'Learners',templateTree('MinLeafSize',5));

predB = predict(modelSat,XTest(testSat,:));

%% 7. Model C: Predict region first, then predict gain

% Train the region classifier using training rows only.
modelRegion = fitcensemble( ...
    XTrain,RTrain, ...
    'Method','Bag', ...
    'NumLearningCycles',100, ...
    'Learners',templateTree('MinLeafSize',5));

predictedRegion = predict(modelRegion,XTest);

% Train separate regressors for each region present in training data.
regionNames = categories(RTrain);
regionModels = struct();

for k = 1:numel(regionNames)

    thisRegion = regionNames{k};
    trainMask = RTrain == thisRegion;

    if sum(trainMask) < 20
        warning('Skipping region %s: too few training rows.',thisRegion);
        continue;
    end

    field = matlab.lang.makeValidName(thisRegion);

    regionModels.(field) = fitrensemble( ...
        XTrain(trainMask,:),YTrain(trainMask), ...
        'Method','LSBoost', ...
        'NumLearningCycles',150, ...
        'Learners',templateTree('MinLeafSize',5));
end

% At test time, use the PREDICTED region, not the true region.
predC = nan(size(YTest));

for k = 1:numel(regionNames)

    thisRegion = regionNames{k};
    field = matlab.lang.makeValidName(thisRegion);

    if ~isfield(regionModels,field)
        continue;
    end

    mask = predictedRegion == categorical( ...
        {thisRegion},categories(RTrain));

    if any(mask)
        predC(mask) = predict(regionModels.(field),XTest(mask,:));
    end
end

%% 8. Metrics

metricA = regressionMetrics(YTest,predA);

metricC = regressionMetrics(YTest,predC);

% Saturation-only model is evaluated only on truly saturated test rows.
metricB = regressionMetrics(YTest(testSat),predB);

Model = [ ...
    "A_Original_Model"; ...
    "B_Saturation_Only"; ...
    "C_Two_Stage_Pipeline"];

EvaluationSubset = [ ...
    "All test circuits"; ...
    "True saturation test circuits only"; ...
    "All test circuits"];

RMSE_dB = [metricA.RMSE;metricB.RMSE;metricC.RMSE];
MAE_dB  = [metricA.MAE;metricB.MAE;metricC.MAE];
R2      = [metricA.R2;metricB.R2;metricC.R2];

Results = table(Model,EvaluationSubset,RMSE_dB,MAE_dB,R2);

fprintf('\n===== MODEL COMPARISON =====\n');
disp(Results);

%% 9. Region classifier accuracy

regionAccuracy = mean(predictedRegion == RTest);

fprintf('\nRegion classification accuracy: %.2f%%\n', ...
    100*regionAccuracy);

confusion = confusionmat(RTest,predictedRegion);

disp('Confusion matrix (actual rows, predicted columns):');
disp(confusion);

%% 10. Per-voltage evaluation for comparable models A and C

voltages = unique(D.VDD_V(isTest));

VoltageResults = table();

for k = 1:numel(voltages)

    v = voltages(k);
    mask = abs(D.VDD_V(isTest)-v) < 1e-9;

    if ~any(mask)
        continue;
    end

    mA = regressionMetrics(YTest(mask),predA(mask));
    mC = regressionMetrics(YTest(mask),predC(mask));

    row = table(v,sum(mask), ...
        mA.RMSE,mC.RMSE,mA.MAE,mC.MAE,mA.R2,mC.R2, ...
        'VariableNames',{'VDD_V','TestRows', ...
        'OriginalRMSE_dB','TwoStageRMSE_dB', ...
        'OriginalMAE_dB','TwoStageMAE_dB', ...
        'OriginalR2','TwoStageR2'});

    VoltageResults = [VoltageResults;row]; %#ok<AGROW>
end

fprintf('\n===== PERFORMANCE BY SUPPLY VOLTAGE =====\n');
disp(VoltageResults);

%% 11. Save results

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outDir = fullfile(root,'results', ...
    'Model_Evaluation','Common_Source','RegionAware',stamp);

modelDir = fullfile(root,'models', ...
    'Common_Source','RegionAware',stamp);

if ~exist(outDir,'dir'), mkdir(outDir); end
if ~exist(modelDir,'dir'), mkdir(modelDir); end

PredictionTable = D(isTest,features);
PredictionTable.ActualGain_dB = YTest;
PredictionTable.ActualRegion = RTest;
PredictionTable.PredictedRegion = predictedRegion;
PredictionTable.OriginalPrediction_dB = predA;
PredictionTable.TwoStagePrediction_dB = predC;
PredictionTable.OriginalAbsoluteError_dB = abs(YTest-predA);
PredictionTable.TwoStageAbsoluteError_dB = abs(YTest-predC);

writetable(Results,fullfile(outDir,'model_comparison.csv'));
writetable(VoltageResults,fullfile(outDir,'performance_by_voltage.csv'));
writetable(PredictionTable,fullfile(outDir,'test_predictions.csv'));

writematrix(confusion,fullfile(outDir,'region_confusion_matrix.csv'));

save(fullfile(modelDir,'RegionAwareModels.mat'), ...
    'modelSat','modelRegion','regionModels','features', ...
    'VTO','regionNames','Results','regionAccuracy','confusion');

%% 12. Plot model predictions

fig = figure('Visible','off');

scatter(YTest,predA,24,'filled');
hold on;
scatter(YTest,predC,24,'filled');

lo = min([YTest;predA;predC],[],'omitnan');
hi = max([YTest;predA;predC],[],'omitnan');

plot([lo hi],[lo hi],'k--','LineWidth',1.5);

xlabel('Actual SPICE Peak Gain (dB)');
ylabel('Predicted Peak Gain (dB)');
title('Original vs Two-Stage Region-Aware Model');

legend('Original model','Two-stage model','Ideal prediction', ...
    'Location','best');

grid on;

saveas(fig,fullfile(outDir,'prediction_comparison.png'));
close(fig);

fprintf('\nAnalysis complete.\n');
fprintf('Evaluation results:\n%s\n',outDir);
fprintf('Saved region-aware models:\n%s\n',modelDir);

%% Local helper
function M = regressionMetrics(actual,predicted)

    actual = actual(:);
    predicted = predicted(:);

    valid = isfinite(actual) & isfinite(predicted);

    actual = actual(valid);
    predicted = predicted(valid);

    if isempty(actual)
        M = struct('RMSE',NaN,'MAE',NaN,'R2',NaN);
        return;
    end

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

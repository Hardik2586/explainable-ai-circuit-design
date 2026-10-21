
%% PHASE 2 - MOSFET MODEL TRAINING AND EVALUATION
clear; clc; close all;
rng(42,'twister');

root = 'C:\Internship Project';

dataFile = fullfile(root,'data','universal','Common_Source', ...
    'training_ready','MOSFET_TrainingReady_GainAt1kHz.csv');

modelDir = fullfile(root,'models','Common_Source','Phase2_MOSFET');
resultDir = fullfile(root,'results','Phase2_MOSFET');

if ~isfolder(modelDir), mkdir(modelDir); end
if ~isfolder(resultDir), mkdir(resultDir); end

assert(isfile(dataFile),'Training-ready dataset not found: %s',dataFile);
T = readtable(dataFile);

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F'};
target = 'GainAt1kHz_dB';

assert(all(ismember([features,{target}],T.Properties.VariableNames)), ...
    'One or more required features/target columns are missing.');

X = T{:,features};
Y = T.(target);

valid = all(isfinite(X),2) & isfinite(Y);
T = T(valid,:);
X = X(valid,:);
Y = Y(valid);

assert(size(X,1)>=20,'Too few usable rows for model evaluation.');

%% Group by resistor configuration.
% All CIN variants sharing the same four resistor values stay together.

groupTable = T(:,{'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm'});
[~,~,groupID] = unique(groupTable,'rows');

nGroups = max(groupID);
assert(nGroups>=5,'Too few independent resistor groups for holdout evaluation.');

groupOrder = randperm(nGroups);
nTestGroups = max(1,round(0.20*nGroups));
testGroups = groupOrder(1:nTestGroups);

isTest = ismember(groupID,testGroups);
isTrain = ~isTest;

assert(any(isTrain) && any(isTest),'Invalid grouped split.');

XTrain = X(isTrain,:);
YTrain = Y(isTrain);
XTest = X(isTest,:);
YTest = Y(isTest);

fprintf('Usable rows: %d\n',size(X,1));
fprintf('Unique resistor groups: %d\n',nGroups);
fprintf('Training rows/groups: %d / %d\n',sum(isTrain), ...
    numel(unique(groupID(isTrain))));
fprintf('Test rows/groups: %d / %d\n',sum(isTest), ...
    numel(unique(groupID(isTest))));

%% Fit three candidate models

models = cell(3,1);
modelNames = ["BaggedTrees";"BoostedTrees";"RidgeRegression"];
predictions = zeros(sum(isTest),3);

models{1} = fitrensemble(XTrain,YTrain, ...
    'Method','Bag', ...
    'NumLearningCycles',100, ...
    'Learners',templateTree('MinLeafSize',5));

models{2} = fitrensemble(XTrain,YTrain, ...
    'Method','LSBoost', ...
    'NumLearningCycles',100, ...
    'Learners',templateTree('MinLeafSize',5), ...
    'LearnRate',0.05);

% Standardize ridge inputs using training data only.
mu = mean(XTrain,1);
sigma = std(XTrain,0,1);
sigma(~isfinite(sigma) | sigma<1e-12) = 1;

models{3} = fitrlinear((XTrain-mu)./sigma,YTrain, ...
    'Learner','leastsquares', ...
    'Regularization','ridge', ...
    'Lambda',1);

predictions(:,1) = predict(models{1},XTest);
predictions(:,2) = predict(models{2},XTest);
predictions(:,3) = predict(models{3},(XTest-mu)./sigma);

%% Evaluate held-out predictions

nModels = numel(modelNames);
RMSE = zeros(nModels,1);
MAE = zeros(nModels,1);
R2 = zeros(nModels,1);

for k = 1:nModels
    err = YTest - predictions(:,k);
    RMSE(k) = sqrt(mean(err.^2));
    MAE(k) = mean(abs(err));

    ssRes = sum(err.^2);
    ssTot = sum((YTest-mean(YTest)).^2);

    if ssTot > 0
        R2(k) = 1-ssRes/ssTot;
    else
        R2(k) = NaN;
    end
end

Metrics = table(modelNames,RMSE,MAE,R2, ...
    'VariableNames',{'Model','RMSE_dB','MAE_dB','R2'});

Metrics = sortrows(Metrics,'RMSE_dB','ascend');
disp(Metrics);

writetable(Metrics,fullfile(resultDir,'Phase2_ModelMetrics.csv'));

%% Select by held-out RMSE and save the model bundle

[~,bestIndex] = min(RMSE);

assert(isfinite(RMSE(bestIndex)), ...
    'No model produced a finite RMSE.');

bestModel = models{bestIndex};
bestName = modelNames(bestIndex);

bundle = struct();
bundle.Model = bestModel;
bundle.ModelName = bestName;
bundle.FeatureNames = features;
bundle.TargetName = target;
bundle.TargetUnits = 'dB';
bundle.RidgeMean = mu;
bundle.RidgeStd = sigma;
bundle.TrainingDataset = dataFile;
bundle.RandomSeed = 42;
bundle.SplitMethod = ...
    'Grouped holdout by RGU, RGL, RD, RS resistor configuration';
bundle.TrainingRows = sum(isTrain);
bundle.TestRows = sum(isTest);
bundle.UniqueGroups = nGroups;
bundle.SelectedUsing = 'Lowest held-out RMSE';
bundle.TrainedAt = datetime('now');

save(fullfile(modelDir,'MOSFET_GainModel_Phase2.mat'), ...
    'bundle','Metrics','-v7.3');

%% Save predictions and the exact split for reproducibility

TestResults = table(YTest, ...
    predictions(:,1),predictions(:,2),predictions(:,3), ...
    'VariableNames',{'ActualGain_dB','BaggedTrees_dB', ...
    'BoostedTrees_dB','RidgeRegression_dB'});

TestResults.ResidualBestModel_dB = ...
    YTest-predict(bestModel,XTest);

if bestName == "RidgeRegression"
    TestResults.ResidualBestModel_dB = ...
        YTest-predict(bestModel,(XTest-mu)./sigma);
end

writetable(TestResults,fullfile(resultDir,'Phase2_TestPredictions.csv'));

Split = table((1:height(T))',groupID,isTrain,isTest, ...
    'VariableNames',{'PreparedRow','ResistorGroup','IsTraining','IsTest'});

writetable(Split,fullfile(resultDir,'Phase2_GroupedSplit.csv'));

fprintf('\nPHASE 2 TRAINING COMPLETE\n');
fprintf('Selected model: %s\n',bestName);
fprintf('Held-out RMSE: %.4f dB\n',RMSE(bestIndex));
fprintf('Held-out MAE: %.4f dB\n',MAE(bestIndex));
fprintf('Held-out R2: %.4f\n',R2(bestIndex));
fprintf('Saved model: %s\n', ...
    fullfile(modelDir,'MOSFET_GainModel_Phase2.mat'));
fprintf('Saved metrics: %s\n', ...
    fullfile(resultDir,'Phase2_ModelMetrics.csv'));

%% PHASE 4G: STRICT VALIDATION AND MODEL SELECTION
% Universal Circuit-XAI
%
% Compare:
%   A. Global DC-enhanced bagged-tree regressor
%   B. Classifier-routed ridge specialist
%
% Validation:
%   Leave-one-DC-operating-point-group-out
%
% No held-out targets are used for model fitting or routing.
% The same held-out circuits are used for both models.

clear;
clc;
close all;
rng(42,'twister');

%% 1. Paths and dataset
root = 'C:\Internship Project';

dataFile = fullfile(root,'data','universal', ...
    'Common_Source','external_model_validation', ...
    '20261020_000113','CS_Dataset_v2_100.mat');

assert(isfile(dataFile), ...
    'Dataset not found: %s',dataFile);

S = load(dataFile);
T = S.rows;

%% 2. Features and target
featureNames = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A'};

targetName = 'GainAt1kHz_dB';
lowThreshold = -10;

assert(ismember(targetName,T.Properties.VariableNames), ...
    'Target column missing.');

assert(all(ismember(featureNames,T.Properties.VariableNames)), ...
    'One or more feature columns missing.');

valid = logical(T.SimulationValid);

for k = 1:numel(featureNames)
    valid = valid & isfinite(T.(featureNames{k}));
end

valid = valid & isfinite(T.(targetName));
T = T(valid,:);

n = height(T);
X = zeros(n,numel(featureNames));

for k = 1:numel(featureNames)
    X(:,k) = T.(featureNames{k});
end

Y = T.(targetName);
circuitID = T.CircuitID;
isLow = Y < lowThreshold;

fprintf('Valid circuits: %d\n',n);
fprintf('Low-gain circuits: %d\n',sum(isLow));
fprintf('Other circuits: %d\n',sum(~isLow));

%% 3. Group by rounded DC operating point
% Every circuit with the same rounded operating point is
% held out together.

groupTable = table( ...
    round(T.VGS_V,3), ...
    round(T.VDS_V,3), ...
    round(T.ID_A,5), ...
    'VariableNames',{'VGS','VDS','ID'});

[~,~,groupID] = unique(groupTable,'rows');
numGroups = max(groupID);

fprintf('Unique DC operating-point groups: %d\n',numGroups);

if numGroups < 2
    error('At least two groups are required.');
end

%% 4. Allocate out-of-group predictions
predGlobal = nan(n,1);
predRidge = nan(n,1);
probLow = nan(n,1);
routeLow = false(n,1);
heldOutGroup = zeros(n,1);

%% 5. Leave-one-group-out validation
for g = 1:numGroups

    testIdx = groupID == g;
    trainIdx = ~testIdx;

    XTrain = X(trainIdx,:);
    YTrain = Y(trainIdx);
    XTest = X(testIdx,:);

    lowTrain = YTrain < lowThreshold;

    fprintf('\nGroup %d/%d | Train: %d | Test: %d | Low-gain train: %d\n', ...
        g,numGroups,sum(trainIdx),sum(testIdx),sum(lowTrain));

    %% 5A. Global bagged-tree model
    globalModel = fitrensemble( ...
        XTrain,YTrain, ...
        'Method','Bag', ...
        'NumLearningCycles',100, ...
        'Learners',templateTree('MinLeafSize',5));

    globalTest = predict(globalModel,XTest);
    predGlobal(testIdx) = globalTest;

    %% 5B. Train low-gain classifier
    if numel(unique(lowTrain)) < 2
        error(['Group %d leaves only one low-gain class in training. ' ...
            'Cannot fit the routing classifier.'],g);
    end

    classLabels = categorical( ...
        lowTrain,[false true],{'Other','LowGain'});

    classifier = fitcensemble( ...
        XTrain,classLabels, ...
        'Method','Bag', ...
        'NumLearningCycles',100, ...
        'Learners',templateTree('MinLeafSize',3));

    [~,scores] = predict(classifier,XTest);

    classNames = string(classifier.ClassNames);
    lowColumn = find(classNames == "LowGain",1);

    if isempty(lowColumn)
        error('LowGain class not found in group %d.',g);
    end

    pLow = scores(:,lowColumn);
    useSpecialist = pLow >= 0.5;

    probLow(testIdx) = pLow;
    routeLow(testIdx) = useSpecialist;
    heldOutGroup(testIdx) = g;

    %% 5C. Fit ridge specialist using low-gain training circuits
    XLow = XTrain(lowTrain,:);
    YLow = YTrain(lowTrain);

    if numel(YLow) < 3
        error(['Only %d low-gain training samples in group %d. ' ...
            'Insufficient for this specialist experiment.'], ...
            numel(YLow),g);
    end

    % Standardization uses specialist training data only.
    muLow = mean(XLow,1);
    sigmaLow = std(XLow,0,1);

    sigmaLow(~isfinite(sigmaLow) | sigmaLow < 1e-12) = 1;

    XLowZ = (XLow-muLow)./sigmaLow;
    XTestZ = (XTest-muLow)./sigmaLow;

    ridgeModel = fitrlinear( ...
        XLowZ,YLow, ...
        'Learner','leastsquares', ...
        'Regularization','ridge', ...
        'Lambda',1);

    ridgeTest = predict(ridgeModel,XTestZ);

    %% 5D. Route predictions
    combined = globalTest;
    combined(useSpecialist) = ridgeTest(useSpecialist);

    predRidge(testIdx) = combined;
end

%% 6. Check complete predictions
assert(all(isfinite(predGlobal)), ...
    'Global predictions incomplete.');

assert(all(isfinite(predRidge)), ...
    'Ridge predictions incomplete.');

assert(all(isfinite(probLow)), ...
    'Routing probabilities incomplete.');

%% 7. Overall out-of-group metrics
resGlobal = Y-predGlobal;
resRidge = Y-predRidge;

Model = ["Global_DC_BaggedTrees";"Routed_Ridge_Specialist"];

MAE = [mean(abs(resGlobal));mean(abs(resRidge))];

RMSE = [sqrt(mean(resGlobal.^2));sqrt(mean(resRidge.^2))];

SST = sum((Y-mean(Y)).^2);

R2 = [ ...
    1-sum(resGlobal.^2)/SST; ...
    1-sum(resRidge.^2)/SST];

Overall = table(Model,MAE,RMSE,R2);

fprintf('\n===== OVERALL LEAVE-ONE-GROUP-OUT RESULTS =====\n');
disp(Overall);

%% 8. Metrics by actual target group
Group = ["Actual gain below -10 dB"; ...
         "Actual gain at least -10 dB"];

Count = [sum(isLow);sum(~isLow)];

GlobalMAE = [mean(abs(resGlobal(isLow))); ...
             mean(abs(resGlobal(~isLow)))];

RidgeMAE = [mean(abs(resRidge(isLow))); ...
            mean(abs(resRidge(~isLow)))];

GlobalRMSE = [sqrt(mean(resGlobal(isLow).^2)); ...
              sqrt(mean(resGlobal(~isLow).^2))];

RidgeRMSE = [sqrt(mean(resRidge(isLow).^2)); ...
             sqrt(mean(resRidge(~isLow).^2))];

ByGroup = table(Group,Count,GlobalMAE,RidgeMAE, ...
    GlobalRMSE,RidgeRMSE);

fprintf('\n===== PERFORMANCE BY ACTUAL TARGET GROUP =====\n');
disp(ByGroup);

%% 9. Routing metrics
TP = sum(routeLow & isLow);
FP = sum(routeLow & ~isLow);
FN = sum(~routeLow & isLow);
TN = sum(~routeLow & ~isLow);

Recall = TP/max(TP+FN,1);
Precision = TP/max(TP+FP,1);
Specificity = TN/max(TN+FP,1);

Routing = table(TP,FP,FN,TN,Recall,Precision,Specificity);

fprintf('\n===== ROUTING METRICS =====\n');
disp(Routing);

%% 10. Per-circuit results
PerCircuit = table( ...
    circuitID,Y,predGlobal,predRidge, ...
    abs(resGlobal),abs(resRidge),probLow, ...
    routeLow,isLow,heldOutGroup, ...
    'VariableNames',{ ...
    'CircuitID','ActualGain_dB','GlobalPrediction_dB', ...
    'RidgePrediction_dB','GlobalAbsoluteError_dB', ...
    'RidgeAbsoluteError_dB','PredictedLowGainProbability', ...
    'RoutedToSpecialist','ActualLowGain','HeldOutGroup'});

% Positive improvement means ridge has lower absolute error.
PerCircuit.ErrorImprovement_dB = ...
    PerCircuit.GlobalAbsoluteError_dB - ...
    PerCircuit.RidgeAbsoluteError_dB;

PerCircuit = sortrows(PerCircuit,'GlobalAbsoluteError_dB','descend');

fprintf('\n===== WORST 15 GLOBAL-MODEL CIRCUITS =====\n');
disp(PerCircuit(1:min(15,height(PerCircuit)),:));

%% 11. Summary of specialist improvements
fprintf('\nMean absolute-error improvement: %.4f dB\n', ...
    mean(PerCircuit.ErrorImprovement_dB));

fprintf('Circuits improved by specialist: %d/%d\n', ...
    sum(PerCircuit.ErrorImprovement_dB > 0),n);

fprintf('Circuits worsened by specialist: %d/%d\n', ...
    sum(PerCircuit.ErrorImprovement_dB < 0),n);

%% 12. Save results
outDir = fullfile(root,'results', ...
    ['Phase4G_StrictValidation_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss'))]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

writetable(Overall,fullfile(outDir, ...
    'Phase4G_Overall_Metrics.csv'));

writetable(ByGroup,fullfile(outDir, ...
    'Phase4G_Group_Metrics.csv'));

writetable(Routing,fullfile(outDir, ...
    'Phase4G_Routing_Metrics.csv'));

writetable(PerCircuit,fullfile(outDir, ...
    'Phase4G_PerCircuit_Results.csv'));

%% 13. Plot actual versus predicted
fig = figure('Color','w');

scatter(Y,predGlobal,45,'filled');
hold on;
scatter(Y,predRidge,45,'filled');

lo = min([Y;predGlobal;predRidge]);
hi = max([Y;predGlobal;predRidge]);

plot([lo hi],[lo hi],'k--','LineWidth',1.4);

xlabel('Actual Gain (dB)');
ylabel('Predicted Gain (dB)');
title('Phase 4G: Leave-One-Group-Out Predictions');

legend('Global model','Ridge specialist','Ideal prediction', ...
    'Location','best');

grid on;

exportgraphics(fig,fullfile(outDir, ...
    'Phase4G_Actual_vs_Predicted.png'),'Resolution',200);

%% 14. Plot absolute errors
fig = figure('Color','w');

scatter(Y,abs(resGlobal),45,'filled');
hold on;
scatter(Y,abs(resRidge),45,'filled');

xlabel('Actual Gain (dB)');
ylabel('Absolute Error (dB)');
title('Phase 4G: Leave-One-Group-Out Absolute Errors');

legend('Global model','Ridge specialist','Location','best');
grid on;

exportgraphics(fig,fullfile(outDir, ...
    'Phase4G_Absolute_Errors.png'),'Resolution',200);

fprintf('\nResults saved to:\n%s\n',outDir);
fprintf('\nPhase 4G completed successfully.\n');

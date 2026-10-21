
%% PHASE 4F: SPECIALIST ROBUSTNESS AND ERROR ANALYSIS
% Universal Circuit-XAI
%
% Models:
%   1. Global DC-enhanced bagged-tree regressor
%   2. Classifier-routed linear specialist
%   3. Classifier-routed ridge specialist
%
% Validation:
%   Grouped 5-fold cross-validation
%
% Important:
%   - No held-out targets are used for routing.
%   - Ridge standardization uses training specialist samples only.
%   - Source dataset is never modified.

clear;
clc;
close all;
rng(42,'twister');

%% 1. Paths
root = 'C:\Internship Project';

dataFile = fullfile(root,'data','universal', ...
    'Common_Source','external_model_validation', ...
    '20261020_000113','CS_Dataset_v2_100.mat');

assert(isfile(dataFile), ...
    'Dataset file not found: %s',dataFile);

S = load(dataFile);
T = S.rows;

%% 2. Features and target
featureNames = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A'};

targetName = 'GainAt1kHz_dB';
lowThreshold = -10;
numFolds = 5;

assert(ismember(targetName,T.Properties.VariableNames), ...
    'Target column is missing.');

assert(all(ismember(featureNames,T.Properties.VariableNames)), ...
    'One or more predictor columns are missing.');

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

if sum(isLow) < 5
    error('Too few low-gain samples for this experiment.');
end

%% 3. Group circuits by rounded DC operating point
% Circuits with similar rounded DC operating points remain
% in the same validation fold.

groupTable = table( ...
    round(T.VGS_V,3), ...
    round(T.VDS_V,3), ...
    round(T.ID_A,5), ...
    'VariableNames',{'VGS','VDS','ID'});

[~,~,groupID] = unique(groupTable,'rows');

numGroups = max(groupID);

if numGroups < numFolds
    error('Not enough distinct groups for 5-fold validation.');
end

groupSizes = accumarray(groupID,1);
[~,groupOrder] = sort(groupSizes,'descend');

foldSizes = zeros(numFolds,1);
groupFold = zeros(numGroups,1);

% Greedy assignment of entire groups to the currently smallest fold.
for k = 1:numGroups
    g = groupOrder(k);
    [~,f] = min(foldSizes);

    groupFold(g) = f;
    foldSizes(f) = foldSizes(f) + groupSizes(g);
end

foldID = groupFold(groupID);

fprintf('\nFold sizes:\n');
disp(accumarray(foldID,1,[numFolds,1]));

%% 4. Allocate out-of-fold predictions
predGlobal = nan(n,1);
predLinear = nan(n,1);
predRidge = nan(n,1);

probLow = nan(n,1);
routeLow = false(n,1);

%% 5. Grouped cross-validation
for f = 1:numFolds

    trainIdx = foldID ~= f;
    testIdx = foldID == f;

    XTrain = X(trainIdx,:);
    YTrain = Y(trainIdx);
    XTest = X(testIdx,:);

    lowTrain = YTrain < lowThreshold;

    fprintf('\nFold %d/%d\n',f,numFolds);
    fprintf('Train: %d | Test: %d | Low-gain train: %d\n', ...
        sum(trainIdx),sum(testIdx),sum(lowTrain));

    if sum(lowTrain) < 5
        error('Fold %d has too few specialist training samples.',f);
    end

    %% 5A. Global bagged-tree model
    globalModel = fitrensemble( ...
        XTrain,YTrain, ...
        'Method','Bag', ...
        'NumLearningCycles',100, ...
        'Learners',templateTree('MinLeafSize',5));

    globalTest = predict(globalModel,XTest);
    predGlobal(testIdx) = globalTest;

    %% 5B. Train low-gain classifier
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
        error('LowGain class not found in fold %d.',f);
    end

    pLow = scores(:,lowColumn);
    useSpecialist = pLow >= 0.5;

    probLow(testIdx) = pLow;
    routeLow(testIdx) = useSpecialist;

    %% 5C. Fit linear specialist
    XLow = XTrain(lowTrain,:);
    YLow = YTrain(lowTrain);

    linearModel = fitlm(XLow,YLow);
    linearTest = predict(linearModel,XTest);

    %% 5D. Fit ridge specialist
    % Standardize using only low-gain training samples.
    % This avoids the unsupported Standardize argument.

    muLow = mean(XLow,1);
    sigmaLow = std(XLow,0,1);

    % Protect constant predictors from division by zero.
    sigmaLow(~isfinite(sigmaLow) | sigmaLow < 1e-12) = 1;

    XLowZ = (XLow-muLow)./sigmaLow;
    XTestZ = (XTest-muLow)./sigmaLow;

    ridgeModel = fitrlinear( ...
        XLowZ,YLow, ...
        'Learner','leastsquares', ...
        'Regularization','ridge', ...
        'Lambda',1);

    ridgeTest = predict(ridgeModel,XTestZ);

    %% 5E. Route both specialist predictions
    % Start with global predictions, then replace only those
    % predictions routed by the classifier.

    combinedLinear = globalTest;
    combinedRidge = globalTest;

    combinedLinear(useSpecialist) = ...
        linearTest(useSpecialist);

    combinedRidge(useSpecialist) = ...
        ridgeTest(useSpecialist);

    predLinear(testIdx) = combinedLinear;
    predRidge(testIdx) = combinedRidge;

    fprintf('Routed to specialist: %d/%d\n', ...
        sum(useSpecialist),sum(testIdx));
end

%% 6. Check out-of-fold coverage
assert(all(isfinite(predGlobal)), ...
    'Global predictions contain missing values.');

assert(all(isfinite(predLinear)), ...
    'Linear specialist predictions contain missing values.');

assert(all(isfinite(predRidge)), ...
    'Ridge specialist predictions contain missing values.');

assert(all(isfinite(probLow)), ...
    'Routing probabilities contain missing values.');

%% 7. Overall metrics
predictions = {predGlobal,predLinear,predRidge};

modelNames = [ ...
    "Global_DC_BaggedTrees"; ...
    "Routed_Linear_Specialist"; ...
    "Routed_Ridge_Specialist"];

MAE = zeros(3,1);
RMSE = zeros(3,1);
R2 = zeros(3,1);

SST = sum((Y-mean(Y)).^2);

for m = 1:3
    residual = Y-predictions{m};

    MAE(m) = mean(abs(residual));
    RMSE(m) = sqrt(mean(residual.^2));
    R2(m) = 1-sum(residual.^2)/SST;
end

Overall = table(modelNames,MAE,RMSE,R2);

fprintf('\n===== OVERALL GROUPED OOF METRICS =====\n');
disp(Overall);

%% 8. Metrics by actual-gain group
groupNames = ["Below -10 dB";"At least -10 dB"];
masks = {isLow,~isLow};

Group = strings(6,1);
Model = strings(6,1);
Count = zeros(6,1);
GroupMAE = zeros(6,1);
GroupRMSE = zeros(6,1);

r = 0;

for g = 1:2
    mask = masks{g};

    for m = 1:3
        r = r+1;
        residual = Y(mask)-predictions{m}(mask);

        Group(r) = groupNames(g);
        Model(r) = modelNames(m);
        Count(r) = sum(mask);
        GroupMAE(r) = mean(abs(residual));
        GroupRMSE(r) = sqrt(mean(residual.^2));
    end
end

ByGroup = table(Group,Model,Count,GroupMAE,GroupRMSE);

fprintf('\n===== PERFORMANCE BY ACTUAL-GAIN GROUP =====\n');
disp(ByGroup);

%% 9. Routing diagnostics
% Actual target labels are used only to evaluate routing performance.

TP = sum(routeLow & isLow);
FP = sum(routeLow & ~isLow);
FN = sum(~routeLow & isLow);
TN = sum(~routeLow & ~isLow);

RoutingRecall = TP/max(TP+FN,1);
RoutingPrecision = TP/max(TP+FP,1);
RoutingSpecificity = TN/max(TN+FP,1);

RoutingMetrics = table(TP,FP,FN,TN, ...
    RoutingRecall,RoutingPrecision,RoutingSpecificity);

fprintf('\n===== LOW-GAIN ROUTING METRICS =====\n');
disp(RoutingMetrics);

%% 10. Per-circuit prediction comparison
ResidualGlobal = Y-predGlobal;
ResidualLinear = Y-predLinear;
ResidualRidge = Y-predRidge;

PerCircuit = table( ...
    circuitID,Y,predGlobal,predLinear,predRidge, ...
    abs(ResidualGlobal),abs(ResidualLinear),abs(ResidualRidge), ...
    probLow,routeLow,isLow,foldID, ...
    'VariableNames',{ ...
    'CircuitID','ActualGain_dB','GlobalPrediction_dB', ...
    'LinearSpecialistPrediction_dB','RidgeSpecialistPrediction_dB', ...
    'GlobalAbsoluteError_dB','LinearAbsoluteError_dB', ...
    'RidgeAbsoluteError_dB','PredictedLowGainProbability', ...
    'RoutedToSpecialist','ActualLowGain','Fold'});

PerCircuit = sortrows(PerCircuit, ...
    'GlobalAbsoluteError_dB','descend');

%% 11. Inspect previously difficult circuits
focusIDs = [29 35 43 3 13 26 41 54 80];

Focus = PerCircuit(ismember(PerCircuit.CircuitID,focusIDs),:);
Focus = sortrows(Focus,'CircuitID');

fprintf('\n===== PREVIOUSLY DIFFICULT CIRCUITS =====\n');
disp(Focus);

%% 12. Save results
outDir = fullfile(root,'results', ...
    ['Phase4F_Robustness_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss'))]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

writetable(Overall,fullfile(outDir, ...
    'Phase4F_Overall_Metrics.csv'));

writetable(ByGroup,fullfile(outDir, ...
    'Phase4F_Group_Metrics.csv'));

writetable(RoutingMetrics,fullfile(outDir, ...
    'Phase4F_Routing_Metrics.csv'));

writetable(PerCircuit,fullfile(outDir, ...
    'Phase4F_PerCircuit_Predictions.csv'));

writetable(Focus,fullfile(outDir, ...
    'Phase4F_Difficult_Circuits.csv'));

%% 13. Plot overall model comparison
fig = figure('Color','w');

bar(categorical(modelNames),[MAE RMSE]);

ylabel('Error (dB)');
title('Phase 4F: Grouped Out-of-Fold Model Comparison');
legend('MAE','RMSE','Location','best');
grid on;

exportgraphics(fig,fullfile(outDir, ...
    'Phase4F_Model_Comparison.png'),'Resolution',200);

%% 14. Plot low-gain predictions
fig = figure('Color','w');

scatter(Y(isLow),predGlobal(isLow),60,'filled');
hold on;
scatter(Y(isLow),predLinear(isLow),60,'filled');
scatter(Y(isLow),predRidge(isLow),60,'filled');

lo = min([Y(isLow);predGlobal(isLow); ...
    predLinear(isLow);predRidge(isLow)]);

hi = max([Y(isLow);predGlobal(isLow); ...
    predLinear(isLow);predRidge(isLow)]);

plot([lo hi],[lo hi],'k--','LineWidth',1.4);

xlabel('Actual Gain (dB)');
ylabel('Predicted Gain (dB)');
title('Phase 4F: Low-Gain Circuit Predictions');

legend('Global','Linear specialist','Ridge specialist', ...
    'Ideal prediction','Location','best');

grid on;

exportgraphics(fig,fullfile(outDir, ...
    'Phase4F_LowGain_Comparison.png'),'Resolution',200);

%% 15. Finish
fprintf('\nResults saved to:\n%s\n',outDir);
fprintf('\nPhase 4F completed successfully.\n');

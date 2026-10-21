clear; clc; close all;
rng(42, 'twister');

root = 'C:\Internship Project';

dataFile = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'external_model_validation', ...
    '20261020_000113', 'CS_Dataset_v2_100.mat');

assert(isfile(dataFile), 'Dataset MAT file not found.');

S = load(dataFile);
T = S.rows;

%% 1. Select target and features
featureNames = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A'};

targetName = 'GainAt1kHz_dB';

assert(ismember(targetName, T.Properties.VariableNames), ...
    'Target column is missing.');

assert(all(ismember(featureNames, T.Properties.VariableNames)), ...
    'One or more feature columns are missing.');

valid = logical(T.SimulationValid);

for k = 1:numel(featureNames)
    x = T.(featureNames{k});
    valid = valid & isfinite(x);
end

valid = valid & isfinite(T.(targetName));

T = T(valid,:);

X = zeros(height(T), numel(featureNames));
for k = 1:numel(featureNames)
    X(:,k) = T.(featureNames{k});
end

Y = T.(targetName);
circuitID = T.CircuitID;

fprintf('Valid circuits: %d\n', height(T));
fprintf('Low-gain circuits (Y < -10 dB): %d\n', sum(Y < -10));
fprintf('Other circuits: %d\n', sum(Y >= -10));

assert(sum(Y < -10) >= 5, ...
    'Too few low-gain circuits for this experiment.');

%% 2. Create grouped folds using rounded DC operating points
% Circuits with similar rounded operating points stay in the same fold.
% This reduces leakage between repeated operating points.

groupTable = table( ...
    round(T.VGS_V,3), ...
    round(T.VDS_V,3), ...
    round(T.ID_A,5), ...
    'VariableNames', {'VGS','VDS','ID'});

[~,~,groupID] = unique(groupTable, 'rows');

numGroups = max(groupID);
numFolds = 5;

assert(numGroups >= numFolds, ...
    'Not enough distinct groups for five-fold validation.');

% Assign whole groups to folds, balancing approximate circuit counts.
groupSizes = accumarray(groupID, 1);
[~, groupOrder] = sort(groupSizes, 'descend');

foldSizes = zeros(numFolds,1);
groupFold = zeros(numGroups,1);

for k = 1:numGroups
    g = groupOrder(k);
    [~, f] = min(foldSizes);
    groupFold(g) = f;
    foldSizes(f) = foldSizes(f) + groupSizes(g);
end

foldID = groupFold(groupID);

fprintf('\nFold sizes:\n');
disp(accumarray(foldID,1,[numFolds,1]));

%% 3. Prepare out-of-fold predictions
n = numel(Y);

globalOOF = nan(n,1);
specialistOOF = nan(n,1);
routeOOF = false(n,1);
lowGainProbabilityOOF = nan(n,1);

foldMetrics = table();

%% 4. Run grouped cross-validation
for f = 1:numFolds

    testIdx = foldID == f;
    trainIdx = ~testIdx;

    XTrain = X(trainIdx,:);
    YTrain = Y(trainIdx);

    XTest = X(testIdx,:);

    % Classifier labels are determined from TRAINING targets only.
    lowTrain = YTrain < -10;

    fprintf('\nFold %d/%d\n', f, numFolds);
    fprintf('Training circuits: %d\n', sum(trainIdx));
    fprintf('Held-out circuits: %d\n', sum(testIdx));
    fprintf('Low-gain training circuits: %d\n', sum(lowTrain));

    %% Global regressor
    globalModel = fitrensemble( ...
        XTrain, YTrain, ...
        'Method','Bag', ...
        'NumLearningCycles',100, ...
        'Learners',templateTree('MinLeafSize',5));

    globalOOF(testIdx) = predict(globalModel, XTest);

    %% Specialist routing classifier
    % Use a binary classifier to estimate P(low gain | features).
    classLabels = categorical(lowTrain, [false true], ...
        {'Other','LowGain'});

    classifier = fitcensemble( ...
        XTrain, classLabels, ...
        'Method','Bag', ...
        'NumLearningCycles',100, ...
        'Learners',templateTree('MinLeafSize',3));

    [~, scores] = predict(classifier, XTest);

    classNames = string(classifier.ClassNames);
    lowColumn = find(classNames == "LowGain", 1);

    if isempty(lowColumn)
        error('LowGain class was not found in classifier classes.');
    end

    pLow = scores(:,lowColumn);
    lowGainProbabilityOOF(testIdx) = pLow;

    % Routing threshold fixed before evaluating held-out predictions.
    useSpecialist = pLow >= 0.5;
    routeOOF(testIdx) = useSpecialist;

    %% Specialist regressor
    % Only training-fold low-gain samples are used to fit this model.
    %
    % Linear regression is intentionally simple because the specialist
    % dataset is small. It acts as an experimental baseline, not an
    % assumption that the relationship is truly linear.

    if sum(lowTrain) >= 5
        specialistModel = fitlm( ...
            XTrain(lowTrain,:), YTrain(lowTrain));

        specialistPred = predict(specialistModel, XTest);
    else
        warning(['Fold %d has fewer than five low-gain training ' ...
            'samples. Using the global model as specialist fallback.'], f);

        specialistPred = predict(globalModel, XTest);
    end

    % Route using classifier predictions only.
    combinedPred = predict(globalModel, XTest);
    combinedPred(useSpecialist) = specialistPred(useSpecialist);

    specialistOOF(testIdx) = combinedPred;

    fprintf('Held-out circuits routed to specialist: %d/%d\n', ...
        sum(useSpecialist), sum(testIdx));
end

%% 5. Evaluate OOF predictions
actual = Y;

baselineResidual = actual - globalOOF;
specialistResidual = actual - specialistOOF;

modelName = ["Global_DC_BaggedTrees"; ...
             "Classifier_Routed_Specialist"];

MAE = [mean(abs(baselineResidual)); ...
       mean(abs(specialistResidual))];

RMSE = [sqrt(mean(baselineResidual.^2)); ...
        sqrt(mean(specialistResidual.^2))];

SST = sum((actual - mean(actual)).^2);

R2 = [ ...
    1 - sum(baselineResidual.^2)/SST; ...
    1 - sum(specialistResidual.^2)/SST];

Summary = table(modelName, MAE, RMSE, R2);

fprintf('\n===== OVERALL GROUPED OOF RESULTS =====\n');
disp(Summary);

%% 6. Evaluate low-gain and other circuits separately
lowActual = actual < -10;
otherActual = ~lowActual;

Group = ["Actual gain below -10 dB"; ...
         "Actual gain at least -10 dB"];

Count = [sum(lowActual); sum(otherActual)];

GlobalMAE = [ ...
    mean(abs(baselineResidual(lowActual))); ...
    mean(abs(baselineResidual(otherActual)))];

SpecialistMAE = [ ...
    mean(abs(specialistResidual(lowActual))); ...
    mean(abs(specialistResidual(otherActual)))];

GlobalRMSE = [ ...
    sqrt(mean(baselineResidual(lowActual).^2)); ...
    sqrt(mean(baselineResidual(otherActual).^2))];

SpecialistRMSE = [ ...
    sqrt(mean(specialistResidual(lowActual).^2)); ...
    sqrt(mean(specialistResidual(otherActual).^2))];

GroupSummary = table(Group, Count, ...
    GlobalMAE, SpecialistMAE, GlobalRMSE, SpecialistRMSE);

fprintf('\n===== PERFORMANCE BY ACTUAL TARGET GROUP =====\n');
disp(GroupSummary);

%% 7. Save per-circuit OOF predictions
Predictions = table( ...
    circuitID, actual, globalOOF, specialistOOF, ...
    baselineResidual, specialistResidual, ...
    lowGainProbabilityOOF, routeOOF, ...
    'VariableNames', { ...
    'CircuitID','ActualGain_dB','GlobalPrediction_dB', ...
    'SpecialistPrediction_dB','GlobalResidual_dB', ...
    'SpecialistResidual_dB','PredictedLowGainProbability', ...
    'RoutedToSpecialist'});

writetable(Predictions, fullfile(outDirPlaceholder(), ...
    'placeholder.csv'));


%% 8. Save results and plots
outDir = fullfile(root, 'results', ...
    ['Phase4E_LowGainSpecialist_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss'))]);

mkdir(outDir);

writetable(Summary, fullfile(outDir, ...
    'Phase4E_Overall_Metrics.csv'));

writetable(GroupSummary, fullfile(outDir, ...
    'Phase4E_Group_Metrics.csv'));

writetable(Predictions, fullfile(outDir, ...
    'Phase4E_OOF_Predictions.csv'));

%% Plot overall predictions
fig = figure('Color','w');

scatter(actual, globalOOF, 42, 'filled');
hold on;
scatter(actual, specialistOOF, 42, 'filled');

lo = min([actual; globalOOF; specialistOOF]);
hi = max([actual; globalOOF; specialistOOF]);

plot([lo hi],[lo hi],'k--','LineWidth',1.4);

xlabel('Actual Gain at 1 kHz (dB)');
ylabel('Out-of-Fold Predicted Gain (dB)');
title('Phase 4E: Global vs Specialist Model');
legend('Global model','Specialist model','Ideal prediction', ...
    'Location','best');
grid on;

exportgraphics(fig, fullfile(outDir, ...
    'Phase4E_Global_vs_Specialist.png'), ...
    'Resolution',200);

%% Compare absolute errors
fig = figure('Color','w');

scatter(actual, abs(baselineResidual), 42, 'filled');
hold on;
scatter(actual, abs(specialistResidual), 42, 'filled');

xlabel('Actual Gain at 1 kHz (dB)');
ylabel('Absolute Error (dB)');
title('Phase 4E: Absolute Error Comparison');
legend('Global model','Specialist model','Location','best');
grid on;

exportgraphics(fig, fullfile(outDir, ...
    'Phase4E_Absolute_Error.png'), 'Resolution',200);

fprintf('\nResults saved to:\n%s\n', outDir);

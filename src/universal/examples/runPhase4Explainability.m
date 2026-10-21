
%% PHASE 4: EXPLAINABLE AI
% MATLAB-only permutation importance and feature-effect analysis.
% Uses the existing 100-circuit dataset without modifying it.

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

featureNames = { ...
    'RGU_Ohm', 'RGL_Ohm', 'RD_Ohm', ...
    'RS_Ohm', 'CIN_F', 'VGS_V', 'VDS_V', 'ID_A'};

assert(all(ismember([featureNames, {target}], ...
    T.Properties.VariableNames)), ...
    'Required columns are missing.');

X = T{:, featureNames};
Y = T.(target);

valid = all(isfinite(X),2) & isfinite(Y);
X = X(valid,:);
Y = Y(valid);
T = T(valid,:);

n = numel(Y);
K = 5;

% Create held-out folds
cv = cvpartition(n, 'KFold', K);

oofPrediction = nan(n,1);
importanceByFold = nan(K, numel(featureNames));

%% 1. Held-out permutation importance

for k = 1:K

    trainIdx = training(cv,k);
    testIdx = test(cv,k);

    Xtrain = X(trainIdx,:);
    Ytrain = Y(trainIdx);
    Xtest = X(testIdx,:);
    Ytest = Y(testIdx);

    mdl = fitrensemble( ...
        Xtrain, Ytrain, ...
        'Method','Bag', ...
        'NumLearningCycles',100, ...
        'Learners',templateTree('MinLeafSize',5));

    baselinePrediction = predict(mdl, Xtest);
    oofPrediction(testIdx) = baselinePrediction;

    baselineRMSE = sqrt(mean((Ytest-baselinePrediction).^2));

    for j = 1:numel(featureNames)

        % Repeat permutations to reduce random noise
        repeatRMSE = nan(10,1);

        for r = 1:10
            Xpermuted = Xtest;
            order = randperm(size(Xtest,1));

            Xpermuted(:,j) = Xpermuted(order,j);

            permutedPrediction = predict(mdl, Xpermuted);

            repeatRMSE(r) = sqrt(mean( ...
                (Ytest-permutedPrediction).^2));
        end

        importanceByFold(k,j) = ...
            mean(repeatRMSE) - baselineRMSE;
    end

    fprintf('Completed XAI fold %d/%d\n',k,K);
end

%% 2. Summarize importance

meanImportance = mean(importanceByFold,1)';
stdImportance = std(importanceByFold,0,1)';

importanceTable = table( ...
    string(featureNames(:)), ...
    meanImportance, stdImportance, ...
    'VariableNames', ...
    {'Feature','MeanIncreaseInRMSE_dB','StdAcrossFolds_dB'});

importanceTable = sortrows( ...
    importanceTable,'MeanIncreaseInRMSE_dB','descend');

disp('===== HELD-OUT PERMUTATION IMPORTANCE =====');
disp(importanceTable);

%% 3. Save experiment

resultsDir = fullfile(root,'results', ...
    ['Phase4_XAI_' datestr(now,'yyyymmdd_HHMMSS')]);

mkdir(resultsDir);

writetable(importanceTable, fullfile(resultsDir, ...
    'XAI_Permutation_Importance.csv'));

writetable(array2table(importanceByFold, ...
    'VariableNames',featureNames), ...
    fullfile(resultsDir,'XAI_Importance_By_Fold.csv'));

%% 4. Plot importance

figure('Name','XAI Permutation Importance');

barh(importanceTable.MeanIncreaseInRMSE_dB);
yticks(1:height(importanceTable));
yticklabels(importanceTable.Feature);
xlabel('Increase in held-out RMSE (dB)');
ylabel('Feature');
title('Permutation Importance Across Five Folds');
grid on;

set(gca,'YDir','reverse');

saveas(gcf,fullfile(resultsDir, ...
    'XAI_Permutation_Importance.png'));

%% 5. Save out-of-fold predictions

predictionTable = table(Y,oofPrediction, ...
    Y-oofPrediction,abs(Y-oofPrediction), ...
    'VariableNames',{'ActualGain_dB', ...
    'PredictedGain_dB','Residual_dB','AbsoluteError_dB'});

writetable(predictionTable,fullfile(resultsDir, ...
    'XAI_OutOfFold_Predictions.csv'));

fprintf('\nXAI experiment saved to:\n%s\n',resultsDir);

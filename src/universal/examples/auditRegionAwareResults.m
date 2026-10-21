
%% AUDIT REGION-AWARE MODEL RESULTS
clear; clc; close all;

root = 'C:\Internship Project';

dataFile = fullfile(root,'results','Optimization', ...
    'Common_Source_Exhaustive','20261013_030513', ...
    'all_1215_candidate_results.csv');

predictionFile = fullfile(root,'results','Model_Evaluation', ...
    'Common_Source','RegionAware','20261013_151249', ...
    'test_predictions.csv');

modelFile = fullfile(root,'models','Common_Source', ...
    'RegionAware','20261013_151249','RegionAwareModels.mat');

assert(isfile(dataFile),'Dataset not found: %s',dataFile);
assert(isfile(predictionFile),'Predictions not found: %s',predictionFile);
assert(isfile(modelFile),'Saved models not found: %s',modelFile);

D = readtable(dataFile);
P = readtable(predictionFile);
M = load(modelFile);

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

%% 1. Check the saved test predictions

requiredP = [features, {'ActualGain_dB','ActualRegion', ...
    'PredictedRegion','OriginalPrediction_dB', ...
    'TwoStagePrediction_dB'}];

for k = 1:numel(requiredP)
    assert(ismember(requiredP{k},P.Properties.VariableNames), ...
        'Missing prediction column: %s',requiredP{k});
end

actualRegion = string(P.ActualRegion);
predictedRegion = string(P.PredictedRegion);

isSat = actualRegion == "Saturation";
isTriode = actualRegion == "Triode";

fprintf('\n===== TEST SET CHECK =====\n');
fprintf('Test rows: %d\n',height(P));
fprintf('Actual saturation: %d\n',sum(isSat));
fprintf('Actual triode: %d\n',sum(isTriode));
fprintf('Predicted-region accuracy: %.2f%%\n', ...
    100*mean(actualRegion == predictedRegion));

%% 2. Predict saturation test rows using the saved saturation model

assert(isfield(M,'modelSat'),'modelSat missing from saved model file');

Xtest = P{:,features};
Ytest = P.ActualGain_dB;

predSatModel = predict(M.modelSat,Xtest(isSat,:));

Ysat = Ytest(isSat);
originalSat = P.OriginalPrediction_dB(isSat);
twoStageSat = P.TwoStagePrediction_dB(isSat);

fprintf('\n===== SAME SATURATION TEST ROWS =====\n');
printMetrics('Original model',Ysat,originalSat);
printMetrics('Two-stage model',Ysat,twoStageSat);
printMetrics('Saturation-only model',Ysat,predSatModel);

%% 3. Residual audit

residual = Ysat - predSatModel;

fprintf('\n===== SATURATION MODEL RESIDUALS =====\n');
fprintf('Mean residual: %.8f dB\n',mean(residual));
fprintf('Max absolute error: %.8f dB\n',max(abs(residual)));
fprintf('90th percentile absolute error: %.8f dB\n', ...
    prctile(abs(residual),90));

ResidualTable = table(Ysat,predSatModel,residual,abs(residual), ...
    'VariableNames',{'ActualGain_dB','PredictedGain_dB', ...
    'Residual_dB','AbsoluteError_dB'});

disp(ResidualTable(1:min(15,height(ResidualTable)),:));

%% 4. Check whether identical input configurations are duplicated

Xall = D{:,features};
[~,~,groupID] = unique(Xall,'rows');
counts = accumarray(groupID,1);

fprintf('\n===== FEATURE COMBINATION CHECK =====\n');
fprintf('Full dataset rows: %d\n',height(D));
fprintf('Unique six-feature combinations: %d\n',numel(counts));
fprintf('Rows in repeated combinations: %d\n',sum(counts(groupID)>1));

% Match test rows against full dataset and verify their gain values.
[found,loc] = ismember(P(:,features),D(:,features),'rows');

fprintf('Test rows found in full dataset: %d / %d\n', ...
    sum(found),height(P));

if all(found)
    gainDifference = abs(P.ActualGain_dB - D.PeakGain_dB(loc));
    fprintf('Maximum test-label mismatch vs source dataset: %.10g dB\n', ...
        max(gainDifference));
end

%% 5. Compare prediction errors on identical saturation test rows

fig = figure('Color','w');

scatter(Ysat,originalSat,28,'filled');
hold on;
scatter(Ysat,twoStageSat,28,'filled');
scatter(Ysat,predSatModel,28,'filled');

lims = [min([Ysat;originalSat;twoStageSat;predSatModel]), ...
        max([Ysat;originalSat;twoStageSat;predSatModel])];

plot(lims,lims,'k--','LineWidth',1.5);

xlabel('Actual SPICE Peak Gain (dB)');
ylabel('Predicted Peak Gain (dB)');
title('Models on Identical Saturation Test Circuits');
legend('Original','Two-stage','Saturation-only','Ideal', ...
    'Location','best');
grid on;

%% 6. Save audit outputs

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outDir = fullfile(root,'results','Diagnostics', ...
    'RegionAware_Audit',stamp);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

writetable(ResidualTable,fullfile(outDir, ...
    'saturation_test_residuals.csv'));

saveas(fig,fullfile(outDir,'saturation_model_comparison.png'));

fprintf('\nAudit outputs saved to:\n%s\n',outDir);

%% Local helper
function printMetrics(name,actual,predicted)

    actual = actual(:);
    predicted = predicted(:);
    err = actual-predicted;

    rmse = sqrt(mean(err.^2));
    mae = mean(abs(err));

    sst = sum((actual-mean(actual)).^2);
    if sst > 0
        r2 = 1-sum(err.^2)/sst;
    else
        r2 = NaN;
    end

    fprintf('%s: RMSE %.6f dB | MAE %.6f dB | R2 %.6f\n', ...
        name,rmse,mae,r2);
end


%% ANALYZE STRUCTURE OF SATURATION-REGION GAIN
% Investigates how gain changes with CIN and operating-point variables.
% Read-only: does not modify datasets or trained models.

clear; clc; close all;

root = 'C:\Internship Project';

dataFile = fullfile(root,'results','Optimization', ...
    'Common_Source_Exhaustive','20261013_030513', ...
    'all_1215_candidate_results.csv');

assert(isfile(dataFile),'Dataset not found.');

T = readtable(dataFile);

required = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VDD_V','VGS_V','VDS_V','ID_A','PeakGain_dB'};

for k = 1:numel(required)
    assert(ismember(required{k},T.Properties.VariableNames), ...
        'Missing column: %s',required{k});
end

%% 1. Select saturation circuits using the project's Level-1 assumption

VTO = 2.0;

valid = true(height(T),1);

for k = 1:numel(required)
    valid = valid & isfinite(T.(required{k}));
end

if ismember('SimulationValid',T.Properties.VariableNames)
    valid = valid & logical(T.SimulationValid);
end

D = T(valid,:);
sat = D.VGS_V > VTO & D.VDS_V >= (D.VGS_V-VTO);
S = D(sat,:);

fprintf('\nSaturation rows: %d\n',height(S));

%% 2. Examine gain changes across CIN

% Group by all resistor and supply values, excluding CIN.
groupColumns = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V'};

[G,groupTable] = findgroups(S(:,groupColumns));

groupGainRange = splitapply( ...
    @(x) max(x)-min(x),S.PeakGain_dB,G);

groupCINCount = splitapply(@numel,S.CIN_F,G);

fprintf('\n===== WITHIN-CONFIGURATION GAIN VARIATION =====\n');
fprintf('Configurations with multiple CIN values: %d\n', ...
    sum(groupCINCount > 1));

fprintf('Median peak-to-peak gain variation: %.8f dB\n', ...
    median(groupGainRange));

fprintf('Maximum peak-to-peak gain variation: %.8f dB\n', ...
    max(groupGainRange));

fprintf('90th percentile gain variation: %.8f dB\n', ...
    prctile(groupGainRange,90));

VariationTable = groupTable;
VariationTable.GainRange_dB = groupGainRange;
VariationTable.CINCount = groupCINCount;

%% 3. Correlation with electrical features

electricalFeatures = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V','VGS_V','VDS_V','ID_A'};

X = S{:,electricalFeatures};
Y = S.PeakGain_dB;

corrValues = corr(X,Y,'Rows','complete');

CorrelationTable = table( ...
    string(electricalFeatures(:)),corrValues(:), ...
    'VariableNames',{'Feature','CorrelationWithPeakGain'});

CorrelationTable = sortrows( ...
    CorrelationTable,'CorrelationWithPeakGain','descend');

fprintf('\n===== CORRELATIONS =====\n');
disp(CorrelationTable);

%% 4. Fit an interpretable linear baseline using electrical features

% This is a diagnostic approximation, not a replacement for SPICE.
% Use a held-out random partition for a first comparison.

rng(42,'twister');

cv = cvpartition(height(S),'HoldOut',0.20);

train = training(cv);
test = test(cv);

Xlinear = S{:,{'VGS_V','VDS_V','ID_A','RD_Ohm','RS_Ohm','VDD_V'}};

% Standardize from training data only.
mu = mean(Xlinear(train,:),1);
sigma = std(Xlinear(train,:),0,1);
sigma(sigma == 0) = 1;

Xtrain = (Xlinear(train,:)-mu)./sigma;
Xtest = (Xlinear(test,:)-mu)./sigma;

linearModel = fitlm(Xtrain,S.PeakGain_dB(train));

predicted = predict(linearModel,Xtest);
actual = S.PeakGain_dB(test);

err = actual-predicted;

rmse = sqrt(mean(err.^2));
mae = mean(abs(err));

sst = sum((actual-mean(actual)).^2);
r2 = 1-sum(err.^2)/sst;

fprintf('\n===== LINEAR ELECTRICAL BASELINE =====\n');
fprintf('RMSE: %.6f dB\n',rmse);
fprintf('MAE:  %.6f dB\n',mae);
fprintf('R2:   %.6f\n',r2);

%% 5. Save diagnostics

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outDir = fullfile(root,'results','Diagnostics', ...
    'Saturation_Gain_Structure',stamp);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

writetable(VariationTable,fullfile(outDir, ...
    'gain_variation_by_configuration.csv'));

writetable(CorrelationTable,fullfile(outDir, ...
    'electrical_feature_correlations.csv'));

fig = figure('Visible','off');
histogram(groupGainRange,30);
xlabel('Peak-to-Peak Gain Variation Across CIN (dB)');
ylabel('Number of Configurations');
title('Gain Sensitivity to Input Capacitor');
grid on;

exportgraphics(fig,fullfile(outDir,'gain_variation_histogram.png'));
close(fig);

fprintf('\nDiagnostics saved to:\n%s\n',outDir);

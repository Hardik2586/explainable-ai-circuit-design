
%% Phase 4C: Diagnose large prediction errors
clear; clc; close all;

root = 'C:\Internship Project';

dataFile = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'external_model_validation', ...
    '20261020_000113', 'CS_Dataset_v2_100.mat');

predFile = fullfile(root, 'results', ...
    'Phase4_XAI_20261020_013607', ...
    'XAI_OutOfFold_Predictions.csv');

assert(isfile(dataFile), 'Dataset not found.');
assert(isfile(predFile), 'Prediction CSV not found.');

S = load(dataFile);
T = S.rows;
P = readtable(predFile);

% Match the valid-row filtering used in Phase 4.
T = T(logical(T.SimulationValid), :);

assert(height(T) == height(P), ...
    'Row alignment mismatch: stop and investigate.');

% Create diagnostic table.
R = table(T.CircuitID, P.ActualGain_dB, ...
    P.PredictedGain_dB, P.Residual_dB, ...
    P.AbsoluteError_dB, ...
    'VariableNames', {'CircuitID','ActualGain_dB', ...
    'PredictedGain_dB','Residual_dB','AbsoluteError_dB'});

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A', ...
    'Vgate_V','Vsource_V','Vdrain_V'};

for k = 1:numel(features)
    f = features{k};
    if ismember(f, T.Properties.VariableNames)
        R.(f) = T.(f);
    end
end

outDir = fullfile(root, 'results', ...
    ['Phase4C_ErrorDiagnosis_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss'))]);

mkdir(outDir);

%% A. Inspect selected circuits
ids = [29 43 35 3 13 80];
selected = ismember(R.CircuitID, ids);

SelectedCircuits = sortrows(R(selected,:), ...
    'AbsoluteError_dB', 'descend');

disp('===== SELECTED CIRCUITS =====');
disp(SelectedCircuits);

writetable(SelectedCircuits, ...
    fullfile(outDir, 'Selected_Circuits.csv'));

%% B. Compare low-gain and other circuits
lowGain = R.ActualGain_dB < -10;

fprintf('\nLow-gain circuits: %d\n', sum(lowGain));
fprintf('Other circuits: %d\n', sum(~lowGain));

Group = ["Actual gain below -10 dB"; ...
         "Actual gain at least -10 dB"];

Count = [sum(lowGain); sum(~lowGain)];

MAE = [mean(R.AbsoluteError_dB(lowGain)); ...
       mean(R.AbsoluteError_dB(~lowGain))];

RMSE = [sqrt(mean(R.Residual_dB(lowGain).^2)); ...
        sqrt(mean(R.Residual_dB(~lowGain).^2))];

GroupSummary = table(Group, Count, MAE, RMSE);
disp('===== ERROR BY TARGET GROUP =====');
disp(GroupSummary);

writetable(GroupSummary, ...
    fullfile(outDir, 'Error_By_Target_Group.csv'));

%% C. Plot error against actual gain
fig = figure('Color','w');

scatter(R.ActualGain_dB, R.AbsoluteError_dB, 45, 'filled');
xlabel('Actual Gain at 1 kHz (dB)');
ylabel('Absolute Prediction Error (dB)');
title('Prediction Error vs Actual Gain');
grid on;

exportgraphics(fig, fullfile(outDir, ...
    'Error_vs_Actual_Gain.png'), 'Resolution', 200);

%% D. Compare selected circuits' component and DC values
compareFeatures = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VGS_V','VDS_V','ID_A'};

disp('===== FEATURE COMPARISON =====');
for k = 1:numel(compareFeatures)
    f = compareFeatures{k};
    if ismember(f, SelectedCircuits.Properties.VariableNames)
        fprintf('\n%s\n', f);
        disp(SelectedCircuits(:, {'CircuitID', f, ...
            'ActualGain_dB','PredictedGain_dB'}));
    end
end

fprintf('\nResults saved to:\n%s\n', outDir);

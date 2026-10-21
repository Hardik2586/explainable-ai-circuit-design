clear; clc; close all;
rng(42, 'twister');

projectRoot = 'C:\Internship Project';

xaiDir = fullfile(projectRoot, ...
    'results', 'Phase4_XAI_20261020_013607');

dataFile = fullfile(projectRoot, 'data', 'universal', ...
    'Common_Source', 'external_model_validation', ...
    '20261020_000113', 'CS_Dataset_v2_100.mat');

predictionFile = fullfile(xaiDir, ...
    'XAI_OutOfFold_Predictions.csv');

assert(isfile(predictionFile), ...
    'Prediction CSV not found: %s', predictionFile);
assert(isfile(dataFile), ...
    'Dataset MAT file not found: %s', dataFile);

outDir = fullfile(projectRoot, 'results', ...
    ['Phase4B_Explanations_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss'))]);

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 1. Load saved predictions and dataset
P = readtable(predictionFile);
S = load(dataFile);

assert(all(ismember( ...
    {'ActualGain_dB','PredictedGain_dB', ...
     'Residual_dB','AbsoluteError_dB'}, ...
     P.Properties.VariableNames)), ...
     'Unexpected prediction CSV columns.');

assert(isfield(S, 'rows'), ...
    'The MAT file does not contain the expected rows table.');

T = S.rows;

assert(height(P) == height(T), ...
    ['Prediction and dataset row counts differ. ' ...
     'Do not join rows by position without checking alignment.']);

% The Phase 4 script filters valid rows before prediction.
% Reproduce that filtering and verify alignment.
valid = logical(T.SimulationValid);
Tvalid = T(valid,:);

assert(height(Tvalid) == height(P), ...
    ['The valid-row count differs from the prediction count. ' ...
     'Check the Phase 4 filtering and row order before proceeding.']);

%% 2. Build a combined circuit-level table
% These predictions are out-of-fold predictions.
% Their row order must match the Phase 4 input order.

if ismember('CircuitID', Tvalid.Properties.VariableNames)
    CircuitID = Tvalid.CircuitID;
else
    CircuitID = (1:height(P))';
end

R = table( ...
    CircuitID, ...
    P.ActualGain_dB, ...
    P.PredictedGain_dB, ...
    P.Residual_dB, ...
    P.AbsoluteError_dB, ...
    'VariableNames', { ...
    'CircuitID','ActualGain_dB','PredictedGain_dB', ...
    'Residual_dB','AbsoluteError_dB'});

% Add features for circuit-level interpretation.
featureNames = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A'};

for k = 1:numel(featureNames)
    name = featureNames{k};
    assert(ismember(name, Tvalid.Properties.VariableNames), ...
        'Missing expected feature: %s', name);
    R.(name) = Tvalid.(name);
end

writetable(R, fullfile(outDir, ...
    'Phase4B_Circuit_Level_Results.csv'));

%% 3. Best and worst predictions
RBest = sortrows(R, 'AbsoluteError_dB', 'ascend');
RWorst = sortrows(R, 'AbsoluteError_dB', 'descend');

nShow = min(10, height(R));

Best10 = RBest(1:nShow,:);
Worst10 = RWorst(1:nShow,:);

writetable(Best10, fullfile(outDir, ...
    'Phase4B_Best10_Predictions.csv'));

writetable(Worst10, fullfile(outDir, ...
    'Phase4B_Worst10_Predictions.csv'));

fprintf('\n===== BEST 10 PREDICTIONS =====\n');
disp(Best10(:, {'CircuitID','ActualGain_dB', ...
    'PredictedGain_dB','AbsoluteError_dB'}));

fprintf('\n===== WORST 10 PREDICTIONS =====\n');
disp(Worst10(:, {'CircuitID','ActualGain_dB', ...
    'PredictedGain_dB','AbsoluteError_dB'}));

%% 4. Actual versus predicted gain
fig = figure('Color','w');

scatter(R.ActualGain_dB, R.PredictedGain_dB, ...
    48, 'filled');
hold on;

lo = min([R.ActualGain_dB; R.PredictedGain_dB]);
hi = max([R.ActualGain_dB; R.PredictedGain_dB]);

plot([lo hi], [lo hi], 'k--', 'LineWidth', 1.5);

xlabel('Actual Gain (dB)');
ylabel('Out-of-Fold Predicted Gain (dB)');
title('Phase 4B: Actual vs Predicted Gain');
grid on;
axis tight;

exportgraphics(fig, fullfile(outDir, ...
    'Phase4B_Actual_vs_Predicted.png'), 'Resolution', 200);

%% 5. Residual analysis
fig = figure('Color','w');

scatter(R.PredictedGain_dB, R.Residual_dB, ...
    48, 'filled');
hold on;
yline(0, 'k--', 'LineWidth', 1.5);

xlabel('Predicted Gain (dB)');
ylabel('Residual (Actual - Predicted) (dB)');
title('Phase 4B: Residual Analysis');
grid on;

exportgraphics(fig, fullfile(outDir, ...
    'Phase4B_Residual_Analysis.png'), 'Resolution', 200);

%% 6. Error distribution
fig = figure('Color','w');

histogram(R.Residual_dB, 15);
xlabel('Residual (dB)');
ylabel('Number of Circuits');
title('Phase 4B: Out-of-Fold Residual Distribution');
grid on;

exportgraphics(fig, fullfile(outDir, ...
    'Phase4B_Residual_Distribution.png'), 'Resolution', 200);

%% 7. Feature versus gain plots
% These are observational plots, not causal explanations.
% Each plot shows the dataset relationship, not a controlled sweep.

for k = 1:numel(featureNames)
    name = featureNames{k};

    x = R.(name);
    y = R.ActualGain_dB;

    fig = figure('Color','w');
    scatter(x, y, 42, 'filled');

    xlabel(strrep(name, '_', '\_'));
    ylabel('Actual Gain at 1 kHz (dB)');
    title(['Feature vs Gain: ', name]);
    grid on;

    exportgraphics(fig, fullfile(outDir, ...
        ['Phase4B_FeatureEffect_', name, '.png']), ...
        'Resolution', 200);

    close(fig);
end

%% 8. Investigate the worst-predicted circuit
worst = RWorst(1,:);

fprintf('\n===== WORST-PREDICTED CIRCUIT =====\n');
disp(worst);

featureValues = zeros(numel(featureNames), 1);

for k = 1:numel(featureNames)
    featureValues(k) = worst.(featureNames{k});
end

fig = figure('Color','w');

bar(featureValues);
xticks(1:numel(featureNames));
xticklabels(featureNames);
xtickangle(35);
ylabel('Raw Feature Value');
title(sprintf('Worst Circuit %g: Input Features', ...
    worst.CircuitID));
grid on;

exportgraphics(fig, fullfile(outDir, ...
    'Phase4B_WorstCircuit_RawFeatures.png'), ...
    'Resolution', 200);

%% 9. Summary metrics
actual = R.ActualGain_dB;
predicted = R.PredictedGain_dB;
residual = R.Residual_dB;

MAE = mean(abs(residual), 'omitnan');
RMSE = sqrt(mean(residual.^2, 'omitnan'));

SSE = sum(residual.^2, 'omitnan');
SST = sum((actual - mean(actual,'omitnan')).^2, 'omitnan');
R2 = 1 - SSE / SST;

Summary = table(height(R), MAE, RMSE, R2, ...
    worst.CircuitID, worst.ActualGain_dB, ...
    worst.PredictedGain_dB, worst.AbsoluteError_dB, ...
    'VariableNames', {'NumCircuits','MAE_dB','RMSE_dB', ...
    'R2','WorstCircuitID','WorstActualGain_dB', ...
    'WorstPredictedGain_dB','WorstAbsoluteError_dB'});

writetable(Summary, fullfile(outDir, ...
    'Phase4B_Summary.csv'));

fprintf('\n===== PHASE 4B SUMMARY =====\n');
disp(Summary);

fprintf('\nResults saved to:\n%s\n', outDir);

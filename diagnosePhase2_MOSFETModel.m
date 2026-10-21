
clear; clc; close all;

projectRoot = 'C:\Internship Project';
inputFile = fullfile(projectRoot, 'results', 'Phase2_MOSFET', ...
    'Phase2_TestPredictions.csv');

outputDir = fullfile(projectRoot, 'results', ...
    'Phase2_MOSFET_Diagnostics');

if ~isfile(inputFile)
    error('Prediction file not found: %s', inputFile);
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

T = readtable(inputFile);

requiredColumns = {'ActualGain_dB', 'BaggedTrees_dB', ...
    'BoostedTrees_dB', 'RidgeRegression_dB'};

for k = 1:numel(requiredColumns)
    if ~ismember(requiredColumns{k}, T.Properties.VariableNames)
        error('Missing required column: %s', requiredColumns{k});
    end
end

% Remove rows with non-finite values in any required prediction.
A = T{:, 'ActualGain_dB'};
P = [T.BaggedTrees_dB, T.BoostedTrees_dB, ...
     T.RidgeRegression_dB];

valid = isfinite(A) & all(isfinite(P), 2);
T = T(valid, :);

A = T.ActualGain_dB;
P = [T.BaggedTrees_dB, T.BoostedTrees_dB, ...
     T.RidgeRegression_dB];

modelNames = ["BaggedTrees"; "BoostedTrees"; "RidgeRegression"];
n = numel(A);

if n < 2
    error('At least two valid test predictions are required.');
end

%% 1. Overall metrics
RMSE = zeros(3,1);
MAE = zeros(3,1);
R2 = zeros(3,1);
Bias = zeros(3,1);
MaxAbsError = zeros(3,1);

sst = sum((A - mean(A)).^2);

for m = 1:3
    residual = A - P(:,m);

    RMSE(m) = sqrt(mean(residual.^2));
    MAE(m) = mean(abs(residual));
    Bias(m) = mean(P(:,m) - A);
    MaxAbsError(m) = max(abs(residual));

    if sst > 0
        R2(m) = 1 - sum(residual.^2)/sst;
    else
        R2(m) = NaN;
    end
end

Overall = table(modelNames, RMSE, MAE, R2, Bias, MaxAbsError, ...
    'VariableNames', {'Model','RMSE_dB','MAE_dB','R2', ...
    'PredictionBias_dB','MaxAbsError_dB'});

Overall = sortrows(Overall, 'RMSE_dB', 'ascend');

writetable(Overall, fullfile(outputDir, 'Diagnostic_OverallMetrics.csv'));

fprintf('\n===== PHASE 2 DIAGNOSTIC =====\n');
fprintf('Valid held-out predictions: %d\n', n);
disp(Overall);

%% 2. Per-circuit errors
Errors = table;
Errors.ActualGain_dB = A;
Errors.BaggedTrees_dB = P(:,1);
Errors.BoostedTrees_dB = P(:,2);
Errors.RidgeRegression_dB = P(:,3);

for m = 1:3
    prefix = char(modelNames(m));
    Errors.([prefix '_Residual_dB']) = P(:,m) - A;
    Errors.([prefix '_AbsError_dB']) = abs(P(:,m) - A);
end

Errors = sortrows(Errors, 'BaggedTrees_AbsError_dB', 'descend');
writetable(Errors, fullfile(outputDir, 'Diagnostic_PerCircuitErrors.csv'));

%% 3. Performance by actual-gain range
% These are descriptive groups, not validated engineering thresholds.
edges = [-Inf, 0, 5, 10, Inf];
binLabels = ["Below 0 dB"; "0 to below 5 dB"; ...
             "5 to below 10 dB"; "10 dB and above"];

GainRange = strings(0,1);
Model = strings(0,1);
Count = zeros(0,1);
RMSE_dB = zeros(0,1);
MAE_dB = zeros(0,1);
MeanActual_dB = zeros(0,1);

for b = 1:numel(binLabels)
    idx = A >= edges(b) & A < edges(b+1);

    for m = 1:3
        if any(idx)
            r = A(idx) - P(idx,m);

            GainRange(end+1,1) = binLabels(b);
            Model(end+1,1) = modelNames(m);
            Count(end+1,1) = sum(idx);
            RMSE_dB(end+1,1) = sqrt(mean(r.^2));
            MAE_dB(end+1,1) = mean(abs(r));
            MeanActual_dB(end+1,1) = mean(A(idx));
        end
    end
end

ByRange = table(GainRange, Model, Count, RMSE_dB, ...
    MAE_dB, MeanActual_dB);

writetable(ByRange, fullfile(outputDir, 'Diagnostic_ByGainRange.csv'));

fprintf('\n===== ERROR BY ACTUAL-GAIN RANGE =====\n');
disp(ByRange);

%% 4. Compare against test-mean reference
% This is descriptive only: it uses the test labels and is NOT a
% deployable baseline. A proper baseline must use the training-set mean.

testMean = mean(A);
testMeanRMSE = sqrt(mean((A - testMean).^2));
testMeanMAE = mean(abs(A - testMean));

fprintf('\nTest-set mean-reference RMSE: %.4f dB\n', testMeanRMSE);
fprintf('Test-set mean-reference MAE : %.4f dB\n', testMeanMAE);
fprintf(['Note: this reference uses test labels and must not be ' ...
    'treated as a valid deployment baseline.\n']);

%% 5. Actual vs predicted plot
figure('Name', 'Actual vs Predicted Gain', 'Color', 'w');
tiledlayout(1,3, 'TileSpacing','compact');

for m = 1:3
    nexttile;
    scatter(A, P(:,m), 45, 'filled');
    hold on;

    low = min([A; P(:,m)]);
    high = max([A; P(:,m)]);
    plot([low high], [low high], 'k--', 'LineWidth', 1.2);

    xlabel('Actual gain (dB)');
    ylabel('Predicted gain (dB)');
    title(char(modelNames(m)));
    grid on;
end

saveas(gcf, fullfile(outputDir, 'Diagnostic_ActualVsPredicted.png'));

%% 6. Absolute error vs actual gain
figure('Name', 'Absolute Prediction Error', 'Color', 'w');
hold on;

for m = 1:3
    scatter(A, abs(A - P(:,m)), 42, 'filled', ...
        'DisplayName', char(modelNames(m)));
end

xlabel('Actual gain (dB)');
ylabel('Absolute error (dB)');
title('Prediction error across held-out gain range');
legend('Location','best');
grid on;

saveas(gcf, fullfile(outputDir, 'Diagnostic_AbsoluteError.png'));

%% 7. Summary
fprintf('\nDiagnostic outputs saved to:\n%s\n', outputDir);
fprintf('1. Diagnostic_OverallMetrics.csv\n');
fprintf('2. Diagnostic_PerCircuitErrors.csv\n');
fprintf('3. Diagnostic_ByGainRange.csv\n');
fprintf('4. Diagnostic_ActualVsPredicted.png\n');
fprintf('5. Diagnostic_AbsoluteError.png\n');
fprintf('\nDiagnostic complete. Original data was not modified.\n');

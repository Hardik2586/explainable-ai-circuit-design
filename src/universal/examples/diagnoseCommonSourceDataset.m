clear; clc; close all;

projectRoot = 'C:\Internship Project';

dataFile = fullfile(projectRoot, 'results', ...
    'Optimization', 'Common_Source_Exhaustive', ...
    '20261013_030513', 'all_1215_candidate_results.csv');

predictionFile = fullfile(projectRoot, 'results', ...
    'Model_Evaluation', 'Common_Source', ...
    '20261013_101458', 'test_predictions.csv');

assert(isfile(dataFile), 'Dataset not found: %s', dataFile);

T = readtable(dataFile);

timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(projectRoot, 'results', ...
    'Diagnostics', 'Common_Source', timestamp);

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fprintf('\n========================================\n');
fprintf('COMMON-SOURCE DATASET DIAGNOSTICS\n');
fprintf('========================================\n');

fprintf('Dataset rows: %d\n', height(T));
fprintf('Dataset columns: %d\n\n', width(T));

disp('Available dataset columns:');
disp(T.Properties.VariableNames');

%% 1. Required fields and valid rows

required = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V','PeakGain_dB'};

for k = 1:numel(required)
    assert(ismember(required{k}, T.Properties.VariableNames), ...
        'Required column missing: %s', required{k});
end

numericColumns = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V','PeakGain_dB'};

valid = true(height(T),1);

for k = 1:numel(numericColumns)
    x = T.(numericColumns{k});
    valid = valid & isfinite(double(x));
end

if ismember('SimulationValid', T.Properties.VariableNames)
    valid = valid & logical(T.SimulationValid);
end

D = T(valid,:);

fprintf('\nRows retained for numerical analysis: %d / %d\n', ...
    height(D), height(T));

if height(D) == 0
    error('No valid rows remain after filtering.');
end

%% 2. Gain distribution and outliers

gain = D.PeakGain_dB;

fprintf('\n--- Peak Gain Distribution ---\n');
fprintf('Minimum: %.4f dB\n', min(gain));
fprintf('Maximum: %.4f dB\n', max(gain));
fprintf('Mean: %.4f dB\n', mean(gain));
fprintf('Median: %.4f dB\n', median(gain));
fprintf('Standard deviation: %.4f dB\n', std(gain));
fprintf('25th percentile: %.4f dB\n', prctile(gain,25));
fprintf('75th percentile: %.4f dB\n', prctile(gain,75));

outlierMask = isoutlier(gain, 'quartiles');

fprintf('IQR-rule outliers: %d / %d\n', ...
    sum(outlierMask), numel(gain));

GainSummary = table( ...
    min(gain), max(gain), mean(gain), median(gain), ...
    std(gain), prctile(gain,25), prctile(gain,75), ...
    sum(outlierMask), ...
    'VariableNames', {'Minimum_dB','Maximum_dB','Mean_dB', ...
    'Median_dB','Std_dB','P25_dB','P75_dB','IQR_OutlierCount'});

writetable(GainSummary, fullfile(outDir, 'gain_summary.csv'));

Outliers = D(outlierMask,:);
writetable(Outliers, fullfile(outDir, 'gain_outlier_rows.csv'));

fig = figure('Visible','off');
histogram(gain, 30);
xlabel('Peak Gain (dB)');
ylabel('Number of Circuits');
title('Exhaustive Dataset: Peak Gain Distribution');
grid on;
saveas(fig, fullfile(outDir, 'gain_distribution.png'));
close(fig);

%% 3. Gain distribution at each supply voltage

fprintf('\n--- Gain by Supply Voltage ---\n');

VoltageSummary = groupsummary( ...
    D, 'VDD_V', {'mean','median','std','min','max'}, 'PeakGain_dB');

disp(VoltageSummary);

writetable(VoltageSummary, ...
    fullfile(outDir, 'gain_by_supply_voltage.csv'));

fig = figure('Visible','off');
boxchart(categorical(D.VDD_V), D.PeakGain_dB);
xlabel('Supply Voltage (V)');
ylabel('Peak Gain (dB)');
title('Peak Gain by Supply Voltage');
grid on;
saveas(fig, fullfile(outDir, 'gain_by_supply_voltage.png'));
close(fig);

%% 4. Inspect operating-region labels, if present

if ismember('BiasRegion', D.Properties.VariableNames)

    fprintf('\n--- Bias Region Counts ---\n');

    region = string(D.BiasRegion);
    [regionNames,~,regionID] = unique(region);
    regionCounts = accumarray(regionID,1);

    RegionSummary = table(regionNames, regionCounts, ...
        'VariableNames', {'BiasRegion','Count'});

    disp(RegionSummary);

    writetable(RegionSummary, ...
        fullfile(outDir, 'bias_region_counts.csv'));

    fprintf('\n--- Gain by Bias Region ---\n');

    RegionGainSummary = groupsummary( ...
        D, 'BiasRegion', {'mean','median','std','min','max'}, ...
        'PeakGain_dB');

    disp(RegionGainSummary);

    writetable(RegionGainSummary, ...
        fullfile(outDir, 'gain_by_bias_region.csv'));

else
    fprintf('\nBiasRegion column not found in this dataset.\n');
end

%% 5. Inspect simulated operating-point fields

operatingPointColumns = {'Vgate_V','Vsource_V','Vdrain_V', ...
    'VGS_V','VDS_V','ID_A'};

availableOP = operatingPointColumns( ...
    ismember(operatingPointColumns, D.Properties.VariableNames));

fprintf('\n--- Available Operating-Point Fields ---\n');
disp(availableOP');

if ismember('VGS_V', D.Properties.VariableNames) && ...
        ismember('VDS_V', D.Properties.VariableNames)

    fig = figure('Visible','off');

    scatter(D.VGS_V, D.VDS_V, 30, D.PeakGain_dB, 'filled');
    xlabel('VGS (V)');
    ylabel('VDS (V)');
    title('Operating Point vs Peak Gain');
    cb = colorbar;
    cb.Label.String = 'Peak Gain (dB)';
    grid on;

    saveas(fig, fullfile(outDir, 'operating_point_gain.png'));
    close(fig);
end

%% 6. Component-value correlations with gain

featureColumns = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

X = D{:, featureColumns};
Y = D.PeakGain_dB;

correlations = corr(X, Y, 'Rows','complete');

CorrelationSummary = table( ...
    string(featureColumns(:)), correlations(:), ...
    'VariableNames', {'Feature','PearsonCorrelationWithGain'});

CorrelationSummary = sortrows( ...
    CorrelationSummary, 'PearsonCorrelationWithGain', 'descend');

fprintf('\n--- Feature Correlations ---\n');
disp(CorrelationSummary);

writetable(CorrelationSummary, ...
    fullfile(outDir, 'feature_gain_correlations.csv'));

%% 7. Inspect prior held-out prediction errors

if isfile(predictionFile)

    P = readtable(predictionFile);

    expectedPredictionColumns = { ...
        'ActualGain_dB', ...
        'OriginalPredictedGain_dB', ...
        'NewPredictedGain_dB'};

    hasPredictionColumns = all(ismember( ...
        expectedPredictionColumns, P.Properties.VariableNames));

    if hasPredictionColumns

        actual = P.ActualGain_dB;
        originalPred = P.OriginalPredictedGain_dB;
        newPred = P.NewPredictedGain_dB;

        originalError = actual - originalPred;
        newError = actual - newPred;

        fprintf('\n--- Held-Out Prediction Error ---\n');

        fprintf('Original bias (mean actual - predicted): %.4f dB\n', ...
            mean(originalError, 'omitnan'));

        fprintf('New model bias (mean actual - predicted): %.4f dB\n', ...
            mean(newError, 'omitnan'));

        fprintf('Original 90th percentile absolute error: %.4f dB\n', ...
            prctile(abs(originalError),90));

        fprintf('New model 90th percentile absolute error: %.4f dB\n', ...
            prctile(abs(newError),90));

        if ismember('VDD_V', P.Properties.VariableNames)

            ErrorByVoltage = table();

            voltages = unique(P.VDD_V);

            for k = 1:numel(voltages)

                idx = P.VDD_V == voltages(k);

                originalRMSE = sqrt(mean( ...
                    originalError(idx).^2, 'omitnan'));

                newRMSE = sqrt(mean( ...
                    newError(idx).^2, 'omitnan'));

                row = table(voltages(k), sum(idx), ...
                    originalRMSE, newRMSE, ...
                    'VariableNames', {'VDD_V','TestRows', ...
                    'OriginalRMSE_dB','NewRMSE_dB'});

                ErrorByVoltage = [ErrorByVoltage; row]; %#ok<AGROW>
            end

            fprintf('\n--- Prediction RMSE by Supply Voltage ---\n');
            disp(ErrorByVoltage);

            writetable(ErrorByVoltage, ...
                fullfile(outDir, 'test_error_by_voltage.csv'));
        end

        ErrorComparison = table( ...
            actual, originalPred, newPred, ...
            abs(originalError), abs(newError), ...
            'VariableNames', {'ActualGain_dB', ...
            'OriginalPrediction_dB','NewPrediction_dB', ...
            'OriginalAbsoluteError_dB','NewAbsoluteError_dB'});

        writetable(ErrorComparison, ...
            fullfile(outDir, 'test_error_details.csv'));

    else
        fprintf('\nPrediction file exists but expected columns are missing.\n');
        disp(P.Properties.VariableNames');
    end

else
    fprintf('\nPrevious test-prediction file not found; skipping error analysis.\n');
end

%% 8. Component-versus-gain plots

plotFeatures = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

for k = 1:numel(plotFeatures)

    featureName = plotFeatures{k};

    fig = figure('Visible','off');

    scatter(D.(featureName), D.PeakGain_dB, 24, 'filled');

    xlabel(strrep(featureName,'_',' '));
    ylabel('Peak Gain (dB)');
    title(['Peak Gain vs ', strrep(featureName,'_',' ')]);
    grid on;

    saveas(fig, fullfile(outDir, ...
        ['gain_vs_', featureName, '.png']));

    close(fig);
end

%% 9. Save audit summary

fid = fopen(fullfile(outDir, 'diagnostic_summary.txt'), 'w');

if fid ~= -1

    fprintf(fid, 'COMMON-SOURCE DIAGNOSTIC SUMMARY\n');
    fprintf(fid, 'Dataset: %s\n', dataFile);
    fprintf(fid, 'Rows in original table: %d\n', height(T));
    fprintf(fid, 'Rows analyzed: %d\n', height(D));
    fprintf(fid, 'Gain minimum: %.6f dB\n', min(gain));
    fprintf(fid, 'Gain maximum: %.6f dB\n', max(gain));
    fprintf(fid, 'Gain mean: %.6f dB\n', mean(gain));
    fprintf(fid, 'Gain median: %.6f dB\n', median(gain));
    fprintf(fid, 'Gain standard deviation: %.6f dB\n', std(gain));
    fprintf(fid, 'IQR outliers: %d\n', sum(outlierMask));

    fclose(fid);
end

fprintf('\n========================================\n');
fprintf('DIAGNOSTICS COMPLETE\n');
fprintf('========================================\n');
fprintf('Results saved to:\n%s\n', outDir);

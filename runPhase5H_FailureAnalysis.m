clear; clc; close all;

%% 1. CONFIGURATION
projectRoot = 'C:\Internship Project';
resultsRoot = fullfile(projectRoot, 'results');

gainThreshold_dB = 3;
timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

outputFolder = fullfile(resultsRoot, ...
    ['Phase5H_FailureAnalysis_' timestamp]);

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

fprintf('\n===== PHASE 5H: FAILURE ANALYSIS =====\n');

%% 2. FIND THE LATEST PHASE 5G FOLDER
phaseFolders = dir(fullfile(resultsRoot, ...
    'Phase5G_IndependentValidation_*'));

phaseFolders = phaseFolders([phaseFolders.isdir]);

if isempty(phaseFolders)
    error(['No Phase5G_IndependentValidation_* folder found in: ' ...
        resultsRoot]);
end

[~, order] = sort({phaseFolders.name});
phaseFolders = phaseFolders(order);

% Search newest to oldest, looking for a CSV with trial data.
csvPath = '';
sourceFolder = '';

for k = numel(phaseFolders):-1:1
    candidateFolder = fullfile(resultsRoot, ...
        phaseFolders(k).name);

    csvFiles = dir(fullfile(candidateFolder, '*.csv'));

    for j = 1:numel(csvFiles)
        candidatePath = fullfile(candidateFolder, ...
            csvFiles(j).name);

        try
            opts = detectImportOptions(candidatePath);
            opts.VariableNamingRule = 'preserve';
            candidateTable = readtable(candidatePath, opts);

            names = candidateTable.Properties.VariableNames;

            hasTrial = any(strcmp(names, 'Trial'));
            hasDC = any(strcmp(names, 'DCFeasible'));
            hasGain = any(strcmp(names, 'GainAt1kHz_dB'));

            if hasTrial && hasDC && hasGain
                csvPath = candidatePath;
                sourceFolder = candidateFolder;
                T = candidateTable;
                break;
            end
        catch
            % Ignore CSVs that cannot be read; inspect others.
        end
    end

    if ~isempty(csvPath)
        break;
    end
end

if isempty(csvPath)
    fprintf('\nCould not find a CSV with all expected trial columns.\n');
    fprintf('Recent Phase 5G folder contents:\n');

    for k = 1:numel(phaseFolders)
        p = fullfile(resultsRoot, phaseFolders(k).name);
        fprintf('\n%s\n', p);
        disp(dir(p));
    end

    error(['No suitable Phase 5G trial CSV found. ' ...
        'Check the printed filenames and column names.']);
end

fprintf('Source folder: %s\n', sourceFolder);
fprintf('Source CSV:    %s\n', csvPath);
fprintf('Output folder: %s\n', outputFolder);

%% 3. VALIDATE REQUIRED COLUMNS
names = T.Properties.VariableNames;

required = {'Trial','DCFeasible','GainAt1kHz_dB'};

for k = 1:numel(required)
    if ~any(strcmp(names, required{k}))
        error('Missing required column: %s', required{k});
    end
end

% Convert logical/numeric columns safely.
T.DCFeasible = logical(T.DCFeasible);

if any(strcmp(names, 'ACSuccess'))
    T.ACSuccess = logical(T.ACSuccess);
else
    warning('ACSuccess column missing; AC success counts unavailable.');
end

if any(strcmp(names, 'MeetsAllConstraints'))
    T.MeetsAllConstraints = logical(T.MeetsAllConstraints);
else
    warning(['MeetsAllConstraints column missing; ' ...
        'the script will calculate a reconstructed result.']);
end

gain = T.GainAt1kHz_dB;
finiteGain = isfinite(gain);

% Status may contain strings, categorical values, or cell text.
if any(strcmp(names, 'Status'))
    status = string(T.Status);
else
    status = repmat("UNKNOWN", height(T), 1);
end

if any(strcmp(names, 'ErrorMessage'))
    errorMessage = string(T.ErrorMessage);
else
    errorMessage = repmat("", height(T), 1);
end

simulationError = ...
    contains(lower(status), 'error') | ...
    contains(lower(status), 'fail');

% Empty or nonfinite gains are not valid gain measurements.
missingGain = ~finiteGain;

gainPass = finiteGain & gain >= gainThreshold_dB;

% Reconstructed robust result. AC success is required if available.
if any(strcmp(names, 'ACSuccess'))
    reconstructedRobust = T.DCFeasible & ...
        T.ACSuccess & gainPass;
else
    reconstructedRobust = T.DCFeasible & gainPass;
end

if any(strcmp(names, 'MeetsAllConstraints'))
    recordedRobust = T.MeetsAllConstraints;
else
    recordedRobust = reconstructedRobust;
end

%% 4. CORE COUNTS AND CONSISTENCY CHECKS
N = height(T);

dcCount = sum(T.DCFeasible);
gainFailCount = sum(finiteGain & gain < gainThreshold_dB);
dcGainFail = T.DCFeasible & finiteGain & ...
    gain < gainThreshold_dB;

robustGainFail = recordedRobust & ...
    finiteGain & gain < gainThreshold_dB;

missingGainCount = sum(missingGain);
errorCount = sum(simulationError);
recordedRobustCount = sum(recordedRobust);
reconstructedRobustCount = sum(reconstructedRobust);

fprintf('\n--- Core results ---\n');
fprintf('Total trials:                         %d\n', N);
fprintf('DC-feasible trials:                   %d (%.2f%%)\n', ...
    dcCount, 100*dcCount/N);
fprintf('Trials with finite gain:              %d\n', ...
    sum(finiteGain));
fprintf('Trials with gain >= %.2f dB:          %d\n', ...
    gainThreshold_dB, sum(gainPass));
fprintf('Trials with finite gain below limit:  %d\n', ...
    gainFailCount);
fprintf('DC-feasible trials with gain below:   %d\n', ...
    sum(dcGainFail));
fprintf('Recorded robust-feasible trials:      %d\n', ...
    recordedRobustCount);
fprintf('Reconstructed robust-feasible trials: %d\n', ...
    reconstructedRobustCount);
fprintf('Missing/nonfinite gain trials:        %d\n', ...
    missingGainCount);
fprintf('Potential simulation error trials:    %d\n', ...
    errorCount);

fprintf('Recorded robust trials below gain threshold: %d\n', ...
    sum(robustGainFail));

mismatch = recordedRobust ~= reconstructedRobust;

fprintf('Recorded/reconstructed robust mismatch: %d\n', ...
    sum(mismatch));

if sum(dcGainFail) > 0
    warning(['Some DC-feasible trials have gain below the limit. ' ...
        'Check whether they were incorrectly marked robust-feasible.']);
end

if sum(mismatch) > 0
    warning(['Recorded and reconstructed robust classifications differ. ' ...
        'Inspect the rows in the exported diagnostic table.']);
end

%% 5. BUILD A DIAGNOSTIC TABLE
D = table;
D.Trial = T.Trial;
D.DCFeasible = T.DCFeasible;
D.GainAt1kHz_dB = gain;
D.GainFinite = finiteGain;
D.GainPass = gainPass;
D.RecordedRobust = recordedRobust;
D.ReconstructedRobust = reconstructedRobust;
D.ClassificationMismatch = mismatch;
D.PotentialSimulationError = simulationError;
D.Status = status;
D.ErrorMessage = errorMessage;

% Copy useful columns if present.
optionalColumns = { ...
    'CandidateID','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VDD_V','Vsource_V','Vdrain_V', ...
    'VGS_V','VDS_V','ID_A','SupplyPower_mW', ...
    'DCSuccess','ACSuccess'};

for k = 1:numel(optionalColumns)
    nm = optionalColumns{k};
    if any(strcmp(T.Properties.VariableNames, nm))
        D.(nm) = T.(nm);
    end
end

writetable(D, fullfile(outputFolder, ...
    'Phase5H_FailureAnalysis.csv'));

%% 6. SUMMARIZE BY STATUS
statusCategories = unique(status);
StatusSummary = table;

StatusSummary.Status = statusCategories;
StatusSummary.Trials = zeros(numel(statusCategories),1);
StatusSummary.DCFeasible = zeros(numel(statusCategories),1);
StatusSummary.RobustFeasible = zeros(numel(statusCategories),1);
StatusSummary.MissingGain = zeros(numel(statusCategories),1);

for k = 1:numel(statusCategories)
    idx = status == statusCategories(k);

    StatusSummary.Trials(k) = sum(idx);
    StatusSummary.DCFeasible(k) = sum(T.DCFeasible(idx));
    StatusSummary.RobustFeasible(k) = sum(recordedRobust(idx));
    StatusSummary.MissingGain(k) = sum(missingGain(idx));
end

writetable(StatusSummary, fullfile(outputFolder, ...
    'Phase5H_FailureByStatus.csv'));

disp(' ');
disp('--- Results by status ---');
disp(StatusSummary);

%% 7. FAILED VS PASSED PARAMETER DISTRIBUTIONS
parameterNames = { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V'};

% Define pass/fail using reconstructed overall constraints.
passed = reconstructedRobust;
failed = ~reconstructedRobust;

ParameterSummary = table;
ParameterSummary.Parameter = string(parameterNames(:));
ParameterSummary.PassCount = zeros(numel(parameterNames),1);
ParameterSummary.FailCount = zeros(numel(parameterNames),1);
ParameterSummary.PassMedian = nan(numel(parameterNames),1);
ParameterSummary.FailMedian = nan(numel(parameterNames),1);
ParameterSummary.PassMean = nan(numel(parameterNames),1);
ParameterSummary.FailMean = nan(numel(parameterNames),1);

for k = 1:numel(parameterNames)
    nm = parameterNames{k};

    if ~any(strcmp(T.Properties.VariableNames, nm))
        warning('Parameter column missing: %s', nm);
        continue;
    end

    x = T.(nm);
    x = double(x);

    xp = x(passed & isfinite(x));
    xf = x(failed & isfinite(x));

    ParameterSummary.PassCount(k) = numel(xp);
    ParameterSummary.FailCount(k) = numel(xf);

    if ~isempty(xp)
        ParameterSummary.PassMedian(k) = median(xp);
        ParameterSummary.PassMean(k) = mean(xp);
    end

    if ~isempty(xf)
        ParameterSummary.FailMedian(k) = median(xf);
        ParameterSummary.FailMean(k) = mean(xf);
    end
end

writetable(ParameterSummary, fullfile(outputFolder, ...
    'Phase5H_ParameterComparison.csv'));

disp(' ');
disp('--- Passed vs failed parameter comparison ---');
disp(ParameterSummary);

%% 8. EXPORT WORST-GAIN AND DC-INFEASIBLE ROWS
finiteRows = find(finiteGain);
[~, sortIdx] = sort(gain(finiteRows), 'ascend');
worstRows = finiteRows(sortIdx(1:min(10,numel(sortIdx))));

writetable(D(worstRows,:), fullfile(outputFolder, ...
    'Phase5H_WorstGainTrials.csv'));

dcFailRows = find(~T.DCFeasible);
writetable(D(dcFailRows,:), fullfile(outputFolder, ...
    'Phase5H_DCInfeasibleTrials.csv'));

%% 9. PLOT GAIN DISTRIBUTION
fig = figure('Visible','off');
histogram(gain(finiteGain), 30);
hold on;
xline(gainThreshold_dB, '--r', '3 dB threshold');
xlabel('Gain at 1 kHz (dB)');
ylabel('Trial count');
title('Phase 5G Independent Validation: Gain Distribution');
grid on;

saveas(fig, fullfile(outputFolder, ...
    'Phase5H_GainDistribution.png'));
close(fig);

%% 10. PLOT ROBUST FEASIBILITY
fig = figure('Visible','off');
bar([dcCount, recordedRobustCount, ...
    sum(reconstructedRobust), sum(simulationError)]);
set(gca, 'XTickLabel', ...
    {'DC feasible','Recorded robust','Reconstructed robust','Errors'});
ylabel('Trial count');
title('Phase 5H: Feasibility Consistency Check');
grid on;

saveas(fig, fullfile(outputFolder, ...
    'Phase5H_FeasibilityCheck.png'));
close(fig);

%% 11. SAVE SUMMARY TEXT
summaryFile = fullfile(outputFolder, ...
    'Phase5H_Summary.txt');

fid = fopen(summaryFile, 'w');

if fid == -1
    warning('Could not create summary text file.');
else
    fprintf(fid, 'PHASE 5H FAILURE ANALYSIS\n\n');
    fprintf(fid, 'Input CSV: %s\n', csvPath);
    fprintf(fid, 'Total trials: %d\n', N);
    fprintf(fid, 'DC-feasible trials: %d (%.2f%%)\n', ...
        dcCount, 100*dcCount/N);
    fprintf(fid, 'Finite gain trials: %d\n', sum(finiteGain));
    fprintf(fid, 'Gain below %.2f dB: %d\n', ...
        gainThreshold_dB, gainFailCount);
    fprintf(fid, 'DC-feasible and gain below threshold: %d\n', ...
        sum(dcGainFail));
    fprintf(fid, 'Recorded robust-feasible: %d\n', ...
        recordedRobustCount);
    fprintf(fid, 'Reconstructed robust-feasible: %d\n', ...
        reconstructedRobustCount);
    fprintf(fid, 'Missing/nonfinite gain: %d\n', missingGainCount);
    fprintf(fid, 'Potential simulation errors: %d\n', errorCount);
    fprintf(fid, 'Robust classification mismatches: %d\n', ...
        sum(mismatch));
    fclose(fid);
end

fprintf('\n===== PHASE 5H COMPLETE =====\n');
fprintf('Saved analysis to:\n%s\n', outputFolder);
fprintf('\nReview these files first:\n');
fprintf('  Phase5H_Summary.txt\n');
fprintf('  Phase5H_FailureAnalysis.csv\n');
fprintf('  Phase5H_ParameterComparison.csv\n');
fprintf('  Phase5H_WorstGainTrials.csv\n');
fprintf('  Phase5H_DCInfeasibleTrials.csv\n');


clear; clc; close all;

projectRoot = 'C:\Internship Project';

inputCSV = fullfile(projectRoot, 'results', ...
    'Phase5D_RobustFinalists_20261020_213627', ...
    'Phase5D_AllTrials.csv');

% If the specified dated folder does not exist, use the newest
% matching Phase5D_AllTrials.csv.
if ~isfile(inputCSV)
    f = dir(fullfile(projectRoot, 'results', ...
        'Phase5D*', 'Phase5D_AllTrials.csv'));

    if isempty(f)
        error(['Phase5D_AllTrials.csv not found. ' ...
            'Check projectRoot and the results folder.']);
    end

    [~, ix] = max([f.datenum]);
    inputCSV = fullfile(f(ix).folder, f(ix).name);
end

fprintf('Reading input:\n%s\n\n', inputCSV);

T = readtable(inputCSV, 'VariableNamingRule', 'preserve');

names = string(T.Properties.VariableNames);
normNames = lower(regexprep(names, '[^a-zA-Z0-9]', ''));

% Match column names independent of case and punctuation.
col = @(s) find(normNames == ...
    lower(regexprep(string(s), '[^a-zA-Z0-9]', '')), 1);

%% 2. Validate required columns
% IMPORTANT: use the actual Phase 5D names for gain and power.
required = ["CandidateID", "Trial", "VDD_V", "RD_Ohm", ...
    "Vdrain_V", "VDS_V", "ID_A", "GainAt1kHz_dB"];

missing = strings(0, 1);

for k = 1:numel(required)
    if isempty(col(required(k)))
        missing(end+1, 1) = required(k); %#ok<SAGROW>
    end
end

if ~isempty(missing)
    error('Required column(s) missing: %s\nAvailable columns: %s', ...
        strjoin(missing, ', '), strjoin(names, ', '));
end

% Status columns are mandatory for reliable diagnosis.
% Do not silently classify missing status information as success.
statusRequired = ["DCSuccess", "ACSuccess"];

for k = 1:numel(statusRequired)
    if isempty(col(statusRequired(k)))
        error(['Required status column missing: %s. ' ...
            'Cannot reliably classify simulation failures.'], ...
            statusRequired(k));
    end
end

%% 3. Read numeric data
getNum = @(s) numericColumn(T, col(s));

CandidateID = getNum("CandidateID");
Trial       = getNum("Trial");
VDD         = getNum("VDD_V");
RD          = getNum("RD_Ohm");
Vdrain      = getNum("Vdrain_V");
VDS         = getNum("VDS_V");
ID          = getNum("ID_A");

% FIX 1: Phase 5D uses GainAt1kHz_dB, not Gain_dB.
Gain        = getNum("GainAt1kHz_dB");

% FIX 2: Phase 5D uses SupplyPower_mW, not Power_mW.
Power       = getNum("SupplyPower_mW");

% Optional parameter columns.
RGU         = getNum("RGU_Ohm");
RGL         = getNum("RGL_Ohm");
RS          = getNum("RS_Ohm");
CIN         = getNum("CIN_F");
Vsource     = getNum("Vsource_V");

% Read status columns.
dcOK = logicalColumn(T, col("DCSuccess"));
acOK = logicalColumn(T, col("ACSuccess"));

% Detect missing or unrecognized status values rather than counting
% them as simulation failures or successes without reporting them.
dcStatusUnknown = isnan(dcOK);
acStatusUnknown = isnan(acOK);

dcOK(dcStatusUnknown) = false;
acOK(acStatusUnknown) = false;

%% 4. Basic input checks
n = height(T);

if n == 0
    error('The input CSV contains no trial rows.');
end

if any(~isfinite(CandidateID))
    warning('%d row(s) have missing/invalid CandidateID.', ...
        sum(~isfinite(CandidateID)));
end

if any(~isfinite(Trial))
    warning('%d row(s) have missing/invalid Trial.', ...
        sum(~isfinite(Trial)));
end

if any(~isfinite(VDD) | VDD <= 0)
    warning('%d row(s) have invalid VDD values.', ...
        sum(~isfinite(VDD) | VDD <= 0));
end

if any(~isfinite(RD) | RD <= 0)
    warning('%d row(s) have invalid RD values.', ...
        sum(~isfinite(RD) | RD <= 0));
end

if any(dcStatusUnknown)
    warning(['%d row(s) have unrecognized/missing DCSuccess values. ' ...
        'These rows are conservatively treated as DC failures.'], ...
        sum(dcStatusUnknown));
end

if any(acStatusUnknown)
    warning(['%d row(s) have unrecognized/missing ACSuccess values. ' ...
        'These rows are conservatively treated as AC failures.'], ...
        sum(acStatusUnknown));
end

%% 5. Recompute individual DC constraint failures
% These are the thresholds from the original Phase 5E script.
% Confirm that they match your actual design specifications.

drainRatio = nan(n, 1);
validVDD = isfinite(VDD) & VDD > 0;
drainRatio(validVDD) = Vdrain(validVDD) ./ VDD(validVDD);

currentLimit = nan(n, 1);
validRD = isfinite(RD) & RD > 0;
currentLimit(validRD) = VDD(validRD) ./ RD(validRD);

badVDS = isfinite(VDS) & VDS < 1;

badDrainLow = isfinite(drainRatio) & drainRatio < 0.15;
badDrainHigh = isfinite(drainRatio) & drainRatio > 0.85;

badIDLow = isfinite(ID) & ID < 1e-6;

badIDHigh = isfinite(ID) & isfinite(currentLimit) ...
    & ID >= currentLimit;

% A trial is DC-feasible only when its DC simulation succeeded,
% all required measurements exist, and all listed constraints pass.
dcFeasible = dcOK ...
    & isfinite(VDS) ...
    & isfinite(drainRatio) ...
    & isfinite(ID) ...
    & isfinite(currentLimit) ...
    & ~badVDS ...
    & ~badDrainLow ...
    & ~badDrainHigh ...
    & ~badIDLow ...
    & ~badIDHigh;

%% 6. AC gain and robust feasibility
% Gain is measured at 1 kHz in the Phase 5D data.
gainLow = acOK & isfinite(Gain) & Gain < 3;
gainNegative = acOK & isfinite(Gain) & Gain < 0;

% Gain >= 3 dB is retained from the original Phase 5E criterion.
robustFeasible = dcFeasible & acOK ...
    & isfinite(Gain) & Gain >= 3;

% AC success without a recorded gain is a data-quality problem.
gainMissing = acOK & ~isfinite(Gain);

%% 7. Generate explicit reasons for each trial
reason = strings(n, 1);

for i = 1:n
    r = strings(0, 1);

    if dcStatusUnknown(i)
        r(end+1) = "DC status missing or unrecognized";
    elseif ~dcOK(i)
        r(end+1) = "DC simulation failed";
    end

    if ~isfinite(VDS(i))
        r(end+1) = "VDS missing";
    elseif badVDS(i)
        r(end+1) = "VDS below 1 V";
    end

    if ~isfinite(drainRatio(i))
        r(end+1) = "Drain ratio unavailable";
    else
        if badDrainLow(i)
            r(end+1) = "Drain ratio below 0.15";
        end

        if badDrainHigh(i)
            r(end+1) = "Drain ratio above 0.85";
        end
    end

    if ~isfinite(ID(i))
        r(end+1) = "Drain current missing";
    else
        if badIDLow(i)
            r(end+1) = "ID below 1 uA";
        end

        if badIDHigh(i)
            r(end+1) = "ID >= VDD/RD";
        end
    end

    if acStatusUnknown(i)
        r(end+1) = "AC status missing or unrecognized";
    elseif ~acOK(i)
        r(end+1) = "AC simulation failed";
    elseif ~isfinite(Gain(i))
        r(end+1) = "Gain missing despite AC success";
    elseif Gain(i) < 3
        r(end+1) = "Gain below 3 dB";
    end

    if isempty(r)
        reason(i) = "No recomputed failure";
    else
        reason(i) = strjoin(r, "; ");
    end
end

%% 8. Trial-level diagnosis table
D = table(CandidateID, Trial, RGU, RGL, RD, RS, CIN, VDD, ...
    Vsource, Vdrain, drainRatio, VDS, ID, currentLimit, Gain, Power, ...
    dcOK, acOK, dcFeasible, robustFeasible, ...
    badVDS, badDrainLow, badDrainHigh, badIDLow, badIDHigh, ...
    gainLow, gainNegative, gainMissing, ...
    dcStatusUnknown, acStatusUnknown, reason, ...
    'VariableNames', {'CandidateID', 'Trial', 'RGU_Ohm', 'RGL_Ohm', ...
    'RD_Ohm', 'RS_Ohm', 'CIN_F', 'VDD_V', 'Vsource_V', 'Vdrain_V', ...
    'DrainRatio', 'VDS_V', 'ID_A', 'CurrentLimit_A', ...
    'GainAt1kHz_dB', 'SupplyPower_mW', ...
    'DCSuccess', 'ACSuccess', 'DCFeasible', 'RobustFeasible', ...
    'Fail_VDS', 'Fail_DrainLow', 'Fail_DrainHigh', ...
    'Fail_IDLow', 'Fail_IDHigh', 'GainBelow3dB', 'NegativeGain', ...
    'GainMissing', 'DCStatusUnknown', 'ACStatusUnknown', ...
    'FailureReasons'});

%% 9. Candidate-level summary
ids = unique(CandidateID(isfinite(CandidateID)));
S = table();

for k = 1:numel(ids)
    id = ids(k);
    ix = CandidateID == id;

    successfulGain = ix & acOK & isfinite(Gain);
    g = Gain(successfulGain);

    if isempty(g)
        meanG = NaN;
        stdG = NaN;
        p05 = NaN;
        worstG = NaN;
    else
        meanG = mean(g);
        if numel(g) > 1
            stdG = std(g);
        else
            stdG = 0;
        end
        worstG = min(g);
        p05 = prctile(g, 5);
    end

    totalTrials = sum(ix);

    % Rates use all trials for the candidate as denominator.
    % Unknown status values are conservatively counted as unsuccessful.
    row = table(id, totalTrials, mean(dcOK(ix)), mean(acOK(ix)), ...
        mean(dcFeasible(ix)), mean(robustFeasible(ix)), ...
        sum(ix & badVDS), sum(ix & badDrainLow), ...
        sum(ix & badDrainHigh), sum(ix & badIDLow), ...
        sum(ix & badIDHigh), sum(ix & gainLow), ...
        sum(ix & gainNegative), sum(ix & gainMissing), ...
        sum(ix & dcStatusUnknown), sum(ix & acStatusUnknown), ...
        meanG, stdG, p05, worstG, ...
        'VariableNames', {'CandidateID', 'Trials', 'DCSuccessRate', ...
        'ACSuccessRate', 'DCFeasibilityRate', 'RobustFeasibilityRate', ...
        'Count_VDS_Fail', 'Count_DrainLow', 'Count_DrainHigh', ...
        'Count_IDLow', 'Count_IDHigh', 'Count_GainBelow3dB', ...
        'Count_NegativeGain', 'Count_GainMissing', ...
        'Count_DCStatusUnknown', 'Count_ACStatusUnknown', ...
        'MeanGain_dB', 'StdGain_dB', 'P05Gain_dB', 'WorstGain_dB'});

    S = [S; row]; %#ok<AGROW>
end

%% 10. Lowest-gain successful AC trials
W = D(acOK & isfinite(Gain), :);
W = sortrows(W, 'GainAt1kHz_dB', 'ascend');
W = W(1:min(30, height(W)), :);

%% 11. Save reports
outDir = fullfile(fileparts(inputCSV), 'Phase5E_Diagnosis');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

writetable(D, fullfile(outDir, 'Phase5E_TrialDiagnosis.csv'));
writetable(S, fullfile(outDir, 'Phase5E_CandidateFailureSummary.csv'));
writetable(W, fullfile(outDir, 'Phase5E_WorstGainTrials.csv'));

save(fullfile(outDir, 'Phase5E_Diagnosis.mat'), ...
    'inputCSV', 'D', 'S', 'W', ...
    'dcFeasible', 'robustFeasible', ...
    'gainLow', 'gainNegative', 'gainMissing');

%% 12. Plot constraint failure counts
counts = [sum(badVDS), sum(badDrainLow), sum(badDrainHigh), ...
    sum(badIDLow), sum(badIDHigh), sum(~dcOK), sum(~acOK), ...
    sum(gainMissing)];

labels = {'VDS<1V', 'Drain<0.15', 'Drain>0.85', ...
    'ID<1uA', 'ID>=VDD/RD', 'DC failed', 'AC failed', ...
    'Gain missing'};

f1 = figure('Color', 'w');
bar(categorical(labels), counts);
ylabel('Number of trials');
title('Phase 5D: Constraint Failure Counts');
grid on;

ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(f1, fullfile(outDir, 'Phase5E_FailureCounts.png'), ...
    'Resolution', 160);

%% 13. Plot gain distribution per candidate
f2 = figure('Color', 'w');
hold on;

for k = 1:numel(ids)
    ix = CandidateID == ids(k) & acOK & isfinite(Gain);

    if any(ix)
        histogram(Gain(ix), 'DisplayStyle', 'stairs', ...
            'LineWidth', 1.5, ...
            'DisplayName', sprintf('Candidate %.0f', ids(k)));
    end
end

xline(3, '--', '3 dB target');
xlabel('Gain at 1 kHz (dB)');
ylabel('Trial count');
title('Phase 5D: Tolerance Gain Distributions');

if ~isempty(ids)
    legend('Location', 'best');
end

grid on;
ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(f2, fullfile(outDir, 'Phase5E_GainDistribution.png'), ...
    'Resolution', 160);

%% 14. Console report
fprintf('\n===== PHASE 5E FAILURE DIAGNOSIS =====\n');
fprintf('Input: %s\n', inputCSV);
fprintf('Total trials: %d\n', height(D));
fprintf('Unique candidates: %d\n', numel(ids));
fprintf('DC simulation failures/unknown: %d\n', sum(~dcOK));
fprintf('AC simulation failures/unknown: %d\n', sum(~acOK));
fprintf('DC-infeasible trials: %d\n', sum(~dcFeasible));
fprintf('Gain below 3 dB: %d\n', sum(gainLow));
fprintf('Negative gain: %d\n', sum(gainNegative));
fprintf('Missing gain after AC success: %d\n', sum(gainMissing));
fprintf('Robust-feasible trials: %d\n\n', sum(robustFeasible));

disp(S);

fprintf('\nLowest-gain successful AC trials:\n');

if isempty(W)
    fprintf('No successful AC trials with valid gain were found.\n');
else
    disp(W(:, {'CandidateID', 'Trial', 'GainAt1kHz_dB', ...
        'VDS_V', 'DrainRatio', 'ID_A', 'FailureReasons'}));
end

fprintf('\nReports saved to:\n%s\n', outDir);

fprintf(['\nInterpretation note: this script analyzes the saved per-trial ' ...
    'gain at 1 kHz. It cannot inspect full AC response curves unless ' ...
    'those curves were separately saved.\n']);

%% 15. Local helper functions
function x = numericColumn(T, idx)
    n = height(T);

    if isempty(idx)
        x = nan(n, 1);
        return;
    end

    v = T{:, idx};

    if isnumeric(v) || islogical(v)
        x = double(v);
    else
        x = str2double(string(v));
    end

    x = x(:);
end

function x = logicalColumn(T, idx)
    n = height(T);

    if isempty(idx)
        x = nan(n, 1);
        return;
    end

    v = T{:, idx};

    if islogical(v)
        x = double(v(:));
    elseif isnumeric(v)
        x = double(v(:));
        x(~ismember(x, [0, 1])) = NaN;
    else
        s = lower(strtrim(string(v(:))));
        x = nan(n, 1);

        trueValues = ["true", "1", "yes", "success", "ok"];
        falseValues = ["false", "0", "no", "fail", "failed", ...
            "failure", "error"];

        x(ismember(s, trueValues)) = 1;
        x(ismember(s, falseValues)) = 0;
        x = double(x);
    end

    x = x(:);
end


clear; clc; close all;

%% PHASE 5F: FINALIST RANKING AND SELECTION
% Uses existing Phase 5D trial results and Phase 5E diagnosis.
% No circuit simulations are rerun in this phase.
%
% Ranking priority:
% 1. Robust feasibility rate (higher is better)
% 2. 5th-percentile gain (higher is better)
% 3. Mean gain (higher is better)
% 4. Gain standard deviation (lower is better)
% 5. Mean supply power (lower is better)
%
% IMPORTANT:
% The result is preliminary until the engineering constraints
% used by Phase 5E are confirmed.

%% 1. Locate input files
projectRoot = 'C:\Internship Project';

phase5DDir = fullfile(projectRoot, 'results', ...
    'Phase5D_RobustFinalists_20261020_213627');

inputCSV = fullfile(phase5DDir, 'Phase5D_AllTrials.csv');

phase5EDir = fullfile(phase5DDir, 'Phase5E_Diagnosis');
diagnosisCSV = fullfile(phase5EDir, ...
    'Phase5E_TrialDiagnosis.csv');

summaryCSV = fullfile(phase5EDir, ...
    'Phase5E_CandidateFailureSummary.csv');

if ~isfile(inputCSV)
    error('Phase 5D input file not found: %s', inputCSV);
end

if ~isfile(diagnosisCSV)
    error(['Phase 5E diagnosis file not found: %s\n' ...
        'Run Phase 5E first.'], diagnosisCSV);
end

if ~isfile(summaryCSV)
    error('Phase 5E candidate summary not found: %s', summaryCSV);
end

fprintf('Phase 5F finalist ranking\n');
fprintf('Phase 5D input: %s\n', inputCSV);
fprintf('Phase 5E input: %s\n\n', diagnosisCSV);

%% 2. Load existing results
T = readtable(inputCSV, 'VariableNamingRule', 'preserve');
D = readtable(diagnosisCSV, 'VariableNamingRule', 'preserve');
S = readtable(summaryCSV, 'VariableNamingRule', 'preserve');

% Normalize names for case/punctuation-independent matching.
normalize = @(x) lower(regexprep(string(x), '[^a-zA-Z0-9]', ''));

colT = @(s) find(normalize(T.Properties.VariableNames) ...
    == normalize(s), 1);

colD = @(s) find(normalize(D.Properties.VariableNames) ...
    == normalize(s), 1);

%% 3. Validate required fields
requiredT = ["CandidateID", "Trial", ...
    "GainAt1kHz_dB", "SupplyPower_mW"];

requiredD = ["CandidateID", "Trial", ...
    "DCFeasible", "RobustFeasible", ...
    "ACSuccess", "GainAt1kHz_dB", "SupplyPower_mW"];

for k = 1:numel(requiredT)
    if isempty(colT(requiredT(k)))
        error('Required Phase 5D column missing: %s', requiredT(k));
    end
end

for k = 1:numel(requiredD)
    if isempty(colD(requiredD(k)))
        error('Required Phase 5E column missing: %s', requiredD(k));
    end
end

% Use the Phase 5E diagnosis as the authoritative source for
% feasibility under the existing Phase 5E rules.
CandidateID = readNumeric(D, colD("CandidateID"));
Trial       = readNumeric(D, colD("Trial"));
DCFeasible  = readLogical(D, colD("DCFeasible"));
Robust      = readLogical(D, colD("RobustFeasible"));
ACSuccess   = readLogical(D, colD("ACSuccess"));

Gain = readNumeric(D, colD("GainAt1kHz_dB"));
Power = readNumeric(D, colD("SupplyPower_mW"));

if height(T) ~= height(D)
    error(['Phase 5D and Phase 5E row counts differ. ' ...
        'Cannot safely align trial results.']);
end

% Verify that candidate/trial identifiers correspond row by row.
candidateT = readNumeric(T, colT("CandidateID"));
trialT = readNumeric(T, colT("Trial"));

if any(candidateT ~= CandidateID | trialT ~= Trial, 'all')
    error(['Phase 5D and Phase 5E trial ordering/identifiers differ. ' ...
        'Resolve the mismatch before ranking.']);
end

if any(isnan(DCFeasible) | isnan(Robust) | isnan(ACSuccess))
    error('Missing feasibility/status values detected. Resolve first.');
end

if any(Robust & ~DCFeasible)
    error('Inconsistent data: a robust-feasible trial is DC-infeasible.');
end

%% 4. Identify finalists
ids = unique(CandidateID(isfinite(CandidateID)));

if isempty(ids)
    error('No valid candidate IDs found.');
end

fprintf('Candidates found: %s\n', mat2str(ids'));
fprintf('Total trials: %d\n\n', height(D));

%% 5. Calculate comparable candidate metrics
R = table();

for k = 1:numel(ids)
    id = ids(k);
    ix = CandidateID == id;
    nTrials = sum(ix);

    if nTrials == 0
        continue;
    end

    % Rates use all trials as the denominator.
    dcRate = mean(DCFeasible(ix));
    robustRate = mean(Robust(ix));

    % Gain metrics use trials with successful AC and finite gain.
    validGain = ix & ACSuccess & isfinite(Gain);
    g = Gain(validGain);

    nValidGain = numel(g);

    if isempty(g)
        meanGain = NaN;
        stdGain = NaN;
        p05Gain = NaN;
        worstGain = NaN;
        medianGain = NaN;
    else
        meanGain = mean(g);
        medianGain = median(g);
        p05Gain = prctile(g, 5);
        worstGain = min(g);

        if numel(g) > 1
            stdGain = std(g);
        else
            stdGain = 0;
        end
    end

    % Power metrics use available finite recorded power values.
    validPower = ix & isfinite(Power);
    p = Power(validPower);

    nValidPower = numel(p);

    if isempty(p)
        meanPower = NaN;
        maxPower = NaN;
        p95Power = NaN;
    else
        meanPower = mean(p);
        maxPower = max(p);
        p95Power = prctile(p, 95);
    end

    % Count failures under the existing Phase 5E classification.
    dcFailures = sum(ix & ~DCFeasible);
    robustFailures = sum(ix & ~Robust);

    row = table(id, nTrials, nValidGain, nValidPower, ...
        dcRate, robustRate, dcFailures, robustFailures, ...
        meanGain, medianGain, stdGain, p05Gain, worstGain, ...
        meanPower, p95Power, maxPower);

    R = [R; row]; %#ok<AGROW>
end

R.Properties.VariableNames = { ...
    'CandidateID', 'Trials', 'ValidGainTrials', 'ValidPowerTrials', ...
    'DCFeasibilityRate', 'RobustFeasibilityRate', ...
    'DCFailures', 'RobustFailures', ...
    'MeanGain_dB', 'MedianGain_dB', 'StdGain_dB', ...
    'P05Gain_dB', 'WorstGain_dB', ...
    'MeanSupplyPower_mW', 'P95SupplyPower_mW', ...
    'MaxSupplyPower_mW'};

%% 6. Rank finalists
% Lexicographic ranking: feasibility takes priority over gain.
% Gain statistics then break ties; power is the final tie-breaker.
%
% Missing metrics are placed after available metrics.
% Power is ranked ascending only after all higher-priority criteria.

R.P05Sort = R.P05Gain_dB;
R.MeanGainSort = R.MeanGain_dB;
R.StdGainSort = R.StdGain_dB;
R.PowerSort = R.MeanSupplyPower_mW;

R.P05Sort(~isfinite(R.P05Sort)) = -Inf;
R.MeanGainSort(~isfinite(R.MeanGainSort)) = -Inf;
R.StdGainSort(~isfinite(R.StdGainSort)) = Inf;
R.PowerSort(~isfinite(R.PowerSort)) = Inf;

R = sortrows(R, ...
    {'RobustFeasibilityRate', 'P05Sort', 'MeanGainSort', ...
     'StdGainSort', 'PowerSort'}, ...
    {'descend', 'descend', 'descend', 'ascend', 'ascend'});

R.Rank = (1:height(R))';

% Put rank and candidate ID at the beginning.
R = movevars(R, 'Rank', 'Before', 'CandidateID');

% Remove helper columns used only for sorting.
R.P05Sort = [];
R.MeanGainSort = [];
R.StdGainSort = [];
R.PowerSort = [];

%% 7. Select preliminary winner
winnerID = R.CandidateID(1);

% A feasibility rate of 100% is not required here because this is
% a preliminary ranking of the supplied finalists.
% The winner remains subject to engineering constraint validation.
winner = R(1, :);

fprintf('===== PHASE 5F RANKING =====\n');
disp(R);

fprintf('\nPreliminary winner: Candidate %.0f\n', winnerID);
fprintf('Robust feasibility: %.2f%%\n', ...
    100 * winner.RobustFeasibilityRate);
fprintf('Mean gain: %.4f dB\n', winner.MeanGain_dB);
fprintf('5th-percentile gain: %.4f dB\n', winner.P05Gain_dB);
fprintf('Worst recorded gain: %.4f dB\n', winner.WorstGain_dB);
fprintf('Gain standard deviation: %.4f dB\n', winner.StdGain_dB);
fprintf('Mean recorded supply power: %.4f mW\n', ...
    winner.MeanSupplyPower_mW);

%% 8. Create output directory
outDir = fullfile(phase5DDir, 'Phase5F_FinalistRanking');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 9. Save rankings and winner
writetable(R, fullfile(outDir, ...
    'Phase5F_FinalistRanking.csv'));

writetable(winner, fullfile(outDir, ...
    'Phase5F_PreliminaryWinner.csv'));

% Save the trial data and ranking for reproducibility.
save(fullfile(outDir, 'Phase5F_FinalistRanking.mat'), ...
    'inputCSV', 'diagnosisCSV', 'R', 'winner', ...
    'winnerID', 'CandidateID', 'Trial', ...
    'DCFeasible', 'Robust', 'ACSuccess', 'Gain', 'Power');

%% 10. Plot robust-feasibility rate
f1 = figure('Color', 'w');

bar(categorical(string(R.CandidateID)), ...
    100 * R.RobustFeasibilityRate);

ylabel('Robust-feasible trials (%)');
xlabel('Candidate ID');
title('Phase 5F: Finalist Feasibility Comparison');
grid on;

ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(f1, fullfile(outDir, ...
    'Phase5F_FeasibilityComparison.png'), 'Resolution', 160);

%% 11. Plot gain distribution
f2 = figure('Color', 'w');
hold on;

for k = 1:numel(ids)
    ix = CandidateID == ids(k) & ACSuccess & isfinite(Gain);

    if any(ix)
        histogram(Gain(ix), 'DisplayStyle', 'stairs', ...
            'LineWidth', 1.5, ...
            'DisplayName', sprintf('Candidate %.0f', ids(k)));
    end
end

xline(3, '--', '3 dB target');
xlabel('Gain at 1 kHz (dB)');
ylabel('Trial count');
title('Phase 5F: Gain Distribution Comparison');
legend('Location', 'best');
grid on;

ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(f2, fullfile(outDir, ...
    'Phase5F_GainComparison.png'), 'Resolution', 160);

%% 12. Plot mean recorded power
if any(isfinite(R.MeanSupplyPower_mW))
    f3 = figure('Color', 'w');

    bar(categorical(string(R.CandidateID)), ...
        R.MeanSupplyPower_mW);

    ylabel('Mean recorded supply power (mW)');
    xlabel('Candidate ID');
    title('Phase 5F: Supply Power Comparison');
    grid on;

    ax = gca;
    ax.Toolbar.Visible = 'off';

    exportgraphics(f3, fullfile(outDir, ...
        'Phase5F_PowerComparison.png'), 'Resolution', 160);
end

%% 13. Save human-readable decision report
reportFile = fullfile(outDir, 'Phase5F_DecisionReport.txt');
fid = fopen(reportFile, 'w');

if fid < 0
    warning('Could not create text report: %s', reportFile);
else
    fprintf(fid, 'PHASE 5F: FINALIST RANKING\n\n');
    fprintf(fid, 'Input CSV: %s\n', inputCSV);
    fprintf(fid, 'Diagnosis CSV: %s\n\n', diagnosisCSV);

    fprintf(fid, 'Ranking priority:\n');
    fprintf(fid, '1. Robust feasibility rate, descending\n');
    fprintf(fid, '2. 5th-percentile gain, descending\n');
    fprintf(fid, '3. Mean gain, descending\n');
    fprintf(fid, '4. Gain standard deviation, ascending\n');
    fprintf(fid, '5. Mean supply power, ascending\n\n');

    fprintf(fid, 'Preliminary winner: Candidate %.0f\n', winnerID);
    fprintf(fid, 'Robust feasibility: %.2f%%\n', ...
        100 * winner.RobustFeasibilityRate);
    fprintf(fid, 'Mean gain: %.4f dB\n', winner.MeanGain_dB);
    fprintf(fid, 'P05 gain: %.4f dB\n', winner.P05Gain_dB);
    fprintf(fid, 'Worst gain: %.4f dB\n', winner.WorstGain_dB);
    fprintf(fid, 'Gain standard deviation: %.4f dB\n', ...
        winner.StdGain_dB);
    fprintf(fid, 'Mean supply power: %.4f mW\n\n', ...
        winner.MeanSupplyPower_mW);

    fprintf(fid, ['WARNING: This ranking inherits the Phase 5E ' ...
        'constraint definitions. Validate the 1 V VDS minimum, ' ...
        'drain-ratio bounds, and 3 dB gain requirement before ' ...
        'calling this a validated final design.\n']);

    fclose(fid);
end

%% 14. Completion message
fprintf('\nReports saved to:\n%s\n', outDir);

fprintf(['\nPhase 5F is a ranking phase, not a new circuit ' ...
    'simulation or independent validation phase.\n']);

fprintf(['The preliminary winner is selected using the existing ' ...
    'Phase 5E feasibility rules and the stated tie-breakers.\n']);

%% Local helper functions
function x = readNumeric(T, idx)
    v = T{:, idx};

    if isnumeric(v) || islogical(v)
        x = double(v);
    else
        x = str2double(string(v));
    end

    x = x(:);
end

function x = readLogical(T, idx)
    v = T{:, idx};

    if islogical(v)
        x = double(v(:));
    elseif isnumeric(v)
        x = double(v(:));
        x(~ismember(x, [0 1])) = NaN;
    else
        s = lower(strtrim(string(v(:))));
        x = nan(numel(s), 1);

        trueValues = ["true", "1", "yes", "success", "ok"];
        falseValues = ["false", "0", "no", "fail", "failed", ...
            "failure", "error"];

        x(ismember(s, trueValues)) = 1;
        x(ismember(s, falseValues)) = 0;
    end

    x = x(:);
end

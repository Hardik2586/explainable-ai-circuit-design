
%% PHASE 5G: INDEPENDENT VALIDATION OF CANDIDATE 152
% Fresh Monte Carlo validation using the existing SPICE engine.
% Does not retrain the ML model or change Candidate 152's nominal design.

clear; clc; close all;

%% 1. Configuration
rng(20261022, 'twister');

root = 'C:\Internship Project';
addpath(genpath(fullfile(root, 'src')));
rehash;

assert(exist('runUniversalSpice', 'file') == 2, ...
    'runUniversalSpice not found. Check the src folder.');

resultsRoot = fullfile(root, 'results');
candidateID = 152;
Ntrials = 1000;

VDDnom = 12;
tolR = 0.05;
tolC = 0.10;
tolVDD = 0.05;
fref = 1000;

minVDS = 1.0;
minDrainRatio = 0.15;
maxDrainRatio = 0.85;
minID = 1e-6;
minGain = 3;

%% 2. Load Candidate 152 nominal parameters
d = dir(fullfile(resultsRoot, 'Phase5A_ExhaustiveAC_*'));
d = d([d.isdir]);

assert(~isempty(d), ...
    'No Phase5A_ExhaustiveAC folder found.');

[~, ix] = max([d.datenum]);
sourceDir = fullfile(d(ix).folder, d(ix).name);

rankingFile = fullfile(sourceDir, ...
    'Phase5A1_Exhaustive_AC_Ranking.csv');

assert(isfile(rankingFile), ...
    'Candidate ranking file not found: %s', rankingFile);

Ranked = readtable(rankingFile, ...
    'VariableNamingRule', 'preserve');

required = {'CandidateID','RGU_Ohm','RGL_Ohm', ...
    'RD_Ohm','RS_Ohm','CIN_F'};

assert(all(ismember(required, Ranked.Properties.VariableNames)), ...
    'The Phase 5A ranking file is missing required columns.');

qRows = Ranked(Ranked.CandidateID == candidateID, :);

assert(height(qRows) == 1, ...
    'Expected exactly one nominal row for Candidate 152.');

q = qRows(1,:);

fprintf('Candidate ID: %d\n', candidateID);
fprintf('Nominal RGU: %.6g Ohm\n', q.RGU_Ohm);
fprintf('Nominal RGL: %.6g Ohm\n', q.RGL_Ohm);
fprintf('Nominal RD:  %.6g Ohm\n', q.RD_Ohm);
fprintf('Nominal RS:  %.6g Ohm\n', q.RS_Ohm);
fprintf('Nominal CIN: %.6g F\n', q.CIN_F);
fprintf('Nominal VDD: %.4f V\n', VDDnom);
fprintf('Fresh trials: %d\n\n', Ntrials);

%% 3. Load the existing 2N7000 model
modelPath = fullfile(root, ...
    'models', 'mosfet', '2N7000.onsemi.lib');

assert(isfile(modelPath), ...
    '2N7000 model not found: %s', modelPath);

mm = ModelManager();
mm = mm.registerFileModel("2N7000", "MOSFET", modelPath);

optDC = struct( ...
    'Analysis', "DC", ...
    'KeepFiles', true);

optAC = struct( ...
    'Analysis', "AC", ...
    'ACStart', 10, ...
    'ACStop', 1e6, ...
    'PointsPerDecade', 50, ...
    'PrintExpressions', ["vm(IN)", "vp(IN)", ...
        "vm(GATE)", "vp(GATE)", ...
        "vm(DRAIN)", "vp(DRAIN)"], ...
    'KeepFiles', true);

%% 4. Create a separate output folder
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));

outDir = fullfile(resultsRoot, ...
    ['Phase5G_IndependentValidation_' stamp]);

if ~isfolder(outDir)
    mkdir(outDir);
end

%% 5. Initialize validation results
Trial = table();

%% 6. Run fresh independent trials
for t = 1:Ntrials

    % Independent uniform tolerance draws.
    RGU = q.RGU_Ohm * (1 + uniformTol(tolR));
    RGL = q.RGL_Ohm * (1 + uniformTol(tolR));
    RD  = q.RD_Ohm  * (1 + uniformTol(tolR));
    RS  = q.RS_Ohm  * (1 + uniformTol(tolR));
    CIN = q.CIN_F   * (1 + uniformTol(tolC));
    VDD = VDDnom    * (1 + uniformTol(tolVDD));

   r = table( ...
       candidateID, t, RGU, RGL, RD, RS, CIN, VDD, ...
       NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
       false, false, false, false, "NOT_RUN", "", ...
      'VariableNames', { ...
      'CandidateID','Trial', ...
      'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V', ...
      'Vsource_V','Vdrain_V','VGS_V','VDS_V','ID_A', ...
      'GainAt1kHz_dB','SupplyPower_mW', ...
      'DCSuccess','ACSuccess','DCFeasible', ...
      'MeetsAllConstraints','Status','ErrorMessage'});

    try
        %% DC simulation
        c = makeCircuit(candidateID*10000+t, ...
            RGU, RGL, RD, RS, CIN, VDD);

        dc = runUniversalSpice(c, mm, optDC);

        if ~dc.Success
            error('DC simulation failed: %s', ...
                string(dc.ErrorMessage));
        end

        r.Vsource_V = nodeV(dc, "source");
        r.Vdrain_V  = nodeV(dc, "drain");
        r.VGS_V = nodeV(dc, "gate") - r.Vsource_V;
        r.VDS_V = r.Vdrain_V - r.Vsource_V;
        r.ID_A = r.Vsource_V / RS;
        r.DCSuccess = true;

        drainRatio = r.Vdrain_V / VDD;

        r.SupplyPower_mW = ...
            1000 * VDD * (r.ID_A + VDD/(RGU+RGL));

        % Retain the current Phase 5E electrical criteria.
        r.DCFeasible = ...
            r.VDS_V >= minVDS && ...
            drainRatio >= minDrainRatio && ...
            drainRatio <= maxDrainRatio && ...
            r.ID_A >= minID && ...
            r.ID_A < VDD/RD;

        %% AC simulation
        iVIN = find(arrayfun(@(z) ...
            string(z.Name) == "VIN", c.Components), 1);

        assert(~isempty(iVIN), 'VIN component not found.');

        vin = c.Components(iVIN);
        vin.Parameters.DC = 0;
        vin.Parameters.AC = 1;
        vin.Parameters.ACPhase = 0;
        c.Components(iVIN) = vin;

        ac = runUniversalSpice(c, mm, optAC);

        if ~ac.Success
            error('AC simulation failed: %s', ...
                string(ac.ErrorMessage));
        end

        assert(isfield(ac.ACSignals,'in') && ...
            isfield(ac.ACSignals,'drain'), ...
            'AC input/drain signals missing.');

        si = ac.ACSignals.in;
        so = ac.ACSignals.drain;

        f = si.Frequency(:);
        fo = so.Frequency(:);

        assert(numel(f) == numel(fo) && ...
            all(abs(f-fo) < 1e-9), ...
            'AC frequency grids differ.');

        [f, ord] = sort(f);
        inputMag = si.Magnitude(ord);
        outputMag = so.Magnitude(ord);

        gainDB = 20*log10(max( ...
            outputMag ./ inputMag, realmin));

        r.GainAt1kHz_dB = interp1( ...
            log10(f), gainDB, log10(fref), 'linear');

        assert(isfinite(r.GainAt1kHz_dB), ...
            'Gain at 1 kHz is invalid.');

        r.ACSuccess = true;

        r.MeetsAllConstraints = ...
            r.DCFeasible && r.GainAt1kHz_dB >= minGain;

        r.Status = "SUCCESS";

    catch ME
        % A simulation or measurement error counts as unsuccessful
        % for the overall validation rate.
        r.Status = "ERROR";
        r.ErrorMessage = string(ME.message);
    end

    Trial = [Trial; r]; %#ok<AGROW>

    %% Progress and recovery files
    if mod(t,25) == 0 || t == Ntrials

        fprintf(['Trial %4d/%4d | DC feasible %4d | ' ...
            'AC success %4d | Robust feasible %4d\n'], ...
            t, Ntrials, ...
            sum(Trial.DCFeasible), ...
            sum(Trial.ACSuccess), ...
            sum(Trial.MeetsAllConstraints));

        writetable(Trial, fullfile(outDir, ...
            'Phase5G_Progress.csv'));

        save(fullfile(outDir, 'Phase5G_Progress.mat'), ...
            'Trial','q','Ntrials','tolR','tolC','tolVDD', ...
            'minVDS','minDrainRatio','maxDrainRatio', ...
            'minID','minGain','fref','-v7.3');
    end
end

%% 7. Calculate independent validation metrics
N = height(Trial);

dcRate = mean(Trial.DCFeasible);
acRate = mean(Trial.ACSuccess);
robustRate = mean(Trial.MeetsAllConstraints);

nRobust = sum(Trial.MeetsAllConstraints);
nErrors = sum(Trial.Status == "ERROR");

validGain = Trial.ACSuccess & ...
    isfinite(Trial.GainAt1kHz_dB);

g = Trial.GainAt1kHz_dB(validGain);

if isempty(g)
    meanGain = NaN;
    stdGain = NaN;
    p05Gain = NaN;
    worstGain = NaN;
else
    meanGain = mean(g);
    stdGain = std(g);
    p05Gain = prctile(g,5);
    worstGain = min(g);
end

validPower = isfinite(Trial.SupplyPower_mW);
p = Trial.SupplyPower_mW(validPower);

if isempty(p)
    meanPower = NaN;
else
    meanPower = mean(p);
end

%% 8. 95% Wilson confidence interval for robust feasibility
% Does not require the Statistics and Machine Learning Toolbox.
z = 1.95996398454005;
phat = nRobust / N;

denom = 1 + z^2/N;

center = (phat + z^2/(2*N)) / denom;

halfWidth = z * sqrt( ...
    phat*(1-phat)/N + z^2/(4*N^2)) / denom;

ciLow = max(0, center-halfWidth);
ciHigh = min(1, center+halfWidth);

%% 9. Summary table
Summary = table(candidateID, N, nRobust, nErrors, ...
    dcRate, acRate, robustRate, ciLow, ciHigh, ...
    meanGain, stdGain, p05Gain, worstGain, meanPower, ...
    'VariableNames', {'CandidateID','Trials', ...
    'RobustFeasibleTrials','SimulationErrorTrials', ...
    'DCFeasibilityRate','ACSuccessRate', ...
    'RobustFeasibilityRate','Wilson95_CI_Lower', ...
    'Wilson95_CI_Upper','MeanGain_dB','StdGain_dB', ...
    'P05Gain_dB','WorstGain_dB','MeanSupplyPower_mW'});

%% 10. Save final outputs
writetable(Trial, fullfile(outDir, ...
    'Phase5G_IndependentValidation_AllTrials.csv'));

writetable(Summary, fullfile(outDir, ...
    'Phase5G_ValidationSummary.csv'));

save(fullfile(outDir, 'Phase5G_IndependentValidation.mat'), ...
    'Trial','Summary','q','Ntrials','tolR','tolC','tolVDD', ...
    'minVDS','minDrainRatio','maxDrainRatio','minID', ...
    'minGain','fref','ciLow','ciHigh','-v7.3');

%% 11. Gain distribution plot
fig = figure('Color','w');

histogram(Trial.GainAt1kHz_dB(validGain), ...
    'DisplayStyle','stairs','LineWidth',1.5);

hold on;
xline(minGain,'--','3 dB minimum');

xlabel('Gain at 1 kHz (dB)');
ylabel('Trial count');
title('Phase 5G: Independent Validation Gain Distribution');
grid on;

ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(fig, fullfile(outDir, ...
    'Phase5G_GainDistribution.png'), 'Resolution', 180);

%% 12. Feasibility plot
fig2 = figure('Color','w');

bar(categorical(["DC feasible","AC success","Robust feasible"]), ...
    100*[dcRate acRate robustRate]);

ylabel('Rate (%)');
title('Phase 5G: Independent Validation Rates');
ylim([0 100]);
grid on;

ax = gca;
ax.Toolbar.Visible = 'off';

exportgraphics(fig2, fullfile(outDir, ...
    'Phase5G_FeasibilityRates.png'), 'Resolution', 180);

%% 13. Console report
fprintf('\n===== PHASE 5G INDEPENDENT VALIDATION =====\n');
fprintf('Candidate: %d\n', candidateID);
fprintf('Trials: %d\n', N);
fprintf('DC feasibility: %.2f%%\n', 100*dcRate);
fprintf('AC success: %.2f%%\n', 100*acRate);
fprintf('Robust feasibility: %d/%d = %.2f%%\n', ...
    nRobust, N, 100*robustRate);
fprintf('95%% Wilson confidence interval: [%.2f%%, %.2f%%]\n', ...
    100*ciLow, 100*ciHigh);
fprintf('Simulation error trials: %d\n', nErrors);
fprintf('Mean gain at 1 kHz: %.4f dB\n', meanGain);
fprintf('Gain standard deviation: %.4f dB\n', stdGain);
fprintf('5th-percentile gain: %.4f dB\n', p05Gain);
fprintf('Worst recorded gain: %.4f dB\n', worstGain);
fprintf('Mean recorded supply power: %.4f mW\n', meanPower);
fprintf('\nReports saved to:\n%s\n', outDir);

fprintf(['\nInterpretation: this is independent validation under the ' ...
    'specified tolerance distributions and current constraints. ' ...
    'It does not prove hardware performance or validate the ' ...
    'engineering thresholds themselves.\n']);

%% Local helper functions
function x = uniformTol(t)
    x = (2*rand-1)*t;
end

function c = makeCircuit(id, RGU, RGL, RD, RS, CIN, VDD)
    c = createCircuit("Phase5G_CS_" + string(id));
    c.Metadata.Topology = "Common_Source";

    c = circuitAddComponent(c,"VDD","VOLTAGE_SOURCE", ...
        ["VDD","GND"],VDD);

    c = circuitAddComponent(c,"VIN","VOLTAGE_SOURCE", ...
        ["IN","GND"],0);

    c = circuitAddComponent(c,"RD","R", ...
        ["VDD","DRAIN"],RD);

    c = circuitAddComponent(c,"RS","R", ...
        ["SOURCE","GND"],RS);

    c = circuitAddComponent(c,"RGU","R", ...
        ["VDD","GATE"],RGU);

    c = circuitAddComponent(c,"M1","MOSFET", ...
        ["DRAIN","GATE","SOURCE"],[],"2N7000");

    i = find(arrayfun(@(x) string(x.Name)=="M1", ...
        c.Components),1);

    assert(~isempty(i),'M1 component not found.');

    m = c.Components(i);
    m = m.setParameter("UseSubcircuit",true);
    c.Components(i) = m;

    c = circuitAddComponent(c,"RGL","R", ...
        ["GATE","GND"],RGL);

    c = circuitAddComponent(c,"CIN","C", ...
        ["IN","GATE"],CIN);
end

function v = nodeV(r,n)
    s = lower(strtrim(string(r.NodeNames)));
    i = find(s == lower(string(n)),1);

    if isempty(i)
        error('Node not found: %s',n);
    end

    v = r.NodeVoltages(i);

    if ~isscalar(v) || ~isfinite(v)
        error('Invalid node voltage: %s',n);
    end
end

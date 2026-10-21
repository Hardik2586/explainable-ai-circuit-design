%% STEP 8C - OPERATING-POINT CONSTRAINT AUDIT
%
% Purpose:
%   Analyze SPICE-derived operating-point data from the existing
%   660 canonical CE amplifier circuits.
%
% This step DOES NOT:
%   - modify the canonical ML dataset
%   - modify the DL model
%   - modify circuitConstraints.m
%   - run optimization
%
% It identifies physically meaningful candidate constraints using
% actual SPICE operating-point data.
%
% Quantities analyzed:
%   Gain_dB
%   VCE
%   VCB
%   IC
%
% Outputs:
%   - statistical audit
%   - percentile analysis
%   - gain-region analysis
%   - correlation analysis
%   - candidate constraint recommendations
%   - plots
%   - MAT/CSV results
%
% IMPORTANT:
%   Candidate constraints are recommendations only.
%   They must be physically verified before being used in fmincon.

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8C - OPERATING-POINT CONSTRAINT AUDIT\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

inputCSV = fullfile( ...
    projectRoot, ...
    'data', ...
    'processed', ...
    'CE_Amplifier_OperatingPoint_660.csv');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

figureDir = fullfile(outputDir,'figures');

if ~isfolder(figureDir)
    mkdir(figureDir);
end

%% ============================================================
% CHECK INPUT
% ============================================================

if ~isfile(inputCSV)

    error( ...
        'Operating-point dataset not found:\n%s', ...
        inputCSV);

end

fprintf('[PASS] Operating-point dataset found.\n');

%% ============================================================
% LOAD DATA
% ============================================================

T = readtable(inputCSV);

fprintf('[PASS] Dataset loaded.\n');
fprintf('Rows: %d\n',height(T));
fprintf('Columns: %d\n',width(T));

if height(T) ~= 660

    error( ...
        'Expected 660 rows, found %d.', ...
        height(T));

end

requiredColumns = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC', ...
    'Gain_dB', ...
    'VB','VE','VC', ...
    'IB','IC','IE', ...
    'VCE','VCB', ...
    'Success','PhysicalValid'};

missing = setdiff( ...
    requiredColumns, ...
    T.Properties.VariableNames);

if ~isempty(missing)

    error( ...
        'Missing required columns: %s', ...
        strjoin(missing,', '));

end

fprintf('[PASS] Required columns confirmed.\n');

%% ============================================================
% BASIC VALIDITY CHECK
% ============================================================

if any(~T.Success)

    warning( ...
        '%d rows have unsuccessful SPICE runs.', ...
        sum(~T.Success));

end

if any(~T.PhysicalValid)

    warning( ...
        '%d rows are marked physically invalid.', ...
        sum(~T.PhysicalValid));

end

valid = T.Success & T.PhysicalValid;

Tv = T(valid,:);

Nvalid = height(Tv);

fprintf('\n');
fprintf('Valid SPICE operating points: %d / %d\n', ...
    Nvalid,height(T));

if Nvalid == 0

    error('No valid operating points available.');

end

%% ============================================================
% EXTRACT VARIABLES
% ============================================================

Gain = Tv.Gain_dB;

VCE = Tv.VCE;

VCB = Tv.VCB;

IC = Tv.IC;

VB = Tv.VB;

VE = Tv.VE;

VC = Tv.VC;

VCC = Tv.VCC;

%% ============================================================
% BASIC STATISTICS FUNCTION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' BASIC OPERATING-POINT STATISTICS\n');
fprintf('============================================================\n');

fprintf('\nGain_dB:\n');
fprintf('  Min    = %.6f dB\n',min(Gain));
fprintf('  1%%     = %.6f dB\n',prctile(Gain,1));
fprintf('  5%%     = %.6f dB\n',prctile(Gain,5));
fprintf('  Median = %.6f dB\n',median(Gain));
fprintf('  95%%    = %.6f dB\n',prctile(Gain,95));
fprintf('  99%%    = %.6f dB\n',prctile(Gain,99));
fprintf('  Max    = %.6f dB\n',max(Gain));

fprintf('\nVCE:\n');
fprintf('  Min    = %.6f V\n',min(VCE));
fprintf('  1%%     = %.6f V\n',prctile(VCE,1));
fprintf('  5%%     = %.6f V\n',prctile(VCE,5));
fprintf('  10%%    = %.6f V\n',prctile(VCE,10));
fprintf('  Median = %.6f V\n',median(VCE));
fprintf('  90%%    = %.6f V\n',prctile(VCE,90));
fprintf('  95%%    = %.6f V\n',prctile(VCE,95));
fprintf('  99%%    = %.6f V\n',prctile(VCE,99));
fprintf('  Max    = %.6f V\n',max(VCE));

fprintf('\nVCB:\n');
fprintf('  Min    = %.6f V\n',min(VCB));
fprintf('  1%%     = %.6f V\n',prctile(VCB,1));
fprintf('  5%%     = %.6f V\n',prctile(VCB,5));
fprintf('  10%%    = %.6f V\n',prctile(VCB,10));
fprintf('  Median = %.6f V\n',median(VCB));
fprintf('  90%%    = %.6f V\n',prctile(VCB,90));
fprintf('  95%%    = %.6f V\n',prctile(VCB,95));
fprintf('  99%%    = %.6f V\n',prctile(VCB,99));
fprintf('  Max    = %.6f V\n',max(VCB));

fprintf('\nIC:\n');
fprintf('  Min    = %.6e A\n',min(IC));
fprintf('  1%%     = %.6e A\n',prctile(IC,1));
fprintf('  5%%     = %.6e A\n',prctile(IC,5));
fprintf('  10%%    = %.6e A\n',prctile(IC,10));
fprintf('  Median = %.6e A\n',median(IC));
fprintf('  90%%    = %.6e A\n',prctile(IC,90));
fprintf('  95%%    = %.6e A\n',prctile(IC,95));
fprintf('  99%%    = %.6e A\n',prctile(IC,99));
fprintf('  Max    = %.6e A\n',max(IC));

%% ============================================================
% CORRELATION WITH GAIN
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' OPERATING POINT vs GAIN\n');
fprintf('============================================================\n');

rhoVCE = corr(Gain,VCE,'Type','Spearman');

rhoVCB = corr(Gain,VCB,'Type','Spearman');

rhoIC = corr(Gain,IC,'Type','Spearman');

rhoVB = corr(Gain,VB,'Type','Spearman');

rhoVE = corr(Gain,VE,'Type','Spearman');

rhoVC = corr(Gain,VC,'Type','Spearman');

fprintf('\nSpearman correlations with Gain_dB:\n');

fprintf('  VCE = %+0.6f\n',rhoVCE);
fprintf('  VCB = %+0.6f\n',rhoVCB);
fprintf('  IC  = %+0.6f\n',rhoIC);
fprintf('  VB  = %+0.6f\n',rhoVB);
fprintf('  VE  = %+0.6f\n',rhoVE);
fprintf('  VC  = %+0.6f\n',rhoVC);

%% ============================================================
% DEFINE GAIN REGIONS
% ============================================================
%
% Instead of arbitrarily calling circuits "good" or "bad",
% divide the existing dataset into:
%
%   Low    = bottom 25%
%   Medium = 25%-75%
%   High   = top 25%
%
% These are descriptive regions only.

q25 = prctile(Gain,25);
q75 = prctile(Gain,75);

lowIdx = Gain < q25;

mediumIdx = ...
    Gain >= q25 & ...
    Gain <= q75;

highIdx = Gain > q75;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' GAIN REGION DEFINITIONS\n');
fprintf('============================================================\n');

fprintf('\n25th percentile = %.6f dB\n',q25);
fprintf('75th percentile = %.6f dB\n',q75);

fprintf('\nLow region:\n');
fprintf('  Count = %d\n',sum(lowIdx));
fprintf('  Gain range = %.3f to %.3f dB\n', ...
    min(Gain(lowIdx)),max(Gain(lowIdx)));

fprintf('\nMedium region:\n');
fprintf('  Count = %d\n',sum(mediumIdx));
fprintf('  Gain range = %.3f to %.3f dB\n', ...
    min(Gain(mediumIdx)),max(Gain(mediumIdx)));

fprintf('\nHigh region:\n');
fprintf('  Count = %d\n',sum(highIdx));
fprintf('  Gain range = %.3f to %.3f dB\n', ...
    min(Gain(highIdx)),max(Gain(highIdx)));

%% ============================================================
% OPERATING-POINT STATISTICS BY GAIN REGION
% ============================================================

regionNames = ["Low";"Medium";"High"];

regionIdx = {
    lowIdx
    mediumIdx
    highIdx
    };

regionSummary = table( ...
    regionNames, ...
    zeros(3,1), ...
    zeros(3,1), ...
    zeros(3,1), ...
    zeros(3,1), ...
    zeros(3,1), ...
    zeros(3,1), ...
    zeros(3,1), ...
    zeros(3,1), ...
    'VariableNames',{ ...
    'Region', ...
    'Count', ...
    'Gain_Median_dB', ...
    'Gain_Min_dB', ...
    'Gain_Max_dB', ...
    'VCE_Median_V', ...
    'VCE_Min_V', ...
    'VCB_Median_V', ...
    'VCB_Min_V'});

for k = 1:3

    idx = regionIdx{k};

    regionSummary.Count(k) = sum(idx);

    regionSummary.Gain_Median_dB(k) = ...
        median(Gain(idx));

    regionSummary.Gain_Min_dB(k) = ...
        min(Gain(idx));

    regionSummary.Gain_Max_dB(k) = ...
        max(Gain(idx));

    regionSummary.VCE_Median_V(k) = ...
        median(VCE(idx));

    regionSummary.VCE_Min_V(k) = ...
        min(VCE(idx));

    regionSummary.VCB_Median_V(k) = ...
        median(VCB(idx));

    regionSummary.VCB_Min_V(k) = ...
        min(VCB(idx));

end

fprintf('\n');
fprintf('============================================================\n');
fprintf(' OPERATING POINT BY GAIN REGION\n');
fprintf('============================================================\n');

disp(regionSummary);

%% ============================================================
% MORE DETAILED REGION STATISTICS
% ============================================================

fprintf('\n');
fprintf('Detailed region statistics:\n');

for k = 1:3

    idx = regionIdx{k};

    fprintf('\n%s region:\n',regionNames(k));

    fprintf('  VCE median = %.6f V\n', ...
        median(VCE(idx)));

    fprintf('  VCE 10%%    = %.6f V\n', ...
        prctile(VCE(idx),10));

    fprintf('  VCE min    = %.6f V\n', ...
        min(VCE(idx)));

    fprintf('  VCB median = %.6f V\n', ...
        median(VCB(idx)));

    fprintf('  VCB 10%%    = %.6f V\n', ...
        prctile(VCB(idx),10));

    fprintf('  VCB min    = %.6f V\n', ...
        min(VCB(idx)));

    fprintf('  IC median  = %.6e A\n', ...
        median(IC(idx)));

    fprintf('  IC 10%%     = %.6e A\n', ...
        prctile(IC(idx),10));

    fprintf('  IC min     = %.6e A\n', ...
        min(IC(idx)));

end

%% ============================================================
% CANDIDATE CONSTRAINT ANALYSIS
% ============================================================
%
% We examine several possible lower bounds.
%
% These are NOT yet accepted constraints.
%
% Candidate VCE:
%   0.5 V
%   0.6 V
%   0.7 V
%   1.0 V
%
% Candidate VCB:
%   0.05 V
%   0.10 V
%   0.20 V
%   0.50 V
%
% Candidate IC:
%   50 uA
%   100 uA
%   200 uA
%   500 uA
%
% For each threshold we report:
%   - number of existing valid circuits retained
%   - percentage retained
%   - maximum gain retained
%   - median gain retained
%
% This tells us how restrictive each candidate would be.

%% ------------------------------------------------------------
% VCE candidates
% ------------------------------------------------------------

VCE_candidates = [ ...
    0.50 ...
    0.60 ...
    0.70 ...
    1.00 ...
    1.50 ...
    2.00];

VCE_candidate_summary = table( ...
    VCE_candidates(:), ...
    zeros(numel(VCE_candidates),1), ...
    zeros(numel(VCE_candidates),1), ...
    NaN(numel(VCE_candidates),1), ...
    NaN(numel(VCE_candidates),1), ...
    'VariableNames',{ ...
    'VCE_Min_V', ...
    'Retained_Count', ...
    'Retained_Percent', ...
    'Max_Gain_dB', ...
    'Median_Gain_dB'});

for k = 1:numel(VCE_candidates)

    threshold = VCE_candidates(k);

    idx = VCE >= threshold;

    VCE_candidate_summary.Retained_Count(k) = sum(idx);

    VCE_candidate_summary.Retained_Percent(k) = ...
        100*sum(idx)/Nvalid;

    if any(idx)

        VCE_candidate_summary.Max_Gain_dB(k) = ...
            max(Gain(idx));

        VCE_candidate_summary.Median_Gain_dB(k) = ...
            median(Gain(idx));

    end

end

%% ------------------------------------------------------------
% VCB candidates
% ------------------------------------------------------------

VCB_candidates = [ ...
    0.05 ...
    0.10 ...
    0.20 ...
    0.50 ...
    1.00];

VCB_candidate_summary = table( ...
    VCB_candidates(:), ...
    zeros(numel(VCB_candidates),1), ...
    zeros(numel(VCB_candidates),1), ...
    NaN(numel(VCB_candidates),1), ...
    NaN(numel(VCB_candidates),1), ...
    'VariableNames',{ ...
    'VCB_Min_V', ...
    'Retained_Count', ...
    'Retained_Percent', ...
    'Max_Gain_dB', ...
    'Median_Gain_dB'});

for k = 1:numel(VCB_candidates)

    threshold = VCB_candidates(k);

    idx = VCB >= threshold;

    VCB_candidate_summary.Retained_Count(k) = sum(idx);

    VCB_candidate_summary.Retained_Percent(k) = ...
        100*sum(idx)/Nvalid;

    if any(idx)

        VCB_candidate_summary.Max_Gain_dB(k) = ...
            max(Gain(idx));

        VCB_candidate_summary.Median_Gain_dB(k) = ...
            median(Gain(idx));

    end

end

%% ------------------------------------------------------------
% IC candidates
% ------------------------------------------------------------

IC_candidates = [ ...
    50e-6 ...
    100e-6 ...
    200e-6 ...
    500e-6 ...
    1e-3 ...
    2e-3];

IC_candidate_summary = table( ...
    IC_candidates(:), ...
    zeros(numel(IC_candidates),1), ...
    zeros(numel(IC_candidates),1), ...
    NaN(numel(IC_candidates),1), ...
    NaN(numel(IC_candidates),1), ...
    'VariableNames',{ ...
    'IC_Min_A', ...
    'Retained_Count', ...
    'Retained_Percent', ...
    'Max_Gain_dB', ...
    'Median_Gain_dB'});

for k = 1:numel(IC_candidates)

    threshold = IC_candidates(k);

    idx = IC >= threshold;

    IC_candidate_summary.Retained_Count(k) = sum(idx);

    IC_candidate_summary.Retained_Percent(k) = ...
        100*sum(idx)/Nvalid;

    if any(idx)

        IC_candidate_summary.Max_Gain_dB(k) = ...
            max(Gain(idx));

        IC_candidate_summary.Median_Gain_dB(k) = ...
            median(Gain(idx));

    end

end

%% ============================================================
% DISPLAY CANDIDATE CONSTRAINT RESULTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' VCE CANDIDATE CONSTRAINTS\n');
fprintf('============================================================\n');

disp(VCE_candidate_summary);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' VCB CANDIDATE CONSTRAINTS\n');
fprintf('============================================================\n');

disp(VCB_candidate_summary);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' IC CANDIDATE CONSTRAINTS\n');
fprintf('============================================================\n');

disp(IC_candidate_summary);

%% ============================================================
% COMBINED CONSTRAINT ANALYSIS
% ============================================================
%
% Examine combinations of candidate VCE and VCB constraints.
%
% This is particularly important because both quantities describe
% how far the transistor is from the saturation boundary.

combined_VCE = [0.5 0.7 1.0];

combined_VCB = [0.05 0.10 0.20 0.50];

combinedRows = [];

for i = 1:numel(combined_VCE)

    for j = 1:numel(combined_VCB)

        vceMin = combined_VCE(i);
        vcbMin = combined_VCB(j);

        idx = ...
            VCE >= vceMin & ...
            VCB >= vcbMin;

        row = [ ...
            vceMin, ...
            vcbMin, ...
            sum(idx), ...
            100*sum(idx)/Nvalid];

        if any(idx)

            row = [ ...
                row, ...
                max(Gain(idx)), ...
                median(Gain(idx))];

        else

            row = [ ...
                row, ...
                NaN, ...
                NaN];

        end

        combinedRows = [combinedRows;row]; %#ok<AGROW>

    end

end

combinedConstraintSummary = array2table( ...
    combinedRows, ...
    'VariableNames',{ ...
    'VCE_Min_V', ...
    'VCB_Min_V', ...
    'Retained_Count', ...
    'Retained_Percent', ...
    'Max_Gain_dB', ...
    'Median_Gain_dB'});

fprintf('\n');
fprintf('============================================================\n');
fprintf(' COMBINED VCE + VCB CONSTRAINT ANALYSIS\n');
fprintf('============================================================\n');

disp(combinedConstraintSummary);

%% ============================================================
% HIGH-GAIN SAFETY ANALYSIS
% ============================================================
%
% Analyze the top 10% gain circuits.
%
% This tells us whether high gain tends to push the transistor
% toward low VCE / low VCB / extreme IC.

highGainThreshold = prctile(Gain,90);

topGainIdx = Gain >= highGainThreshold;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' TOP 10%% GAIN OPERATING-POINT ANALYSIS\n');
fprintf('============================================================\n');

fprintf('\nHigh-gain threshold = %.6f dB\n', ...
    highGainThreshold);

fprintf('Number of high-gain circuits = %d\n', ...
    sum(topGainIdx));

fprintf('\nHigh-gain VCE:\n');
fprintf('  Min    = %.6f V\n',min(VCE(topGainIdx)));
fprintf('  5%%     = %.6f V\n',prctile(VCE(topGainIdx),5));
fprintf('  Median = %.6f V\n',median(VCE(topGainIdx)));

fprintf('\nHigh-gain VCB:\n');
fprintf('  Min    = %.6f V\n',min(VCB(topGainIdx)));
fprintf('  5%%     = %.6f V\n',prctile(VCB(topGainIdx),5));
fprintf('  Median = %.6f V\n',median(VCB(topGainIdx)));

fprintf('\nHigh-gain IC:\n');
fprintf('  Min    = %.6e A\n',min(IC(topGainIdx)));
fprintf('  5%%     = %.6e A\n',prctile(IC(topGainIdx),5));
fprintf('  Median = %.6e A\n',median(IC(topGainIdx)));

%% ============================================================
% IDENTIFY LOW-MARGIN HIGH-GAIN CIRCUITS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' HIGH-GAIN / LOW-MARGIN CIRCUITS\n');
fprintf('============================================================\n');

% Define descriptive low-margin regions.
%
% These are NOT proposed final constraints.
% They are simply used to locate interesting circuits.

lowVCE_idx = VCE < 1.0;

lowVCB_idx = VCB < 0.5;

highGain_lowVCE = ...
    topGainIdx & lowVCE_idx;

highGain_lowVCB = ...
    topGainIdx & lowVCB_idx;

fprintf('\nHigh-gain circuits with VCE < 1.0 V: %d\n', ...
    sum(highGain_lowVCE));

fprintf('High-gain circuits with VCB < 0.5 V: %d\n', ...
    sum(highGain_lowVCB));

if any(highGain_lowVCE)

    fprintf('\nGain range for high-gain + low-VCE group:\n');
    fprintf('  Min = %.6f dB\n',min(Gain(highGain_lowVCE)));
    fprintf('  Max = %.6f dB\n',max(Gain(highGain_lowVCE)));

end

if any(highGain_lowVCB)

    fprintf('\nGain range for high-gain + low-VCB group:\n');
    fprintf('  Min = %.6f dB\n',min(Gain(highGain_lowVCB)));
    fprintf('  Max = %.6f dB\n',max(Gain(highGain_lowVCB)));

end

%% ============================================================
% FIND HIGHEST-GAIN CIRCUITS
% ============================================================

[~,sortIdx] = sort(Gain,'descend');

topN = min(10,Nvalid);

topRows = Tv(sortIdx(1:topN),:);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' TOP 10 HIGHEST-GAIN CIRCUITS\n');
fprintf('============================================================\n');

displayColumns = { ...
    'Gain_dB', ...
    'VCE', ...
    'VCB', ...
    'IC', ...
    'VB', ...
    'VE', ...
    'VC', ...
    'VCC'};

disp(topRows(:,displayColumns));

%% ============================================================
% PLOT 1 - GAIN VS VCE
% ============================================================

fig = figure( ...
    'Name','Gain vs VCE', ...
    'NumberTitle','off');

scatter( ...
    VCE, ...
    Gain, ...
    28, ...
    'filled');

xlabel('V_{CE} (V)');
ylabel('Gain (dB)');
title('SPICE Gain vs V_{CE}');
grid on;

saveas( ...
    fig, ...
    fullfile(figureDir,'Gain_vs_VCE.png'));

%% ============================================================
% PLOT 2 - GAIN VS VCB
% ============================================================

fig = figure( ...
    'Name','Gain vs VCB', ...
    'NumberTitle','off');

scatter( ...
    VCB, ...
    Gain, ...
    28, ...
    'filled');

xlabel('V_{CB} (V)');
ylabel('Gain (dB)');
title('SPICE Gain vs V_{CB}');
grid on;

saveas( ...
    fig, ...
    fullfile(figureDir,'Gain_vs_VCB.png'));

%% ============================================================
% PLOT 3 - GAIN VS IC
% ============================================================

fig = figure( ...
    'Name','Gain vs IC', ...
    'NumberTitle','off');

scatter( ...
    IC, ...
    Gain, ...
    28, ...
    'filled');

set(gca,'XScale','log');

xlabel('I_C (A)');
ylabel('Gain (dB)');
title('SPICE Gain vs I_C');
grid on;

saveas( ...
    fig, ...
    fullfile(figureDir,'Gain_vs_IC.png'));

%% ============================================================
% PLOT 4 - VCE DISTRIBUTION
% ============================================================

fig = figure( ...
    'Name','VCE Distribution', ...
    'NumberTitle','off');

histogram(VCE,30);

xlabel('V_{CE} (V)');
ylabel('Number of circuits');
title('SPICE V_{CE} Distribution');
grid on;

saveas( ...
    fig, ...
    fullfile(figureDir,'VCE_Distribution.png'));

%% ============================================================
% PLOT 5 - VCB DISTRIBUTION
% ============================================================

fig = figure( ...
    'Name','VCB Distribution', ...
    'NumberTitle','off');

histogram(VCB,30);

xlabel('V_{CB} (V)');
ylabel('Number of circuits');
title('SPICE V_{CB} Distribution');
grid on;

saveas( ...
    fig, ...
    fullfile(figureDir,'VCB_Distribution.png'));

%% ============================================================
% PLOT 6 - IC DISTRIBUTION
% ============================================================

fig = figure( ...
    'Name','IC Distribution', ...
    'NumberTitle','off');

histogram(IC,30);

set(gca,'XScale','log');

xlabel('I_C (A)');
ylabel('Number of circuits');
title('SPICE I_C Distribution');
grid on;

saveas( ...
    fig, ...
    fullfile(figureDir,'IC_Distribution.png'));

%% ============================================================
% PLOT 7 - GAIN VS VCE / VCB RELATION
% ============================================================

fig = figure( ...
    'Name','Gain Operating Point Summary', ...
    'NumberTitle','off');

scatter3( ...
    VCE, ...
    VCB, ...
    Gain, ...
    28, ...
    'filled');

xlabel('V_{CE} (V)');
ylabel('V_{CB} (V)');
zlabel('Gain (dB)');
title('Gain Surface in SPICE Operating-Point Space');
grid on;
view(45,30);

saveas( ...
    fig, ...
    fullfile(figureDir,'Gain_VCE_VCB_3D.png'));

%% ============================================================
% SAVE RESULTS
% ============================================================

auditResults = struct();

auditResults.inputFile = inputCSV;

auditResults.N_total = height(T);

auditResults.N_valid = Nvalid;

auditResults.gainStatistics = struct( ...
    'min',min(Gain), ...
    'p1',prctile(Gain,1), ...
    'p5',prctile(Gain,5), ...
    'median',median(Gain), ...
    'p95',prctile(Gain,95), ...
    'p99',prctile(Gain,99), ...
    'max',max(Gain));

auditResults.VCE_statistics = struct( ...
    'min',min(VCE), ...
    'p1',prctile(VCE,1), ...
    'p5',prctile(VCE,5), ...
    'p10',prctile(VCE,10), ...
    'median',median(VCE), ...
    'p90',prctile(VCE,90), ...
    'p95',prctile(VCE,95), ...
    'p99',prctile(VCE,99), ...
    'max',max(VCE));

auditResults.VCB_statistics = struct( ...
    'min',min(VCB), ...
    'p1',prctile(VCB,1), ...
    'p5',prctile(VCB,5), ...
    'p10',prctile(VCB,10), ...
    'median',median(VCB), ...
    'p90',prctile(VCB,90), ...
    'p95',prctile(VCB,95), ...
    'p99',prctile(VCB,99), ...
    'max',max(VCB));

auditResults.IC_statistics = struct( ...
    'min',min(IC), ...
    'p1',prctile(IC,1), ...
    'p5',prctile(IC,5), ...
    'p10',prctile(IC,10), ...
    'median',median(IC), ...
    'p90',prctile(IC,90), ...
    'p95',prctile(IC,95), ...
    'p99',prctile(IC,99), ...
    'max',max(IC));

auditResults.correlation = struct( ...
    'Gain_VCE_Spearman',rhoVCE, ...
    'Gain_VCB_Spearman',rhoVCB, ...
    'Gain_IC_Spearman',rhoIC, ...
    'Gain_VB_Spearman',rhoVB, ...
    'Gain_VE_Spearman',rhoVE, ...
    'Gain_VC_Spearman',rhoVC);

auditResults.gainThresholds = struct( ...
    'Q25',q25, ...
    'Q75',q75, ...
    'Q90',highGainThreshold);

auditResults.regionSummary = regionSummary;

auditResults.VCE_candidate_summary = ...
    VCE_candidate_summary;

auditResults.VCB_candidate_summary = ...
    VCB_candidate_summary;

auditResults.IC_candidate_summary = ...
    IC_candidate_summary;

auditResults.combinedConstraintSummary = ...
    combinedConstraintSummary;

auditResults.highGainAnalysis = struct( ...
    'threshold',highGainThreshold, ...
    'count',sum(topGainIdx), ...
    'VCE_min',min(VCE(topGainIdx)), ...
    'VCE_p5',prctile(VCE(topGainIdx),5), ...
    'VCE_median',median(VCE(topGainIdx)), ...
    'VCB_min',min(VCB(topGainIdx)), ...
    'VCB_p5',prctile(VCB(topGainIdx),5), ...
    'VCB_median',median(VCB(topGainIdx)), ...
    'IC_min',min(IC(topGainIdx)), ...
    'IC_p5',prctile(IC(topGainIdx),5), ...
    'IC_median',median(IC(topGainIdx)));

%% ============================================================
% SAVE MAT
% ============================================================

outputMAT = fullfile( ...
    outputDir, ...
    'Step8C_OperatingPoint_Constraint_Audit.mat');

save( ...
    outputMAT, ...
    'auditResults', ...
    'regionSummary', ...
    'VCE_candidate_summary', ...
    'VCB_candidate_summary', ...
    'IC_candidate_summary', ...
    'combinedConstraintSummary');

fprintf('\n');
fprintf('[PASS] MAT results saved:\n%s\n',outputMAT);

%% ============================================================
% SAVE CSV TABLES
% ============================================================

writetable( ...
    regionSummary, ...
    fullfile(outputDir,'Gain_Region_OperatingPoint_Summary.csv'));

writetable( ...
    VCE_candidate_summary, ...
    fullfile(outputDir,'VCE_Candidate_Constraints.csv'));

writetable( ...
    VCB_candidate_summary, ...
    fullfile(outputDir,'VCB_Candidate_Constraints.csv'));

writetable( ...
    IC_candidate_summary, ...
    fullfile(outputDir,'IC_Candidate_Constraints.csv'));

writetable( ...
    combinedConstraintSummary, ...
    fullfile(outputDir,'Combined_VCE_VCB_Constraints.csv'));

fprintf('[PASS] CSV summaries saved.\n');

%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8C FINAL STATUS\n');
fprintf('============================================================\n');

fprintf('[PASS] 660-row SPICE operating-point dataset analyzed.\n');
fprintf('[PASS] VCE distribution analyzed.\n');
fprintf('[PASS] VCB distribution analyzed.\n');
fprintf('[PASS] IC distribution analyzed.\n');
fprintf('[PASS] Gain relationships analyzed.\n');
fprintf('[PASS] Candidate constraints evaluated.\n');
fprintf('[PASS] No optimizer constraints were changed.\n');

fprintf('\n');
fprintf('IMPORTANT:\n');
fprintf('Candidate thresholds are NOT yet accepted as final\n');
fprintf('optimization constraints. They require physical review\n');
fprintf('before being incorporated into fmincon.\n');

fprintf('\nOutput directory:\n%s\n',outputDir);

fprintf('\n============================================================\n');
fprintf(' STEP 8C COMPLETE\n');
fprintf('============================================================\n');
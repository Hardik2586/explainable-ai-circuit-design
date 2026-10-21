%% STEP 7D - ROBUSTNESS ANALYSIS
% Explainable AI Framework for CE Amplifier
%
% IMPORTANT:
% No new SPICE simulations are performed.
% This script analyzes the 300 simulations from Step 7C.

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7D - ROBUSTNESS ANALYSIS\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

robustnessDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'robustness');

resultFile = fullfile( ...
    robustnessDir, ...
    'Robustness_SPICE_Results.mat');

summaryFile = fullfile( ...
    robustnessDir, ...
    'Robustness_Summary.csv');

if ~isfile(resultFile)

    error( ...
        'Robustness result file not found:\n%s', ...
        resultFile);

end

fprintf('\n[PASS] Robustness result file found.\n');

%% ============================================================
% LOAD RESULTS
% ============================================================

D = load(resultFile);

requiredFields = { ...
    'robustness', ...
    'summary', ...
    'featureNames', ...
    'N', ...
    'resistorTol', ...
    'capacitorTol', ...
    'vccTol'};

for k = 1:numel(requiredFields)

    if ~isfield(D,requiredFields{k})

        error( ...
            'Missing field in robustness result file: %s', ...
            requiredFields{k});

    end

end

robustness = D.robustness;
summaryOld = D.summary;

N = D.N;

resistorTol = D.resistorTol;
capacitorTol = D.capacitorTol;
vccTol = D.vccTol;

featureNames = D.featureNames;

fprintf('[PASS] Robustness result structure loaded.\n');

%% ============================================================
% BASIC EXPERIMENT CHECK
% ============================================================

circuitNames = {'Low','Medium','High'};

fprintf('\nExperiment configuration:\n');
fprintf('Samples per circuit = %d\n',N);
fprintf('Total expected runs = %d\n',3*N);
fprintf('Resistor tolerance  = +/- %.1f %%\n',100*resistorTol);
fprintf('Capacitor tolerance = +/- %.1f %%\n',100*capacitorTol);
fprintf('VCC tolerance       = +/- %.1f %%\n',100*vccTol);

%% ============================================================
% ANALYZE EACH CIRCUIT
% ============================================================

analysis = struct();

for c = 1:numel(circuitNames)

    caseName = circuitNames{c};

    R = robustness.(caseName);

    %% --------------------------------------------------------
    % Successful simulations
    % ---------------------------------------------------------

    successful = logical(R.success);

    valid = logical(R.valid);

    gains = R.gain_dB(successful);

    delta = R.deltaGain_dB(successful);

    validSuccessful = valid(successful);

    %% --------------------------------------------------------
    % Basic counts
    % ---------------------------------------------------------

    nSuccessful = sum(successful);

    nFailed = N - nSuccessful;

    nValid = sum(validSuccessful);

    nInvalid = nSuccessful - nValid;

    validityPercent = ...
        100*nValid/N;

    simulationSuccessPercent = ...
        100*nSuccessful/N;

    %% --------------------------------------------------------
    % Gain statistics
    % ---------------------------------------------------------

    meanGain = mean(gains);

    medianGain = median(gains);

    stdGain = std(gains);

    minGain = min(gains);

    maxGain = max(gains);

    %% --------------------------------------------------------
    % Delta gain statistics
    % ---------------------------------------------------------

    meanDelta = mean(delta);

    stdDelta = std(delta);

    minDelta = min(delta);

    maxDelta = max(delta);

    %% --------------------------------------------------------
    % Worst absolute deviation
    % ---------------------------------------------------------

    absDelta = abs(delta);

    maxAbsDelta = max(absDelta);

    meanAbsDelta = mean(absDelta);

    medianAbsDelta = median(absDelta);

    %% --------------------------------------------------------
    % Coefficient of variation
    % ---------------------------------------------------------

    coefficientVariation = ...
        100*stdGain/meanGain;

    %% --------------------------------------------------------
    % Store
    % ---------------------------------------------------------

    analysis.(caseName).nominalGain_dB = ...
        R.nominalGain_dB;

    analysis.(caseName).successfulRuns = ...
        nSuccessful;

    analysis.(caseName).failedRuns = ...
        nFailed;

    analysis.(caseName).validRuns = ...
        nValid;

    analysis.(caseName).invalidRuns = ...
        nInvalid;

    analysis.(caseName).simulationSuccessPercent = ...
        simulationSuccessPercent;

    analysis.(caseName).validityPercent = ...
        validityPercent;

    analysis.(caseName).meanGain_dB = ...
        meanGain;

    analysis.(caseName).medianGain_dB = ...
        medianGain;

    analysis.(caseName).stdGain_dB = ...
        stdGain;

    analysis.(caseName).minGain_dB = ...
        minGain;

    analysis.(caseName).maxGain_dB = ...
        maxGain;

    analysis.(caseName).meanDeltaGain_dB = ...
        meanDelta;

    analysis.(caseName).stdDeltaGain_dB = ...
        stdDelta;

    analysis.(caseName).minDeltaGain_dB = ...
        minDelta;

    analysis.(caseName).maxDeltaGain_dB = ...
        maxDelta;

    analysis.(caseName).meanAbsDeltaGain_dB = ...
        meanAbsDelta;

    analysis.(caseName).medianAbsDeltaGain_dB = ...
        medianAbsDelta;

    analysis.(caseName).maxAbsDeltaGain_dB = ...
        maxAbsDelta;

    analysis.(caseName).coefficientVariation_percent = ...
        coefficientVariation;

end

%% ============================================================
% CREATE FINAL ANALYSIS TABLE
% ============================================================

Circuit = string(circuitNames(:));

NominalGain_dB = zeros(3,1);
SuccessfulRuns = zeros(3,1);
FailedRuns = zeros(3,1);
ValidRuns = zeros(3,1);
InvalidRuns = zeros(3,1);
ValidityPercent = zeros(3,1);

MeanGain_dB = zeros(3,1);
MedianGain_dB = zeros(3,1);
StdGain_dB = zeros(3,1);
MinGain_dB = zeros(3,1);
MaxGain_dB = zeros(3,1);

MeanDeltaGain_dB = zeros(3,1);
StdDeltaGain_dB = zeros(3,1);
MinDeltaGain_dB = zeros(3,1);
MaxDeltaGain_dB = zeros(3,1);

MeanAbsDeltaGain_dB = zeros(3,1);
MedianAbsDeltaGain_dB = zeros(3,1);
MaxAbsDeltaGain_dB = zeros(3,1);

CoefficientVariation_percent = zeros(3,1);

for c = 1:3

    name = circuitNames{c};
    A = analysis.(name);

    NominalGain_dB(c) = A.nominalGain_dB;
    SuccessfulRuns(c) = A.successfulRuns;
    FailedRuns(c) = A.failedRuns;
    ValidRuns(c) = A.validRuns;
    InvalidRuns(c) = A.invalidRuns;
    ValidityPercent(c) = A.validityPercent;

    MeanGain_dB(c) = A.meanGain_dB;
    MedianGain_dB(c) = A.medianGain_dB;
    StdGain_dB(c) = A.stdGain_dB;
    MinGain_dB(c) = A.minGain_dB;
    MaxGain_dB(c) = A.maxGain_dB;

    MeanDeltaGain_dB(c) = A.meanDeltaGain_dB;
    StdDeltaGain_dB(c) = A.stdDeltaGain_dB;
    MinDeltaGain_dB(c) = A.minDeltaGain_dB;
    MaxDeltaGain_dB(c) = A.maxDeltaGain_dB;

    MeanAbsDeltaGain_dB(c) = A.meanAbsDeltaGain_dB;
    MedianAbsDeltaGain_dB(c) = A.medianAbsDeltaGain_dB;
    MaxAbsDeltaGain_dB(c) = A.maxAbsDeltaGain_dB;

    CoefficientVariation_percent(c) = ...
        A.coefficientVariation_percent;

end

finalTable = table( ...
    Circuit, ...
    NominalGain_dB, ...
    SuccessfulRuns, ...
    FailedRuns, ...
    ValidRuns, ...
    InvalidRuns, ...
    ValidityPercent, ...
    MeanGain_dB, ...
    MedianGain_dB, ...
    StdGain_dB, ...
    MinGain_dB, ...
    MaxGain_dB, ...
    MeanDeltaGain_dB, ...
    StdDeltaGain_dB, ...
    MinDeltaGain_dB, ...
    MaxDeltaGain_dB, ...
    MeanAbsDeltaGain_dB, ...
    MedianAbsDeltaGain_dB, ...
    MaxAbsDeltaGain_dB, ...
    CoefficientVariation_percent);

%% ============================================================
% ROBUSTNESS RANKING
% ============================================================
%
% Lower gain standard deviation = more robust.

[~,rankOrder] = sort(StdGain_dB,'ascend');

RobustnessRank = zeros(3,1);

for rank = 1:3

    RobustnessRank(rankOrder(rank)) = rank;

end

finalTable.RobustnessRank = RobustnessRank;

%% ============================================================
% DISPLAY RESULTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FINAL ROBUSTNESS ANALYSIS\n');
fprintf('============================================================\n');

disp(finalTable);

%% ============================================================
% PRINT INTERPRETATION METRICS
% ============================================================

fprintf('\nKey robustness metrics:\n\n');

for c = 1:3

    name = circuitNames{c};
    A = analysis.(name);

    fprintf('%s-Gain:\n',name);

    fprintf('  Nominal gain          = %.4f dB\n', ...
        A.nominalGain_dB);

    fprintf('  Mean gain             = %.4f dB\n', ...
        A.meanGain_dB);

    fprintf('  Gain std              = %.4f dB\n', ...
        A.stdGain_dB);

    fprintf('  Gain range            = %.4f to %.4f dB\n', ...
        A.minGain_dB,A.maxGain_dB);

    fprintf('  Mean |Delta gain|     = %.4f dB\n', ...
        A.meanAbsDeltaGain_dB);

    fprintf('  Worst |Delta gain|    = %.4f dB\n', ...
        A.maxAbsDeltaGain_dB);

    fprintf('  Coefficient variation = %.3f %%\n', ...
        A.coefficientVariation_percent);

    fprintf('  Physical validity     = %.1f %%\n', ...
        A.validityPercent);

    fprintf('\n');

end

%% ============================================================
% ROBUSTNESS RANKING
% ============================================================

fprintf('============================================================\n');
fprintf(' ROBUSTNESS RANKING\n');
fprintf('============================================================\n');

[~,sortedIdx] = sort(StdGain_dB,'ascend');

for rank = 1:3

    idx = sortedIdx(rank);

    fprintf('%d. %s-Gain | Std = %.4f dB | CV = %.3f %%\n', ...
        rank, ...
        circuitNames{idx}, ...
        StdGain_dB(idx), ...
        CoefficientVariation_percent(idx));

end

%% ============================================================
% GLOBAL CHECKS
% ============================================================

totalSuccessful = sum(SuccessfulRuns);
totalValid = sum(ValidRuns);
totalInvalid = sum(InvalidRuns);

expectedRuns = 3*N;

allSuccessful = ...
    totalSuccessful == expectedRuns;

allPhysicallyValid = ...
    totalValid == expectedRuns;

noInvalid = ...
    totalInvalid == 0;

fprintf('\n============================================================\n');
fprintf(' ROBUSTNESS VALIDATION CHECKS\n');
fprintf('============================================================\n');

fprintf('Expected simulations : %d\n',expectedRuns);
fprintf('Successful           : %d\n',totalSuccessful);
fprintf('Physically valid     : %d\n',totalValid);
fprintf('Invalid               : %d\n',totalInvalid);

if allSuccessful
    fprintf('[PASS] All 300 SPICE simulations succeeded.\n');
else
    fprintf('[FAIL] Not all SPICE simulations succeeded.\n');
end

if allPhysicallyValid
    fprintf('[PASS] All 300 samples were physically valid.\n');
else
    fprintf('[WARN] Some samples were physically invalid.\n');
end

if noInvalid
    fprintf('[PASS] Zero invalid robustness samples.\n');
else
    fprintf('[WARN] Invalid robustness samples detected.\n');
end

%% ============================================================
% SAVE ANALYSIS RESULTS
% ============================================================

analysisFile = fullfile( ...
    robustnessDir, ...
    'Robustness_Analysis_Results.mat');

analysisCSV = fullfile( ...
    robustnessDir, ...
    'Robustness_Final_Analysis.csv');

save( ...
    analysisFile, ...
    'analysis', ...
    'finalTable', ...
    'RobustnessRank', ...
    'N', ...
    'resistorTol', ...
    'capacitorTol', ...
    'vccTol');

writetable( ...
    finalTable, ...
    analysisCSV);

fprintf('\nAnalysis saved to:\n%s\n',analysisFile);
fprintf('CSV saved to:\n%s\n',analysisCSV);

%% ============================================================
% FIGURE 1 - GAIN RANGE
% ============================================================

figure;

hold on;

for c = 1:3

    errorbar( ...
        c, ...
        MeanGain_dB(c), ...
        MeanGain_dB(c)-MinGain_dB(c), ...
        MaxGain_dB(c)-MeanGain_dB(c), ...
        'o', ...
        'LineWidth',1.5, ...
        'MarkerSize',8);

end

plot( ...
    1:3, ...
    NominalGain_dB, ...
    'kx', ...
    'MarkerSize',10, ...
    'LineWidth',2);

set(gca, ...
    'XTick',1:3, ...
    'XTickLabel',circuitNames);

xlabel('Optimized Circuit');
ylabel('Gain (dB)');

title( ...
    'Gain Range Under Component and Supply Tolerances');

legend( ...
    'Mean and Min/Max Range', ...
    'Nominal Gain', ...
    'Location','best');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
        robustnessDir, ...
        'Final_Gain_Range.png'));

%% ============================================================
% FIGURE 2 - STANDARD DEVIATION
% ============================================================

figure;

bar(StdGain_dB);

set(gca, ...
    'XTickLabel',circuitNames);

xlabel('Optimized Circuit');
ylabel('Gain Standard Deviation (dB)');

title( ...
    'Gain Variability Under Component Tolerances');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
        robustnessDir, ...
        'Final_Gain_Std.png'));

%% ============================================================
% FIGURE 3 - COEFFICIENT OF VARIATION
% ============================================================

figure;

bar(CoefficientVariation_percent);

set(gca, ...
    'XTickLabel',circuitNames);

xlabel('Optimized Circuit');
ylabel('Coefficient of Variation (%)');

title( ...
    'Normalized Gain Variability');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
        robustnessDir, ...
        'Final_Robustness_CV.png'));

%% ============================================================
% FIGURE 4 - VALIDITY
% ============================================================

figure;

bar(ValidityPercent);

set(gca, ...
    'XTickLabel',circuitNames);

xlabel('Optimized Circuit');
ylabel('Physically Valid Samples (%)');

title( ...
    'Physical Validity Under Component Tolerances');

ylim([0 105]);

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
        robustnessDir, ...
        'Final_Physical_Validity.png'));

%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7D COMPLETE\n');
fprintf('============================================================\n');

if allSuccessful && allPhysicallyValid

    fprintf('\n[PASS] Robustness analysis fully validated.\n');
    fprintf('[PASS] 300/300 SPICE simulations successful.\n');
    fprintf('[PASS] 300/300 physically valid.\n');

else

    fprintf('\n[WARN] Review robustness validation results.\n');

end

fprintf('\nNo new SPICE simulations were performed by Step 7D.\n');
fprintf('Only the existing Step 7C results were analyzed.\n');
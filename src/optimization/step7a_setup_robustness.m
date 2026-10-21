%% STEP 7A - ROBUSTNESS SETUP TEST
% Explainable AI Framework for CE Amplifier
%
% Purpose:
%   1. Load the existing optimized designs
%   2. Verify the three xOpt vectors
%   3. Verify runSpice is accessible
%   4. Run ONE perturbed SPICE simulation per circuit
%
% No large robustness experiment is performed here.

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7A - ROBUSTNESS SETUP TEST\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% =============================================================

projectRoot = 'C:\Internship Project';

optimizationFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_fmincon_Optimization_Results.mat');

spiceDir = fullfile( ...
    projectRoot, ...
    'src', ...
    'spice');

fprintf('\nOptimization file:\n%s\n', optimizationFile);
fprintf('\nSPICE source directory:\n%s\n', spiceDir);

%% ============================================================
% CHECK FILE
% =============================================================

if ~isfile(optimizationFile)

    error('Optimization result file not found:\n%s', ...
        optimizationFile);

end

fprintf('\n[PASS] Optimization result file found.\n');

%% ============================================================
% LOAD OPTIMIZATION RESULTS
% ============================================================

O = load(optimizationFile);

fprintf('\nOptimization result variables:\n');
disp(fieldnames(O));

%% ============================================================
% IDENTIFY CIRCUIT RESULTS
% ============================================================

requiredCases = {'Low','Medium','High'};

for k = 1:numel(requiredCases)

    caseName = requiredCases{k};

    if ~isfield(O.optimizationResults,caseName)

        error('Missing optimization result for case: %s', ...
            caseName);

    end

end

fprintf('[PASS] Low, Medium and High optimization results found.\n');

%% ============================================================
% EXTRACT OPTIMIZED DESIGNS
% ============================================================

R = O.optimizationResults;

xLow    = R.Low.xOpt;
xMedium = R.Medium.xOpt;
xHigh   = R.High.xOpt;

fprintf('\nOptimized design sizes:\n');
fprintf('Low    = %d variables\n',numel(xLow));
fprintf('Medium = %d variables\n',numel(xMedium));
fprintf('High   = %d variables\n',numel(xHigh));

%% ============================================================
% VERIFY DESIGN DIMENSIONS
% ============================================================

assert(numel(xLow) == 9, ...
    'Low optimized design must contain 9 variables.');

assert(numel(xMedium) == 9, ...
    'Medium optimized design must contain 9 variables.');

assert(numel(xHigh) == 9, ...
    'High optimized design must contain 9 variables.');

fprintf('[PASS] All optimized designs contain 9 variables.\n');

%% ============================================================
% FEATURE ORDER
% ============================================================

featureNames = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};

fprintf('\nFeature order:\n');

for k = 1:numel(featureNames)

    fprintf('%d. %s\n',k,featureNames{k});

end

%% ============================================================
% DISPLAY OPTIMIZED DESIGNS
% ============================================================

fprintf('\n============================================================\n');
fprintf(' OPTIMIZED DESIGNS\n');
fprintf('============================================================\n');

for k = 1:9

    fprintf('%-5s | Low = %.10g | Medium = %.10g | High = %.10g\n', ...
        featureNames{k}, ...
        xLow(k), ...
        xMedium(k), ...
        xHigh(k));

end

%% ============================================================
% FINITE VALUE CHECK
% ============================================================

finiteLow = all(isfinite(xLow));
finiteMedium = all(isfinite(xMedium));
finiteHigh = all(isfinite(xHigh));

fprintf('\nFinite value checks:\n');
fprintf('Low    : %d\n',finiteLow);
fprintf('Medium : %d\n',finiteMedium);
fprintf('High   : %d\n',finiteHigh);

assert(finiteLow && finiteMedium && finiteHigh, ...
    'One or more optimized designs contain non-finite values.');

fprintf('[PASS] All optimized design values are finite.\n');

%% ============================================================
% CHECK SPICE FUNCTION
% ============================================================

if ~isfolder(spiceDir)

    error('SPICE source directory not found:\n%s',spiceDir);

end

addpath(spiceDir);

fprintf('\nChecking runSpice...\n');

if exist('runSpice','file') ~= 2

    error(['runSpice.m could not be found on the MATLAB path. ' ...
           'Expected location:\n%s'],spiceDir);

end

fprintf('[PASS] runSpice.m is available.\n');

%% ============================================================
% CREATE TEST PERTURBATIONS
% ============================================================

rng(42);

% Resistors: +/- 5%
resistorTol = 0.05;

% Capacitors: +/- 10%
capacitorTol = 0.10;

% Supply: +/- 5%
vccTol = 0.05;

fprintf('\nPerturbation model:\n');
fprintf('Resistors : +/- %.1f %%\n',100*resistorTol);
fprintf('Capacitors: +/- %.1f %%\n',100*capacitorTol);
fprintf('VCC       : +/- %.1f %%\n',100*vccTol);

%% ============================================================
% FUNCTION TO PERTURB DESIGN
% ============================================================

perturbDesign = @(x) [ ...
    x(1) * (1 + resistorTol*(2*rand-1)); ...
    x(2) * (1 + resistorTol*(2*rand-1)); ...
    x(3) * (1 + resistorTol*(2*rand-1)); ...
    x(4) * (1 + resistorTol*(2*rand-1)); ...
    x(5) * (1 + resistorTol*(2*rand-1)); ...
    x(6) * (1 + capacitorTol*(2*rand-1)); ...
    x(7) * (1 + capacitorTol*(2*rand-1)); ...
    x(8) * (1 + capacitorTol*(2*rand-1)); ...
    x(9) * (1 + vccTol*(2*rand-1)) ...
    ];

%% ============================================================
% GENERATE ONE TEST PERTURBATION PER CIRCUIT
% ============================================================

xLowTest = perturbDesign(xLow);
xMediumTest = perturbDesign(xMedium);
xHighTest = perturbDesign(xHigh);

fprintf('\n[PASS] One random perturbation generated for each circuit.\n');

%% ============================================================
% DISPLAY PERTURBATIONS
% ============================================================

fprintf('\n============================================================\n');
fprintf(' SAMPLE PERTURBATION\n');
fprintf('============================================================\n');

fprintf('\nLOW:\n');

for k = 1:9

    fprintf('%-5s: nominal = %.10g   perturbed = %.10g   change = %+7.3f %%\n', ...
        featureNames{k}, ...
        xLow(k), ...
        xLowTest(k), ...
        100*(xLowTest(k)/xLow(k)-1));

end

fprintf('\nMEDIUM:\n');

for k = 1:9

    fprintf('%-5s: nominal = %.10g   perturbed = %.10g   change = %+7.3f %%\n', ...
        featureNames{k}, ...
        xMedium(k), ...
        xMediumTest(k), ...
        100*(xMediumTest(k)/xMedium(k)-1));

end

fprintf('\nHIGH:\n');

for k = 1:9

    fprintf('%-5s: nominal = %.10g   perturbed = %.10g   change = %+7.3f %%\n', ...
        featureNames{k}, ...
        xHigh(k), ...
        xHighTest(k), ...
        100*(xHighTest(k)/xHigh(k)-1));

end

%% ============================================================
% FINAL SETUP CHECK
% ============================================================

fprintf('\n============================================================\n');
fprintf(' STEP 7A STATUS\n');
fprintf('============================================================\n');

fprintf('[PASS] Optimization results loaded.\n');
fprintf('[PASS] Three optimized designs found.\n');
fprintf('[PASS] Each design contains 9 variables.\n');
fprintf('[PASS] All optimized values are finite.\n');
fprintf('[PASS] Feature ordering confirmed.\n');
fprintf('[PASS] runSpice.m is accessible.\n');
fprintf('[PASS] Perturbation generation works.\n');

fprintf('\n============================================================\n');
fprintf(' STEP 7A COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nNo SPICE robustness simulations were executed yet.\n');
fprintf('Next step will test ONE perturbed circuit through SPICE.\n');
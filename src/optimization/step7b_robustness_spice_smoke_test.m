%% STEP 7B - ROBUSTNESS SPICE SMOKE TEST
% Explainable AI Framework for CE Amplifier
%
% Runs exactly ONE perturbed SPICE simulation for each
% optimized circuit.
%
% Total = 3 SPICE simulations.

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7B - ROBUSTNESS SPICE SMOKE TEST\n');
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

addpath(spiceDir);

%% ============================================================
% LOAD OPTIMIZED DESIGNS
% ============================================================

O = load(optimizationFile);
R = O.optimizationResults;

xLow    = R.Low.xOpt(:);
xMedium = R.Medium.xOpt(:);
xHigh   = R.High.xOpt(:);

%% ============================================================
% FEATURE NAMES
% ============================================================

featureNames = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

%% ============================================================
% PERTURBATION SETTINGS
% ============================================================

rng(42);

resistorTol = 0.05;
capacitorTol = 0.10;
vccTol = 0.05;

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
% SPICE OPTIONS
% ============================================================

spiceOptions = struct();

spiceOptions.ngspice_exe = ...
    'C:\ngspice-47_64\bin\ngspice_con.exe';

spiceOptions.model_path = ...
    fullfile(projectRoot,'spice','models','2N3904.lib');

spiceOptions.temperature = 27;
spiceOptions.ac_fstart = 10;
spiceOptions.ac_fstop = 1e9;
spiceOptions.ac_points_per_decade = 20;
spiceOptions.cleanup = false;

%% ============================================================
% GENERATE SAME PERTURBATIONS AS STEP 7A
% ============================================================

xLowTest = perturbDesign(xLow);
xMediumTest = perturbDesign(xMedium);
xHighTest = perturbDesign(xHigh);

Xnom = {xLow,xMedium,xHigh};
Xtest = {xLowTest,xMediumTest,xHighTest};

names = {'Low','Medium','High'};

%% ============================================================
% OUTPUT DIRECTORY
% ============================================================

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'robustness', ...
    'smoke_test');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

%% ============================================================
% RESULTS
% ============================================================

results = struct();

%% ============================================================
% RUN THREE SPICE TESTS
% ============================================================

for c = 1:3

    caseName = names{c};

    fprintf('\n============================================================\n');
    fprintf(' %s-GAIN ROBUSTNESS TEST\n',upper(caseName));
    fprintf('============================================================\n');

    xNominal = Xnom{c};
    xPerturbed = Xtest{c};

    %% --------------------------------------------------------
    % Convert vectors to parameter structures
    % ---------------------------------------------------------

    perturbed = struct();

    for k = 1:9
        perturbed.(featureNames{k}) = xPerturbed(k);
    end

    %% --------------------------------------------------------
    % Display perturbation
    % ---------------------------------------------------------

    fprintf('\nPerturbations:\n');

    for k = 1:9

        pctChange = ...
            100*(xPerturbed(k)/xNominal(k)-1);

        fprintf('%-5s : %+8.3f %%\n', ...
            featureNames{k},pctChange);

    end

    %% --------------------------------------------------------
    % Working directory
    % ---------------------------------------------------------

    workDir = fullfile( ...
        outputDir, ...
        [lower(caseName) '_test']);

    if isfolder(workDir)
        rmdir(workDir,'s');
    end

    mkdir(workDir);

    %% --------------------------------------------------------
    % Run SPICE
    % ---------------------------------------------------------

    fprintf('\nRunning perturbed SPICE simulation...\n');

    try

        spiceResult = runSpice( ...
            perturbed, ...
            workDir, ...
            spiceOptions);

        if spiceResult.success

            fprintf('[PASS] SPICE execution completed.\n');

        else

            fprintf('[FAIL] SPICE returned unsuccessful result.\n');
            fprintf('Error: %s\n',spiceResult.error_msg);

            results.(caseName).success = false;
            results.(caseName).errorMessage = ...
                spiceResult.error_msg;

            continue;

        end

    catch ME

        fprintf('[FAIL] SPICE execution failed.\n');
        fprintf('%s\n',ME.message);

        results.(caseName).success = false;
        results.(caseName).errorMessage = ME.message;

        continue;

    end

    %% --------------------------------------------------------
    % Gain
    % ---------------------------------------------------------

    gain = spiceResult.gain_dB;

    fprintf('\nPerturbed SPICE gain = %.6f dB\n',gain);

    %% --------------------------------------------------------
    % Physical validity
    % ---------------------------------------------------------

    VCB = spiceResult.VC - spiceResult.VB;

    physicalValid = ...
        isfinite(spiceResult.IC) && ...
        isfinite(spiceResult.IB) && ...
        isfinite(spiceResult.VCE) && ...
        isfinite(VCB) && ...
        spiceResult.IC > 1e-7 && ...
        spiceResult.IB > 0 && ...
        spiceResult.VCE > 0.2 && ...
        VCB > 0;

    fprintf('\nDC operating point:\n');
    fprintf('VB  = %.6f V\n',spiceResult.VB);
    fprintf('VE  = %.6f V\n',spiceResult.VE);
    fprintf('VC  = %.6f V\n',spiceResult.VC);
    fprintf('IB  = %.6e A\n',spiceResult.IB);
    fprintf('IC  = %.6e A\n',spiceResult.IC);
    fprintf('VCE = %.6f V\n',spiceResult.VCE);
    fprintf('VCB = %.6f V\n',VCB);

    fprintf('\nPhysical validity = %d\n',physicalValid);

    %% --------------------------------------------------------
    % Store result
    % ---------------------------------------------------------

    results.(caseName).success = true;
    results.(caseName).gain_dB = gain;
    results.(caseName).physicalValid = physicalValid;
    results.(caseName).nominalX = xNominal;
    results.(caseName).perturbedX = xPerturbed;
    results.(caseName).spice = spiceResult;

end

%% ============================================================
% SUMMARY
% ============================================================

fprintf('\n============================================================\n');
fprintf(' STEP 7B SUMMARY\n');
fprintf('============================================================\n');

fprintf('\nCircuit    Gain (dB)       Valid\n');
fprintf('----------------------------------------\n');

for c = 1:3

    caseName = names{c};

    if results.(caseName).success

        fprintf('%-10s %-15.6f %d\n', ...
            caseName, ...
            results.(caseName).gain_dB, ...
            results.(caseName).physicalValid);

    else

        fprintf('%-10s FAILED\n',caseName);

    end

end

%% ============================================================
% SAVE SMOKE TEST RESULTS
% ============================================================

save( ...
    fullfile(outputDir,'Step7B_Smoke_Test_Results.mat'), ...
    'results', ...
    'Xnom', ...
    'Xtest', ...
    'featureNames');

fprintf('\nResults saved to:\n%s\n', ...
    fullfile(outputDir,'Step7B_Smoke_Test_Results.mat'));

fprintf('\n============================================================\n');
fprintf(' STEP 7B COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nOnly 3 SPICE simulations were attempted.\n');
fprintf('No large robustness experiment was executed.\n');
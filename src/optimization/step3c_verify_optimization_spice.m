%% ============================================================
% STEP 3C
% SPICE VERIFICATION OF DL + FMINCON OPTIMIZED CE AMPLIFIERS
%
% Flow:
%
%   DL surrogate
%        ↓
%     fmincon
%        ↓
%   optimized candidate
%        ↓
%      ngspice
%        ↓
% actual circuit performance
%
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf(' STEP 3C: SPICE VERIFICATION OF OPTIMIZED CIRCUITS\n');
fprintf('============================================================\n\n');


%% ------------------------------------------------------------
% Paths
% ------------------------------------------------------------

projectRoot = 'C:\Internship Project';
spiceSourceDir = fullfile(projectRoot,'src','spice');

if ~isfolder(spiceSourceDir)
    error('SPICE source directory not found:\n%s', spiceSourceDir);
end

addpath(spiceSourceDir);

fprintf('SPICE source path added:\n%s\n',spiceSourceDir);

optimizationFile = ...
    fullfile(projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_fmincon_Optimization_Results.mat');

setupFile = ...
    fullfile(projectRoot, ...
    'results', ...
    'optimization', ...
    'Optimization_Setup.mat');

outputDir = ...
    fullfile(projectRoot, ...
    'results', ...
    'optimization', ...
    'spice_verification');


%% ------------------------------------------------------------
% Create output directory
% ------------------------------------------------------------

if ~isfolder(outputDir)
    mkdir(outputDir);
end


%% ------------------------------------------------------------
% Load optimization results
% ------------------------------------------------------------

fprintf('Loading optimization results...\n');

O = load(optimizationFile);

optimizationResults = O.optimizationResults;


%% ------------------------------------------------------------
% Load optimization setup
% ------------------------------------------------------------

fprintf('Loading optimization setup...\n');

S = load(setupFile);

optimizationSetup = S.optimizationSetup;


%% ------------------------------------------------------------
% Feature names
% ------------------------------------------------------------

featureNames = optimizationSetup.featureNames;

fprintf('\nFeatures:\n');

for k = 1:numel(featureNames)
    fprintf('  %d. %s\n',k,featureNames{k});
end


%% ------------------------------------------------------------
% SPICE options
% ------------------------------------------------------------

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


%% ------------------------------------------------------------
% Verify SPICE infrastructure
% ------------------------------------------------------------

fprintf('\nChecking SPICE infrastructure...\n');

if ~isfile(spiceOptions.ngspice_exe)
    error('ngspice executable not found:\n%s', ...
        spiceOptions.ngspice_exe);
end

if ~isfile(spiceOptions.model_path)
    error('2N3904 model not found:\n%s', ...
        spiceOptions.model_path);
end

fprintf('ngspice      : OK\n');
fprintf('2N3904 model : OK\n');


%% ------------------------------------------------------------
% Circuit names
% ------------------------------------------------------------

circuitNames = {'Low','Medium','High'};


%% ------------------------------------------------------------
% Results container
% ------------------------------------------------------------

spiceResults = struct();


%% ============================================================
% RUN SPICE
% ============================================================

for k = 1:numel(circuitNames)

    name = circuitNames{k};

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' VERIFYING %s-GAIN CIRCUIT\n',upper(name));
    fprintf('============================================================\n');


    %% --------------------------------------------------------
    % Baseline parameters
    % --------------------------------------------------------

    xBaseline = ...
        optimizationSetup.baseline.(name).x;

    baselineGainReference = ...
        optimizationSetup.baseline.(name).gainSPICE;


    %% --------------------------------------------------------
    % Optimized parameters
    % --------------------------------------------------------

    xOptimized = ...
        optimizationResults.(name).xOpt;


    %% --------------------------------------------------------
    % DL predicted optimized gain
    % --------------------------------------------------------

    predictedOptimizedGain = ...
        optimizationResults.(name).predictedOptimizedGain;


    %% --------------------------------------------------------
    % Convert vectors to structs
    % --------------------------------------------------------

    baselineParams = vectorToParams(xBaseline);

    optimizedParams = vectorToParams(xOptimized);


    %% --------------------------------------------------------
    % Create dedicated working directories
    % --------------------------------------------------------

    baselineDir = fullfile( ...
        outputDir, ...
        [lower(name) '_baseline']);

    optimizedDir = fullfile( ...
        outputDir, ...
        [lower(name) '_optimized']);


    %% --------------------------------------------------------
    % Remove old simulation directories
    % --------------------------------------------------------

    if isfolder(baselineDir)
        rmdir(baselineDir,'s');
    end

    if isfolder(optimizedDir)
        rmdir(optimizedDir,'s');
    end


    %% ========================================================
    % BASELINE SPICE
    % ========================================================

    fprintf('\nRunning baseline SPICE...\n');

    baselineSPICE = runSpice( ...
        baselineParams, ...
        baselineDir, ...
        spiceOptions);


    %% ========================================================
    % OPTIMIZED SPICE
    % ========================================================

    fprintf('Running optimized SPICE...\n');

    optimizedSPICE = runSpice( ...
        optimizedParams, ...
        optimizedDir, ...
        spiceOptions);


    %% --------------------------------------------------------
    % Compare with stored baseline
    % --------------------------------------------------------

    baselineMatchError = ...
        baselineSPICE.gain_dB - baselineGainReference;


    %% --------------------------------------------------------
    % Actual SPICE improvement
    % --------------------------------------------------------

    if baselineSPICE.success && optimizedSPICE.success

        actualImprovement = ...
            optimizedSPICE.gain_dB - baselineSPICE.gain_dB;

    else

        actualImprovement = NaN;

    end


    %% --------------------------------------------------------
    % Surrogate prediction error
    % --------------------------------------------------------

    if optimizedSPICE.success

        optimizationPredictionError = ...
            predictedOptimizedGain - optimizedSPICE.gain_dB;

    else

        optimizationPredictionError = NaN;

    end


    %% --------------------------------------------------------
    % Physical validity
    % --------------------------------------------------------

    baselinePhysicalValid = ...
        classifySPICEResult(baselineSPICE);

    optimizedPhysicalValid = ...
        classifySPICEResult(optimizedSPICE);


    %% --------------------------------------------------------
    % Store
    % --------------------------------------------------------

    spiceResults.(name).baseline.parameters = ...
        baselineParams;

    spiceResults.(name).baseline.result = ...
        baselineSPICE;

    spiceResults.(name).baseline.referenceGain = ...
        baselineGainReference;

    spiceResults.(name).baseline.matchError = ...
        baselineMatchError;

    spiceResults.(name).baseline.physicalValid = ...
        baselinePhysicalValid;


    spiceResults.(name).optimized.parameters = ...
        optimizedParams;

    spiceResults.(name).optimized.result = ...
        optimizedSPICE;

    spiceResults.(name).optimized.dlPredictedGain = ...
        predictedOptimizedGain;

    spiceResults.(name).optimized.predictionError = ...
        optimizationPredictionError;

    spiceResults.(name).optimized.actualImprovement = ...
        actualImprovement;

    spiceResults.(name).optimized.physicalValid = ...
        optimizedPhysicalValid;


    %% --------------------------------------------------------
    % Print results
    % --------------------------------------------------------

    fprintf('\n------------------------------------------------------------\n');
    fprintf('%s-GAIN VERIFICATION RESULT\n',upper(name));
    fprintf('------------------------------------------------------------\n');

    fprintf('\nBASELINE\n');

    fprintf('  Stored SPICE gain       : %.6f dB\n', ...
        baselineGainReference);

    fprintf('  Re-run SPICE gain       : %.6f dB\n', ...
        baselineSPICE.gain_dB);

    fprintf('  Baseline match error    : %.6f dB\n', ...
        baselineMatchError);

    fprintf('  SPICE success           : %d\n', ...
        baselineSPICE.success);

    fprintf('  Physical validity       : %d\n', ...
        baselinePhysicalValid);


    fprintf('\nOPTIMIZED\n');

    fprintf('  DL predicted gain       : %.6f dB\n', ...
        predictedOptimizedGain);

    fprintf('  SPICE actual gain       : %.6f dB\n', ...
        optimizedSPICE.gain_dB);

    fprintf('  Prediction error        : %.6f dB\n', ...
        optimizationPredictionError);

    fprintf('  Actual SPICE improvement: %.6f dB\n', ...
        actualImprovement);

    fprintf('  SPICE success           : %d\n', ...
        optimizedSPICE.success);

    fprintf('  Physical validity       : %d\n', ...
        optimizedPhysicalValid);


    %% --------------------------------------------------------
    % DC operating point
    % --------------------------------------------------------

    if optimizedSPICE.success

        fprintf('\nOptimized DC operating point:\n');

        fprintf('  VB   = %.6f V\n',optimizedSPICE.VB);
        fprintf('  VE   = %.6f V\n',optimizedSPICE.VE);
        fprintf('  VC   = %.6f V\n',optimizedSPICE.VC);
        fprintf('  VCE  = %.6f V\n',optimizedSPICE.VCE);
        fprintf('  IB   = %.6e A\n',optimizedSPICE.IB);
        fprintf('  IC   = %.6e A\n',optimizedSPICE.IC);
        fprintf('  IE   = %.6e A\n',optimizedSPICE.IE);

    end

end


%% ============================================================
% SUMMARY TABLE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FINAL SPICE VERIFICATION SUMMARY\n');
fprintf('============================================================\n\n');


fprintf('%-10s %-15s %-15s %-15s %-15s %-10s\n', ...
    'Circuit', ...
    'Baseline', ...
    'DL Pred.', ...
    'SPICE Opt.', ...
    'Actual Δ', ...
    'Valid');

fprintf('%-10s %-15s %-15s %-15s %-15s %-10s\n', ...
    ' ', ...
    '(dB)', ...
    '(dB)', ...
    '(dB)', ...
    '(dB)', ...
    '');


for k = 1:numel(circuitNames)

    name = circuitNames{k};

    baselineGain = ...
        spiceResults.(name).baseline.result.gain_dB;

    dlGain = ...
        spiceResults.(name).optimized.dlPredictedGain;

    optimizedGain = ...
        spiceResults.(name).optimized.result.gain_dB;

    improvement = ...
        spiceResults.(name).optimized.actualImprovement;

    valid = ...
        spiceResults.(name).optimized.physicalValid;

    fprintf('%-10s %-15.4f %-15.4f %-15.4f %-15.4f %-10d\n', ...
        name, ...
        baselineGain, ...
        dlGain, ...
        optimizedGain, ...
        improvement, ...
        valid);

end


%% ------------------------------------------------------------
% Save complete results
% ------------------------------------------------------------

outputFile = fullfile( ...
    outputDir, ...
    'SPICE_Optimization_Verification.mat');

save(outputFile, ...
    'spiceResults', ...
    'spiceOptions', ...
    'featureNames', ...
    '-v7.3');


fprintf('\n');
fprintf('Saved complete verification results:\n');
fprintf('%s\n',outputFile);

fprintf('\nSTEP 3C COMPLETE.\n');


%% ============================================================
% LOCAL FUNCTION: VECTOR → PARAMETER STRUCT
% ============================================================

function params = vectorToParams(x)

    params = struct();

    params.R1   = x(1);
    params.R2   = x(2);
    params.RC   = x(3);
    params.RE   = x(4);
    params.RL   = x(5);
    params.Cin  = x(6);
    params.Cout = x(7);
    params.Ce   = x(8);
    params.VCC  = x(9);

end


%% ============================================================
% LOCAL FUNCTION: SPICE PHYSICAL VALIDITY
% ============================================================

function valid = classifySPICEResult(result)

    % Basic simulation success
    if ~result.success
        valid = false;
        return;
    end


    % Required DC quantities
    requiredValues = [ ...
        result.VB, ...
        result.VE, ...
        result.VC, ...
        result.IB, ...
        result.IC, ...
        result.IE, ...
        result.VCE];

    if any(~isfinite(requiredValues))
        valid = false;
        return;
    end


    % Existing project physical-screening logic
    %
    % Positive collector current
    if result.IC <= 1e-7
        valid = false;
        return;
    end


    % Positive base current
    if result.IB <= 0
        valid = false;
        return;
    end


    % Minimum collector-emitter voltage
    if result.VCE <= 0.20
        valid = false;
        return;
    end


    % Collector-base voltage
    VCB = result.VC - result.VB;

    if VCB <= 0
        valid = false;
        return;
    end


    valid = true;

end
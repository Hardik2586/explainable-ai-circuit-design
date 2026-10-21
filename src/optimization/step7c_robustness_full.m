%% STEP 7C - FULL SPICE ROBUSTNESS EXPERIMENT
% Explainable AI Framework for CE Amplifier
%
% 100 perturbations per optimized circuit
% 3 circuits
% Total = 300 SPICE simulations

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7C - FULL SPICE ROBUSTNESS EXPERIMENT\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% ============================================================

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

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'robustness');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

addpath(spiceDir);

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
% LOAD OPTIMIZED DESIGNS
% ============================================================

O = load(optimizationFile);
R = O.optimizationResults;

xLow    = R.Low.xOpt(:);
xMedium = R.Medium.xOpt(:);
xHigh   = R.High.xOpt(:);

Xnom = {xLow,xMedium,xHigh};
names = {'Low','Medium','High'};

%% ============================================================
% FEATURE NAMES
% ============================================================

featureNames = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

%% ============================================================
% EXPERIMENT SETTINGS
% ============================================================

N = 100;

resistorTol = 0.05;
capacitorTol = 0.10;
vccTol = 0.05;

rng(42);

fprintf('\nExperiment settings:\n');
fprintf('Samples per circuit : %d\n',N);
fprintf('Number of circuits  : 3\n');
fprintf('Total SPICE runs    : %d\n',3*N);
fprintf('Resistors           : +/- %.1f %%\n',100*resistorTol);
fprintf('Capacitors          : +/- %.1f %%\n',100*capacitorTol);
fprintf('VCC                 : +/- %.1f %%\n',100*vccTol);
fprintf('Random seed         : 42\n');

%% ============================================================
% PREALLOCATE RESULTS
% ============================================================

robustness = struct();

for c = 1:3

    caseName = names{c};

    robustness.(caseName).nominalX = Xnom{c};

    robustness.(caseName).gain_dB = NaN(N,1);

    robustness.(caseName).deltaGain_dB = NaN(N,1);

    robustness.(caseName).valid = false(N,1);

    robustness.(caseName).success = false(N,1);

    robustness.(caseName).perturbedX = NaN(N,9);

    robustness.(caseName).VB = NaN(N,1);
    robustness.(caseName).VE = NaN(N,1);
    robustness.(caseName).VC = NaN(N,1);

    robustness.(caseName).IB = NaN(N,1);
    robustness.(caseName).IC = NaN(N,1);

    robustness.(caseName).VCE = NaN(N,1);
    robustness.(caseName).VCB = NaN(N,1);

    robustness.(caseName).errorMessage = cell(N,1);

end

%% ============================================================
% GENERATE AND RUN PERTURATIONS
% ============================================================

totalRuns = 3*N;
runCounter = 0;

experimentStart = tic;

for c = 1:3

    caseName = names{c};

    xNominal = Xnom{c};

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' ROBUSTNESS: %s-GAIN CIRCUIT\n',upper(caseName));
    fprintf('============================================================\n');

    for n = 1:N

        runCounter = runCounter + 1;

        %% ----------------------------------------------------
        % Generate perturbation
        % -----------------------------------------------------

        multipliers = ones(9,1);

        % Resistors: +/- 5%
        multipliers(1:5) = ...
            1 + resistorTol*(2*rand(5,1)-1);

        % Capacitors: +/- 10%
        multipliers(6:8) = ...
            1 + capacitorTol*(2*rand(3,1)-1);

        % VCC: +/- 5%
        multipliers(9) = ...
            1 + vccTol*(2*rand-1);

        xPerturbed = xNominal .* multipliers;

        robustness.(caseName).perturbedX(n,:) = ...
            xPerturbed(:)';

        %% ----------------------------------------------------
        % Convert vector to SPICE parameter structure
        % -----------------------------------------------------

        params = struct();

        for k = 1:9
            params.(featureNames{k}) = xPerturbed(k);
        end

        %% ----------------------------------------------------
        % Working directory
        % -----------------------------------------------------

        workDir = fullfile( ...
            outputDir, ...
            'simulations', ...
            lower(caseName), ...
            sprintf('run_%03d',n));

        if isfolder(workDir)
            rmdir(workDir,'s');
        end

        mkdir(workDir);

        %% ----------------------------------------------------
        % Progress
        % -----------------------------------------------------

        fprintf( ...
            '[%3d/%3d] %s sample %3d ... ', ...
            runCounter,totalRuns,caseName,n);

        %% ----------------------------------------------------
        % Run SPICE
        % -----------------------------------------------------

        try

            spiceResult = runSpice( ...
                params, ...
                workDir, ...
                spiceOptions);

            if spiceResult.success

                gain = spiceResult.gain_dB;

                VCB = ...
                    spiceResult.VC - spiceResult.VB;

                physicalValid = ...
                    isfinite(spiceResult.IC) && ...
                    isfinite(spiceResult.IB) && ...
                    isfinite(spiceResult.VCE) && ...
                    isfinite(VCB) && ...
                    spiceResult.IC > 1e-7 && ...
                    spiceResult.IB > 0 && ...
                    spiceResult.VCE > 0.2 && ...
                    VCB > 0;

                robustness.(caseName).success(n) = true;

                robustness.(caseName).gain_dB(n) = gain;

                robustness.(caseName).valid(n) = ...
                    physicalValid;

                robustness.(caseName).VB(n) = ...
                    spiceResult.VB;

                robustness.(caseName).VE(n) = ...
                    spiceResult.VE;

                robustness.(caseName).VC(n) = ...
                    spiceResult.VC;

                robustness.(caseName).IB(n) = ...
                    spiceResult.IB;

                robustness.(caseName).IC(n) = ...
                    spiceResult.IC;

                robustness.(caseName).VCE(n) = ...
                    spiceResult.VCE;

                robustness.(caseName).VCB(n) = ...
                    VCB;

                fprintf( ...
                    'Gain = %8.4f dB | Valid = %d\n', ...
                    gain,physicalValid);

            else

                robustness.(caseName).errorMessage{n} = ...
                    spiceResult.error_msg;

                fprintf('SPICE FAIL\n');

            end

        catch ME

            robustness.(caseName).errorMessage{n} = ...
                ME.message;

            fprintf('ERROR\n');

        end

    end

    %% --------------------------------------------------------
    % Calculate delta gain
    % ---------------------------------------------------------

    % Obtain nominal gain using the optimized design itself.
    nominalParams = struct();

    for k = 1:9
        nominalParams.(featureNames{k}) = xNominal(k);
    end

    nominalDir = fullfile( ...
        outputDir, ...
        'nominal', ...
        lower(caseName));

    if ~isfolder(nominalDir)
        mkdir(nominalDir);
    end

    nominalResult = runSpice( ...
        nominalParams, ...
        nominalDir, ...
        spiceOptions);

    if ~nominalResult.success

        error( ...
            'Nominal SPICE simulation failed for %s circuit.', ...
            caseName);

    end

    nominalGain = nominalResult.gain_dB;

    robustness.(caseName).nominalGain_dB = ...
        nominalGain;

    robustness.(caseName).deltaGain_dB = ...
        robustness.(caseName).gain_dB - nominalGain;

    fprintf('\n%s nominal gain = %.6f dB\n', ...
        caseName,nominalGain);

end

experimentTime = toc(experimentStart);

%% ============================================================
% SUMMARY TABLE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' ROBUSTNESS SUMMARY\n');
fprintf('============================================================\n');

summary = table();

for c = 1:3

    caseName = names{c};

    gains = robustness.(caseName).gain_dB;

    validFinite = ...
        isfinite(gains);

    validGains = gains(validFinite);

    delta = ...
        robustness.(caseName).deltaGain_dB;

    deltaFinite = ...
        isfinite(delta);

    validFlags = ...
        robustness.(caseName).valid;

    successful = ...
        robustness.(caseName).success;

    nSuccessful = sum(successful);

    nValid = sum(validFlags & successful);

    nInvalid = nSuccessful - nValid;

    validityPercent = ...
        100*nValid/N;

    failurePercent = ...
        100*(N-nValid)/N;

    meanGain = mean(validGains);

    medianGain = median(validGains);

    stdGain = std(validGains);

    minGain = min(validGains);

    maxGain = max(validGains);

    meanDelta = mean(delta(deltaFinite));

    minDelta = min(delta(deltaFinite));

    maxDelta = max(delta(deltaFinite));

    stdDelta = std(delta(deltaFinite));

    newRow = table( ...
        string(caseName), ...
        robustness.(caseName).nominalGain_dB, ...
        nSuccessful, ...
        nValid, ...
        nInvalid, ...
        validityPercent, ...
        failurePercent, ...
        meanGain, ...
        medianGain, ...
        stdGain, ...
        minGain, ...
        maxGain, ...
        meanDelta, ...
        stdDelta, ...
        minDelta, ...
        maxDelta, ...
        'VariableNames',{ ...
        'Circuit', ...
        'NominalGain_dB', ...
        'SuccessfulRuns', ...
        'ValidRuns', ...
        'InvalidRuns', ...
        'ValidityPercent', ...
        'FailurePercent', ...
        'MeanGain_dB', ...
        'MedianGain_dB', ...
        'StdGain_dB', ...
        'MinGain_dB', ...
        'MaxGain_dB', ...
        'MeanDeltaGain_dB', ...
        'StdDeltaGain_dB', ...
        'MinDeltaGain_dB', ...
        'MaxDeltaGain_dB'});

    summary = [summary; newRow];

end

%% ============================================================
% DISPLAY SUMMARY
% ============================================================

disp(summary);

fprintf('\nTotal experiment time = %.2f minutes\n', ...
    experimentTime/60);

%% ============================================================
% SAVE RESULTS
% ============================================================

save( ...
    fullfile(outputDir,'Robustness_SPICE_Results.mat'), ...
    'robustness', ...
    'summary', ...
    'featureNames', ...
    'N', ...
    'resistorTol', ...
    'capacitorTol', ...
    'vccTol');

writetable( ...
    summary, ...
    fullfile(outputDir,'Robustness_Summary.csv'));

%% ============================================================
% FIGURE 1 - GAIN DISTRIBUTIONS
% ============================================================

figure;

hold on;

for c = 1:3

    caseName = names{c};

    gains = robustness.(caseName).gain_dB;

    gains = gains(isfinite(gains));

    histogram(gains,20, ...
        'DisplayName',caseName);

end

xlabel('Gain (dB)');
ylabel('Number of Samples');

title( ...
    'SPICE Gain Distribution Under Component Tolerances');

legend('Location','best');

grid on;

saveas( ...
    gcf, ...
    fullfile(outputDir,'Gain_Distribution.png'));

%% ============================================================
% FIGURE 2 - GAIN DEVIATION
% ============================================================

figure;

hold on;

for c = 1:3

    caseName = names{c};

    delta = ...
        robustness.(caseName).deltaGain_dB;

    delta = delta(isfinite(delta));

    plot( ...
        1:numel(delta), ...
        delta, ...
        '.', ...
        'DisplayName',caseName);

end

yline(0,'k--');

xlabel('Perturbation Sample');
ylabel('\Delta Gain (dB)');

title( ...
    'Gain Deviation from Nominal Design');

legend('Location','best');

grid on;

saveas( ...
    gcf, ...
    fullfile(outputDir,'Gain_Deviation.png'));

%% ============================================================
% FIGURE 3 - ROBUSTNESS COMPARISON
% ============================================================

figure;

bar(summary.ValidityPercent);

set(gca, ...
    'XTickLabel',summary.Circuit);

ylabel('Physically Valid Samples (%)');

xlabel('Optimized Circuit');

title( ...
    'Physical Validity Under Component Tolerances');

ylim([0 105]);

grid on;

saveas( ...
    gcf, ...
    fullfile(outputDir,'Robustness_Validity.png'));

%% ============================================================
% FINAL STATUS
% ============================================================

allSuccessful = ...
    all(summary.SuccessfulRuns == N);

allHaveValidSamples = ...
    all(summary.ValidRuns > 0);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7C FINAL STATUS\n');
fprintf('============================================================\n');

if allSuccessful

    fprintf('[PASS] All 300 SPICE simulations completed.\n');

else

    fprintf('[WARN] Some SPICE simulations failed.\n');

end

if allHaveValidSamples

    fprintf('[PASS] All circuits have physically valid robustness samples.\n');

else

    fprintf('[WARN] One or more circuits have zero valid samples.\n');

end

fprintf('\nResults saved to:\n');
fprintf('%s\n',outputDir);

fprintf('\n============================================================\n');
fprintf(' STEP 7C COMPLETE\n');
fprintf('============================================================\n');
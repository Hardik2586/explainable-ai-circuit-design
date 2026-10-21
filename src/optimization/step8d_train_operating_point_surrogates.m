%% STEP 8E - CIRCUIT-AWARE OPTIMIZATION
%
% Purpose:
%   Optimize CE amplifier gain while incorporating operating-point
%   constraints using surrogate models, followed by mandatory SPICE
%   physical verification.
%
% ================================================================
%
% MODEL PIPELINE
%
%   Gain DL model:
%       first 8 parameters -> log10
%       VCC               -> linear
%       training normalization using saved DL preprocessing
%
%   VCE / VCB surrogates:
%       first 8 parameters -> log10
%       VCC               -> linear
%       NO normalization
%
%   Physical authority:
%       ngspice
%
% ================================================================
%
% IMPORTANT:
%
%   runSpice() does NOT return VCB directly.
%
%       VCB = VC - VB
%
%   Therefore VCB is calculated everywhere in this script.
%
% ================================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8E - CIRCUIT-AWARE OPTIMIZATION\n');
fprintf('============================================================\n');


%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

dataCSV = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

operatingPointCSV = fullfile( ...
    projectRoot, ...
    'data', ...
    'processed', ...
    'CE_Amplifier_OperatingPoint_660.csv');

dlModelFile = fullfile( ...
    projectRoot, ...
    'models', ...
    'deep_learning', ...
    'CE_Gain_DL_Model.mat');

dlPredictionSetupFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_Optimization_Prediction_Setup.mat');

vceModelFile = fullfile( ...
    projectRoot, ...
    'models', ...
    'optimization', ...
    'VCE_OperatingPoint_Surrogate.mat');

vcbModelFile = fullfile( ...
    projectRoot, ...
    'models', ...
    'optimization', ...
    'VCB_OperatingPoint_Surrogate.mat');

spiceVerificationFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'spice_verification', ...
    'SPICE_Optimization_Verification.mat');

previousOptimizationFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_fmincon_Optimization_Results.mat');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

candidateDir = fullfile( ...
    outputDir, ...
    'physical_repair_candidates');

if ~isfolder(candidateDir)
    mkdir(candidateDir);
end


%% ============================================================
% FEATURE DEFINITIONS
% ============================================================

featureNames = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

nFeatures = numel(featureNames);

fprintf('\nFeatures:\n');
disp(featureNames');


%% ============================================================
% CHECK REQUIRED FILES
% ============================================================

requiredFiles = { ...
    dataCSV
    operatingPointCSV
    dlModelFile
    dlPredictionSetupFile
    vceModelFile
    vcbModelFile
    spiceVerificationFile
    previousOptimizationFile
    };

requiredNames = { ...
    'Canonical ML dataset'
    'Operating-point dataset'
    'DL model'
    'DL preprocessing setup'
    'VCE surrogate'
    'VCB surrogate'
    'Previous SPICE verification'
    'Previous DL optimization'
    };

for k = 1:numel(requiredFiles)

    if ~isfile(requiredFiles{k})

        error( ...
            '%s not found:\n%s', ...
            requiredNames{k}, ...
            requiredFiles{k});

    end

    fprintf('[PASS] %s\n',requiredNames{k});

end


%% ============================================================
% LOAD CANONICAL DATASET
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING DATASET\n');
fprintf('============================================================\n');

T = readtable(dataCSV);

if height(T) ~= 660

    error( ...
        'Expected 660 canonical rows, found %d.', ...
        height(T));

end

missingFeatures = setdiff( ...
    featureNames, ...
    T.Properties.VariableNames);

if ~isempty(missingFeatures)

    error( ...
        'Missing features: %s', ...
        strjoin(missingFeatures,', '));

end

Xdataset = T{:,featureNames};
Ydataset = T.Gain_dB;

if any(~isfinite(Xdataset),'all') || ...
        any(~isfinite(Ydataset))

    error('Non-finite values found in canonical dataset.');

end

fprintf( ...
    '[PASS] Canonical dataset loaded: %d rows.\n', ...
    height(T));


%% ============================================================
% DATASET BOUNDS
% ============================================================

lb = min(Xdataset,[],1);
ub = max(Xdataset,[],1);

fprintf('\nDataset bounds:\n');

for k = 1:nFeatures

    fprintf( ...
        '  %-5s : %.8g -> %.8g\n', ...
        featureNames{k}, ...
        lb(k), ...
        ub(k));

end


%% ============================================================
% LOAD DL MODEL
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING DL GAIN MODEL\n');
fprintf('============================================================\n');

D = load(dlModelFile);

if isfield(D,'net')

    net = D.net;

elseif isfield(D,'DLModel')

    net = D.DLModel;

else

    vars = fieldnames(D);

    found = false;

    for k = 1:numel(vars)

        candidate = D.(vars{k});

        if isa(candidate,'dlnetwork') || ...
                isa(candidate,'SeriesNetwork') || ...
                isa(candidate,'DAGNetwork')

            net = candidate;
            found = true;
            break;

        end

    end

    if ~found

        error( ...
            'Could not identify the DL network in model file.');

    end

end

fprintf('[PASS] DL network loaded.\n');


%% ============================================================
% LOAD EXACT DL PREPROCESSING
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING DL PREPROCESSING\n');
fprintf('============================================================\n');

P = load(dlPredictionSetupFile);

fprintf('Variables in DL setup file:\n');
disp(fieldnames(P));

if isfield(P,'mu')

    dlMu = P.mu;

elseif isfield(P,'featureMean')

    dlMu = P.featureMean;

else

    error( ...
        'Could not find DL normalization mean.');

end

if isfield(P,'sigma')

    dlSigma = P.sigma;

elseif isfield(P,'featureStd')

    dlSigma = P.featureStd;

else

    error( ...
        'Could not find DL normalization standard deviation.');

end

dlMu = double(dlMu(:)');
dlSigma = double(dlSigma(:)');

if numel(dlMu) ~= nFeatures || ...
        numel(dlSigma) ~= nFeatures

    error( ...
        'DL preprocessing dimensions do not match 9 features.');

end

fprintf('[PASS] DL preprocessing loaded.\n');


%% ============================================================
% DL PREDICTION FUNCTION
% ============================================================
%
% Exact project preprocessing:
%
%   first 8 -> log10
%   VCC     -> linear
%   normalize using saved development statistics
%

predictDL = @(x) predictDLGain( ...
    net, ...
    x, ...
    dlMu, ...
    dlSigma);


%% ============================================================
% LOAD VCE SURROGATE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING OPERATING-POINT SURROGATES\n');
fprintf('============================================================\n');

V = load(vceModelFile);

if ~isfield(V,'VCEModel')

    error('VCEModel not found.');

end

VCEModel = V.VCEModel;

if isfield(V,'VCE_LIMIT')

    VCE_LIMIT = V.VCE_LIMIT;

else

    VCE_LIMIT = 1.0;

end

fprintf('[PASS] VCE surrogate loaded.\n');


%% ============================================================
% LOAD VCB SURROGATE
% ============================================================

C = load(vcbModelFile);

if ~isfield(C,'VCBModel')

    error('VCBModel not found.');

end

VCBModel = C.VCBModel;

if isfield(C,'VCB_LIMIT')

    VCB_LIMIT = C.VCB_LIMIT;

else

    VCB_LIMIT = 0.5;

end

fprintf('[PASS] VCB surrogate loaded.\n');

fprintf('\nOperating-point limits:\n');
fprintf('  VCE >= %.3f V\n',VCE_LIMIT);
fprintf('  VCB >= %.3f V\n',VCB_LIMIT);


%% ============================================================
% OPERATING-POINT SURROGATE PREDICTION
% ============================================================
%
% EXACTLY matches Step 8D:
%
%       X(:,1:8) = log10(Xraw(:,1:8));
%
% NO normalization.
%

predictVCE = @(x) predictOperatingPoint( ...
    VCEModel, ...
    x);

predictVCB = @(x) predictOperatingPoint( ...
    VCBModel, ...
    x);


%% ============================================================
% LOAD PREVIOUS OPTIMIZATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING PREVIOUS OPTIMIZATION\n');
fprintf('============================================================\n');

O = load(previousOptimizationFile);

if ~isfield(O,'optimizationResults')

    error( ...
        'optimizationResults not found.');

end

previousOptimization = O.optimizationResults;

fprintf('[PASS] Previous optimization loaded.\n');


%% ============================================================
% DEFINE CASES
% ============================================================

caseNames = {'Low','Medium','High'};

baselineRows = [ ...
    409 ...
    527 ...
    536];

% Actual SPICE rerun baseline gains from Step 3C.
baselineSpiceGain = [ ...
    16.170634 ...
    35.026311 ...
    47.655775];


%% ============================================================
% LOAD PREVIOUS OPTIMIZED POINTS
% ============================================================

xPrevious = zeros(3,nFeatures);

for k = 1:3

    caseName = caseNames{k};

    S = previousOptimization.(caseName);

    if ~isfield(S,'xOpt')

        error( ...
            'Previous optimization case %s lacks xOpt.', ...
            caseName);

    end

    xPrevious(k,:) = double(S.xOpt(:)');

end

fprintf('\nPrevious optimized points loaded.\n');


%% ============================================================
% VERIFY PREVIOUS DL AND SURROGATE PREDICTIONS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' PREVIOUS DL OPTIMIZATION CHECK\n');
fprintf('============================================================\n');

for k = 1:3

    caseName = caseNames{k};

    x0 = xPrevious(k,:);

    gainPred = predictDL(x0);

    vcePred = predictVCE(x0);

    vcbPred = predictVCB(x0);

    fprintf('\n%s:\n',caseName);

    fprintf( ...
        '  Previous xOpt DL gain = %.6f dB\n', ...
        gainPred);

    fprintf( ...
        '  VCE surrogate         = %.6f V\n', ...
        vcePred);

    fprintf( ...
        '  VCB surrogate         = %.6f V\n', ...
        vcbPred);

end


%% ============================================================
% LOAD WORKING SPICE CONFIGURATION
% ============================================================
%
% Reuse the exact SPICE options already proven to work.
%

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING WORKING SPICE CONFIGURATION\n');
fprintf('============================================================\n');

SP = load(spiceVerificationFile);

if ~isfield(SP,'spiceOptions')

    error( ...
        ['spiceOptions was not found in Step 3C file. ', ...
         'Do not hard-code a new SPICE model path.']);

end

spiceOptions = SP.spiceOptions;

if ~isfield(spiceOptions,'ngspice_exe')

    error( ...
        'spiceOptions.ngspice_exe is missing.');

end

fprintf('[PASS] Loaded SPICE options from Step 3C.\n');

fprintf( ...
    'ngspice executable:\n%s\n', ...
    spiceOptions.ngspice_exe);


%% ============================================================
% SPICE CONFIGURATION SMOKE TEST
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' SPICE CONFIGURATION SMOKE TEST\n');
fprintf('============================================================\n');

smokeDir = fullfile( ...
    candidateDir, ...
    'spice_smoke_test');

if ~isfolder(smokeDir)
    mkdir(smokeDir);
end

smokeParams = vectorToParams(xPrevious(1,:));

smokeResult = runSpice( ...
    smokeParams, ...
    smokeDir, ...
    spiceOptions);

if ~smokeResult.success

    fprintf('\n[FAIL] SPICE smoke test failed.\n');

    fprintf('\nSPICE error message:\n');
    disp(smokeResult.error_msg);

    fprintf('\nSPICE log:\n');
    disp(smokeResult.log);

    fprintf('\nExit code:\n');
    disp(smokeResult.exit_code);

    if isfield(smokeResult,'netlist_path')

        fprintf( ...
            '\nNetlist:\n%s\n', ...
            smokeResult.netlist_path);

    end

    error( ...
        'Stopping Step 8E because SPICE smoke test failed.');

end

% ------------------------------------------------------------
% IMPORTANT:
%
% runSpice does NOT return VCB directly.
%
% VCB = VC - VB
% ------------------------------------------------------------

smokeVCB = ...
    smokeResult.VC - smokeResult.VB;

fprintf('[PASS] SPICE smoke test successful.\n');

fprintf( ...
    'Gain = %.6f dB\n', ...
    smokeResult.gain_dB);

fprintf( ...
    'VCE  = %.6f V\n', ...
    smokeResult.VCE);

fprintf( ...
    'VCB  = %.6f V\n', ...
    smokeVCB);


%% ============================================================
% OPTIMIZATION SETTINGS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' OPTIMIZATION SETTINGS\n');
fprintf('============================================================\n');

fminconOptions = optimoptions( ...
    'fmincon', ...
    'Algorithm','sqp', ...
    'Display','iter', ...
    'MaxIterations',200, ...
    'MaxFunctionEvaluations',3000, ...
    'OptimalityTolerance',1e-8, ...
    'StepTolerance',1e-10, ...
    'ConstraintTolerance',1e-8);


%% ============================================================
% STORAGE
% ============================================================

stage1Results = struct();
stage2Results = struct();
finalResults = struct();


%% ============================================================
% STAGE 1
% SURROGATE-GUIDED OPTIMIZATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STAGE 1 - SURROGATE-GUIDED OPTIMIZATION\n');
fprintf('============================================================\n');

for k = 1:3

    caseName = caseNames{k};

    fprintf('\n');
    fprintf('------------------------------------------------------------\n');
    fprintf(' CASE: %s\n',caseName);
    fprintf('------------------------------------------------------------\n');

    xStart = xPrevious(k,:);

    % Objective:
    % maximize DL-predicted gain
    objective = @(x) -predictDL(x);

    % Surrogate constraints:
    %
    %   VCE >= 1.0 V
    %   VCB >= 0.5 V
    %
    % fmincon convention:
    %   c <= 0

    nonlcon = @(x) ...
        operatingPointSurrogateConstraints( ...
            x, ...
            predictVCE, ...
            predictVCB, ...
            VCE_LIMIT, ...
            VCB_LIMIT);

    fprintf('\nStarting point:\n');

    fprintf( ...
        '  DL gain = %.6f dB\n', ...
        predictDL(xStart));

    fprintf( ...
        '  VCE     = %.6f V\n', ...
        predictVCE(xStart));

    fprintf( ...
        '  VCB     = %.6f V\n', ...
        predictVCB(xStart));

    tic;

    [xOpt,fval,exitflag,output] = fmincon( ...
        objective, ...
        xStart, ...
        [],[],[],[], ...
        lb, ...
        ub, ...
        nonlcon, ...
        fminconOptions);

    stage1Time = toc;

    predictedGain = -fval;

    predictedVCE = predictVCE(xOpt);
    predictedVCB = predictVCB(xOpt);

    stage1Results.(caseName).xStart = xStart;
    stage1Results.(caseName).xOpt = xOpt;
    stage1Results.(caseName).predictedGain = predictedGain;
    stage1Results.(caseName).predictedVCE = predictedVCE;
    stage1Results.(caseName).predictedVCB = predictedVCB;
    stage1Results.(caseName).exitflag = exitflag;
    stage1Results.(caseName).output = output;
    stage1Results.(caseName).runtime = stage1Time;

    fprintf('\nStage 1 result:\n');

    fprintf( ...
        '  Predicted gain = %.6f dB\n', ...
        predictedGain);

    fprintf( ...
        '  Predicted VCE  = %.6f V\n', ...
        predictedVCE);

    fprintf( ...
        '  Predicted VCB  = %.6f V\n', ...
        predictedVCB);

    fprintf( ...
        '  Exit flag      = %d\n', ...
        exitflag);

end


%% ============================================================
% STAGE 2
% ACTUAL SPICE VERIFICATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STAGE 2 - ACTUAL SPICE VERIFICATION\n');
fprintf('============================================================\n');

for k = 1:3

    caseName = caseNames{k};

    fprintf('\n');
    fprintf('------------------------------------------------------------\n');
    fprintf(' SPICE VERIFICATION: %s\n',caseName);
    fprintf('------------------------------------------------------------\n');

    xCandidate = ...
        stage1Results.(caseName).xOpt;

    workDir = fullfile( ...
        candidateDir, ...
        ['stage2_' lower(caseName)]);

    if ~isfolder(workDir)
        mkdir(workDir);
    end

    params = vectorToParams(xCandidate);

    result = runSpice( ...
        params, ...
        workDir, ...
        spiceOptions);

    stage2Results.(caseName).result = result;
    stage2Results.(caseName).x = xCandidate;

    if ~result.success

        fprintf('\n[FAIL] SPICE evaluation failed.\n');

        fprintf('\nError message:\n');
        disp(result.error_msg);

        fprintf('\nSPICE log:\n');
        disp(result.log);

        fprintf('\nExit code:\n');
        disp(result.exit_code);

        if isfield(result,'netlist_path')

            fprintf( ...
                '\nNetlist:\n%s\n', ...
                result.netlist_path);

        end

        stage2Results.(caseName).VCB = NaN;
        stage2Results.(caseName).spiceValid = false;

        continue;

    end

    % --------------------------------------------------------
    % Calculate VCB from returned node voltages.
    % --------------------------------------------------------

    resultVCB = ...
        result.VC - result.VB;

    stage2Results.(caseName).VCB = resultVCB;

    spiceValid = ...
        result.VCE >= VCE_LIMIT && ...
        resultVCB >= VCB_LIMIT;

    stage2Results.(caseName).spiceValid = ...
        spiceValid;

    fprintf('\nSPICE result:\n');

    fprintf( ...
        '  Gain = %.6f dB\n', ...
        result.gain_dB);

    fprintf( ...
        '  VCE  = %.6f V\n', ...
        result.VCE);

    fprintf( ...
        '  VCB  = %.6f V\n', ...
        resultVCB);

    fprintf( ...
        '  Physical validity = %d\n', ...
        result.success);

    fprintf( ...
        '  Circuit-aware validity = %d\n', ...
        spiceValid);

end


%% ============================================================
% STAGE 3
% PHYSICAL SPICE REPAIR SEARCH
% ============================================================
%
% If the surrogate optimizer proposes a candidate that does not
% satisfy actual SPICE constraints, search locally around it.
%
% Every repair candidate is evaluated with actual SPICE.
%
% The surrogate is ONLY used to rank candidate gain.
%

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STAGE 3 - PHYSICAL SPICE REPAIR SEARCH\n');
fprintf('============================================================\n');

rng(42);

numRepairCandidates = 100;

resistorIdx = 1:5;
capacitorIdx = 6:8;
vccIdx = 9;

for k = 1:3

    caseName = caseNames{k};

    fprintf('\n');
    fprintf('------------------------------------------------------------\n');
    fprintf(' PHYSICAL REPAIR: %s\n',caseName);
    fprintf('------------------------------------------------------------\n');

    if stage2Results.(caseName).spiceValid

        fprintf( ...
            '[PASS] Stage 1 candidate already satisfies SPICE constraints.\n');

        finalResults.(caseName).source = ...
            'Stage1_SPICE_Feasible';

        finalResults.(caseName).xOpt = ...
            stage1Results.(caseName).xOpt;

        finalResults.(caseName).stage1 = ...
            stage1Results.(caseName);

        finalResults.(caseName).stage2 = ...
            stage2Results.(caseName);

        continue;

    end

    xCenter = ...
        stage1Results.(caseName).xOpt;

    bestFound = false;
    bestGain = -Inf;
    bestX = [];
    bestSpice = [];

    % --------------------------------------------------------
    % Generate candidate matrix
    % --------------------------------------------------------

    candidateList = ...
        zeros(numRepairCandidates,nFeatures);

    % First candidate = exact Stage 1 solution
    candidateList(1,:) = xCenter;

    for n = 2:numRepairCandidates

        xCandidate = xCenter;

        % Resistors: +/-15%
        xCandidate(resistorIdx) = ...
            xCenter(resistorIdx) .* ...
            ( ...
            1 + ...
            0.15 * ...
            (2*rand(1,numel(resistorIdx))-1) ...
            );

        % Capacitors: +/-25%
        xCandidate(capacitorIdx) = ...
            xCenter(capacitorIdx) .* ...
            ( ...
            1 + ...
            0.25 * ...
            (2*rand(1,numel(capacitorIdx))-1) ...
            );

        % VCC: +/-10%
        xCandidate(vccIdx) = ...
            xCenter(vccIdx) .* ...
            ( ...
            1 + ...
            0.10 * ...
            (2*rand-1) ...
            );

        % Dataset bounds
        xCandidate = ...
            max(xCandidate,lb);

        xCandidate = ...
            min(xCandidate,ub);

        candidateList(n,:) = ...
            xCandidate;

    end


    % --------------------------------------------------------
    % Candidate records
    % --------------------------------------------------------

    candidateRecords = struct( ...
        'candidate',{}, ...
        'dlGain',{}, ...
        'spiceGain',{}, ...
        'VCE',{}, ...
        'VCB',{}, ...
        'valid',{});


    validCount = 0;


    % --------------------------------------------------------
    % Evaluate candidates with SPICE
    % --------------------------------------------------------

    for n = 1:numRepairCandidates

        xCandidate = ...
            candidateList(n,:);

        dlGain = ...
            predictDL(xCandidate);

        workDir = fullfile( ...
            candidateDir, ...
            ['repair_' lower(caseName)], ...
            sprintf('candidate_%03d',n));

        if ~isfolder(workDir)
            mkdir(workDir);
        end

        params = ...
            vectorToParams(xCandidate);

        result = ...
            runSpice( ...
            params, ...
            workDir, ...
            spiceOptions);


        if result.success

            resultVCB = ...
                result.VC - result.VB;

            isValid = ...
                result.VCE >= VCE_LIMIT && ...
                resultVCB >= VCB_LIMIT;

            spiceGain = ...
                result.gain_dB;

            if isValid

                validCount = ...
                    validCount + 1;

                if dlGain > bestGain

                    bestGain = ...
                        dlGain;

                    bestX = ...
                        xCandidate;

                    bestSpice = ...
                        result;

                    bestFound = true;

                end

            end

        else

            resultVCB = NaN;
            isValid = false;
            spiceGain = NaN;

        end


        % ----------------------------------------------------
        % Store candidate information
        % ----------------------------------------------------

        candidateRecords(n).candidate = ...
            xCandidate;

        candidateRecords(n).dlGain = ...
            dlGain;

        candidateRecords(n).spiceGain = ...
            spiceGain;

        candidateRecords(n).VCE = ...
            resultVCEOrNaN(result);

        candidateRecords(n).VCB = ...
            resultVCB;

        candidateRecords(n).valid = ...
            isValid;


        % ----------------------------------------------------
        % Console
        % ----------------------------------------------------

        fprintf( ...
            'Candidate %3d/%3d | DL %.4f dB | ', ...
            n, ...
            numRepairCandidates, ...
            dlGain);

        if result.success

            fprintf( ...
                'SPICE %.4f dB | VCE %.4f | VCB %.4f | Valid %d\n', ...
                result.gain_dB, ...
                result.VCE, ...
                resultVCB, ...
                isValid);

        else

            fprintf( ...
                'SPICE FAILED\n');

        end

    end


    % --------------------------------------------------------
    % Repair summary
    % --------------------------------------------------------

    fprintf('\nRepair search summary:\n');

    fprintf( ...
        '  Total candidates        = %d\n', ...
        numRepairCandidates);

    fprintf( ...
        '  SPICE-valid candidates  = %d\n', ...
        validCount);


    if bestFound

        bestVCB = ...
            bestSpice.VC - bestSpice.VB;

        fprintf( ...
            '  Best DL predicted gain  = %.6f dB\n', ...
            bestGain);

        fprintf( ...
            '  Actual SPICE gain       = %.6f dB\n', ...
            bestSpice.gain_dB);

        fprintf( ...
            '  Actual VCE              = %.6f V\n', ...
            bestSpice.VCE);

        fprintf( ...
            '  Actual VCB              = %.6f V\n', ...
            bestVCB);


        finalResults.(caseName).source = ...
            'Stage3_SPICE_Repair';

        finalResults.(caseName).xOpt = ...
            bestX;

        finalResults.(caseName).stage1 = ...
            stage1Results.(caseName);

        finalResults.(caseName).stage2 = ...
            stage2Results.(caseName);

        finalResults.(caseName).repairBestDLGain = ...
            bestGain;

        finalResults.(caseName).repairBestSPICE = ...
            bestSpice;

        finalResults.(caseName).repairValidCount = ...
            validCount;

        finalResults.(caseName).repairCandidates = ...
            candidateRecords;

    else

        fprintf( ...
            '\n[WARNING] No physically valid repair candidate found.\n');

        finalResults.(caseName).source = ...
            'No_SPICE_Feasible_Candidate';

        finalResults.(caseName).xOpt = ...
            xCenter;

        finalResults.(caseName).stage1 = ...
            stage1Results.(caseName);

        finalResults.(caseName).stage2 = ...
            stage2Results.(caseName);

        finalResults.(caseName).repairValidCount = ...
            validCount;

        finalResults.(caseName).repairCandidates = ...
            candidateRecords;

    end

end


%% ============================================================
% FINAL EVALUATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FINAL CIRCUIT-AWARE RESULTS\n');
fprintf('============================================================\n');

summaryRows = [];

for k = 1:3

    caseName = caseNames{k};

    F = ...
        finalResults.(caseName);

    xFinal = ...
        F.xOpt;


    % --------------------------------------------------------
    % Always run a fresh final SPICE verification.
    % --------------------------------------------------------

    finalWorkDir = ...
        fullfile( ...
        candidateDir, ...
        ['final_' lower(caseName)]);

    if ~isfolder(finalWorkDir)
        mkdir(finalWorkDir);
    end

    finalParams = ...
        vectorToParams(xFinal);

    finalSpice = ...
        runSpice( ...
        finalParams, ...
        finalWorkDir, ...
        spiceOptions);

    finalResults.(caseName).finalSPICE = ...
        finalSpice;


    % --------------------------------------------------------
    % Gain
    % --------------------------------------------------------

    baselineGain = ...
        baselineSpiceGain(k);

    dlPredGain = ...
        predictDL(xFinal);


    % --------------------------------------------------------
    % Final SPICE results
    % --------------------------------------------------------

    if finalSpice.success

        actualGain = ...
            finalSpice.gain_dB;

        actualVCE = ...
            finalSpice.VCE;

        actualVCB = ...
            finalSpice.VC - finalSpice.VB;

        physicalValid = ...
            true;

        constraintValid = ...
            actualVCE >= VCE_LIMIT && ...
            actualVCB >= VCB_LIMIT;

        actualImprovement = ...
            actualGain - baselineGain;

    else

        fprintf('\n[FAIL] Final SPICE evaluation failed for %s.\n', ...
            caseName);

        fprintf('\nError:\n');
        disp(finalSpice.error_msg);

        fprintf('\nLog:\n');
        disp(finalSpice.log);

        actualGain = NaN;
        actualVCE = NaN;
        actualVCB = NaN;

        physicalValid = false;
        constraintValid = false;

        actualImprovement = NaN;

    end


    % --------------------------------------------------------
    % DL predicted improvement
    % --------------------------------------------------------

    baselineDLGain = ...
        predictDL( ...
        Xdataset(baselineRows(k),:));

    predictedImprovement = ...
        dlPredGain - baselineDLGain;


    % --------------------------------------------------------
    % Store final values
    % --------------------------------------------------------

    finalResults.(caseName).baselineGain = ...
        baselineGain;

    finalResults.(caseName).dlPredictedGain = ...
        dlPredGain;

    finalResults.(caseName).actualGain = ...
        actualGain;

    finalResults.(caseName).actualVCE = ...
        actualVCE;

    finalResults.(caseName).actualVCB = ...
        actualVCB;

    finalResults.(caseName).physicalValid = ...
        physicalValid;

    finalResults.(caseName).constraintValid = ...
        constraintValid;

    finalResults.(caseName).predictedImprovement = ...
        predictedImprovement;

    finalResults.(caseName).actualImprovement = ...
        actualImprovement;


    % --------------------------------------------------------
    % Console output
    % --------------------------------------------------------

    fprintf('\n%s:\n',caseName);

    fprintf( ...
        '  Baseline SPICE gain       = %.6f dB\n', ...
        baselineGain);

    fprintf( ...
        '  DL predicted final gain   = %.6f dB\n', ...
        dlPredGain);

    fprintf( ...
        '  SPICE final gain          = %.6f dB\n', ...
        actualGain);

    fprintf( ...
        '  SPICE VCE                 = %.6f V\n', ...
        actualVCE);

    fprintf( ...
        '  SPICE VCB                 = %.6f V\n', ...
        actualVCB);

    fprintf( ...
        '  Predicted improvement     = %.6f dB\n', ...
        predictedImprovement);

    fprintf( ...
        '  Actual improvement        = %.6f dB\n', ...
        actualImprovement);

    fprintf( ...
        '  Physical validity         = %d\n', ...
        physicalValid);

    fprintf( ...
        '  Circuit constraint valid  = %d\n', ...
        constraintValid);


    % --------------------------------------------------------
    % Summary row
    % --------------------------------------------------------

    summaryRows = [ ...
        summaryRows;
        k, ...
        baselineGain, ...
        dlPredGain, ...
        actualGain, ...
        predictedImprovement, ...
        actualImprovement, ...
        actualVCE, ...
        actualVCB, ...
        double(physicalValid), ...
        double(constraintValid)]; %#ok<AGROW>

end


%% ============================================================
% FINAL SUMMARY TABLE
% ============================================================

summaryTable = array2table( ...
    summaryRows, ...
    'VariableNames',{ ...
    'CaseIndex', ...
    'Baseline_SPICE_Gain_dB', ...
    'DL_Predicted_Gain_dB', ...
    'Final_SPICE_Gain_dB', ...
    'Predicted_Improvement_dB', ...
    'Actual_Improvement_dB', ...
    'Final_VCE_V', ...
    'Final_VCB_V', ...
    'Physical_Valid', ...
    'Constraint_Valid'});


summaryTable.Case = ...
    string(caseNames');

summaryTable = ...
    movevars( ...
    summaryTable, ...
    'Case', ...
    'Before', ...
    'CaseIndex');


%% ============================================================
% FINAL DESIGN TABLE
% ============================================================

designMatrix = ...
    zeros(3,nFeatures);

for k = 1:3

    designMatrix(k,:) = ...
        finalResults.(caseNames{k}).xOpt;

end

designTable = ...
    array2table( ...
    designMatrix, ...
    'VariableNames', ...
    featureNames);

designTable.Case = ...
    string(caseNames');

designTable = ...
    movevars( ...
    designTable, ...
    'Case', ...
    'Before', ...
    1);


%% ============================================================
% SAVE RESULTS
% ============================================================

resultsMAT = ...
    fullfile( ...
    outputDir, ...
    'Step8E_Circuit_Aware_Optimization_Results.mat');

save( ...
    resultsMAT, ...
    'featureNames', ...
    'VCE_LIMIT', ...
    'VCB_LIMIT', ...
    'stage1Results', ...
    'stage2Results', ...
    'finalResults', ...
    'summaryTable', ...
    'spiceOptions', ...
    'baselineSpiceGain');


resultsCSV = ...
    fullfile( ...
    outputDir, ...
    'Step8E_Final_Summary.csv');

writetable( ...
    summaryTable, ...
    resultsCSV);


designCSV = ...
    fullfile( ...
    outputDir, ...
    'Step8E_Final_Designs.csv');

writetable( ...
    designTable, ...
    designCSV);


%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8E FINAL STATUS\n');
fprintf('============================================================\n');

disp(summaryTable);

allConstraintValid = ...
    all(summaryTable.Constraint_Valid == 1);

if allConstraintValid

    fprintf( ...
        '\n[PASS] All final designs satisfy the SPICE operating-point constraints.\n');

else

    fprintf( ...
        '\n[WARNING] One or more final designs do not satisfy the SPICE constraints.\n');

end

fprintf('\nResults saved:\n');

fprintf('%s\n',resultsMAT);
fprintf('%s\n',resultsCSV);
fprintf('%s\n',designCSV);

fprintf('\nIMPORTANT:\n');
fprintf('SPICE is the final physical authority.\n');
fprintf('VCE/VCB surrogate predictions are not treated as physical truth.\n');

fprintf('\n============================================================\n');
fprintf(' STEP 8E COMPLETE\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTION: DL GAIN PREDICTION
% ============================================================

function gain = predictDLGain( ...
    net, ...
    x, ...
    mu, ...
    sigma)

x = double(x(:)');

if numel(x) ~= 9

    error( ...
        'DL input must contain exactly 9 features.');

end

X = x;

% First 8 parameters -> log10
X(1:8) = log10(X(1:8));

% Normalize using saved DL development statistics
X = ...
    (X - mu) ./ sigma;

Xdl = ...
    single(X);

Ypred = ...
    predict(net,Xdl);

if isa(Ypred,'dlarray')

    Ypred = ...
        extractdata(Ypred);

end

Ypred = ...
    double(Ypred);

gain = ...
    Ypred(1);

end


%% ============================================================
% LOCAL FUNCTION: OPERATING-POINT SURROGATE
% ============================================================

function y = predictOperatingPoint( ...
    model, ...
    x)

x = ...
    double(x(:)');

if numel(x) ~= 9

    error( ...
        'Operating-point input must contain exactly 9 features.');

end

X = x;

% EXACT Step 8D preprocessing:
%
%   first 8 -> log10
%   VCC     -> linear
%
% NO normalization.

X(1:8) = ...
    log10(X(1:8));

y = ...
    predict(model,X);

y = ...
    double(y);

y = ...
    y(1);

end


%% ============================================================
% LOCAL FUNCTION: SURROGATE CONSTRAINTS
% ============================================================

function [c,ceq] = ...
    operatingPointSurrogateConstraints( ...
    x, ...
    predictVCE, ...
    predictVCB, ...
    VCE_LIMIT, ...
    VCB_LIMIT)

predictedVCE = ...
    predictVCE(x);

predictedVCB = ...
    predictVCB(x);

% fmincon requires:
%
%       c <= 0
%
% Therefore:
%
%       VCE_LIMIT - predictedVCE <= 0
%       VCB_LIMIT - predictedVCB <= 0

c = [ ...
    VCE_LIMIT - predictedVCE;
    VCB_LIMIT - predictedVCB];

ceq = [];

end


%% ============================================================
% LOCAL FUNCTION: VECTOR -> SPICE STRUCT
% ============================================================

function params = ...
    vectorToParams(x)

params = struct();

params.R1 = x(1);
params.R2 = x(2);
params.RC = x(3);
params.RE = x(4);
params.RL = x(5);
params.Cin = x(6);
params.Cout = x(7);
params.Ce = x(8);
params.VCC = x(9);

end


%% ============================================================
% LOCAL FUNCTION: RETURN VCE OR NaN
% ============================================================

function value = ...
    resultVCEOrNaN(result)

if isstruct(result) && ...
        isfield(result,'success') && ...
        result.success && ...
        isfield(result,'VCE')

    value = ...
        result.VCE;

else

    value = NaN;

end

end
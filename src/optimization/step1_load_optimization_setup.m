%% ============================================================
% STEP 1 - LOAD AND FREEZE OPTIMIZATION SETUP
%
% Purpose:
%   1. Load the canonical 660-row CE amplifier dataset
%   2. Load the already-trained DL model
%   3. Verify dataset structure
%   4. Identify the three baseline circuits
%   5. Establish dataset-derived optimization bounds
%   6. Save a frozen optimization setup
%
% IMPORTANT:
%   - No retraining
%   - No optimization
%   - No SPICE simulation
%   - No modification of the dataset
%
% Next step:
%   Build the exact DL prediction wrapper and fmincon optimizer.
%% ============================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 1 - LOAD AND FREEZE OPTIMIZATION SETUP\n');
fprintf('============================================================\n\n');


%% ------------------------------------------------------------
% 1. PROJECT PATHS
% ------------------------------------------------------------

projectRoot = 'C:\Internship Project';

datasetFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

modelFile = fullfile( ...
    projectRoot, ...
    'models', ...
    'deep_learning', ...
    'CE_Gain_DL_Model.mat');

optimizationDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization');


fprintf('Project root:\n%s\n\n', projectRoot);

fprintf('Dataset file:\n%s\n\n', datasetFile);

fprintf('DL model file:\n%s\n\n', modelFile);


%% ------------------------------------------------------------
% 2. CHECK FILES AND FOLDERS
% ------------------------------------------------------------

if ~isfolder(projectRoot)
    error('Project root does not exist:\n%s', projectRoot);
end

if ~isfile(datasetFile)
    error('Canonical dataset not found:\n%s', datasetFile);
end

if ~isfile(modelFile)
    error('DL model not found:\n%s', modelFile);
end

if ~isfolder(optimizationDir)
    mkdir(optimizationDir);
end

fprintf('File/folder checks: PASSED\n\n');


%% ------------------------------------------------------------
% 3. LOAD CANONICAL DATASET
% ------------------------------------------------------------

fprintf('Loading canonical dataset...\n');

T = readtable(datasetFile);

fprintf('Dataset loaded successfully.\n');
fprintf('Rows    : %d\n', height(T));
fprintf('Columns : %d\n\n', width(T));


%% ------------------------------------------------------------
% 4. DEFINE FEATURE ORDER
%
% THIS ORDER MUST NEVER CHANGE.
% It must match the order used by the DL model.
% ------------------------------------------------------------

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

targetName = 'Gain_dB';


%% ------------------------------------------------------------
% 5. VERIFY REQUIRED DATASET COLUMNS
% ------------------------------------------------------------

requiredVars = [featureNames, {targetName}];

missingVars = setdiff( ...
    requiredVars, ...
    T.Properties.VariableNames);

if ~isempty(missingVars)

    fprintf('\nMissing variables detected:\n');
    disp(missingVars');

    error('Dataset does not contain all required variables.');

end

fprintf('Required dataset variables: PASSED\n');


%% ------------------------------------------------------------
% 6. EXTRACT X AND Y
% ------------------------------------------------------------

X = T{:, featureNames};
Y = T{:, targetName};

fprintf('\nFeature matrix X:\n');
fprintf('Rows    : %d\n', size(X,1));
fprintf('Features: %d\n', size(X,2));

fprintf('\nTarget vector Y:\n');
fprintf('Rows    : %d\n', size(Y,1));


%% ------------------------------------------------------------
% 7. DATA TYPE CHECK
% ------------------------------------------------------------

if ~isnumeric(X)

    error('Feature matrix X is not numeric.');

end

if ~isnumeric(Y)

    error('Target vector Y is not numeric.');

end

fprintf('\nNumeric data check: PASSED\n');


%% ------------------------------------------------------------
% 8. NaN / INF CHECK
% ------------------------------------------------------------

hasNaNX = any(isnan(X), 'all');
hasNaNY = any(isnan(Y), 'all');

hasInfX = any(isinf(X), 'all');
hasInfY = any(isinf(Y), 'all');

if hasNaNX || hasNaNY

    error('NaN values detected in optimization dataset.');

end

if hasInfX || hasInfY

    error('Inf values detected in optimization dataset.');

end

fprintf('NaN/Inf check: PASSED\n');


%% ------------------------------------------------------------
% 9. DATASET SUMMARY
% ------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' DATASET SUMMARY\n');
fprintf('============================================================\n');

fprintf('Number of valid circuits : %d\n', size(X,1));
fprintf('Number of input features : %d\n', size(X,2));

fprintf('\nGain range:\n');
fprintf('Minimum Gain = %.6f dB\n', min(Y));
fprintf('Maximum Gain = %.6f dB\n', max(Y));
fprintf('Mean Gain    = %.6f dB\n', mean(Y));
fprintf('Median Gain  = %.6f dB\n', median(Y));


%% ------------------------------------------------------------
% 10. CHECK FOR DUPLICATE PARAMETER ROWS
% ------------------------------------------------------------

[~, uniqueIdx] = unique(X, 'rows');

numberUnique = numel(uniqueIdx);
numberDuplicate = size(X,1) - numberUnique;

fprintf('\nDuplicate parameter rows:\n');
fprintf('Unique rows     : %d\n', numberUnique);
fprintf('Duplicate rows  : %d\n', numberDuplicate);


%% ------------------------------------------------------------
% 11. DATASET-DERIVED OPTIMIZATION BOUNDS
%
% We initially restrict optimization to the region represented
% by the valid dataset.
%
% This avoids immediate extrapolation by the DL surrogate.
% ------------------------------------------------------------

LB = min(X, [], 1);
UB = max(X, [], 1);

fprintf('\n============================================================\n');
fprintf(' DATASET-DERIVED OPTIMIZATION BOUNDS\n');
fprintf('============================================================\n');

fprintf('\n%-8s %-18s %-18s\n', ...
    'Feature', 'Lower Bound', 'Upper Bound');

fprintf('%s\n', repmat('-',1,48));

for k = 1:numel(featureNames)

    fprintf('%-8s %-18.8g %-18.8g\n', ...
        featureNames{k}, ...
        LB(k), ...
        UB(k));

end


%% ------------------------------------------------------------
% 12. SELECT THREE BASELINE CIRCUITS
%
% These are the SAME representative circuits used in the
% completed unified XAI analysis.
%
% Low:
%    dataset row 409
%
% Medium:
%    dataset row 527
%
% High:
%    dataset row 536
% ------------------------------------------------------------

lowRow = 409;
mediumRow = 527;
highRow = 536;


% Safety check
selectedRows = [lowRow, mediumRow, highRow];

if any(selectedRows < 1) || ...
        any(selectedRows > height(T))

    error('One or more representative dataset rows are invalid.');

end


%% ------------------------------------------------------------
% 13. EXTRACT BASELINE CIRCUITS
% ------------------------------------------------------------

xLow = T{lowRow, featureNames};
xMedium = T{mediumRow, featureNames};
xHigh = T{highRow, featureNames};


gainLowSPICE = T{lowRow, targetName};
gainMediumSPICE = T{mediumRow, targetName};
gainHighSPICE = T{highRow, targetName};


%% ------------------------------------------------------------
% 14. VERIFY BASELINE CIRCUITS ARE INSIDE BOUNDS
% ------------------------------------------------------------

if any(xLow < LB) || any(xLow > UB)

    error('Low-gain baseline is outside dataset bounds.');

end

if any(xMedium < LB) || any(xMedium > UB)

    error('Medium-gain baseline is outside dataset bounds.');

end

if any(xHigh < LB) || any(xHigh > UB)

    error('High-gain baseline is outside dataset bounds.');

end

fprintf('\nBaseline bound check: PASSED\n');


%% ------------------------------------------------------------
% 15. DISPLAY BASELINE CIRCUITS
% ------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' BASELINE CIRCUITS\n');
fprintf('============================================================\n');


fprintf('\nLOW-GAIN BASELINE\n');
fprintf('Dataset row : %d\n', lowRow);
fprintf('SPICE Gain  : %.6f dB\n', gainLowSPICE);

fprintf('\n%-8s %-18s\n', 'Feature', 'Value');
fprintf('%s\n', repmat('-',1,30));

for k = 1:numel(featureNames)

    fprintf('%-8s %-18.10g\n', ...
        featureNames{k}, ...
        xLow(k));

end


fprintf('\nMEDIUM-GAIN BASELINE\n');
fprintf('Dataset row : %d\n', mediumRow);
fprintf('SPICE Gain  : %.6f dB\n', gainMediumSPICE);

fprintf('\n%-8s %-18s\n', 'Feature', 'Value');
fprintf('%s\n', repmat('-',1,30));

for k = 1:numel(featureNames)

    fprintf('%-8s %-18.10g\n', ...
        featureNames{k}, ...
        xMedium(k));

end


fprintf('\nHIGH-GAIN BASELINE\n');
fprintf('Dataset row : %d\n', highRow);
fprintf('SPICE Gain  : %.6f dB\n', gainHighSPICE);

fprintf('\n%-8s %-18s\n', 'Feature', 'Value');
fprintf('%s\n', repmat('-',1,30));

for k = 1:numel(featureNames)

    fprintf('%-8s %-18.10g\n', ...
        featureNames{k}, ...
        xHigh(k));

end


%% ------------------------------------------------------------
% 16. LOAD DL MODEL
% ------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' LOADING DL MODEL\n');
fprintf('============================================================\n');

modelData = load(modelFile);

fprintf('\nVariables contained in DL model MAT file:\n');

modelFields = fieldnames(modelData);

for k = 1:numel(modelFields)

    fprintf('  %s\n', modelFields{k});

end


%% ------------------------------------------------------------
% 17. IDENTIFY NETWORK VARIABLE
%
% We do NOT assume the variable name.
% ------------------------------------------------------------

net = [];

for k = 1:numel(modelFields)

    candidate = modelData.(modelFields{k});

    % Check for MATLAB neural network / dlnetwork-like object
    if isa(candidate, 'dlnetwork')

        net = candidate;

        fprintf('\nDL network found in variable: %s\n', ...
            modelFields{k});

        break;

    end

end


if isempty(net)

    fprintf('\nWARNING:\n');
    fprintf(['No dlnetwork object was automatically identified.\n']);
    fprintf(['This is NOT a failure of Step 1.\n']);
    fprintf(['The MAT file structure will be inspected before Step 2.\n\n']);

else

    fprintf('DL network loading: PASSED\n');

end


%% ------------------------------------------------------------
% 18. SEARCH FOR PREPROCESSING VARIABLES
%
% We look for common names but DO NOT overwrite anything.
% ------------------------------------------------------------

mu = [];
sigma = [];

possibleMuNames = { ...
    'mu', ...
    'Mu', ...
    'meanX', ...
    'XMean', ...
    'X_mu', ...
    'muX'};

possibleSigmaNames = { ...
    'sigma', ...
    'Sigma', ...
    'stdX', ...
    'XStd', ...
    'X_sigma', ...
    'sigmaX'};


% Search for mean
for k = 1:numel(possibleMuNames)

    name = possibleMuNames{k};

    if isfield(modelData, name)

        candidate = modelData.(name);

        if isnumeric(candidate)

            mu = candidate;

            fprintf('Preprocessing mean found: %s\n', name);

            break;

        end

    end

end


% Search for standard deviation
for k = 1:numel(possibleSigmaNames)

    name = possibleSigmaNames{k};

    if isfield(modelData, name)

        candidate = modelData.(name);

        if isnumeric(candidate)

            sigma = candidate;

            fprintf('Preprocessing std found: %s\n', name);

            break;

        end

    end

end


%% ------------------------------------------------------------
% 19. PREPROCESSING STATUS
% ------------------------------------------------------------

fprintf('\nPreprocessing information:\n');

if ~isempty(mu)

    fprintf('  Mean found: YES\n');

else

    fprintf('  Mean found: NO\n');

end


if ~isempty(sigma)

    fprintf('  Std found : YES\n');

else

    fprintf('  Std found : NO\n');

end


%% ------------------------------------------------------------
% 20. BASIC PREPROCESSING DIMENSION CHECK
% ------------------------------------------------------------

if ~isempty(mu) && ~isempty(sigma)

    mu = double(mu(:)');
    sigma = double(sigma(:)');

    fprintf('\nPreprocessing dimensions:\n');
    fprintf('  mu    : %d elements\n', numel(mu));
    fprintf('  sigma : %d elements\n', numel(sigma));

    if numel(mu) ~= numel(featureNames)

        warning(['Mean vector does not contain 9 elements. ' ...
                 'Do not use it for optimization until verified.']);

    end

    if numel(sigma) ~= numel(featureNames)

        warning(['Std vector does not contain 9 elements. ' ...
                 'Do not use it for optimization until verified.']);

    end

else

    fprintf('\nExact preprocessing vectors were not automatically found.\n');
    fprintf(['We will identify their actual names/structure before ' ...
             'building the optimization prediction wrapper.\n']);

end


%% ------------------------------------------------------------
% 21. CREATE BASELINE STRUCTURE
% ------------------------------------------------------------

baseline.featureNames = featureNames;

baseline.Low.datasetRow = lowRow;
baseline.Low.x = xLow;
baseline.Low.gainSPICE = gainLowSPICE;

baseline.Medium.datasetRow = mediumRow;
baseline.Medium.x = xMedium;
baseline.Medium.gainSPICE = gainMediumSPICE;

baseline.High.datasetRow = highRow;
baseline.High.x = xHigh;
baseline.High.gainSPICE = gainHighSPICE;


%% ------------------------------------------------------------
% 22. CREATE OPTIMIZATION SETUP STRUCTURE
% ------------------------------------------------------------

optimizationSetup = struct();

optimizationSetup.projectRoot = projectRoot;

optimizationSetup.datasetFile = datasetFile;

optimizationSetup.modelFile = modelFile;

optimizationSetup.featureNames = featureNames;

optimizationSetup.targetName = targetName;

optimizationSetup.X = X;

optimizationSetup.Y = Y;

optimizationSetup.LB = LB;

optimizationSetup.UB = UB;

optimizationSetup.baseline = baseline;

optimizationSetup.modelFields = modelFields;

optimizationSetup.model = modelData;

optimizationSetup.net = net;

optimizationSetup.mu = mu;

optimizationSetup.sigma = sigma;


%% ------------------------------------------------------------
% 23. SAVE FROZEN SETUP
% ------------------------------------------------------------

setupFile = fullfile( ...
    optimizationDir, ...
    'Optimization_Setup.mat');

save( ...
    setupFile, ...
    'optimizationSetup', ...
    '-v7.3');


%% ------------------------------------------------------------
% 24. FINAL SUMMARY
% ------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' STEP 1 COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nDataset:\n');
fprintf('  660-row canonical dataset loaded and verified.\n');

fprintf('\nFeatures:\n');
fprintf('  9 input variables verified.\n');

fprintf('\nBaseline circuits:\n');
fprintf('  Low    : row %d, %.6f dB\n', ...
    lowRow, gainLowSPICE);

fprintf('  Medium : row %d, %.6f dB\n', ...
    mediumRow, gainMediumSPICE);

fprintf('  High   : row %d, %.6f dB\n', ...
    highRow, gainHighSPICE);

fprintf('\nOptimization bounds:\n');
fprintf('  Dataset-derived lower/upper bounds calculated.\n');

fprintf('\nFrozen setup saved to:\n%s\n', setupFile);

fprintf('\nIMPORTANT:\n');
fprintf(['No optimization has been performed yet.\n' ...
         'No SPICE simulation has been performed yet.\n' ...
         'No model retraining has been performed.\n']);

fprintf('\nNext stage:\n');
fprintf('Build the exact DL prediction wrapper and fmincon objective.\n');

fprintf('\n============================================================\n');
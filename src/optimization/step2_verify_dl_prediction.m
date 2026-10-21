%% ============================================================
% STEP 2 - VERIFY EXACT DL PREDICTION PIPELINE
%
% Purpose:
%   Reconstruct the exact preprocessing used to train the frozen
%   DL model and verify that raw circuit parameters can be passed
%   through the model correctly.
%
% IMPORTANT:
%   - No retraining
%   - No optimization
%   - No SPICE
%   - Uses the existing frozen DL model
%
% Preprocessing:
%   Features 1:8 -> log10
%   VCC         -> linear
%   Normalization -> mean/std of ALL 528 development samples
%
% Final output:
%   Verified DL prediction setup for optimization
%% ============================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 2 - VERIFY EXACT DL PREDICTION PIPELINE\n');
fprintf('============================================================\n\n');


%% ------------------------------------------------------------
% 1. PROJECT PATHS
% ------------------------------------------------------------

projectRoot = 'C:\Internship Project';

dlDatasetFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Dataset.mat');

splitFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Data_Split.mat');

modelFile = fullfile( ...
    projectRoot, ...
    'models', ...
    'deep_learning', ...
    'CE_Gain_DL_Model.mat');

setupFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'Optimization_Setup.mat');


%% ------------------------------------------------------------
% 2. CHECK REQUIRED FILES
% ------------------------------------------------------------

requiredFiles = { ...
    dlDatasetFile, ...
    splitFile, ...
    modelFile, ...
    setupFile};

for k = 1:numel(requiredFiles)

    if ~isfile(requiredFiles{k})

        error( ...
            'Required file not found:\n%s', ...
            requiredFiles{k});

    end

end

fprintf('Required files: PASSED\n\n');


%% ------------------------------------------------------------
% 3. LOAD DATA
% ------------------------------------------------------------

fprintf('Loading DL dataset...\n');

D = load(dlDatasetFile);

fprintf('Loading DL split information...\n');

S = load(splitFile);

fprintf('Loading trained DL model...\n');

M = load(modelFile);

fprintf('Loading optimization setup...\n');

O = load(setupFile);

fprintf('All required files loaded.\n\n');


%% ------------------------------------------------------------
% 4. LOAD NETWORK
% ------------------------------------------------------------

if ~isfield(M,'net')

    error( ...
        'Variable "net" not found in CE_Gain_DL_Model.mat.');

end

net = M.net;

fprintf('Network loaded successfully.\n');
fprintf('Network class: %s\n\n', class(net));


%% ------------------------------------------------------------
% 5. DEFINE EXACT FEATURE ORDER
% ------------------------------------------------------------

features = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};

nFeatures = numel(features);

fprintf('Feature order:\n');

for k = 1:nFeatures

    fprintf('  %d. %s\n', ...
        k, features{k});

end


%% ------------------------------------------------------------
% 6. LOAD CANONICAL RAW DATASET
% ------------------------------------------------------------

canonicalFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

if ~isfile(canonicalFile)

    error( ...
        'Canonical dataset not found:\n%s', ...
        canonicalFile);

end

fprintf('\nLoading canonical dataset...\n');

T = readtable(canonicalFile);

fprintf('Canonical dataset loaded: %d x %d\n', ...
    height(T), width(T));


if height(T) ~= 660

    error( ...
        'Expected 660 canonical rows, found %d.', ...
        height(T));

end


%% ------------------------------------------------------------
% 7. BUILD RAW FEATURE MATRIX
% ------------------------------------------------------------

XRawAll = zeros(height(T), nFeatures);

for k = 1:nFeatures

    if ~ismember(features{k}, ...
            T.Properties.VariableNames)

        error( ...
            'Feature "%s" not found in canonical dataset.', ...
            features{k});

    end

    XRawAll(:,k) = ...
        double(T.(features{k}));

end


%% ------------------------------------------------------------
% 8. LOAD RAW TARGET
% ------------------------------------------------------------

if ~ismember( ...
        'Gain_dB', ...
        T.Properties.VariableNames)

    error( ...
        'Gain_dB column not found in canonical dataset.');

end

YRawAll = double(T.Gain_dB);


%% ------------------------------------------------------------
% 9. VERIFY DL DATASET VARIABLES
% ------------------------------------------------------------

requiredDLVariables = { ...
    'X_train_norm', ...
    'X_test_norm', ...
    'Y_train', ...
    'Y_test'};

for k = 1:numel(requiredDLVariables)

    if ~isfield(D,requiredDLVariables{k})

        error( ...
            'Variable "%s" missing from DL_Dataset.mat.', ...
            requiredDLVariables{k});

    end

end

fprintf('\nDL_Dataset.mat variables: PASSED\n');


%% ------------------------------------------------------------
% 10. RECONSTRUCT FINAL 132 TEST ROWS
%
% The final test targets stored in DL_Dataset.mat are matched
% against the canonical 660-row dataset.
% ------------------------------------------------------------

YTestSaved = ...
    double(D.Y_test(:));

idxTest = ...
    false(height(T),1);


for k = 1:numel(YTestSaved)

    target = YTestSaved(k);

    match = find( ...
        ~idxTest & ...
        abs(YRawAll - target) < 1e-12, ...
        1);

    if isempty(match)

        error( ...
            ['Could not reconstruct final test row ', ...
             'for target %.15g.'], ...
            target);

    end

    idxTest(match) = true;

end


idxDevelopment = ~idxTest;


%% ------------------------------------------------------------
% 11. VERIFY DEVELOPMENT / TEST SIZES
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf(' OUTER DATA SPLIT VERIFICATION\n');
fprintf('============================================================\n');

fprintf('\nDevelopment rows : %d\n', ...
    sum(idxDevelopment));

fprintf('Test rows        : %d\n', ...
    sum(idxTest));


if sum(idxDevelopment) ~= 528

    error( ...
        'Expected 528 development rows, found %d.', ...
        sum(idxDevelopment));

end


if sum(idxTest) ~= 132

    error( ...
        'Expected 132 test rows, found %d.', ...
        sum(idxTest));

end

fprintf('\nOuter split reconstruction: PASSED\n');


%% ------------------------------------------------------------
% 12. CREATE DEVELOPMENT / TEST RAW DATA
% ------------------------------------------------------------

XDevelopmentRaw = ...
    XRawAll(idxDevelopment,:);

YDevelopmentRaw = ...
    YRawAll(idxDevelopment);

XTestRaw = ...
    XRawAll(idxTest,:);

YTestRaw = ...
    YRawAll(idxTest);


%% ------------------------------------------------------------
% 13. VERIFY TEST TARGETS
% ------------------------------------------------------------

testTargetDifference = max( ...
    abs( ...
        sort(YTestRaw(:)) - ...
        sort(YTestSaved(:)) ...
    ));


fprintf('\nTest target verification:\n');
fprintf('Maximum difference = %.15g dB\n', ...
    testTargetDifference);


if testTargetDifference > 1e-10

    error( ...
        'Canonical test targets do not match DL_Dataset.mat.');

end

fprintf('Test target verification: PASSED\n');


%% ------------------------------------------------------------
% 14. EXACT LOG TRANSFORMATION
%
% The original DL preprocessing uses:
%
%   R1,R2,RC,RE,RL,Cin,Cout,Ce -> log10
%   VCC                         -> linear
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf(' RECONSTRUCTING DL PREPROCESSING\n');
fprintf('============================================================\n');


if any( ...
        XDevelopmentRaw(:,1:8) <= 0, ...
        'all')

    error( ...
        'Non-positive development value found in first 8 features.');

end


if any( ...
        XTestRaw(:,1:8) <= 0, ...
        'all')

    error( ...
        'Non-positive test value found in first 8 features.');

end


XDevelopmentLog = ...
    XDevelopmentRaw;

XTestLog = ...
    XTestRaw;


XDevelopmentLog(:,1:8) = ...
    log10(XDevelopmentRaw(:,1:8));


XTestLog(:,1:8) = ...
    log10(XTestRaw(:,1:8));


fprintf('\nLog transformation: PASSED\n');
fprintf('  First 8 features : log10\n');
fprintf('  VCC               : linear\n');


%% ------------------------------------------------------------
% 15. RECONSTRUCT EXACT NORMALIZATION
%
% IMPORTANT:
%
% The normalization was based on ALL 528 DEVELOPMENT samples.
%
% It was NOT based on:
%   - 423 training samples
%   - 105 validation samples
%   - 132 test samples
%   - all 660 samples
% ------------------------------------------------------------

mu = ...
    mean(XDevelopmentLog,1);

sigma = ...
    std( ...
        XDevelopmentLog, ...
        0, ...
        1);


if any(sigma == 0)

    error( ...
        'At least one feature has zero standard deviation.');

end


fprintf('\nNormalization statistics reconstructed.\n');

fprintf('\nmu =\n');
disp(mu);

fprintf('sigma =\n');
disp(sigma);


%% ------------------------------------------------------------
% 16. RECONSTRUCT NORMALIZED DEVELOPMENT DATA
% ------------------------------------------------------------

XDevelopmentNorm = ...
    (XDevelopmentLog - mu) ./ sigma;


%% ------------------------------------------------------------
% 17. VERIFY NORMALIZATION AGAINST DL_DATASET.MAT
% ------------------------------------------------------------

storedDevelopmentNorm = ...
    double(D.X_train_norm);


normalizationDifference = max( ...
    abs( ...
        XDevelopmentNorm(:) - ...
        storedDevelopmentNorm(:) ...
    ));


fprintf('\n');
fprintf('============================================================\n');
fprintf(' NORMALIZATION VERIFICATION\n');
fprintf('============================================================\n');

fprintf('\nMaximum difference = %.15g\n', ...
    normalizationDifference);


if normalizationDifference > 1e-10

    error( ...
        ['NORMALIZATION VERIFICATION FAILED.\n' ...
         'Maximum difference = %.15g'], ...
        normalizationDifference);

end


fprintf('Normalization verification: PASSED\n');


%% ------------------------------------------------------------
% 18. CREATE DL PREDICTION FUNCTION
% ------------------------------------------------------------

predictDLGain = @(X) ...
    predictDLRaw( ...
        net, ...
        X, ...
        mu, ...
        sigma);


%% ------------------------------------------------------------
% 19. PREDICT ALL 132 TEST CIRCUITS
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf(' TESTING DL PREDICTION WRAPPER\n');
fprintf('============================================================\n');


YPredTestWrapper = ...
    predictDLGain(XTestRaw);


if any(~isfinite(YPredTestWrapper))

    error( ...
        'DL wrapper produced NaN or Inf predictions.');

end


fprintf('\nPredictions generated: %d\n', ...
    numel(YPredTestWrapper));


%% ------------------------------------------------------------
% 20. COMPARE AGAINST ORIGINAL SAVED PREDICTIONS
% ------------------------------------------------------------

trainingResultsFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning', ...
    'DL_Training_Results.mat');


predictionDifference = NaN;


if isfile(trainingResultsFile)

    R = load(trainingResultsFile);


    if isfield(R,'YPredTest')

        YPredTestOriginal = ...
            double(R.YPredTest(:));


        if numel(YPredTestOriginal) ~= ...
                numel(YPredTestWrapper)

            error( ...
                ['Original and wrapper prediction sizes ', ...
                 'are different.']);

        end


        predictionDifference = max( ...
            abs( ...
                YPredTestWrapper(:) - ...
                YPredTestOriginal(:) ...
            ));


        fprintf('\n');
        fprintf('Original-vs-wrapper prediction check:\n');

        fprintf( ...
            'Maximum difference = %.15g dB\n', ...
            predictionDifference);


        if predictionDifference > 1e-6

            error( ...
                ['DL prediction wrapper verification FAILED.\n' ...
                 'Maximum difference = %.15g dB'], ...
                predictionDifference);

        end


        fprintf( ...
            'Prediction wrapper verification: PASSED\n');

    else

        warning( ...
            'YPredTest not found in DL_Training_Results.mat.');

    end

else

    warning( ...
        'DL_Training_Results.mat not found.');

end


%% ------------------------------------------------------------
% 21. TEST THE THREE REPRESENTATIVE CIRCUITS
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf(' REPRESENTATIVE CIRCUIT PREDICTIONS\n');
fprintf('============================================================\n');


lowRow = 409;
mediumRow = 527;
highRow = 536;


xLow = ...
    T{lowRow,features};

xMedium = ...
    T{mediumRow,features};

xHigh = ...
    T{highRow,features};


predLow = ...
    predictDLGain(xLow);

predMedium = ...
    predictDLGain(xMedium);

predHigh = ...
    predictDLGain(xHigh);


actualLow = ...
    T.Gain_dB(lowRow);

actualMedium = ...
    T.Gain_dB(mediumRow);

actualHigh = ...
    T.Gain_dB(highRow);


fprintf('\n');
fprintf( ...
    '%-10s %-18s %-18s %-18s\n', ...
    'Case', ...
    'Actual SPICE', ...
    'DL Prediction', ...
    'Error');

fprintf('%s\n', ...
    repmat('-',1,70));


fprintf( ...
    '%-10s %-18.6f %-18.6f %-18.6f\n', ...
    'Low', ...
    actualLow, ...
    predLow, ...
    predLow - actualLow);


fprintf( ...
    '%-10s %-18.6f %-18.6f %-18.6f\n', ...
    'Medium', ...
    actualMedium, ...
    predMedium, ...
    predMedium - actualMedium);


fprintf( ...
    '%-10s %-18.6f %-18.6f %-18.6f\n', ...
    'High', ...
    actualHigh, ...
    predHigh, ...
    predHigh - actualHigh);


%% ------------------------------------------------------------
% 22. SAVE VERIFIED OPTIMIZATION PREDICTION SETUP
% ------------------------------------------------------------

optimizationDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization');


if ~isfolder(optimizationDir)

    mkdir(optimizationDir);

end


verifiedSetupFile = fullfile( ...
    optimizationDir, ...
    'DL_Optimization_Prediction_Setup.mat');


save( ...
    verifiedSetupFile, ...
    'net', ...
    'mu', ...
    'sigma', ...
    'features', ...
    'predictDLGain', ...
    'YPredTestWrapper', ...
    'predictionDifference', ...
    'lowRow', ...
    'mediumRow', ...
    'highRow', ...
    'predLow', ...
    'predMedium', ...
    'predHigh', ...
    'actualLow', ...
    'actualMedium', ...
    'actualHigh', ...
    '-v7.3');


%% ------------------------------------------------------------
% 23. FINAL SUMMARY
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 2 COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nPreprocessing:\n');
fprintf('  log10(first 8 features) : YES\n');
fprintf('  VCC remains linear      : YES\n');
fprintf('  normalization samples   : 528 development\n');

fprintf('\nVerification:\n');
fprintf('  Outer split             : PASSED\n');
fprintf('  Test target mapping     : PASSED\n');
fprintf('  Normalization           : PASSED\n');
fprintf('  DL prediction wrapper   : PASSED\n');

if isfinite(predictionDifference)

    fprintf( ...
        '  Max prediction difference: %.15g dB\n', ...
        predictionDifference);

end

fprintf('\nVerified setup saved to:\n');
fprintf('%s\n', verifiedSetupFile);

fprintf('\nNO OPTIMIZATION HAS BEEN PERFORMED.\n');
fprintf('NO SPICE SIMULATION HAS BEEN PERFORMED.\n');
fprintf('NO MODEL RETRAINING HAS BEEN PERFORMED.\n');

fprintf('\nNext step:\n');
fprintf('Build the fmincon objective and physical constraints.\n');

fprintf('\n============================================================\n');


%% ============================================================
% LOCAL FUNCTION
% ============================================================

function Y = predictDLRaw(net,X,mu,sigma)

    % Convert raw input to double
    X = double(X);

    % Exact transformation used during DL preprocessing
    X(:,1:8) = ...
        log10(X(:,1:8));

    % Exact normalization
    X = ...
        (X - mu) ./ sigma;

    % Existing frozen DL network
    Y = predict( ...
        net, ...
        single(X));

    % One prediction per observation
    Y = double(Y(:));

end
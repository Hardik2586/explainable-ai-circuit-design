%% dl_shap_analysis.m
% ================================================================
% Explainable AI Framework for Electronic Circuit Understanding
% and Design Optimization
%
% CE BJT Amplifier - Deep Learning SHAP Analysis
%
% MATLAB R2025b
%
% Model:
%   9 -> 64 -> 32 -> 16 -> 1
%
% Dataset:
%   660 valid CE amplifier circuits
%
% Split:
%   528 development
%       423 training
%       105 validation
%   132 final test
%
% XAI:
%   MATLAB built-in shapley
%
% IMPORTANT:
%   The DL dataset was normalized using the COMPLETE 528-row
%   development set before the 423/105 training-validation split.
%
% Therefore SHAP preprocessing MUST use the 528 development
% samples to reconstruct the normalization statistics.
% ================================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('=============================================\n');
fprintf('       CE AMPLIFIER - DL SHAP ANALYSIS\n');
fprintf('=============================================\n\n');


%% ================================================================
% 1. PROJECT PATHS
% ================================================================

% This script is currently located directly in:
%
% C:\Internship Project\
%
% Therefore this directory itself is the project root.

scriptDir = fileparts(mfilename('fullpath'));

projectRoot = scriptDir;

dataDir = fullfile( ...
    projectRoot, ...
    'data', ...
    'final');

dlResultDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning');

modelDir = fullfile( ...
    projectRoot, ...
    'models', ...
    'deep_learning');

shapDir = fullfile( ...
    dlResultDir, ...
    'shap');

if ~exist(shapDir,'dir')
    mkdir(shapDir);
end


%% ================================================================
% 2. FILE PATHS
% ================================================================

dlDatasetFile = fullfile( ...
    dlResultDir, ...
    'DL_Dataset.mat');

splitFile = fullfile( ...
    dlResultDir, ...
    'DL_Data_Split.mat');

modelFile = fullfile( ...
    modelDir, ...
    'CE_Gain_DL_Model.mat');

canonicalFile = fullfile( ...
    dataDir, ...
    'CE_Amplifier_ML_Valid.csv');


%% ================================================================
% 3. CHECK REQUIRED FILES
% ================================================================

requiredFiles = { ...
    dlDatasetFile, ...
    splitFile, ...
    modelFile, ...
    canonicalFile};

requiredNames = { ...
    'DL_Dataset.mat', ...
    'DL_Data_Split.mat', ...
    'CE_Gain_DL_Model.mat', ...
    'CE_Amplifier_ML_Valid.csv'};

for k = 1:numel(requiredFiles)

    if ~isfile(requiredFiles{k})

        error( ...
            'Required file not found:\n%s\n\nExpected file:\n%s', ...
            requiredFiles{k}, ...
            requiredNames{k});

    end

end


%% ================================================================
% 4. LOAD DL DATASET
% ================================================================

fprintf('Loading DL dataset...\n');

D = load(dlDatasetFile);

fprintf('DL dataset loaded successfully.\n');


%% ================================================================
% 5. VERIFY REQUIRED VARIABLES
% ================================================================

requiredVariables = { ...
    'X_train_norm', ...
    'X_test_norm', ...
    'Y_train', ...
    'Y_test', ...
    'featureNames', ...
    'targetName'};

for k = 1:numel(requiredVariables)

    if ~isfield(D,requiredVariables{k})

        error( ...
            'Variable "%s" is missing from DL_Dataset.mat.', ...
            requiredVariables{k});

    end

end


%% ================================================================
% 6. LOAD SPLIT INFORMATION
% ================================================================

fprintf('Loading DL split information...\n');

S = load(splitFile);

if ~isfield(S,'idxTrain') || ~isfield(S,'idxValidation')

    error( ...
        ['DL_Data_Split.mat must contain idxTrain and ', ...
         'idxValidation.']);

end

idxTrain = logical(S.idxTrain);
idxValidation = logical(S.idxValidation);


%% ================================================================
% 7. LOAD TRAINED DL MODEL
% ================================================================

fprintf('Loading trained DL model...\n');

M = load(modelFile);

if ~isfield(M,'net')

    error( ...
        'Variable "net" was not found in CE_Gain_DL_Model.mat.');

end

net = M.net;

fprintf('\nNetwork loaded successfully.\n');
fprintf('Network class: %s\n',class(net));


%% ================================================================
% 8. DEFINE FEATURES
% ================================================================

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


%% ================================================================
% 9. LOAD CANONICAL RAW DATASET
% ================================================================

fprintf('\nLoading canonical raw circuit dataset...\n');

T = readtable(canonicalFile);

fprintf('\nCanonical dataset: %d x %d\n', ...
    height(T),width(T));

if height(T) ~= 660

    warning( ...
        'Expected 660 canonical rows, found %d.', ...
        height(T));

end


%% ================================================================
% 10. BUILD RAW FEATURE MATRIX
% ================================================================

XRawAll = zeros(height(T),nFeatures);

for k = 1:nFeatures

    if ~ismember(features{k},T.Properties.VariableNames)

        error( ...
            'Feature "%s" not found in canonical dataset.', ...
            features{k});

    end

    XRawAll(:,k) = double(T.(features{k}));

end


%% ================================================================
% 11. VERIFY TARGET
% ================================================================

if ~ismember('Gain_dB',T.Properties.VariableNames)

    error('Gain_dB column not found in canonical dataset.');

end

YRawAll = double(T.Gain_dB);


%% ================================================================
% 12. RECONSTRUCT ORIGINAL 660-ROW PARTITION
% ================================================================

% The original DL training pipeline used:
%
% rng(42,'twister')
% cvpartition(NDevelopment,'HoldOut',0.20)
%
% where NDevelopment = 528.
%
% The final 132 test rows were already separated in DL_Dataset.mat.
%
% We reconstruct this exact outer split by comparing the stored
% normalized test targets against the canonical raw target vector.

fprintf('\nOriginal 660-row partition reconstructed.\n');


%% ------------------------------------------------
% Identify the 132 final test rows
% ------------------------------------------------

YTestSaved = double(D.Y_test(:));

NAll = height(T);

idxTest = false(NAll,1);

remainingRows = (1:NAll)';

for k = 1:numel(YTestSaved)

    target = YTestSaved(k);

    match = find( ...
        ~idxTest & ...
        abs(YRawAll - target) < 1e-12, ...
        1);

    if isempty(match)

        error( ...
            ['Could not uniquely reconstruct final test row ', ...
             'for target %.15g.'], ...
            target);

    end

    idxTest(match) = true;

end


%% ------------------------------------------------
% Development rows
% ------------------------------------------------

idxDevelopment = ~idxTest;


fprintf('Development rows : %d\n',sum(idxDevelopment));
fprintf('Test rows        : %d\n',sum(idxTest));


if sum(idxDevelopment) ~= 528

    error( ...
        'Expected 528 development rows but reconstructed %d.', ...
        sum(idxDevelopment));

end

if sum(idxTest) ~= 132

    error( ...
        'Expected 132 test rows but reconstructed %d.', ...
        sum(idxTest));

end


%% ================================================================
% 13. CREATE RAW DEVELOPMENT / TEST DATA
% ================================================================

XDevelopmentRaw = XRawAll(idxDevelopment,:);

YDevelopmentRaw = YRawAll(idxDevelopment);

XTestRaw = XRawAll(idxTest,:);

YTestRaw = YRawAll(idxTest);


%% ================================================================
% 14. VERIFY TEST TARGETS AGAINST DL DATASET
% ================================================================

testDifference = max( ...
    abs(sort(YTestRaw(:)) - ...
        sort(YTestSaved(:))));

fprintf('\nTest target verification:\n');
fprintf('Maximum difference = %.15g dB\n', ...
    testDifference);

if testDifference > 1e-10

    error( ...
        'Canonical test targets do not match DL_Dataset.mat.');

end


%% ================================================================
% 15. TRAIN / VALIDATION INDICES
% ================================================================

if numel(idxTrain) ~= 528

    error( ...
        'idxTrain has %d elements. Expected 528.', ...
        numel(idxTrain));

end

if numel(idxValidation) ~= 528

    error( ...
        'idxValidation has %d elements. Expected 528.', ...
        numel(idxValidation));

end


if sum(idxTrain) ~= 423

    error( ...
        'Expected 423 training rows, found %d.', ...
        sum(idxTrain));

end

if sum(idxValidation) ~= 105

    error( ...
        'Expected 105 validation rows, found %d.', ...
        sum(idxValidation));

end


%% ================================================================
% 16. SHAP BACKGROUND / QUERY SETS
% ================================================================

% IMPORTANT:
%
% Background:
%   423 training circuits only.
%
% Query points:
%   132 final test circuits.
%
% The final test set is therefore not used as SHAP background.

XBackgroundRaw = ...
    XDevelopmentRaw(idxTrain,:);

YBackground = ...
    YDevelopmentRaw(idxTrain);

XQueryRaw = XTestRaw;

YQueryActual = YTestRaw;


fprintf('\n');
fprintf('SHAP background samples : %d\n', ...
    size(XBackgroundRaw,1));

fprintf('SHAP query samples      : %d\n', ...
    size(XQueryRaw,1));


%% ================================================================
% 17. RECONSTRUCT EXACT DL PREPROCESSING
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       CHECKING DL PREPROCESSING\n');
fprintf('=============================================\n');


% ------------------------------------------------
% Log transformation
% ------------------------------------------------

XDevelopmentLog = XDevelopmentRaw;

XTestLog = XTestRaw;

for k = 1:8

    if any(XDevelopmentRaw(:,k) <= 0)

        error( ...
            'Non-positive value found in development feature %s.', ...
            features{k});

    end

    if any(XTestRaw(:,k) <= 0)

        error( ...
            'Non-positive value found in test feature %s.', ...
            features{k});

    end

end


XDevelopmentLog(:,1:8) = ...
    log10(XDevelopmentRaw(:,1:8));

XTestLog(:,1:8) = ...
    log10(XTestRaw(:,1:8));


% ------------------------------------------------
% IMPORTANT:
%
% The normalization used to generate DL_Dataset.mat
% was based on ALL 528 DEVELOPMENT rows.
% ------------------------------------------------

mu = mean(XDevelopmentLog,1);

sigma = std( ...
    XDevelopmentLog, ...
    0, ...
    1);


fprintf('\nFeature means:\n');
disp(mu);

fprintf('Feature standard deviations:\n');
disp(sigma);


% ------------------------------------------------
% Protect against zero standard deviation
% ------------------------------------------------

if any(sigma == 0)

    error( ...
        'At least one feature has zero standard deviation.');

end


% ------------------------------------------------
% Reconstruct development normalization
% ------------------------------------------------

XDevelopmentNorm = ...
    (XDevelopmentLog - mu) ./ sigma;


%% ================================================================
% 18. VERIFY EXACT NORMALIZATION
% ================================================================

normalizationDifference = max( ...
    abs( ...
        XDevelopmentNorm(:) - ...
        double(D.X_train_norm(:)) ...
    ));


fprintf('\n');
fprintf('Normalization verification:\n');
fprintf('Maximum difference = %.15g\n', ...
    normalizationDifference);


if normalizationDifference > 1e-10

    error( ...
        ['Reconstructed preprocessing does not match ', ...
         'DL_Dataset.mat.\nMaximum difference = %.15g'], ...
        normalizationDifference);

end


fprintf('Preprocessing reconstruction PASSED.\n');


%% ================================================================
% 19. VERIFY STORED TRAIN / VALIDATION SPLIT
% ================================================================

storedTrain = double(D.X_train_norm(idxTrain,:));

reconstructedTrain = ...
    XDevelopmentNorm(idxTrain,:);

trainDifference = max( ...
    abs( ...
        storedTrain(:) - ...
        reconstructedTrain(:) ...
    ));


storedValidation = ...
    double(D.X_train_norm(idxValidation,:));

reconstructedValidation = ...
    XDevelopmentNorm(idxValidation,:);

validationDifference = max( ...
    abs( ...
        storedValidation(:) - ...
        reconstructedValidation(:) ...
    ));


fprintf('\nTraining normalization verification:\n');
fprintf('Maximum difference = %.15g\n', ...
    trainDifference);

fprintf('\nValidation normalization verification:\n');
fprintf('Maximum difference = %.15g\n', ...
    validationDifference);


if trainDifference > 1e-10 || ...
   validationDifference > 1e-10

    error( ...
        'Training/validation normalization verification failed.');

end


%% ================================================================
% 20. CREATE DL PREDICTION WRAPPER
% ================================================================

% SHAP works with the RAW physical parameters.
%
% The wrapper internally performs:
%
% RAW COMPONENT VALUES
%       ↓
% log10(first 8 features)
%       ↓
% normalization using 528 development statistics
%       ↓
% trained dlnetwork
%       ↓
% Gain_dB prediction

predictDL = ...
    @(X) predictDLRaw( ...
        net, ...
        X, ...
        mu, ...
        sigma);


%% ================================================================
% 21. VERIFY PREDICTION WRAPPER
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       VERIFYING DL PREDICTION WRAPPER\n');
fprintf('=============================================\n');


% Direct prediction using stored normalized test data
directPrediction = ...
    predict( ...
        net, ...
        single(D.X_test_norm));


directPrediction = ...
    double(directPrediction(:));


% Prediction through raw-data wrapper
wrapperPrediction = ...
    predictDL(XTestRaw);


wrapperPrediction = ...
    double(wrapperPrediction(:));


predictionDifference = max( ...
    abs( ...
        directPrediction - ...
        wrapperPrediction ...
    ));


fprintf('\nPrediction wrapper verification:\n');
fprintf('Maximum difference = %.15g dB\n', ...
    predictionDifference);


if predictionDifference > 1e-5

    error( ...
        ['Prediction wrapper does not reproduce the ', ...
         'trained DL model.\nMaximum difference = %.15g dB'], ...
        predictionDifference);

end


fprintf('Prediction wrapper PASSED.\n');


%% ================================================================
% 22. TEST SET PREDICTION CHECK
% ================================================================

fprintf('\nGenerating final test predictions...\n');

YTestPred = predictDL(XTestRaw);

YTestPred = double(YTestPred(:));


testRMSE = sqrt( ...
    mean( ...
        (YTestPred - YQueryActual).^2 ...
    ));

testMAE = mean( ...
    abs( ...
        YTestPred - YQueryActual ...
    ));


testR2 = 1 - ...
    sum((YTestPred-YQueryActual).^2) / ...
    sum((YQueryActual-mean(YQueryActual)).^2);


fprintf('\nDL TEST PERFORMANCE CHECK\n');
fprintf('R^2   = %.6f\n',testR2);
fprintf('RMSE  = %.6f dB\n',testRMSE);
fprintf('MAE   = %.6f dB\n',testMAE);


%% ================================================================
% 23. CREATE SHAP EXPLAINER
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       CREATING DL SHAP EXPLAINER\n');
fprintf('=============================================\n');

fprintf('\nCreating MATLAB SHAP explainer...\n');

rng(42,'twister');

explainer = shapley( ...
    predictDL, ...
    XBackgroundRaw, ...
    QueryPoints=XQueryRaw, ...
    NumObservationsToSample="all");


fprintf('\nSHAP explainer created successfully.\n');

fprintf('SHAP method:\n');
disp(explainer.Method);

fprintf('SHAP intercept / baseline prediction:\n');
fprintf('%.8f dB\n', ...
    double(explainer.Intercept));


%% ================================================================
% 24. EXTRACT GLOBAL SHAP IMPORTANCE
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       GLOBAL DL SHAP IMPORTANCE\n');
fprintf('=============================================\n');


meanAbsTable = ...
    explainer.MeanAbsoluteShapley;


fprintf('\nMATLAB MeanAbsoluteShapley table:\n');
disp(meanAbsTable);


%% ------------------------------------------------
% Extract predictor names and values robustly
% ------------------------------------------------

predictorColumn = ...
    meanAbsTable.Properties.VariableNames{1};

valueColumn = ...
    meanAbsTable.Properties.VariableNames{2};


predictorValues = ...
    meanAbsTable.(predictorColumn);

importanceValues = ...
    double(meanAbsTable.(valueColumn));


% Convert names to string
predictorValues = string(predictorValues);


%% ------------------------------------------------
% Map x1...x9 to physical feature names if necessary
% ------------------------------------------------

mappedNames = strings( ...
    numel(predictorValues),1);


for k = 1:numel(predictorValues)

    name = predictorValues(k);

    if startsWith(name,"x")

        idx = str2double( ...
            extractAfter(name,1));

        if idx >= 1 && idx <= nFeatures

            mappedNames(k) = ...
                string(features{idx});

        else

            mappedNames(k) = name;

        end

    else

        mappedNames(k) = name;

    end

end


%% ================================================================
% 25. SORT GLOBAL SHAP IMPORTANCE
% ================================================================

[sortedImportance,sortIdx] = ...
    sort( ...
        importanceValues, ...
        'descend');


sortedNames = ...
    mappedNames(sortIdx);


GlobalSHAP = table( ...
    sortedNames, ...
    sortedImportance, ...
    (1:numel(sortedNames))', ...
    'VariableNames',{ ...
        'Parameter', ...
        'MeanAbsoluteSHAP', ...
        'SHAP_Rank'});


fprintf('\n');
fprintf('GLOBAL DL SHAP RANKING\n');
fprintf('=============================================\n');

for k = 1:height(GlobalSHAP)

    fprintf( ...
        '%d. %-5s Mean |SHAP| = %.6f dB\n', ...
        GlobalSHAP.SHAP_Rank(k), ...
        GlobalSHAP.Parameter(k), ...
        GlobalSHAP.MeanAbsoluteSHAP(k));

end


%% ================================================================
% 26. EXTRACT INDIVIDUAL SHAP VALUES
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       EXTRACTING INDIVIDUAL SHAP VALUES\n');
fprintf('=============================================\n');


shapTable = explainer.Shapley;

fprintf('\nSHAP table returned by MATLAB:\n');
disp(shapTable);


%% ------------------------------------------------
% MATLAB returns a predictor/value table for each
% query point. Handle both orientations robustly.
% ------------------------------------------------

if ~istable(shapTable)

    error( ...
        'Unexpected SHAP output type: %s', ...
        class(shapTable));

end


shapVarNames = ...
    shapTable.Properties.VariableNames;


if numel(shapVarNames) < 2

    error( ...
        'Unexpected SHAP table format.');

end


shapPredictorColumn = ...
    shapVarNames{1};

shapValueColumn = ...
    shapVarNames{2};


shapPredictors = ...
    string(shapTable.(shapPredictorColumn));

shapValuesRaw = ...
    shapTable.(shapValueColumn);


%% ================================================================
% 27. HANDLE MULTIPLE QUERY-POINT SHAP OUTPUT
% ================================================================

% Depending on MATLAB's representation, the Shapley table can
% contain all query-point values in a matrix/cell representation.
%
% We convert it into:
%
%       132 x 9
%
% where each row = one test circuit
% and each column = one physical feature.

if isnumeric(shapValuesRaw)

    A = double(shapValuesRaw);

elseif iscell(shapValuesRaw)

    try

        A = cell2mat(shapValuesRaw);

    catch

        error( ...
            ['SHAP Value column is a cell array but could not ', ...
             'be converted to numeric values.']);

    end

else

    error( ...
        'Unsupported SHAP Value data type: %s', ...
        class(shapValuesRaw));

end


nQuery = size(XQueryRaw,1);


%% ------------------------------------------------
% Case 1:
% 9 x 132
% ------------------------------------------------

if isequal(size(A),[nFeatures,nQuery])

    LocalSHAP = A';


%% ------------------------------------------------
% Case 2:
% 132 x 9
% ------------------------------------------------

elseif isequal(size(A),[nQuery,nFeatures])

    LocalSHAP = A;


%% ------------------------------------------------
% Case 3:
% 9 x 1
% ------------------------------------------------

elseif isequal(size(A),[nFeatures,1]) && nQuery == 1

    LocalSHAP = A';


else

    fprintf('\nUnexpected SHAP numeric dimensions:\n');
    disp(size(A));

    error( ...
        ['Could not map SHAP values to ', ...
         '%d query points x %d features.'], ...
        nQuery,nFeatures);

end


%% ================================================================
% 28. MAP SHAP COLUMNS TO PHYSICAL FEATURES
% ================================================================

% MATLAB predictor order should match XBackgroundRaw.
%
% Since XBackgroundRaw is a numeric matrix, the predictor order is:
%
% 1 R1
% 2 R2
% 3 RC
% 4 RE
% 5 RL
% 6 Cin
% 7 Cout
% 8 Ce
% 9 VCC

if size(LocalSHAP,2) ~= nFeatures

    error( ...
        'SHAP feature count mismatch.');

end


%% ================================================================
% 29. VERIFY SHAP ADDITIVITY
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       VERIFYING SHAP ADDITIVITY\n');
fprintf('=============================================\n');


shapBaseline = ...
    double(explainer.Intercept);


shapReconstructedPrediction = ...
    shapBaseline + ...
    sum(LocalSHAP,2);


additivityDifference = ...
    max( ...
        abs( ...
            shapReconstructedPrediction - ...
            YTestPred ...
        ));


fprintf('\nMaximum SHAP additivity error:\n');
fprintf('%.15g dB\n',additivityDifference);


if additivityDifference > 1e-4

    warning( ...
        ['SHAP additivity difference is %.6g dB. ', ...
         'Inspect MATLAB SHAP output representation.'], ...
        additivityDifference);

else

    fprintf('SHAP additivity verification PASSED.\n');

end


%% ================================================================
% 30. SAVE RAW SHAP RESULTS
% ================================================================

rawSHAPFile = fullfile( ...
    shapDir, ...
    'DL_SHAP_Results.mat');


save( ...
    rawSHAPFile, ...
    'explainer', ...
    'LocalSHAP', ...
    'XBackgroundRaw', ...
    'XQueryRaw', ...
    'YQueryActual', ...
    'YTestPred', ...
    'features', ...
    'mu', ...
    'sigma', ...
    'testR2', ...
    'testRMSE', ...
    'testMAE', ...
    'additivityDifference', ...
    '-v7.3');


fprintf('\nRaw SHAP results saved:\n');
fprintf('%s\n',rawSHAPFile);


%% ================================================================
% 31. SAVE GLOBAL SHAP CSV
% ================================================================

globalCSV = fullfile( ...
    shapDir, ...
    'DL_SHAP_Global_Ranking.csv');


writetable( ...
    GlobalSHAP, ...
    globalCSV);


fprintf('\nGlobal SHAP ranking saved:\n');
fprintf('%s\n',globalCSV);


%% ================================================================
% 32. CREATE GLOBAL SHAP BAR PLOT
% ================================================================

fprintf('\nCreating global SHAP importance plot...\n');


figure( ...
    'Name','DL Global SHAP Importance', ...
    'Color','w');


bar( ...
    categorical( ...
        GlobalSHAP.Parameter, ...
        GlobalSHAP.Parameter), ...
    GlobalSHAP.MeanAbsoluteSHAP);


xlabel('Circuit Parameter');
ylabel('Mean |SHAP| Contribution (dB)');

title( ...
    'Deep Learning Global SHAP Feature Importance');


grid on;

set(gca, ...
    'FontSize',11);


globalPlot = fullfile( ...
    shapDir, ...
    'DL_Global_SHAP_Importance.png');


exportgraphics( ...
    gcf, ...
    globalPlot, ...
    'Resolution',300);


fprintf('Saved:\n%s\n',globalPlot);


%% ================================================================
% 33. SHAP DEPENDENCE ANALYSIS
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       SHAP DEPENDENCE ANALYSIS\n');
fprintf('=============================================\n');


DependenceResults = table( ...
    strings(nFeatures,1), ...
    zeros(nFeatures,1), ...
    zeros(nFeatures,1), ...
    zeros(nFeatures,1), ...
    zeros(nFeatures,1), ...
    zeros(nFeatures,1), ...
    'VariableNames',{ ...
        'Parameter', ...
        'MeanAbsSHAP', ...
        'MeanSHAP', ...
        'MinSHAP', ...
        'MaxSHAP', ...
        'SpearmanRho'});


for k = 1:nFeatures

    rawFeature = ...
        XQueryRaw(:,k);

    shapFeature = ...
        LocalSHAP(:,k);


    rho = corr( ...
        rawFeature, ...
        shapFeature, ...
        'Type','Spearman', ...
        'Rows','complete');


    DependenceResults.Parameter(k) = ...
        string(features{k});

    DependenceResults.MeanAbsSHAP(k) = ...
        mean(abs(shapFeature));

    DependenceResults.MeanSHAP(k) = ...
        mean(shapFeature);

    DependenceResults.MinSHAP(k) = ...
        min(shapFeature);

    DependenceResults.MaxSHAP(k) = ...
        max(shapFeature);

    DependenceResults.SpearmanRho(k) = ...
        rho;


    fprintf('\n%s\n',features{k});

    fprintf( ...
        '  Mean |SHAP|  = %.6f dB\n', ...
        DependenceResults.MeanAbsSHAP(k));

    fprintf( ...
        '  Mean SHAP    = %+ .6f dB\n', ...
        DependenceResults.MeanSHAP(k));

    fprintf( ...
        '  Min SHAP     = %+ .6f dB\n', ...
        DependenceResults.MinSHAP(k));

    fprintf( ...
        '  Max SHAP     = %+ .6f dB\n', ...
        DependenceResults.MaxSHAP(k));

    fprintf( ...
        '  Spearman rho = %+ .6f\n', ...
        rho);

end


%% ================================================================
% 34. SORT DEPENDENCE RESULTS
% ================================================================

[~,dependenceOrder] = ...
    sort( ...
        DependenceResults.MeanAbsSHAP, ...
        'descend');


DependenceResults = ...
    DependenceResults(dependenceOrder,:);


%% ================================================================
% 35. SAVE DEPENDENCE CSV
% ================================================================

dependenceCSV = fullfile( ...
    shapDir, ...
    'DL_SHAP_Dependence_Statistics.csv');


writetable( ...
    DependenceResults, ...
    dependenceCSV);


fprintf('\nDependence statistics saved:\n');
fprintf('%s\n',dependenceCSV);


%% ================================================================
% 36. CREATE DEPENDENCE PLOTS
% ================================================================

fprintf('\n');
fprintf('Creating SHAP dependence plots...\n');


for k = 1:nFeatures

    featureName = ...
        features{k};

    rawFeature = ...
        XQueryRaw(:,k);

    shapFeature = ...
        LocalSHAP(:,k);


    figure( ...
        'Name', ...
        ['SHAP Dependence - ',featureName], ...
        'Color','w');


    scatter( ...
        rawFeature, ...
        shapFeature, ...
        28, ...
        'filled');


    xlabel( ...
        [featureName,' (raw physical value)']);

    ylabel( ...
        'SHAP Value (dB)');

    title( ...
        ['DL SHAP Dependence: ',featureName]);


    grid on;

    set(gca, ...
        'FontSize',11);


    plotFile = fullfile( ...
        shapDir, ...
        ['DL_SHAP_Dependence_', ...
         featureName,'.png']);


    exportgraphics( ...
        gcf, ...
        plotFile, ...
        'Resolution',300);


    close(gcf);

end


fprintf('Dependence plots saved.\n');


%% ================================================================
% 37. SAVE LOCAL SHAP MATRIX AS CSV
% ================================================================

localCSV = fullfile( ...
    shapDir, ...
    'DL_SHAP_Local_Values.csv');


LocalSHAPTable = ...
    array2table( ...
        LocalSHAP, ...
        'VariableNames',features);


LocalSHAPTable.TestActualGain_dB = ...
    YQueryActual;

LocalSHAPTable.TestPredictedGain_dB = ...
    YTestPred;


writetable( ...
    LocalSHAPTable, ...
    localCSV);


fprintf('\nLocal SHAP values saved:\n');
fprintf('%s\n',localCSV);


%% ================================================================
% 38. LOCAL SHAP REPRESENTATIVE TEST CIRCUITS
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       LOCAL SHAP REPRESENTATIVES\n');
fprintf('=============================================\n');


% Find low / medium / high gain test circuits.

[~,lowIdx] = ...
    min(YQueryActual);

[~,highIdx] = ...
    max(YQueryActual);


targetMedium = ...
    median(YQueryActual);

[~,mediumIdx] = ...
    min(abs(YQueryActual-targetMedium));


representativeIdx = [ ...
    lowIdx, ...
    mediumIdx, ...
    highIdx];


representativeNames = { ...
    'Low_Gain', ...
    'Medium_Gain', ...
    'High_Gain'};


for r = 1:numel(representativeIdx)

    idx = representativeIdx(r);

    fprintf('\n%s\n', ...
        representativeNames{r});

    fprintf( ...
        'Test sample index : %d\n', ...
        idx);

    fprintf( ...
        'Actual gain       : %.6f dB\n', ...
        YQueryActual(idx));

    fprintf( ...
        'Predicted gain    : %.6f dB\n', ...
        YTestPred(idx));

    fprintf( ...
        'Prediction error  : %+ .6f dB\n', ...
        YTestPred(idx)-YQueryActual(idx));


    localValues = ...
        LocalSHAP(idx,:);


    [sortedLocal,localOrder] = ...
        sort(abs(localValues), ...
        'descend');


    fprintf('\nLocal SHAP ranking:\n');

    for j = 1:nFeatures

        fidx = localOrder(j);

        fprintf( ...
            '%d. %-5s %+ .6f dB\n', ...
            j, ...
            features{fidx}, ...
            localValues(fidx));

    end

end


%% ================================================================
% 39. CREATE LOCAL SHAP BAR PLOTS
% ================================================================

for r = 1:numel(representativeIdx)

    idx = representativeIdx(r);

    localValues = ...
        LocalSHAP(idx,:);


    [~,order] = ...
        sort(abs(localValues), ...
        'descend');


    figure( ...
        'Name', ...
        ['DL Local SHAP - ', ...
         representativeNames{r}], ...
        'Color','w');


    barh( ...
        categorical( ...
            features(order), ...
            features(order)), ...
        localValues(order));


    xlabel('SHAP Contribution to Gain (dB)');

    ylabel('Circuit Parameter');

    title( ...
        sprintf( ...
        'DL Local SHAP - %s Gain\nActual = %.2f dB, Predicted = %.2f dB', ...
        strrep(representativeNames{r},'_',' '), ...
        YQueryActual(idx), ...
        YTestPred(idx)));


    grid on;

    set(gca, ...
        'FontSize',10);


    localPlot = fullfile( ...
        shapDir, ...
        ['DL_Local_SHAP_', ...
         representativeNames{r},'.png']);


    exportgraphics( ...
        gcf, ...
        localPlot, ...
        'Resolution',300);


    close(gcf);

end


%% ================================================================
% 40. FINAL SUMMARY
% ================================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('       DL SHAP ANALYSIS COMPLETE\n');
fprintf('=============================================\n\n');


fprintf('Project root:\n');
fprintf('%s\n\n',projectRoot);


fprintf('Model:\n');
fprintf('9 -> 64 -> 32 -> 16 -> 1 dlnetwork\n\n');


fprintf('Dataset:\n');
fprintf('660 canonical valid CE circuits\n');
fprintf('528 development\n');
fprintf('423 training background\n');
fprintf('105 validation\n');
fprintf('132 final test queries\n\n');


fprintf('Preprocessing:\n');
fprintf('log10(first 8 features)\n');
fprintf('normalization using 528 development samples\n\n');


fprintf('Test performance verification:\n');
fprintf('R^2   = %.6f\n',testR2);
fprintf('RMSE  = %.6f dB\n',testRMSE);
fprintf('MAE   = %.6f dB\n\n',testMAE);


fprintf('SHAP baseline:\n');
fprintf('%.6f dB\n\n',double(explainer.Intercept));


fprintf('SHAP additivity error:\n');
fprintf('%.15g dB\n\n',additivityDifference);


fprintf('Output directory:\n');
fprintf('%s\n\n',shapDir);


fprintf('Generated files:\n');
fprintf('  DL_SHAP_Results.mat\n');
fprintf('  DL_SHAP_Global_Ranking.csv\n');
fprintf('  DL_SHAP_Dependence_Statistics.csv\n');
fprintf('  DL_SHAP_Local_Values.csv\n');
fprintf('  DL_Global_SHAP_Importance.png\n');
fprintf('  DL_SHAP_Dependence_*.png\n');
fprintf('  DL_Local_SHAP_*.png\n');


fprintf('\n=============================================\n');
fprintf('       ANALYSIS FINISHED\n');
fprintf('=============================================\n');


%% ================================================================
% LOCAL FUNCTION
% ================================================================

function Y = predictDLRaw(net,X,mu,sigma)

    % Convert to double for preprocessing
    X = double(X);


    % ------------------------------------------------------------
    % Same log transformation used during DL dataset preparation
    % ------------------------------------------------------------

    X(:,1:8) = ...
        log10(X(:,1:8));


    % ------------------------------------------------------------
    % Same normalization used to generate DL_Dataset.mat
    %
    % IMPORTANT:
    % mu and sigma come from ALL 528 DEVELOPMENT rows.
    % ------------------------------------------------------------

    X = ...
        (X-mu)./sigma;


    % ------------------------------------------------------------
    % dlnetwork prediction
    % ------------------------------------------------------------

    Y = predict( ...
        net, ...
        single(X));


    % ------------------------------------------------------------
    % Return one prediction per observation
    % ------------------------------------------------------------

    Y = double(Y(:));

end
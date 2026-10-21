%% ============================================================
%        UNIFIED XAI MODEL COMPARISON
%        Deep Learning vs LSBoost
%
%  Project:
%  Explainable AI Framework for Electronic Circuit
%  Understanding and Design Optimization
%
%  Canonical dataset:
%  CE_Amplifier_ML_Valid.csv
%
%  Models:
%  1. Deep Learning
%  2. LSBoost
%
%  XAI:
%  1. Precomputed Deep Learning SHAP
%  2. MATLAB SHAPLEY for LSBoost
%
%  IMPORTANT:
%  LSBoost SHAP was already computed and saved to:
%
%  C:\Internship Project\results\unified_XAI\
%  LSBoost_SHAP_Intermediate.mat
%
%  Therefore the expensive SHAP calculation is skipped when
%  the intermediate file exists.
%
% ============================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf('              UNIFIED XAI MODEL COMPARISON\n');
fprintf('============================================================\n');


%% ============================================================
% 1. CONFIGURATION
% ============================================================

dataFile = ...
    'C:\Internship Project\data\final\CE_Amplifier_ML_Valid.csv';

lsModelFile = ...
    'C:\Internship Project\ml\models\Gain_Boosted_Model.mat';

dlShapFile = ...
    'C:\Internship Project\results\deep_learning\shap\DL_SHAP_Results.mat';

outputDir = ...
    'C:\Internship Project\results\unified_XAI';

plotDir = fullfile(outputDir,'plots');

intermediateSHAPFile = ...
    fullfile(outputDir,'LSBoost_SHAP_Intermediate.mat');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

if ~exist(plotDir,'dir')
    mkdir(plotDir);
end

rng(42,'twister');

lsBackgroundCount = 100;

useParallel = "auto";


fprintf('\n');
fprintf('Configuration:\n');
fprintf('  Dataset               : %s\n',dataFile);
fprintf('  LSBoost model         : %s\n',lsModelFile);
fprintf('  DL SHAP results       : %s\n',dlShapFile);
fprintf('  Random seed           : 42\n');
fprintf('  LSBoost SHAP bg       : %d\n',lsBackgroundCount);
fprintf('  Parallel              : %s\n',string(useParallel));


%% ============================================================
% 2. LOADING CANONICAL DATASET
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('2. LOADING CANONICAL DATASET\n');
fprintf('============================================================\n');

T = readtable(dataFile);

fprintf('\nRows    : %d\n',height(T));
fprintf('Columns : %d\n',width(T));


%% ------------------------------------------------------------
% Feature definitions
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

targetName = 'Gain_dB';


fprintf('\nFeatures:\n');

for k = 1:numel(features)

    fprintf( ...
        '  %d. %s\n', ...
        k,features{k});

end

fprintf('\nTarget: %s\n',targetName);


%% ------------------------------------------------------------
% Extract data
% ------------------------------------------------------------

X = T{:,features};
Y = T{:,targetName};

fprintf('\nMissing values:\n');

fprintf( ...
    '  X = %d\n', ...
    sum(ismissing(X),'all'));

fprintf( ...
    '  Y = %d\n', ...
    sum(ismissing(Y),'all'));


%% ============================================================
% 3. LOADING DL SHAP RESULTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('3. LOADING DL SHAP RESULTS\n');
fprintf('============================================================\n');

DL = load(dlShapFile);

fprintf('\nLoaded DL SHAP file.\n\n');

fprintf('Variables contained in DL_SHAP_Results.mat:\n');

disp(fieldnames(DL));


%% ============================================================
% 4. EXTRACTING EXACT DL SHAP DATA
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('4. EXTRACTING EXACT DL SHAP DATA\n');
fprintf('============================================================\n');


requiredDLVars = { ...
    'LocalSHAP', ...
    'XBackgroundRaw', ...
    'XQueryRaw', ...
    'YQueryActual', ...
    'YTestPred'};


for k = 1:numel(requiredDLVars)

    if ~isfield(DL,requiredDLVars{k})

        error( ...
            'Required DL SHAP variable "%s" not found.', ...
            requiredDLVars{k});

    end

end


DL_SHAP_raw = DL.LocalSHAP;

DL_Query = DL.XQueryRaw;

DL_Background = DL.XBackgroundRaw;

DL_Actual = DL.YQueryActual(:);

DL_Pred = DL.YTestPred(:);


fprintf( ...
    'Exact DL query circuits      : %d\n', ...
    size(DL_Query,1));

fprintf( ...
    'Exact DL background circuits: %d\n', ...
    size(DL_Background,1));

fprintf( ...
    'Query feature count          : %d\n', ...
    size(DL_Query,2));


%% ============================================================
% 5. EXTRACTING DL SHAP MATRIX
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('5. EXTRACTING DL SHAP MATRIX\n');
fprintf('============================================================\n');

fprintf('LocalSHAP class:\n');
disp(class(DL_SHAP_raw));

fprintf('LocalSHAP size:\n');
disp(size(DL_SHAP_raw));


if ~isnumeric(DL_SHAP_raw)

    error('DL LocalSHAP is not numeric.');

end


%% ------------------------------------------------------------
% Define dimensions NOW
% ------------------------------------------------------------

nFeatures = numel(features);

nQuery = size(DL_Query,1);


%% ------------------------------------------------------------
% Orient DL SHAP
% ------------------------------------------------------------

if isequal(size(DL_SHAP_raw),[nQuery,nFeatures])

    DL_SHAP = double(DL_SHAP_raw);

elseif isequal(size(DL_SHAP_raw),[nFeatures,nQuery])

    DL_SHAP = double(DL_SHAP_raw');

else

    error( ...
        ['Unexpected DL SHAP dimensions: %d x %d. ' ...
         'Expected %d x %d or %d x %d.'], ...
        size(DL_SHAP_raw,1), ...
        size(DL_SHAP_raw,2), ...
        nQuery, ...
        nFeatures, ...
        nFeatures, ...
        nQuery);

end


fprintf('\nDL SHAP matrix:\n');

fprintf( ...
    '  Features = %d\n', ...
    size(DL_SHAP,2));

fprintf( ...
    '  Queries  = %d\n', ...
    size(DL_SHAP,1));


%% ============================================================
% 6. VERIFYING DL SHAP ADDITIVITY
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('6. VERIFYING DL SHAP ADDITIVITY\n');
fprintf('============================================================\n');


if isfield(DL,'additivityDifference')

    addErr = double(DL.additivityDifference(:));

    fprintf( ...
        'Maximum stored additivity error: %.12g dB\n', ...
        max(abs(addErr)));

    fprintf( ...
        'Mean stored additivity error   : %.12g dB\n', ...
        mean(abs(addErr)));

else

    fprintf( ...
        'Stored additivityDifference not found.\n');

end


%% ============================================================
% 7. VERIFYING DL SHAP DATA
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('7. VERIFYING DL SHAP DATA\n');
fprintf('============================================================\n');


fprintf( ...
    'DL query matrix : %d x %d\n', ...
    size(DL_Query,1), ...
    size(DL_Query,2));

fprintf( ...
    'DL background   : %d x %d\n', ...
    size(DL_Background,1), ...
    size(DL_Background,2));

fprintf( ...
    'DL SHAP         : %d x %d\n', ...
    size(DL_SHAP,1), ...
    size(DL_SHAP,2));

fprintf( ...
    'DL actual       : %d values\n', ...
    numel(DL_Actual));

fprintf( ...
    'DL prediction   : %d values\n', ...
    numel(DL_Pred));


if size(DL_Query,2) ~= nFeatures

    error( ...
        'DL query feature count does not match canonical features.');

end


if size(DL_SHAP,2) ~= nFeatures

    error( ...
        'DL SHAP feature count does not match canonical features.');

end


if size(DL_Query,1) ~= numel(DL_Actual)

    error( ...
        'DL query count does not match DL actual values.');

end


if size(DL_Query,1) ~= numel(DL_Pred)

    error( ...
        'DL query count does not match DL prediction values.');

end


fprintf('\nDL SHAP data verification PASSED.\n');


%% ============================================================
% 8. LOADING LSBOOST MODEL
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('8. LOADING LSBOOST MODEL\n');
fprintf('============================================================\n');


LS = load(lsModelFile);

fprintf('Variables in LSBoost MAT file:\n');

disp(fieldnames(LS));


if ~isfield(LS,'model')

    error( ...
        'LSBoost MAT file does not contain variable "model".');

end


lsModel = LS.model;


fprintf('\nLSBoost model class:\n');

disp(class(lsModel));


%% ============================================================
% 9. MATCHING DL QUERY CIRCUITS TO CANONICAL DATASET
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('9. MATCHING DL QUERY CIRCUITS TO CANONICAL DATASET\n');
fprintf('============================================================\n');


queryIndices = zeros(nQuery,1);

matchTolerance = 1e-10;


for i = 1:nQuery

    differences = abs(X - DL_Query(i,:));

    relativeDifferences = ...
        differences ./ max(abs(DL_Query(i,:)),1);

    rowError = ...
        max(relativeDifferences,[],2);

    [minError,idx] = min(rowError);

    if minError > matchTolerance

        error( ...
            ['Could not match DL query circuit %d. ' ...
             'Minimum relative error = %.3e'], ...
            i,minError);

    end

    queryIndices(i) = idx;

end


if numel(unique(queryIndices)) ~= nQuery

    warning( ...
        'Duplicate canonical dataset indices detected.');

end


fprintf( ...
    'Successfully matched %d / %d DL query circuits.\n', ...
    sum(queryIndices > 0), ...
    nQuery);


%% ============================================================
% 10. LSBOOST PREPROCESSING
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('10. LSBOOST PREPROCESSING\n');
fprintf('============================================================\n');

fprintf('First 8 features: log10 transformed.\n');
fprintf('VCC: linear.\n');


XQueryRaw = DL_Query;

XQueryLS = XQueryRaw;

XQueryLS(:,1:8) = ...
    log10(XQueryRaw(:,1:8));


%% ============================================================
% 11. LSBOOST PREDICTION VERIFICATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('11. LSBOOST PREDICTION VERIFICATION\n');
fprintf('============================================================\n');


YLS_direct = ...
    predict(lsModel,XQueryLS);

YLS_direct = double(YLS_direct(:));


YLS_wrapper = ...
    predictLSBoostRaw(lsModel,XQueryRaw);

YLS_wrapper = double(YLS_wrapper(:));


maxPredictionDifference = ...
    max(abs(YLS_direct-YLS_wrapper));


fprintf( ...
    'Maximum direct-vs-wrapper difference: %.12g dB\n', ...
    maxPredictionDifference);


if maxPredictionDifference > 1e-10

    error( ...
        'LSBoost wrapper verification FAILED.');

else

    fprintf( ...
        'LSBoost wrapper verification PASSED.\n');

end


%% ============================================================
% 12. MODEL PERFORMANCE ON SAME 132 CIRCUITS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('12. MODEL PERFORMANCE ON SAME 132 CIRCUITS\n');
fprintf('============================================================\n');


YActual = DL_Actual;

YDL = DL_Pred;

YLS = YLS_wrapper;


%% ------------------------------------------------------------
% Deep Learning
% ------------------------------------------------------------

DL_R2 = calculateR2(YActual,YDL);

DL_RMSE = ...
    sqrt(mean((YActual-YDL).^2));

DL_MAE = ...
    mean(abs(YActual-YDL));

DL_Pearson = ...
    corr(YActual,YDL,'Type','Pearson');

DL_Spearman = ...
    corr(YActual,YDL,'Type','Spearman');


%% ------------------------------------------------------------
% LSBoost
% ------------------------------------------------------------

LS_R2 = calculateR2(YActual,YLS);

LS_RMSE = ...
    sqrt(mean((YActual-YLS).^2));

LS_MAE = ...
    mean(abs(YActual-YLS));

LS_Pearson = ...
    corr(YActual,YLS,'Type','Pearson');

LS_Spearman = ...
    corr(YActual,YLS,'Type','Spearman');


fprintf('\nDeep Learning:\n');

fprintf( ...
    '  R²       = %.6f\n',DL_R2);

fprintf( ...
    '  RMSE     = %.6f dB\n',DL_RMSE);

fprintf( ...
    '  MAE      = %.6f dB\n',DL_MAE);

fprintf( ...
    '  Pearson  = %.6f\n',DL_Pearson);

fprintf( ...
    '  Spearman = %.6f\n',DL_Spearman);


fprintf('\nLSBoost:\n');

fprintf( ...
    '  R²       = %.6f\n',LS_R2);

fprintf( ...
    '  RMSE     = %.6f dB\n',LS_RMSE);

fprintf( ...
    '  MAE      = %.6f dB\n',LS_MAE);

fprintf( ...
    '  Pearson  = %.6f\n',LS_Pearson);

fprintf( ...
    '  Spearman = %.6f\n',LS_Spearman);


%% ============================================================
% 13. SELECTING LSBOOST SHAP BACKGROUND
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('13. SELECTING LSBOOST SHAP BACKGROUND\n');
fprintf('============================================================\n');


fprintf( ...
    'Full DL background: %d circuits\n', ...
    size(DL_Background,1));

fprintf( ...
    'LSBoost SHAP background: %d circuits\n', ...
    lsBackgroundCount);


if lsBackgroundCount > size(DL_Background,1)

    error( ...
        'Requested LSBoost background exceeds DL background.');

end


rng(42,'twister');


backgroundIdx = ...
    randperm( ...
        size(DL_Background,1), ...
        lsBackgroundCount);


LS_BackgroundRaw = ...
    DL_Background(backgroundIdx,:);


%% ============================================================
% 14. CREATE / LOAD LSBOOST SHAP EXPLAINER
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('14. CREATING / LOADING LSBOOST SHAP EXPLAINER\n');
fprintf('============================================================\n');


lsShapRuntime = NaN;


if exist(intermediateSHAPFile,'file')

    fprintf('\nExisting LSBoost SHAP result found.\n');

    fprintf('Loading:\n');

    fprintf( ...
        '  %s\n', ...
        intermediateSHAPFile);


    S = load( ...
        intermediateSHAPFile, ...
        'lsExplainer');


    if ~isfield(S,'lsExplainer')

        error( ...
            ['Intermediate SHAP file exists but does not ' ...
             'contain "lsExplainer".']);

    end


    lsExplainer = S.lsExplainer;


    fprintf('\nLSBoost SHAP loaded successfully.\n');

    fprintf( ...
        'Skipping expensive SHAP computation.\n');


else

    fprintf('\n');
    fprintf('LSBoost Kernel SHAP configuration:\n');

    fprintf( ...
        '  Background : %d\n', ...
        size(LS_BackgroundRaw,1));

    fprintf( ...
        '  Queries    : %d\n', ...
        size(XQueryRaw,1));

    fprintf( ...
        '  Features   : %d\n', ...
        size(XQueryRaw,2));

    fprintf( ...
        '  Parallel   : %s\n', ...
        string(useParallel));


    fprintf('\n');
    fprintf( ...
        'Starting LSBoost SHAP...\n');

    fprintf( ...
        'This is the computationally expensive stage.\n\n');


    tic;


    lsExplainer = shapley( ...
        @predictLSBoostRawForSHAP, ...
        lsModel, ...
        LS_BackgroundRaw, ...
        'QueryPoints',XQueryRaw, ...
        'UseParallel',useParallel);


    lsShapRuntime = toc;


    fprintf('\n');
    fprintf( ...
        'LSBoost SHAP completed.\n');

    fprintf( ...
        'Runtime: %.2f seconds\n', ...
        lsShapRuntime);

    fprintf( ...
        'Runtime: %.2f minutes\n', ...
        lsShapRuntime/60);


    fprintf('\nSaving intermediate SHAP result...\n');


    save( ...
        intermediateSHAPFile, ...
        'lsExplainer', ...
        '-v7.3');


    fprintf( ...
        'Intermediate SHAP result saved.\n');

end


%% ============================================================
% 15. EXTRACT LSBOOST SHAP VALUES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('15. EXTRACTING LSBOOST SHAP VALUES\n');
fprintf('============================================================\n');


lsShapTable = ...
    lsExplainer.ShapleyValues;


fprintf('LSBoost SHAP table:\n');

disp(lsShapTable);


%% ------------------------------------------------------------
% Define dimensions explicitly
% ------------------------------------------------------------

nFeatures = numel(features);

nQuery = size(XQueryRaw,1);


fprintf('\nExpected dimensions:\n');

fprintf( ...
    '  Features : %d\n', ...
    nFeatures);

fprintf( ...
    '  Queries  : %d\n', ...
    nQuery);


%% ------------------------------------------------------------
% Check table variables
% ------------------------------------------------------------

tableVariableNames = ...
    lsShapTable.Properties.VariableNames;


fprintf('\nSHAP table variables:\n');

disp(tableVariableNames);


%% ------------------------------------------------------------
% Identify SHAP value column
% ------------------------------------------------------------

if ismember( ...
        'ShapleyValue', ...
        tableVariableNames)

    shapValueColumn = ...
        'ShapleyValue';

elseif ismember( ...
        'Value', ...
        tableVariableNames)

    shapValueColumn = ...
        'Value';

else

    error( ...
        ['Could not find SHAP-value column. ' ...
         'Available variables: %s'], ...
        strjoin(tableVariableNames,', '));

end


fprintf( ...
    '\nUsing SHAP value column: %s\n', ...
    shapValueColumn);


%% ------------------------------------------------------------
% Extract numeric SHAP matrix
% ------------------------------------------------------------

shapData = ...
    lsShapTable.(shapValueColumn);


fprintf('\nSHAP value variable class:\n');

disp(class(shapData));


fprintf('SHAP value variable size:\n');

disp(size(shapData));


shapData = double(shapData);


%% ------------------------------------------------------------
% Orient SHAP matrix
%
% Current MATLAB output:
%
%     9 x 132
%
% Convert to:
%
%     132 x 9
% ------------------------------------------------------------

if isequal( ...
        size(shapData), ...
        [nFeatures,nQuery])

    LS_SHAP = ...
        shapData';


elseif isequal( ...
        size(shapData), ...
        [nQuery,nFeatures])

    LS_SHAP = ...
        shapData;


else

    error( ...
        ['Unexpected SHAP matrix dimensions: %d x %d. ' ...
         'Expected %d x %d or %d x %d.'], ...
        size(shapData,1), ...
        size(shapData,2), ...
        nFeatures, ...
        nQuery, ...
        nQuery, ...
        nFeatures);

end


fprintf('\nLSBoost SHAP matrix successfully extracted.\n');

fprintf( ...
    '  Queries  : %d\n', ...
    size(LS_SHAP,1));

fprintf( ...
    '  Features : %d\n', ...
    size(LS_SHAP,2));


if size(LS_SHAP,1) ~= nQuery

    error( ...
        'LSBoost SHAP query count is incorrect.');

end


if size(LS_SHAP,2) ~= nFeatures

    error( ...
        'LSBoost SHAP feature count is incorrect.');

end


%% ============================================================
% 16. MAPPING LSBOOST SHAP TO PHYSICAL FEATURES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('16. MAPPING LSBOOST SHAP TO PHYSICAL FEATURES\n');
fprintf('============================================================\n');


for k = 1:nFeatures

    fprintf( ...
        '  x%d -> %s\n', ...
        k,features{k});

end


fprintf('\nLSBoost SHAP extraction PASSED.\n');


%% ============================================================
% 17. LSBOOST SHAP ADDITIVITY
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('17. LSBOOST SHAP ADDITIVITY CHECK\n');
fprintf('============================================================\n');


LS_baseline = [];


%% ------------------------------------------------------------
% Try BaseValue
% ------------------------------------------------------------

try

    if isprop(lsExplainer,'BaseValue')

        LS_baseline = ...
            lsExplainer.BaseValue;

    end

catch

end


%% ------------------------------------------------------------
% Try ExpectedValue
% ------------------------------------------------------------

if isempty(LS_baseline)

    try

        if isprop(lsExplainer,'ExpectedValue')

            LS_baseline = ...
                lsExplainer.ExpectedValue;

        end

    catch

    end

end


%% ------------------------------------------------------------
% Try Intercept
% ------------------------------------------------------------

if isempty(LS_baseline)

    try

        if isprop(lsExplainer,'Intercept')

            LS_baseline = ...
                lsExplainer.Intercept;

        end

    catch

    end

end


if isempty(LS_baseline)

    fprintf( ...
        'Explainer baseline property not directly available.\n');

    fprintf( ...
        'Skipping numerical LSBoost additivity check.\n');

else

    LS_baseline = ...
        double(LS_baseline(:));


    if numel(LS_baseline) == 1

        LS_reconstructed = ...
            LS_baseline + sum(LS_SHAP,2);

        LS_additivity_error = ...
            YLS - LS_reconstructed;


        fprintf( ...
            'LSBoost SHAP baseline: %.12f dB\n', ...
            LS_baseline(1));

        fprintf( ...
            'Maximum LSBoost SHAP additivity error: %.12g dB\n', ...
            max(abs(LS_additivity_error)));

        fprintf( ...
            'Mean LSBoost SHAP additivity error   : %.12g dB\n', ...
            mean(abs(LS_additivity_error)));

    end

end


%% ============================================================
% 18. GLOBAL SHAP IMPORTANCE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('18. GLOBAL SHAP IMPORTANCE\n');
fprintf('============================================================\n');


DL_Global = ...
    mean(abs(DL_SHAP),1)';


LS_Global = ...
    mean(abs(LS_SHAP),1)';


GlobalTable = table( ...
    features(:), ...
    DL_Global, ...
    LS_Global, ...
    'VariableNames', ...
    {'Feature', ...
     'DL_MeanAbsSHAP', ...
     'LSBoost_MeanAbsSHAP'});


%% ------------------------------------------------------------
% Global ranking
% ------------------------------------------------------------

[~,DL_order] = ...
    sort(DL_Global,'descend');


[~,LS_order] = ...
    sort(LS_Global,'descend');


DL_Rank = ...
    zeros(nFeatures,1);


LS_Rank = ...
    zeros(nFeatures,1);


DL_Rank(DL_order) = ...
    1:nFeatures;


LS_Rank(LS_order) = ...
    1:nFeatures;


GlobalTable.DL_Rank = ...
    DL_Rank;


GlobalTable.LSBoost_Rank = ...
    LS_Rank;


fprintf('\n');

disp(GlobalTable);


%% ============================================================
% 19. GLOBAL SHAP RANK CORRELATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('19. GLOBAL SHAP RANK CORRELATION\n');
fprintf('============================================================\n');


GlobalSpearman = ...
    corr( ...
        DL_Global, ...
        LS_Global, ...
        'Type','Spearman');


GlobalPearson = ...
    corr( ...
        DL_Global, ...
        LS_Global, ...
        'Type','Pearson');


fprintf( ...
    'Spearman correlation = %.6f\n', ...
    GlobalSpearman);


fprintf( ...
    'Pearson correlation  = %.6f\n', ...
    GlobalPearson);


%% ============================================================
% 20. FEATURE-WISE SHAP CORRELATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('20. FEATURE-WISE SHAP CORRELATION\n');
fprintf('============================================================\n');


FeatureCorrelation = ...
    zeros(nFeatures,1);


for k = 1:nFeatures

    FeatureCorrelation(k) = ...
        corr( ...
            DL_SHAP(:,k), ...
            LS_SHAP(:,k), ...
            'Type','Spearman');

end


FeatureCorrelationTable = table( ...
    features(:), ...
    DL_Global, ...
    LS_Global, ...
    FeatureCorrelation, ...
    'VariableNames', ...
    {'Feature', ...
     'DL_MeanAbsSHAP', ...
     'LSBoost_MeanAbsSHAP', ...
     'SHAP_Spearman_Correlation'});


disp(FeatureCorrelationTable);


%% ============================================================
% 21. LOCAL REPRESENTATIVE CIRCUITS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('21. SELECTING LOCAL REPRESENTATIVE CIRCUITS\n');
fprintf('============================================================\n');


[~,lowIdx] = ...
    min(YActual);


medianGain = ...
    median(YActual);


[~,mediumIdx] = ...
    min(abs(YActual-medianGain));


[~,highIdx] = ...
    max(YActual);


localIndices = ...
    [lowIdx,mediumIdx,highIdx];


localNames = { ...
    'Low-Gain', ...
    'Medium-Gain', ...
    'High-Gain'};


for i = 1:3

    idx = localIndices(i);


    fprintf('\n%s circuit:\n',localNames{i});

    fprintf( ...
        '  Test index : %d\n', ...
        idx);

    fprintf( ...
        '  Dataset row: %d\n', ...
        queryIndices(idx));

    fprintf( ...
        '  Actual     : %.6f dB\n', ...
        YActual(idx));

    fprintf( ...
        '  DL         : %.6f dB\n', ...
        YDL(idx));

    fprintf( ...
        '  LSBoost    : %.6f dB\n', ...
        YLS(idx));

end


%% ============================================================
% 22. LOCAL SHAP VALUES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('22. LOCAL SHAP VALUES\n');
fprintf('============================================================\n');


LocalRows = cell( ...
    3*nFeatures,8);


counter = 1;


for i = 1:3

    idx = ...
        localIndices(i);


    for k = 1:nFeatures

        LocalRows{counter,1} = ...
            localNames{i};

        LocalRows{counter,2} = ...
            idx;

        LocalRows{counter,3} = ...
            queryIndices(idx);

        LocalRows{counter,4} = ...
            features{k};

        LocalRows{counter,5} = ...
            DL_SHAP(idx,k);

        LocalRows{counter,6} = ...
            LS_SHAP(idx,k);

        LocalRows{counter,7} = ...
            abs(DL_SHAP(idx,k));

        LocalRows{counter,8} = ...
            abs(LS_SHAP(idx,k));

        counter = counter + 1;

    end

end


LocalTable = cell2table( ...
    LocalRows, ...
    'VariableNames',{ ...
    'Case', ...
    'TestIndex', ...
    'DatasetRow', ...
    'Feature', ...
    'DL_SHAP', ...
    'LSBoost_SHAP', ...
    'DL_AbsSHAP', ...
    'LSBoost_AbsSHAP'});


disp(LocalTable);


%% ============================================================
% 23. LOCAL TOP-3 FEATURES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('23. LOCAL TOP-3 FEATURES\n');
fprintf('============================================================\n');


for i = 1:3

    idx = ...
        localIndices(i);


    [~,DL_LocalOrder] = ...
        sort(abs(DL_SHAP(idx,:)),'descend');


    [~,LS_LocalOrder] = ...
        sort(abs(LS_SHAP(idx,:)),'descend');


    fprintf('\n%s:\n',localNames{i});


    fprintf('  Deep Learning:\n');


    for j = 1:3

        k = ...
            DL_LocalOrder(j);


        fprintf( ...
            '    %d. %-5s %+10.5f dB\n', ...
            j, ...
            features{k}, ...
            DL_SHAP(idx,k));

    end


    fprintf('  LSBoost:\n');


    for j = 1:3

        k = ...
            LS_LocalOrder(j);


        fprintf( ...
            '    %d. %-5s %+10.5f dB\n', ...
            j, ...
            features{k}, ...
            LS_SHAP(idx,k));

    end

end


%% ============================================================
% 24. LOCAL SHAP RANK CORRELATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('24. LOCAL SHAP RANK CORRELATION\n');
fprintf('============================================================\n');


LocalSpearman = ...
    zeros(3,1);


for i = 1:3

    idx = ...
        localIndices(i);


    LocalSpearman(i) = ...
        corr( ...
            abs(DL_SHAP(idx,:))', ...
            abs(LS_SHAP(idx,:))', ...
            'Type','Spearman');

end


LocalCorrelationTable = table( ...
    localNames(:), ...
    LocalSpearman, ...
    'VariableNames', ...
    {'Case','Spearman_Rank_Correlation'});


disp(LocalCorrelationTable);


%% ============================================================
% 25. LOCAL SHAP SIGN AGREEMENT
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('25. LOCAL SHAP SIGN AGREEMENT\n');
fprintf('============================================================\n');


SignAgreement = ...
    zeros(3,1);


for i = 1:3

    idx = ...
        localIndices(i);


    sameSign = ...
        sign(DL_SHAP(idx,:)) == ...
        sign(LS_SHAP(idx,:));


    SignAgreement(i) = ...
        mean(sameSign);

end


SignAgreementTable = table( ...
    localNames(:), ...
    SignAgreement, ...
    'VariableNames', ...
    {'Case','Sign_Agreement'});


disp(SignAgreementTable);


%% ============================================================
% 26. SHAP VS CLASSICAL SENSITIVITY
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('26. LOCAL SHAP VS CLASSICAL SENSITIVITY\n');
fprintf('============================================================\n');


% Canonical normalized classical sensitivity values
%
% Feature order:
%
% R1
% R2
% RC
% RE
% RL
% Cin
% Cout
% Ce
% VCC

ClassicalSensitivity = [ ...
    0.973230; ...
    0.646230; ...
    0.536433; ...
    0.588481; ...
    0.384938; ...
    0.001683; ...
    0.000678; ...
    0.002755; ...
    1.317847];


ClassicalSensitivity = ...
    ClassicalSensitivity(:);


ClassicalSensitivityTable = table( ...
    features(:), ...
    ClassicalSensitivity, ...
    'VariableNames', ...
    {'Feature','Classical_Sensitivity'});


fprintf('\nClassical sensitivity:\n');

disp(ClassicalSensitivityTable);


%% ------------------------------------------------------------
% DL SHAP vs classical sensitivity
% ------------------------------------------------------------

DL_Classical_Global = ...
    corr( ...
        DL_Global, ...
        ClassicalSensitivity, ...
        'Type','Spearman');


%% ------------------------------------------------------------
% LSBoost SHAP vs classical sensitivity
% ------------------------------------------------------------

LS_Classical_Global = ...
    corr( ...
        LS_Global, ...
        ClassicalSensitivity, ...
        'Type','Spearman');


fprintf('\nGlobal SHAP vs classical sensitivity:\n');

fprintf( ...
    '  DL SHAP       : %.6f\n', ...
    DL_Classical_Global);

fprintf( ...
    '  LSBoost SHAP  : %.6f\n', ...
    LS_Classical_Global);


%% ------------------------------------------------------------
% Local comparison
% ------------------------------------------------------------

LocalVsClassical = ...
    zeros(3,1);


for i = 1:3

    idx = ...
        localIndices(i);


    LocalVsClassical(i) = ...
        corr( ...
            abs(DL_SHAP(idx,:))', ...
            ClassicalSensitivity, ...
            'Type','Spearman');

end


LocalVsClassicalTable = table( ...
    localNames(:), ...
    LocalVsClassical, ...
    'VariableNames', ...
    {'Case','DL_SHAP_vs_Classical_Spearman'});


fprintf('\nDL local SHAP vs classical sensitivity:\n');

disp(LocalVsClassicalTable);


%% ============================================================
% 27. MODEL ERROR ANALYSIS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('27. MODEL ERROR ANALYSIS\n');
fprintf('============================================================\n');


DL_Error = ...
    YDL-YActual;


LS_Error = ...
    YLS-YActual;


DL_AbsError = ...
    abs(DL_Error);


LS_AbsError = ...
    abs(LS_Error);


[DL_MaxError,DL_MaxIdx] = ...
    max(DL_AbsError);


[LS_MaxError,LS_MaxIdx] = ...
    max(LS_AbsError);


fprintf('\nDeep Learning:\n');

fprintf( ...
    '  Mean error     = %+0.6f dB\n', ...
    mean(DL_Error));

fprintf( ...
    '  Std error      = %.6f dB\n', ...
    std(DL_Error));

fprintf( ...
    '  Median abs err = %.6f dB\n', ...
    median(DL_AbsError));

fprintf( ...
    '  Max abs err    = %.6f dB\n', ...
    DL_MaxError);

fprintf( ...
    '  Max error idx  = %d\n', ...
    DL_MaxIdx);


fprintf('\nLSBoost:\n');

fprintf( ...
    '  Mean error     = %+0.6f dB\n', ...
    mean(LS_Error));

fprintf( ...
    '  Std error      = %.6f dB\n', ...
    std(LS_Error));

fprintf( ...
    '  Median abs err = %.6f dB\n', ...
    median(LS_AbsError));

fprintf( ...
    '  Max abs err    = %.6f dB\n', ...
    LS_MaxError);

fprintf( ...
    '  Max error idx  = %d\n', ...
    LS_MaxIdx);


%% ============================================================
% 28. PERFORMANCE COMPARISON
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('28. PERFORMANCE COMPARISON\n');
fprintf('============================================================\n');


ModelPerformance = table( ...
    {'Deep Learning';'LSBoost'}, ...
    [DL_R2;LS_R2], ...
    [DL_RMSE;LS_RMSE], ...
    [DL_MAE;LS_MAE], ...
    [DL_Pearson;LS_Pearson], ...
    [DL_Spearman;LS_Spearman], ...
    'VariableNames',{ ...
    'Model', ...
    'R2', ...
    'RMSE_dB', ...
    'MAE_dB', ...
    'Pearson', ...
    'Spearman'});


disp(ModelPerformance);


%% ============================================================
% 29. GLOBAL SHAP RANKING COMPARISON
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('29. GLOBAL SHAP RANKING COMPARISON\n');
fprintf('============================================================\n');


RankingTable = ...
    sortrows(GlobalTable,'DL_Rank');


disp(RankingTable);


%% ============================================================
% 30. SAVE RESULTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('30. SAVING RESULTS\n');
fprintf('============================================================\n');


globalCSV = ...
    fullfile( ...
        outputDir, ...
        'Global_XAI_Ranking.csv');


localCSV = ...
    fullfile( ...
        outputDir, ...
        'Local_XAI_Values.csv');


performanceCSV = ...
    fullfile( ...
        outputDir, ...
        'Model_Performance.csv');


rankCorrelationCSV = ...
    fullfile( ...
        outputDir, ...
        'Rank_Correlation_Summary.csv');


featureCorrelationCSV = ...
    fullfile( ...
        outputDir, ...
        'Feature_SHAP_Correlation.csv');


sensitivityCSV = ...
    fullfile( ...
        outputDir, ...
        'SHAP_vs_Classical_Sensitivity.csv');


writetable( ...
    GlobalTable, ...
    globalCSV);


writetable( ...
    LocalTable, ...
    localCSV);


writetable( ...
    ModelPerformance, ...
    performanceCSV);


writetable( ...
    LocalCorrelationTable, ...
    rankCorrelationCSV);


writetable( ...
    FeatureCorrelationTable, ...
    featureCorrelationCSV);


writetable( ...
    LocalVsClassicalTable, ...
    sensitivityCSV);


%% ------------------------------------------------------------
% Save unified MAT file
% ------------------------------------------------------------

resultsFile = ...
    fullfile( ...
        outputDir, ...
        'Unified_XAI_Results.mat');


save( ...
    resultsFile, ...
    'features', ...
    'DL_SHAP', ...
    'LS_SHAP', ...
    'DL_Global', ...
    'LS_Global', ...
    'GlobalTable', ...
    'LocalTable', ...
    'ModelPerformance', ...
    'LocalCorrelationTable', ...
    'SignAgreementTable', ...
    'FeatureCorrelationTable', ...
    'ClassicalSensitivity', ...
    'LocalVsClassicalTable', ...
    'YActual', ...
    'YDL', ...
    'YLS', ...
    'queryIndices', ...
    'localIndices', ...
    'lsShapRuntime', ...
    'GlobalSpearman', ...
    'GlobalPearson', ...
    'DL_Classical_Global', ...
    'LS_Classical_Global');


fprintf('\nSaved:\n');

fprintf('  %s\n',globalCSV);
fprintf('  %s\n',localCSV);
fprintf('  %s\n',performanceCSV);
fprintf('  %s\n',rankCorrelationCSV);
fprintf('  %s\n',featureCorrelationCSV);
fprintf('  %s\n',sensitivityCSV);
fprintf('  %s\n',resultsFile);


%% ============================================================
% 31. GENERATING PLOTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('31. GENERATING PLOTS\n');
fprintf('============================================================\n');


%% ------------------------------------------------------------
% Plot 1: Global SHAP comparison
% ------------------------------------------------------------

figure('Visible','off');

bar([DL_Global LS_Global]);

set(gca, ...
    'XTick',1:nFeatures, ...
    'XTickLabel',features);

xtickangle(45);

ylabel('Mean |SHAP| (dB)');

title( ...
    'Global SHAP Importance Comparison');


legend( ...
    {'Deep Learning','LSBoost'}, ...
    'Location','northoutside');


grid on;


saveas( ...
    gcf, ...
    fullfile( ...
        plotDir, ...
        'Global_SHAP_Comparison.png'));


close;


%% ------------------------------------------------------------
% Plot 2: Actual vs predicted
% ------------------------------------------------------------

figure('Visible','off');

plot( ...
    YActual, ...
    YDL, ...
    'o');

hold on;

plot( ...
    YActual, ...
    YLS, ...
    'x');


minVal = ...
    min(YActual);

maxVal = ...
    max(YActual);


plot( ...
    [minVal maxVal], ...
    [minVal maxVal], ...
    '--');


xlabel('Actual Gain (dB)');

ylabel('Predicted Gain (dB)');

title( ...
    'Actual vs Predicted Gain');


legend( ...
    {'Deep Learning','LSBoost','Ideal'}, ...
    'Location','best');


grid on;


saveas( ...
    gcf, ...
    fullfile( ...
        plotDir, ...
        'Actual_vs_Predicted.png'));


close;


%% ------------------------------------------------------------
% Plot 3: SHAP rank comparison
% ------------------------------------------------------------

figure('Visible','off');

bar([DL_Rank LS_Rank]);

set(gca, ...
    'XTick',1:nFeatures, ...
    'XTickLabel',features);

xtickangle(45);

ylabel('SHAP Rank');

title( ...
    'Global SHAP Feature Ranking');


legend( ...
    {'Deep Learning','LSBoost'}, ...
    'Location','best');


grid on;


saveas( ...
    gcf, ...
    fullfile( ...
        plotDir, ...
        'SHAP_Rank_Comparison.png'));


close;


%% ------------------------------------------------------------
% Plot 4: Feature-wise SHAP correlation
% ------------------------------------------------------------

figure('Visible','off');

bar(FeatureCorrelation);

set(gca, ...
    'XTick',1:nFeatures, ...
    'XTickLabel',features);

xtickangle(45);

ylabel('Spearman correlation');

title( ...
    'Feature-wise SHAP Agreement');


grid on;


saveas( ...
    gcf, ...
    fullfile( ...
        plotDir, ...
        'Featurewise_SHAP_Correlation.png'));


close;


%% ------------------------------------------------------------
% Plot 5: SHAP vs classical sensitivity
% ------------------------------------------------------------

figure('Visible','off');

bar( ...
    [DL_Global ...
     LS_Global ...
     ClassicalSensitivity]);


set(gca, ...
    'XTick',1:nFeatures, ...
    'XTickLabel',features);

xtickangle(45);

ylabel('Importance / Sensitivity');

title( ...
    'SHAP Importance vs Classical Sensitivity');


legend( ...
    {'DL Mean |SHAP|', ...
     'LSBoost Mean |SHAP|', ...
     'Classical Sensitivity'}, ...
    'Location','northoutside');


grid on;


saveas( ...
    gcf, ...
    fullfile( ...
        plotDir, ...
        'SHAP_vs_Classical_Sensitivity.png'));


close;


%% ============================================================
% FINAL SUMMARY
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('                 FINAL XAI SUMMARY\n');
fprintf('============================================================\n');


fprintf('\nMODEL PERFORMANCE\n');


fprintf( ...
    'Deep Learning : R² = %.4f | RMSE = %.4f dB | MAE = %.4f dB\n', ...
    DL_R2, ...
    DL_RMSE, ...
    DL_MAE);


fprintf( ...
    'LSBoost       : R² = %.4f | RMSE = %.4f dB | MAE = %.4f dB\n', ...
    LS_R2, ...
    LS_RMSE, ...
    LS_MAE);


fprintf('\nGLOBAL SHAP AGREEMENT\n');


fprintf( ...
    'Spearman rank correlation = %.4f\n', ...
    GlobalSpearman);


fprintf( ...
    'Pearson correlation       = %.4f\n', ...
    GlobalPearson);


fprintf('\nGLOBAL SHAP RANKING\n');


for i = 1:nFeatures

    k = ...
        DL_order(i);


    fprintf( ...
        '  %d. %-5s | DL = %.4f | LSBoost = %.4f\n', ...
        i, ...
        features{k}, ...
        DL_Global(k), ...
        LS_Global(k));

end


fprintf('\nLOCAL SHAP AGREEMENT\n');


for i = 1:3

    fprintf( ...
        '  %-12s : Spearman = %.4f | Sign agreement = %.2f%%\n', ...
        localNames{i}, ...
        LocalSpearman(i), ...
        SignAgreement(i)*100);

end


fprintf('\nCLASSICAL SENSITIVITY AGREEMENT\n');


fprintf( ...
    '  DL global SHAP vs sensitivity      : %.4f\n', ...
    DL_Classical_Global);


fprintf( ...
    '  LSBoost global SHAP vs sensitivity : %.4f\n', ...
    LS_Classical_Global);


if ~isnan(lsShapRuntime)

    fprintf('\nLSBoost SHAP runtime: %.2f minutes\n', ...
        lsShapRuntime);

else

    fprintf('\nLSBoost SHAP runtime: loaded from intermediate file\n');

end


fprintf('\nResults saved to:\n');

fprintf( ...
    '  %s\n', ...
    outputDir);


fprintf('\n');
fprintf('============================================================\n');
fprintf('              UNIFIED XAI COMPLETED\n');
fprintf('============================================================\n');


%% ============================================================
% LOCAL FUNCTIONS
% ============================================================


function Y = predictLSBoostRaw(model,Xraw)

    % --------------------------------------------------------
    % Raw physical variables:
    %
    % R1,R2,RC,RE,RL,Cin,Cout,Ce -> log10
    % VCC                          -> unchanged
    % --------------------------------------------------------

    Xtransformed = Xraw;

    Xtransformed(:,1:8) = ...
        log10(Xraw(:,1:8));


    Y = predict( ...
        model, ...
        Xtransformed);


    Y = double(Y(:));

end


function Y = predictLSBoostRawForSHAP(model,Xraw)

    % Wrapper specifically for SHAP.
    %
    % The SHAP interface supplies raw physical parameters.
    % The trained LSBoost model expects transformed parameters.

    Xtransformed = Xraw;

    Xtransformed(:,1:8) = ...
        log10(Xraw(:,1:8));


    Y = predict( ...
        model, ...
        Xtransformed);


    Y = double(Y(:));

end


function R2 = calculateR2(Yactual,Ypred)

    Yactual = ...
        double(Yactual(:));


    Ypred = ...
        double(Ypred(:));


    SSres = ...
        sum((Yactual-Ypred).^2);


    SStot = ...
        sum((Yactual-mean(Yactual)).^2);


    R2 = ...
        1 - SSres/SStot;

end
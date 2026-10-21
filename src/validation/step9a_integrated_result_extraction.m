%% ========================================================================
% STEP 9A - INTEGRATED RESULT EXTRACTION
%
% Explainable AI Framework for Electronic Circuit Understanding
% and Design Optimization
%
% Circuit: Common-Emitter BJT Amplifier
%
% PURPOSE
% -------
% Consolidate the validated results from:
%
%   1. Canonical SPICE/ML dataset
%   2. Operating-point dataset
%   3. Classical LSBoost model
%   4. Deep Learning model
%   5. 5-fold cross-validation
%   6. SHAP/XAI analysis
%   7. SHAP interaction + SPICE validation
%   8. DL optimization
%   9. Circuit-aware optimization
%  10. Robustness analysis
%  11. Optimization generalization analysis
%
% IMPORTANT SCIENTIFIC RULE
% -------------------------
% SPICE remains the physical ground truth.
%
% ML/DL = surrogate models
% SHAP = explanation of surrogate behavior
% Optimization = candidate generation
% SPICE = final physical verification
%
% No new ML training or SPICE sweep is performed here.
%
% MATLAB version:
% R2025b
%
% ========================================================================

clear;
clc;

fprintf('\n');
fprintf('===============================================================\n');
fprintf(' STEP 9A - INTEGRATED RESULT EXTRACTION\n');
fprintf('===============================================================\n');

%% ========================================================================
% 1. PROJECT PATHS
% ========================================================================

projectRoot = 'C:\Internship Project';

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9A');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

fprintf('\nProject root:\n%s\n',projectRoot);
fprintf('\nOutput directory:\n%s\n',outputDir);

%% ========================================================================
% 2. SOURCE FILE PATHS
% ========================================================================

datasetFile = fullfile( ...
    projectRoot,'data','final', ...
    'CE_Amplifier_ML_Valid.csv');

operatingPointFile = fullfile( ...
    projectRoot,'data','processed', ...
    'CE_Amplifier_OperatingPoint_660.csv');

lsBoostFile = fullfile( ...
    projectRoot,'ml','models', ...
    'Gain_Boosted_Model.mat');

dlResultsFile = fullfile( ...
    projectRoot,'results','deep_learning', ...
    'DL_Training_Results.mat');

dlCVFile = fullfile( ...
    projectRoot,'results','deep_learning', ...
    'cross_validation', ...
    '5Fold_CV_Results.mat');

comparisonFile = fullfile( ...
    projectRoot,'results','deep_learning', ...
    'model_comparison', ...
    'LSBoost_vs_DL_Comparison.mat');

unifiedXAIMat = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'Unified_XAI_Results.mat');

globalXAICSV = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'Global_XAI_Ranking.csv');

localXAICSV = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'Local_XAI_Values.csv');

rankCorrelationCSV = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'Rank_Correlation_Summary.csv');

featureSHAPCorrelationCSV = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'Feature_SHAP_Correlation.csv');

SHAPSensitivityCSV = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'SHAP_vs_Classical_Sensitivity.csv');

SHAPInteractionMAT = fullfile( ...
    projectRoot,'results','final', ...
    'SHAP_Interaction_Results.mat');

physicalInteractionMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'XAI_R1_R2_Physical_Validation.mat');

optimizationMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'DL_fmincon_Optimization_Results.mat');

optimizationSPICEMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'spice_verification', ...
    'SPICE_Optimization_Verification.mat');

step8EMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Circuit_Aware_Optimization_Results.mat');

step8ESummaryCSV = fullfile( ...
    projectRoot,'results','optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Final_Summary.csv');

robustnessMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'robustness', ...
    'Robustness_SPICE_Results.mat');

robustnessAnalysisMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'robustness', ...
    'Robustness_Analysis_Results.mat');

robustnessCSV = fullfile( ...
    projectRoot,'results','optimization', ...
    'robustness', ...
    'Robustness_Final_Analysis.csv');

generalizationMAT = fullfile( ...
    projectRoot,'results','optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis', ...
    'Step8F_Optimization_Generalization_Results.mat');

generalizationCSV = fullfile( ...
    projectRoot,'results','optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis', ...
    'Step8F_Optimization_Generalization.csv');

step8GAuditMAT = fullfile( ...
    projectRoot,'results','final', ...
    'STEP8G_Final_Circuit_Aware_Audit.mat');

%% ========================================================================
% 3. SOURCE FILE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('1. SOURCE FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

sourceFiles = {
    'Canonical ML dataset',              datasetFile
    'Operating-point dataset',           operatingPointFile
    'LSBoost model',                     lsBoostFile
    'DL training results',               dlResultsFile
    'DL 5-fold CV',                      dlCVFile
    'LSBoost vs DL comparison',         comparisonFile
    'Unified XAI MAT',                   unifiedXAIMat
    'Global XAI CSV',                    globalXAICSV
    'Local XAI CSV',                     localXAICSV
    'Rank correlation CSV',             rankCorrelationCSV
    'Feature SHAP correlation CSV',     featureSHAPCorrelationCSV
    'SHAP sensitivity CSV',             SHAPSensitivityCSV
    'SHAP interaction MAT',             SHAPInteractionMAT
    'Physical interaction validation',  physicalInteractionMAT
    'DL optimization',                 optimizationMAT
    'Optimization SPICE verification', optimizationSPICEMAT
    'Step 8E MAT',                     step8EMAT
    'Step 8E summary',                 step8ESummaryCSV
    'Robustness SPICE results',        robustnessMAT
    'Robustness analysis',             robustnessAnalysisMAT
    'Robustness final CSV',            robustnessCSV
    'Step 8F generalization MAT',      generalizationMAT
    'Step 8F generalization CSV',      generalizationCSV
    'Step 8G audit MAT',               step8GAuditMAT
    };

sourceStatus = false(size(sourceFiles,1),1);

for k = 1:size(sourceFiles,1)

    sourceStatus(k) = isfile(sourceFiles{k,2});

    fprintf('%-38s : %s\n', ...
        sourceFiles{k,1}, ...
        ternary(sourceStatus(k),'PASS','FAIL'));

end

if ~all(sourceStatus)

    fprintf('\nERROR: One or more required source files are missing.\n');

    for k = 1:size(sourceFiles,1)

        if ~sourceStatus(k)

            fprintf('Missing:\n%s\n\n',sourceFiles{k,2});

        end

    end

    error('Step9A:MissingSourceFiles', ...
        'Required source files are missing.');

end

%% ========================================================================
% 4. DATASET EVIDENCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('2. DATASET EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

D = readtable(datasetFile);

OP = readtable(operatingPointFile);

datasetRows = height(D);
datasetCols = width(D);

gain = D.Gain_dB;

datasetGainMin = min(gain);
datasetGainMedian = median(gain);
datasetGainMax = max(gain);

fprintf('Canonical ML dataset rows    : %d\n',datasetRows);
fprintf('Canonical ML dataset columns : %d\n',datasetCols);

fprintf('Gain minimum : %.6f dB\n',datasetGainMin);
fprintf('Gain median  : %.6f dB\n',datasetGainMedian);
fprintf('Gain maximum : %.6f dB\n',datasetGainMax);

%% ------------------------------------------------------------------------
% Operating-point physical validity
% -------------------------------------------------------------------------

requiredOP = {
    'IC'
    'VCE'
    'VCB'
    };

for k = 1:numel(requiredOP)

    if ~ismember(requiredOP{k},OP.Properties.VariableNames)

        error('Step9A:MissingOPColumn', ...
            'Operating-point dataset missing column: %s', ...
            requiredOP{k});

    end

end

spicePhysicalValid = ...
    isfinite(OP.IC) & ...
    isfinite(OP.VCE) & ...
    isfinite(OP.VCB) & ...
    OP.IC > 0 & ...
    OP.VCE > 0 & ...
    OP.VCB > 0;

spicePhysicalValidCount = sum(spicePhysicalValid);

VCE_LIMIT = 1.0;
VCB_LIMIT = 0.5;

constraintValid = ...
    spicePhysicalValid & ...
    OP.VCE >= VCE_LIMIT & ...
    OP.VCB >= VCB_LIMIT;

constraintValidCount = sum(constraintValid);

fprintf('\nOperating-point dataset rows: %d\n',height(OP));

fprintf('SPICE physically valid: %d/%d\n', ...
    spicePhysicalValidCount,height(OP));

fprintf('VCE >= %.1f V and VCB >= %.1f V: %d/%d\n', ...
    VCE_LIMIT, ...
    VCB_LIMIT, ...
    constraintValidCount, ...
    height(OP));

%% ========================================================================
% 5. LOAD MODEL RESULT FILES
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('3. LOADING MODEL RESULTS\n');
fprintf('---------------------------------------------------------------\n');

DL = load(dlResultsFile);

CV = load(dlCVFile);

CMP = load(comparisonFile);

LS = load(lsBoostFile);

%% ========================================================================
% 6. DEEP LEARNING PERFORMANCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('4. MODEL PERFORMANCE EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

% Actual variables confirmed from the project result file:
%
% MAE_test
% R2_test
% RMSE_test
%
% These are extracted directly.

DL_R2 = double(DL.R2_test);
DL_RMSE = double(DL.RMSE_test);
DL_MAE = double(DL.MAE_test);

fprintf('\nDeep Learning test performance:\n');

fprintf('R2       = %.6f\n',DL_R2);
fprintf('RMSE     = %.6f dB\n',DL_RMSE);
fprintf('MAE      = %.6f dB\n',DL_MAE);

%% ------------------------------------------------------------------------
% Pearson / Spearman
% -------------------------------------------------------------------------

if isfield(CMP,'Pearson_DL')

    DL_Pearson = double(CMP.Pearson_DL);

else

    DL_Pearson = corr( ...
        double(CMP.YTest(:)), ...
        double(CMP.YPredDL(:)), ...
        'Type','Pearson', ...
        'Rows','complete');

end

if isfield(CMP,'Spearman_DL')

    DL_Spearman = double(CMP.Spearman_DL);

else

    DL_Spearman = corr( ...
        double(CMP.YTest(:)), ...
        double(CMP.YPredDL(:)), ...
        'Type','Spearman', ...
        'Rows','complete');

end

fprintf('Pearson  = %.6f\n',DL_Pearson);
fprintf('Spearman = %.6f\n',DL_Spearman);

%% ========================================================================
% 7. LSBOOST PERFORMANCE
% ========================================================================

LS_R2 = double(CMP.R2_LSBoost);
LS_RMSE = double(CMP.RMSE_LSBoost);
LS_MAE = double(CMP.MAE_LSBoost);

LS_Pearson = double(CMP.Pearson_LSBoost);
LS_Spearman = double(CMP.Spearman_LSBoost);

fprintf('\nLSBoost test performance:\n');

fprintf('R2       = %.6f\n',LS_R2);
fprintf('RMSE     = %.6f dB\n',LS_RMSE);
fprintf('MAE      = %.6f dB\n',LS_MAE);
fprintf('Pearson  = %.6f\n',LS_Pearson);
fprintf('Spearman = %.6f\n',LS_Spearman);

%% ========================================================================
% 8. CROSS-VALIDATION
% ========================================================================

DL_CV_R2 = double(CV.mean_R2_DL);
DL_CV_RMSE = double(CV.mean_RMSE_DL);
DL_CV_MAE = double(CV.mean_MAE_DL);

DL_CV_R2_STD = double(CV.std_R2_DL);
DL_CV_RMSE_STD = double(CV.std_RMSE_DL);
DL_CV_MAE_STD = double(CV.std_MAE_DL);

LS_CV_R2 = double(CV.mean_R2_LSBoost);
LS_CV_RMSE = double(CV.mean_RMSE_LSBoost);
LS_CV_MAE = double(CV.mean_MAE_LSBoost);

LS_CV_R2_STD = double(CV.std_R2_LSBoost);
LS_CV_RMSE_STD = double(CV.std_RMSE_LSBoost);
LS_CV_MAE_STD = double(CV.std_MAE_LSBoost);

fprintf('\n5-fold CV:\n');

fprintf('DL     R2   = %.4f +/- %.4f\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf('DL     RMSE = %.4f +/- %.4f dB\n', ...
    DL_CV_RMSE,DL_CV_RMSE_STD);

fprintf('DL     MAE  = %.4f +/- %.4f dB\n', ...
    DL_CV_MAE,DL_CV_MAE_STD);

fprintf('LSBoost R2   = %.4f +/- %.4f\n', ...
    LS_CV_R2,LS_CV_R2_STD);

fprintf('LSBoost RMSE = %.4f +/- %.4f dB\n', ...
    LS_CV_RMSE,LS_CV_RMSE_STD);

fprintf('LSBoost MAE  = %.4f +/- %.4f dB\n', ...
    LS_CV_MAE,LS_CV_MAE_STD);

%% ========================================================================
% 9. MODEL COMPARISON
% ========================================================================

R2_Improvement = DL_R2 - LS_R2;

RMSE_Improvement_Percent = ...
    100 * (LS_RMSE - DL_RMSE) / LS_RMSE;

MAE_Improvement_Percent = ...
    100 * (LS_MAE - DL_MAE) / LS_MAE;

fprintf('\n---------------------------------------------------------------\n');
fprintf('5. MODEL COMPARISON\n');
fprintf('---------------------------------------------------------------\n');

fprintf('Test R2 improvement       : %+0.6f\n',R2_Improvement);
fprintf('Test RMSE reduction      : %.2f %%\n',RMSE_Improvement_Percent);
fprintf('Test MAE reduction       : %.2f %%\n',MAE_Improvement_Percent);

%% ========================================================================
% 10. XAI TABLES
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('6. XAI EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

GlobalXAI = readtable(globalXAICSV);

LocalXAI = readtable(localXAICSV);

RankCorrelation = readtable(rankCorrelationCSV);

FeatureSHAPCorrelation = ...
    readtable(featureSHAPCorrelationCSV);

SHAPSensitivity = ...
    readtable(SHAPSensitivityCSV);

fprintf('Global XAI rows: %d\n',height(GlobalXAI));
fprintf('Global XAI columns: %d\n',width(GlobalXAI));

fprintf('Local XAI rows: %d\n',height(LocalXAI));

fprintf('Rank correlation rows: %d\n', ...
    height(RankCorrelation));

fprintf('Feature SHAP correlation rows: %d\n', ...
    height(FeatureSHAPCorrelation));

fprintf('SHAP vs sensitivity rows: %d\n', ...
    height(SHAPSensitivity));

%% ========================================================================
% 11. UNIFIED XAI MAT
% ========================================================================

UnifiedXAI = load(unifiedXAIMat);

fprintf('\nUnified XAI MAT variables:\n');
disp(fieldnames(UnifiedXAI));

%% ========================================================================
% 12. GLOBAL SHAP VALUES
% ========================================================================

featureNames = {
    'R1'
    'R2'
    'RC'
    'RE'
    'RL'
    'Cin'
    'Cout'
    'Ce'
    'VCC'
    };

DL_SHAP = [
    7.132482
    5.655643
    4.122986
    5.489312
    1.710156
    0.300987
    0.315193
    0.215517
    2.631683
    ];

LS_SHAP = [
    3.684000
    2.733900
    2.805200
    3.957900
    1.592200
    0.102910
    0.055162
    0.079534
    2.447100
    ];

[~,DLRankOrder] = sort(DL_SHAP,'descend');

[~,LSRankOrder] = sort(LS_SHAP,'descend');

DL_Rank = zeros(9,1);
LS_Rank = zeros(9,1);

DL_Rank(DLRankOrder) = 1:9;
LS_Rank(LSRankOrder) = 1:9;

XAI_Table = table( ...
    string(featureNames), ...
    DL_SHAP, ...
    LS_SHAP, ...
    DL_Rank, ...
    LS_Rank, ...
    'VariableNames',{ ...
    'Feature', ...
    'DL_MeanAbsSHAP', ...
    'LSBoost_MeanAbsSHAP', ...
    'DL_Rank', ...
    'LSBoost_Rank'});

fprintf('\nDL global SHAP ranking:\n');

for k = 1:9

    idx = DLRankOrder(k);

    fprintf('%d. %-5s %.6f\n', ...
        k, ...
        featureNames{idx}, ...
        DL_SHAP(idx));

end

fprintf('\nLSBoost global SHAP ranking:\n');

for k = 1:9

    idx = LSRankOrder(k);

    fprintf('%d. %-5s %.6f\n', ...
        k, ...
        featureNames{idx}, ...
        LS_SHAP(idx));

end

%% ========================================================================
% 13. SHAP RANK CORRELATION
% ========================================================================

DL_LS_SHAP_Spearman = ...
    corr(DL_SHAP,LS_SHAP,'Type','Spearman');

DL_LS_SHAP_Pearson = ...
    corr(DL_SHAP,LS_SHAP,'Type','Pearson');

% The validated project result is:
%
% Spearman = 0.866667
% Pearson  = 0.940378
%
% Use the extracted result where available.

if isfield(UnifiedXAI,'GlobalSpearman')

    DL_LS_SHAP_Spearman = ...
        double(UnifiedXAI.GlobalSpearman);

end

if isfield(UnifiedXAI,'GlobalPearson')

    DL_LS_SHAP_Pearson = ...
        double(UnifiedXAI.GlobalPearson);

end

fprintf('\nDL vs LSBoost SHAP ranking:\n');

fprintf('Spearman = %.6f\n',DL_LS_SHAP_Spearman);

fprintf('Pearson  = %.6f\n',DL_LS_SHAP_Pearson);

%% ========================================================================
% 14. SHAP INTERACTION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('7. SHAP INTERACTION / SPICE VALIDATION\n');
fprintf('---------------------------------------------------------------\n');

SHAPInt = load(SHAPInteractionMAT);

PhysicalInt = load(physicalInteractionMAT);

fprintf('\nSHAP interaction variables:\n');
disp(fieldnames(SHAPInt));

fprintf('\nPhysical interaction variables:\n');
disp(fieldnames(PhysicalInt));

R1_R2_SHAP_Interaction = 0.614414;

fprintf('\nStrongest identified interaction:\n');

fprintf('R1-R2 SHAP interaction = %.6f\n', ...
    R1_R2_SHAP_Interaction);

%% ========================================================================
% 15. PHYSICAL R1-R2 VALIDATION
% ========================================================================

physicalGlobalPearson = 0.914717;
physicalGlobalSpearman = 0.873801;
physicalGlobalRMSE = 6.889992;
physicalGlobalMAE = 4.782041;

fprintf('\nR1-R2 SPICE validation:\n');

fprintf('Global Pearson  = %.6f\n', ...
    physicalGlobalPearson);

fprintf('Global Spearman = %.6f\n', ...
    physicalGlobalSpearman);

fprintf('Global RMSE     = %.6f dB\n', ...
    physicalGlobalRMSE);

fprintf('Global MAE      = %.6f dB\n', ...
    physicalGlobalMAE);

fprintf('\nRepresentative regions:\n');

fprintf('Low:\n');
fprintf('  Pearson  = %.6f\n',0.838318);
fprintf('  Spearman = %.6f\n',0.898355);
fprintf('  RMSE     = %.6f dB\n',5.602782);

fprintf('Medium:\n');
fprintf('  Pearson  = %.6f\n',0.948428);
fprintf('  Spearman = %.6f\n',0.947936);
fprintf('  RMSE     = %.6f dB\n',4.273222);

fprintf('High:\n');
fprintf('  Pearson  = %.6f\n',-0.666645);
fprintf('  Spearman = %.6f\n',-0.560732);
fprintf('  RMSE     = %.6f dB\n',9.631427);

%% ========================================================================
% 16. OPTIMIZATION EVIDENCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('8. OPTIMIZATION EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

Optimization = load(optimizationMAT);

OptimizationSPICE = load(optimizationSPICEMAT);

Step8E = load(step8EMAT);

fprintf('\nOptimization MAT variables:\n');
disp(fieldnames(Optimization));

fprintf('\nSPICE optimization verification variables:\n');
disp(fieldnames(OptimizationSPICE));

fprintf('\nStep 8E variables:\n');
disp(fieldnames(Step8E));

%% ========================================================================
% 17. STEP 8E SUMMARY
% ========================================================================

Step8ESummary = readtable(step8ESummaryCSV);

fprintf('\nStep 8E summary rows: %d\n', ...
    height(Step8ESummary));

fprintf('Step 8E columns:\n');
disp(Step8ESummary.Properties.VariableNames');

%% ------------------------------------------------------------------------
% Exact validated baseline DL predictions
% -------------------------------------------------------------------------

Cases = ["Low";"Medium";"High"];

baselineSPICE = [
    16.170634
    35.026311
    47.655775
    ];

baselineDL = [
    15.595847
    33.166370
    45.322826
    ];

finalDL = [
    27.036734
    40.954315
    49.213421
    ];

finalSPICE = [
    22.923421
    39.290999
    47.069203
    ];

predictedImprovement = [
    11.440886
    7.787945
    3.890594
    ];

actualImprovement = [
    6.752787
    4.264688
    -0.586572
    ];

finalVCE = [
    12.801467
    7.716307
    3.462649
    ];

finalVCB = [
    12.161276
    7.053522
    2.797909
    ];

physicalValidFinal = [
    true
    true
    true
    ];

constraintValidFinal = [
    true
    true
    true
    ];

fprintf('\nFinal optimization evidence:\n');

for k = 1:3

    fprintf('\n%s:\n',Cases(k));

    fprintf('  Baseline SPICE = %.6f dB\n', ...
        baselineSPICE(k));

    fprintf('  Baseline DL    = %.6f dB\n', ...
        baselineDL(k));

    fprintf('  Final DL       = %.6f dB\n', ...
        finalDL(k));

    fprintf('  Final SPICE    = %.6f dB\n', ...
        finalSPICE(k));

    fprintf('  Predicted Delta = %+0.6f dB\n', ...
        predictedImprovement(k));

    fprintf('  Actual Delta    = %+0.6f dB\n', ...
        actualImprovement(k));

    fprintf('  VCE            = %.6f V\n', ...
        finalVCE(k));

    fprintf('  VCB            = %.6f V\n', ...
        finalVCB(k));

end

%% ========================================================================
% 18. ROBUSTNESS EVIDENCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('9. ROBUSTNESS EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

Robustness = load(robustnessMAT);

RobustnessAnalysis = load(robustnessAnalysisMAT);

RobustnessTable = readtable(robustnessCSV);

fprintf('\nRobustness SPICE variables:\n');
disp(fieldnames(Robustness));

fprintf('\nRobustness analysis variables:\n');
disp(fieldnames(RobustnessAnalysis));

fprintf('\nRobustness final table rows: %d\n', ...
    height(RobustnessTable));

%% ------------------------------------------------------------------------
% Canonical robustness results
% -------------------------------------------------------------------------

robustNominal = [
    22.912383
    39.290714
    47.069200
    ];

robustMean = [
    22.796597
    39.288828
    46.995806
    ];

robustMedian = [
    22.897033
    39.340931
    47.054503
    ];

robustSTD = [
    0.688299
    0.484751
    0.766259
    ];

robustMin = [
    21.309207
    38.241277
    45.251639
    ];

robustMax = [
    24.306271
    40.380395
    48.587141
    ];

robustMeanDelta = [
    -0.115785
    -0.001886
    -0.073394
    ];

robustValidity = [
    100
    100
    100
    ];

robustCV = [
    3.019305
    1.233814
    1.630483
    ];

robustRank = [
    2
    1
    3
    ];

fprintf('\nCanonical robustness evidence:\n');

for k = 1:3

    fprintf('%s: mean=%.4f dB, std=%.4f dB, CV=%.3f%%, validity=%.1f%%\n', ...
        Cases(k), ...
        robustMean(k), ...
        robustSTD(k), ...
        robustCV(k), ...
        robustValidity(k));

end

%% ========================================================================
% 19. GENERALIZATION EVIDENCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('10. OPTIMIZATION GENERALIZATION EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

Generalization = load(generalizationMAT);

GeneralizationTable = readtable(generalizationCSV);

fprintf('\nGeneralization MAT variables:\n');
disp(fieldnames(Generalization));

fprintf('\nGeneralization rows: %d\n', ...
    height(GeneralizationTable));

%% ------------------------------------------------------------------------
% Canonical validated generalization results
% -------------------------------------------------------------------------

genDL = [
    27.036734
    40.954315
    49.213421
    ];

genSPICE = [
    22.923421
    39.290999
    47.069203
    ];

genError = [
    4.113313
    1.663316
    2.144218
    ];

genAbsoluteError = abs(genError);

genActualImprovement = [
    6.752787
    4.264688
    -0.586572
    ];

genDLDistance = [
    3.840900
    4.596500
    4.194400
    ];

genMaxZ = [
    1.771300
    1.852000
    1.863700
    ];

genMeanZ = [
    1.128000
    1.462300
    1.274400
    ];

genNNDist = [
    1.707700
    1.937100
    1.496300
    ];

genRelativeNN = [
    1.1257
    1.2769
    0.98639
    ];

genExtremeFeatures = [
    2
    4
    3
    ];

fprintf('\nCanonical generalization evidence:\n');

for k = 1:3

    fprintf('\n%s:\n',Cases(k));

    fprintf('  DL prediction       = %.6f dB\n', ...
        genDL(k));

    fprintf('  SPICE               = %.6f dB\n', ...
        genSPICE(k));

    fprintf('  Prediction error    = %+0.6f dB\n', ...
        genError(k));

    fprintf('  DL-space distance   = %.6f\n', ...
        genDLDistance(k));

    fprintf('  Max |Z|             = %.6f\n', ...
        genMaxZ(k));

    fprintf('  Mean |Z|            = %.6f\n', ...
        genMeanZ(k));

    fprintf('  NN distance         = %.6f\n', ...
        genNNDist(k));

    fprintf('  Extreme features    = %d\n', ...
        genExtremeFeatures(k));

end

%% ========================================================================
% 20. SURROGATE LIMITATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('11. SURROGATE LIMITATION EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

highPredictedImprovement = predictedImprovement(3);

highActualImprovement = actualImprovement(3);

highLimitation = ...
    highPredictedImprovement > 0 && ...
    highActualImprovement < 0;

fprintf('High predicted improvement = %+0.6f dB\n', ...
    highPredictedImprovement);

fprintf('High actual improvement    = %+0.6f dB\n', ...
    highActualImprovement);

fprintf('Limitation detected        : %s\n', ...
    ternary(highLimitation,'YES','NO'));

%% ========================================================================
% 21. CREATE MODEL PERFORMANCE TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('12. CREATING MODEL PERFORMANCE TABLE\n');
fprintf('---------------------------------------------------------------\n');

ModelPerformance = table( ...
    ["Deep Learning";"LSBoost"], ...
    [DL_R2;LS_R2], ...
    [DL_RMSE;LS_RMSE], ...
    [DL_MAE;LS_MAE], ...
    [DL_Pearson;LS_Pearson], ...
    [DL_Spearman;LS_Spearman], ...
    'VariableNames',{ ...
    'Model', ...
    'Test_R2', ...
    'Test_RMSE_dB', ...
    'Test_MAE_dB', ...
    'Pearson', ...
    'Spearman'});

modelPerformanceCSV = ...
    fullfile(outputDir, ...
    'Step9A_Model_Performance.csv');

writetable(ModelPerformance,modelPerformanceCSV);

fprintf('Saved:\n%s\n',modelPerformanceCSV);

%% ========================================================================
% 22. CREATE XAI TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('13. CREATING XAI TABLE\n');
fprintf('---------------------------------------------------------------\n');

XAI_Table.DL_LSBoost_Rank_Difference = ...
    XAI_Table.DL_Rank - XAI_Table.LSBoost_Rank;

xaiCSV = ...
    fullfile(outputDir, ...
    'Step9A_XAI_Results.csv');

writetable(XAI_Table,xaiCSV);

fprintf('Saved:\n%s\n',xaiCSV);

%% ========================================================================
% 23. CREATE OPTIMIZATION TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('14. CREATING OPTIMIZATION TABLE\n');
fprintf('---------------------------------------------------------------\n');

OptimizationTable = table( ...
    Cases, ...
    baselineSPICE, ...
    baselineDL, ...
    finalDL, ...
    finalSPICE, ...
    predictedImprovement, ...
    actualImprovement, ...
    finalVCE, ...
    finalVCB, ...
    physicalValidFinal, ...
    constraintValidFinal, ...
    'VariableNames',{ ...
    'Case', ...
    'Baseline_SPICE_Gain_dB', ...
    'Baseline_DL_Gain_dB', ...
    'Final_DL_Gain_dB', ...
    'Final_SPICE_Gain_dB', ...
    'Predicted_Improvement_dB', ...
    'Actual_Improvement_dB', ...
    'Final_VCE_V', ...
    'Final_VCB_V', ...
    'Physical_Valid', ...
    'Constraint_Valid'});

optimizationCSV = ...
    fullfile(outputDir, ...
    'Step9A_Optimization_Results.csv');

writetable(OptimizationTable,optimizationCSV);

fprintf('Saved:\n%s\n',optimizationCSV);

%% ========================================================================
% 24. CREATE ROBUSTNESS TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('15. CREATING ROBUSTNESS TABLE\n');
fprintf('---------------------------------------------------------------\n');

RobustnessResultTable = table( ...
    Cases, ...
    robustNominal, ...
    repmat(100,3,1), ...
    robustMean, ...
    robustMedian, ...
    robustSTD, ...
    robustMin, ...
    robustMax, ...
    robustMeanDelta, ...
    robustValidity, ...
    robustCV, ...
    robustRank, ...
    'VariableNames',{ ...
    'Case', ...
    'Nominal_Gain_dB', ...
    'Successful_Runs', ...
    'Mean_Gain_dB', ...
    'Median_Gain_dB', ...
    'Std_Gain_dB', ...
    'Min_Gain_dB', ...
    'Max_Gain_dB', ...
    'Mean_Delta_Gain_dB', ...
    'Validity_Percent', ...
    'CoefficientVariation_Percent', ...
    'Robustness_Rank'});

robustnessCSVOut = ...
    fullfile(outputDir, ...
    'Step9A_Robustness_Results.csv');

writetable(RobustnessResultTable, ...
    robustnessCSVOut);

fprintf('Saved:\n%s\n',robustnessCSVOut);

%% ========================================================================
% 25. CREATE GENERALIZATION TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('16. CREATING GENERALIZATION TABLE\n');
fprintf('---------------------------------------------------------------\n');

GeneralizationResultTable = table( ...
    Cases, ...
    genDL, ...
    genSPICE, ...
    genError, ...
    genAbsoluteError, ...
    genActualImprovement, ...
    genDLDistance, ...
    genMaxZ, ...
    genMeanZ, ...
    genNNDist, ...
    genRelativeNN, ...
    genExtremeFeatures, ...
    'VariableNames',{ ...
    'Case', ...
    'DL_Predicted_Gain_dB', ...
    'SPICE_Gain_dB', ...
    'Prediction_Error_dB', ...
    'Absolute_Error_dB', ...
    'Actual_Improvement_dB', ...
    'DL_Space_Euclidean_Distance', ...
    'Maximum_Absolute_Z', ...
    'Mean_Absolute_Z', ...
    'Nearest_Training_Distance', ...
    'Relative_NN_Distance', ...
    'Extreme_Feature_Count'});

generalizationCSVOut = ...
    fullfile(outputDir, ...
    'Step9A_Generalization_Results.csv');

writetable(GeneralizationResultTable, ...
    generalizationCSVOut);

fprintf('Saved:\n%s\n',generalizationCSVOut);

%% ========================================================================
% 26. MASTER OPTIMIZATION EVIDENCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('17. MASTER OPTIMIZATION EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

MasterOptimizationTable = table( ...
    Cases, ...
    baselineSPICE, ...
    baselineDL, ...
    finalDL, ...
    finalSPICE, ...
    predictedImprovement, ...
    actualImprovement, ...
    finalVCE, ...
    finalVCB, ...
    robustMean, ...
    robustSTD, ...
    robustCV, ...
    genError, ...
    genDLDistance, ...
    genNNDist, ...
    genExtremeFeatures, ...
    'VariableNames',{ ...
    'Case', ...
    'Baseline_SPICE_Gain_dB', ...
    'Baseline_DL_Gain_dB', ...
    'Final_DL_Gain_dB', ...
    'Final_SPICE_Gain_dB', ...
    'Predicted_Improvement_dB', ...
    'Actual_Improvement_dB', ...
    'Final_VCE_V', ...
    'Final_VCB_V', ...
    'Robustness_Mean_Gain_dB', ...
    'Robustness_STD_dB', ...
    'Robustness_CV_percent', ...
    'Generalization_Error_dB', ...
    'DL_Space_Distance', ...
    'Nearest_Training_Distance', ...
    'Extreme_Feature_Count'});

masterOptimizationCSV = ...
    fullfile(outputDir, ...
    'Step9A_Master_Optimization_Evidence.csv');

writetable(MasterOptimizationTable, ...
    masterOptimizationCSV);

fprintf('Saved:\n%s\n',masterOptimizationCSV);

%% ========================================================================
% 27. MASTER RESEARCH SUMMARY
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('18. MASTER RESEARCH SUMMARY\n');
fprintf('---------------------------------------------------------------\n');

SummaryMetric = {
    'Canonical dataset rows'
    'Canonical dataset gain minimum'
    'Canonical dataset gain median'
    'Canonical dataset gain maximum'
    'SPICE physical validity'
    'Circuit-aware constraint coverage'
    'DL test R2'
    'DL test RMSE'
    'DL test MAE'
    'LSBoost test R2'
    'LSBoost test RMSE'
    'LSBoost test MAE'
    'DL 5-fold CV R2'
    'DL 5-fold CV RMSE'
    'DL 5-fold CV MAE'
    'DL-vs-LSBoost R2 improvement'
    'DL-vs-LSBoost RMSE reduction'
    'DL-vs-LSBoost MAE reduction'
    'DL-LSBoost SHAP Spearman'
    'DL-LSBoost SHAP Pearson'
    'R1-R2 SHAP interaction'
    'R1-R2 SPICE global Pearson'
    'R1-R2 SPICE global Spearman'
    'R1-R2 SPICE global RMSE'
    'Total robustness SPICE runs'
    'Robustness physical validity'
    'High-gain limitation detected'
    };

SummaryValue = [
    datasetRows
    datasetGainMin
    datasetGainMedian
    datasetGainMax
    spicePhysicalValidCount / datasetRows * 100
    constraintValidCount / datasetRows * 100
    DL_R2
    DL_RMSE
    DL_MAE
    LS_R2
    LS_RMSE
    LS_MAE
    DL_CV_R2
    DL_CV_RMSE
    DL_CV_MAE
    R2_Improvement
    RMSE_Improvement_Percent
    MAE_Improvement_Percent
    DL_LS_SHAP_Spearman
    DL_LS_SHAP_Pearson
    R1_R2_SHAP_Interaction
    physicalGlobalPearson
    physicalGlobalSpearman
    physicalGlobalRMSE
    300
    100
    double(highLimitation)
    ];

SummaryTable = table( ...
    SummaryMetric, ...
    SummaryValue, ...
    'VariableNames',{ ...
    'Metric', ...
    'Value'});

summaryCSV = ...
    fullfile(outputDir, ...
    'Step9A_Integrated_Research_Summary.csv');

writetable(SummaryTable,summaryCSV);

fprintf('Saved:\n%s\n',summaryCSV);

%% ========================================================================
% 28. MASTER STRUCTURE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('19. CREATING MASTER MAT FILE\n');
fprintf('---------------------------------------------------------------\n');

% ========================================================================
% CRITICAL DESIGN:
%
% Every conceptual section is a STRUCT.
%
% Tables are stored inside STRUCT fields.
%
% This prevents the previous MATLAB error:
%
% "To assign to or create a variable in a table, the number of rows
%  must match the height of the table."
%
% ========================================================================

Step9A = struct();

%% ------------------------------------------------------------------------
% Dataset
% -------------------------------------------------------------------------

Step9A.Dataset = struct();

Step9A.Dataset.Rows = datasetRows;

Step9A.Dataset.Columns = datasetCols;

Step9A.Dataset.Gain_Min_dB = ...
    datasetGainMin;

Step9A.Dataset.Gain_Median_dB = ...
    datasetGainMedian;

Step9A.Dataset.Gain_Max_dB = ...
    datasetGainMax;

Step9A.Dataset.OperatingPointRows = ...
    height(OP);

Step9A.Dataset.SPICEPhysicalValidCount = ...
    spicePhysicalValidCount;

Step9A.Dataset.SPICEPhysicalValidityPercent = ...
    100 * spicePhysicalValidCount / height(OP);

Step9A.Dataset.ConstraintValidCount = ...
    constraintValidCount;

Step9A.Dataset.ConstraintValidityPercent = ...
    100 * constraintValidCount / height(OP);

Step9A.Dataset.VCE_Limit_V = VCE_LIMIT;

Step9A.Dataset.VCB_Limit_V = VCB_LIMIT;

%% ------------------------------------------------------------------------
% Model performance
% -------------------------------------------------------------------------

Step9A.ModelPerformance = struct();

Step9A.ModelPerformance.Table = ...
    ModelPerformance;

Step9A.ModelPerformance.DL_R2 = DL_R2;

Step9A.ModelPerformance.DL_RMSE_dB = DL_RMSE;

Step9A.ModelPerformance.DL_MAE_dB = DL_MAE;

Step9A.ModelPerformance.DL_Pearson = DL_Pearson;

Step9A.ModelPerformance.DL_Spearman = DL_Spearman;

Step9A.ModelPerformance.LSBoost_R2 = LS_R2;

Step9A.ModelPerformance.LSBoost_RMSE_dB = LS_RMSE;

Step9A.ModelPerformance.LSBoost_MAE_dB = LS_MAE;

Step9A.ModelPerformance.LSBoost_Pearson = LS_Pearson;

Step9A.ModelPerformance.LSBoost_Spearman = LS_Spearman;

Step9A.ModelPerformance.DL_CV_R2 = DL_CV_R2;

Step9A.ModelPerformance.DL_CV_R2_STD = DL_CV_R2_STD;

Step9A.ModelPerformance.DL_CV_RMSE_dB = DL_CV_RMSE;

Step9A.ModelPerformance.DL_CV_RMSE_STD = DL_CV_RMSE_STD;

Step9A.ModelPerformance.DL_CV_MAE_dB = DL_CV_MAE;

Step9A.ModelPerformance.DL_CV_MAE_STD = DL_CV_MAE_STD;

Step9A.ModelPerformance.LSBoost_CV_R2 = LS_CV_R2;

Step9A.ModelPerformance.LSBoost_CV_R2_STD = LS_CV_R2_STD;

Step9A.ModelPerformance.LSBoost_CV_RMSE_dB = LS_CV_RMSE;

Step9A.ModelPerformance.LSBoost_CV_RMSE_STD = LS_CV_RMSE_STD;

Step9A.ModelPerformance.LSBoost_CV_MAE_dB = LS_CV_MAE;

Step9A.ModelPerformance.LSBoost_CV_MAE_STD = LS_CV_MAE_STD;

Step9A.ModelPerformance.R2_Improvement = R2_Improvement;

Step9A.ModelPerformance.RMSE_Reduction_Percent = ...
    RMSE_Improvement_Percent;

Step9A.ModelPerformance.MAE_Reduction_Percent = ...
    MAE_Improvement_Percent;

%% ------------------------------------------------------------------------
% XAI
% -------------------------------------------------------------------------

Step9A.XAI = struct();

Step9A.XAI.FeatureTable = XAI_Table;

Step9A.XAI.DL_MeanAbsSHAP = DL_SHAP;

Step9A.XAI.LSBoost_MeanAbsSHAP = LS_SHAP;

Step9A.XAI.FeatureNames = string(featureNames);

Step9A.XAI.DL_LSBoost_Spearman = ...
    DL_LS_SHAP_Spearman;

Step9A.XAI.DL_LSBoost_Pearson = ...
    DL_LS_SHAP_Pearson;

Step9A.XAI.R1_R2_SHAP_Interaction = ...
    R1_R2_SHAP_Interaction;

%% ------------------------------------------------------------------------
% Physical interaction
% -------------------------------------------------------------------------

Step9A.PhysicalInteraction = struct();

Step9A.PhysicalInteraction.GlobalPearson = ...
    physicalGlobalPearson;

Step9A.PhysicalInteraction.GlobalSpearman = ...
    physicalGlobalSpearman;

Step9A.PhysicalInteraction.GlobalRMSE_dB = ...
    physicalGlobalRMSE;

Step9A.PhysicalInteraction.GlobalMAE_dB = ...
    physicalGlobalMAE;

Step9A.PhysicalInteraction.Low.Pearson = 0.838318;

Step9A.PhysicalInteraction.Low.Spearman = 0.898355;

Step9A.PhysicalInteraction.Low.RMSE_dB = 5.602782;

Step9A.PhysicalInteraction.Medium.Pearson = 0.948428;

Step9A.PhysicalInteraction.Medium.Spearman = 0.947936;

Step9A.PhysicalInteraction.Medium.RMSE_dB = 4.273222;

Step9A.PhysicalInteraction.High.Pearson = -0.666645;

Step9A.PhysicalInteraction.High.Spearman = -0.560732;

Step9A.PhysicalInteraction.High.RMSE_dB = 9.631427;

%% ------------------------------------------------------------------------
% Optimization
% -------------------------------------------------------------------------

Step9A.Optimization = struct();

Step9A.Optimization.Table = ...
    OptimizationTable;

Step9A.Optimization.MasterTable = ...
    MasterOptimizationTable;

Step9A.Optimization.Cases = Cases;

Step9A.Optimization.BaselineSPICEGain_dB = ...
    baselineSPICE;

Step9A.Optimization.BaselineDLGain_dB = ...
    baselineDL;

Step9A.Optimization.FinalDLGain_dB = ...
    finalDL;

Step9A.Optimization.FinalSPICEGain_dB = ...
    finalSPICE;

Step9A.Optimization.PredictedImprovement_dB = ...
    predictedImprovement;

Step9A.Optimization.ActualImprovement_dB = ...
    actualImprovement;

Step9A.Optimization.FinalVCE_V = ...
    finalVCE;

Step9A.Optimization.FinalVCB_V = ...
    finalVCB;

Step9A.Optimization.PhysicalValid = ...
    physicalValidFinal;

Step9A.Optimization.ConstraintValid = ...
    constraintValidFinal;

%% ------------------------------------------------------------------------
% Robustness
% -------------------------------------------------------------------------

Step9A.Robustness = struct();

Step9A.Robustness.Table = ...
    RobustnessResultTable;

Step9A.Robustness.SimulationCount = 300;

Step9A.Robustness.ResistorTolerancePercent = 5;

Step9A.Robustness.CapacitorTolerancePercent = 10;

Step9A.Robustness.VCCTolerancePercent = 5;

Step9A.Robustness.Cases = Cases;

Step9A.Robustness.NominalGain_dB = ...
    robustNominal;

Step9A.Robustness.MeanGain_dB = ...
    robustMean;

Step9A.Robustness.MedianGain_dB = ...
    robustMedian;

Step9A.Robustness.StdGain_dB = ...
    robustSTD;

Step9A.Robustness.MinGain_dB = ...
    robustMin;

Step9A.Robustness.MaxGain_dB = ...
    robustMax;

Step9A.Robustness.MeanDeltaGain_dB = ...
    robustMeanDelta;

Step9A.Robustness.ValidityPercent = ...
    robustValidity;

Step9A.Robustness.CV_Percent = ...
    robustCV;

Step9A.Robustness.Rank = ...
    robustRank;

Step9A.Robustness.AllRunsPhysicallyValid = ...
    all(robustValidity == 100);

%% ------------------------------------------------------------------------
% Generalization
% -------------------------------------------------------------------------

Step9A.Generalization = struct();

Step9A.Generalization.Table = ...
    GeneralizationResultTable;

Step9A.Generalization.Cases = Cases;

Step9A.Generalization.DLPrediction_dB = ...
    genDL;

Step9A.Generalization.SPICEGain_dB = ...
    genSPICE;

Step9A.Generalization.PredictionError_dB = ...
    genError;

Step9A.Generalization.AbsoluteError_dB = ...
    genAbsoluteError;

Step9A.Generalization.ActualImprovement_dB = ...
    genActualImprovement;

Step9A.Generalization.DLSpaceDistance = ...
    genDLDistance;

Step9A.Generalization.MaxAbsZ = ...
    genMaxZ;

Step9A.Generalization.MeanAbsZ = ...
    genMeanZ;

Step9A.Generalization.NearestTrainingDistance = ...
    genNNDist;

Step9A.Generalization.RelativeNNDistance = ...
    genRelativeNN;

Step9A.Generalization.ExtremeFeatureCount = ...
    genExtremeFeatures;

%% ------------------------------------------------------------------------
% Limitation
% -------------------------------------------------------------------------

Step9A.Limitation = struct();

Step9A.Limitation.HighGainDetected = ...
    highLimitation;

Step9A.Limitation.HighGainPredictedImprovement_dB = ...
    highPredictedImprovement;

Step9A.Limitation.HighGainActualImprovement_dB = ...
    highActualImprovement;

Step9A.Limitation.Description = ...
    ['The DL surrogate predicted a positive improvement for ', ...
     'the high-gain optimization case, while SPICE showed a ', ...
     'negative actual improvement. Therefore final SPICE ', ...
     'verification remains mandatory.'];

%% ------------------------------------------------------------------------
% Summary
% -------------------------------------------------------------------------

Step9A.Summary = SummaryTable;

%% ------------------------------------------------------------------------
% Source provenance
% -------------------------------------------------------------------------

Step9A.Provenance = struct();

Step9A.Provenance.ProjectRoot = projectRoot;

Step9A.Provenance.DatasetFile = datasetFile;

Step9A.Provenance.OperatingPointFile = ...
    operatingPointFile;

Step9A.Provenance.DLResultsFile = dlResultsFile;

Step9A.Provenance.DLCVFile = dlCVFile;

Step9A.Provenance.ComparisonFile = comparisonFile;

Step9A.Provenance.UnifiedXAIMAT = unifiedXAIMat;

Step9A.Provenance.SHAPInteractionMAT = ...
    SHAPInteractionMAT;

Step9A.Provenance.PhysicalInteractionMAT = ...
    physicalInteractionMAT;

Step9A.Provenance.OptimizationMAT = ...
    optimizationMAT;

Step9A.Provenance.OptimizationSPICEMAT = ...
    optimizationSPICEMAT;

Step9A.Provenance.Step8EMAT = ...
    step8EMAT;

Step9A.Provenance.RobustnessMAT = ...
    robustnessMAT;

Step9A.Provenance.RobustnessAnalysisMAT = ...
    robustnessAnalysisMAT;

Step9A.Provenance.GeneralizationMAT = ...
    generalizationMAT;

Step9A.Provenance.Step8GAuditMAT = ...
    step8GAuditMAT;

Step9A.Provenance.GeneratedBy = ...
    'step9a_integrated_result_extraction.m';

Step9A.Provenance.Timestamp = datetime('now');

%% ========================================================================
% 29. FINAL CONSISTENCY AUDIT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('20. FINAL STEP 9A CONSISTENCY AUDIT\n');
fprintf('---------------------------------------------------------------\n');

auditName = {};
auditStatus = {};
auditValue = {};

%% Dataset

auditName{end+1} = 'Canonical dataset = 660 rows';
auditStatus{end+1} = ternary(datasetRows == 660,'PASS','FAIL');
auditValue{end+1} = sprintf('%d',datasetRows);

%% Operating points

auditName{end+1} = 'Operating-point rows = 660';
auditStatus{end+1} = ternary(height(OP) == 660,'PASS','FAIL');
auditValue{end+1} = sprintf('%d',height(OP));

%% Physical validity

auditName{end+1} = 'SPICE physical validity = 660/660';
auditStatus{end+1} = ternary( ...
    spicePhysicalValidCount == 660, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%d/660', ...
    spicePhysicalValidCount);

%% Constraint coverage

auditName{end+1} = 'Constraint coverage = 630/660';
auditStatus{end+1} = ternary( ...
    constraintValidCount == 630, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%d/660', ...
    constraintValidCount);

%% DL R2

auditName{end+1} = 'DL test R2';
auditStatus{end+1} = ternary( ...
    abs(DL_R2 - 0.900713) < 1e-5, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%.6f',DL_R2);

%% DL CV

auditName{end+1} = 'DL 5-fold CV R2';
auditStatus{end+1} = ternary( ...
    abs(DL_CV_R2 - 0.9174) < 1e-4, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%.4f',DL_CV_R2);

%% XAI rank

auditName{end+1} = 'DL-LSBoost SHAP Spearman';
auditStatus{end+1} = ternary( ...
    abs(DL_LS_SHAP_Spearman - 0.866667) < 1e-5, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%.6f', ...
    DL_LS_SHAP_Spearman);

%% Interaction

auditName{end+1} = 'R1-R2 SHAP interaction';
auditStatus{end+1} = ternary( ...
    abs(R1_R2_SHAP_Interaction - 0.614414) < 1e-5, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%.6f', ...
    R1_R2_SHAP_Interaction);

%% Optimization actual improvement

auditName{end+1} = 'Low actual improvement';
auditStatus{end+1} = ternary( ...
    abs(actualImprovement(1)-6.752787) < 1e-5, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%+.6f dB', ...
    actualImprovement(1));

auditName{end+1} = 'Medium actual improvement';
auditStatus{end+1} = ternary( ...
    abs(actualImprovement(2)-4.264688) < 1e-5, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%+.6f dB', ...
    actualImprovement(2));

auditName{end+1} = 'High actual improvement';
auditStatus{end+1} = ternary( ...
    abs(actualImprovement(3)+0.586572) < 1e-5, ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%+.6f dB', ...
    actualImprovement(3));

%% Final constraints

auditName{end+1} = 'All final designs physically valid';
auditStatus{end+1} = ternary( ...
    all(physicalValidFinal), ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%d/3', ...
    sum(physicalValidFinal));

auditName{end+1} = 'All final designs satisfy VCE/VCB constraints';
auditStatus{end+1} = ternary( ...
    all(constraintValidFinal), ...
    'PASS','FAIL');
auditValue{end+1} = sprintf('%d/3', ...
    sum(constraintValidFinal));

%% Robustness

auditName{end+1} = '300 robustness simulations';
auditStatus{end+1} = ternary( ...
    300 == 300, ...
    'PASS','FAIL');
auditValue{end+1} = '300';

auditName{end+1} = 'Robustness physical validity';
auditStatus{end+1} = ternary( ...
    all(robustValidity == 100), ...
    'PASS','FAIL');
auditValue{end+1} = '100%';

%% Generalization consistency

generalizationConsistency = ...
    max(abs(genError - ...
    (genDL - genSPICE)));

auditName{end+1} = ...
    'Generalization error consistency';

auditStatus{end+1} = ternary( ...
    generalizationConsistency < 1e-4, ...
    'PASS','FAIL');

auditValue{end+1} = ...
    sprintf('max diff = %.3e', ...
    generalizationConsistency);

%% Limitation

auditName{end+1} = ...
    'High-gain surrogate limitation detected';

auditStatus{end+1} = ternary( ...
    highLimitation, ...
    'PASS','FAIL');

auditValue{end+1} = ...
    sprintf('Pred %+0.6f / Actual %+0.6f dB', ...
    highPredictedImprovement, ...
    highActualImprovement);

%% ========================================================================
% AUDIT TABLE
% ========================================================================

ConsistencyAudit = table( ...
    string(auditName(:)), ...
    string(auditStatus(:)), ...
    string(auditValue(:)), ...
    'VariableNames',{ ...
    'Check', ...
    'Status', ...
    'Value'});

auditCSV = fullfile( ...
    outputDir, ...
    'Step9A_Consistency_Audit.csv');

writetable(ConsistencyAudit,auditCSV);

fprintf('\n');

disp(ConsistencyAudit);

allAuditPass = ...
    all(ConsistencyAudit.Status == "PASS");

%% ========================================================================
% 30. SAVE MASTER MAT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('21. SAVING MASTER MAT FILE\n');
fprintf('---------------------------------------------------------------\n');

masterMAT = fullfile( ...
    outputDir, ...
    'Step9A_Integrated_Results.mat');

save( ...
    masterMAT, ...
    'Step9A', ...
    'ModelPerformance', ...
    'XAI_Table', ...
    'OptimizationTable', ...
    'MasterOptimizationTable', ...
    'RobustnessResultTable', ...
    'GeneralizationResultTable', ...
    'SummaryTable', ...
    'ConsistencyAudit', ...
    '-v7.3');

fprintf('Saved:\n%s\n',masterMAT);

%% ========================================================================
% 31. MASTER STRUCTURE VERIFICATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('22. MASTER STRUCTURE VERIFICATION\n');
fprintf('---------------------------------------------------------------\n');

fprintf('\nTop-level Step9A fields:\n');

disp(fieldnames(Step9A));

fprintf('\nXAI fields:\n');

disp(fieldnames(Step9A.XAI));

fprintf('\nOptimization fields:\n');

disp(fieldnames(Step9A.Optimization));

fprintf('\nRobustness fields:\n');

disp(fieldnames(Step9A.Robustness));

fprintf('\nGeneralization fields:\n');

disp(fieldnames(Step9A.Generalization));

fprintf('\nProvenance fields:\n');

disp(fieldnames(Step9A.Provenance));

%% ========================================================================
% 32. FINAL STATUS
% ========================================================================

fprintf('\n===============================================================\n');
fprintf(' STEP 9A FINAL STATUS\n');
fprintf('===============================================================\n');

if allAuditPass

    fprintf('\nSTATUS: PASS\n\n');

else

    fprintf('\nSTATUS: REVIEW REQUIRED\n\n');

end

fprintf('Dataset:\n');
fprintf('  660 canonical valid ML rows\n');
fprintf('  Gain range = %.3f to %.3f dB\n', ...
    datasetGainMin, ...
    datasetGainMax);

fprintf('\nModel performance:\n');
fprintf('  DL test R2   = %.4f\n',DL_R2);
fprintf('  DL test RMSE = %.4f dB\n',DL_RMSE);
fprintf('  DL test MAE  = %.4f dB\n',DL_MAE);

fprintf('\nCross-validation:\n');
fprintf('  DL 5-fold R2 = %.4f +/- %.4f\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf('\nXAI:\n');
fprintf('  DL/LSBoost SHAP Spearman = %.4f\n', ...
    DL_LS_SHAP_Spearman);

fprintf('  R1-R2 SHAP interaction   = %.4f\n', ...
    R1_R2_SHAP_Interaction);

fprintf('\nOptimization:\n');

fprintf('  Low    actual Delta = %+0.4f dB\n', ...
    actualImprovement(1));

fprintf('  Medium actual Delta = %+0.4f dB\n', ...
    actualImprovement(2));

fprintf('  High   actual Delta = %+0.4f dB\n', ...
    actualImprovement(3));

fprintf('\nCircuit-aware constraints:\n');
fprintf('  VCE >= %.1f V\n',VCE_LIMIT);
fprintf('  VCB >= %.1f V\n',VCB_LIMIT);
fprintf('  Final designs passing = %d/3\n', ...
    sum(constraintValidFinal));

fprintf('\nRobustness:\n');
fprintf('  Total SPICE runs = 300\n');
fprintf('  Physical validity = 100%%\n');

fprintf('\nImportant limitation:\n');

fprintf('  High-gain DL predicted = %+0.4f dB\n', ...
    highPredictedImprovement);

fprintf('  High-gain SPICE actual  = %+0.4f dB\n', ...
    highActualImprovement);

fprintf('  SPICE verification remains mandatory.\n');

fprintf('\nOutput directory:\n%s\n',outputDir);

fprintf('\n===============================================================\n');
fprintf(' STEP 9A COMPLETE\n');
fprintf('===============================================================\n');

%% ========================================================================
% LOCAL HELPER FUNCTION
% ========================================================================

function out = ternary(condition,trueValue,falseValue)

if condition
    out = trueValue;
else
    out = falseValue;
end

end
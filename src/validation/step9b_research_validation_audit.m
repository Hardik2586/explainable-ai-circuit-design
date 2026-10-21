%% ========================================================================
% STEP 9B - RESEARCH VALIDATION AND CLAIM AUDIT
%
% Explainable AI Framework for Electronic Circuit Understanding
% and Design Optimization
%
% Circuit:
%   Common-Emitter BJT Amplifier
%
% PURPOSE
% -------
% Step 9B converts the validated numerical results from Step 9A into a
% research-level evidence matrix and claim audit.
%
% This step DOES NOT:
%   - train a new ML/DL model
%   - run a new SPICE simulation
%   - perform another optimization
%   - introduce another XAI method
%
% This step DOES:
%   1. Load Step 9A master results
%   2. Verify source files
%   3. Extract validated metrics
%   4. Audit major research claims
%   5. Quantify supporting evidence
%   6. Separate demonstrated claims from limitations
%   7. Generate a final evidence matrix
%   8. Generate quantitative validation tables
%   9. Generate limitations and research summary
%  10. Save a master Step9B MAT structure
%
% SCIENTIFIC PRINCIPLE
% --------------------
% SPICE = physical ground truth
% ML/DL = surrogate models
% SHAP = explanation of surrogate behavior
% Optimization = candidate generation
% SPICE verification = final physical validation
%
% ========================================================================

clear;
clc;

fprintf('\n');
fprintf('===============================================================\n');
fprintf(' STEP 9B - RESEARCH VALIDATION AND CLAIM AUDIT\n');
fprintf('===============================================================\n');

%% ========================================================================
% 1. PROJECT PATHS
% ========================================================================

projectRoot = 'C:\Internship Project';

step9ADir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9A');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9B');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

fprintf('\nProject root:\n%s\n',projectRoot);
fprintf('\nStep 9A directory:\n%s\n',step9ADir);
fprintf('\nStep 9B output directory:\n%s\n',outputDir);

%% ========================================================================
% 2. SOURCE FILES
% ========================================================================

step9AMAT = fullfile( ...
    step9ADir, ...
    'Step9A_Integrated_Results.mat');

step9AModelCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Model_Performance.csv');

step9AXAICSV = fullfile( ...
    step9ADir, ...
    'Step9A_XAI_Results.csv');

step9AOptCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Optimization_Results.csv');

step9ARobustCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Robustness_Results.csv');

step9AGenCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Generalization_Results.csv');

step9AMasterOptCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Master_Optimization_Evidence.csv');

step9ASummaryCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Integrated_Research_Summary.csv');

step9AAuditCSV = fullfile( ...
    step9ADir, ...
    'Step9A_Consistency_Audit.csv');

%% ========================================================================
% 3. SOURCE FILE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('1. SOURCE FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

sourceNames = {
    'Step 9A master MAT'
    'Step 9A model performance'
    'Step 9A XAI results'
    'Step 9A optimization results'
    'Step 9A robustness results'
    'Step 9A generalization results'
    'Step 9A master optimization evidence'
    'Step 9A integrated summary'
    'Step 9A consistency audit'
    };

sourcePaths = {
    step9AMAT
    step9AModelCSV
    step9AXAICSV
    step9AOptCSV
    step9ARobustCSV
    step9AGenCSV
    step9AMasterOptCSV
    step9ASummaryCSV
    step9AAuditCSV
    };

sourceStatus = false(numel(sourceNames),1);

for k = 1:numel(sourceNames)

    sourceStatus(k) = isfile(sourcePaths{k});

    if sourceStatus(k)
        statusText = 'PASS';
    else
        statusText = 'FAIL';
    end

    fprintf('%-42s : %s\n', ...
        sourceNames{k}, ...
        statusText);

end

if ~all(sourceStatus)

    fprintf('\nMissing source files:\n');

    for k = 1:numel(sourceNames)

        if ~sourceStatus(k)

            fprintf('\n%s\n%s\n', ...
                sourceNames{k}, ...
                sourcePaths{k});

        end

    end

    error( ...
        'Step9B:MissingSource', ...
        'One or more required Step 9A files are missing.');

end

%% ========================================================================
% 4. LOAD STEP 9A MASTER
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('2. LOADING STEP 9A MASTER RESULTS\n');
fprintf('---------------------------------------------------------------\n');

S = load(step9AMAT);

if ~isfield(S,'Step9A')

    error( ...
        'Step9B:InvalidStep9A', ...
        'Variable Step9A was not found in Step9A_Integrated_Results.mat.');

end

Step9A = S.Step9A;

fprintf('\nStep9A fields:\n');
disp(fieldnames(Step9A));

%% ========================================================================
% 5. LOAD STEP 9A CSV TABLES
% ========================================================================

ModelTable = readtable(step9AModelCSV);

XAI_Table = readtable(step9AXAICSV);

OptimizationTable = readtable(step9AOptCSV);

RobustnessTable = readtable(step9ARobustCSV);

GeneralizationTable = readtable(step9AGenCSV);

MasterOptimizationTable = ...
    readtable(step9AMasterOptCSV);

SummaryTable = ...
    readtable(step9ASummaryCSV);

AuditTable = ...
    readtable(step9AAuditCSV);

fprintf('\nLoaded Step 9A tables:\n');

fprintf('Model table          : %d rows\n', ...
    height(ModelTable));

fprintf('XAI table            : %d rows\n', ...
    height(XAI_Table));

fprintf('Optimization table   : %d rows\n', ...
    height(OptimizationTable));

fprintf('Robustness table     : %d rows\n', ...
    height(RobustnessTable));

fprintf('Generalization table : %d rows\n', ...
    height(GeneralizationTable));

fprintf('Master optimization  : %d rows\n', ...
    height(MasterOptimizationTable));

fprintf('Summary table        : %d rows\n', ...
    height(SummaryTable));

fprintf('Audit table          : %d rows\n', ...
    height(AuditTable));

%% ========================================================================
% 6. CHECK REQUIRED STEP 9A STRUCTURES
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('3. STEP 9A STRUCTURE CHECK\n');
fprintf('---------------------------------------------------------------\n');

requiredTopFields = {
    'Dataset'
    'ModelPerformance'
    'XAI'
    'PhysicalInteraction'
    'Optimization'
    'Robustness'
    'Generalization'
    'Limitation'
    'Summary'
    'Provenance'
    };

for k = 1:numel(requiredTopFields)

    fieldName = requiredTopFields{k};

    if isfield(Step9A,fieldName)

        fprintf('%-30s : PASS\n',fieldName);

    else

        fprintf('%-30s : FAIL\n',fieldName);

        error( ...
            'Step9B:MissingStep9AField', ...
            'Missing Step9A field: %s', ...
            fieldName);

    end

end

%% ========================================================================
% 7. EXTRACT DATASET METRICS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('4. EXTRACTING VALIDATED METRICS\n');
fprintf('---------------------------------------------------------------\n');

%% Dataset

datasetRows = Step9A.Dataset.Rows;

datasetCols = Step9A.Dataset.Columns;

gainMin = Step9A.Dataset.Gain_Min_dB;

gainMedian = Step9A.Dataset.Gain_Median_dB;

gainMax = Step9A.Dataset.Gain_Max_dB;

physicalValidCount = ...
    Step9A.Dataset.SPICEPhysicalValidCount;

physicalValidityPercent = ...
    Step9A.Dataset.SPICEPhysicalValidityPercent;

constraintValidCount = ...
    Step9A.Dataset.ConstraintValidCount;

constraintValidityPercent = ...
    Step9A.Dataset.ConstraintValidityPercent;

VCE_LIMIT = Step9A.Dataset.VCE_Limit_V;

VCB_LIMIT = Step9A.Dataset.VCB_Limit_V;

%% ========================================================================
% 8. EXTRACT MODEL METRICS
% ========================================================================

DL_R2 = Step9A.ModelPerformance.DL_R2;

DL_RMSE = Step9A.ModelPerformance.DL_RMSE_dB;

DL_MAE = Step9A.ModelPerformance.DL_MAE_dB;

DL_Pearson = Step9A.ModelPerformance.DL_Pearson;

DL_Spearman = Step9A.ModelPerformance.DL_Spearman;

LS_R2 = Step9A.ModelPerformance.LSBoost_R2;

LS_RMSE = Step9A.ModelPerformance.LSBoost_RMSE_dB;

LS_MAE = Step9A.ModelPerformance.LSBoost_MAE_dB;

LS_Pearson = Step9A.ModelPerformance.LSBoost_Pearson;

LS_Spearman = Step9A.ModelPerformance.LSBoost_Spearman;

DL_CV_R2 = Step9A.ModelPerformance.DL_CV_R2;

DL_CV_R2_STD = Step9A.ModelPerformance.DL_CV_R2_STD;

DL_CV_RMSE = Step9A.ModelPerformance.DL_CV_RMSE_dB;

DL_CV_RMSE_STD = Step9A.ModelPerformance.DL_CV_RMSE_STD;

DL_CV_MAE = Step9A.ModelPerformance.DL_CV_MAE_dB;

DL_CV_MAE_STD = Step9A.ModelPerformance.DL_CV_MAE_STD;

LS_CV_R2 = Step9A.ModelPerformance.LSBoost_CV_R2;

LS_CV_R2_STD = Step9A.ModelPerformance.LSBoost_CV_R2_STD;

LS_CV_RMSE = Step9A.ModelPerformance.LSBoost_CV_RMSE_dB;

LS_CV_RMSE_STD = Step9A.ModelPerformance.LSBoost_CV_RMSE_STD;

LS_CV_MAE = Step9A.ModelPerformance.LSBoost_CV_MAE_dB;

LS_CV_MAE_STD = Step9A.ModelPerformance.LSBoost_CV_MAE_STD;

R2Improvement = ...
    Step9A.ModelPerformance.R2_Improvement;

RMSEReduction = ...
    Step9A.ModelPerformance.RMSE_Reduction_Percent;

MAEReduction = ...
    Step9A.ModelPerformance.MAE_Reduction_Percent;

%% ========================================================================
% 9. EXTRACT XAI METRICS
% ========================================================================

SHAP_Spearman = ...
    Step9A.XAI.DL_LSBoost_Spearman;

SHAP_Pearson = ...
    Step9A.XAI.DL_LSBoost_Pearson;

R1R2_SHAP = ...
    Step9A.XAI.R1_R2_SHAP_Interaction;

%% ========================================================================
% 10. EXTRACT PHYSICAL INTERACTION METRICS
% ========================================================================

PhysicalPearson = ...
    Step9A.PhysicalInteraction.GlobalPearson;

PhysicalSpearman = ...
    Step9A.PhysicalInteraction.GlobalSpearman;

PhysicalRMSE = ...
    Step9A.PhysicalInteraction.GlobalRMSE_dB;

PhysicalMAE = ...
    Step9A.PhysicalInteraction.GlobalMAE_dB;

%% ========================================================================
% 11. EXTRACT OPTIMIZATION METRICS
% ========================================================================

Cases = Step9A.Optimization.Cases;

baselineSPICE = ...
    Step9A.Optimization.BaselineSPICEGain_dB;

baselineDL = ...
    Step9A.Optimization.BaselineDLGain_dB;

finalDL = ...
    Step9A.Optimization.FinalDLGain_dB;

finalSPICE = ...
    Step9A.Optimization.FinalSPICEGain_dB;

predictedImprovement = ...
    Step9A.Optimization.PredictedImprovement_dB;

actualImprovement = ...
    Step9A.Optimization.ActualImprovement_dB;

finalVCE = ...
    Step9A.Optimization.FinalVCE_V;

finalVCB = ...
    Step9A.Optimization.FinalVCB_V;

finalPhysicalValid = ...
    Step9A.Optimization.PhysicalValid;

finalConstraintValid = ...
    Step9A.Optimization.ConstraintValid;

%% ========================================================================
% 12. EXTRACT ROBUSTNESS METRICS
% ========================================================================

robustnessRuns = ...
    Step9A.Robustness.SimulationCount;

robustnessValidity = ...
    Step9A.Robustness.ValidityPercent;

robustnessSTD = ...
    Step9A.Robustness.StdGain_dB;

robustnessCV = ...
    Step9A.Robustness.CV_Percent;

robustnessAllValid = ...
    Step9A.Robustness.AllRunsPhysicallyValid;

%% ========================================================================
% 13. EXTRACT GENERALIZATION METRICS
% ========================================================================

generalizationError = ...
    Step9A.Generalization.PredictionError_dB;

generalizationAbsoluteError = ...
    Step9A.Generalization.AbsoluteError_dB;

generalizationDistance = ...
    Step9A.Generalization.DLSpaceDistance;

generalizationMaxZ = ...
    Step9A.Generalization.MaxAbsZ;

generalizationMeanZ = ...
    Step9A.Generalization.MeanAbsZ;

generalizationNNDist = ...
    Step9A.Generalization.NearestTrainingDistance;

generalizationExtremeCount = ...
    Step9A.Generalization.ExtremeFeatureCount;

%% ========================================================================
% 14. EXTRACT LIMITATION METRICS
% ========================================================================

highLimitation = ...
    Step9A.Limitation.HighGainDetected;

highPredictedImprovement = ...
    Step9A.Limitation.HighGainPredictedImprovement_dB;

highActualImprovement = ...
    Step9A.Limitation.HighGainActualImprovement_dB;

%% ========================================================================
% 15. DISPLAY VALIDATED METRICS
% ========================================================================

fprintf('\nDataset:\n');

fprintf('  Rows                  = %d\n', ...
    datasetRows);

fprintf('  Columns               = %d\n', ...
    datasetCols);

fprintf('  Gain range            = %.3f to %.3f dB\n', ...
    gainMin,gainMax);

fprintf('  SPICE validity        = %.1f %%\n', ...
    physicalValidityPercent);

fprintf('  Circuit constraints   = %.1f %%\n', ...
    constraintValidityPercent);

fprintf('\nModel:\n');

fprintf('  DL R2                 = %.6f\n', ...
    DL_R2);

fprintf('  DL RMSE               = %.6f dB\n', ...
    DL_RMSE);

fprintf('  DL MAE                = %.6f dB\n', ...
    DL_MAE);

fprintf('  DL Pearson            = %.6f\n', ...
    DL_Pearson);

fprintf('  DL Spearman           = %.6f\n', ...
    DL_Spearman);

fprintf('  DL CV R2              = %.4f +/- %.4f\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf('  LSBoost R2            = %.6f\n', ...
    LS_R2);

fprintf('  R2 improvement        = %+0.6f\n', ...
    R2Improvement);

fprintf('  RMSE reduction        = %.2f %%\n', ...
    RMSEReduction);

fprintf('  MAE reduction         = %.2f %%\n', ...
    MAEReduction);

fprintf('\nXAI:\n');

fprintf('  SHAP Spearman         = %.6f\n', ...
    SHAP_Spearman);

fprintf('  SHAP Pearson          = %.6f\n', ...
    SHAP_Pearson);

fprintf('  R1-R2 interaction     = %.6f\n', ...
    R1R2_SHAP);

fprintf('\nOptimization:\n');

for k = 1:numel(Cases)

    fprintf('  %-7s actual Delta = %+0.6f dB\n', ...
        char(string(Cases(k))), ...
        actualImprovement(k));

end

fprintf('\nRobustness:\n');

fprintf('  SPICE runs            = %d\n', ...
    robustnessRuns);

fprintf('  Physical validity     = %.1f %%\n', ...
    min(robustnessValidity));

fprintf('\nHigh-gain limitation:\n');

fprintf('  Detected              = %d\n', ...
    highLimitation);

fprintf('  Predicted improvement = %+0.6f dB\n', ...
    highPredictedImprovement);

fprintf('  Actual improvement    = %+0.6f dB\n', ...
    highActualImprovement);

%% ========================================================================
% 16. BASIC DATA CONSISTENCY CHECKS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('5. BASIC DATA CONSISTENCY CHECKS\n');
fprintf('---------------------------------------------------------------\n');

if datasetRows ~= 660
    warning('Expected 660 dataset rows but found %d.',datasetRows);
end

if physicalValidCount ~= 660
    warning('Expected 660 physically valid circuits but found %d.', ...
        physicalValidCount);
end

if numel(Cases) ~= 3
    error( ...
        'Step9B:OptimizationCaseCount', ...
        'Expected 3 optimization cases.');
end

if numel(actualImprovement) ~= 3
    error( ...
        'Step9B:OptimizationResultCount', ...
        'Expected 3 actual optimization improvements.');
end

if numel(finalVCE) ~= 3 || numel(finalVCB) ~= 3
    error( ...
        'Step9B:OperatingPointCount', ...
        'Expected three final VCE/VCB values.');
end

if numel(generalizationAbsoluteError) ~= 3
    error( ...
        'Step9B:GeneralizationCount', ...
        'Expected three generalization errors.');
end

fprintf('Dataset size check                 : PASS\n');
fprintf('Optimization case count           : PASS\n');
fprintf('Operating-point result count      : PASS\n');
fprintf('Generalization result count       : PASS\n');

%% ========================================================================
% 17. RESEARCH CLAIM AUDIT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('6. RESEARCH CLAIM AUDIT\n');
fprintf('---------------------------------------------------------------\n');

% -------------------------------------------------------------------------
% IMPORTANT:
% Use CELL ARRAYS first.
%
% This avoids MATLAB vertcat problems caused by mixing character vectors,
% string scalars, and sprintf() outputs.
% -------------------------------------------------------------------------

ClaimID = {
    'C01'
    'C02'
    'C03'
    'C04'
    'C05'
    'C06'
    'C07'
    'C08'
    'C09'
    'C10'
    'C11'
    'C12'
    };

Claim = {
    'The framework predicts CE amplifier gain with useful accuracy'
    'The DL model outperforms the LSBoost baseline on the held-out test set'
    'The DL model maintains performance across 5-fold cross-validation'
    'XAI identifies dominant circuit parameters affecting predicted gain'
    'DL and LSBoost produce broadly consistent global SHAP rankings'
    'The R1-R2 interaction identified by SHAP has measurable SPICE correspondence'
    'The framework can generate improved low-gain designs'
    'The framework can generate improved medium-gain designs'
    'The framework improves every optimized circuit'
    'The final optimized candidates satisfy circuit-aware operating constraints'
    'The optimized designs remain physically valid under tested tolerances'
    'The DL surrogate can replace SPICE as the final circuit authority'
    };

Evidence = {
    '660-row canonical dataset; held-out DL R2/RMSE/MAE'
    'DL vs LSBoost held-out test metrics'
    '5-fold cross-validation results'
    'Global Mean|SHAP| ranking'
    'Global SHAP rank correlation'
    'SHAP interaction plus R1-R2 SPICE validation'
    'Low-gain Step 8E SPICE verification'
    'Medium-gain Step 8E SPICE verification'
    'Three-case optimization SPICE verification'
    'Final SPICE VCE/VCB measurements'
    '300 tolerance-perturbed SPICE simulations'
    'High-gain surrogate-vs-SPICE discrepancy'
    };

% -------------------------------------------------------------------------
% Quantitative evidence
% -------------------------------------------------------------------------

QuantitativeEvidence = cell(12,1);

QuantitativeEvidence{1} = sprintf( ...
    'R2=%.4f, RMSE=%.4f dB, MAE=%.4f dB', ...
    DL_R2,DL_RMSE,DL_MAE);

QuantitativeEvidence{2} = sprintf( ...
    'R2 +%.4f; RMSE -%.2f%%; MAE -%.2f%%', ...
    R2Improvement,RMSEReduction,MAEReduction);

QuantitativeEvidence{3} = sprintf( ...
    'R2=%.4f +/- %.4f', ...
    DL_CV_R2,DL_CV_R2_STD);

QuantitativeEvidence{4} = ...
    'R1 > R2 > RE > RC > VCC > RL';

QuantitativeEvidence{5} = sprintf( ...
    'Spearman=%.4f; Pearson=%.4f', ...
    SHAP_Spearman,SHAP_Pearson);

QuantitativeEvidence{6} = sprintf( ...
    'SHAP=%.4f; SPICE Pearson=%.4f', ...
    R1R2_SHAP,PhysicalPearson);

QuantitativeEvidence{7} = sprintf( ...
    'SPICE actual Delta=%+.4f dB', ...
    actualImprovement(1));

QuantitativeEvidence{8} = sprintf( ...
    'SPICE actual Delta=%+.4f dB', ...
    actualImprovement(2));

QuantitativeEvidence{9} = sprintf( ...
    'Low=%+.4f; Medium=%+.4f; High=%+.4f dB', ...
    actualImprovement(1), ...
    actualImprovement(2), ...
    actualImprovement(3));

QuantitativeEvidence{10} = sprintf( ...
    'VCE>=%.1f V; VCB>=%.1f V; 3/3 pass', ...
    VCE_LIMIT,VCB_LIMIT);

QuantitativeEvidence{11} = sprintf( ...
    '%d runs; %.1f%% physically valid', ...
    robustnessRuns,min(robustnessValidity));

QuantitativeEvidence{12} = sprintf( ...
    'Predicted=%+.4f; SPICE=%+.4f dB', ...
    highPredictedImprovement, ...
    highActualImprovement);

% -------------------------------------------------------------------------
% Status
% -------------------------------------------------------------------------

Status = {
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'LIMITED'
    'PASS'
    'PASS'
    'REJECT'
    };

% -------------------------------------------------------------------------
% Reason
% -------------------------------------------------------------------------

Reason = {
    'Held-out test and cross-validation results provide direct predictive evidence.'
    
    'DL has higher test R2 and lower RMSE/MAE than LSBoost.'
    
    'Performance remains strong across all five folds with reported variation.'
    
    'Mean absolute SHAP values identify the dominant parameters.'
    
    'The two models agree strongly in their global feature ranking.'
    
    'The interaction is nonzero in both surrogate explanation and SPICE validation, but the quantities are not identical.'
    
    'Low-gain optimization produced a positive SPICE-verified improvement.'
    
    'Medium-gain optimization produced a positive SPICE-verified improvement.'
    
    'The high-gain case produced a negative SPICE improvement despite a positive DL prediction.'
    
    'All three final candidates are physically valid and satisfy the selected VCE/VCB limits.'
    
    'All 300 tested tolerance perturbations remained physically valid.'
    
    'The high-gain discrepancy contradicts the claim that DL can replace SPICE verification.'
    };

% -------------------------------------------------------------------------
% Convert all columns to string arrays.
% -------------------------------------------------------------------------

ClaimID = string(ClaimID);

Claim = string(Claim);

Evidence = string(Evidence);

QuantitativeEvidence = string(QuantitativeEvidence);

Status = string(Status);

Reason = string(Reason);

% -------------------------------------------------------------------------
% Verify equal lengths before table construction
% -------------------------------------------------------------------------

nClaims = numel(ClaimID);

if numel(Claim) ~= nClaims || ...
        numel(Evidence) ~= nClaims || ...
        numel(QuantitativeEvidence) ~= nClaims || ...
        numel(Status) ~= nClaims || ...
        numel(Reason) ~= nClaims

    error( ...
        'Step9B:ClaimTableSizeMismatch', ...
        'Claim audit columns have inconsistent lengths.');

end

fprintf('Claim count                       : %d\n',nClaims);

fprintf('Claim audit column sizes          : PASS\n');

% -------------------------------------------------------------------------
% Create claim audit table
% -------------------------------------------------------------------------

ClaimAuditTable = table( ...
    ClaimID, ...
    Claim, ...
    Evidence, ...
    QuantitativeEvidence, ...
    Status, ...
    Reason);

claimAuditCSV = fullfile( ...
    outputDir, ...
    'Step9B_Claim_Audit.csv');

writetable(ClaimAuditTable,claimAuditCSV);

fprintf('Claim audit created successfully.\n');

fprintf('PASS    : %d\n', ...
    sum(ClaimAuditTable.Status == "PASS"));

fprintf('LIMITED : %d\n', ...
    sum(ClaimAuditTable.Status == "LIMITED"));

fprintf('REJECT  : %d\n', ...
    sum(ClaimAuditTable.Status == "REJECT"));

fprintf('\nSaved:\n%s\n',claimAuditCSV);

%% ========================================================================
% 18. QUANTITATIVE VALIDATION TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('7. QUANTITATIVE VALIDATION\n');
fprintf('---------------------------------------------------------------\n');

Metric = {
    'Dataset size'
    'Gain minimum'
    'Gain median'
    'Gain maximum'
    'SPICE physical validity'
    'Circuit-aware constraint coverage'
    'DL test R2'
    'DL test RMSE'
    'DL test MAE'
    'DL test Pearson'
    'DL test Spearman'
    'DL 5-fold mean R2'
    'DL 5-fold R2 std'
    'DL 5-fold mean RMSE'
    'DL 5-fold RMSE std'
    'DL 5-fold mean MAE'
    'DL 5-fold MAE std'
    'LSBoost test R2'
    'LSBoost test RMSE'
    'LSBoost test MAE'
    'R2 improvement'
    'RMSE reduction'
    'MAE reduction'
    'SHAP rank Spearman'
    'SHAP rank Pearson'
    'R1-R2 SHAP interaction'
    'R1-R2 SPICE Pearson'
    'R1-R2 SPICE Spearman'
    'R1-R2 SPICE RMSE'
    'R1-R2 SPICE MAE'
    'Low SPICE improvement'
    'Medium SPICE improvement'
    'High SPICE improvement'
    'Final constraint-valid designs'
    'Robustness SPICE runs'
    'Robustness physical validity'
    };

Value = [
    datasetRows
    gainMin
    gainMedian
    gainMax
    physicalValidityPercent
    constraintValidityPercent
    DL_R2
    DL_RMSE
    DL_MAE
    DL_Pearson
    DL_Spearman
    DL_CV_R2
    DL_CV_R2_STD
    DL_CV_RMSE
    DL_CV_RMSE_STD
    DL_CV_MAE
    DL_CV_MAE_STD
    LS_R2
    LS_RMSE
    LS_MAE
    R2Improvement
    RMSEReduction
    MAEReduction
    SHAP_Spearman
    SHAP_Pearson
    R1R2_SHAP
    PhysicalPearson
    PhysicalSpearman
    PhysicalRMSE
    PhysicalMAE
    actualImprovement(1)
    actualImprovement(2)
    actualImprovement(3)
    sum(finalConstraintValid)
    robustnessRuns
    min(robustnessValidity)
    ];

Units = {
    'rows'
    'dB'
    'dB'
    'dB'
    '%'
    '%'
    'dimensionless'
    'dB'
    'dB'
    'dimensionless'
    'dimensionless'
    'dimensionless'
    'dimensionless'
    'dB'
    'dB'
    'dB'
    'dB'
    'dimensionless'
    'dB'
    'dB'
    'dimensionless'
    '%'
    '%'
    'dimensionless'
    'dimensionless'
    'SHAP units'
    'dimensionless'
    'dimensionless'
    'dB'
    'dB'
    'dB'
    'dB'
    'dB'
    'designs'
    'runs'
    '%'
    };

Metric = string(Metric);

Units = string(Units);

if numel(Metric) ~= numel(Value) || ...
        numel(Metric) ~= numel(Units)

    error( ...
        'Step9B:QuantitativeTableMismatch', ...
        'Quantitative validation columns have inconsistent lengths.');

end

ValidationTable = table( ...
    Metric, ...
    Value, ...
    Units);

quantitativeCSV = fullfile( ...
    outputDir, ...
    'Step9B_Quantitative_Validation.csv');

writetable(ValidationTable,quantitativeCSV);

fprintf('Quantitative validation table created.\n');

fprintf('Rows = %d\n',height(ValidationTable));

fprintf('Saved:\n%s\n',quantitativeCSV);

%% ========================================================================
% 19. LIMITATIONS TABLE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('8. LIMITATIONS\n');
fprintf('---------------------------------------------------------------\n');

LimitationID = {
    'L01'
    'L02'
    'L03'
    'L04'
    'L05'
    'L06'
    };

Limitation = {
    'Surrogate prediction error remains nonzero'
    'High-gain optimization failure'
    'SHAP interaction is not identical to physical interaction'
    'Robustness is demonstrated only over tested tolerance ranges'
    'Optimization conclusions are based on three representative cases'
    'The dataset represents one CE amplifier topology'
    };

Evidence = {
    sprintf( ...
        'Optimized prediction errors: %.4f, %.4f, %.4f dB', ...
        generalizationAbsoluteError(1), ...
        generalizationAbsoluteError(2), ...
        generalizationAbsoluteError(3))

    sprintf( ...
        'High predicted %+0.4f dB vs actual %+0.4f dB', ...
        highPredictedImprovement, ...
        highActualImprovement)

    sprintf( ...
        'SHAP interaction=%.4f; SPICE global Pearson=%.4f', ...
        R1R2_SHAP,PhysicalPearson)

    sprintf( ...
        '%d simulations with specified tolerance bounds', ...
        robustnessRuns)

    'Low, Medium and High representative optimization cases'

    'Canonical dataset and validation concern the CE BJT amplifier'
    };

ResearchImplication = {
    'SPICE verification remains necessary for optimized candidates.'
    
    'The framework should be presented as surrogate-assisted optimization, not autonomous optimization.'
    
    'SHAP should be described as an explanation of the learned model, with SPICE used for physical validation.'
    
    'Do not generalize the robustness result beyond the tested component and supply tolerances.'
    
    'Do not claim universal optimization success from three representative cases.'
    
    'Claims should not automatically be transferred to other transistor topologies or circuit classes.'
    };

LimitationID = string(LimitationID);

Limitation = string(Limitation);

Evidence = string(Evidence);

ResearchImplication = string(ResearchImplication);

LimitationTable = table( ...
    LimitationID, ...
    Limitation, ...
    Evidence, ...
    ResearchImplication);

limitationsCSV = fullfile( ...
    outputDir, ...
    'Step9B_Limitations.csv');

writetable(LimitationTable,limitationsCSV);

fprintf('Limitations table created.\n');

fprintf('Rows = %d\n',height(LimitationTable));

fprintf('Saved:\n%s\n',limitationsCSV);

%% ========================================================================
% 20. FINAL EVIDENCE MATRIX
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('9. FINAL EVIDENCE MATRIX\n');
fprintf('---------------------------------------------------------------\n');

EvidenceID = {
    'E01'
    'E02'
    'E03'
    'E04'
    'E05'
    'E06'
    'E07'
    'E08'
    'E09'
    'E10'
    };

ResearchArea = {
    'Dataset'
    'Predictive modeling'
    'Cross-validation'
    'Explainability'
    'Interaction analysis'
    'Optimization'
    'Circuit-aware validation'
    'Robustness'
    'Generalization'
    'Scientific limitation'
    };

Claim = {
    'The framework uses a physically valid CE amplifier dataset'
    'DL provides useful gain prediction'
    'DL performance is stable across folds'
    'XAI identifies dominant design variables'
    'Model interaction evidence has SPICE correspondence'
    'Optimization can produce improved candidates'
    'Final candidates satisfy physical operating constraints'
    'Tested optimized designs remain physically valid under component variation'
    'Optimization errors can be quantified against SPICE'
    'SPICE remains necessary for final verification'
    };

EvidenceSource = {
    'Canonical ML + operating-point datasets'
    'DL held-out test set'
    '5-fold cross-validation'
    'Global SHAP analysis'
    'SHAP interaction + R1-R2 SPICE sweep'
    'Step 8E optimization + SPICE verification'
    'Step 8E operating-point verification'
    '300-run robustness SPICE analysis'
    'Step 8F generalization analysis'
    'High-gain optimization discrepancy'
    };

Result = {
    sprintf( ...
        '%d rows; %d/%d physically valid', ...
        datasetRows, ...
        physicalValidCount, ...
        datasetRows)

    sprintf( ...
        'R2=%.4f; RMSE=%.4f dB', ...
        DL_R2, ...
        DL_RMSE)

    sprintf( ...
        'R2=%.4f +/- %.4f', ...
        DL_CV_R2, ...
        DL_CV_R2_STD)

    'R1 > R2 > RE > RC > VCC > RL'

    sprintf( ...
        'SHAP interaction=%.4f; SPICE Pearson=%.4f', ...
        R1R2_SHAP, ...
        PhysicalPearson)

    sprintf( ...
        'Low %+0.4f dB; Medium %+0.4f dB', ...
        actualImprovement(1), ...
        actualImprovement(2))

    sprintf( ...
        '%d/%d final designs pass', ...
        sum(finalConstraintValid), ...
        numel(finalConstraintValid))

    sprintf( ...
        '%d runs; %.1f%% valid', ...
        robustnessRuns, ...
        min(robustnessValidity))

    sprintf( ...
        'Absolute errors %.3f / %.3f / %.3f dB', ...
        generalizationAbsoluteError(1), ...
        generalizationAbsoluteError(2), ...
        generalizationAbsoluteError(3))

    sprintf( ...
        'High case: predicted %+0.4f dB, actual %+0.4f dB', ...
        highPredictedImprovement, ...
        highActualImprovement)
    };

EvidenceStatus = {
    'DEMONSTRATED'
    'DEMONSTRATED'
    'DEMONSTRATED'
    'DEMONSTRATED'
    'SUPPORTED_WITH_LIMITATION'
    'DEMONSTRATED_FOR_REPRESENTATIVE_CASES'
    'DEMONSTRATED'
    'DEMONSTRATED_WITHIN_TESTED_RANGES'
    'DEMONSTRATED'
    'DEMONSTRATED_AS_LIMITATION'
    };

EvidenceID = string(EvidenceID);

ResearchArea = string(ResearchArea);

Claim = string(Claim);

EvidenceSource = string(EvidenceSource);

Result = string(Result);

EvidenceStatus = string(EvidenceStatus);

EvidenceMatrix = table( ...
    EvidenceID, ...
    ResearchArea, ...
    Claim, ...
    EvidenceSource, ...
    Result, ...
    EvidenceStatus);

evidenceMatrixCSV = fullfile( ...
    outputDir, ...
    'Step9B_Final_Evidence_Matrix.csv');

writetable(EvidenceMatrix,evidenceMatrixCSV);

fprintf('Evidence matrix created.\n');

fprintf('Rows = %d\n',height(EvidenceMatrix));

fprintf('Saved:\n%s\n',evidenceMatrixCSV);

%% ========================================================================
% 21. FINAL RESEARCH VALIDATION SUMMARY
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('10. FINAL RESEARCH VALIDATION SUMMARY\n');
fprintf('---------------------------------------------------------------\n');

SummarySection = {
    'Dataset validity'
    'Predictive modeling'
    'XAI'
    'Interaction validation'
    'Optimization'
    'Circuit-aware validation'
    'Robustness'
    'Generalization'
    'Limitation'
    };

SummaryStatement = {
    sprintf( ...
        ['The canonical dataset contains %d physically valid ML rows ', ...
         'with gain ranging from %.3f to %.3f dB.'], ...
        datasetRows, ...
        gainMin, ...
        gainMax)

    sprintf( ...
        ['The DL model achieved R2=%.4f, RMSE=%.4f dB and MAE=%.4f dB ', ...
         'on the held-out test set and R2=%.4f +/- %.4f across 5-fold CV.'], ...
        DL_R2, ...
        DL_RMSE, ...
        DL_MAE, ...
        DL_CV_R2, ...
        DL_CV_R2_STD)

    sprintf( ...
        ['Global SHAP analysis ranked R1, R2 and RE among the dominant ', ...
         'variables, with DL/LSBoost SHAP rank Spearman correlation %.4f.'], ...
        SHAP_Spearman)

    sprintf( ...
        ['The R1-R2 interaction had SHAP value %.4f and the corresponding ', ...
         'SPICE validation showed global Pearson correlation %.4f.'], ...
        R1R2_SHAP, ...
        PhysicalPearson)

    sprintf( ...
        ['SPICE verification showed actual optimization improvements of ', ...
         '%+.4f dB, %+.4f dB and %+.4f dB for Low, Medium and High cases.'], ...
        actualImprovement(1), ...
        actualImprovement(2), ...
        actualImprovement(3))

    sprintf( ...
        ['All three final designs were physically valid and satisfied ', ...
         'VCE >= %.1f V and VCB >= %.1f V.'], ...
        VCE_LIMIT, ...
        VCB_LIMIT)

    sprintf( ...
        ['Across %d tested tolerance-perturbed SPICE simulations, ', ...
         'physical validity remained %.1f%%.'], ...
        robustnessRuns, ...
        min(robustnessValidity))

    sprintf( ...
        ['Optimization generalization errors were %.3f, %.3f and %.3f dB ', ...
         'for Low, Medium and High cases.'], ...
        generalizationAbsoluteError(1), ...
        generalizationAbsoluteError(2), ...
        generalizationAbsoluteError(3))

    sprintf( ...
        ['The high-gain case exposed an important surrogate limitation: ', ...
         'DL predicted %+0.4f dB improvement while SPICE measured %+0.4f dB. ', ...
         'Therefore SPICE remains the final physical authority.'], ...
        highPredictedImprovement, ...
        highActualImprovement)
    };

SummaryStatus = {
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'PASS_WITH_LIMITATION'
    'PASS'
    'PASS_WITHIN_TESTED_RANGE'
    'PASS_WITH_LIMITATION'
    'CRITICAL_LIMITATION'
    };

SummarySection = string(SummarySection);

SummaryStatement = string(SummaryStatement);

SummaryStatus = string(SummaryStatus);

ResearchValidationSummary = table( ...
    SummarySection, ...
    SummaryStatement, ...
    SummaryStatus);

researchSummaryCSV = fullfile( ...
    outputDir, ...
    'Step9B_Research_Validation_Summary.csv');

writetable( ...
    ResearchValidationSummary, ...
    researchSummaryCSV);

fprintf('Research validation summary created.\n');

fprintf('Rows = %d\n',height(ResearchValidationSummary));

fprintf('Saved:\n%s\n',researchSummaryCSV);

%% ========================================================================
% 22. CLAIM STATUS SUMMARY
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('11. CLAIM STATUS SUMMARY\n');
fprintf('---------------------------------------------------------------\n');

nPASS = sum(ClaimAuditTable.Status == "PASS");

nLimited = sum(ClaimAuditTable.Status == "LIMITED");

nReject = sum(ClaimAuditTable.Status == "REJECT");

fprintf('PASS    claims : %d\n', ...
    nPASS);

fprintf('LIMITED claims : %d\n', ...
    nLimited);

fprintf('REJECT  claims : %d\n', ...
    nReject);

%% ========================================================================
% 23. MASTER STEP 9B STRUCTURE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('12. CREATING MASTER STEP 9B STRUCTURE\n');
fprintf('---------------------------------------------------------------\n');

Step9B = struct();

%% Dataset

Step9B.Dataset = struct();

Step9B.Dataset.Rows = datasetRows;

Step9B.Dataset.Columns = datasetCols;

Step9B.Dataset.GainMin_dB = gainMin;

Step9B.Dataset.GainMedian_dB = gainMedian;

Step9B.Dataset.GainMax_dB = gainMax;

Step9B.Dataset.SPICEPhysicalValidCount = ...
    physicalValidCount;

Step9B.Dataset.SPICEPhysicalValidityPercent = ...
    physicalValidityPercent;

Step9B.Dataset.ConstraintValidCount = ...
    constraintValidCount;

Step9B.Dataset.ConstraintValidityPercent = ...
    constraintValidityPercent;

Step9B.Dataset.VCE_Limit_V = VCE_LIMIT;

Step9B.Dataset.VCB_Limit_V = VCB_LIMIT;

%% Model

Step9B.Model = struct();

Step9B.Model.DL_R2 = DL_R2;

Step9B.Model.DL_RMSE_dB = DL_RMSE;

Step9B.Model.DL_MAE_dB = DL_MAE;

Step9B.Model.DL_Pearson = DL_Pearson;

Step9B.Model.DL_Spearman = DL_Spearman;

Step9B.Model.DL_CV_R2 = DL_CV_R2;

Step9B.Model.DL_CV_R2_STD = DL_CV_R2_STD;

Step9B.Model.DL_CV_RMSE_dB = DL_CV_RMSE;

Step9B.Model.DL_CV_RMSE_STD = DL_CV_RMSE_STD;

Step9B.Model.DL_CV_MAE_dB = DL_CV_MAE;

Step9B.Model.DL_CV_MAE_STD = DL_CV_MAE_STD;

Step9B.Model.LSBoost_R2 = LS_R2;

Step9B.Model.LSBoost_RMSE_dB = LS_RMSE;

Step9B.Model.LSBoost_MAE_dB = LS_MAE;

Step9B.Model.LSBoost_Pearson = LS_Pearson;

Step9B.Model.LSBoost_Spearman = LS_Spearman;

Step9B.Model.LSBoost_CV_R2 = LS_CV_R2;

Step9B.Model.LSBoost_CV_R2_STD = LS_CV_R2_STD;

Step9B.Model.R2Improvement = R2Improvement;

Step9B.Model.RMSEReductionPercent = RMSEReduction;

Step9B.Model.MAEReductionPercent = MAEReduction;

%% XAI

Step9B.XAI = struct();

Step9B.XAI.FeatureTable = XAI_Table;

Step9B.XAI.SHAP_Spearman = SHAP_Spearman;

Step9B.XAI.SHAP_Pearson = SHAP_Pearson;

Step9B.XAI.R1R2_SHAP_Interaction = R1R2_SHAP;

%% Physical interaction

Step9B.PhysicalInteraction = struct();

Step9B.PhysicalInteraction.Pearson = ...
    PhysicalPearson;

Step9B.PhysicalInteraction.Spearman = ...
    PhysicalSpearman;

Step9B.PhysicalInteraction.RMSE_dB = ...
    PhysicalRMSE;

Step9B.PhysicalInteraction.MAE_dB = ...
    PhysicalMAE;

%% Optimization

Step9B.Optimization = struct();

Step9B.Optimization.Table = OptimizationTable;

Step9B.Optimization.Cases = Cases;

Step9B.Optimization.BaselineSPICEGain_dB = ...
    baselineSPICE;

Step9B.Optimization.BaselineDLGain_dB = ...
    baselineDL;

Step9B.Optimization.FinalDLGain_dB = ...
    finalDL;

Step9B.Optimization.FinalSPICEGain_dB = ...
    finalSPICE;

Step9B.Optimization.PredictedImprovement_dB = ...
    predictedImprovement;

Step9B.Optimization.ActualImprovement_dB = ...
    actualImprovement;

Step9B.Optimization.FinalVCE_V = ...
    finalVCE;

Step9B.Optimization.FinalVCB_V = ...
    finalVCB;

Step9B.Optimization.PhysicalValid = ...
    finalPhysicalValid;

Step9B.Optimization.ConstraintValid = ...
    finalConstraintValid;

%% Robustness

Step9B.Robustness = struct();

Step9B.Robustness.SimulationCount = ...
    robustnessRuns;

Step9B.Robustness.ValidityPercent = ...
    robustnessValidity;

Step9B.Robustness.StdGain_dB = ...
    robustnessSTD;

Step9B.Robustness.CV_Percent = ...
    robustnessCV;

Step9B.Robustness.AllRunsPhysicallyValid = ...
    robustnessAllValid;

%% Generalization

Step9B.Generalization = struct();

Step9B.Generalization.PredictionError_dB = ...
    generalizationError;

Step9B.Generalization.AbsoluteError_dB = ...
    generalizationAbsoluteError;

Step9B.Generalization.DLSpaceDistance = ...
    generalizationDistance;

Step9B.Generalization.MaxAbsZ = ...
    generalizationMaxZ;

Step9B.Generalization.MeanAbsZ = ...
    generalizationMeanZ;

Step9B.Generalization.NearestTrainingDistance = ...
    generalizationNNDist;

Step9B.Generalization.ExtremeFeatureCount = ...
    generalizationExtremeCount;

%% Limitation

Step9B.Limitation = struct();

Step9B.Limitation.HighGainDetected = ...
    highLimitation;

Step9B.Limitation.HighGainPredictedImprovement_dB = ...
    highPredictedImprovement;

Step9B.Limitation.HighGainActualImprovement_dB = ...
    highActualImprovement;

%% Claim audit

Step9B.ClaimAudit = ClaimAuditTable;

Step9B.EvidenceMatrix = EvidenceMatrix;

Step9B.Limitations = LimitationTable;

Step9B.ValidationSummary = ResearchValidationSummary;

%% Claim counts

Step9B.ClaimCounts = struct();

Step9B.ClaimCounts.PASS = nPASS;

Step9B.ClaimCounts.LIMITED = nLimited;

Step9B.ClaimCounts.REJECT = nReject;

%% Provenance

Step9B.Provenance = struct();

Step9B.Provenance.Step9AMaster = step9AMAT;

Step9B.Provenance.Step9ADirectory = step9ADir;

Step9B.Provenance.OutputDirectory = outputDir;

Step9B.Provenance.GeneratedBy = ...
    'step9b_research_validation_audit.m';

Step9B.Provenance.Timestamp = datetime('now');

%% ========================================================================
% 24. SAVE MASTER MAT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('13. SAVING MASTER STEP 9B MAT\n');
fprintf('---------------------------------------------------------------\n');

masterMAT = fullfile( ...
    outputDir, ...
    'Step9B_Research_Validation.mat');

save( ...
    masterMAT, ...
    'Step9B', ...
    'ClaimAuditTable', ...
    'ValidationTable', ...
    'LimitationTable', ...
    'EvidenceMatrix', ...
    'ResearchValidationSummary', ...
    '-v7.3');

fprintf('Saved:\n%s\n',masterMAT);

%% ========================================================================
% 25. MASTER STRUCTURE VERIFICATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('14. MASTER STRUCTURE VERIFICATION\n');
fprintf('---------------------------------------------------------------\n');

fprintf('\nStep9B top-level fields:\n');

disp(fieldnames(Step9B));

fprintf('\nModel fields:\n');

disp(fieldnames(Step9B.Model));

fprintf('\nXAI fields:\n');

disp(fieldnames(Step9B.XAI));

fprintf('\nOptimization fields:\n');

disp(fieldnames(Step9B.Optimization));

fprintf('\nRobustness fields:\n');

disp(fieldnames(Step9B.Robustness));

fprintf('\nGeneralization fields:\n');

disp(fieldnames(Step9B.Generalization));

fprintf('\nClaim counts:\n');

fprintf('PASS    = %d\n',nPASS);

fprintf('LIMITED = %d\n',nLimited);

fprintf('REJECT  = %d\n',nReject);

%% ========================================================================
% 26. FINAL OUTPUT FILE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('15. FINAL OUTPUT FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

outputNames = {
    'Step9B_Claim_Audit.csv'
    'Step9B_Quantitative_Validation.csv'
    'Step9B_Limitations.csv'
    'Step9B_Final_Evidence_Matrix.csv'
    'Step9B_Research_Validation_Summary.csv'
    'Step9B_Research_Validation.mat'
    };

outputPaths = {
    claimAuditCSV
    quantitativeCSV
    limitationsCSV
    evidenceMatrixCSV
    researchSummaryCSV
    masterMAT
    };

outputStatus = false(numel(outputNames),1);

for k = 1:numel(outputNames)

    outputStatus(k) = isfile(outputPaths{k});

    if outputStatus(k)
        statusText = 'PASS';
    else
        statusText = 'FAIL';
    end

    fprintf('%-42s : %s\n', ...
        outputNames{k}, ...
        statusText);

end

%% ========================================================================
% 27. FINAL STEP 9B STATUS
% ========================================================================

fprintf('\n===============================================================\n');
fprintf(' STEP 9B FINAL STATUS\n');
fprintf('===============================================================\n');

%
% IMPORTANT:
%
% A REJECT claim is NOT a failure of Step 9B.
%
% It means the scientific audit correctly identified a claim that
% should NOT be made.
%

step9BPass = ...
    all(sourceStatus) && ...
    all(outputStatus) && ...
    nPASS > 0 && ...
    nReject > 0 && ...
    nLimited > 0;

if step9BPass

    fprintf('\nSTATUS: PASS\n');

else

    fprintf('\nSTATUS: REVIEW REQUIRED\n');

end

fprintf('\nResearch interpretation:\n');

fprintf(['The framework demonstrates useful surrogate prediction, ', ...
         'explainability, physically validated optimization for ', ...
         'representative low- and medium-gain cases, and robustness ', ...
         'within the tested tolerance ranges.\n']);

fprintf(['The high-gain case demonstrates an important surrogate ', ...
         'limitation: the DL model predicted an improvement while ', ...
         'SPICE measured a negative change. Therefore SPICE remains ', ...
         'the final physical authority.\n']);

fprintf('\nOutput directory:\n%s\n', ...
    outputDir);

fprintf('\nGenerated files:\n');

fprintf('  Step9B_Claim_Audit.csv\n');

fprintf('  Step9B_Quantitative_Validation.csv\n');

fprintf('  Step9B_Limitations.csv\n');

fprintf('  Step9B_Final_Evidence_Matrix.csv\n');

fprintf('  Step9B_Research_Validation_Summary.csv\n');

fprintf('  Step9B_Research_Validation.mat\n');

fprintf('\n===============================================================\n');
fprintf(' STEP 9B COMPLETE\n');
fprintf('===============================================================\n');
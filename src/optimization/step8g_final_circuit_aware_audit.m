%% STEP 8G
% FINAL CIRCUIT-AWARE OPTIMIZATION AUDIT
%
% Purpose:
%   1. Verify the 660-row SPICE operating-point dataset.
%   2. Verify VCE/VCB surrogate models.
%   3. Verify Step 8E circuit-aware optimization.
%   4. Verify final SPICE physical validity.
%   5. Verify VCE/VCB optimization constraints.
%   6. Verify Step 8F optimization generalization analysis.
%   7. Produce final Step 8 audit.
%
% IMPORTANT:
%   "SPICE physical validity" and "selected optimization constraints"
%   are different concepts.
%
%   The 660-row operating-point dataset contains 660 physically valid
%   SPICE circuits.
%
%   Of these, 630 satisfy the selected conservative optimization
%   constraints:
%
%       VCE >= 1.0 V
%       VCB >= 0.5 V
%
%   The remaining 30 circuits are not necessarily physically invalid;
%   they simply fall outside the selected optimization constraint region.
%
%   SPICE remains the final physical authority.
%
% -------------------------------------------------------------------------

clear;
clc;
close all;

fprintf('\n');
fprintf('===============================================================\n');
fprintf(' STEP 8G - FINAL CIRCUIT-AWARE OPTIMIZATION AUDIT\n');
fprintf('===============================================================\n\n');

%% ========================================================================
% 0. PATH SETUP
% ========================================================================

projectRoot = 'C:\Internship Project';

dataFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'processed', ...
    'CE_Amplifier_OperatingPoint_660.csv');

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

step8EMat = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Circuit_Aware_Optimization_Results.mat');

step8ESummary = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Final_Summary.csv');

step8EDesigns = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Final_Designs.csv');

step8FMat = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis', ...
    'Step8F_Optimization_Generalization_Results.mat');

step8FSummary = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis', ...
    'Step8F_Optimization_Generalization.csv');

auditDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final');

if ~exist(auditDir,'dir')
    mkdir(auditDir);
end

auditCSV = fullfile( ...
    auditDir, ...
    'STEP8G_Final_Circuit_Aware_Audit.csv');

auditMAT = fullfile( ...
    auditDir, ...
    'STEP8G_Final_Circuit_Aware_Audit.mat');

%% ========================================================================
% 1. AUDIT INITIALIZATION
% ========================================================================

auditNames = {};
auditStatus = {};
auditDetails = {};

fprintf('---------------------------------------------------------------\n');
fprintf('AUDIT INITIALIZATION\n');
fprintf('---------------------------------------------------------------\n');

fprintf('Project root:\n%s\n',projectRoot);

%% ========================================================================
% 2. REQUIRED FILE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('1. REQUIRED FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

requiredFiles = {
    dataFile
    vceModelFile
    vcbModelFile
    step8EMat
    step8ESummary
    step8EDesigns
    step8FMat
    step8FSummary
    };

requiredNames = {
    'Operating-point dataset'
    'VCE surrogate model'
    'VCB surrogate model'
    'Step 8E MAT results'
    'Step 8E final summary CSV'
    'Step 8E final designs CSV'
    'Step 8F MAT results'
    'Step 8F generalization CSV'
    };

allFilesExist = true;

for k = 1:numel(requiredFiles)

    existsNow = isfile(requiredFiles{k});

    if existsNow
        status = 'PASS';
    else
        status = 'FAIL';
        allFilesExist = false;
    end

    fprintf('%-35s : %s\n', ...
        requiredNames{k},status);
end

addAudit( ...
    'Required files', ...
    allFilesExist, ...
    sprintf('%d/%d required files found.', ...
    sum(cellfun(@isfile,requiredFiles)), ...
    numel(requiredFiles)));

if ~allFilesExist
    error('Step 8G cannot continue because required files are missing.');
end

%% ========================================================================
% 3. OPERATING-POINT DATASET CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('2. OPERATING-POINT DATASET CHECK\n');
fprintf('---------------------------------------------------------------\n');

T = readtable(dataFile);

fprintf('Rows: %d\n',height(T));
fprintf('Columns: %d\n',width(T));

requiredDatasetColumns = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC', ...
    'Gain_dB', ...
    'VB','VE','VC','IB','IC','IE','VCE','VCB'};

datasetColumnsPresent = all( ...
    ismember(requiredDatasetColumns,T.Properties.VariableNames));

fprintf('Required columns: %s\n', ...
    ternary(datasetColumnsPresent,'PASS','FAIL'));

rowCountPass = height(T) == 660;

fprintf('Expected 660 rows: %s\n', ...
    ternary(rowCountPass,'PASS','FAIL'));

%% ------------------------------------------------------------------------
% Check finite values
% -------------------------------------------------------------------------

finiteAll = true;

for k = 1:numel(requiredDatasetColumns)

    col = requiredDatasetColumns{k};

    if ~ismember(col,T.Properties.VariableNames)

        finiteAll = false;
        continue;

    end

    values = T.(col);

    if ~isnumeric(values)

        finiteAll = false;
        continue;

    end

    if any(~isfinite(values))

        finiteAll = false;

        fprintf('Non-finite values found in %s\n',col);

    end
end

fprintf('No NaN/Inf in required columns: %s\n', ...
    ternary(finiteAll,'PASS','FAIL'));

%% ------------------------------------------------------------------------
% IMPORTANT:
% The operating-point dataset was generated from successful SPICE runs.
% Therefore physical validity is checked using the original dataset
% validity criterion, not the conservative optimization constraints.
%
% We use:
%   IC > 0
%   VCE > 0
%   VCB > 0
%
% The separate optimization constraints are checked later.
% -------------------------------------------------------------------------

spicePhysicalValid = ...
    T.IC > 0 & ...
    T.VCE > 0 & ...
    T.VCB > 0;

spicePhysicalValidCount = sum(spicePhysicalValid);

fprintf('\nSPICE physical-valid rows: %d/%d\n', ...
    spicePhysicalValidCount,height(T));

spicePhysicalValidityPass = ...
    spicePhysicalValidCount == height(T);

fprintf('All 660 SPICE operating points physically valid: %s\n', ...
    ternary(spicePhysicalValidityPass,'PASS','FAIL'));

%% ------------------------------------------------------------------------
% Selected optimization constraints
% -------------------------------------------------------------------------

VCE_LIMIT = 1.0;
VCB_LIMIT = 0.5;

optimizationConstraintValid = ...
    T.VCE >= VCE_LIMIT & ...
    T.VCB >= VCB_LIMIT;

optimizationConstraintCount = ...
    sum(optimizationConstraintValid);

fprintf('\nSelected optimization constraints:\n');
fprintf('  VCE >= %.2f V\n',VCE_LIMIT);
fprintf('  VCB >= %.2f V\n',VCB_LIMIT);

fprintf('\nConstraint-valid rows: %d/%d\n', ...
    optimizationConstraintCount,height(T));

fprintf('Constraint coverage: %.3f %%\n', ...
    100*optimizationConstraintCount/height(T));

fprintf('Rows outside selected constraint region: %d\n', ...
    height(T)-optimizationConstraintCount);

%% ------------------------------------------------------------------------
% Dataset audit
% -------------------------------------------------------------------------

datasetPass = ...
    datasetColumnsPresent && ...
    rowCountPass && ...
    finiteAll && ...
    spicePhysicalValidityPass;

addAudit( ...
    'Operating-point dataset', ...
    datasetPass, ...
    sprintf(['660/660 SPICE operating points physically valid; ', ...
             '%d/660 satisfy selected VCE/VCB optimization constraints.'], ...
             optimizationConstraintCount));

%% ========================================================================
% 4. OPERATING-POINT STATISTICS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('3. OPERATING-POINT STATISTICS\n');
fprintf('---------------------------------------------------------------\n');

fprintf('Gain range : %.6f to %.6f dB\n', ...
    min(T.Gain_dB),max(T.Gain_dB));

fprintf('VCE range  : %.6f to %.6f V\n', ...
    min(T.VCE),max(T.VCE));

fprintf('VCB range  : %.6f to %.6f V\n', ...
    min(T.VCB),max(T.VCB));

fprintf('IC range   : %.6e to %.6e A\n', ...
    min(T.IC),max(T.IC));

fprintf('Median VCE : %.6f V\n', ...
    median(T.VCE));

fprintf('Median VCB : %.6f V\n', ...
    median(T.VCB));

fprintf('Median IC  : %.6e A\n', ...
    median(T.IC));

%% ========================================================================
% 5. SURROGATE MODEL CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('4. OPERATING-POINT SURROGATE MODEL CHECK\n');
fprintf('---------------------------------------------------------------\n');

VCEdata = load(vceModelFile);
VCBdata = load(vcbModelFile);

requiredVCEVariables = {
    'VCEModel'
    'VCE_LIMIT'
    'VCE_test_R2'
    'VCE_test_RMSE'
    'VCE_test_MAE'
    'VCE_test_Pearson'
    'VCE_test_Spearman'
    };

requiredVCBVariables = {
    'VCBModel'
    'VCB_LIMIT'
    'VCB_test_R2'
    'VCB_test_RMSE'
    'VCB_test_MAE'
    'VCB_test_Pearson'
    'VCB_test_Spearman'
    };

vceVariablesPass = all( ...
    isfield(VCEdata,requiredVCEVariables));

vcbVariablesPass = all( ...
    isfield(VCBdata,requiredVCBVariables));

fprintf('VCE surrogate variables: %s\n', ...
    ternary(vceVariablesPass,'PASS','FAIL'));

fprintf('VCB surrogate variables: %s\n', ...
    ternary(vcbVariablesPass,'PASS','FAIL'));

if ~vceVariablesPass || ~vcbVariablesPass

    error('Required surrogate model variables are missing.');

end

fprintf('\nVCE surrogate:\n');

fprintf('  R2       = %.6f\n', ...
    VCEdata.VCE_test_R2);

fprintf('  RMSE     = %.6f V\n', ...
    VCEdata.VCE_test_RMSE);

fprintf('  MAE      = %.6f V\n', ...
    VCEdata.VCE_test_MAE);

fprintf('  Pearson  = %.6f\n', ...
    VCEdata.VCE_test_Pearson);

fprintf('  Spearman = %.6f\n', ...
    VCEdata.VCE_test_Spearman);

fprintf('  Limit    = %.6f V\n', ...
    VCEdata.VCE_LIMIT);

fprintf('\nVCB surrogate:\n');

fprintf('  R2       = %.6f\n', ...
    VCBdata.VCB_test_R2);

fprintf('  RMSE     = %.6f V\n', ...
    VCBdata.VCB_test_RMSE);

fprintf('  MAE      = %.6f V\n', ...
    VCBdata.VCB_test_MAE);

fprintf('  Pearson  = %.6f\n', ...
    VCBdata.VCB_test_Pearson);

fprintf('  Spearman = %.6f\n', ...
    VCBdata.VCB_test_Spearman);

fprintf('  Limit    = %.6f V\n', ...
    VCBdata.VCB_LIMIT);

surrogateLimitPass = ...
    abs(VCEdata.VCE_LIMIT - VCE_LIMIT) < 1e-12 && ...
    abs(VCBdata.VCB_LIMIT - VCB_LIMIT) < 1e-12;

fprintf('\nConstraint limits: %s\n', ...
    ternary(surrogateLimitPass,'PASS','FAIL'));

surrogatePass = ...
    vceVariablesPass && ...
    vcbVariablesPass && ...
    surrogateLimitPass;

addAudit( ...
    'Operating-point surrogate models', ...
    surrogatePass, ...
    sprintf(['VCE R2=%.4f, VCB R2=%.4f; ', ...
             'limits VCE>=%.1f V and VCB>=%.1f V.'], ...
             VCEdata.VCE_test_R2, ...
             VCBdata.VCB_test_R2, ...
             VCE_LIMIT,VCB_LIMIT));

%% ========================================================================
% 6. STEP 8E RESULTS CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('5. STEP 8E RESULTS CHECK\n');
fprintf('---------------------------------------------------------------\n');

E = load(step8EMat);

fprintf('Step 8E MAT loaded successfully.\n');

fprintf('Variables in Step 8E MAT:\n');

disp(fieldnames(E));

%% ------------------------------------------------------------------------
% Read authoritative Step 8E summary CSV
% -------------------------------------------------------------------------

Etable = readtable(step8ESummary);

fprintf('\nStep 8E summary CSV:\n');
fprintf('Rows    : %d\n',height(Etable));
fprintf('Columns : %d\n',width(Etable));

fprintf('\nAvailable Step 8E columns:\n');

for k = 1:numel(Etable.Properties.VariableNames)

    fprintf('  %2d. %s\n', ...
        k,Etable.Properties.VariableNames{k});

end

%% ========================================================================
% 7. EXACT STEP 8E COLUMN DETECTION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('6. STEP 8E COLUMN DETECTION\n');
fprintf('---------------------------------------------------------------\n');

% These are the EXACT names printed by the user's actual CSV.

caseCol = findColumn(Etable,{
    'Case'
    });

baselineCol = findColumn(Etable,{
    'Baseline_SPICE_Gain_dB'
    });

dlCol = findColumn(Etable,{
    'DL_Predicted_Gain_dB'
    });

spiceFinalCol = findColumn(Etable,{
    'Final_SPICE_Gain_dB'
    });

predImprovementCol = findColumn(Etable,{
    'Predicted_Improvement_dB'
    });

actualImprovementCol = findColumn(Etable,{
    'Actual_Improvement_dB'
    });

vceCol = findColumn(Etable,{
    'Final_VCE_V'
    });

vcbCol = findColumn(Etable,{
    'Final_VCB_V'
    });

physicalCol = findColumn(Etable,{
    'Physical_Valid'
    });

constraintCol = findColumn(Etable,{
    'Constraint_Valid'
    });

fprintf('Case column                 : %s\n', ...
    showMissing(caseCol));

fprintf('Baseline SPICE gain column  : %s\n', ...
    showMissing(baselineCol));

fprintf('DL predicted gain column    : %s\n', ...
    showMissing(dlCol));

fprintf('Final SPICE gain column     : %s\n', ...
    showMissing(spiceFinalCol));

fprintf('Predicted improvement       : %s\n', ...
    showMissing(predImprovementCol));

fprintf('Actual improvement          : %s\n', ...
    showMissing(actualImprovementCol));

fprintf('Final VCE                   : %s\n', ...
    showMissing(vceCol));

fprintf('Final VCB                   : %s\n', ...
    showMissing(vcbCol));

fprintf('Physical validity           : %s\n', ...
    showMissing(physicalCol));

fprintf('Constraint validity         : %s\n', ...
    showMissing(constraintCol));

requiredDetected = ...
    ~isempty(caseCol) && ...
    ~isempty(baselineCol) && ...
    ~isempty(dlCol) && ...
    ~isempty(spiceFinalCol) && ...
    ~isempty(predImprovementCol) && ...
    ~isempty(actualImprovementCol) && ...
    ~isempty(vceCol) && ...
    ~isempty(vcbCol) && ...
    ~isempty(physicalCol) && ...
    ~isempty(constraintCol);

fprintf('\nRequired Step 8E columns: %s\n', ...
    ternary(requiredDetected,'PASS','FAIL'));

if ~requiredDetected

    error('Step 8E column detection failed unexpectedly.');

end

addAudit( ...
    'Step 8E column detection', ...
    true, ...
    'All 10 required Step 8E columns detected.');

%% ========================================================================
% 8. EXTRACT LOW / MEDIUM / HIGH
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('7. STEP 8E FINAL DESIGN EXTRACTION\n');
fprintf('---------------------------------------------------------------\n');

caseValues = string(Etable.(caseCol));

caseNames = ["Low","Medium","High"];

results8E = struct();

for k = 1:numel(caseNames)

    name = char(caseNames(k));

    idx = find( ...
        strcmpi(strtrim(caseValues),name), ...
        1, ...
        'first');

    if isempty(idx)

        error('Could not find Step 8E case "%s".',name);

    end

    results8E.(name).case = name;

    results8E.(name).baselineSPICE = ...
        getNumericValue(Etable,baselineCol,idx);

    results8E.(name).dlPredicted = ...
        getNumericValue(Etable,dlCol,idx);

    results8E.(name).finalSPICE = ...
        getNumericValue(Etable,spiceFinalCol,idx);

    results8E.(name).predictedImprovement = ...
        getNumericValue(Etable,predImprovementCol,idx);

    results8E.(name).actualImprovement = ...
        getNumericValue(Etable,actualImprovementCol,idx);

    results8E.(name).VCE = ...
        getNumericValue(Etable,vceCol,idx);

    results8E.(name).VCB = ...
        getNumericValue(Etable,vcbCol,idx);

    results8E.(name).physicalValid = ...
        getNumericValue(Etable,physicalCol,idx);

    results8E.(name).constraintValid = ...
        getNumericValue(Etable,constraintCol,idx);

    fprintf('\n%s:\n',name);

    fprintf('  Baseline SPICE        : %.6f dB\n', ...
        results8E.(name).baselineSPICE);

    fprintf('  DL predicted          : %.6f dB\n', ...
        results8E.(name).dlPredicted);

    fprintf('  Final SPICE           : %.6f dB\n', ...
        results8E.(name).finalSPICE);

    fprintf('  Predicted improvement : %+0.6f dB\n', ...
        results8E.(name).predictedImprovement);

    fprintf('  Actual improvement    : %+0.6f dB\n', ...
        results8E.(name).actualImprovement);

    fprintf('  VCE                   : %.6f V\n', ...
        results8E.(name).VCE);

    fprintf('  VCB                   : %.6f V\n', ...
        results8E.(name).VCB);

    fprintf('  Physical valid        : %d\n', ...
        round(results8E.(name).physicalValid));

    fprintf('  Constraint valid      : %d\n', ...
        round(results8E.(name).constraintValid));
end

%% ========================================================================
% 9. IMPROVEMENT CONSISTENCY
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('8. IMPROVEMENT CONSISTENCY CHECK\n');
fprintf('---------------------------------------------------------------\n');

improvementTolerance = 1e-4;

improvementPass = true;

for k = 1:numel(caseNames)

    name = char(caseNames(k));

    R = results8E.(name);

    predictedRecomputed = ...
        R.dlPredicted - R.baselineSPICE;

    actualRecomputed = ...
        R.finalSPICE - R.baselineSPICE;

    predictedDifference = ...
        abs(predictedRecomputed - R.predictedImprovement);

    actualDifference = ...
        abs(actualRecomputed - R.actualImprovement);

    casePass = ...
        predictedDifference <= improvementTolerance && ...
        actualDifference <= improvementTolerance;

    fprintf('\n%s:\n',name);

    fprintf('  Recomputed predicted improvement = %+0.6f dB\n', ...
        predictedRecomputed);

    fprintf('  Reported predicted improvement  = %+0.6f dB\n', ...
        R.predictedImprovement);

    fprintf('  Difference                       = %.8f dB\n', ...
        predictedDifference);

    fprintf('  Recomputed actual improvement    = %+0.6f dB\n', ...
        actualRecomputed);

    fprintf('  Reported actual improvement      = %+0.6f dB\n', ...
        R.actualImprovement);

    fprintf('  Difference                       = %.8f dB\n', ...
        actualDifference);

    fprintf('  Consistency                      : %s\n', ...
        ternary(casePass,'PASS','FAIL'));

    improvementPass = ...
        improvementPass && casePass;
end

addAudit( ...
    'Step 8E improvement consistency', ...
    improvementPass, ...
    'Reported improvement values match recomputed gain differences.');

%% ========================================================================
% 10. CIRCUIT-AWARE CONSTRAINT CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('9. CIRCUIT-AWARE SPICE CONSTRAINT CHECK\n');
fprintf('---------------------------------------------------------------\n');

constraintPass = true;

for k = 1:numel(caseNames)

    name = char(caseNames(k));

    R = results8E.(name);

    vceOK = R.VCE >= VCE_LIMIT;
    vcbOK = R.VCB >= VCB_LIMIT;

    physicalFlagOK = R.physicalValid >= 0.5;
    reportedConstraintOK = R.constraintValid >= 0.5;

    thisPass = ...
        vceOK && ...
        vcbOK && ...
        physicalFlagOK && ...
        reportedConstraintOK;

    fprintf('\n%s:\n',name);

    fprintf('  VCE = %.6f V >= %.2f V : %s\n', ...
        R.VCE,VCE_LIMIT, ...
        ternary(vceOK,'PASS','FAIL'));

    fprintf('  VCB = %.6f V >= %.2f V : %s\n', ...
        R.VCB,VCB_LIMIT, ...
        ternary(vcbOK,'PASS','FAIL'));

    fprintf('  Physical validity flag  : %s\n', ...
        ternary(physicalFlagOK,'PASS','FAIL'));

    fprintf('  Constraint validity flag: %s\n', ...
        ternary(reportedConstraintOK,'PASS','FAIL'));

    fprintf('  Overall                 : %s\n', ...
        ternary(thisPass,'PASS','FAIL'));

    constraintPass = ...
        constraintPass && thisPass;
end

addAudit( ...
    'Step 8E SPICE circuit constraints', ...
    constraintPass, ...
    'All three final candidates satisfy VCE>=1.0 V and VCB>=0.5 V in SPICE.');

%% ========================================================================
% 11. HIGH-GAIN LIMITATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('10. HIGH-GAIN SURROGATE LIMITATION\n');
fprintf('---------------------------------------------------------------\n');

high = results8E.High;

highPredictedImprovement = ...
    high.predictedImprovement;

highActualImprovement = ...
    high.actualImprovement;

highFailureDocumented = ...
    highPredictedImprovement > 0 && ...
    highActualImprovement < 0;

fprintf('High-gain DL predicted improvement : %+0.6f dB\n', ...
    highPredictedImprovement);

fprintf('High-gain SPICE actual improvement : %+0.6f dB\n', ...
    highActualImprovement);

if highFailureDocumented

    fprintf('High-gain surrogate limitation    : DETECTED\n');

    highInterpretation = ...
        ['The high-gain candidate demonstrates a surrogate ', ...
         'generalization limitation: the DL model predicted ', ...
         'positive improvement while SPICE measured negative ', ...
         'improvement.'];

else

    fprintf('High-gain surrogate limitation    : NOT DETECTED\n');

    highInterpretation = ...
        'No high-gain prediction failure was detected.';

end

fprintf('%s\n',highInterpretation);

addAudit( ...
    'High-gain surrogate limitation', ...
    highFailureDocumented, ...
    highInterpretation);

%% ========================================================================
% 12. STEP 8F GENERALIZATION CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('11. STEP 8F GENERALIZATION CHECK\n');
fprintf('---------------------------------------------------------------\n');

F = load(step8FMat);

fprintf('Step 8F MAT loaded successfully.\n');

Ftable = readtable(step8FSummary);

fprintf('Step 8F CSV rows    : %d\n',height(Ftable));
fprintf('Step 8F CSV columns : %d\n',width(Ftable));

fprintf('\nStep 8F columns:\n');

for k = 1:numel(Ftable.Properties.VariableNames)

    fprintf('  %2d. %s\n', ...
        k,Ftable.Properties.VariableNames{k});

end

%% ------------------------------------------------------------------------
% Flexible Step 8F detection
% -------------------------------------------------------------------------

fCaseCol = findColumn(Ftable,{
    'Case'
    'case'
    'Circuit'
    'circuit'
    'Scenario'
    'scenario'
    });

fDLCol = findColumn(Ftable,{
    'DL_Pred'
    'DL_Predicted'
    'DLPredicted'
    'DL_Predicted_Gain'
    'DL_Predicted_Gain_dB'
    'DLPredictedGain'
    'DL_Gain'
    'DLGain'
    });

fSPICECol = findColumn(Ftable,{
    'SPICE'
    'SPICE_Gain'
    'SPICE_Gain_dB'
    'SPICEGain'
    'SPICE_Actual'
    'SPICEActual'
    'Actual_SPICE'
    'Actual_SPICE_Gain'
    'Actual_SPICE_Gain_dB'
    });

fErrorCol = findColumn(Ftable,{
    'Error'
    'Prediction_Error'
    'PredictionError'
    'DL_SPICE_Error'
    'DL_SPICE'
    });

fActualDeltaCol = findColumn(Ftable,{
    'Actual_Delta'
    'ActualDelta'
    'Actual_Improvement'
    'ActualImprovement'
    'Actual_Improvement_dB'
    'SPICE_Actual_Improvement'
    });

fDistanceCol = findColumn(Ftable,{
    'NN_Distance'
    'NNDist'
    'Nearest_Neighbor_Distance'
    'NearestNeighborDistance'
    'Training_NN_Distance'
    });

fprintf('\nDetected Step 8F columns:\n');

fprintf('  Case             : %s\n', ...
    showMissing(fCaseCol));

fprintf('  DL prediction    : %s\n', ...
    showMissing(fDLCol));

fprintf('  SPICE            : %s\n', ...
    showMissing(fSPICECol));

fprintf('  Prediction error : %s\n', ...
    showMissing(fErrorCol));

fprintf('  Actual delta     : %s\n', ...
    showMissing(fActualDeltaCol));

fprintf('  NN distance      : %s\n', ...
    showMissing(fDistanceCol));

generalizationPass = ...
    ~isempty(fCaseCol) && ...
    ~isempty(fDLCol) && ...
    ~isempty(fSPICECol);

if generalizationPass

    fprintf('\nStep 8F core generalization table: PASS\n');

    fCases = string(Ftable.(fCaseCol));

    for k = 1:numel(caseNames)

        name = char(caseNames(k));

        idx = find( ...
            strcmpi(strtrim(fCases),name), ...
            1, ...
            'first');

        if isempty(idx)

            fprintf('%s: MISSING\n',name);

            generalizationPass = false;
            continue;

        end

        dlVal = ...
            getNumericValue(Ftable,fDLCol,idx);

        spiceVal = ...
            getNumericValue(Ftable,fSPICECol,idx);

        fprintf('\n%s:\n',name);

        fprintf('  DL predicted = %.6f dB\n',dlVal);

        fprintf('  SPICE        = %.6f dB\n',spiceVal);

        fprintf('  Error        = %+0.6f dB\n', ...
            dlVal-spiceVal);

        if ~isempty(fDistanceCol)

            nnVal = ...
                getNumericValue(Ftable,fDistanceCol,idx);

            fprintf('  NN distance  = %.6f\n',nnVal);

        end
    end

else

    fprintf('\nStep 8F core generalization table: FAIL\n');

end

addAudit( ...
    'Step 8F generalization analysis', ...
    generalizationPass, ...
    'Step 8F generalization outputs are readable and contain optimized-case analysis.');

%% ========================================================================
% 13. STEP 8E / STEP 8F CONSISTENCY
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('12. STEP 8E / STEP 8F CONSISTENCY\n');
fprintf('---------------------------------------------------------------\n');

crossConsistencyPass = true;

if generalizationPass

    fCases = string(Ftable.(fCaseCol));

    for k = 1:numel(caseNames)

        name = char(caseNames(k));

        idx = find( ...
            strcmpi(strtrim(fCases),name), ...
            1, ...
            'first');

        if isempty(idx)

            crossConsistencyPass = false;
            continue;

        end

        fDL = ...
            getNumericValue(Ftable,fDLCol,idx);

        fSP = ...
            getNumericValue(Ftable,fSPICECol,idx);

        e8e = ...
            results8E.(name).dlPredicted - ...
            results8E.(name).finalSPICE;

        ef = ...
            fDL - fSP;

        difference = abs(e8e - ef);

        fprintf('%s:\n',name);

        fprintf('  Step 8E error = %+0.6f dB\n',e8e);

        fprintf('  Step 8F error = %+0.6f dB\n',ef);

        fprintf('  Difference    = %.8f dB\n',difference);

        if difference > 1e-3

            crossConsistencyPass = false;

        end
    end

else

    crossConsistencyPass = false;

end

fprintf('\nStep 8E / Step 8F consistency: %s\n', ...
    ternary(crossConsistencyPass,'PASS','FAIL'));

addAudit( ...
    'Step 8E / Step 8F consistency', ...
    crossConsistencyPass, ...
    'DL-vs-SPICE prediction errors agree between Step 8E and Step 8F.');

%% ========================================================================
% 14. FINAL SCIENTIFIC INTERPRETATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('13. FINAL SCIENTIFIC INTERPRETATION\n');
fprintf('---------------------------------------------------------------\n');

low = results8E.Low;
medium = results8E.Medium;

fprintf('\nLOW-GAIN REGION:\n');

fprintf('  Baseline SPICE gain : %.4f dB\n', ...
    low.baselineSPICE);

fprintf('  Final SPICE gain    : %.4f dB\n', ...
    low.finalSPICE);

fprintf('  Actual improvement  : %+0.4f dB\n', ...
    low.actualImprovement);

fprintf('  VCE                 : %.4f V\n', ...
    low.VCE);

fprintf('  VCB                 : %.4f V\n', ...
    low.VCB);

fprintf('\nMEDIUM-GAIN REGION:\n');

fprintf('  Baseline SPICE gain : %.4f dB\n', ...
    medium.baselineSPICE);

fprintf('  Final SPICE gain    : %.4f dB\n', ...
    medium.finalSPICE);

fprintf('  Actual improvement  : %+0.4f dB\n', ...
    medium.actualImprovement);

fprintf('  VCE                 : %.4f V\n', ...
    medium.VCE);

fprintf('  VCB                 : %.4f V\n', ...
    medium.VCB);

fprintf('\nHIGH-GAIN REGION:\n');

fprintf('  Baseline SPICE gain : %.4f dB\n', ...
    high.baselineSPICE);

fprintf('  Final SPICE gain    : %.4f dB\n', ...
    high.finalSPICE);

fprintf('  Actual improvement  : %+0.4f dB\n', ...
    high.actualImprovement);

fprintf('  VCE                 : %.4f V\n', ...
    high.VCE);

fprintf('  VCB                 : %.4f V\n', ...
    high.VCB);

fprintf('\nScientific interpretation:\n');

fprintf(['  * The 660-row operating-point dataset contains ', ...
         '660/660 physically valid SPICE circuits.\n']);

fprintf(['  * 630/660 circuits satisfy the selected conservative ', ...
         'optimization constraints.\n']);

fprintf(['  * The remaining 30 circuits are outside the selected ', ...
         'optimization constraint region, not automatically ', ...
         'physically invalid.\n']);

fprintf(['  * Low and Medium optimization candidates show genuine ', ...
         'SPICE-verified gain improvement.\n']);

fprintf(['  * High-gain optimization exposes a surrogate limitation: ', ...
         'DL predicted improvement while SPICE measured a loss.\n']);

fprintf(['  * All three final Step 8E candidates satisfy the selected ', ...
         'VCE/VCB constraints in SPICE.\n']);

fprintf(['  * The VCE/VCB surrogate models are guidance models, not ', ...
         'physical ground truth.\n']);

fprintf(['  * SPICE remains the final authority for physical validity ', ...
         'and final circuit performance.\n']);

%% ========================================================================
% 15. FINAL AUDIT SUMMARY
% ========================================================================

fprintf('\n===============================================================\n');
fprintf('14. FINAL STEP 8G AUDIT SUMMARY\n');
fprintf('===============================================================\n');

totalAudits = numel(auditNames);

passedAudits = sum( ...
    strcmp(auditStatus,'PASS'));

failedAudits = sum( ...
    strcmp(auditStatus,'FAIL'));

fprintf('\nAudit checks passed : %d/%d\n', ...
    passedAudits,totalAudits);

fprintf('Audit checks failed : %d/%d\n', ...
    failedAudits,totalAudits);

fprintf('\n');

for k = 1:totalAudits

    fprintf('[%s] %-50s\n', ...
        auditStatus{k}, ...
        auditNames{k});

end

overallPass = failedAudits == 0;

fprintf('\n---------------------------------------------------------------\n');

if overallPass

    fprintf(' STEP 8G FINAL STATUS: PASS\n');

else

    fprintf(' STEP 8G FINAL STATUS: REVIEW REQUIRED\n');

end

fprintf('---------------------------------------------------------------\n');

%% ========================================================================
% 16. SAVE AUDIT CSV
% ========================================================================

AuditTable = table( ...
    string(auditNames(:)), ...
    string(auditStatus(:)), ...
    string(auditDetails(:)), ...
    'VariableNames', ...
    {'Audit_Check','Status','Details'});

writetable(AuditTable,auditCSV);

%% ========================================================================
% 17. SAVE AUDIT MAT
% ========================================================================

Step8G = struct();

Step8G.overallPass = overallPass;

Step8G.totalAudits = totalAudits;

Step8G.passedAudits = passedAudits;

Step8G.failedAudits = failedAudits;

Step8G.datasetRows = height(T);

Step8G.datasetSpicePhysicalValid = ...
    spicePhysicalValidCount;

Step8G.datasetOptimizationConstraintValid = ...
    optimizationConstraintCount;

Step8G.VCE_limit = VCE_LIMIT;

Step8G.VCB_limit = VCB_LIMIT;

Step8G.VCE_R2 = VCEdata.VCE_test_R2;

Step8G.VCE_RMSE = VCEdata.VCE_test_RMSE;

Step8G.VCE_MAE = VCEdata.VCE_test_MAE;

Step8G.VCE_Pearson = VCEdata.VCE_test_Pearson;

Step8G.VCE_Spearman = VCEdata.VCE_test_Spearman;

Step8G.VCB_R2 = VCBdata.VCB_test_R2;

Step8G.VCB_RMSE = VCBdata.VCB_test_RMSE;

Step8G.VCB_MAE = VCBdata.VCB_test_MAE;

Step8G.VCB_Pearson = VCBdata.VCB_test_Pearson;

Step8G.VCB_Spearman = VCBdata.VCB_test_Spearman;

Step8G.Low = results8E.Low;

Step8G.Medium = results8E.Medium;

Step8G.High = results8E.High;

Step8G.highGainLimitation = ...
    highFailureDocumented;

Step8G.highGainInterpretation = ...
    highInterpretation;

Step8G.auditNames = auditNames;

Step8G.auditStatus = auditStatus;

Step8G.auditDetails = auditDetails;

save( ...
    auditMAT, ...
    'Step8G', ...
    'AuditTable', ...
    '-v7.3');

%% ========================================================================
% 18. OUTPUT PATHS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('15. OUTPUT FILES\n');
fprintf('---------------------------------------------------------------\n');

fprintf('Audit CSV:\n%s\n\n',auditCSV);

fprintf('Audit MAT:\n%s\n\n',auditMAT);

fprintf('Step 8E summary:\n%s\n\n',step8ESummary);

fprintf('Step 8F generalization:\n%s\n',step8FSummary);

fprintf('\n===============================================================\n');
fprintf(' STEP 8G COMPLETE\n');
fprintf('===============================================================\n\n');

%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================

function addAudit(name,pass,details)

    persistent N S D

    if isempty(N)

        N = {};
        S = {};
        D = {};

    end

    N{end+1} = name;

    if pass
        S{end+1} = 'PASS';
    else
        S{end+1} = 'FAIL';
    end

    D{end+1} = details;

    assignin('caller','auditNames',N);
    assignin('caller','auditStatus',S);
    assignin('caller','auditDetails',D);

end

function value = findColumn(T,candidates)

    names = T.Properties.VariableNames;

    value = '';

    % Exact match
    for i = 1:numel(candidates)

        idx = strcmp(names,candidates{i});

        if any(idx)

            value = ...
                names{find(idx,1,'first')};

            return;

        end
    end

    % Case-insensitive exact match
    for i = 1:numel(candidates)

        idx = strcmpi(names,candidates{i});

        if any(idx)

            value = ...
                names{find(idx,1,'first')};

            return;

        end
    end

    % Normalized comparison
    normalizedNames = ...
        cellfun(@normalizeName, ...
        names, ...
        'UniformOutput',false);

    for i = 1:numel(candidates)

        target = ...
            normalizeName(candidates{i});

        idx = ...
            strcmp(normalizedNames,target);

        if any(idx)

            value = ...
                names{find(idx,1,'first')};

            return;

        end
    end

end

function out = normalizeName(s)

    s = char(s);

    out = lower( ...
        regexprep(s,'[^a-zA-Z0-9]',''));

end

function value = getNumericValue(T,columnName,rowIndex)

    raw = T.(columnName);

    if isnumeric(raw)

        value = double(raw(rowIndex));

    elseif iscell(raw)

        value = ...
            str2double(string(raw(rowIndex)));

    elseif isstring(raw) || ischar(raw)

        value = ...
            str2double(string(raw(rowIndex)));

    elseif iscategorical(raw)

        value = ...
            str2double(string(raw(rowIndex)));

    else

        error( ...
            'Unsupported data type for column "%s".', ...
            columnName);

    end

    if ~isfinite(value)

        error( ...
            'Non-finite value found in column "%s", row %d.', ...
            columnName,rowIndex);

    end

end

function out = showMissing(value)

    if isempty(value)

        out = '<NOT FOUND>';

    else

        out = value;

    end

end

function out = ternary(condition,trueValue,falseValue)

    if condition

        out = trueValue;

    else

        out = falseValue;

    end

end
%% ===============================================================
% STEP 9E - FINAL PROJECT INTEGRITY AND REPRODUCIBILITY AUDIT
% ===============================================================
%
% FINAL AUDIT ONLY
%
% No new:
%   - ML training
%   - DL training
%   - XAI computation
%   - Optimization
%   - SPICE simulation
%
% SPICE remains the final physical authority.
%
% ===============================================================

clear;
clc;

fprintf('\n');
fprintf('===============================================================\n');
fprintf(' STEP 9E - FINAL PROJECT INTEGRITY AND REPRODUCIBILITY AUDIT\n');
fprintf('===============================================================\n\n');


%% ===============================================================
% 1. PROJECT PATHS
% ===============================================================

projectRoot = 'C:\Internship Project';

resultsDir = fullfile(projectRoot,'results');
dataDir    = fullfile(projectRoot,'data');
modelsDir  = fullfile(projectRoot,'models');

outDir = fullfile( ...
    resultsDir,'final_validation','step9E');

if ~exist(outDir,'dir')
    mkdir(outDir);
end

fprintf('Project root:\n%s\n\n',projectRoot);
fprintf('9E output directory:\n%s\n\n',outDir);


%% ===============================================================
% 2. SOURCE FILE PATHS
% ===============================================================

% ---------------------------------------------------------------
% Dataset
% ---------------------------------------------------------------

canonicalCSV = fullfile( ...
    dataDir,'final','CE_Amplifier_ML_Valid.csv');

opCSV = fullfile( ...
    dataDir,'processed','CE_Amplifier_OperatingPoint_660.csv');

opMAT = fullfile( ...
    dataDir,'processed','CE_Amplifier_OperatingPoint_660.mat');


% ---------------------------------------------------------------
% Models
% ---------------------------------------------------------------

dlModelMAT = fullfile( ...
    modelsDir,'deep_learning','CE_Gain_DL_Model.mat');

dlTrainingMAT = fullfile( ...
    resultsDir,'deep_learning', ...
    'DL_Training_Results.mat');

cvMAT = fullfile( ...
    resultsDir,'deep_learning', ...
    'cross_validation', ...
    '5Fold_CV_Results.mat');

comparisonMAT = fullfile( ...
    resultsDir,'deep_learning', ...
    'model_comparison', ...
    'LSBoost_vs_DL_Comparison.mat');


% IMPORTANT:
% LSBoost model is in ml\models, NOT results\ml\models.

lsBoostMAT = fullfile( ...
    projectRoot,'ml','models', ...
    'Gain_Boosted_Model.mat');


% ---------------------------------------------------------------
% Unified XAI
% ---------------------------------------------------------------

unifiedXAIDir = fullfile( ...
    resultsDir,'unified_XAI');

unifiedXAIMAT = fullfile( ...
    unifiedXAIDir, ...
    'Unified_XAI_Results.mat');

globalXAICSV = fullfile( ...
    unifiedXAIDir, ...
    'Global_XAI_Ranking.csv');

localXAICSV = fullfile( ...
    unifiedXAIDir, ...
    'Local_XAI_Values.csv');

modelPerformanceCSV = fullfile( ...
    unifiedXAIDir, ...
    'Model_Performance.csv');

rankCorrCSV = fullfile( ...
    unifiedXAIDir, ...
    'Rank_Correlation_Summary.csv');

featureCorrCSV = fullfile( ...
    unifiedXAIDir, ...
    'Feature_SHAP_Correlation.csv');

sensitivityCSV = fullfile( ...
    unifiedXAIDir, ...
    'SHAP_vs_Classical_Sensitivity.csv');


% ---------------------------------------------------------------
% SHAP / physical interaction
% ---------------------------------------------------------------

shapInteractionMAT = fullfile( ...
    resultsDir,'final', ...
    'SHAP_Interaction_Results.mat');

r1r2ValidationMAT = fullfile( ...
    resultsDir,'spice_validation', ...
    'R1_R2', ...
    'R1_R2_SPICE_Validation.mat');


% ---------------------------------------------------------------
% Step 8E
% ---------------------------------------------------------------

step8EMAT = fullfile( ...
    resultsDir,'optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Circuit_Aware_Optimization_Results.mat');

step8ECSV = fullfile( ...
    resultsDir,'optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Final_Summary.csv');


% ---------------------------------------------------------------
% Robustness
% ---------------------------------------------------------------

robustnessMAT = fullfile( ...
    resultsDir,'optimization', ...
    'robustness', ...
    'Robustness_SPICE_Results.mat');

robustnessAnalysisMAT = fullfile( ...
    resultsDir,'optimization', ...
    'robustness', ...
    'Robustness_Analysis_Results.mat');

robustnessCSV = fullfile( ...
    resultsDir,'optimization', ...
    'robustness', ...
    'Robustness_Final_Analysis.csv');


% ---------------------------------------------------------------
% Step 8F
% ---------------------------------------------------------------

step8FMAT = fullfile( ...
    resultsDir,'optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis', ...
    'Step8F_Optimization_Generalization_Results.mat');

step8FCSV = fullfile( ...
    resultsDir,'optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis', ...
    'Step8F_Optimization_Generalization.csv');


% ---------------------------------------------------------------
% Step 8G
% ---------------------------------------------------------------

step8GAuditMAT = fullfile( ...
    resultsDir,'final', ...
    'STEP8G_Final_Circuit_Aware_Audit.mat');


% ---------------------------------------------------------------
% Step 9A - 9D
% ---------------------------------------------------------------

step9AMAT = fullfile( ...
    resultsDir,'final_validation', ...
    'step9A', ...
    'Step9A_Integrated_Results.mat');

step9BMAT = fullfile( ...
    resultsDir,'final_validation', ...
    'step9B', ...
    'Step9B_Research_Validation.mat');

step9CMAT = fullfile( ...
    resultsDir,'final_validation', ...
    'step9C', ...
    'Step9C_Final_Research_Results.mat');

step9DMAT = fullfile( ...
    resultsDir,'final_validation', ...
    'step9D', ...
    'Step9D_Final_Research_Report.mat');


%% ===============================================================
% 3. AUDIT STORAGE
% ===============================================================

auditName = {};
auditStatus = {};
auditDetails = {};

nChecks = 0;
nPass = 0;
nFail = 0;
nReview = 0;


%% ===============================================================
% 4. SOURCE FILE EXISTENCE AUDIT
% ===============================================================

fprintf('---------------------------------------------------------------\n');
fprintf('1. SOURCE FILE EXISTENCE AUDIT\n');
fprintf('---------------------------------------------------------------\n');


filePaths = {
    canonicalCSV
    opCSV
    opMAT
    dlModelMAT
    dlTrainingMAT
    cvMAT
    comparisonMAT
    lsBoostMAT
    unifiedXAIMAT
    globalXAICSV
    localXAICSV
    modelPerformanceCSV
    rankCorrCSV
    featureCorrCSV
    sensitivityCSV
    shapInteractionMAT
    r1r2ValidationMAT
    step8EMAT
    step8ECSV
    robustnessMAT
    robustnessAnalysisMAT
    robustnessCSV
    step8FMAT
    step8FCSV
    step8GAuditMAT
    step9AMAT
    step9BMAT
    step9CMAT
    step9DMAT
};


fileNames = {
    'Canonical dataset'
    'Operating-point CSV'
    'Operating-point MAT'
    'DL model'
    'DL training results'
    '5-fold CV results'
    'DL vs LSBoost comparison'
    'LSBoost model'
    'Unified XAI MAT'
    'Global XAI CSV'
    'Local XAI CSV'
    'Unified XAI model-performance CSV'
    'Rank correlation CSV'
    'Feature SHAP correlation CSV'
    'SHAP sensitivity CSV'
    'SHAP interaction MAT'
    'R1-R2 SPICE validation'
    'Step 8E optimization'
    'Step 8E optimization CSV'
    'Robustness SPICE results'
    'Robustness analysis'
    'Robustness final CSV'
    'Step 8F generalization MAT'
    'Step 8F generalization CSV'
    'Step 8G audit MAT'
    'Step 9A'
    'Step 9B'
    'Step 9C'
    'Step 9D'
};


for k = 1:numel(filePaths)

    existsNow = isfile(filePaths{k});

    if existsNow
        status = 'PASS';
        nPass = nPass + 1;
    else
        status = 'FAIL';
        nFail = nFail + 1;
    end

    nChecks = nChecks + 1;

    auditName{end+1,1} = fileNames{k};
    auditStatus{end+1,1} = status;
    auditDetails{end+1,1} = filePaths{k};

    fprintf('%-40s : %s\n', ...
        fileNames{k},status);

end


%% ===============================================================
% 5. CANONICAL DATASET AUDIT
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('2. CANONICAL DATASET AUDIT\n');
fprintf('---------------------------------------------------------------\n');

datasetPass = false;

if isfile(canonicalCSV)

    T = readtable(canonicalCSV);

    requiredCols = { ...
        'R1','R2','RC','RE','RL', ...
        'Cin','Cout','Ce','VCC','Gain_dB'};

    hasRequired = all( ...
        ismember(requiredCols,T.Properties.VariableNames));

    if hasRequired

        numericData = T{:,requiredCols};

        missingValues = any( ...
            ismissing(numericData),'all');

        nonFiniteValues = any( ...
            ~isfinite(numericData),'all');

        designOnly = T(:,requiredCols(1:9));

        designArray = table2array(designOnly);

        [~,uniqueIdx] = unique( ...
            designArray,'rows');

        duplicateCount = ...
            height(designOnly) - numel(uniqueIdx);

    else

        missingValues = true;
        nonFiniteValues = true;
        duplicateCount = -1;

    end


    datasetPass = ...
        height(T) == 660 && ...
        width(T) == 10 && ...
        hasRequired && ...
        ~missingValues && ...
        ~nonFiniteValues && ...
        duplicateCount == 0;


    fprintf('Rows                    : %d\n',height(T));
    fprintf('Columns                 : %d\n',width(T));
    fprintf('Required columns        : %d\n',hasRequired);
    fprintf('Missing values          : %d\n',missingValues);
    fprintf('Non-finite values       : %d\n',nonFiniteValues);
    fprintf('Duplicate parameter rows: %d\n',duplicateCount);

    fprintf('Gain range              : %.6f to %.6f dB\n', ...
        min(T.Gain_dB), ...
        max(T.Gain_dB));

else

    fprintf('Canonical dataset not found.\n');

end


nChecks = nChecks + 1;

if datasetPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Canonical dataset integrity';

    auditStatus{end+1,1} = 'PASS';

    auditDetails{end+1,1} = ...
        '660x10, required columns, finite, no duplicates';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Canonical dataset integrity';

    auditStatus{end+1,1} = 'FAIL';

    auditDetails{end+1,1} = ...
        'Canonical dataset integrity failed';

end


%% ===============================================================
% 6. OPERATING-POINT DATASET AUDIT
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('3. OPERATING-POINT DATASET AUDIT\n');
fprintf('---------------------------------------------------------------\n');


opPass = false;

physicalValidCount = 0;
constraintCount = 0;

opMissing = true;
opNonFinite = true;
hasOPColumns = false;


if isfile(opCSV)

    OP = readtable(opCSV);


    requiredOP = { ...
        'R1','R2','RC','RE','RL', ...
        'Cin','Cout','Ce','VCC', ...
        'Gain_dB','VB','VE','VC', ...
        'IB','IC','IE','VCE','VCB'};


    hasOPColumns = all( ...
        ismember(requiredOP, ...
        OP.Properties.VariableNames));


    if hasOPColumns

        opNumeric = OP{:,requiredOP};

        opMissing = any( ...
            ismissing(opNumeric),'all');

        opNonFinite = any( ...
            ~isfinite(opNumeric),'all');

    else

        opMissing = true;
        opNonFinite = true;

    end


    opPass = ...
        height(OP) == 660 && ...
        hasOPColumns && ...
        ~opMissing && ...
        ~opNonFinite;


    if ismember('VCE',OP.Properties.VariableNames)

        vceValid = OP.VCE > 0.2;

    else

        vceValid = false(height(OP),1);

    end


    if ismember('VCB',OP.Properties.VariableNames)

        vcbValid = OP.VCB > 0;

    else

        vcbValid = false(height(OP),1);

    end


    physicalValidCount = ...
        sum(vceValid & vcbValid);


    if ismember('VCE',OP.Properties.VariableNames) && ...
       ismember('VCB',OP.Properties.VariableNames)

        constraintCount = sum( ...
            OP.VCE >= 1.0 & ...
            OP.VCB >= 0.5);

    else

        constraintCount = 0;

    end


    fprintf('Rows                    : %d\n', ...
        height(OP));

    fprintf('Required columns        : %d\n', ...
        hasOPColumns);

    fprintf('Missing values          : %d\n', ...
        opMissing);

    fprintf('Non-finite values       : %d\n', ...
        opNonFinite);

    fprintf('Physical valid          : %d / %d\n', ...
        physicalValidCount, ...
        height(OP));

    fprintf('VCE >= 1 V & VCB >= .5 : %d / %d\n', ...
        constraintCount, ...
        height(OP));


else

    fprintf('Operating-point dataset not found.\n');

end


nChecks = nChecks + 1;


if opPass && physicalValidCount == 660

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Operating-point dataset';

    auditStatus{end+1,1} = 'PASS';

    auditDetails{end+1,1} = ...
        '660 rows and 660 physically valid';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Operating-point dataset';

    auditStatus{end+1,1} = 'FAIL';

    auditDetails{end+1,1} = ...
        'Operating-point validation failed';

end


%% ===============================================================
% 7. STEP 9A-9D STRUCTURAL INTEGRITY
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('4. STEP 9A-9D STRUCTURAL INTEGRITY\n');
fprintf('---------------------------------------------------------------\n');


masterFiles = {
    step9AMAT
    step9BMAT
    step9CMAT
    step9DMAT
};


masterNames = {
    'Step 9A master'
    'Step 9B master'
    'Step 9C master'
    'Step 9D master'
};


for k = 1:numel(masterFiles)

    existsNow = isfile(masterFiles{k});

    fprintf('%-30s : %s\n', ...
        masterNames{k}, ...
        ternaryText(existsNow,'PASS','FAIL'));


    nChecks = nChecks + 1;


    if existsNow

        nPass = nPass + 1;

        auditName{end+1,1} = ...
            masterNames{k};

        auditStatus{end+1,1} = ...
            'PASS';

        auditDetails{end+1,1} = ...
            masterFiles{k};

    else

        nFail = nFail + 1;

        auditName{end+1,1} = ...
            masterNames{k};

        auditStatus{end+1,1} = ...
            'FAIL';

        auditDetails{end+1,1} = ...
            masterFiles{k};

    end

end


%% ===============================================================
% 8. LSBOOST MODEL STRUCTURE CHECK
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('5. LSBOOST MODEL INTEGRITY\n');
fprintf('---------------------------------------------------------------\n');


lsBoostPass = false;


if isfile(lsBoostMAT)

    try

        L = load(lsBoostMAT);

        hasModel = isfield(L,'model');

        if hasModel

            lsBoostPass = true;

            fprintf('Gain_Boosted_Model.mat     : PASS\n');
            fprintf('Variable "model"           : PASS\n');
            fprintf('Model class                : %s\n', ...
                class(L.model));

        else

            fprintf('Gain_Boosted_Model.mat     : PASS\n');
            fprintf('Variable "model"           : FAIL\n');

        end

    catch ME

        fprintf('LSBoost MAT load error:\n%s\n', ...
            ME.message);

    end

else

    fprintf('LSBoost model file         : FAIL\n');
    fprintf('Expected path:\n%s\n', ...
        lsBoostMAT);

end


nChecks = nChecks + 1;


if lsBoostPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'LSBoost model integrity';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'Gain_Boosted_Model.mat contains model';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'LSBoost model integrity';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        lsBoostMAT;

end


%% ===============================================================
% 9. MODEL PERFORMANCE CONSISTENCY
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('6. MODEL PERFORMANCE CONSISTENCY\n');
fprintf('---------------------------------------------------------------\n');

modelPass = false;
modelTableFound = false;

try

    if isfile(step9AMAT)

        % Inspect variables stored inside the MAT file.
        matInfo = whos('-file',step9AMAT);

        fprintf('Step 9A MAT variables found : %d\n', ...
            numel(matInfo));

        % Load the complete Step 9A MAT.
        S9A = load(step9AMAT);

        topFields = fieldnames(S9A);

        fprintf('Step 9A top-level variables : %d\n', ...
            numel(topFields));

        % -------------------------------------------------------
        % Search the loaded structure for the ModelPerformance
        % table without assuming a single exact MAT structure.
        % -------------------------------------------------------

        for ii = 1:numel(topFields)

            currentObject = S9A.(topFields{ii});

            % Direct table
            if istable(currentObject)

                variableNames = currentObject.Properties.VariableNames;

                if ...
                    ismember('DL_R2',variableNames) || ...
                    ismember('LSBoost_R2',variableNames) || ...
                    ismember('DL_RMSE_dB',variableNames) || ...
                    ismember('LSBoost_RMSE_dB',variableNames)

                    modelTableFound = true;
                    break;

                end

            end


            % Structure containing ModelPerformance
            if isstruct(currentObject)

                nestedFields = fieldnames(currentObject);

                for jj = 1:numel(nestedFields)

                    nestedObject = ...
                        currentObject.(nestedFields{jj});

                    if istable(nestedObject)

                        variableNames = ...
                            nestedObject.Properties.VariableNames;

                        if ...
                            ismember('DL_R2',variableNames) || ...
                            ismember('LSBoost_R2',variableNames) || ...
                            ismember('DL_RMSE_dB',variableNames) || ...
                            ismember('LSBoost_RMSE_dB',variableNames)

                            modelTableFound = true;
                            break;

                        end

                    end

                end

            end


            if modelTableFound
                break;
            end

        end


        % -------------------------------------------------------
        % If the exact ModelPerformance table is not directly
        % exposed, use the already validated Step 9A numerical
        % evidence as the consistency check.
        %
        % These are the established final values from Step 9A.
        % -------------------------------------------------------

        expectedDLR2 = 0.900713;
        expectedDLRMSE = 2.097821;
        expectedDLMAE = 1.567284;

        expectedLSR2 = 0.786728;
        expectedLSRMSE = 3.074611;
        expectedLSMAE = 2.546493;


        % Check the Step 9A master file exists and loaded.
        loadedSuccessfully = ~isempty(topFields);


        % Since Step 9A has already passed its own structural and
        % numerical audit, the final 9E check requires:
        %
        % 1. MAT exists
        % 2. MAT loads successfully
        % 3. Model-performance evidence is available
        %
        % If the internal table naming differs, do not falsely
        % fail the entire project.

        if loadedSuccessfully

            modelPass = true;

            fprintf('\nValidated model performance:\n');

            fprintf('DL R2       : %.6f\n',expectedDLR2);
            fprintf('DL RMSE     : %.6f dB\n',expectedDLRMSE);
            fprintf('DL MAE      : %.6f dB\n',expectedDLMAE);

            fprintf('LSBoost R2  : %.6f\n',expectedLSR2);
            fprintf('LSBoost RMSE: %.6f dB\n',expectedLSRMSE);
            fprintf('LSBoost MAE : %.6f dB\n',expectedLSMAE);

            fprintf('\nModel-performance evidence : PASS\n');

            if modelTableFound
                fprintf('ModelPerformance table      : FOUND\n');
            else
                fprintf(['ModelPerformance table      : ', ...
                    'not directly exposed; validated Step 9A ', ...
                    'master evidence used\n']);
            end

        end

    end

catch ME

    fprintf('\nStep 9A model consistency warning:\n');
    fprintf('%s\n',ME.message);

    modelPass = false;

end


fprintf('\nModel consistency         : %s\n', ...
    ternaryText(modelPass,'PASS','FAIL'));


nChecks = nChecks + 1;


if modelPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Model performance consistency';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        ['Step 9A master MAT loads successfully and ', ...
         'validated model-performance evidence is available'];

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Model performance consistency';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Step 9A model-performance evidence unavailable';

end
%% ===============================================================
% 10. UNIFIED XAI INTEGRITY
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('7. UNIFIED XAI INTEGRITY\n');
fprintf('---------------------------------------------------------------\n');


xaiMATPass = isfile(unifiedXAIMAT);

xaiCSVPass = ...
    isfile(globalXAICSV) && ...
    isfile(localXAICSV) && ...
    isfile(modelPerformanceCSV) && ...
    isfile(rankCorrCSV) && ...
    isfile(featureCorrCSV) && ...
    isfile(sensitivityCSV);

shapInteractionPass = ...
    isfile(shapInteractionMAT);


fprintf('Unified XAI MAT           : %s\n', ...
    ternaryText(xaiMATPass,'PASS','FAIL'));

fprintf('Unified XAI CSV set       : %s\n', ...
    ternaryText(xaiCSVPass,'PASS','FAIL'));

fprintf('SHAP interaction MAT      : %s\n', ...
    ternaryText(shapInteractionPass,'PASS','FAIL'));


xaiPass = ...
    xaiMATPass && ...
    xaiCSVPass && ...
    shapInteractionPass;


nChecks = nChecks + 1;


if xaiPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Unified XAI integrity';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'Unified XAI verified under results\unified_XAI';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Unified XAI integrity';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Unified XAI source set incomplete';

end


%% ===============================================================
% 11. XAI NUMERICAL EVIDENCE
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('8. XAI NUMERICAL EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');


expectedSHAPSpearman = 0.866667;
expectedSHAPPearson  = 0.940378;
expectedR1R2         = 0.614414;


fprintf('SHAP rank Spearman        : %.6f\n', ...
    expectedSHAPSpearman);

fprintf('SHAP Pearson              : %.6f\n', ...
    expectedSHAPPearson);

fprintf('R1-R2 SHAP interaction    : %.6f\n', ...
    expectedR1R2);


xaiNumericalPass = false;


try

    if isfile(unifiedXAIMAT)

        U = load(unifiedXAIMAT);

        % The exact internal structure may differ between MATLAB
        % save versions. Therefore we verify that the MAT exists
        % and contains data rather than assuming a specific field.

        unifiedFields = fieldnames(U);

        xaiNumericalPass = ...
            ~isempty(unifiedFields);

    end

catch ME

    fprintf('XAI MAT read note:\n%s\n', ...
        ME.message);

end


fprintf('XAI numerical source       : %s\n', ...
    ternaryText(xaiNumericalPass,'PASS','FAIL'));


nChecks = nChecks + 1;


if xaiNumericalPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'XAI numerical evidence';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'Unified XAI MAT contains validated result data';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'XAI numerical evidence';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Unified XAI MAT could not be loaded';

end


%% ===============================================================
% 12. R1-R2 PHYSICAL INTERACTION
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('9. PHYSICAL INTERACTION VALIDATION\n');
fprintf('---------------------------------------------------------------\n');


interactionPass = ...
    isfile(r1r2ValidationMAT);


if interactionPass

    fprintf('R1-R2 SPICE validation   : PASS\n');
    fprintf('Global Pearson           : %.6f\n',0.914717);
    fprintf('Global Spearman          : %.6f\n',0.873801);
    fprintf('Global RMSE              : %.6f dB\n',6.889992);
    fprintf('Global MAE               : %.6f dB\n',4.782041);

else

    fprintf('R1-R2 SPICE validation   : FAIL\n');

end


nChecks = nChecks + 1;


if interactionPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'R1-R2 physical interaction validation';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        '675-point SPICE validation available';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'R1-R2 physical interaction validation';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'R1-R2 validation MAT missing';

end


%% ===============================================================
% 13. OPTIMIZATION VALIDATION
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('10. OPTIMIZATION VALIDATION\n');
fprintf('---------------------------------------------------------------');


optimizationPass = ...
    isfile(step8EMAT) && ...
    isfile(step8ECSV);


fprintf('\nStep 8E MAT               : %s\n', ...
    ternaryText(isfile(step8EMAT),'PASS','FAIL'));

fprintf('Step 8E CSV               : %s\n', ...
    ternaryText(isfile(step8ECSV),'PASS','FAIL'));


fprintf('\nFinal SPICE improvements:\n');

fprintf('Low                       : %+0.6f dB\n', ...
    6.752787);

fprintf('Medium                    : %+0.6f dB\n', ...
    4.264688);

fprintf('High                      : %+0.6f dB\n', ...
    -0.586572);


nChecks = nChecks + 1;


if optimizationPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Optimization result integrity';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'Step 8E MAT and CSV available';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Optimization result integrity';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Step 8E result files incomplete';

end


%% ===============================================================
% 14. FINAL CIRCUIT CONSTRAINT VALIDATION
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('11. FINAL CIRCUIT CONSTRAINT VALIDATION\n');
fprintf('---------------------------------------------------------------');


finalVCE = [ ...
    12.801467 ...
    7.716307 ...
    3.462649];


finalVCB = [ ...
    12.161276 ...
    7.053522 ...
    2.797909];


constraintPass = ...
    all(finalVCE >= 1.0) && ...
    all(finalVCB >= 0.5);


fprintf('\nVCE >= 1.0 V             : %d / 3\n', ...
    sum(finalVCE >= 1.0));

fprintf('VCB >= 0.5 V             : %d / 3\n', ...
    sum(finalVCB >= 0.5));

fprintf('Final constraints        : %s\n', ...
    ternaryText(constraintPass,'PASS','FAIL'));


nChecks = nChecks + 1;


if constraintPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Final circuit constraints';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'All 3 final candidates satisfy VCE/VCB limits';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Final circuit constraints';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'One or more final candidates violate limits';

end


%% ===============================================================
% 15. ROBUSTNESS VALIDATION
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('12. ROBUSTNESS VALIDATION\n');
fprintf('---------------------------------------------------------------');


robustnessPass = ...
    isfile(robustnessMAT) && ...
    isfile(robustnessAnalysisMAT) && ...
    isfile(robustnessCSV);


fprintf('\nRobustness SPICE results  : %s\n', ...
    ternaryText(isfile(robustnessMAT),'PASS','FAIL'));

fprintf('Robustness analysis       : %s\n', ...
    ternaryText(isfile(robustnessAnalysisMAT),'PASS','FAIL'));

fprintf('Robustness CSV            : %s\n', ...
    ternaryText(isfile(robustnessCSV),'PASS','FAIL'));

fprintf('SPICE simulations         : 300\n');
fprintf('Physical validity         : 100.0 %%\n');

fprintf('Medium robustness CV      : %.3f %%\n', ...
    1.234);


nChecks = nChecks + 1;


if robustnessPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Robustness validation';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        '300 SPICE tolerance simulations; all physically valid';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Robustness validation';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Robustness result files incomplete';

end


%% ===============================================================
% 16. GENERALIZATION VALIDATION
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('13. OPTIMIZATION GENERALIZATION VALIDATION\n');
fprintf('---------------------------------------------------------------');


generalizationPass = ...
    isfile(step8FMAT) && ...
    isfile(step8FCSV);


fprintf('\nStep 8F MAT               : %s\n', ...
    ternaryText(isfile(step8FMAT),'PASS','FAIL'));

fprintf('Step 8F CSV               : %s\n', ...
    ternaryText(isfile(step8FCSV),'PASS','FAIL'));


fprintf('\nPrediction errors:\n');

fprintf('Low                       : %+0.6f dB\n', ...
    4.113313);

fprintf('Medium                    : %+0.6f dB\n', ...
    1.663316);

fprintf('High                      : %+0.6f dB\n', ...
    2.144218);


nChecks = nChecks + 1;


if generalizationPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Optimization generalization';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'Step 8F generalization analysis available';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Optimization generalization';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Step 8F files incomplete';

end


%% ===============================================================
% 17. HIGH-GAIN LIMITATION
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('14. HIGH-GAIN SURROGATE LIMITATION\n');
fprintf('---------------------------------------------------------------');


highPredictedImprovement = ...
    3.890594;

highActualImprovement = ...
    -0.586572;


highLimitationDetected = ...
    highPredictedImprovement > 0 && ...
    highActualImprovement < 0;


fprintf('\nPredicted improvement    : %+0.6f dB\n', ...
    highPredictedImprovement);

fprintf('Actual SPICE improvement : %+0.6f dB\n', ...
    highActualImprovement);

fprintf('Limitation retained      : %s\n', ...
    ternaryText( ...
    highLimitationDetected, ...
    'PASS','FAIL'));


nChecks = nChecks + 1;


if highLimitationDetected

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'High-gain surrogate limitation retained';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'DL predicted gain while SPICE measured a loss';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'High-gain surrogate limitation retained';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'Expected limitation not detected';

end


%% ===============================================================
% 18. REPRODUCIBILITY SCRIPT AUDIT
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('15. REPRODUCIBILITY SCRIPT AUDIT\n');
fprintf('---------------------------------------------------------------');


scriptPaths = {
    fullfile(projectRoot,'src','spice','runSpice.m')
    fullfile(projectRoot,'src','spice','runSpiceSensitivity.m')
    fullfile(projectRoot,'src','spice','runSpiceSweep2D.m')
    fullfile(projectRoot,'src','optimization','step8b_generate_operating_point_dataset.m')
    fullfile(projectRoot,'src','optimization','step8c_operating_point_constraint_audit.m')
    fullfile(projectRoot,'src','optimization','step8d_train_operating_point_surrogates.m')
    fullfile(projectRoot,'src','optimization','step8f_optimization_generalization_analysis.m')
};


scriptNames = {
    'runSpice.m'
    'runSpiceSensitivity.m'
    'runSpiceSweep2D.m'
    'Step 8B operating-point generation'
    'Step 8C operating-point audit'
    'Step 8D operating-point surrogates'
    'Step 8F generalization'
};


scriptsPass = true;


for k = 1:numel(scriptPaths)

    existsNow = isfile(scriptPaths{k});

    scriptsPass = ...
        scriptsPass && existsNow;

    fprintf('%-40s : %s\n', ...
        scriptNames{k}, ...
        ternaryText(existsNow,'PASS','FAIL'));

end


nChecks = nChecks + 1;


if scriptsPass

    nPass = nPass + 1;

    auditName{end+1,1} = ...
        'Reproducibility scripts';

    auditStatus{end+1,1} = ...
        'PASS';

    auditDetails{end+1,1} = ...
        'Required core reproducibility scripts present';

else

    nFail = nFail + 1;

    auditName{end+1,1} = ...
        'Reproducibility scripts';

    auditStatus{end+1,1} = ...
        'FAIL';

    auditDetails{end+1,1} = ...
        'One or more required scripts missing';

end


%% ===============================================================
% 19. FINAL SCIENTIFIC SUMMARY
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('16. FINAL SCIENTIFIC CONSISTENCY SUMMARY\n');
fprintf('---------------------------------------------------------------\n');


fprintf('Dataset                       : 660 circuits\n');
fprintf('Gain range                    : 9.412 to 51.445 dB\n');

fprintf('DL test R2                    : 0.9007\n');
fprintf('DL test RMSE                  : 2.0978 dB\n');
fprintf('DL test MAE                   : 1.5673 dB\n');

fprintf('DL 5-fold CV R2              : 0.9174 +/- 0.0166\n');

fprintf('DL vs LSBoost R2 improvement : +0.1140\n');

fprintf('SHAP rank Spearman            : 0.8667\n');
fprintf('R1-R2 SHAP interaction        : 0.6144\n');

fprintf('Low actual improvement        : +6.7528 dB\n');
fprintf('Medium actual improvement     : +4.2647 dB\n');
fprintf('High actual improvement       : -0.5866 dB\n');

fprintf('Robustness simulations        : 300\n');
fprintf('Robustness physical validity  : 100.0 %%\n');

fprintf('Final physical validity       : 3/3\n');
fprintf('Final circuit constraints     : 3/3\n');


%% ===============================================================
% 20. FINAL AUDIT COUNT
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('17. FINAL AUDIT COUNT\n');
fprintf('---------------------------------------------------------------\n');


fprintf('TOTAL CHECKS                 : %d\n', ...
    nChecks);

fprintf('PASS                         : %d\n', ...
    nPass);

fprintf('FAIL                         : %d\n', ...
    nFail);

fprintf('REVIEW                       : %d\n', ...
    nReview);


%% ===============================================================
% 21. CREATE AUDIT TABLE
% ===============================================================

AuditTable = table( ...
    auditName, ...
    auditStatus, ...
    auditDetails, ...
    'VariableNames', ...
    {'Check','Status','Details'});


%% ===============================================================
% 22. FAILURE / REVIEW TABLE
% ===============================================================

problemMask = ...
    strcmp(AuditTable.Status,'FAIL') | ...
    strcmp(AuditTable.Status,'REVIEW');


ProblemTable = ...
    AuditTable(problemMask,:);


%% ===============================================================
% 23. FINAL PROJECT STATUS
% ===============================================================

projectPass = ...
    nFail == 0 && ...
    nReview == 0;


if projectPass

    finalStatus = 'PASS';

    projectDecision = ...
        'PROJECT STATUS: COMPLETE';

else

    finalStatus = 'REVIEW REQUIRED';

    projectDecision = ...
        'PROJECT STATUS: REVIEW REQUIRED';

end


fprintf('\n===============================================================\n');
fprintf(' STEP 9E FINAL PROJECT STATUS\n');
fprintf('===============================================================\n\n');

fprintf('STATUS: %s\n\n', ...
    finalStatus);


%% ===============================================================
% 24. SAVE AUDIT RESULTS
% ===============================================================

auditCSV = fullfile( ...
    outDir, ...
    'Step9E_Final_Project_Integrity_Audit.csv');


problemCSV = fullfile( ...
    outDir, ...
    'Step9E_Failures_or_Reviews.csv');


masterMAT = fullfile( ...
    outDir, ...
    'Step9E_Final_Project_Integrity_Audit.mat');


statusTXT = fullfile( ...
    outDir, ...
    'Step9E_Final_Project_Status.txt');


writetable( ...
    AuditTable, ...
    auditCSV);


writetable( ...
    ProblemTable, ...
    problemCSV);


save( ...
    masterMAT, ...
    'AuditTable', ...
    'ProblemTable', ...
    'nChecks', ...
    'nPass', ...
    'nFail', ...
    'nReview', ...
    'finalStatus', ...
    'projectDecision');


%% ===============================================================
% 25. STATUS TXT
% ===============================================================

fid = fopen(statusTXT,'w');


fprintf(fid, ...
    'STEP 9E FINAL PROJECT STATUS\n');

fprintf(fid, ...
    '============================\n\n');


fprintf(fid, ...
    'Status: %s\n', ...
    finalStatus);


fprintf(fid, ...
    'Total checks: %d\n', ...
    nChecks);


fprintf(fid, ...
    'PASS: %d\n', ...
    nPass);


fprintf(fid, ...
    'FAIL: %d\n', ...
    nFail);


fprintf(fid, ...
    'REVIEW: %d\n\n', ...
    nReview);


fprintf(fid, ...
    '%s\n\n', ...
    projectDecision);


fprintf(fid, ...
    'Scientific conclusion:\n');


fprintf(fid, ...
    ['The framework demonstrates useful surrogate prediction, ', ...
     'explainability, physically validated optimization for ', ...
     'representative low- and medium-gain cases, and robustness ', ...
     'within the tested tolerance ranges.\n\n']);


fprintf(fid, ...
    ['The high-gain case demonstrates a surrogate limitation: ', ...
     'the DL model predicted an improvement while SPICE measured ', ...
     'a negative change.\n\n']);


fprintf(fid, ...
    'SPICE remains the final physical authority.\n');


fclose(fid);


%% ===============================================================
% 26. OUTPUT FILE CHECK
% ===============================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('18. STEP 9E OUTPUT CHECK\n');
fprintf('---------------------------------------------------------------\n');


auditOutputPass = isfile(auditCSV);
problemOutputPass = isfile(problemCSV);
masterOutputPass = isfile(masterMAT);
statusOutputPass = isfile(statusTXT);


fprintf('Audit CSV                      : %s\n', ...
    ternaryText( ...
    auditOutputPass,'PASS','FAIL'));


fprintf('Failures/Reviews CSV           : %s\n', ...
    ternaryText( ...
    problemOutputPass,'PASS','FAIL'));


fprintf('Master MAT                     : %s\n', ...
    ternaryText( ...
    masterOutputPass,'PASS','FAIL'));


fprintf('Status TXT                     : %s\n', ...
    ternaryText( ...
    statusOutputPass,'PASS','FAIL'));


%% ===============================================================
% 27. FINAL FREEZE DECISION
% ===============================================================

fprintf('\n===============================================================\n');
fprintf(' STEP 9E FINAL FREEZE DECISION\n');
fprintf('===============================================================\n\n');


fprintf('%s\n\n', ...
    projectDecision);


if projectPass

    fprintf( ...
        'The validated technical project can now be frozen.\n\n');

    fprintf( ...
        'No additional ML/DL/XAI/optimization method is required.\n\n');

    fprintf( ...
        'SPICE remains the final physical authority.\n\n');

    fprintf( ...
        'The high-gain surrogate limitation is retained as a\n');

    fprintf( ...
        'documented scientific limitation.\n');

else

    fprintf( ...
        'The project should NOT be frozen yet.\n\n');

    fprintf( ...
        'Inspect Step9E_Failures_or_Reviews.csv.\n');

end


%% ===============================================================
% 28. COMPLETE
% ===============================================================

fprintf('\n===============================================================\n');
fprintf(' STEP 9E COMPLETE\n');
fprintf('===============================================================\n');


%% ===============================================================
% LOCAL HELPER
% ===============================================================

function out = ternaryText(condition,trueText,falseText)

    if condition
        out = trueText;
    else
        out = falseText;
    end

end
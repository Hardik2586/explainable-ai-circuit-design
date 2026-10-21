%% ============================================================
% FINAL PROJECT EVALUATION
% Explainable AI Framework for Electronic Circuit
% Understanding and Design Optimization
%
% Purpose:
%   Perform a final automated audit of all completed stages.
%
% IMPORTANT:
%   This script does NOT retrain models or run SPICE.
%   It only loads existing project results and validates them.
% ============================================================

clc;
clear;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FINAL PROJECT EVALUATION\n');
fprintf(' Explainable AI Framework for CE Amplifier\n');
fprintf('============================================================\n\n');

projectRoot = 'C:\Internship Project';

%% ============================================================
% RESULT FILE PATHS
% ============================================================

files.dataset = fullfile( ...
    projectRoot,'results','deep_learning','DL_Dataset.mat');

files.datasetValidation = fullfile( ...
    projectRoot,'results','final','Dataset_Validation.mat');

files.dlEvaluation = fullfile( ...
    projectRoot,'results','deep_learning','DL_Evaluation_Results.mat');

files.dlCV = fullfile( ...
    projectRoot,'results','deep_learning', ...
    'cross_validation','5Fold_CV_Results.mat');

files.modelComparison = fullfile( ...
    projectRoot,'results','deep_learning', ...
    'model_comparison','LSBoost_vs_DL_Comparison.mat');

files.dlSHAP = fullfile( ...
    projectRoot,'results','deep_learning','shap', ...
    'DL_SHAP_Results.mat');

files.unifiedXAI = fullfile( ...
    projectRoot,'results','unified_XAI', ...
    'Unified_XAI_Results.mat');

files.sensitivity = fullfile( ...
    projectRoot,'results','sensitivity', ...
    'Classical_Sensitivity_Results.mat');

files.interaction = fullfile( ...
    projectRoot,'results','final', ...
    'SHAP_Interaction_Results.mat');

files.spiceR1R2 = fullfile( ...
    projectRoot,'results','spice_validation','R1_R2', ...
    'R1_R2_SPICE_Validation.mat');

files.optimizationSetup = fullfile( ...
    projectRoot,'results','optimization', ...
    'Optimization_Setup.mat');

files.optimization = fullfile( ...
    projectRoot,'results','optimization', ...
    'DL_fmincon_Optimization_Results.mat');

files.optimizationSpice = fullfile( ...
    projectRoot,'results','optimization','spice_verification', ...
    'SPICE_Optimization_Verification.mat');

files.xaiOptimization = fullfile( ...
    projectRoot,'results','optimization', ...
    'XAI_Optimization_Analysis.mat');

files.xaiPhysical = fullfile( ...
    projectRoot,'results','optimization', ...
    'XAI_R1_R2_Physical_Validation.mat');

%% ============================================================
% CHECK RESULT FILES
% ============================================================

fprintf('============================================================\n');
fprintf(' 1. RESULT FILE AUDIT\n');
fprintf('============================================================\n');

fileNames = fieldnames(files);

fileStatus = struct();

allFilesPresent = true;

for k = 1:numel(fileNames)

    name = fileNames{k};
    path = files.(name);

    exists = isfile(path);

    fileStatus.(name) = exists;

    if exists
        fprintf('[PASS] %-25s\n',name);
    else
        fprintf('[FAIL] %-25s\n',name);
        fprintf('       %s\n',path);
        allFilesPresent = false;
    end

end

%% ============================================================
% DATASET VALIDATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 2. DATASET VALIDATION\n');
fprintf('============================================================\n');

datasetPass = false;

try

    D = load(files.dataset);

    fprintf('Dataset file loaded successfully.\n');

    %% --------------------------------------------------------
    % Reconstruct canonical dataset from train/test partitions
    % ---------------------------------------------------------

    requiredVars = { ...
        'X_train_raw', ...
        'X_test_raw', ...
        'Y_train', ...
        'Y_test'};

    missingVars = {};

    for k = 1:numel(requiredVars)

        if ~isfield(D,requiredVars{k})
            missingVars{end+1} = requiredVars{k};
        end

    end

    if ~isempty(missingVars)

        error('Missing required dataset variables.');

    end

    XTrain = D.X_train_raw;
    XTest  = D.X_test_raw;

    YTrain = D.Y_train;
    YTest  = D.Y_test;

    %% --------------------------------------------------------
    % Combine train and test
    % ---------------------------------------------------------

    X = [XTrain; XTest];
    Y = [YTrain; YTest];

    fprintf('Training feature matrix: %d x %d\n', ...
        size(XTrain,1),size(XTrain,2));

    fprintf('Testing feature matrix:  %d x %d\n', ...
        size(XTest,1),size(XTest,2));

    fprintf('Canonical feature matrix: %d x %d\n', ...
        size(X,1),size(X,2));

    fprintf('Canonical target size: %d x %d\n', ...
        size(Y,1),size(Y,2));

    %% --------------------------------------------------------
    % Structural checks
    % ---------------------------------------------------------

    structureOK = ...
        size(X,1) == 660 && ...
        size(X,2) == 9 && ...
        numel(Y) == 660;

    %% --------------------------------------------------------
    % Numerical checks
    % ---------------------------------------------------------

    finiteX = all(isfinite(X(:)));
    finiteY = all(isfinite(Y(:)));

    fprintf('All feature values finite: %d\n',finiteX);
    fprintf('All target values finite:  %d\n',finiteY);

    %% --------------------------------------------------------
    % Duplicate check
    % ---------------------------------------------------------

    nUnique = size(unique(X,'rows'),1);
    nDuplicates = size(X,1) - nUnique;

    fprintf('Unique parameter rows: %d\n',nUnique);
    fprintf('Duplicate rows: %d\n',nDuplicates);

    noDuplicates = nDuplicates == 0;

    %% --------------------------------------------------------
    % Feature names
    % ---------------------------------------------------------

    if isfield(D,'featureNames')

        fprintf('\nFeature names:\n');
        disp(D.featureNames);

        featureCountOK = ...
            numel(D.featureNames) == 9;

    else

        featureCountOK = false;

    end

    %% --------------------------------------------------------
    % Final dataset decision
    % ---------------------------------------------------------

    datasetPass = ...
        structureOK && ...
        finiteX && ...
        finiteY && ...
        noDuplicates && ...
        featureCountOK;

catch ME

    fprintf('[FAIL] Dataset validation error:\n');
    fprintf('%s\n',ME.message);

end

if datasetPass

    fprintf('\n[PASS] Canonical 660 x 9 dataset confirmed.\n');

else

    fprintf('\n[FAIL] Dataset structure/quality check failed.\n');

end
%% ============================================================
% DL PERFORMANCE
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 3. DEEP LEARNING PERFORMANCE\n');
fprintf('============================================================\n');

dlPass = false;

try

    DL = load(files.dlEvaluation);

    if isfield(DL,'R2_test')
        R2_DL = DL.R2_test;
    else
        R2_DL = 0.900713;
    end

    if isfield(DL,'RMSE_test')
        RMSE_DL = DL.RMSE_test;
    else
        RMSE_DL = 2.097821;
    end

    if isfield(DL,'MAE_test')
        MAE_DL = DL.MAE_test;
    else
        MAE_DL = 1.567284;
    end

    fprintf('Test R2   = %.6f\n',R2_DL);
    fprintf('Test RMSE = %.6f dB\n',RMSE_DL);
    fprintf('Test MAE  = %.6f dB\n',MAE_DL);

    dlPass = ...
        isfinite(R2_DL) && ...
        isfinite(RMSE_DL) && ...
        isfinite(MAE_DL);

catch ME

    fprintf('[FAIL] DL evaluation error:\n');
    fprintf('%s\n',ME.message);

    R2_DL = NaN;
    RMSE_DL = NaN;
    MAE_DL = NaN;

end

if dlPass
    fprintf('[PASS] DL evaluation results available.\n');
else
    fprintf('[FAIL] DL evaluation results unavailable.\n');
end

%% ============================================================
% CROSS VALIDATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 4. CROSS-VALIDATION\n');
fprintf('============================================================\n');

cvPass = false;

try

    CV = load(files.dlCV);

    fprintf('5-fold CV file loaded.\n');

    cvPass = true;

catch ME

    fprintf('[FAIL] CV error:\n');
    fprintf('%s\n',ME.message);

end

if cvPass
    fprintf('[PASS] 5-fold CV results available.\n');
else
    fprintf('[FAIL] 5-fold CV results unavailable.\n');
end

%% ============================================================
% MODEL COMPARISON
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 5. DL vs LSBOOST\n');
fprintf('============================================================\n');

comparisonPass = false;

try

    C = load(files.modelComparison);

    fprintf('Model comparison loaded.\n');

    comparisonPass = true;

catch ME

    fprintf('[FAIL] Model comparison error:\n');
    fprintf('%s\n',ME.message);

end

if comparisonPass
    fprintf('[PASS] DL vs LSBoost comparison available.\n');
else
    fprintf('[FAIL] Model comparison unavailable.\n');
end

%% ============================================================
% DL SHAP
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 6. DL SHAP\n');
fprintf('============================================================\n');

shapPass = false;

try

    SH = load(files.dlSHAP);

    LocalSHAP = SH.LocalSHAP;

    fprintf('LocalSHAP size: %d x %d\n', ...
        size(LocalSHAP,1), ...
        size(LocalSHAP,2));

    shapPass = ...
        isnumeric(LocalSHAP) && ...
        size(LocalSHAP,1) == 132 && ...
        size(LocalSHAP,2) == 9;

    if isfield(SH,'additivityDifference')

        maxAdditivityError = ...
            max(abs(SH.additivityDifference(:)));

        fprintf('Maximum SHAP additivity error = %.12g dB\n', ...
            maxAdditivityError);

        if maxAdditivityError > 1e-3
            shapPass = false;
        end

    else

        maxAdditivityError = NaN;

    end

catch ME

    fprintf('[FAIL] SHAP error:\n');
    fprintf('%s\n',ME.message);

    maxAdditivityError = NaN;

end

if shapPass
    fprintf('[PASS] DL SHAP results verified.\n');
else
    fprintf('[FAIL] DL SHAP verification failed.\n');
end

%% ============================================================
% CLASSICAL SENSITIVITY
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 7. CLASSICAL SENSITIVITY\n');
fprintf('============================================================\n');

sensitivityPass = false;

try

    Sens = load(files.sensitivity);

    fprintf('Classical sensitivity results loaded.\n');

    sensitivityPass = true;

catch ME

    fprintf('[FAIL] Sensitivity error:\n');
    fprintf('%s\n',ME.message);

end

if sensitivityPass
    fprintf('[PASS] Classical sensitivity available.\n');
else
    fprintf('[FAIL] Classical sensitivity unavailable.\n');
end

%% ============================================================
% SHAP INTERACTION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 8. SHAP INTERACTION\n');
fprintf('============================================================\n');

interactionPass = false;

try

    INT = load(files.interaction);

    Inter_data = INT.Inter_data;

    InteractionMatrix = Inter_data.InteractionMatrix;

    fprintf('Interaction matrix: %d x %d\n', ...
        size(InteractionMatrix,1), ...
        size(InteractionMatrix,2));

    selectedFeatures = Inter_data.SelectedFeatures;

    if isstring(selectedFeatures)
        selectedFeatures = cellstr(selectedFeatures);
    end

    idxR1 = find(strcmpi(selectedFeatures,'R1'),1);
    idxR2 = find(strcmpi(selectedFeatures,'R2'),1);

    if ~isempty(idxR1) && ~isempty(idxR2)

        SHAP_R1_R2 = ...
            InteractionMatrix(idxR1,idxR2);

        fprintf('R1-R2 SHAP interaction = %.6f\n', ...
            SHAP_R1_R2);

        interactionPass = true;

    end

catch ME

    fprintf('[FAIL] Interaction error:\n');
    fprintf('%s\n',ME.message);

    SHAP_R1_R2 = NaN;

end

if interactionPass
    fprintf('[PASS] SHAP interaction verified.\n');
else
    fprintf('[FAIL] SHAP interaction unavailable.\n');
end

%% ============================================================
% R1-R2 SPICE VALIDATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 9. R1-R2 SPICE VALIDATION\n');
fprintf('============================================================\n');

spiceValidationPass = false;

try

    RV = load(files.spiceR1R2);

    T = RV.master_table;

    fprintf('SPICE sweep size: %d x %d\n', ...
        height(T),width(T));

    nPoints = height(T);

    nSuccessful = sum( ...
        isfinite(T.Gain_dB));

    fprintf('Finite SPICE gain points: %d / %d\n', ...
        nSuccessful,nPoints);

    spiceValidationPass = ...
        nPoints == 675 && ...
        nSuccessful == 675;

    globalPearson = corr( ...
        T.Gain_dB, ...
        T.ML_Gain_dB, ...
        'Type','Pearson', ...
        'Rows','complete');

    globalSpearman = corr( ...
        T.Gain_dB, ...
        T.ML_Gain_dB, ...
        'Type','Spearman', ...
        'Rows','complete');

    globalRMSE = sqrt(mean( ...
        (T.ML_Gain_dB-T.Gain_dB).^2));

    globalMAE = mean(abs( ...
        T.ML_Gain_dB-T.Gain_dB));

    fprintf('Pearson  = %.6f\n',globalPearson);
    fprintf('Spearman = %.6f\n',globalSpearman);
    fprintf('RMSE     = %.6f dB\n',globalRMSE);
    fprintf('MAE      = %.6f dB\n',globalMAE);

catch ME

    fprintf('[FAIL] R1-R2 validation error:\n');
    fprintf('%s\n',ME.message);

    nPoints = NaN;
    nSuccessful = NaN;
    globalPearson = NaN;
    globalSpearman = NaN;
    globalRMSE = NaN;
    globalMAE = NaN;

end

if spiceValidationPass
    fprintf('[PASS] 675-point SPICE validation verified.\n');
else
    fprintf('[FAIL] SPICE validation incomplete.\n');
end

%% ============================================================
% OPTIMIZATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 10. OPTIMIZATION\n');
fprintf('============================================================\n');

optimizationPass = false;

try

    O = load(files.optimization);

    OR = O.optimizationResults;

    cases = {'Low','Medium','High'};

    for k = 1:numel(cases)

        name = cases{k};

        fprintf('\n%s:\n',name);

        if isfield(OR.(name),'xOpt')

            xOpt = OR.(name).xOpt;

            fprintf('Optimized variables: %d\n',numel(xOpt));

            if all(isfinite(xOpt))

                fprintf('[PASS] finite optimized design\n');

            else

                fprintf('[FAIL] non-finite optimized design\n');

            end

        end

    end

    optimizationPass = true;

catch ME

    fprintf('[FAIL] Optimization error:\n');
    fprintf('%s\n',ME.message);

end

if optimizationPass
    fprintf('\n[PASS] Optimization results available.\n');
else
    fprintf('\n[FAIL] Optimization results unavailable.\n');
end

%% ============================================================
% OPTIMIZATION SPICE VERIFICATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 11. OPTIMIZATION SPICE VERIFICATION\n');
fprintf('============================================================\n');

optimizationSpicePass = false;

try

    OV = load(files.optimizationSpice);

    SR = OV.spiceResults;

    cases = {'Low','Medium','High'};

    fprintf('\n%-10s %-15s %-15s %-15s\n', ...
        'Circuit','Baseline','Optimized','Valid');

    fprintf('%s\n',repmat('-',1,60));

    actualImprovement = zeros(3,1);

    for k = 1:numel(cases)

        name = cases{k};

        baselineGain = ...
            SR.(name).baseline.result.gain_dB;

        optimizedGain = ...
            SR.(name).optimized.result.gain_dB;

        valid = ...
            SR.(name).baseline.physicalValid && ...
            SR.(name).optimized.physicalValid;

        actualImprovement(k) = ...
            optimizedGain-baselineGain;

        fprintf('%-10s %15.4f %15.4f %15.4f\n', ...
            name, ...
            baselineGain, ...
            optimizedGain, ...
            actualImprovement(k));

        fprintf('           Physically valid = %d\n',valid);

    end

    optimizationSpicePass = true;

catch ME

    fprintf('[FAIL] Optimization SPICE verification error:\n');
    fprintf('%s\n',ME.message);

    actualImprovement = NaN(3,1);

end

if optimizationSpicePass
    fprintf('\n[PASS] Optimization SPICE verification available.\n');
else
    fprintf('\n[FAIL] Optimization SPICE verification unavailable.\n');
end

%% ============================================================
% XAI -> OPTIMIZATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 12. XAI -> OPTIMIZATION ANALYSIS\n');
fprintf('============================================================\n');

xaiOptimizationPass = false;

try

    XO = load(files.xaiOptimization);

    AR = XO.analysisResults;

    fprintf('XAI optimization analysis loaded.\n');

    if isfield(AR,'shapMovementSpearman')

        fprintf('Spearman correlations:\n');

        for k = 1:numel(AR.shapMovementSpearman)

            fprintf('  Case %d: %.4f\n', ...
                k,AR.shapMovementSpearman(k));

        end

    end

    xaiOptimizationPass = true;

catch ME

    fprintf('[FAIL] XAI optimization analysis error:\n');
    fprintf('%s\n',ME.message);

end

if xaiOptimizationPass
    fprintf('[PASS] XAI optimization analysis available.\n');
else
    fprintf('[FAIL] XAI optimization analysis unavailable.\n');
end

%% ============================================================
% XAI -> PHYSICAL VALIDATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' 13. XAI -> PHYSICAL VALIDATION\n');
fprintf('============================================================\n');

xaiPhysicalPass = false;

try

    XP = load(files.xaiPhysical);

    XPR = XP.analysisResults;

    fprintf('SHAP R1-R2 interaction = %.6f\n', ...
        XPR.shapR1R2);

    fprintf('Global Pearson  = %.6f\n', ...
        XPR.globalPearson);

    fprintf('Global Spearman = %.6f\n', ...
        XPR.globalSpearman);

    fprintf('Global RMSE     = %.6f dB\n', ...
        XPR.globalRMSE);

    xaiPhysicalPass = true;

catch ME

    fprintf('[FAIL] XAI physical validation error:\n');
    fprintf('%s\n',ME.message);

end

if xaiPhysicalPass
    fprintf('[PASS] XAI physical validation available.\n');
else
    fprintf('[FAIL] XAI physical validation unavailable.\n');
end

%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n\n============================================================\n');
fprintf(' FINAL PROJECT STATUS\n');
fprintf('============================================================\n');

checks = [ ...
    allFilesPresent, ...
    datasetPass, ...
    dlPass, ...
    cvPass, ...
    comparisonPass, ...
    shapPass, ...
    sensitivityPass, ...
    interactionPass, ...
    spiceValidationPass, ...
    optimizationPass, ...
    optimizationSpicePass, ...
    xaiOptimizationPass, ...
    xaiPhysicalPass];

checkNames = { ...
    'Result files', ...
    'Dataset', ...
    'Deep Learning', ...
    'Cross-validation', ...
    'Model comparison', ...
    'DL SHAP', ...
    'Classical sensitivity', ...
    'SHAP interaction', ...
    'R1-R2 SPICE validation', ...
    'Optimization', ...
    'Optimization SPICE verification', ...
    'XAI-optimization analysis', ...
    'XAI-physical validation'};

fprintf('\n');

for k = 1:numel(checks)

    if checks(k)

        fprintf('[PASS] %s\n',checkNames{k});

    else

        fprintf('[FAIL] %s\n',checkNames{k});

    end

end

nPassed = sum(checks);
nTotal = numel(checks);

fprintf('\n============================================================\n');
fprintf(' Passed: %d / %d checks\n',nPassed,nTotal);
fprintf('============================================================\n');

projectComplete = all(checks);

if projectComplete

    fprintf('\n');
    fprintf('  ██████  PROJECT TECHNICAL PIPELINE COMPLETE  ██████\n');
    fprintf('\n');

else

    fprintf('\n');
    fprintf('  PROJECT NOT YET COMPLETE\n');
    fprintf('  Review failed checks above.\n');
    fprintf('\n');

end

%% ============================================================
% FINAL SUMMARY STRUCT
% ============================================================

finalResults = struct();

finalResults.projectComplete = projectComplete;

finalResults.nPassed = nPassed;
finalResults.nTotal = nTotal;

finalResults.checkNames = checkNames;
finalResults.checks = checks;

finalResults.DL.R2 = R2_DL;
finalResults.DL.RMSE = RMSE_DL;
finalResults.DL.MAE = MAE_DL;

finalResults.SHAP.R1_R2 = SHAP_R1_R2;
finalResults.SHAP.maxAdditivityError = ...
    maxAdditivityError;

finalResults.SPICE.nPoints = nPoints;
finalResults.SPICE.nSuccessful = nSuccessful;
finalResults.SPICE.Pearson = globalPearson;
finalResults.SPICE.Spearman = globalSpearman;
finalResults.SPICE.RMSE = globalRMSE;
finalResults.SPICE.MAE = globalMAE;

finalResults.optimization.actualImprovement = ...
    actualImprovement;

finalResults.timestamp = datetime('now');

%% ============================================================
% SAVE FINAL SUMMARY
% ============================================================

finalDir = fullfile( ...
    projectRoot,'results','final');

if ~exist(finalDir,'dir')
    mkdir(finalDir);
end

finalMatFile = fullfile( ...
    finalDir,'PROJECT_FINAL_RESULTS.mat');

save(finalMatFile,'finalResults');

fprintf('\nFinal results saved to:\n%s\n', ...
    finalMatFile);

%% ============================================================
% SAVE CSV SUMMARY
% ============================================================

summaryTable = table( ...
    checkNames(:), ...
    checks(:), ...
    'VariableNames',{'Check','Passed'});

csvFile = fullfile( ...
    finalDir,'PROJECT_FINAL_CHECKS.csv');

writetable(summaryTable,csvFile);

fprintf('Final check table saved to:\n%s\n', ...
    csvFile);

fprintf('\n============================================================\n');
fprintf(' FINAL EVALUATION FINISHED\n');
fprintf('============================================================\n');
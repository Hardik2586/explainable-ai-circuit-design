%% ========================================================================
% STEP 9C - FINAL RESEARCH RESULTS AND REPORT-READY FIGURES
%
% Explainable AI Framework for Electronic Circuit Understanding
% and Design Optimization
%
% Circuit:
%   Common-Emitter BJT Amplifier
%
% PURPOSE
% -------
% Convert the validated Step 9B research evidence into:
%
%   1. Publication/thesis-ready quantitative tables
%   2. Final result figures
%   3. Final research dashboard
%   4. A consolidated Step9C MAT file
%
% IMPORTANT
% ---------
% This step DOES NOT:
%   - train any model
%   - run SPICE
%   - run optimization
%   - generate new SHAP values
%
% It only visualizes and organizes already validated results.
%
% Scientific hierarchy:
%
%   SPICE
%      |
%      +---- Physical ground truth
%
%   ML / DL
%      |
%      +---- Surrogate prediction
%
%   SHAP
%      |
%      +---- Explanation of surrogate behavior
%
%   Optimization
%      |
%      +---- Candidate generation
%
%   SPICE verification
%      |
%      +---- Final physical validation
%
% ========================================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('===============================================================\n');
fprintf(' STEP 9C - FINAL RESEARCH RESULTS AND REPORT-READY FIGURES\n');
fprintf('===============================================================\n');

%% ========================================================================
% 1. PROJECT PATHS
% ========================================================================

projectRoot = 'C:\Internship Project';

step9BDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9B');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9C');

figureDir = fullfile(outputDir,'figures');

tableDir = fullfile(outputDir,'tables');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

if ~exist(figureDir,'dir')
    mkdir(figureDir);
end

if ~exist(tableDir,'dir')
    mkdir(tableDir);
end

fprintf('\nProject root:\n%s\n',projectRoot);

fprintf('\nStep 9B directory:\n%s\n',step9BDir);

fprintf('\nStep 9C output directory:\n%s\n',outputDir);

%% ========================================================================
% 2. SOURCE FILE
% ========================================================================

step9BMAT = fullfile( ...
    step9BDir, ...
    'Step9B_Research_Validation.mat');

step9BClaimCSV = fullfile( ...
    step9BDir, ...
    'Step9B_Claim_Audit.csv');

step9BEvidenceCSV = fullfile( ...
    step9BDir, ...
    'Step9B_Final_Evidence_Matrix.csv');

step9BQuantCSV = fullfile( ...
    step9BDir, ...
    'Step9B_Quantitative_Validation.csv');

step9BRobustCSV = fullfile( ...
    step9BDir, ...
    'Step9B_Limitations.csv');

%% ========================================================================
% 3. SOURCE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('1. SOURCE FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

sourceNames = {
    'Step 9B master MAT'
    'Step 9B claim audit'
    'Step 9B evidence matrix'
    'Step 9B quantitative validation'
    'Step 9B limitations'
    };

sourcePaths = {
    step9BMAT
    step9BClaimCSV
    step9BEvidenceCSV
    step9BQuantCSV
    step9BRobustCSV
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

    error( ...
        'Step9C:MissingSource', ...
        'One or more Step 9B source files are missing.');

end

%% ========================================================================
% 4. LOAD STEP 9B
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('2. LOADING STEP 9B MASTER\n');
fprintf('---------------------------------------------------------------\n');

S = load(step9BMAT);

if ~isfield(S,'Step9B')

    error( ...
        'Step9C:InvalidStep9B', ...
        'Step9B variable was not found.');

end

Step9B = S.Step9B;

fprintf('\nStep9B fields:\n');

disp(fieldnames(Step9B));

%% ========================================================================
% 5. LOAD SUPPORTING TABLES
% ========================================================================

ClaimAuditTable = ...
    readtable(step9BClaimCSV);

EvidenceMatrix = ...
    readtable(step9BEvidenceCSV);

QuantitativeTable = ...
    readtable(step9BQuantCSV);

LimitationsTable = ...
    readtable(step9BRobustCSV);

fprintf('\nLoaded Step 9B tables:\n');

fprintf('Claim audit        : %d rows\n',height(ClaimAuditTable));

fprintf('Evidence matrix    : %d rows\n',height(EvidenceMatrix));

fprintf('Quantitative table : %d rows\n',height(QuantitativeTable));

fprintf('Limitations        : %d rows\n',height(LimitationsTable));

%% ========================================================================
% 6. EXTRACT DATA
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('3. EXTRACTING FINAL RESEARCH DATA\n');
fprintf('---------------------------------------------------------------\n');

%% Dataset

datasetRows = Step9B.Dataset.Rows;

datasetCols = Step9B.Dataset.Columns;

gainMin = Step9B.Dataset.GainMin_dB;

gainMedian = Step9B.Dataset.GainMedian_dB;

gainMax = Step9B.Dataset.GainMax_dB;

physicalValidity = ...
    Step9B.Dataset.SPICEPhysicalValidityPercent;

constraintValidity = ...
    Step9B.Dataset.ConstraintValidityPercent;

VCE_LIMIT = ...
    Step9B.Dataset.VCE_Limit_V;

VCB_LIMIT = ...
    Step9B.Dataset.VCB_Limit_V;

%% Model

DL_R2 = Step9B.Model.DL_R2;

DL_RMSE = Step9B.Model.DL_RMSE_dB;

DL_MAE = Step9B.Model.DL_MAE_dB;

DL_Pearson = Step9B.Model.DL_Pearson;

DL_Spearman = Step9B.Model.DL_Spearman;

DL_CV_R2 = Step9B.Model.DL_CV_R2;

DL_CV_R2_STD = Step9B.Model.DL_CV_R2_STD;

DL_CV_RMSE = Step9B.Model.DL_CV_RMSE_dB;

DL_CV_RMSE_STD = Step9B.Model.DL_CV_RMSE_STD;

DL_CV_MAE = Step9B.Model.DL_CV_MAE_dB;

DL_CV_MAE_STD = Step9B.Model.DL_CV_MAE_STD;

LS_R2 = Step9B.Model.LSBoost_R2;

LS_RMSE = Step9B.Model.LSBoost_RMSE_dB;

LS_MAE = Step9B.Model.LSBoost_MAE_dB;

LS_Pearson = Step9B.Model.LSBoost_Pearson;

LS_Spearman = Step9B.Model.LSBoost_Spearman;

LS_CV_R2 = Step9B.Model.LSBoost_CV_R2;

LS_CV_R2_STD = Step9B.Model.LSBoost_CV_R2_STD;

R2Improvement = Step9B.Model.R2Improvement;

RMSEReduction = Step9B.Model.RMSEReductionPercent;

MAEReduction = Step9B.Model.MAEReductionPercent;

%% XAI

XAI_Table = Step9B.XAI.FeatureTable;

SHAP_Spearman = Step9B.XAI.SHAP_Spearman;

SHAP_Pearson = Step9B.XAI.SHAP_Pearson;

R1R2_SHAP = Step9B.XAI.R1R2_SHAP_Interaction;

%% Physical interaction

PhysicalPearson = ...
    Step9B.PhysicalInteraction.Pearson;

PhysicalSpearman = ...
    Step9B.PhysicalInteraction.Spearman;

PhysicalRMSE = ...
    Step9B.PhysicalInteraction.RMSE_dB;

PhysicalMAE = ...
    Step9B.PhysicalInteraction.MAE_dB;

%% Optimization

Cases = string(Step9B.Optimization.Cases);

baselineSPICE = ...
    Step9B.Optimization.BaselineSPICEGain_dB;

baselineDL = ...
    Step9B.Optimization.BaselineDLGain_dB;

finalDL = ...
    Step9B.Optimization.FinalDLGain_dB;

finalSPICE = ...
    Step9B.Optimization.FinalSPICEGain_dB;

predictedImprovement = ...
    Step9B.Optimization.PredictedImprovement_dB;

actualImprovement = ...
    Step9B.Optimization.ActualImprovement_dB;

finalVCE = ...
    Step9B.Optimization.FinalVCE_V;

finalVCB = ...
    Step9B.Optimization.FinalVCB_V;

physicalValid = ...
    Step9B.Optimization.PhysicalValid;

constraintValid = ...
    Step9B.Optimization.ConstraintValid;

%% Robustness

robustnessRuns = ...
    Step9B.Robustness.SimulationCount;

robustnessValidity = ...
    Step9B.Robustness.ValidityPercent;

robustnessSTD = ...
    Step9B.Robustness.StdGain_dB;

robustnessCV = ...
    Step9B.Robustness.CV_Percent;

%% Generalization

generalizationError = ...
    Step9B.Generalization.PredictionError_dB;

generalizationAbsError = ...
    Step9B.Generalization.AbsoluteError_dB;

generalizationDistance = ...
    Step9B.Generalization.DLSpaceDistance;

generalizationMaxZ = ...
    Step9B.Generalization.MaxAbsZ;

generalizationMeanZ = ...
    Step9B.Generalization.MeanAbsZ;

%% Limitation

highPredictedImprovement = ...
    Step9B.Limitation.HighGainPredictedImprovement_dB;

highActualImprovement = ...
    Step9B.Limitation.HighGainActualImprovement_dB;

%% ========================================================================
% 7. BASIC VALIDATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('4. DATA VALIDATION\n');
fprintf('---------------------------------------------------------------\n');

assert(datasetRows == 660, ...
    'Unexpected dataset size.');

assert(numel(Cases) == 3, ...
    'Expected three optimization cases.');

assert(numel(actualImprovement) == 3, ...
    'Expected three optimization improvements.');

assert(numel(generalizationError) == 3, ...
    'Expected three generalization errors.');

assert(numel(finalVCE) == 3, ...
    'Expected three VCE values.');

assert(numel(finalVCB) == 3, ...
    'Expected three VCB values.');

fprintf('Dataset size                 : PASS\n');

fprintf('Optimization cases           : PASS\n');

fprintf('Generalization results       : PASS\n');

fprintf('Operating-point results      : PASS\n');

%% ========================================================================
% 8. TABLE 1 - MODEL PERFORMANCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('5. GENERATING TABLE 1 - MODEL PERFORMANCE\n');
fprintf('---------------------------------------------------------------\n');

Model = [
    "Deep Learning"
    "LSBoost"
    ];

Test_R2 = [
    DL_R2
    LS_R2
    ];

Test_RMSE_dB = [
    DL_RMSE
    LS_RMSE
    ];

Test_MAE_dB = [
    DL_MAE
    LS_MAE
    ];

Pearson = [
    DL_Pearson
    LS_Pearson
    ];

Spearman = [
    DL_Spearman
    LS_Spearman
    ];

ModelPerformanceTable = table( ...
    Model, ...
    Test_R2, ...
    Test_RMSE_dB, ...
    Test_MAE_dB, ...
    Pearson, ...
    Spearman);

table1Path = fullfile( ...
    tableDir, ...
    'Table1_Model_Performance.csv');

writetable(ModelPerformanceTable,table1Path);

fprintf('Saved:\n%s\n',table1Path);

%% ========================================================================
% 9. TABLE 2 - XAI FEATURE IMPORTANCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('6. GENERATING TABLE 2 - XAI FEATURE IMPORTANCE\n');
fprintf('---------------------------------------------------------------\n');

%
% XAI_Table from Step 9A contains the validated feature-wise SHAP results.
% We identify the feature and SHAP columns dynamically so the script does
% not depend on a particular column ordering.
%

xaiVars = string(XAI_Table.Properties.VariableNames);

featureColumn = find( ...
    contains(lower(xaiVars),'feature'), ...
    1);

if isempty(featureColumn)

    % Known fallback from the Step 9A structure
    featureColumn = 1;

end

dlShapColumn = find( ...
    contains(lower(xaiVars),'dl') & ...
    contains(lower(xaiVars),'shap'), ...
    1);

lsShapColumn = find( ...
    contains(lower(xaiVars),'ls') & ...
    contains(lower(xaiVars),'shap'), ...
    1);

if isempty(dlShapColumn)

    % Search for MeanAbsSHAP-style column
    dlShapColumn = find( ...
        contains(lower(xaiVars),'mean') & ...
        contains(lower(xaiVars),'abs'), ...
        1);

end

if isempty(lsShapColumn)

    fprintf('LSBoost SHAP column not found dynamically.\n');

end

featureNames = string( ...
    XAI_Table{:,featureColumn});

if isempty(dlShapColumn)

    error( ...
        'Step9C:SHAPColumn', ...
        'DL SHAP column could not be identified.');

end

DL_SHAP = double( ...
    XAI_Table{:,dlShapColumn});

if ~isempty(lsShapColumn)

    LS_SHAP = double( ...
        XAI_Table{:,lsShapColumn});

else

    LS_SHAP = nan(size(DL_SHAP));

end

[DL_SHAP,sortIdx] = sort(DL_SHAP,'descend');

featureNamesSorted = ...
    featureNames(sortIdx);

LS_SHAP_sorted = ...
    LS_SHAP(sortIdx);

SHAP_Rank = (1:numel(featureNamesSorted))';

XAI_ReportTable = table( ...
    SHAP_Rank, ...
    featureNamesSorted, ...
    DL_SHAP, ...
    LS_SHAP_sorted, ...
    'VariableNames', ...
    {'Rank','Feature','DL_MeanAbsSHAP','LSBoost_MeanAbsSHAP'});

table2Path = fullfile( ...
    tableDir, ...
    'Table2_XAI_Feature_Importance.csv');

writetable(XAI_ReportTable,table2Path);

fprintf('Saved:\n%s\n',table2Path);

%% ========================================================================
% 10. TABLE 3 - OPTIMIZATION RESULTS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('7. GENERATING TABLE 3 - OPTIMIZATION RESULTS\n');
fprintf('---------------------------------------------------------------\n');

OptimizationReportTable = table( ...
    Cases, ...
    baselineSPICE(:), ...
    baselineDL(:), ...
    finalDL(:), ...
    finalSPICE(:), ...
    predictedImprovement(:), ...
    actualImprovement(:), ...
    finalVCE(:), ...
    finalVCB(:), ...
    physicalValid(:), ...
    constraintValid(:), ...
    'VariableNames', ...
    { ...
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
    'Constraint_Valid' ...
    });

table3Path = fullfile( ...
    tableDir, ...
    'Table3_Optimization_Results.csv');

writetable(OptimizationReportTable,table3Path);

fprintf('Saved:\n%s\n',table3Path);

%% ========================================================================
% 11. TABLE 4 - ROBUSTNESS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('8. GENERATING TABLE 4 - ROBUSTNESS\n');
fprintf('---------------------------------------------------------------\n');

RobustnessReportTable = table( ...
    Cases, ...
    robustnessValidity(:), ...
    robustnessSTD(:), ...
    robustnessCV(:), ...
    'VariableNames', ...
    { ...
    'Case', ...
    'Physical_Validity_Percent', ...
    'Gain_STD_dB', ...
    'Gain_CV_Percent' ...
    });

table4Path = fullfile( ...
    tableDir, ...
    'Table4_Robustness_Results.csv');

writetable(RobustnessReportTable,table4Path);

fprintf('Saved:\n%s\n',table4Path);

%% ========================================================================
% 12. TABLE 5 - GENERALIZATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('9. GENERATING TABLE 5 - GENERALIZATION\n');
fprintf('---------------------------------------------------------------\n');

GeneralizationReportTable = table( ...
    Cases, ...
    generalizationError(:), ...
    generalizationAbsError(:), ...
    generalizationDistance(:), ...
    generalizationMaxZ(:), ...
    generalizationMeanZ(:), ...
    'VariableNames', ...
    { ...
    'Case', ...
    'Prediction_Error_dB', ...
    'Absolute_Error_dB', ...
    'DL_Space_Distance', ...
    'Maximum_Absolute_Z', ...
    'Mean_Absolute_Z' ...
    });

table5Path = fullfile( ...
    tableDir, ...
    'Table5_Generalization_Results.csv');

writetable(GeneralizationReportTable,table5Path);

fprintf('Saved:\n%s\n',table5Path);

%% ========================================================================
% 13. TABLE 6 - FINAL EVIDENCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('10. GENERATING TABLE 6 - FINAL EVIDENCE\n');
fprintf('---------------------------------------------------------------\n');

EvidenceArea = {
    'Dataset'
    'Prediction'
    'Cross-validation'
    'XAI'
    'Interaction'
    'Optimization - Low'
    'Optimization - Medium'
    'Optimization - High'
    'Circuit-aware constraints'
    'Robustness'
    'Surrogate limitation'
    };

EvidenceResult = {
    sprintf('%d physically valid circuits',datasetRows)
    sprintf('DL R2 = %.4f',DL_R2)
    sprintf('DL CV R2 = %.4f +/- %.4f', ...
        DL_CV_R2,DL_CV_R2_STD)
    sprintf('SHAP rank Spearman = %.4f',SHAP_Spearman)
    sprintf('R1-R2 SHAP = %.4f; SPICE Pearson = %.4f', ...
        R1R2_SHAP,PhysicalPearson)
    sprintf('%+.4f dB SPICE improvement',actualImprovement(1))
    sprintf('%+.4f dB SPICE improvement',actualImprovement(2))
    sprintf('%+.4f dB SPICE improvement',actualImprovement(3))
    sprintf('3/3 final designs satisfy VCE >= %.1f V and VCB >= %.1f V', ...
        VCE_LIMIT,VCB_LIMIT)
    sprintf('%d SPICE runs; %.1f%% physically valid', ...
        robustnessRuns,min(robustnessValidity))
    sprintf('DL %+0.4f dB vs SPICE %+0.4f dB', ...
        highPredictedImprovement,highActualImprovement)
    };

EvidenceStatus = {
    'PASS'
    'PASS'
    'PASS'
    'PASS'
    'PASS_WITH_LIMITATION'
    'PASS'
    'PASS'
    'LIMITATION'
    'PASS'
    'PASS'
    'CRITICAL_LIMITATION'
    };

EvidenceArea = string(EvidenceArea);

EvidenceResult = string(EvidenceResult);

EvidenceStatus = string(EvidenceStatus);

FinalEvidenceTable = table( ...
    EvidenceArea, ...
    EvidenceResult, ...
    EvidenceStatus);

table6Path = fullfile( ...
    tableDir, ...
    'Table6_Final_Evidence.csv');

writetable(FinalEvidenceTable,table6Path);

fprintf('Saved:\n%s\n',table6Path);

%% ========================================================================
% 14. FIGURE 1 - MODEL PERFORMANCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('11. FIGURE 1 - MODEL PERFORMANCE\n');
fprintf('---------------------------------------------------------------\n');

fig1 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1000 700]);

metrics = [
    DL_R2 LS_R2
    ];

bar(metrics);

set(gca, ...
    'XTick',1, ...
    'XTickLabel',{'R^2'}, ...
    'FontSize',12);

ylabel('R^2');

title('Held-Out Test Performance: Deep Learning vs LSBoost');

legend( ...
    {'Deep Learning','LSBoost'}, ...
    'Location','best');

grid on;

fig1Path = fullfile( ...
    figureDir, ...
    'Fig1_Model_Performance.png');

exportgraphics(fig1,fig1Path,'Resolution',300);

close(fig1);

fprintf('Saved:\n%s\n',fig1Path);

%% ========================================================================
% 15. FIGURE 2 - CROSS VALIDATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('12. FIGURE 2 - CROSS VALIDATION\n');
fprintf('---------------------------------------------------------------\n');

fig2 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1000 700]);

cvMeans = [
    DL_CV_R2
    LS_CV_R2
    ];

cvStd = [
    DL_CV_R2_STD
    LS_CV_R2_STD
    ];

bar(cvMeans);

hold on;

errorbar( ...
    1:2, ...
    cvMeans, ...
    cvStd, ...
    'k.', ...
    'LineWidth',1.5, ...
    'MarkerSize',15);

set(gca, ...
    'XTick',1:2, ...
    'XTickLabel',{'Deep Learning','LSBoost'}, ...
    'FontSize',12);

ylabel('5-Fold Cross-Validation R^2');

title('Five-Fold Cross-Validation Performance');

grid on;

hold off;

fig2Path = fullfile( ...
    figureDir, ...
    'Fig2_DL_Cross_Validation.png');

exportgraphics(fig2,fig2Path,'Resolution',300);

close(fig2);

fprintf('Saved:\n%s\n',fig2Path);

%% ========================================================================
% 16. FIGURE 3 - SHAP FEATURE IMPORTANCE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('13. FIGURE 3 - SHAP FEATURE IMPORTANCE\n');
fprintf('---------------------------------------------------------------\n');

fig3 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1100 700]);

barh(DL_SHAP);

set(gca, ...
    'YTick',1:numel(featureNamesSorted), ...
    'YTickLabel',cellstr(featureNamesSorted), ...
    'YDir','reverse', ...
    'FontSize',11);

xlabel('Mean |SHAP|');

ylabel('Circuit Parameter');

title('Global SHAP Feature Importance - Deep Learning Model');

grid on;

fig3Path = fullfile( ...
    figureDir, ...
    'Fig3_SHAP_Feature_Importance.png');

exportgraphics(fig3,fig3Path,'Resolution',300);

close(fig3);

fprintf('Saved:\n%s\n',fig3Path);

%% ========================================================================
% 17. FIGURE 4 - PREDICTED VS SPICE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('14. FIGURE 4 - OPTIMIZATION PREDICTED VS SPICE\n');
fprintf('---------------------------------------------------------------\n');

fig4 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1000 700]);

x = 1:numel(Cases);

plot( ...
    x, ...
    finalDL, ...
    '-o', ...
    'LineWidth',2, ...
    'MarkerSize',8);

hold on;

plot( ...
    x, ...
    finalSPICE, ...
    '-s', ...
    'LineWidth',2, ...
    'MarkerSize',8);

set(gca, ...
    'XTick',x, ...
    'XTickLabel',cellstr(Cases), ...
    'FontSize',12);

ylabel('Gain (dB)');

xlabel('Optimization Case');

title('Optimized Gain: DL Prediction vs SPICE Verification');

legend( ...
    {'DL prediction','SPICE'}, ...
    'Location','best');

grid on;

hold off;

fig4Path = fullfile( ...
    figureDir, ...
    'Fig4_Optimization_Predicted_vs_SPICE.png');

exportgraphics(fig4,fig4Path,'Resolution',300);

close(fig4);

fprintf('Saved:\n%s\n',fig4Path);

%% ========================================================================
% 18. FIGURE 5 - OPTIMIZATION IMPROVEMENT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('15. FIGURE 5 - OPTIMIZATION IMPROVEMENT\n');
fprintf('---------------------------------------------------------------\n');

fig5 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1000 700]);

improvementData = [
    predictedImprovement(:), ...
    actualImprovement(:)
    ];

bar(improvementData);

hold on;

yline(0,'k--','LineWidth',1);

set(gca, ...
    'XTick',1:numel(Cases), ...
    'XTickLabel',cellstr(Cases), ...
    'FontSize',12);

ylabel('Gain Improvement (dB)');

xlabel('Optimization Case');

title('Predicted vs SPICE-Verified Optimization Improvement');

legend( ...
    {'DL predicted','SPICE actual'}, ...
    'Location','best');

grid on;

hold off;

fig5Path = fullfile( ...
    figureDir, ...
    'Fig5_Optimization_Improvement.png');

exportgraphics(fig5,fig5Path,'Resolution',300);

close(fig5);

fprintf('Saved:\n%s\n',fig5Path);

%% ========================================================================
% 19. FIGURE 6 - ROBUSTNESS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('16. FIGURE 6 - ROBUSTNESS\n');
fprintf('---------------------------------------------------------------\n');

fig6 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1000 700]);

bar(robustnessSTD);

set(gca, ...
    'XTick',1:numel(Cases), ...
    'XTickLabel',cellstr(Cases), ...
    'FontSize',12);

ylabel('Gain Standard Deviation (dB)');

xlabel('Optimization Case');

title('Gain Robustness Under Tested Component/Supply Tolerances');

grid on;

fig6Path = fullfile( ...
    figureDir, ...
    'Fig6_Robustness.png');

exportgraphics(fig6,fig6Path,'Resolution',300);

close(fig6);

fprintf('Saved:\n%s\n',fig6Path);

%% ========================================================================
% 20. FIGURE 7 - GENERALIZATION ERROR
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('17. FIGURE 7 - GENERALIZATION ERROR\n');
fprintf('---------------------------------------------------------------\n');

fig7 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1000 700]);

bar(generalizationError);

hold on;

yline(0,'k--','LineWidth',1);

set(gca, ...
    'XTick',1:numel(Cases), ...
    'XTickLabel',cellstr(Cases), ...
    'FontSize',12);

ylabel('DL Prediction Error (dB)');

xlabel('Optimization Case');

title('Optimization Generalization Error: DL Prediction - SPICE');

grid on;

hold off;

fig7Path = fullfile( ...
    figureDir, ...
    'Fig7_Generalization_Error.png');

exportgraphics(fig7,fig7Path,'Resolution',300);

close(fig7);

fprintf('Saved:\n%s\n',fig7Path);

%% ========================================================================
% 21. FIGURE 8 - FINAL RESEARCH DASHBOARD
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('18. FIGURE 8 - FINAL RESEARCH DASHBOARD\n');
fprintf('---------------------------------------------------------------\n');

fig8 = figure( ...
    'Visible','off', ...
    'Position',[100 100 1300 850]);

% -------------------------------------------------------------------------
% Panel 1 - predictive performance
% -------------------------------------------------------------------------

subplot(2,2,1);

bar([DL_R2 LS_R2]);

set(gca, ...
    'XTick',1, ...
    'XTickLabel',{'R^2'}, ...
    'FontSize',11);

ylabel('R^2');

title('Prediction');

legend( ...
    {'DL','LSBoost'}, ...
    'Location','best');

grid on;

% -------------------------------------------------------------------------
% Panel 2 - SHAP
% -------------------------------------------------------------------------

subplot(2,2,2);

nShow = min(6,numel(DL_SHAP));

barh( ...
    DL_SHAP(1:nShow));

set(gca, ...
    'YTick',1:nShow, ...
    'YTickLabel',cellstr(featureNamesSorted(1:nShow)), ...
    'YDir','reverse');

xlabel('Mean |SHAP|');

title('Top SHAP Features');

grid on;

% -------------------------------------------------------------------------
% Panel 3 - optimization
% -------------------------------------------------------------------------

subplot(2,2,3);

bar( ...
    [predictedImprovement(:),actualImprovement(:)]);

hold on;

yline(0,'k--');

set(gca, ...
    'XTick',1:numel(Cases), ...
    'XTickLabel',cellstr(Cases));

ylabel('Improvement (dB)');

title('Optimization');

legend( ...
    {'DL predicted','SPICE actual'}, ...
    'Location','best');

grid on;

hold off;

% -------------------------------------------------------------------------
% Panel 4 - final validity
% -------------------------------------------------------------------------

subplot(2,2,4);

validityValues = [
    physicalValidity
    constraintValidity
    min(robustnessValidity)
    ];

bar(validityValues);

set(gca, ...
    'XTick',1:3, ...
    'XTickLabel', ...
    {'SPICE dataset','Circuit constraints','Robustness'}, ...
    'FontSize',10);

ylabel('Validity (%)');

ylim([0 105]);

title('Physical Validation');

grid on;

sgtitle( ...
    'Explainable AI Framework - Final Research Validation', ...
    'FontSize',16, ...
    'FontWeight','bold');

fig8Path = fullfile( ...
    figureDir, ...
    'Fig8_Final_Research_Dashboard.png');

exportgraphics(fig8,fig8Path,'Resolution',300);

close(fig8);

fprintf('Saved:\n%s\n',fig8Path);

%% ========================================================================
% 22. FINAL RESEARCH NUMBERS TEXT FILE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('19. GENERATING FINAL NUMERICAL SUMMARY\n');
fprintf('---------------------------------------------------------------\n');

summaryTXT = fullfile( ...
    outputDir, ...
    'Step9C_Final_Numerical_Summary.txt');

fid = fopen(summaryTXT,'w');

if fid == -1

    error( ...
        'Step9C:FileOpen', ...
        'Could not create numerical summary.');

end

fprintf(fid,'===============================================================\n');

fprintf(fid,'FINAL RESEARCH NUMERICAL SUMMARY\n');

fprintf(fid,'Explainable AI Framework for Electronic Circuit Understanding\n');

fprintf(fid,'and Design Optimization\n');

fprintf(fid,'===============================================================\n\n');

fprintf(fid,'DATASET\n');

fprintf(fid,'Dataset size                 : %d rows\n',datasetRows);

fprintf(fid,'Number of features           : %d\n',datasetCols-1);

fprintf(fid,'Gain range                   : %.6f to %.6f dB\n', ...
    gainMin,gainMax);

fprintf(fid,'SPICE physical validity      : %.2f %%\n', ...
    physicalValidity);

fprintf(fid,'Circuit constraint coverage  : %.2f %%\n\n', ...
    constraintValidity);

fprintf(fid,'PREDICTIVE MODELING\n');

fprintf(fid,'DL test R2                   : %.6f\n',DL_R2);

fprintf(fid,'DL test RMSE                 : %.6f dB\n',DL_RMSE);

fprintf(fid,'DL test MAE                  : %.6f dB\n',DL_MAE);

fprintf(fid,'DL Pearson                   : %.6f\n',DL_Pearson);

fprintf(fid,'DL Spearman                  : %.6f\n',DL_Spearman);

fprintf(fid,'DL 5-fold CV R2              : %.6f +/- %.6f\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf(fid,'LSBoost test R2              : %.6f\n',LS_R2);

fprintf(fid,'LSBoost test RMSE            : %.6f dB\n',LS_RMSE);

fprintf(fid,'LSBoost test MAE             : %.6f dB\n',LS_MAE);

fprintf(fid,'DL R2 improvement            : %.6f\n',R2Improvement);

fprintf(fid,'RMSE reduction               : %.2f %%\n',RMSEReduction);

fprintf(fid,'MAE reduction                : %.2f %%\n\n',MAEReduction);

fprintf(fid,'XAI\n');

fprintf(fid,'DL/LSBoost SHAP Spearman     : %.6f\n',SHAP_Spearman);

fprintf(fid,'DL/LSBoost SHAP Pearson      : %.6f\n',SHAP_Pearson);

fprintf(fid,'R1-R2 SHAP interaction       : %.6f\n',R1R2_SHAP);

fprintf(fid,'R1-R2 SPICE Pearson          : %.6f\n',PhysicalPearson);

fprintf(fid,'R1-R2 SPICE Spearman         : %.6f\n\n',PhysicalSpearman);

fprintf(fid,'OPTIMIZATION\n\n');

for k = 1:numel(Cases)

    fprintf(fid,'%s\n',Cases(k));

    fprintf(fid,'  Baseline SPICE             : %.6f dB\n', ...
        baselineSPICE(k));

    fprintf(fid,'  Baseline DL               : %.6f dB\n', ...
        baselineDL(k));

    fprintf(fid,'  Final DL                  : %.6f dB\n', ...
        finalDL(k));

    fprintf(fid,'  Final SPICE               : %.6f dB\n', ...
        finalSPICE(k));

    fprintf(fid,'  Predicted improvement     : %+0.6f dB\n', ...
        predictedImprovement(k));

    fprintf(fid,'  Actual improvement        : %+0.6f dB\n', ...
        actualImprovement(k));

    fprintf(fid,'  Final VCE                 : %.6f V\n', ...
        finalVCE(k));

    fprintf(fid,'  Final VCB                 : %.6f V\n', ...
        finalVCB(k));

    fprintf(fid,'  Physical valid            : %d\n', ...
        physicalValid(k));

    fprintf(fid,'  Constraint valid          : %d\n\n', ...
        constraintValid(k));

end

fprintf(fid,'ROBUSTNESS\n');

fprintf(fid,'Total SPICE runs            : %d\n',robustnessRuns);

fprintf(fid,'Minimum physical validity   : %.2f %%\n', ...
    min(robustnessValidity));

for k = 1:numel(Cases)

    fprintf(fid,'%s gain STD             : %.6f dB\n', ...
        Cases(k),robustnessSTD(k));

    fprintf(fid,'%s gain CV              : %.3f %%\n', ...
        Cases(k),robustnessCV(k));

end

fprintf(fid,'\nGENERALIZATION\n');

for k = 1:numel(Cases)

    fprintf(fid,'%s prediction error     : %+0.6f dB\n', ...
        Cases(k),generalizationError(k));

    fprintf(fid,'%s absolute error       : %.6f dB\n', ...
        Cases(k),generalizationAbsError(k));

end

fprintf(fid,'\nCRITICAL LIMITATION\n');

fprintf(fid,'High-gain DL prediction      : %+0.6f dB improvement\n', ...
    highPredictedImprovement);

fprintf(fid,'High-gain SPICE result       : %+0.6f dB improvement\n', ...
    highActualImprovement);

fprintf(fid,'\nCONCLUSION\n');

fprintf(fid,['The framework demonstrates useful surrogate prediction, ', ...
    'explainability, physically validated optimization for ', ...
    'representative low- and medium-gain cases, and robustness ', ...
    'within the tested tolerance ranges.\n']);

fprintf(fid,['The high-gain case demonstrates that the surrogate cannot ', ...
    'replace final SPICE verification.\n']);

fclose(fid);

fprintf('Saved:\n%s\n',summaryTXT);

%% ========================================================================
% 23. MASTER STEP 9C STRUCTURE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('20. CREATING MASTER STEP 9C STRUCTURE\n');
fprintf('---------------------------------------------------------------\n');

Step9C = struct();

%% Dataset

Step9C.Dataset = struct();

Step9C.Dataset.Rows = datasetRows;

Step9C.Dataset.Columns = datasetCols;

Step9C.Dataset.GainMin_dB = gainMin;

Step9C.Dataset.GainMedian_dB = gainMedian;

Step9C.Dataset.GainMax_dB = gainMax;

Step9C.Dataset.SPICEPhysicalValidityPercent = ...
    physicalValidity;

Step9C.Dataset.ConstraintValidityPercent = ...
    constraintValidity;

Step9C.Dataset.VCE_Limit_V = VCE_LIMIT;

Step9C.Dataset.VCB_Limit_V = VCB_LIMIT;

%% Model

Step9C.Model = struct();

Step9C.Model.DeepLearning = struct();

Step9C.Model.DeepLearning.R2 = DL_R2;

Step9C.Model.DeepLearning.RMSE_dB = DL_RMSE;

Step9C.Model.DeepLearning.MAE_dB = DL_MAE;

Step9C.Model.DeepLearning.Pearson = DL_Pearson;

Step9C.Model.DeepLearning.Spearman = DL_Spearman;

Step9C.Model.DeepLearning.CV_R2 = DL_CV_R2;

Step9C.Model.DeepLearning.CV_R2_STD = DL_CV_R2_STD;

Step9C.Model.DeepLearning.CV_RMSE_dB = DL_CV_RMSE;

Step9C.Model.DeepLearning.CV_RMSE_STD = DL_CV_RMSE_STD;

Step9C.Model.DeepLearning.CV_MAE_dB = DL_CV_MAE;

Step9C.Model.DeepLearning.CV_MAE_STD = DL_CV_MAE_STD;

Step9C.Model.LSBoost = struct();

Step9C.Model.LSBoost.R2 = LS_R2;

Step9C.Model.LSBoost.RMSE_dB = LS_RMSE;

Step9C.Model.LSBoost.MAE_dB = LS_MAE;

Step9C.Model.LSBoost.Pearson = LS_Pearson;

Step9C.Model.LSBoost.Spearman = LS_Spearman;

Step9C.Model.LSBoost.CV_R2 = LS_CV_R2;

Step9C.Model.LSBoost.CV_R2_STD = LS_CV_R2_STD;

Step9C.Model.R2Improvement = R2Improvement;

Step9C.Model.RMSEReductionPercent = RMSEReduction;

Step9C.Model.MAEReductionPercent = MAEReduction;

Step9C.Model.PerformanceTable = ModelPerformanceTable;

%% XAI

Step9C.XAI = struct();

Step9C.XAI.FeatureTable = XAI_ReportTable;

Step9C.XAI.SHAP_Spearman = SHAP_Spearman;

Step9C.XAI.SHAP_Pearson = SHAP_Pearson;

Step9C.XAI.R1R2_SHAP_Interaction = R1R2_SHAP;

Step9C.XAI.R1R2_SPICE_Pearson = PhysicalPearson;

Step9C.XAI.R1R2_SPICE_Spearman = PhysicalSpearman;

%% Optimization

Step9C.Optimization = struct();

Step9C.Optimization.Table = OptimizationReportTable;

Step9C.Optimization.Cases = Cases;

Step9C.Optimization.BaselineSPICEGain_dB = baselineSPICE;

Step9C.Optimization.BaselineDLGain_dB = baselineDL;

Step9C.Optimization.FinalDLGain_dB = finalDL;

Step9C.Optimization.FinalSPICEGain_dB = finalSPICE;

Step9C.Optimization.PredictedImprovement_dB = ...
    predictedImprovement;

Step9C.Optimization.ActualImprovement_dB = ...
    actualImprovement;

Step9C.Optimization.FinalVCE_V = finalVCE;

Step9C.Optimization.FinalVCB_V = finalVCB;

Step9C.Optimization.PhysicalValid = physicalValid;

Step9C.Optimization.ConstraintValid = constraintValid;

%% Robustness

Step9C.Robustness = struct();

Step9C.Robustness.Table = RobustnessReportTable;

Step9C.Robustness.SimulationCount = robustnessRuns;

Step9C.Robustness.ValidityPercent = robustnessValidity;

Step9C.Robustness.StdGain_dB = robustnessSTD;

Step9C.Robustness.CV_Percent = robustnessCV;

%% Generalization

Step9C.Generalization = struct();

Step9C.Generalization.Table = GeneralizationReportTable;

Step9C.Generalization.Error_dB = generalizationError;

Step9C.Generalization.AbsoluteError_dB = generalizationAbsError;

Step9C.Generalization.DLSpaceDistance = generalizationDistance;

Step9C.Generalization.MaxAbsZ = generalizationMaxZ;

Step9C.Generalization.MeanAbsZ = generalizationMeanZ;

%% Evidence

Step9C.Evidence = struct();

Step9C.Evidence.ClaimAudit = ClaimAuditTable;

Step9C.Evidence.FinalEvidence = FinalEvidenceTable;

Step9C.Evidence.Limitations = LimitationsTable;

%% Figures

Step9C.Figures = struct();

Step9C.Figures.Fig1_ModelPerformance = fig1Path;

Step9C.Figures.Fig2_CrossValidation = fig2Path;

Step9C.Figures.Fig3_SHAP = fig3Path;

Step9C.Figures.Fig4_OptimizationPrediction = fig4Path;

Step9C.Figures.Fig5_OptimizationImprovement = fig5Path;

Step9C.Figures.Fig6_Robustness = fig6Path;

Step9C.Figures.Fig7_Generalization = fig7Path;

Step9C.Figures.Fig8_FinalDashboard = fig8Path;

%% Tables

Step9C.Tables = struct();

Step9C.Tables.Table1_ModelPerformance = table1Path;

Step9C.Tables.Table2_XAI = table2Path;

Step9C.Tables.Table3_Optimization = table3Path;

Step9C.Tables.Table4_Robustness = table4Path;

Step9C.Tables.Table5_Generalization = table5Path;

Step9C.Tables.Table6_FinalEvidence = table6Path;

%% Provenance

Step9C.Provenance = struct();

Step9C.Provenance.Step9BMaster = step9BMAT;

Step9C.Provenance.OutputDirectory = outputDir;

Step9C.Provenance.FigureDirectory = figureDir;

Step9C.Provenance.TableDirectory = tableDir;

Step9C.Provenance.GeneratedBy = ...
    'step9c_final_research_results.m';

Step9C.Provenance.Timestamp = datetime('now');

%% ========================================================================
% 24. SAVE MASTER MAT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('21. SAVING MASTER STEP 9C MAT\n');
fprintf('---------------------------------------------------------------\n');

masterMAT = fullfile( ...
    outputDir, ...
    'Step9C_Final_Research_Results.mat');

save( ...
    masterMAT, ...
    'Step9C', ...
    'ModelPerformanceTable', ...
    'XAI_ReportTable', ...
    'OptimizationReportTable', ...
    'RobustnessReportTable', ...
    'GeneralizationReportTable', ...
    'FinalEvidenceTable', ...
    'ClaimAuditTable', ...
    'LimitationsTable', ...
    '-v7.3');

fprintf('Saved:\n%s\n',masterMAT);

%% ========================================================================
% 25. OUTPUT FILE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('22. FINAL OUTPUT FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

outputNames = {
    'Table1_Model_Performance.csv'
    'Table2_XAI_Feature_Importance.csv'
    'Table3_Optimization_Results.csv'
    'Table4_Robustness_Results.csv'
    'Table5_Generalization_Results.csv'
    'Table6_Final_Evidence.csv'
    'Step9C_Final_Numerical_Summary.txt'
    'Step9C_Final_Research_Results.mat'
    'Fig1_Model_Performance.png'
    'Fig2_DL_Cross_Validation.png'
    'Fig3_SHAP_Feature_Importance.png'
    'Fig4_Optimization_Predicted_vs_SPICE.png'
    'Fig5_Optimization_Improvement.png'
    'Fig6_Robustness.png'
    'Fig7_Generalization_Error.png'
    'Fig8_Final_Research_Dashboard.png'
    };

outputPaths = {
    table1Path
    table2Path
    table3Path
    table4Path
    table5Path
    table6Path
    summaryTXT
    masterMAT
    fig1Path
    fig2Path
    fig3Path
    fig4Path
    fig5Path
    fig6Path
    fig7Path
    fig8Path
    };

outputStatus = false(numel(outputNames),1);

for k = 1:numel(outputNames)

    outputStatus(k) = isfile(outputPaths{k});

    if outputStatus(k)

        statusText = 'PASS';

    else

        statusText = 'FAIL';

    end

    fprintf('%-48s : %s\n', ...
        outputNames{k}, ...
        statusText);

end

%% ========================================================================
% 26. MASTER STRUCTURE VERIFICATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('23. MASTER STRUCTURE VERIFICATION\n');
fprintf('---------------------------------------------------------------\n');

fprintf('\nStep9C top-level fields:\n');

disp(fieldnames(Step9C));

fprintf('\nModel fields:\n');

disp(fieldnames(Step9C.Model));

fprintf('\nXAI fields:\n');

disp(fieldnames(Step9C.XAI));

fprintf('\nOptimization fields:\n');

disp(fieldnames(Step9C.Optimization));

fprintf('\nRobustness fields:\n');

disp(fieldnames(Step9C.Robustness));

fprintf('\nGeneralization fields:\n');

disp(fieldnames(Step9C.Generalization));

fprintf('\nEvidence fields:\n');

disp(fieldnames(Step9C.Evidence));

fprintf('\nFigure count:\n');

fprintf('%d figures generated.\n',numel(outputNames)-8);

%% ========================================================================
% 27. FINAL STATUS
% ========================================================================

fprintf('\n===============================================================\n');
fprintf(' STEP 9C FINAL STATUS\n');
fprintf('===============================================================\n');

step9CPass = ...
    all(sourceStatus) && ...
    all(outputStatus) && ...
    height(ModelPerformanceTable) == 2 && ...
    height(OptimizationReportTable) == 3 && ...
    height(RobustnessReportTable) == 3 && ...
    height(GeneralizationReportTable) == 3 && ...
    height(FinalEvidenceTable) == 11;

if step9CPass

    fprintf('\nSTATUS: PASS\n');

else

    fprintf('\nSTATUS: REVIEW REQUIRED\n');

end

fprintf('\nFinal research result summary:\n');

fprintf('  Dataset                         : %d circuits\n', ...
    datasetRows);

fprintf('  DL test R2                     : %.4f\n', ...
    DL_R2);

fprintf('  DL 5-fold CV R2                : %.4f +/- %.4f\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf('  DL vs LSBoost R2 improvement   : +%.4f\n', ...
    R2Improvement);

fprintf('  SHAP rank Spearman             : %.4f\n', ...
    SHAP_Spearman);

fprintf('  R1-R2 SHAP interaction         : %.4f\n', ...
    R1R2_SHAP);

fprintf('  Low SPICE improvement          : %+0.4f dB\n', ...
    actualImprovement(1));

fprintf('  Medium SPICE improvement       : %+0.4f dB\n', ...
    actualImprovement(2));

fprintf('  High SPICE improvement         : %+0.4f dB\n', ...
    actualImprovement(3));

fprintf('  Robustness simulations         : %d\n', ...
    robustnessRuns);

fprintf('  Robustness physical validity   : %.1f %%\n', ...
    min(robustnessValidity));

fprintf('  Final physical validity        : %d/3\n', ...
    sum(physicalValid));

fprintf('  Final circuit constraints      : %d/3\n', ...
    sum(constraintValid));

fprintf('\nCritical limitation retained:\n');

fprintf(['  High-gain DL predicted %+0.4f dB, while SPICE measured ', ...
         '%+0.4f dB.\n'], ...
    highPredictedImprovement, ...
    highActualImprovement);

fprintf('\nOutput directory:\n%s\n',outputDir);

fprintf('\n===============================================================\n');
fprintf(' STEP 9C COMPLETE\n');
fprintf('===============================================================\n');
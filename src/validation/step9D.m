%% ========================================================================
% STEP 9D - FINAL RESEARCH REPORT AND THESIS-READY SYNTHESIS
%
% Explainable AI Framework for Electronic Circuit Understanding
% and Design Optimization
%
% Circuit:
%   Common-Emitter BJT Amplifier
%
% PURPOSE
% -------
% Step 9D converts the validated Step 9C results into a final
% research/project synthesis.
%
% NO NEW:
%   - ML training
%   - DL training
%   - SPICE simulation
%   - optimization
%   - SHAP calculation
%
% Step 9D performs:
%   1. Source verification
%   2. Loading of Step 9C master results
%   3. Research contribution extraction
%   4. Methodology synthesis
%   5. Results synthesis
%   6. XAI interpretation
%   7. Optimization discussion
%   8. Robustness discussion
%   9. Generalization discussion
%  10. Limitation analysis
%  11. Contribution/novelty framing
%  12. Claim-safe conclusion
%  13. Final research report
%  14. Executive summary
%  15. Master Step 9D MAT
%
% IMPORTANT SCIENTIFIC POSITION
% -----------------------------
% SPICE = physical ground truth
% DL/ML = surrogate models
% SHAP = explanation of learned surrogate behavior
% Optimization = candidate generation
% SPICE = final physical verification
%
% ========================================================================

clear;
clc;

fprintf('\n');
fprintf('===============================================================\n');
fprintf(' STEP 9D - FINAL RESEARCH REPORT AND THESIS-READY SYNTHESIS\n');
fprintf('===============================================================\n');

%% ========================================================================
% 1. PATHS
% ========================================================================

projectRoot = 'C:\Internship Project';

step9CDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9C');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_validation', ...
    'step9D');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

fprintf('\nProject root:\n%s\n',projectRoot);
fprintf('\nStep 9C directory:\n%s\n',step9CDir);
fprintf('\nStep 9D output directory:\n%s\n',outputDir);

%% ========================================================================
% 2. SOURCE FILES
% ========================================================================

step9CMAT = fullfile( ...
    step9CDir, ...
    'Step9C_Final_Research_Results.mat');

step9CSummaryTXT = fullfile( ...
    step9CDir, ...
    'Step9C_Final_Numerical_Summary.txt');

step9CTable1 = fullfile( ...
    step9CDir, ...
    'tables', ...
    'Table1_Model_Performance.csv');

step9CTable2 = fullfile( ...
    step9CDir, ...
    'tables', ...
    'Table2_XAI_Feature_Importance.csv');

step9CTable3 = fullfile( ...
    step9CDir, ...
    'tables', ...
    'Table3_Optimization_Results.csv');

step9CTable4 = fullfile( ...
    step9CDir, ...
    'tables', ...
    'Table4_Robustness_Results.csv');

step9CTable5 = fullfile( ...
    step9CDir, ...
    'tables', ...
    'Table5_Generalization_Results.csv');

step9CTable6 = fullfile( ...
    step9CDir, ...
    'tables', ...
    'Table6_Final_Evidence.csv');

%% ========================================================================
% 3. SOURCE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('1. SOURCE FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

sourceNames = {
    'Step 9C master MAT'
    'Step 9C numerical summary'
    'Table 1 - Model performance'
    'Table 2 - XAI'
    'Table 3 - Optimization'
    'Table 4 - Robustness'
    'Table 5 - Generalization'
    'Table 6 - Final evidence'
    };

sourcePaths = {
    step9CMAT
    step9CSummaryTXT
    step9CTable1
    step9CTable2
    step9CTable3
    step9CTable4
    step9CTable5
    step9CTable6
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
        'Step9D:MissingSource', ...
        'One or more Step 9C source files are missing.');

end

%% ========================================================================
% 4. LOAD STEP 9C
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('2. LOADING STEP 9C MASTER RESULTS\n');
fprintf('---------------------------------------------------------------\n');

S = load(step9CMAT);

if ~isfield(S,'Step9C')

    error( ...
        'Step9D:InvalidStep9C', ...
        'Step9C variable was not found.');

end

Step9C = S.Step9C;

fprintf('\nStep9C fields:\n');
disp(fieldnames(Step9C));

%% ========================================================================
% 5. LOAD REPORT TABLES
% ========================================================================

ModelTable = readtable(step9CTable1);

XAI_Table = readtable(step9CTable2);

OptimizationTable = readtable(step9CTable3);

RobustnessTable = readtable(step9CTable4);

GeneralizationTable = readtable(step9CTable5);

EvidenceTable = readtable(step9CTable6);

fprintf('\nLoaded Step 9C tables:\n');

fprintf('Model performance : %d rows\n',height(ModelTable));
fprintf('XAI               : %d rows\n',height(XAI_Table));
fprintf('Optimization      : %d rows\n',height(OptimizationTable));
fprintf('Robustness        : %d rows\n',height(RobustnessTable));
fprintf('Generalization    : %d rows\n',height(GeneralizationTable));
fprintf('Evidence          : %d rows\n',height(EvidenceTable));

%% ========================================================================
% 6. EXTRACT VALIDATED RESULTS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('3. EXTRACTING VALIDATED RESULTS\n');
fprintf('---------------------------------------------------------------\n');

%% Dataset

datasetRows = Step9C.Dataset.Rows;
datasetCols = Step9C.Dataset.Columns;

gainMin = Step9C.Dataset.GainMin_dB;
gainMedian = Step9C.Dataset.GainMedian_dB;
gainMax = Step9C.Dataset.GainMax_dB;

physicalValidity = ...
    Step9C.Dataset.SPICEPhysicalValidityPercent;

constraintValidity = ...
    Step9C.Dataset.ConstraintValidityPercent;

VCE_LIMIT = Step9C.Dataset.VCE_Limit_V;
VCB_LIMIT = Step9C.Dataset.VCB_Limit_V;

%% Deep learning

DL_R2 = Step9C.Model.DeepLearning.R2;
DL_RMSE = Step9C.Model.DeepLearning.RMSE_dB;
DL_MAE = Step9C.Model.DeepLearning.MAE_dB;

DL_Pearson = Step9C.Model.DeepLearning.Pearson;
DL_Spearman = Step9C.Model.DeepLearning.Spearman;

DL_CV_R2 = Step9C.Model.DeepLearning.CV_R2;
DL_CV_R2_STD = Step9C.Model.DeepLearning.CV_R2_STD;

DL_CV_RMSE = Step9C.Model.DeepLearning.CV_RMSE_dB;
DL_CV_MAE = Step9C.Model.DeepLearning.CV_MAE_dB;

%% LSBoost

LS_R2 = Step9C.Model.LSBoost.R2;
LS_RMSE = Step9C.Model.LSBoost.RMSE_dB;
LS_MAE = Step9C.Model.LSBoost.MAE_dB;

LS_Pearson = Step9C.Model.LSBoost.Pearson;
LS_Spearman = Step9C.Model.LSBoost.Spearman;

%% Model improvement

R2Improvement = Step9C.Model.R2Improvement;

RMSEReduction = Step9C.Model.RMSEReductionPercent;

MAEReduction = Step9C.Model.MAEReductionPercent;

%% XAI

SHAP_Spearman = Step9C.XAI.SHAP_Spearman;
SHAP_Pearson = Step9C.XAI.SHAP_Pearson;

R1R2_SHAP = Step9C.XAI.R1R2_SHAP_Interaction;

R1R2_SPICE_Pearson = ...
    Step9C.XAI.R1R2_SPICE_Pearson;

R1R2_SPICE_Spearman = ...
    Step9C.XAI.R1R2_SPICE_Spearman;

%% Optimization

Cases = string(Step9C.Optimization.Cases);

baselineSPICE = ...
    Step9C.Optimization.BaselineSPICEGain_dB;

baselineDL = ...
    Step9C.Optimization.BaselineDLGain_dB;

finalDL = ...
    Step9C.Optimization.FinalDLGain_dB;

finalSPICE = ...
    Step9C.Optimization.FinalSPICEGain_dB;

predictedImprovement = ...
    Step9C.Optimization.PredictedImprovement_dB;

actualImprovement = ...
    Step9C.Optimization.ActualImprovement_dB;

finalVCE = ...
    Step9C.Optimization.FinalVCE_V;

finalVCB = ...
    Step9C.Optimization.FinalVCB_V;

physicalValid = ...
    Step9C.Optimization.PhysicalValid;

constraintValid = ...
    Step9C.Optimization.ConstraintValid;

%% Robustness

robustnessRuns = ...
    Step9C.Robustness.SimulationCount;

robustnessValidity = ...
    Step9C.Robustness.ValidityPercent;

robustnessSTD = ...
    Step9C.Robustness.StdGain_dB;

robustnessCV = ...
    Step9C.Robustness.CV_Percent;

%% Generalization

generalizationError = ...
    Step9C.Generalization.Error_dB;

generalizationAbsError = ...
    Step9C.Generalization.AbsoluteError_dB;

generalizationDistance = ...
    Step9C.Generalization.DLSpaceDistance;

generalizationMaxZ = ...
    Step9C.Generalization.MaxAbsZ;

generalizationMeanZ = ...
    Step9C.Generalization.MeanAbsZ;

%% Limitation

highPredictedImprovement = ...
    Step9C.Optimization.PredictedImprovement_dB(3);

highActualImprovement = ...
    Step9C.Optimization.ActualImprovement_dB(3);

%% ========================================================================
% 7. RESULT VALIDATION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('4. RESULT VALIDATION\n');
fprintf('---------------------------------------------------------------\n');

assert(datasetRows == 660, ...
    'Expected 660 dataset rows.');

assert(numel(Cases) == 3, ...
    'Expected three optimization cases.');

assert(all(physicalValid), ...
    'Not all final designs are physically valid.');

assert(all(constraintValid), ...
    'Not all final designs satisfy circuit constraints.');

assert(robustnessRuns == 300, ...
    'Expected 300 robustness simulations.');

assert(min(robustnessValidity) == 100, ...
    'Expected 100 percent robustness physical validity.');

fprintf('Dataset size                 : PASS\n');
fprintf('Final physical validity      : PASS\n');
fprintf('Final circuit constraints    : PASS\n');
fprintf('Robustness validation        : PASS\n');

%% ========================================================================
% 8. RESEARCH CONTRIBUTIONS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('5. RESEARCH CONTRIBUTION EXTRACTION\n');
fprintf('---------------------------------------------------------------\n');

ContributionID = {
    'CON01'
    'CON02'
    'CON03'
    'CON04'
    'CON05'
    'CON06'
    };

Contribution = {
    'Physics-grounded surrogate modeling'
    'Deep-learning-based circuit gain prediction'
    'Explainable circuit-parameter analysis'
    'Surrogate-assisted circuit optimization'
    'Circuit-aware SPICE validation and robustness analysis'
    'Explicit identification of surrogate limitations'
    };

ContributionEvidence = {
    sprintf( ...
        '%d physically valid CE amplifier circuits used as the canonical dataset.', ...
        datasetRows)

    sprintf( ...
        'DL achieved R2=%.4f and RMSE=%.4f dB on the held-out test set.', ...
        DL_R2,DL_RMSE)

    sprintf( ...
        'Global SHAP rank agreement between DL and LSBoost: Spearman=%.4f.', ...
        SHAP_Spearman)

    sprintf( ...
        'SPICE-verified improvement of +%.4f dB and +%.4f dB for Low and Medium cases.', ...
        actualImprovement(1),actualImprovement(2))

    sprintf( ...
        '%d SPICE robustness simulations with %.1f%% physical validity.', ...
        robustnessRuns,min(robustnessValidity))

    sprintf( ...
        'High-gain DL prediction %+0.4f dB versus SPICE %+0.4f dB.', ...
        highPredictedImprovement,highActualImprovement)
    };

ContributionStatus = {
    'DEMONSTRATED'
    'DEMONSTRATED'
    'DEMONSTRATED'
    'DEMONSTRATED_FOR_REPRESENTATIVE_CASES'
    'DEMONSTRATED_WITHIN_TESTED_RANGE'
    'DEMONSTRATED'
    };

ContributionID = string(ContributionID);
Contribution = string(Contribution);
ContributionEvidence = string(ContributionEvidence);
ContributionStatus = string(ContributionStatus);

ContributionTable = table( ...
    ContributionID, ...
    Contribution, ...
    ContributionEvidence, ...
    ContributionStatus);

contributionCSV = fullfile( ...
    outputDir, ...
    'Step9D_Research_Contributions.csv');

writetable(ContributionTable,contributionCSV);

fprintf('Saved:\n%s\n',contributionCSV);

%% ========================================================================
% 9. METHODOLOGY SYNTHESIS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('6. METHODOLOGY SYNTHESIS\n');
fprintf('---------------------------------------------------------------\n');

MethodSection = {
    'Problem formulation'
    'Dataset generation'
    'Physical validation'
    'Machine learning'
    'Explainable AI'
    'Optimization'
    'Circuit-aware validation'
    'Robustness'
    'Generalization'
    };

MethodDescription = {
    ['The research addresses explainable surrogate modeling and ', ...
     'design optimization of a Common-Emitter BJT amplifier. ', ...
     'The objective is not to replace SPICE, but to create a ', ...
     'data-driven assistant that learns relationships between ', ...
     'circuit parameters and amplifier gain.']

    ['The canonical dataset contains 660 physically valid circuit ', ...
     'configurations. The nine design variables are R1, R2, RC, ', ...
     'RE, RL, Cin, Cout, Ce and VCC, with Gain_dB as the prediction target.']

    ['Each canonical circuit was evaluated using SPICE. Operating ', ...
     'point quantities including VCE and VCB were extracted and ', ...
     'used to establish circuit-aware validity criteria.']

    ['A classical LSBoost ensemble was used as the baseline model. ', ...
     'A feed-forward deep neural network was then trained using ', ...
     'the same canonical feature space and evaluated using a fixed ', ...
     'held-out test set and five-fold cross-validation.']

    ['MATLAB SHAP analysis was used to quantify the contribution of ', ...
     'individual circuit parameters to surrogate predictions. ', ...
     'SHAP interaction analysis was further used to identify ', ...
     'important parameter interactions.']

    ['The trained DL surrogate was embedded in constrained ', ...
     'optimization to generate candidate amplifier designs. ', ...
     'Optimization variables remained within dataset-derived bounds.']

    ['Candidate designs were verified using SPICE. The selected ', ...
     'operating-point constraints were VCE >= 1.0 V and VCB >= 0.5 V. ', ...
     'SPICE remained the final physical authority.']

    ['Robustness was evaluated using 300 tolerance-perturbed SPICE ', ...
     'simulations involving the specified resistor, capacitor and ', ...
     'supply-voltage variations.']

    ['Optimization generalization was evaluated by comparing DL ', ...
     'predictions against SPICE results and by examining transformed ', ...
     'feature-space distance and standardized feature deviations.']
    };

MethodSection = string(MethodSection);
MethodDescription = string(MethodDescription);

MethodologyTable = table( ...
    MethodSection, ...
    MethodDescription);

methodologyCSV = fullfile( ...
    outputDir, ...
    'Step9D_Methodology_Synthesis.csv');

writetable(MethodologyTable,methodologyCSV);

fprintf('Saved:\n%s\n',methodologyCSV);

%% ========================================================================
% 10. RESULTS SYNTHESIS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('7. RESULTS SYNTHESIS\n');
fprintf('---------------------------------------------------------------\n');

ResultID = {
    'R01'
    'R02'
    'R03'
    'R04'
    'R05'
    'R06'
    'R07'
    'R08'
    };

ResultTopic = {
    'Dataset'
    'DL performance'
    'Baseline comparison'
    'Cross-validation'
    'Explainability'
    'Optimization'
    'Robustness'
    'Generalization'
    };

ResultStatement = {
    sprintf( ...
        'The validated dataset contains %d physically valid circuits with gain ranging from %.3f to %.3f dB.', ...
        datasetRows,gainMin,gainMax)

    sprintf( ...
        'The DL model achieved R2=%.4f, RMSE=%.4f dB and MAE=%.4f dB on the held-out test set.', ...
        DL_R2,DL_RMSE,DL_MAE)

    sprintf( ...
        'Compared with LSBoost, the DL model improved R2 by %.4f, reduced RMSE by %.2f%% and reduced MAE by %.2f%%.', ...
        R2Improvement,RMSEReduction,MAEReduction)

    sprintf( ...
        'Five-fold cross-validation produced a DL mean R2 of %.4f +/- %.4f.', ...
        DL_CV_R2,DL_CV_R2_STD)

    sprintf( ...
        'Global SHAP rankings showed strong agreement between DL and LSBoost, with Spearman correlation %.4f.', ...
        SHAP_Spearman)

    sprintf( ...
        'SPICE verification produced actual gain improvements of %+0.4f dB, %+0.4f dB and %+0.4f dB for Low, Medium and High cases.', ...
        actualImprovement(1),actualImprovement(2),actualImprovement(3))

    sprintf( ...
        '%d tolerance-perturbed SPICE simulations remained physically valid, corresponding to %.1f%% validity.', ...
        robustnessRuns,min(robustnessValidity))

    sprintf( ...
        'Optimization prediction errors were %.4f, %.4f and %.4f dB for Low, Medium and High cases.', ...
        generalizationAbsError(1), ...
        generalizationAbsError(2), ...
        generalizationAbsError(3))
    };

ResultInterpretation = {
    'The dataset provides the physical basis for surrogate modeling.'
    
    'The DL model provides useful predictive accuracy for the investigated CE amplifier dataset.'
    
    'The DL model provides a stronger predictive result than the selected classical baseline.'
    
    'The cross-validation result supports model stability across data partitions.'
    
    'The XAI results provide an interpretable ranking of influential circuit variables.'
    
    'Optimization is effective for the tested Low and Medium representative cases, but not universally successful.'
    
    'The optimized candidates remained physically valid under the specified robustness experiment.'
    
    'The generalization analysis demonstrates that surrogate error must be considered during optimization.'
    };

ResultID = string(ResultID);
ResultTopic = string(ResultTopic);
ResultStatement = string(ResultStatement);
ResultInterpretation = string(ResultInterpretation);

ResultsTable = table( ...
    ResultID, ...
    ResultTopic, ...
    ResultStatement, ...
    ResultInterpretation);

resultsCSV = fullfile( ...
    outputDir, ...
    'Step9D_Results_Synthesis.csv');

writetable(ResultsTable,resultsCSV);

fprintf('Saved:\n%s\n',resultsCSV);

%% ========================================================================
% 11. XAI DISCUSSION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('8. XAI INTERPRETATION\n');
fprintf('---------------------------------------------------------------\n');

XAI_Rank = Step9C.XAI.FeatureTable;

XAI_FeatureNames = string(XAI_Rank.Feature);

XAI_DL = XAI_Rank.DL_MeanAbsSHAP;

[~,idx] = sort(XAI_DL,'descend');

XAI_FeatureNames = XAI_FeatureNames(idx);
XAI_DL = XAI_DL(idx);

XAI_Description = {
    'Global feature importance'
    'Dominant DC variables'
    'Supply influence'
    'Load influence'
    'Capacitive variables'
    'Interaction analysis'
    'Physical interpretation boundary'
    };

XAI_Statement = {
    sprintf( ...
        'The DL SHAP analysis ranks %s as the most influential variable.', ...
        XAI_FeatureNames(1))

    ['R1, R2, RE and RC occupy the dominant portion of the global ', ...
     'feature-importance ranking.']

    ['VCC contributes materially to the learned gain prediction, ', ...
     'consistent with its position among the dominant features.']

    ['RL has lower global importance than the dominant bias and ', ...
     'collector/emitter resistance variables but remains relevant.']

    ['Cin, Cout and Ce have substantially smaller global Mean|SHAP| ', ...
     'values than the dominant variables in the learned surrogate.']

    sprintf( ...
        'The R1-R2 SHAP interaction value is %.4f and the corresponding SPICE validation has Pearson correlation %.4f.', ...
        R1R2_SHAP,R1R2_SPICE_Pearson)

    ['SHAP values explain the surrogate model and should not be ', ...
     'interpreted as direct physical sensitivity coefficients. ', ...
     'SPICE validation provides the physical interpretation check.']
    };

XAI_Description = string(XAI_Description);
XAI_Statement = string(XAI_Statement);

XAI_DiscussionTable = table( ...
    XAI_Description, ...
    XAI_Statement);

xaiDiscussionCSV = fullfile( ...
    outputDir, ...
    'Step9D_XAI_Discussion.csv');

writetable(XAI_DiscussionTable,xaiDiscussionCSV);

fprintf('Saved:\n%s\n',xaiDiscussionCSV);

%% ========================================================================
% 12. OPTIMIZATION DISCUSSION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('9. OPTIMIZATION DISCUSSION\n');
fprintf('---------------------------------------------------------------\n');

OptimizationDiscussion = {
    'Low-gain case'
    'Medium-gain case'
    'High-gain case'
    'Circuit-aware validation'
    'Overall interpretation'
    };

OptimizationStatement = {
    sprintf( ...
        'The Low case improved from %.4f dB baseline SPICE gain to %.4f dB after optimization, an actual improvement of %+0.4f dB.', ...
        baselineSPICE(1),finalSPICE(1),actualImprovement(1))

    sprintf( ...
        'The Medium case improved from %.4f dB baseline SPICE gain to %.4f dB after optimization, an actual improvement of %+0.4f dB.', ...
        baselineSPICE(2),finalSPICE(2),actualImprovement(2))

    sprintf( ...
        'The High case illustrates surrogate error: DL predicted %+0.4f dB improvement while SPICE measured %+0.4f dB.', ...
        predictedImprovement(3),actualImprovement(3))

    sprintf( ...
        'All three final candidates satisfy VCE >= %.1f V and VCB >= %.1f V according to final SPICE verification.', ...
        VCE_LIMIT,VCB_LIMIT)

    ['The results support surrogate-assisted optimization rather than ', ...
     'fully autonomous optimization. Candidate designs must remain ', ...
     'subject to physical SPICE verification.']
    };

OptimizationDiscussion = string(OptimizationDiscussion);
OptimizationStatement = string(OptimizationStatement);

OptimizationDiscussionTable = table( ...
    OptimizationDiscussion, ...
    OptimizationStatement);

optimizationDiscussionCSV = fullfile( ...
    outputDir, ...
    'Step9D_Optimization_Discussion.csv');

writetable( ...
    OptimizationDiscussionTable, ...
    optimizationDiscussionCSV);

fprintf('Saved:\n%s\n',optimizationDiscussionCSV);

%% ========================================================================
% 13. ROBUSTNESS DISCUSSION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('10. ROBUSTNESS DISCUSSION\n');
fprintf('---------------------------------------------------------------\n');

RobustnessDiscussion = {
    'Experimental scope'
    'Physical validity'
    'Low case'
    'Medium case'
    'High case'
    'Interpretation'
    };

RobustnessStatement = {
    sprintf( ...
        '%d SPICE simulations were performed using the specified tolerance perturbations.', ...
        robustnessRuns)

    sprintf( ...
        'All tested tolerance-perturbed simulations remained physically valid (%.1f%%).', ...
        min(robustnessValidity))

    sprintf( ...
        'Low-case gain standard deviation was %.4f dB with CV %.3f%%.', ...
        robustnessSTD(1),robustnessCV(1))

    sprintf( ...
        'Medium-case gain standard deviation was %.4f dB with CV %.3f%%.', ...
        robustnessSTD(2),robustnessCV(2))

    sprintf( ...
        'High-case gain standard deviation was %.4f dB with CV %.3f%%.', ...
        robustnessSTD(3),robustnessCV(3))

    ['The robustness result demonstrates stability within the tested ', ...
     'tolerance ranges; it should not be generalized beyond those ', ...
     'specified perturbation ranges.']
    };

RobustnessDiscussion = string(RobustnessDiscussion);
RobustnessStatement = string(RobustnessStatement);

RobustnessDiscussionTable = table( ...
    RobustnessDiscussion, ...
    RobustnessStatement);

robustnessDiscussionCSV = fullfile( ...
    outputDir, ...
    'Step9D_Robustness_Discussion.csv');

writetable( ...
    RobustnessDiscussionTable, ...
    robustnessDiscussionCSV);

fprintf('Saved:\n%s\n',robustnessDiscussionCSV);

%% ========================================================================
% 14. LIMITATIONS
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('11. RESEARCH LIMITATIONS\n');
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
    'Surrogate prediction error'
    'High-gain optimization failure'
    'Limited optimization cases'
    'Single circuit topology'
    'Finite robustness range'
    'SHAP physical interpretation boundary'
    };

LimitationStatement = {
    sprintf( ...
        'Optimization prediction errors reached %.4f dB in the tested cases.', ...
        max(generalizationAbsError))

    sprintf( ...
        'The High case produced %+0.4f dB SPICE improvement despite a predicted improvement of %+0.4f dB.', ...
        highActualImprovement,highPredictedImprovement)

    ['Optimization was evaluated using Low, Medium and High ', ...
     'representative cases rather than exhaustive optimization of ', ...
     'the complete design space.']

    ['The validated dataset and experiments concern a Common-Emitter ', ...
     'BJT amplifier and should not automatically be generalized to ', ...
     'other circuit topologies.']

    sprintf( ...
        'Robustness was evaluated using %d specified tolerance-perturbed SPICE runs.', ...
        robustnessRuns)

    ['SHAP explains the surrogate model. SHAP importance should not ', ...
     'be directly equated with a physical sensitivity coefficient.']
    };

LimitationID = string(LimitationID);
Limitation = string(Limitation);
LimitationStatement = string(LimitationStatement);

LimitationsTable = table( ...
    LimitationID, ...
    Limitation, ...
    LimitationStatement);

limitationsCSV = fullfile( ...
    outputDir, ...
    'Step9D_Final_Limitations.csv');

writetable(LimitationsTable,limitationsCSV);

fprintf('Saved:\n%s\n',limitationsCSV);

%% ========================================================================
% 15. CONTRIBUTION / NOVELTY FRAMING
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('12. CONTRIBUTION AND NOVELTY FRAMING\n');
fprintf('---------------------------------------------------------------\n');

NoveltyArea = {
    'Integrated framework'
    'Physics-grounded learning'
    'Explainability'
    'Circuit-aware optimization'
    'Physical verification'
    'Robustness'
    };

NoveltyStatement = {
    ['An integrated workflow connects SPICE-based circuit generation, ', ...
     'surrogate modeling, XAI, constrained optimization, SPICE ', ...
     'verification and robustness analysis in a single pipeline.']

    ['The approach explicitly retains SPICE as physical ground truth ', ...
     'rather than treating the learned model as a replacement for ', ...
     'circuit simulation.']

    ['The framework links global SHAP explanations and parameter ', ...
     'interaction analysis with direct SPICE validation.']

    ['Optimization is constrained using circuit operating-point ', ...
     'criteria derived from actual SPICE operating-point data.']

    ['Every final optimization candidate is checked against the ', ...
     'physical circuit simulator before being treated as a valid ', ...
     'design result.']

    ['The workflow evaluates not only nominal optimization results ', ...
     'but also tolerance-perturbed physical validity.']
    };

NoveltyQualification = {
    'Framework-level contribution'
    'Methodological contribution'
    'Explainability contribution'
    'Optimization methodology'
    'Validation methodology'
    'Robustness methodology'
    };

NoveltyArea = string(NoveltyArea);
NoveltyStatement = string(NoveltyStatement);
NoveltyQualification = string(NoveltyQualification);

NoveltyTable = table( ...
    NoveltyArea, ...
    NoveltyStatement, ...
    NoveltyQualification);

noveltyCSV = fullfile( ...
    outputDir, ...
    'Step9D_Contribution_and_Novelty.csv');

writetable(NoveltyTable,noveltyCSV);

fprintf('Saved:\n%s\n',noveltyCSV);

%% ========================================================================
% 16. CLAIM-SAFE CONCLUSION
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('13. CLAIM-SAFE RESEARCH CONCLUSION\n');
fprintf('---------------------------------------------------------------\n');

ConclusionParagraph = sprintf([ ...
    'This research developed an explainable surrogate-assisted ', ...
    'framework for understanding and optimizing a Common-Emitter ', ...
    'BJT amplifier. The framework was constructed around SPICE as ', ...
    'the physical ground truth and used machine learning and deep ', ...
    'learning models as computational surrogates. On a canonical ', ...
    'dataset of %d physically valid circuit configurations, the ', ...
    'deep-learning model achieved a held-out test R2 of %.4f, ', ...
    'RMSE of %.4f dB and MAE of %.4f dB. Five-fold cross-validation ', ...
    'produced an R2 of %.4f +/- %.4f, supporting the stability of ', ...
    'the learned surrogate on the investigated dataset.'], ...
    datasetRows, ...
    DL_R2, ...
    DL_RMSE, ...
    DL_MAE, ...
    DL_CV_R2, ...
    DL_CV_R2_STD);

ConclusionParagraph2 = sprintf([ ...
    'Explainability analysis showed strong agreement between the ', ...
    'global feature rankings of the deep-learning and LSBoost models, ', ...
    'with a SHAP rank Spearman correlation of %.4f. The R1-R2 ', ...
    'interaction was identified as an important learned interaction ', ...
    'and was further examined using direct SPICE sweeps. This ', ...
    'establishes a link between model-level explanation and physical ', ...
    'circuit validation without equating SHAP values with physical ', ...
    'sensitivity coefficients.'], ...
    SHAP_Spearman);

ConclusionParagraph3 = sprintf([ ...
    'The surrogate-assisted optimization stage produced positive ', ...
    'SPICE-verified improvements of %+0.4f dB and %+0.4f dB for the ', ...
    'Low and Medium representative cases, respectively. The High ', ...
    'case, however, produced a SPICE change of %+0.4f dB despite a ', ...
    'predicted improvement of %+0.4f dB. This result is a critical ', ...
    'limitation and demonstrates why the learned surrogate cannot be ', ...
    'treated as a replacement for physical circuit simulation.'], ...
    actualImprovement(1), ...
    actualImprovement(2), ...
    highActualImprovement, ...
    highPredictedImprovement);

ConclusionParagraph4 = sprintf([ ...
    'All three final candidates satisfied the selected circuit-aware ', ...
    'operating-point constraints of VCE >= %.1f V and VCB >= %.1f V. ', ...
    'Furthermore, %d tolerance-perturbed SPICE simulations remained ', ...
    'physically valid. Therefore, the results support the framework ', ...
    'as a physics-grounded, explainable and surrogate-assisted ', ...
    'design methodology for the investigated Common-Emitter amplifier, ', ...
    'while also establishing clear boundaries on its predictive and ', ...
    'optimization generalization.'], ...
    VCE_LIMIT, ...
    VCB_LIMIT, ...
    robustnessRuns);

% IMPORTANT:
% Four conclusion paragraphs are stored inside ONE table row.
% Therefore height(ConclusionTable) == 1 is intentional.

ConclusionTable = table( ...
    string({'Conclusion'}), ...
    string({sprintf('%s\n\n%s\n\n%s\n\n%s', ...
        ConclusionParagraph, ...
        ConclusionParagraph2, ...
        ConclusionParagraph3, ...
        ConclusionParagraph4)}), ...
    'VariableNames', ...
    {'Section','Text'});

conclusionCSV = fullfile( ...
    outputDir, ...
    'Step9D_Claim_Safe_Conclusion.csv');

writetable(ConclusionTable,conclusionCSV);

fprintf('Saved:\n%s\n',conclusionCSV);

%% ========================================================================
% 17. GENERATE REPORT TXT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('14. GENERATING THESIS/PAPER-READY REPORT\n');
fprintf('---------------------------------------------------------------\n');

reportTXT = fullfile( ...
    outputDir, ...
    'Step9D_Final_Research_Report.txt');

fid = fopen(reportTXT,'w');

if fid == -1

    error( ...
        'Step9D:ReportFile', ...
        'Could not create final research report.');

end

fprintf(fid,'===============================================================\n');
fprintf(fid,'FINAL RESEARCH REPORT\n');
fprintf(fid,'Explainable AI Framework for Electronic Circuit Understanding\n');
fprintf(fid,'and Design Optimization\n');
fprintf(fid,'Common-Emitter BJT Amplifier\n');
fprintf(fid,'===============================================================\n\n');

fprintf(fid,'1. RESEARCH OBJECTIVE\n\n');

fprintf(fid,'%s\n\n', ...
    ['The objective of this research is to develop an explainable, ', ...
     'physics-grounded surrogate framework for understanding and ', ...
     'optimizing an electronic circuit. The framework learns ', ...
     'relationships between circuit design parameters and amplifier ', ...
     'gain while retaining SPICE as the physical ground truth.']);

fprintf(fid,'2. METHODOLOGY\n\n');

for k = 1:height(MethodologyTable)

    fprintf(fid,'%s:\n%s\n\n', ...
        MethodologyTable.MethodSection(k), ...
        MethodologyTable.MethodDescription(k));

end

fprintf(fid,'3. DATASET\n\n');

fprintf(fid, ...
    'The canonical dataset contains %d physically valid circuit configurations with %d columns. The investigated gain range is %.3f to %.3f dB.\n\n', ...
    datasetRows,datasetCols,gainMin,gainMax);

fprintf(fid,'4. MODEL PERFORMANCE\n\n');

fprintf(fid, ...
    'The deep-learning model achieved R2=%.4f, RMSE=%.4f dB and MAE=%.4f dB on the held-out test set. The corresponding Pearson and Spearman correlations were %.4f and %.4f.\n\n', ...
    DL_R2,DL_RMSE,DL_MAE,DL_Pearson,DL_Spearman);

fprintf(fid, ...
    'Five-fold cross-validation produced R2=%.4f +/- %.4f.\n\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf(fid, ...
    'Compared with LSBoost, the DL model improved R2 by %.4f, reduced RMSE by %.2f%% and reduced MAE by %.2f%%.\n\n', ...
    R2Improvement,RMSEReduction,MAEReduction);

fprintf(fid,'5. EXPLAINABLE AI\n\n');

fprintf(fid, ...
    'The DL and LSBoost global SHAP rankings showed a Spearman correlation of %.4f and Pearson correlation of %.4f. The R1-R2 interaction had a SHAP interaction value of %.4f and was further examined using SPICE validation.\n\n', ...
    SHAP_Spearman,SHAP_Pearson,R1R2_SHAP);

fprintf(fid,'6. OPTIMIZATION\n\n');

fprintf(fid, ...
    'The Low case improved by %+0.4f dB according to SPICE.\n', ...
    actualImprovement(1));

fprintf(fid, ...
    'The Medium case improved by %+0.4f dB according to SPICE.\n', ...
    actualImprovement(2));

fprintf(fid, ...
    'The High case changed by %+0.4f dB according to SPICE, despite a predicted improvement of %+0.4f dB.\n\n', ...
    highActualImprovement,highPredictedImprovement);

fprintf(fid,'7. CIRCUIT-AWARE VALIDATION\n\n');

fprintf(fid, ...
    'All three final designs satisfied VCE >= %.1f V and VCB >= %.1f V and were physically valid according to SPICE verification.\n\n', ...
    VCE_LIMIT,VCB_LIMIT);

fprintf(fid,'8. ROBUSTNESS\n\n');

fprintf(fid, ...
    '%d tolerance-perturbed SPICE simulations were performed. All tested simulations remained physically valid. The robustness result is limited to the specified perturbation ranges.\n\n', ...
    robustnessRuns);

fprintf(fid,'9. GENERALIZATION AND LIMITATIONS\n\n');

fprintf(fid, ...
    'The optimization prediction errors were %.4f, %.4f and %.4f dB for the Low, Medium and High cases, respectively.\n\n', ...
    generalizationAbsError(1), ...
    generalizationAbsError(2), ...
    generalizationAbsError(3));

fprintf(fid, ...
    'The High case demonstrates an important limitation: the surrogate predicted %+0.4f dB improvement while SPICE measured %+0.4f dB. Consequently, the learned model should be regarded as a surrogate and candidate-generation mechanism rather than a replacement for physical circuit simulation.\n\n', ...
    highPredictedImprovement,highActualImprovement);

fprintf(fid,'10. CONTRIBUTION\n\n');

fprintf(fid, ...
    ['The principal contribution is an integrated framework connecting ', ...
     'physics-grounded circuit data generation, surrogate modeling, ', ...
     'explainability, constrained optimization, direct SPICE ', ...
     'verification and robustness evaluation. The framework explicitly ', ...
     'preserves the distinction between learned model behavior and ', ...
     'physical circuit behavior.\n\n']);

fprintf(fid,'11. CONCLUSION\n\n');

fprintf(fid,'%s\n\n',ConclusionParagraph);
fprintf(fid,'%s\n\n',ConclusionParagraph2);
fprintf(fid,'%s\n\n',ConclusionParagraph3);
fprintf(fid,'%s\n\n',ConclusionParagraph4);

fprintf(fid,'===============================================================\n');
fprintf(fid,'END OF REPORT\n');
fprintf(fid,'===============================================================\n');

fclose(fid);

fprintf('Saved:\n%s\n',reportTXT);

%% ========================================================================
% 18. EXECUTIVE SUMMARY
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('15. GENERATING EXECUTIVE SUMMARY\n');
fprintf('---------------------------------------------------------------\n');

executiveTXT = fullfile( ...
    outputDir, ...
    'Step9D_Executive_Summary.txt');

fid = fopen(executiveTXT,'w');

fprintf(fid,'FINAL RESEARCH EXECUTIVE SUMMARY\n');
fprintf(fid,'================================\n\n');

fprintf(fid, ...
    'Dataset: %d physically valid CE amplifier circuits.\n', ...
    datasetRows);

fprintf(fid, ...
    'DL test R2: %.4f.\n',DL_R2);

fprintf(fid, ...
    'DL test RMSE: %.4f dB.\n',DL_RMSE);

fprintf(fid, ...
    'DL 5-fold CV R2: %.4f +/- %.4f.\n', ...
    DL_CV_R2,DL_CV_R2_STD);

fprintf(fid, ...
    'DL versus LSBoost R2 improvement: +%.4f.\n', ...
    R2Improvement);

fprintf(fid, ...
    'SHAP rank Spearman: %.4f.\n', ...
    SHAP_Spearman);

fprintf(fid, ...
    'R1-R2 SHAP interaction: %.4f.\n', ...
    R1R2_SHAP);

fprintf(fid, ...
    'Low SPICE improvement: %+0.4f dB.\n', ...
    actualImprovement(1));

fprintf(fid, ...
    'Medium SPICE improvement: %+0.4f dB.\n', ...
    actualImprovement(2));

fprintf(fid, ...
    'High SPICE improvement: %+0.4f dB.\n', ...
    actualImprovement(3));

fprintf(fid, ...
    'Robustness simulations: %d.\n', ...
    robustnessRuns);

fprintf(fid, ...
    'Robustness physical validity: %.1f%%.\n', ...
    min(robustnessValidity));

fprintf(fid, ...
    'Final physical validity: %d/3.\n', ...
    sum(physicalValid));

fprintf(fid, ...
    'Final circuit constraint validity: %d/3.\n\n', ...
    sum(constraintValid));

fprintf(fid, ...
    'Critical limitation: DL predicted %+0.4f dB for the High case while SPICE measured %+0.4f dB.\n\n', ...
    highPredictedImprovement,highActualImprovement);

fprintf(fid, ...
    'Scientific conclusion: the framework is best characterized as a physics-grounded, explainable, surrogate-assisted circuit design methodology in which SPICE remains the final physical authority.\n');

fclose(fid);

fprintf('Saved:\n%s\n',executiveTXT);

%% ========================================================================
% 19. MASTER STEP 9D STRUCTURE
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('16. CREATING MASTER STEP 9D STRUCTURE\n');
fprintf('---------------------------------------------------------------\n');

Step9D = struct();

%% Core validated data

Step9D.Dataset = Step9C.Dataset;

Step9D.Model = Step9C.Model;

Step9D.XAI = Step9C.XAI;

Step9D.Optimization = Step9C.Optimization;

Step9D.Robustness = Step9C.Robustness;

Step9D.Generalization = Step9C.Generalization;

%% Research synthesis

Step9D.Contributions = ContributionTable;

Step9D.Methodology = MethodologyTable;

Step9D.Results = ResultsTable;

Step9D.XAI_Discussion = XAI_DiscussionTable;

Step9D.Optimization_Discussion = ...
    OptimizationDiscussionTable;

Step9D.Robustness_Discussion = ...
    RobustnessDiscussionTable;

Step9D.Limitations = LimitationsTable;

Step9D.Novelty = NoveltyTable;

Step9D.Conclusion = ConclusionTable;

%% Evidence

Step9D.Evidence = EvidenceTable;

%% Output paths

Step9D.Outputs = struct();

Step9D.Outputs.ContributionCSV = contributionCSV;

Step9D.Outputs.MethodologyCSV = methodologyCSV;

Step9D.Outputs.ResultsCSV = resultsCSV;

Step9D.Outputs.XAIDiscussionCSV = ...
    xaiDiscussionCSV;

Step9D.Outputs.OptimizationDiscussionCSV = ...
    optimizationDiscussionCSV;

Step9D.Outputs.RobustnessDiscussionCSV = ...
    robustnessDiscussionCSV;

Step9D.Outputs.LimitationsCSV = limitationsCSV;

Step9D.Outputs.NoveltyCSV = noveltyCSV;

Step9D.Outputs.ConclusionCSV = conclusionCSV;

Step9D.Outputs.ReportTXT = reportTXT;

Step9D.Outputs.ExecutiveSummaryTXT = ...
    executiveTXT;

Step9D.Outputs.SourceSummaryTXT = ...
    step9CSummaryTXT;

%% Provenance

Step9D.Provenance = struct();

Step9D.Provenance.Step9CMaster = step9CMAT;

Step9D.Provenance.OutputDirectory = outputDir;

Step9D.Provenance.GeneratedBy = ...
    'step9d_final_research_report.m';

Step9D.Provenance.Timestamp = datetime('now');

%% ========================================================================
% 20. SAVE MASTER MAT
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('17. SAVING MASTER STEP 9D MAT\n');
fprintf('---------------------------------------------------------------\n');

masterMAT = fullfile( ...
    outputDir, ...
    'Step9D_Final_Research_Report.mat');

save( ...
    masterMAT, ...
    'Step9D', ...
    'ContributionTable', ...
    'MethodologyTable', ...
    'ResultsTable', ...
    'XAI_DiscussionTable', ...
    'OptimizationDiscussionTable', ...
    'RobustnessDiscussionTable', ...
    'LimitationsTable', ...
    'NoveltyTable', ...
    'ConclusionTable', ...
    '-v7.3');

fprintf('Saved:\n%s\n',masterMAT);

%% ========================================================================
% 21. OUTPUT CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('18. FINAL OUTPUT FILE CHECK\n');
fprintf('---------------------------------------------------------------\n');

outputNames = {
    'Step9D_Research_Contributions.csv'
    'Step9D_Methodology_Synthesis.csv'
    'Step9D_Results_Synthesis.csv'
    'Step9D_XAI_Discussion.csv'
    'Step9D_Optimization_Discussion.csv'
    'Step9D_Robustness_Discussion.csv'
    'Step9D_Final_Limitations.csv'
    'Step9D_Contribution_and_Novelty.csv'
    'Step9D_Claim_Safe_Conclusion.csv'
    'Step9D_Final_Research_Report.txt'
    'Step9D_Executive_Summary.txt'
    'Step9D_Final_Research_Report.mat'
    };

outputPaths = {
    contributionCSV
    methodologyCSV
    resultsCSV
    xaiDiscussionCSV
    optimizationDiscussionCSV
    robustnessDiscussionCSV
    limitationsCSV
    noveltyCSV
    conclusionCSV
    reportTXT
    executiveTXT
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

    fprintf('%-48s : %s\n', ...
        outputNames{k}, ...
        statusText);

end

%% ========================================================================
% 22. MASTER STRUCTURE CHECK
% ========================================================================

fprintf('\n---------------------------------------------------------------\n');
fprintf('19. MASTER STRUCTURE VERIFICATION\n');
fprintf('---------------------------------------------------------------\n');

fprintf('\nStep9D top-level fields:\n');
disp(fieldnames(Step9D));

fprintf('\nContribution rows       : %d\n', ...
    height(ContributionTable));

fprintf('Methodology rows        : %d\n', ...
    height(MethodologyTable));

fprintf('Results rows            : %d\n', ...
    height(ResultsTable));

fprintf('XAI discussion rows     : %d\n', ...
    height(XAI_DiscussionTable));

fprintf('Optimization rows       : %d\n', ...
    height(OptimizationDiscussionTable));

fprintf('Robustness rows         : %d\n', ...
    height(RobustnessDiscussionTable));

fprintf('Limitations rows        : %d\n', ...
    height(LimitationsTable));

fprintf('Novelty rows            : %d\n', ...
    height(NoveltyTable));

fprintf('Conclusion sections     : %d\n', ...
    height(ConclusionTable));

%% ========================================================================
% 23. FINAL STATUS
% ========================================================================

fprintf('\n===============================================================\n');
fprintf(' STEP 9D FINAL STATUS\n');
fprintf('===============================================================\n');

% IMPORTANT CORRECTION:
% ConclusionTable intentionally contains ONE row.
% That row contains the four conclusion paragraphs in its Text field.

step9DPass = ...
    all(sourceStatus) && ...
    all(outputStatus) && ...
    height(ContributionTable) == 6 && ...
    height(MethodologyTable) == 9 && ...
    height(ResultsTable) == 8 && ...
    height(XAI_DiscussionTable) == 7 && ...
    height(OptimizationDiscussionTable) == 5 && ...
    height(RobustnessDiscussionTable) == 6 && ...
    height(LimitationsTable) == 6 && ...
    height(NoveltyTable) == 6 && ...
    height(ConclusionTable) == 1;

if step9DPass

    fprintf('\nSTATUS: PASS\n');

else

    fprintf('\nSTATUS: REVIEW REQUIRED\n');

end

fprintf('\nFinal research summary:\n');

fprintf('  Dataset                         : %d circuits\n', ...
    datasetRows);

fprintf('  Gain range                     : %.3f to %.3f dB\n', ...
    gainMin,gainMax);

fprintf('  DL test R2                     : %.4f\n', ...
    DL_R2);

fprintf('  DL test RMSE                   : %.4f dB\n', ...
    DL_RMSE);

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

fprintf( ...
    '  High-gain DL predicted %+0.4f dB, SPICE measured %+0.4f dB.\n', ...
    highPredictedImprovement, ...
    highActualImprovement);

fprintf('\nOutput directory:\n%s\n',outputDir);

fprintf('\n===============================================================\n');
fprintf(' STEP 9D COMPLETE\n');
fprintf('===============================================================\n');
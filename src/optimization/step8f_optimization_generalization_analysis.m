%% STEP 8F - OPTIMIZATION GENERALIZATION / OOD ANALYSIS
%
% Purpose:
%   Analyze whether the circuit-aware optimized designs are close to
%   or outside the distribution represented by the 660-circuit dataset.
%
%   Compare:
%       - DL predicted gain
%       - SPICE verified gain
%       - prediction error
%       - distance from training distribution
%       - feature-wise percentile position
%       - nearest-neighbor distance
%
% This step does NOT perform another optimization.
%
% SPICE remains the physical ground truth.
%
% ================================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8F - OPTIMIZATION GENERALIZATION / OOD ANALYSIS\n');
fprintf('============================================================\n');


%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

dataCSV = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

optimizationResultsFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'Step8E_Circuit_Aware_Optimization_Results.mat');

dlSetupFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_Optimization_Prediction_Setup.mat');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints', ...
    'generalization_analysis');

if ~isfolder(outputDir)
    mkdir(outputDir);
end


%% ============================================================
% CHECK FILES
% ============================================================

fprintf('\n');
fprintf('Checking required files...\n');

requiredFiles = { ...
    dataCSV
    optimizationResultsFile
    dlSetupFile
    };

requiredNames = { ...
    'Canonical dataset'
    'Step 8E optimization results'
    'DL preprocessing setup'
    };

for k = 1:numel(requiredFiles)

    if ~isfile(requiredFiles{k})

        error( ...
            '%s not found:\n%s', ...
            requiredNames{k}, ...
            requiredFiles{k});

    end

    fprintf('[PASS] %s\n',requiredNames{k});

end


%% ============================================================
% LOAD DATASET
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING CANONICAL DATASET\n');
fprintf('============================================================\n');

T = readtable(dataCSV);

featureNames = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

X = T{:,featureNames};
Y = T.Gain_dB;

if height(T) ~= 660

    error( ...
        'Expected 660 rows, found %d.', ...
        height(T));

end

fprintf( ...
    '[PASS] Dataset contains %d circuits.\n', ...
    height(T));


%% ============================================================
% TRANSFORM DATASET INTO MODEL FEATURE SPACE
% ============================================================
%
% This is the space actually seen by the DL model:
%
%       first 8 -> log10
%       VCC     -> linear
%
% Then normalize using the exact development-set statistics.
%
% This makes the distance analysis consistent with the DL model.
%

P = load(dlSetupFile);

if ~isfield(P,'mu') || ~isfield(P,'sigma')

    error( ...
        'mu/sigma not found in DL preprocessing setup.');

end

mu = double(P.mu(:)');
sigma = double(P.sigma(:)');

XModel = X;

XModel(:,1:8) = ...
    log10(XModel(:,1:8));

XNorm = ...
    (XModel - mu) ./ sigma;

fprintf('[PASS] Dataset transformed into DL feature space.\n');


%% ============================================================
% LOAD STEP 8E RESULTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' LOADING STEP 8E RESULTS\n');
fprintf('============================================================\n');

O = load(optimizationResultsFile);

if ~isfield(O,'finalResults')

    error( ...
        'finalResults not found in Step 8E results.');

end

finalResults = O.finalResults;

caseNames = {'Low','Medium','High'};

nCases = numel(caseNames);


%% ============================================================
% EXTRACT OPTIMIZED DESIGNS
% ============================================================

XOpt = zeros(nCases,9);

for k = 1:nCases

    caseName = caseNames{k};

    if ~isfield(finalResults.(caseName),'xOpt')

        error( ...
            'xOpt missing for case %s.', ...
            caseName);

    end

    XOpt(k,:) = ...
        double(finalResults.(caseName).xOpt(:)');

end

fprintf('[PASS] Extracted final Step 8E designs.\n');


%% ============================================================
% EXTRACT DL / SPICE RESULTS
% ============================================================

DLPred = zeros(nCases,1);
SPICEGain = zeros(nCases,1);
PredictionError = zeros(nCases,1);
ActualImprovement = zeros(nCases,1);

for k = 1:nCases

    caseName = caseNames{k};

    DLPred(k) = ...
        finalResults.(caseName).dlPredictedGain;

    SPICEGain(k) = ...
        finalResults.(caseName).actualGain;

    PredictionError(k) = ...
        DLPred(k) - SPICEGain(k);

    ActualImprovement(k) = ...
        finalResults.(caseName).actualImprovement;

end


%% ============================================================
% TRANSFORM OPTIMIZED DESIGNS
% ============================================================

XOptModel = XOpt;

XOptModel(:,1:8) = ...
    log10(XOptModel(:,1:8));

XOptNorm = ...
    (XOptModel - mu) ./ sigma;


%% ============================================================
% FEATURE-WISE PERCENTILES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FEATURE-WISE DATASET PERCENTILES\n');
fprintf('============================================================\n');

percentiles = zeros(nCases,9);

for k = 1:nCases

    for j = 1:9

        percentiles(k,j) = ...
            100 * ...
            mean(X(:,j) <= XOpt(k,j));

    end

end

fprintf('\nPercentile position of optimized designs:\n');

for k = 1:nCases

    fprintf('\n%s:\n',caseNames{k});

    for j = 1:9

        fprintf( ...
            '  %-5s : %7.2f percentile\n', ...
            featureNames{j}, ...
            percentiles(k,j));

    end

end


%% ============================================================
% STANDARDIZED FEATURE EXTREMENESS
% ============================================================
%
% Calculate distance from dataset mean in the DL feature space.
%

featureZ = XNorm;

optimizedZ = XOptNorm;

EuclideanDistance = zeros(nCases,1);
MaxAbsZ = zeros(nCases,1);
MeanAbsZ = zeros(nCases,1);

for k = 1:nCases

    z = optimizedZ(k,:);

    EuclideanDistance(k) = ...
        norm(z,2);

    MaxAbsZ(k) = ...
        max(abs(z));

    MeanAbsZ(k) = ...
        mean(abs(z));

end


%% ============================================================
% NEAREST-NEIGHBOR DISTANCE
% ============================================================
%
% Distance is measured in normalized DL feature space.
%
% Smaller distance:
%       closer to an existing training circuit.
%
% Larger distance:
%       more unusual / potentially OOD.
%

NearestDistance = zeros(nCases,1);
NearestIndex = zeros(nCases,1);

for k = 1:nCases

    differences = ...
        XNorm - optimizedZ(k,:);

    distances = ...
        sqrt(sum(differences.^2,2));

    [NearestDistance(k),NearestIndex(k)] = ...
        min(distances);

end


%% ============================================================
% DATASET NEAREST-NEIGHBOR BASELINE
% ============================================================
%
% Calculate nearest-neighbor distances among the 660 training
% circuits themselves.
%
% This provides context for the optimized-point distances.
%

N = size(XNorm,1);

trainingNN = inf(N,1);

for i = 1:N

    d = ...
        XNorm - XNorm(i,:);

    distances = ...
        sqrt(sum(d.^2,2));

    distances(i) = Inf;

    trainingNN(i) = ...
        min(distances);

end

medianTrainingNN = ...
    median(trainingNN);

meanTrainingNN = ...
    mean(trainingNN);

p95TrainingNN = ...
    prctile(trainingNN,95);

fprintf('\nTraining-set nearest-neighbor statistics:\n');

fprintf( ...
    '  Mean   = %.6f\n', ...
    meanTrainingNN);

fprintf( ...
    '  Median = %.6f\n', ...
    medianTrainingNN);

fprintf( ...
    '  95%%    = %.6f\n', ...
    p95TrainingNN);


%% ============================================================
% RELATIVE NEAREST-NEIGHBOR DISTANCE
% ============================================================

RelativeNN = ...
    NearestDistance ./ medianTrainingNN;


%% ============================================================
% IDENTIFY EXTREME FEATURES
% ============================================================

ExtremeFeatureCount = zeros(nCases,1);

for k = 1:nCases

    % A feature is considered extreme if it lies outside
    % the central 95% interval of the dataset.

    count = 0;

    for j = 1:9

        qLow = ...
            prctile(X(:,j),2.5);

        qHigh = ...
            prctile(X(:,j),97.5);

        if XOpt(k,j) < qLow || ...
                XOpt(k,j) > qHigh

            count = count + 1;

        end

    end

    ExtremeFeatureCount(k) = count;

end


%% ============================================================
% ERROR VS OOD DISTANCE
% ============================================================

AbsPredictionError = ...
    abs(PredictionError);


%% ============================================================
% BUILD GENERALIZATION TABLE
% ============================================================

GeneralizationTable = table( ...
    string(caseNames'), ...
    DLPred, ...
    SPICEGain, ...
    PredictionError, ...
    AbsPredictionError, ...
    ActualImprovement, ...
    EuclideanDistance, ...
    MaxAbsZ, ...
    MeanAbsZ, ...
    NearestDistance, ...
    RelativeNN, ...
    ExtremeFeatureCount, ...
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


%% ============================================================
% ADD FEATURE PERCENTILES
% ============================================================

for j = 1:9

    GeneralizationTable.( ...
        [featureNames{j} '_Percentile']) = ...
        percentiles(:,j);

end


%% ============================================================
% DISPLAY GENERALIZATION RESULTS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' OPTIMIZATION GENERALIZATION RESULTS\n');
fprintf('============================================================\n');

disp(GeneralizationTable);


%% ============================================================
% PRINT INTERPRETATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' INTERPRETATION\n');
fprintf('============================================================\n');

for k = 1:nCases

    fprintf('\n%s:\n',caseNames{k});

    fprintf( ...
        '  DL prediction          = %.6f dB\n', ...
        DLPred(k));

    fprintf( ...
        '  SPICE gain             = %.6f dB\n', ...
        SPICEGain(k));

    fprintf( ...
        '  Prediction error       = %+ .6f dB\n', ...
        PredictionError(k));

    fprintf( ...
        '  Absolute error         = %.6f dB\n', ...
        AbsPredictionError(k));

    fprintf( ...
        '  Actual improvement     = %+ .6f dB\n', ...
        ActualImprovement(k));

    fprintf( ...
        '  DL-space distance      = %.6f\n', ...
        EuclideanDistance(k));

    fprintf( ...
        '  Nearest training dist. = %.6f\n', ...
        NearestDistance(k));

    fprintf( ...
        '  Relative NN distance   = %.3f x median training NN\n', ...
        RelativeNN(k));

    fprintf( ...
        '  Extreme features       = %d / 9\n', ...
        ExtremeFeatureCount(k));

end


%% ============================================================
% ERROR-DISTANCE CORRELATION
% ============================================================
%
% There are only three optimized points.
%
% Therefore this correlation is descriptive only and must NOT
% be treated as a statistical conclusion.
%

if nCases >= 3

    rho = ...
        corr( ...
        EuclideanDistance, ...
        AbsPredictionError, ...
        'Type','Spearman');

    fprintf('\n');
    fprintf( ...
        'Spearman correlation between OOD distance and absolute ', ...
        'prediction error = %.6f\n', ...
        rho);

    fprintf( ...
        'NOTE: only three optimized points are available; this ', ...
        'correlation is descriptive, not statistically conclusive.\n');

else

    rho = NaN;

end


%% ============================================================
% FEATURE-WISE OPTIMIZED DESIGN MOVEMENT
% ============================================================
%
% Compare each optimized point to the nearest training point.
%
% This helps identify which parameters are responsible for the
% optimized point becoming unusual.
%

NearestFeatureMovement = zeros(nCases,9);

for k = 1:nCases

    idx = ...
        NearestIndex(k);

    NearestFeatureMovement(k,:) = ...
        XOpt(k,:) - X(idx,:);

end


%% ============================================================
% PRINT NEAREST TRAINING CIRCUITS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' NEAREST TRAINING CIRCUITS\n');
fprintf('============================================================\n');

for k = 1:nCases

    idx = ...
        NearestIndex(k);

    fprintf('\n%s:\n',caseNames{k});

    fprintf( ...
        '  Nearest dataset row = %d\n', ...
        idx);

    fprintf( ...
        '  Dataset gain        = %.6f dB\n', ...
        Y(idx));

    fprintf( ...
        '  Distance            = %.6f\n', ...
        NearestDistance(k));

end


%% ============================================================
% FIGURE 1 - DL VS SPICE GAIN
% ============================================================

figure;

bar( ...
    [DLPred,SPICEGain]);

grid on;

set(gca, ...
    'XTick',1:3, ...
    'XTickLabel',caseNames);

xlabel('Optimization Case');
ylabel('Gain (dB)');

legend( ...
    {'DL Prediction','SPICE Verification'}, ...
    'Location','best');

title( ...
    'DL-Predicted vs SPICE-Verified Optimized Gain');


saveas( ...
    gcf, ...
    fullfile( ...
    outputDir, ...
    'DL_vs_SPICE_Optimized_Gain.png'));


%% ============================================================
% FIGURE 2 - PREDICTION ERROR
% ============================================================

figure;

bar( ...
    PredictionError);

grid on;

set(gca, ...
    'XTick',1:3, ...
    'XTickLabel',caseNames);

xlabel('Optimization Case');
ylabel('Prediction Error (dB)');

title( ...
    'DL Prediction Error at Optimized Designs');


saveas( ...
    gcf, ...
    fullfile( ...
    outputDir, ...
    'Optimized_Prediction_Error.png'));


%% ============================================================
% FIGURE 3 - NEAREST-NEIGHBOR DISTANCE
% ============================================================

figure;

bar( ...
    [NearestDistance, ...
     repmat(medianTrainingNN,nCases,1)]);

grid on;

set(gca, ...
    'XTick',1:3, ...
    'XTickLabel',caseNames);

xlabel('Optimization Case');
ylabel('Distance in Normalized DL Feature Space');

legend( ...
    {'Optimized Point','Training Median NN'}, ...
    'Location','best');

title( ...
    'Optimized Design Distance from Training Distribution');


saveas( ...
    gcf, ...
    fullfile( ...
    outputDir, ...
    'Optimized_Training_Distance.png'));


%% ============================================================
% FIGURE 4 - ACTUAL IMPROVEMENT
% ============================================================

figure;

bar( ...
    ActualImprovement);

grid on;

set(gca, ...
    'XTick',1:3, ...
    'XTickLabel',caseNames);

xlabel('Optimization Case');
ylabel('Actual Gain Improvement (dB)');

title( ...
    'Actual SPICE Gain Improvement After Optimization');


saveas( ...
    gcf, ...
    fullfile( ...
    outputDir, ...
    'Actual_SPICE_Improvement.png'));


%% ============================================================
% FIGURE 5 - FEATURE PERCENTILE HEATMAP
% ============================================================

figure;

imagesc(percentiles);

colorbar;

set(gca, ...
    'XTick',1:9, ...
    'XTickLabel',featureNames, ...
    'YTick',1:3, ...
    'YTickLabel',caseNames);

xlabel('Circuit Parameter');
ylabel('Optimization Case');

title( ...
    'Optimized Parameter Percentile within 660-Circuit Dataset');


saveas( ...
    gcf, ...
    fullfile( ...
    outputDir, ...
    'Optimized_Feature_Percentiles.png'));


%% ============================================================
% SAVE CSV
% ============================================================

csvFile = fullfile( ...
    outputDir, ...
    'Step8F_Optimization_Generalization.csv');

writetable( ...
    GeneralizationTable, ...
    csvFile);


%% ============================================================
% SAVE FEATURE PERCENTILES
% ============================================================

PercentileTable = ...
    array2table( ...
    percentiles, ...
    'VariableNames',featureNames);

PercentileTable.Case = ...
    string(caseNames');

PercentileTable = ...
    movevars( ...
    PercentileTable, ...
    'Case', ...
    'Before', ...
    1);

percentileCSV = fullfile( ...
    outputDir, ...
    'Step8F_Feature_Percentiles.csv');

writetable( ...
    PercentileTable, ...
    percentileCSV);


%% ============================================================
% SAVE NEAREST-NEIGHBOR INFORMATION
% ============================================================

NNTable = table( ...
    string(caseNames'), ...
    NearestIndex, ...
    Y(NearestIndex), ...
    NearestDistance, ...
    RelativeNN, ...
    'VariableNames',{ ...
    'Case', ...
    'Nearest_Training_Row', ...
    'Nearest_Training_Gain_dB', ...
    'Nearest_Training_Distance', ...
    'Relative_NN_Distance'});

nnCSV = fullfile( ...
    outputDir, ...
    'Step8F_Nearest_Training_Circuits.csv');

writetable( ...
    NNTable, ...
    nnCSV);


%% ============================================================
% SAVE MAT
% ============================================================

matFile = fullfile( ...
    outputDir, ...
    'Step8F_Optimization_Generalization_Results.mat');

save( ...
    matFile, ...
    'featureNames', ...
    'XOpt', ...
    'DLPred', ...
    'SPICEGain', ...
    'PredictionError', ...
    'ActualImprovement', ...
    'percentiles', ...
    'XOptModel', ...
    'XOptNorm', ...
    'EuclideanDistance', ...
    'MaxAbsZ', ...
    'MeanAbsZ', ...
    'NearestDistance', ...
    'NearestIndex', ...
    'trainingNN', ...
    'medianTrainingNN', ...
    'meanTrainingNN', ...
    'p95TrainingNN', ...
    'RelativeNN', ...
    'ExtremeFeatureCount', ...
    'NearestFeatureMovement', ...
    'rho', ...
    'GeneralizationTable', ...
    'NNTable');


%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8F COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nOutput files:\n');

fprintf('%s\n',matFile);
fprintf('%s\n',csvFile);
fprintf('%s\n',percentileCSV);
fprintf('%s\n',nnCSV);

fprintf('\nFigures:\n');

fprintf('  DL_vs_SPICE_Optimized_Gain.png\n');
fprintf('  Optimized_Prediction_Error.png\n');
fprintf('  Optimized_Training_Distance.png\n');
fprintf('  Actual_SPICE_Improvement.png\n');
fprintf('  Optimized_Feature_Percentiles.png\n');

fprintf('\nIMPORTANT:\n');
fprintf(['Only three optimized designs are available, so the ', ...
    'OOD/error relationship is descriptive rather than ', ...
    'statistically conclusive.\n']);

fprintf('\n============================================================\n');


%% ============================================================
% END
% ============================================================
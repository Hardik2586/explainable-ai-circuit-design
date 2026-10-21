%% STEP 4A: XAI -> OPTIMIZATION PARAMETER ANALYSIS
clc;
clear;
close all;

fprintf('\n============================================================\n');
fprintf(' STEP 4A: XAI -> OPTIMIZATION PARAMETER ANALYSIS\n');
fprintf('============================================================\n\n');

projectRoot = 'C:\Internship Project';

%% ============================================================
% LOAD FILES
% =============================================================

setupFile = fullfile(projectRoot, ...
    'results','optimization','Optimization_Setup.mat');

optFile = fullfile(projectRoot, ...
    'results','optimization','DL_fmincon_Optimization_Results.mat');

shapFile = fullfile(projectRoot, ...
    'results','deep_learning','shap','DL_SHAP_Results.mat');

fprintf('Loading optimization setup...\n');
Ssetup = load(setupFile);

fprintf('Loading optimization results...\n');
Sopt = load(optFile);

fprintf('Loading DL SHAP results...\n');
Sshap = load(shapFile);

optimizationSetup = Ssetup.optimizationSetup;
optimizationResults = Sopt.optimizationResults;

%% ============================================================
% FEATURE NAMES
% =============================================================

featureNames = optimizationSetup.featureNames;

if isstring(featureNames)
    featureNames = cellstr(featureNames);
end

fprintf('\nFeatures:\n');
disp(featureNames);

nFeatures = numel(featureNames);

%% ============================================================
% EXTRACT SHAP VALUES
% =============================================================

fprintf('\n============================================================\n');
fprintf(' EXTRACTING GLOBAL SHAP IMPORTANCE\n');
fprintf('============================================================\n');

LocalSHAP = Sshap.LocalSHAP;

fprintf('LocalSHAP class: %s\n',class(LocalSHAP));
fprintf('LocalSHAP dimensions: %d x %d\n',size(LocalSHAP,1),size(LocalSHAP,2));

%% ============================================================
% DETERMINE SHAP MATRIX ORIENTATION
% ============================================================

if size(LocalSHAP,2) == nFeatures

    % Expected format: 132 x 9
    SHAPMatrix = LocalSHAP;

elseif size(LocalSHAP,1) == nFeatures

    % Alternate format: 9 x 132
    SHAPMatrix = LocalSHAP';

else

    error(['LocalSHAP dimensions do not match the expected ', ...
           '132 x 9 or 9 x 132 format.']);

end

fprintf('SHAP matrix used for analysis: %d x %d\n', ...
    size(SHAPMatrix,1),size(SHAPMatrix,2));

%% ============================================================
% GLOBAL MEAN ABSOLUTE SHAP
% =============================================================

globalSHAP = mean(abs(SHAPMatrix),1)';

[sortedSHAP,shapRank] = sort(globalSHAP,'descend');

fprintf('\n============================================================\n');
fprintf(' GLOBAL DL SHAP IMPORTANCE\n');
fprintf('============================================================\n');

fprintf('%-6s %-10s %-15s\n', ...
    'Rank','Feature','MeanAbsSHAP');

fprintf('%s\n',repmat('-',1,38));

for k = 1:nFeatures

    j = shapRank(k);

    fprintf('%-6d %-10s %12.6f dB\n', ...
        k,featureNames{j},globalSHAP(j));

end

%% ============================================================
% EXTRACT BASELINE AND OPTIMIZED PARAMETERS
% =============================================================

cases = {'Low','Medium','High'};

baselineX = zeros(3,nFeatures);
optimizedX = zeros(3,nFeatures);

for i = 1:3

    caseName = cases{i};

    baselineX(i,:) = ...
        optimizationSetup.baseline.(caseName).x(:)';

    if isfield(optimizationResults.(caseName),'xOpt')

        optimizedX(i,:) = ...
            optimizationResults.(caseName).xOpt(:)';

    elseif isfield(optimizationResults.(caseName),'x')

        optimizedX(i,:) = ...
            optimizationResults.(caseName).x(:)';

    else

        error('Optimized vector not found for %s.',caseName);

    end

end

%% ============================================================
% PARAMETER MOVEMENT
% =============================================================

% First 8 parameters span several orders of magnitude.
% Therefore use logarithmic movement for R1-RL and capacitors.

% VCC uses ordinary percentage change.

relativeChange = zeros(3,nFeatures);

for i = 1:3

    for j = 1:8

        relativeChange(i,j) = ...
            100 * ...
            (log10(optimizedX(i,j)) - ...
             log10(baselineX(i,j)));

    end

    relativeChange(i,9) = ...
        100 * ...
        (optimizedX(i,9)-baselineX(i,9)) / ...
        baselineX(i,9);

end

%% ============================================================
% PRINT BASELINE -> OPTIMIZED PARAMETERS
% =============================================================

for i = 1:3

    fprintf('\n============================================================\n');
    fprintf(' %s-GAIN CIRCUIT\n',upper(cases{i}));
    fprintf('============================================================\n');

    fprintf('%-8s %-15s %-15s %-15s\n', ...
        'Feature','Baseline','Optimized','Movement');

    fprintf('%s\n',repmat('-',1,63));

    for j = 1:nFeatures

        fprintf('%-8s %-15.6g %-15.6g %+13.3f %%\n', ...
            featureNames{j}, ...
            baselineX(i,j), ...
            optimizedX(i,j), ...
            relativeChange(i,j));

    end

end

%% ============================================================
% PARAMETER MOVEMENT RANKING
% =============================================================

fprintf('\n\n============================================================\n');
fprintf(' PARAMETER MOVEMENT RANKING\n');
fprintf('============================================================\n');

for i = 1:3

    [~,movementRank] = ...
        sort(abs(relativeChange(i,:)),'descend');

    fprintf('\n%s:\n',cases{i});

    for k = 1:nFeatures

        j = movementRank(k);

        currentSHAPRank = ...
            find(shapRank == j);

        fprintf('%d. %-5s | movement = %8.3f %% | SHAP rank = %d\n', ...
            k, ...
            featureNames{j}, ...
            abs(relativeChange(i,j)), ...
            currentSHAPRank);

    end

end

%% ============================================================
% SHAP IMPORTANCE vs OPTIMIZATION MOVEMENT
% =============================================================

fprintf('\n\n============================================================\n');
fprintf(' SHAP IMPORTANCE vs OPTIMIZATION MOVEMENT\n');
fprintf('============================================================\n');

rhoValues = zeros(3,1);

for i = 1:3

    rhoValues(i) = corr( ...
        globalSHAP, ...
        abs(relativeChange(i,:))', ...
        'Type','Spearman', ...
        'Rows','complete');

    fprintf('%s: Spearman rho = %.4f\n', ...
        cases{i},rhoValues(i));

end

%% ============================================================
% TOP XAI FEATURES
% =============================================================

topN = 6;

fprintf('\n============================================================\n');
fprintf(' TOP %d XAI FEATURES\n',topN);
fprintf('============================================================\n');

for k = 1:topN

    j = shapRank(k);

    fprintf('%d. %s | MeanAbsSHAP = %.6f dB\n', ...
        k,featureNames{j},globalSHAP(j));

end

%% ============================================================
% SAVE RESULTS
% =============================================================

analysisResults.featureNames = featureNames;
analysisResults.SHAPMatrix = SHAPMatrix;
analysisResults.globalSHAP = globalSHAP;
analysisResults.shapRank = shapRank;

analysisResults.baselineX = baselineX;
analysisResults.optimizedX = optimizedX;
analysisResults.relativeChange = relativeChange;

analysisResults.shapMovementSpearman = rhoValues;
analysisResults.cases = cases;

analysisFile = fullfile( ...
    projectRoot, ...
    'results','optimization', ...
    'XAI_Optimization_Analysis.mat');

save(analysisFile,'analysisResults');

fprintf('\n============================================================\n');
fprintf(' STEP 4A COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nResults saved to:\n%s\n\n',analysisFile);
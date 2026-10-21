%% STEP 4B: XAI R1-R2 INTERACTION -> PHYSICAL SPICE VALIDATION
clc;
clear;
close all;

fprintf('\n============================================================\n');
fprintf(' STEP 4B: XAI -> PHYSICAL INTERACTION VALIDATION\n');
fprintf('============================================================\n\n');

projectRoot = 'C:\Internship Project';

%% ============================================================
% FILES
% ============================================================

shapInteractionFile = fullfile( ...
    projectRoot, ...
    'results','final', ...
    'SHAP_Interaction_Results.mat');

spiceSweepFile = fullfile( ...
    projectRoot, ...
    'results','spice_validation','R1_R2', ...
    'R1_R2_SPICE_Validation.mat');

%% ============================================================
% LOAD
% ============================================================

fprintf('Loading SHAP interaction results...\n');

I = load(shapInteractionFile);
Inter_data = I.Inter_data;

fprintf('Loading R1-R2 SPICE sweep...\n');

R = load(spiceSweepFile);
T = R.master_table;

fprintf('\nSPICE table size: %d x %d\n', ...
    height(T),width(T));

%% ============================================================
% FEATURE INFORMATION
% ============================================================

fprintf('\n============================================================\n');
fprintf(' XAI FEATURE INFORMATION\n');
fprintf('============================================================\n');

selectedFeatures = Inter_data.SelectedFeatures;

if isstring(selectedFeatures)
    selectedFeatures = cellstr(selectedFeatures);
elseif ischar(selectedFeatures)
    selectedFeatures = cellstr(selectedFeatures);
end

disp(selectedFeatures);

%% ============================================================
% INTERACTION MATRIX
% ============================================================

InteractionMatrix = Inter_data.InteractionMatrix;

fprintf('InteractionMatrix class: %s\n', ...
    class(InteractionMatrix));

fprintf('InteractionMatrix size: %d x %d\n', ...
    size(InteractionMatrix,1), ...
    size(InteractionMatrix,2));

%% ============================================================
% FIND R1 AND R2
% ============================================================

idxR1 = find(strcmpi(selectedFeatures,'R1'),1);
idxR2 = find(strcmpi(selectedFeatures,'R2'),1);

if isempty(idxR1) || isempty(idxR2)
    error('R1 or R2 was not found in SelectedFeatures.');
end

shapR1R2 = InteractionMatrix(idxR1,idxR2);

fprintf('\n============================================================\n');
fprintf(' R1-R2 SHAP INTERACTION\n');
fprintf('============================================================\n');

fprintf('R1 index: %d\n',idxR1);
fprintf('R2 index: %d\n',idxR2);

fprintf('R1-R2 SHAP interaction = %.6f\n',shapR1R2);

%% ============================================================
% SPICE TABLE CHECK
% ============================================================

fprintf('\n============================================================\n');
fprintf(' SPICE R1-R2 SWEEP\n');
fprintf('============================================================\n');

requiredColumns = { ...
    'Circuit_Type', ...
    'R1', ...
    'R2', ...
    'R1_multiplier', ...
    'R2_multiplier', ...
    'Gain_dB', ...
    'ML_Gain_dB', ...
    'Error_Gain_dB', ...
    'Simulation_Status'};

for k = 1:numel(requiredColumns)

    if ~ismember(requiredColumns{k}, ...
            T.Properties.VariableNames)

        error('Missing required column: %s', ...
            requiredColumns{k});

    end

end

fprintf('Total sweep points: %d\n',height(T));

fprintf('\nCircuit types in SPICE table:\n');

uniqueCircuitTypes = unique(string(T.Circuit_Type));

disp(uniqueCircuitTypes);

%% ============================================================
% CIRCUIT MAPPING
% ============================================================

% Actual labels in the SPICE table:
%
% Low_Gain
% Medium_Gain
% High_Gain

caseNames = {'Low','Medium','High'};

spiceNames = { ...
    'Low_Gain', ...
    'Medium_Gain', ...
    'High_Gain'};

results = struct();

%% ============================================================
% ANALYZE EACH SURFACE
% ============================================================

for c = 1:numel(caseNames)

    caseName = caseNames{c};
    spiceName = spiceNames{c};

    fprintf('\n============================================================\n');
    fprintf(' %s R1-R2 SURFACE\n',upper(caseName));
    fprintf('============================================================\n');

    %% --------------------------------------------------------
    % Select circuit
    % ---------------------------------------------------------

    mask = strcmpi(string(T.Circuit_Type), ...
                   spiceName);

    Tc = T(mask,:);

    fprintf('Number of points: %d\n',height(Tc));

    if height(Tc) ~= 225

        warning('%s contains %d points instead of expected 225.', ...
            spiceName,height(Tc));

    end

    %% --------------------------------------------------------
    % Valid finite points
    % ---------------------------------------------------------

    validMask = ...
        isfinite(Tc.Gain_dB) & ...
        isfinite(Tc.ML_Gain_dB);

    fprintf('Finite SPICE + ML points: %d / %d\n', ...
        sum(validMask),height(Tc));

    Tv = Tc(validMask,:);

    if height(Tv) < 2
        error('Insufficient valid points for %s.',caseName);
    end

    %% --------------------------------------------------------
    % SPICE vs DL
    % ---------------------------------------------------------

    spiceGain = Tv.Gain_dB;
    dlGain = Tv.ML_Gain_dB;

    errorGain = dlGain - spiceGain;

    pearsonR = corr(spiceGain,dlGain, ...
        'Type','Pearson', ...
        'Rows','complete');

    spearmanR = corr(spiceGain,dlGain, ...
        'Type','Spearman', ...
        'Rows','complete');

    RMSE = sqrt(mean(errorGain.^2));

    MAE = mean(abs(errorGain));

    bias = mean(errorGain);

    fprintf('\nSPICE vs DL:\n');

    fprintf(' Pearson  = %.6f\n',pearsonR);
    fprintf(' Spearman = %.6f\n',spearmanR);
    fprintf(' RMSE     = %.6f dB\n',RMSE);
    fprintf(' MAE      = %.6f dB\n',MAE);
    fprintf(' Bias     = %.6f dB\n',bias);

    %% --------------------------------------------------------
    % Build 15 x 15 surfaces
    % ---------------------------------------------------------

    r1Mult = unique(Tv.R1_multiplier);
    r2Mult = unique(Tv.R2_multiplier);

    r1Mult = sort(r1Mult);
    r2Mult = sort(r2Mult);

    nR1 = numel(r1Mult);
    nR2 = numel(r2Mult);

    fprintf('\nGrid:\n');
    fprintf('Unique R1 multipliers = %d\n',nR1);
    fprintf('Unique R2 multipliers = %d\n',nR2);

    spiceSurface = nan(nR1,nR2);
    dlSurface = nan(nR1,nR2);

    for i = 1:nR1

        for j = 1:nR2

            pointMask = ...
                abs(Tv.R1_multiplier-r1Mult(i)) < 1e-12 & ...
                abs(Tv.R2_multiplier-r2Mult(j)) < 1e-12;

            if sum(pointMask) == 1

                spiceSurface(i,j) = ...
                    Tv.Gain_dB(pointMask);

                dlSurface(i,j) = ...
                    Tv.ML_Gain_dB(pointMask);

            end

        end

    end

    fprintf('Complete SPICE grid points: %d / %d\n', ...
        sum(isfinite(spiceSurface),'all'), ...
        numel(spiceSurface));

    %% --------------------------------------------------------
    % Physical R1-R2 interaction
    %
    % I = G(i+1,j+1) - G(i+1,j)
    %     - G(i,j+1) + G(i,j)
    %
    % This is a local finite-difference interaction measure.
    % ---------------------------------------------------------

    interactionSurface = nan(nR1-1,nR2-1);

    for i = 1:nR1-1

        for j = 1:nR2-1

            g11 = spiceSurface(i,j);
            g12 = spiceSurface(i,j+1);
            g21 = spiceSurface(i+1,j);
            g22 = spiceSurface(i+1,j+1);

            values = [g11 g12 g21 g22];

            if all(isfinite(values))

                interactionSurface(i,j) = ...
                    g22 - g21 - g12 + g11;

            end

        end

    end

    finiteInteraction = ...
        interactionSurface(isfinite(interactionSurface));

    meanPhysicalInteraction = ...
        mean(abs(finiteInteraction));

    maxPhysicalInteraction = ...
        max(abs(finiteInteraction));

    stdPhysicalInteraction = ...
        std(finiteInteraction);

    fprintf('\nPhysical R1-R2 interaction:\n');

    fprintf(' Mean |interaction| = %.6f dB\n', ...
        meanPhysicalInteraction);

    fprintf(' Max  |interaction| = %.6f dB\n', ...
        maxPhysicalInteraction);

    fprintf(' Std interaction    = %.6f dB\n', ...
        stdPhysicalInteraction);

    %% --------------------------------------------------------
    % Operating-region statistics
    % ---------------------------------------------------------

    status = string(Tc.Simulation_Status);

    saturationCount = sum(contains( ...
        lower(status),'saturation'));

    cutoffCount = sum(contains( ...
        lower(status),'cutoff'));

    fprintf('\nPhysical operating regions:\n');

    fprintf(' Saturation points = %d\n',saturationCount);
    fprintf(' Cutoff points     = %d\n',cutoffCount);

    fprintf(' Remaining points  = %d\n', ...
        height(Tc)-saturationCount-cutoffCount);

    %% --------------------------------------------------------
    % Store
    % ---------------------------------------------------------

    results.(caseName).table = Tc;

    results.(caseName).spiceGain = spiceGain;
    results.(caseName).dlGain = dlGain;

    results.(caseName).pearson = pearsonR;
    results.(caseName).spearman = spearmanR;

    results.(caseName).RMSE = RMSE;
    results.(caseName).MAE = MAE;
    results.(caseName).bias = bias;

    results.(caseName).R1_multiplier = r1Mult;
    results.(caseName).R2_multiplier = r2Mult;

    results.(caseName).spiceSurface = spiceSurface;
    results.(caseName).dlSurface = dlSurface;

    results.(caseName).interactionSurface = ...
        interactionSurface;

    results.(caseName).meanPhysicalInteraction = ...
        meanPhysicalInteraction;

    results.(caseName).maxPhysicalInteraction = ...
        maxPhysicalInteraction;

    results.(caseName).stdPhysicalInteraction = ...
        stdPhysicalInteraction;

    results.(caseName).saturationCount = saturationCount;
    results.(caseName).cutoffCount = cutoffCount;

end

%% ============================================================
% GLOBAL 675-POINT AGREEMENT
% ============================================================

fprintf('\n\n============================================================\n');
fprintf(' GLOBAL 675-POINT SURFACE AGREEMENT\n');
fprintf('============================================================\n');

allSPICE = [];
allDL = [];

for c = 1:numel(caseNames)

    name = caseNames{c};

    allSPICE = [allSPICE; ...
        results.(name).spiceGain(:)];

    allDL = [allDL; ...
        results.(name).dlGain(:)];

end

globalPearson = corr(allSPICE,allDL, ...
    'Type','Pearson', ...
    'Rows','complete');

globalSpearman = corr(allSPICE,allDL, ...
    'Type','Spearman', ...
    'Rows','complete');

globalRMSE = sqrt(mean((allDL-allSPICE).^2));

globalMAE = mean(abs(allDL-allSPICE));

fprintf('Pearson  = %.6f\n',globalPearson);
fprintf('Spearman = %.6f\n',globalSpearman);
fprintf('RMSE     = %.6f dB\n',globalRMSE);
fprintf('MAE      = %.6f dB\n',globalMAE);

%% ============================================================
% SUMMARY TABLE
% ============================================================

fprintf('\n============================================================\n');
fprintf(' CROSS-CASE SUMMARY\n');
fprintf('============================================================\n');

fprintf('%-10s %-10s %-10s %-12s %-12s %-12s\n', ...
    'Circuit','Pearson','Spearman','RMSE(dB)', ...
    'MAE(dB)','Mean|I|');

fprintf('%s\n',repmat('-',1,76));

for c = 1:numel(caseNames)

    name = caseNames{c};

    fprintf('%-10s %10.4f %10.4f %12.4f %12.4f %12.4f\n', ...
        name, ...
        results.(name).pearson, ...
        results.(name).spearman, ...
        results.(name).RMSE, ...
        results.(name).MAE, ...
        results.(name).meanPhysicalInteraction);

end

%% ============================================================
% XAI -> PHYSICAL SUMMARY
% ============================================================

fprintf('\n============================================================\n');
fprintf(' XAI -> PHYSICAL INTERACTION SUMMARY\n');
fprintf('============================================================\n');

fprintf('DL-SHAP R1-R2 interaction = %.6f\n',shapR1R2);

for c = 1:numel(caseNames)

    name = caseNames{c};

    fprintf('%s: Mean physical |R1-R2 interaction| = %.6f dB\n', ...
        name, ...
        results.(name).meanPhysicalInteraction);

end

%% ============================================================
% SAVE
% ============================================================

analysisResults = struct();

analysisResults.shapR1R2 = shapR1R2;
analysisResults.selectedFeatures = selectedFeatures;
analysisResults.results = results;

analysisResults.globalPearson = globalPearson;
analysisResults.globalSpearman = globalSpearman;
analysisResults.globalRMSE = globalRMSE;
analysisResults.globalMAE = globalMAE;

analysisResults.sourceFiles.shapInteraction = ...
    shapInteractionFile;

analysisResults.sourceFiles.spiceSweep = ...
    spiceSweepFile;

outputFile = fullfile( ...
    projectRoot, ...
    'results','optimization', ...
    'XAI_R1_R2_Physical_Validation.mat');

save(outputFile,'analysisResults');

fprintf('\nResults saved to:\n%s\n',outputFile);

%% ============================================================
% FIGURES
% ============================================================

figureDir = fullfile( ...
    projectRoot, ...
    'results','optimization', ...
    'XAI_R1_R2_Figures');

if ~exist(figureDir,'dir')
    mkdir(figureDir);
end

for c = 1:numel(caseNames)

    name = caseNames{c};

    %% SPICE surface

    figure('Name',[name ' SPICE R1-R2']);

    imagesc( ...
        results.(name).R2_multiplier, ...
        results.(name).R1_multiplier, ...
        results.(name).spiceSurface);

    set(gca,'YDir','normal');

    xlabel('R2 multiplier');
    ylabel('R1 multiplier');

    title([name '-gain SPICE Gain Surface']);

    colorbar;

    saveas(gcf,fullfile(figureDir, ...
        [name '_SPICE_Surface.png']));

    %% DL surface

    figure('Name',[name ' DL R1-R2']);

    imagesc( ...
        results.(name).R2_multiplier, ...
        results.(name).R1_multiplier, ...
        results.(name).dlSurface);

    set(gca,'YDir','normal');

    xlabel('R2 multiplier');
    ylabel('R1 multiplier');

    title([name '-gain DL Gain Surface']);

    colorbar;

    saveas(gcf,fullfile(figureDir, ...
        [name '_DL_Surface.png']));

    %% Absolute error

    figure('Name',[name ' Error']);

    imagesc( ...
        results.(name).R2_multiplier, ...
        results.(name).R1_multiplier, ...
        abs(results.(name).dlSurface - ...
            results.(name).spiceSurface));

    set(gca,'YDir','normal');

    xlabel('R2 multiplier');
    ylabel('R1 multiplier');

    title([name '-gain |DL - SPICE| Error']);

    colorbar;

    saveas(gcf,fullfile(figureDir, ...
        [name '_Absolute_Error.png']));

    %% Physical interaction

    figure('Name',[name ' Physical Interaction']);

    imagesc( ...
        results.(name).R2_multiplier(1:end-1), ...
        results.(name).R1_multiplier(1:end-1), ...
        results.(name).interactionSurface);

    set(gca,'YDir','normal');

    xlabel('R2 multiplier');
    ylabel('R1 multiplier');

    title([name '-gain Physical R1-R2 Interaction']);

    colorbar;

    saveas(gcf,fullfile(figureDir, ...
        [name '_Physical_Interaction.png']));

end

fprintf('\nFigures saved to:\n%s\n',figureDir);

fprintf('\n============================================================\n');
fprintf(' STEP 4B COMPLETE\n');
fprintf('============================================================\n');
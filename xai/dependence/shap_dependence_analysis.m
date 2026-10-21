%% ============================================================
% SHAP DEPENDENCE ANALYSIS
%
% Explainable AI analysis of the CE amplifier surrogate model.
%
% Purpose:
%   1. Calculate SHAP values for all valid circuits
%   2. Study how each important circuit parameter affects Gain_dB
%   3. Quantify dependence between parameter values and SHAP values
%   4. Generate dependence plots
%
% IMPORTANT:
%   The ML model was trained using:
%       log10(R1)
%       log10(R2)
%       log10(RC)
%       log10(RE)
%       log10(RL)
%       log10(Cin)
%       log10(Cout)
%       log10(Ce)
%       VCC
%
%   SHAP values therefore explain the surrogate model in this
%   transformed feature space.
%
%   SHAP contribution and classical sensitivity are NOT the same
%   quantity. SHAP describes contribution to model prediction,
%   whereas classical sensitivity is a normalized local derivative.
%
% ============================================================

clear;
clc;
close all;

fprintf('\n============================================\n');
fprintf('       SHAP DEPENDENCE ANALYSIS\n');
fprintf('============================================\n\n');


%% ============================================================
% SECTION 1 - PATH SETUP
% ============================================================

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

output_dir = fullfile(project_dir, 'output');
dependence_dir = fullfile(output_dir, 'shap_dependence');

if ~exist(dependence_dir, 'dir')
    mkdir(dependence_dir);
end


%% ============================================================
% SECTION 2 - FILE PATHS
% ============================================================

dataset_file = fullfile( ...
    output_dir, ...
    'CE_Amplifier_ML_Valid.csv');

model_file = fullfile( ...
    output_dir, ...
    'Gain_Boosted_Model.mat');

shap_file = fullfile( ...
    output_dir, ...
    'Gain_SHAP_Results.mat');


fprintf('Checking files...\n');

if ~isfile(dataset_file)
    error('Dataset not found:\n%s', dataset_file);
end

if ~isfile(model_file)
    error('ML model not found:\n%s', model_file);
end

if ~isfile(shap_file)
    error('SHAP results not found:\n%s', shap_file);
end

fprintf('Dataset  : OK\n');
fprintf('ML model : OK\n');
fprintf('SHAP file : OK\n');


%% ============================================================
% SECTION 3 - LOAD DATASET
% ============================================================

fprintf('\n============================================\n');
fprintf('          LOADING DATASET\n');
fprintf('============================================\n\n');

data = readtable(dataset_file);

nRows = height(data);

fprintf('Dataset rows = %d\n', nRows);


%% ============================================================
% SECTION 4 - DEFINE FEATURES
% ============================================================

features = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};

nFeatures = numel(features);

fprintf('\nFeatures:\n');

for k = 1:nFeatures
    fprintf('  %d. %s\n', k, features{k});
end


%% ============================================================
% SECTION 5 - VERIFY DATASET COLUMNS
% ============================================================

required_columns = [features, {'Gain_dB'}];

data_columns = data.Properties.VariableNames;

for k = 1:numel(required_columns)

    if ~ismember(required_columns{k}, data_columns)

        error('Required dataset column not found: %s', ...
            required_columns{k});

    end

end


%% ============================================================
% SECTION 6 - EXTRACT RAW INPUT FEATURES
% ============================================================

Xraw = zeros(nRows, nFeatures);

for k = 1:nFeatures

    Xraw(:,k) = double(data.(features{k}));

end

Y = double(data.Gain_dB);


%% ============================================================
% SECTION 7 - CHECK FOR MISSING / INVALID DATA
% ============================================================

if any(~isfinite(Xraw(:)))
    error('Dataset contains NaN or Inf values in input features.');
end

if any(~isfinite(Y))
    error('Dataset contains NaN or Inf values in Gain_dB.');
end


%% ============================================================
% SECTION 8 - PREPARE MODEL INPUT
% ============================================================

fprintf('\n============================================\n');
fprintf('       PREPARING MODEL INPUT\n');
fprintf('============================================\n\n');

% ------------------------------------------------------------
% The original ML model uses:
%
%   log10() for the eight component values
%   linear VCC
%
% ------------------------------------------------------------

Xmodel = zeros(nRows, nFeatures);

for k = 1:8

    if any(Xraw(:,k) <= 0)

        error( ...
            'Feature %s contains non-positive values; log10 cannot be applied.', ...
            features{k});

    end

    Xmodel(:,k) = log10(Xraw(:,k));

end

% VCC remains linear
Xmodel(:,9) = Xraw(:,9);


fprintf('Model input size:\n');
disp(size(Xmodel));


%% ============================================================
% SECTION 9 - LOAD ML MODEL
% ============================================================

fprintf('\n============================================\n');
fprintf('            LOADING ML MODEL\n');
fprintf('============================================\n\n');

M = load(model_file);

if ~isfield(M, 'model')

    error( ...
        'Variable "model" was not found in ML model MAT file.');

end

model = M.model;

fprintf('Model class: %s\n', class(model));


%% ============================================================
% SECTION 10 - VERIFY MODEL PREDICTIONS
% ============================================================

fprintf('\n============================================\n');
fprintf('       VERIFYING MODEL PREDICTION\n');
fprintf('============================================\n\n');

Ypred = predict(model, Xmodel);

Ypred = double(Ypred(:));
Y = double(Y(:));

residuals = Y - Ypred;

SSres = sum(residuals.^2);
SStot = sum((Y - mean(Y)).^2);

R2_full = 1 - SSres / SStot;

RMSE_full = sqrt(mean(residuals.^2));

MAE_full = mean(abs(residuals));

fprintf('R2   = %.4f\n', R2_full);
fprintf('RMSE = %.4f dB\n', RMSE_full);
fprintf('MAE  = %.4f dB\n', MAE_full);

fprintf('\nNOTE:\n');
fprintf(['These are predictions on the complete %d-row dataset.\n'], ...
    nRows);

fprintf('They are NOT held-out test performance.\n\n');

fprintf('Previously established generalization results:\n');
fprintf('  Test R2   = 0.7867\n');
fprintf('  Test RMSE = 3.0746 dB\n');
fprintf('  CV R2     = 0.7987\n');
fprintf('  CV RMSE   = 3.2246 dB\n');


%% ============================================================
% SECTION 11 - CREATE SHAP EXPLAINER
% ============================================================

fprintf('\n============================================\n');
fprintf('         CREATING SHAP EXPLAINER\n');
fprintf('============================================\n\n');

fprintf('Creating explainer...\n');

explainer = shapley( ...
    model, ...
    Xmodel, ...
    NumObservationsToSample="all");

fprintf('\nSHAP explainer created.\n');

if isprop(explainer, 'Method')

    fprintf('SHAP method: %s\n', ...
        string(explainer.Method));

end


%% ============================================================
% SECTION 12 - CALCULATE SHAP VALUES
% ============================================================

fprintf('\n============================================\n');
fprintf('       CALCULATING INDIVIDUAL SHAP VALUES\n');
fprintf('============================================\n\n');

fprintf('Calculating SHAP values for %d circuits...\n\n', ...
    nRows);

% ------------------------------------------------------------
% Fit SHAP explainer to all query points
% ------------------------------------------------------------

fitted_explainer = fit(explainer, Xmodel);

fprintf('\nSHAP calculation complete.\n');


%% ============================================================
% SECTION 13 - INSPECT SHAP OUTPUT
% ============================================================

fprintf('\n============================================\n');
fprintf('          INSPECTING SHAP OUTPUT\n');
fprintf('============================================\n\n');

shap_table = fitted_explainer.Shapley;

fprintf('Shapley table size:\n');
disp(size(shap_table));

fprintf('\nShapley table variables:\n');
disp(shap_table.Properties.VariableNames);

fprintf('\nShapley table:\n');
disp(shap_table);


%% ============================================================
% SECTION 14 - EXTRACT SHAP VALUES
% ============================================================

fprintf('\n============================================\n');
fprintf('       EXTRACTING INDIVIDUAL SHAP VALUES\n');
fprintf('============================================\n\n');

ValueData = shap_table.Value;

fprintf('Class of ValueData:\n');
disp(class(ValueData));

fprintf('Size of ValueData:\n');
disp(size(ValueData));

fprintf('Number of Value entries:\n');
fprintf('%d\n', numel(ValueData));


% ------------------------------------------------------------
% CASE 1:
%
% MATLAB R2025b may return the array-valued table variable
% as a numeric 9 x 660 matrix.
%
% This is the representation shown in the user's output.
% ------------------------------------------------------------

if isnumeric(ValueData)

    [nValueRows, nValueCols] = size(ValueData);

    fprintf('\nDetected numeric SHAP representation.\n');
    fprintf('Numeric SHAP size = %d x %d\n', ...
        nValueRows, nValueCols);

    if nValueRows == nFeatures && nValueCols == nRows

        % Current MATLAB representation:
        %
        %        predictors x circuits
        %
        %             9 x 660
        %
        % Convert to:
        %
        %             circuits x predictors
        %
        %             660 x 9

        LocalSHAP = double(ValueData.');

        fprintf('\nDetected predictor-wise SHAP vectors.\n');
        fprintf('Transposing 9 x %d -> %d x 9.\n', ...
            nRows, nRows);

    elseif nValueRows == nRows && nValueCols == nFeatures

        % Already in desired format

        LocalSHAP = double(ValueData);

        fprintf('\nSHAP matrix already has desired orientation.\n');

    else

        error( ...
            ['Unexpected numeric SHAP ValueData size: %d x %d.\n' ...
             'Expected either %d x %d or %d x %d.'], ...
             nValueRows, ...
             nValueCols, ...
             nFeatures, ...
             nRows, ...
             nRows, ...
             nFeatures);

    end


% ------------------------------------------------------------
% CASE 2:
%
% Some MATLAB versions / representations may return cells.
% ------------------------------------------------------------

elseif iscell(ValueData)

    fprintf('\nDetected cell-array SHAP representation.\n');

    if numel(ValueData) ~= nFeatures

        error( ...
            ['Expected %d SHAP Value cells but found %d.'], ...
            nFeatures, ...
            numel(ValueData));

    end

    LocalSHAP = NaN(nRows, nFeatures);

    for k = 1:nFeatures

        v = double(ValueData{k}(:));

        if numel(v) ~= nRows

            error( ...
                ['Predictor x%d contains %d SHAP values; ' ...
                 'expected %d.'], ...
                 k, ...
                 numel(v), ...
                 nRows);

        end

        LocalSHAP(:,k) = v;

    end


else

    error( ...
        'Unsupported SHAP ValueData class: %s', ...
        class(ValueData));

end


%% ============================================================
% SECTION 15 - VALIDATE SHAP MATRIX
% ============================================================

fprintf('\n============================================\n');
fprintf('          VALIDATING SHAP MATRIX\n');
fprintf('============================================\n\n');

fprintf('LocalSHAP size:\n');
disp(size(LocalSHAP));

fprintf('Expected size:\n');
fprintf('%d rows x %d features\n', ...
    nRows, nFeatures);


if ~isequal(size(LocalSHAP), [nRows nFeatures])

    error( ...
        ['Final LocalSHAP matrix has size %d x %d. ' ...
         'Expected %d x %d.'], ...
         size(LocalSHAP,1), ...
         size(LocalSHAP,2), ...
         nRows, ...
         nFeatures);

end


if any(~isfinite(LocalSHAP(:)))

    error('SHAP matrix contains NaN or Inf values.');

end

fprintf('\nSHAP matrix successfully extracted.\n');
fprintf('All SHAP values are finite.\n');


%% ============================================================
% SECTION 16 - SHAP FEATURE MAPPING
% ============================================================

fprintf('\n============================================\n');
fprintf('           SHAP FEATURE MAPPING\n');
fprintf('============================================\n\n');

for k = 1:nFeatures

    fprintf('  x%d -> %s\n', ...
        k, features{k});

end


%% ============================================================
% SECTION 17 - GLOBAL SHAP STATISTICS
% ============================================================

fprintf('\n============================================\n');
fprintf('         GLOBAL SHAP STATISTICS\n');
fprintf('============================================\n\n');

MeanAbsSHAP = mean(abs(LocalSHAP), 1);
MeanSHAP = mean(LocalSHAP, 1);

MinSHAP = min(LocalSHAP, [], 1);
MaxSHAP = max(LocalSHAP, [], 1);

fprintf('Global mean absolute SHAP values:\n\n');

for k = 1:nFeatures

    fprintf('%-6s : %.6f dB\n', ...
        features{k}, ...
        MeanAbsSHAP(k));

end


%% ============================================================
% SECTION 18 - SELECT IMPORTANT PARAMETERS
% ============================================================

% ------------------------------------------------------------
% Based on the previously obtained global SHAP ranking:
%
%   RE
%   R1
%   RC
%   R2
%   VCC
%   RL
%
% These six parameters are selected for dependence analysis.
%
% Low-impact capacitors are excluded from the main plots to
% keep the analysis readable.
% ------------------------------------------------------------

selected_features = { ...
    'RE', ...
    'R1', ...
    'RC', ...
    'R2', ...
    'VCC', ...
    'RL'};

nSelected = numel(selected_features);

selected_indices = zeros(1, nSelected);

for k = 1:nSelected

    idx = find(strcmp(features, selected_features{k}), 1);

    if isempty(idx)

        error( ...
            'Selected feature not found: %s', ...
            selected_features{k});

    end

    selected_indices(k) = idx;

end


%% ============================================================
% SECTION 19 - DEPENDENCE STATISTICS
% ============================================================

fprintf('\n============================================\n');
fprintf('       SHAP DEPENDENCE STATISTICS\n');
fprintf('============================================\n\n');

DependenceResults = struct([]);

for k = 1:nSelected

    feature_index = selected_indices(k);

    feature_name = selected_features{k};

    parameter_values = Xraw(:,feature_index);

    shap_values = LocalSHAP(:,feature_index);

    % --------------------------------------------------------
    % Spearman correlation
    %
    % This measures monotonic association between the actual
    % parameter value and its SHAP contribution.
    % --------------------------------------------------------

    rho = corr( ...
        parameter_values, ...
        shap_values, ...
        'Type', 'Spearman', ...
        'Rows', 'complete');

    % --------------------------------------------------------
    % Pearson correlation is also calculated for reference.
    % --------------------------------------------------------

    pearson_r = corr( ...
        parameter_values, ...
        shap_values, ...
        'Type', 'Pearson', ...
        'Rows', 'complete');

    DependenceResults(k).Parameter = feature_name;
    DependenceResults(k).MeanAbsoluteSHAP = ...
        mean(abs(shap_values));

    DependenceResults(k).MeanSHAP = ...
        mean(shap_values);

    DependenceResults(k).MinSHAP = ...
        min(shap_values);

    DependenceResults(k).MaxSHAP = ...
        max(shap_values);

    DependenceResults(k).SpearmanRho = rho;

    DependenceResults(k).PearsonR = pearson_r;

    fprintf('%-5s  Mean|SHAP| = %8.5f dB   ', ...
        feature_name, ...
        DependenceResults(k).MeanAbsoluteSHAP);

    fprintf('Spearman rho = %+7.4f\n', rho);

end


%% ============================================================
% SECTION 20 - CREATE DEPENDENCE RESULTS TABLE
% ============================================================

Parameter = strings(nSelected,1);
MeanAbsoluteSHAP_col = zeros(nSelected,1);
MeanSHAP_col = zeros(nSelected,1);
MinSHAP_col = zeros(nSelected,1);
MaxSHAP_col = zeros(nSelected,1);
SpearmanRho_col = zeros(nSelected,1);
PearsonR_col = zeros(nSelected,1);

for k = 1:nSelected

    Parameter(k) = string(DependenceResults(k).Parameter);

    MeanAbsoluteSHAP_col(k) = ...
        DependenceResults(k).MeanAbsoluteSHAP;

    MeanSHAP_col(k) = ...
        DependenceResults(k).MeanSHAP;

    MinSHAP_col(k) = ...
        DependenceResults(k).MinSHAP;

    MaxSHAP_col(k) = ...
        DependenceResults(k).MaxSHAP;

    SpearmanRho_col(k) = ...
        DependenceResults(k).SpearmanRho;

    PearsonR_col(k) = ...
        DependenceResults(k).PearsonR;

end

DependenceTable = table( ...
    Parameter, ...
    MeanAbsoluteSHAP_col, ...
    MeanSHAP_col, ...
    MinSHAP_col, ...
    MaxSHAP_col, ...
    SpearmanRho_col, ...
    PearsonR_col, ...
    'VariableNames', { ...
        'Parameter', ...
        'MeanAbsoluteSHAP', ...
        'MeanSHAP', ...
        'MinSHAP', ...
        'MaxSHAP', ...
        'SpearmanRho', ...
        'PearsonR'});


%% ============================================================
% SECTION 21 - DISPLAY DEPENDENCE TABLE
% ============================================================

fprintf('\n============================================\n');
fprintf('       DEPENDENCE RESULTS TABLE\n');
fprintf('============================================\n\n');

disp(DependenceTable);


%% ============================================================
% SECTION 22 - SAVE DEPENDENCE STATISTICS
% ============================================================

statistics_file = fullfile( ...
    dependence_dir, ...
    'SHAP_Dependence_Statistics.csv');

writetable( ...
    DependenceTable, ...
    statistics_file);

fprintf('\nSaved dependence statistics:\n%s\n', ...
    statistics_file);


%% ============================================================
% SECTION 23 - CREATE INDIVIDUAL DEPENDENCE PLOTS
% ============================================================

fprintf('\n============================================\n');
fprintf('       CREATING DEPENDENCE PLOTS\n');
fprintf('============================================\n\n');

for k = 1:nSelected

    feature_index = selected_indices(k);

    feature_name = selected_features{k};

    x = Xraw(:,feature_index);

    y = LocalSHAP(:,feature_index);

    fig = figure( ...
        'Name', ...
        ['SHAP Dependence - ' feature_name], ...
        'NumberTitle', ...
        'off');

    scatter(x, y, 28, 'filled');

    hold on;

    % Zero SHAP reference line
    yline(0, '--');

    hold off;

    xlabel(feature_name, ...
        'Interpreter', 'none');

    ylabel('SHAP Contribution (dB)');

    title( ...
        ['SHAP Dependence: ' feature_name], ...
        'Interpreter', 'none');

    grid on;

    % Component values span multiple orders of magnitude.
    % Therefore logarithmic x-axis is used for R/C parameters.
    if feature_index <= 8
        set(gca, 'XScale', 'log');
    end

    drawnow;

    plot_file = fullfile( ...
        dependence_dir, ...
        ['SHAP_Dependence_' feature_name '.png']);

    exportgraphics( ...
        fig, ...
        plot_file, ...
        'Resolution', 200);

    fprintf('Saved: %s\n', plot_file);

    close(fig);

end


%% ============================================================
% SECTION 24 - CREATE COMBINED OVERVIEW
% ============================================================

fprintf('\n============================================\n');
fprintf('       CREATING OVERVIEW PLOT\n');
fprintf('============================================\n\n');

fig_overview = figure( ...
    'Name', ...
    'SHAP Dependence Overview', ...
    'NumberTitle', ...
    'off');

tiledlayout(2,3, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

for k = 1:nSelected

    feature_index = selected_indices(k);

    feature_name = selected_features{k};

    x = Xraw(:,feature_index);

    y = LocalSHAP(:,feature_index);

    nexttile;

    scatter(x, y, 20, 'filled');

    hold on;

    yline(0, '--');

    hold off;

    xlabel(feature_name, ...
        'Interpreter', 'none');

    ylabel('SHAP (dB)');

    title(feature_name, ...
        'Interpreter', 'none');

    grid on;

    if feature_index <= 8
        set(gca, 'XScale', 'log');
    end

end

drawnow;

overview_file = fullfile( ...
    dependence_dir, ...
    'SHAP_Dependence_Overview.png');

exportgraphics( ...
    fig_overview, ...
    overview_file, ...
    'Resolution', 200);

fprintf('Saved: %s\n', overview_file);

close(fig_overview);


%% ============================================================
% SECTION 25 - SHAP RANKING
% ============================================================

fprintf('\n============================================\n');
fprintf('             SHAP RANKING\n');
fprintf('============================================\n\n');

[sorted_importance, sort_order] = ...
    sort(MeanAbsSHAP, 'descend');

fprintf('%-6s %-10s %-15s\n', ...
    'Rank', ...
    'Parameter', ...
    'Mean|SHAP|');

fprintf('--------------------------------------------\n');

for rank = 1:nFeatures

    idx = sort_order(rank);

    fprintf('%-6d %-10s %10.6f dB\n', ...
        rank, ...
        features{idx}, ...
        sorted_importance(rank));

end


%% ============================================================
% SECTION 26 - SAVE SHAP RANKING
% ============================================================

Rank = (1:nFeatures)';

ParameterRanked = strings(nFeatures,1);

MeanAbsoluteSHAPRanked = zeros(nFeatures,1);

for k = 1:nFeatures

    idx = sort_order(k);

    ParameterRanked(k) = string(features{idx});

    MeanAbsoluteSHAPRanked(k) = ...
        sorted_importance(k);

end

SHAPRankingTable = table( ...
    Rank, ...
    ParameterRanked, ...
    MeanAbsoluteSHAPRanked, ...
    'VariableNames', { ...
        'Rank', ...
        'Parameter', ...
        'MeanAbsoluteSHAP'});


ranking_file = fullfile( ...
    dependence_dir, ...
    'SHAP_Dependence_Ranking.csv');

writetable( ...
    SHAPRankingTable, ...
    ranking_file);

fprintf('\nSaved ranking:\n%s\n', ...
    ranking_file);


%% ============================================================
% SECTION 27 - SAVE COMPLETE MATLAB RESULTS
% ============================================================

Results = struct();

Results.DatasetFile = dataset_file;

Results.ModelFile = model_file;

Results.SHAPFile = shap_file;

Results.Features = features;

Results.SelectedFeatures = selected_features;

Results.Xraw = Xraw;

Results.Xmodel = Xmodel;

Results.Y = Y;

Results.Ypred = Ypred;

Results.FullDataset_R2 = R2_full;

Results.FullDataset_RMSE = RMSE_full;

Results.FullDataset_MAE = MAE_full;

Results.LocalSHAP = LocalSHAP;

Results.GlobalMeanAbsSHAP = MeanAbsSHAP;

Results.GlobalMeanSHAP = MeanSHAP;

Results.GlobalMinSHAP = MinSHAP;

Results.GlobalMaxSHAP = MaxSHAP;

Results.DependenceResults = DependenceResults;

Results.DependenceTable = DependenceTable;

Results.SHAPRankingTable = SHAPRankingTable;

Results.SelectedIndices = selected_indices;


results_mat_file = fullfile( ...
    dependence_dir, ...
    'SHAP_Dependence_Results.mat');

save( ...
    results_mat_file, ...
    'Results', ...
    '-v7.3');


fprintf('\nSaved MATLAB results:\n%s\n', ...
    results_mat_file);


%% ============================================================
% SECTION 28 - FINAL SUMMARY
% ============================================================

fprintf('\n============================================\n');
fprintf('          SHAP DEPENDENCE COMPLETE\n');
fprintf('============================================\n\n');

fprintf('Dataset rows analyzed : %d\n', nRows);

fprintf('Number of features    : %d\n', nFeatures);

fprintf('Parameters plotted    : %d\n', nSelected);

fprintf('\nModel verification on complete dataset:\n');

fprintf('  R2   = %.4f\n', R2_full);

fprintf('  RMSE = %.4f dB\n', RMSE_full);

fprintf('  MAE  = %.4f dB\n', MAE_full);

fprintf('\nPreviously established generalization:\n');

fprintf('  Test R2   = 0.7867\n');

fprintf('  Test RMSE = 3.0746 dB\n');

fprintf('  CV R2     = 0.7987\n');

fprintf('  CV RMSE   = 3.2246 dB\n');

fprintf('\nOutput directory:\n%s\n', ...
    dependence_dir);

fprintf('\nGenerated files include:\n');

fprintf('  SHAP_Dependence_Statistics.csv\n');

fprintf('  SHAP_Dependence_Ranking.csv\n');

fprintf('  SHAP_Dependence_Results.mat\n');

fprintf('  SHAP_Dependence_RE.png\n');

fprintf('  SHAP_Dependence_R1.png\n');

fprintf('  SHAP_Dependence_RC.png\n');

fprintf('  SHAP_Dependence_R2.png\n');

fprintf('  SHAP_Dependence_VCC.png\n');

fprintf('  SHAP_Dependence_RL.png\n');

fprintf('  SHAP_Dependence_Overview.png\n');

fprintf('\n============================================\n');
fprintf('                  DONE\n');
fprintf('============================================\n');
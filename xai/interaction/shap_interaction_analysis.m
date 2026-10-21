clear;
clc;
close all;

fprintf('\n============================================\n');
fprintf('       SHAP INTERACTION ANALYSIS\n');
fprintf('============================================\n\n');


%% ============================================================
% SECTION 1 - PATH SETUP
% ============================================================

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

output_dir = fullfile(project_dir, 'output');

interaction_dir = fullfile( ...
    output_dir, ...
    'shap_interaction');

if ~exist(interaction_dir, 'dir')
    mkdir(interaction_dir);
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

fprintf('Checking files...\n');

if ~isfile(dataset_file)
    error('Dataset not found:\n%s', dataset_file);
end

if ~isfile(model_file)
    error('ML model not found:\n%s', model_file);
end

fprintf('Dataset  : OK\n');
fprintf('ML model : OK\n');


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
% SECTION 5 - EXTRACT RAW FEATURES
% ============================================================

Xraw = zeros(nRows, nFeatures);

for k = 1:nFeatures
    Xraw(:,k) = double(data.(features{k}));
end

Y = double(data.Gain_dB);

if any(~isfinite(Xraw(:)))
    error('Input dataset contains NaN or Inf.');
end

if any(~isfinite(Y))
    error('Gain_dB contains NaN or Inf.');
end


%% ============================================================
% SECTION 6 - PREPARE MODEL INPUT
% ============================================================

fprintf('\n============================================\n');
fprintf('       PREPARING MODEL INPUT\n');
fprintf('============================================\n\n');

Xmodel = zeros(nRows, nFeatures);

% Eight component parameters use log10
for k = 1:8

    if any(Xraw(:,k) <= 0)
        error( ...
            'Feature %s contains non-positive values.', ...
            features{k});
    end

    Xmodel(:,k) = log10(Xraw(:,k));

end

% VCC remains linear
Xmodel(:,9) = Xraw(:,9);

fprintf('Model input size:\n');
disp(size(Xmodel));


%% ============================================================
% SECTION 7 - LOAD MODEL
% ============================================================

fprintf('\n============================================\n');
fprintf('            LOADING ML MODEL\n');
fprintf('============================================\n\n');

M = load(model_file);

if ~isfield(M,'model')
    error('Variable "model" not found in model MAT file.');
end

model = M.model;

fprintf('Model class: %s\n', class(model));


%% ============================================================
% SECTION 8 - MODEL PREDICTION CHECK
% ============================================================

fprintf('\n============================================\n');
fprintf('       VERIFYING MODEL PREDICTION\n');
fprintf('============================================\n\n');

Ypred = double(predict(model, Xmodel));

Ypred = Ypred(:);
Y = Y(:);

residuals = Y - Ypred;

R2_full = ...
    1 - sum(residuals.^2) / ...
    sum((Y - mean(Y)).^2);

RMSE_full = sqrt(mean(residuals.^2));

MAE_full = mean(abs(residuals));

fprintf('Full dataset prediction:\n');

fprintf('R2   = %.4f\n', R2_full);
fprintf('RMSE = %.4f dB\n', RMSE_full);
fprintf('MAE  = %.4f dB\n', MAE_full);

fprintf('\nIMPORTANT:\n');
fprintf('These are NOT held-out test results.\n');
fprintf('Previously established test R2 = 0.7867\n');
fprintf('Previously established CV R2   = 0.7987\n');


%% ============================================================
% SECTION 9 - CREATE SHAP EXPLAINER
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

if isprop(explainer,'Method')
    fprintf('SHAP method: %s\n', ...
        string(explainer.Method));
end


%% ============================================================
% SECTION 10 - CALCULATE SHAP VALUES
% ============================================================

fprintf('\n============================================\n');
fprintf('       CALCULATING SHAP VALUES\n');
fprintf('============================================\n\n');

fprintf('Calculating SHAP values for %d circuits...\n\n', ...
    nRows);

fitted_explainer = fit( ...
    explainer, ...
    Xmodel);

fprintf('SHAP calculation complete.\n');


%% ============================================================
% SECTION 11 - EXTRACT SHAP VALUES
% ============================================================

fprintf('\n============================================\n');
fprintf('       EXTRACTING SHAP VALUES\n');
fprintf('============================================\n\n');

shap_table = fitted_explainer.Shapley;

ValueData = shap_table.Value;

fprintf('Class of ValueData:\n');
disp(class(ValueData));

fprintf('Size of ValueData:\n');
disp(size(ValueData));

fprintf('Number of values:\n');
fprintf('%d\n', numel(ValueData));


% ------------------------------------------------------------
% MATLAB R2025b representation:
%
% ValueData = 9 x 660 numeric matrix
%
% Convert:
%
%       9 x 660
%
% into:
%
%       660 x 9
% ------------------------------------------------------------

if isnumeric(ValueData)

    [nr,nc] = size(ValueData);

    if nr == nFeatures && nc == nRows

        LocalSHAP = double(ValueData.');

    elseif nr == nRows && nc == nFeatures

        LocalSHAP = double(ValueData);

    else

        error( ...
            ['Unexpected SHAP matrix size: %d x %d. ' ...
             'Expected %d x %d or %d x %d.'], ...
             nr,nc, ...
             nFeatures,nRows, ...
             nRows,nFeatures);

    end


elseif iscell(ValueData)

    if numel(ValueData) ~= nFeatures
        error( ...
            'Expected %d SHAP cells, found %d.', ...
            nFeatures, numel(ValueData));
    end

    LocalSHAP = NaN(nRows,nFeatures);

    for k = 1:nFeatures

        v = double(ValueData{k}(:));

        if numel(v) ~= nRows
            error( ...
                'SHAP vector x%d has %d values, expected %d.', ...
                k,numel(v),nRows);
        end

        LocalSHAP(:,k) = v;

    end

else

    error( ...
        'Unsupported SHAP ValueData type: %s', ...
        class(ValueData));

end


%% ============================================================
% SECTION 12 - VALIDATE SHAP MATRIX
% ============================================================

fprintf('\n============================================\n');
fprintf('          VALIDATING SHAP MATRIX\n');
fprintf('============================================\n\n');

fprintf('LocalSHAP size:\n');
disp(size(LocalSHAP));

if ~isequal(size(LocalSHAP), ...
        [nRows nFeatures])

    error( ...
        'SHAP matrix has incorrect dimensions.');

end

if any(~isfinite(LocalSHAP(:)))

    error('SHAP contains NaN or Inf values.');

end

fprintf('SHAP matrix successfully extracted.\n');

fprintf('All SHAP values are finite.\n');


%% ============================================================
% SECTION 13 - FEATURE MAPPING
% ============================================================

fprintf('\n============================================\n');
fprintf('           SHAP FEATURE MAPPING\n');
fprintf('============================================\n\n');

for k = 1:nFeatures

    fprintf('x%d -> %s\n', ...
        k,features{k});

end


%% ============================================================
% SECTION 14 - SELECT IMPORTANT PARAMETERS
% ============================================================

% Based on global SHAP results:
%
% R1
% RE
% RC
% R2
% VCC
% RL
%
% These six parameters dominate the model explanation.

selected_features = { ...
    'R1', ...
    'RE', ...
    'RC', ...
    'R2', ...
    'VCC', ...
    'RL'};

nSelected = numel(selected_features);

selected_indices = zeros(1,nSelected);

for k = 1:nSelected

    idx = find( ...
        strcmp(features,selected_features{k}), ...
        1);

    if isempty(idx)
        error( ...
            'Selected feature not found: %s', ...
            selected_features{k});
    end

    selected_indices(k) = idx;

end


%% ============================================================
% SECTION 15 - CALCULATE PAIRWISE SHAP INTERACTION
% ============================================================

fprintf('\n============================================\n');
fprintf('       CALCULATING PAIRWISE INTERACTIONS\n');
fprintf('============================================\n\n');

% ------------------------------------------------------------
% Interaction matrix
%
% Rows:
%   SHAP contribution of parameter i
%
% Columns:
%   parameter j
%
% Entry:
%
%   |Spearman correlation(SHAP_i, X_j)|
%
% ------------------------------------------------------------

InteractionDirectional = zeros( ...
    nSelected, ...
    nSelected);

InteractionMatrix = zeros( ...
    nSelected, ...
    nSelected);

for i = 1:nSelected

    idx_i = selected_indices(i);

    shap_i = LocalSHAP(:,idx_i);

    for j = 1:nSelected

        idx_j = selected_indices(j);

        x_j = Xraw(:,idx_j);

        rho = corr( ...
            shap_i, ...
            x_j, ...
            'Type','Spearman', ...
            'Rows','complete');

        InteractionDirectional(i,j) = rho;

    end

end


% ------------------------------------------------------------
% Symmetrize pairwise interaction strength
% ------------------------------------------------------------

for i = 1:nSelected

    for j = 1:nSelected

        if i == j

            InteractionMatrix(i,j) = 0;

        else

            InteractionMatrix(i,j) = ...
                ( ...
                abs(InteractionDirectional(i,j)) + ...
                abs(InteractionDirectional(j,i)) ...
                ) / 2;

        end

    end

end


%% ============================================================
% SECTION 16 - DISPLAY INTERACTION MATRIX
% ============================================================

fprintf('\n============================================\n');
fprintf('          INTERACTION MATRIX\n');
fprintf('============================================\n\n');

fprintf('Rows / columns:\n');

disp(selected_features');

fprintf('\nInteraction strength matrix:\n');

disp(InteractionMatrix);


%% ============================================================
% SECTION 17 - RANK PARAMETER PAIRS
% ============================================================

fprintf('\n============================================\n');
fprintf('          INTERACTION RANKING\n');
fprintf('============================================\n\n');

pair_i = [];
pair_j = [];
pair_name_i = {};
pair_name_j = {};
pair_strength = [];
pair_direction_i_j = [];
pair_direction_j_i = [];

counter = 0;

for i = 1:nSelected

    for j = i+1:nSelected

        counter = counter + 1;

        pair_i(counter,1) = i;

        pair_j(counter,1) = j;

        pair_name_i{counter,1} = ...
            selected_features{i};

        pair_name_j{counter,1} = ...
            selected_features{j};

        pair_strength(counter,1) = ...
            InteractionMatrix(i,j);

        pair_direction_i_j(counter,1) = ...
            InteractionDirectional(i,j);

        pair_direction_j_i(counter,1) = ...
            InteractionDirectional(j,i);

    end

end


% Sort descending
[sorted_strength,order] = ...
    sort(pair_strength,'descend');

fprintf('%-6s %-8s %-8s %-15s\n', ...
    'Rank', ...
    'Param1', ...
    'Param2', ...
    'Strength');

fprintf('---------------------------------------------\n');

for k = 1:numel(order)

    idx = order(k);

    fprintf('%-6d %-8s %-8s %10.5f\n', ...
        k, ...
        pair_name_i{idx}, ...
        pair_name_j{idx}, ...
        sorted_strength(k));

end


%% ============================================================
% SECTION 18 - CREATE INTERACTION TABLE
% ============================================================

nPairs = numel(pair_strength);

Rank = (1:nPairs)';

Parameter1 = strings(nPairs,1);
Parameter2 = strings(nPairs,1);
InteractionStrength = zeros(nPairs,1);
Directional_1_to_2 = zeros(nPairs,1);
Directional_2_to_1 = zeros(nPairs,1);

for k = 1:nPairs

    idx = order(k);

    Parameter1(k) = ...
        string(pair_name_i{idx});

    Parameter2(k) = ...
        string(pair_name_j{idx});

    InteractionStrength(k) = ...
        pair_strength(idx);

    Directional_1_to_2(k) = ...
        pair_direction_i_j(idx);

    Directional_2_to_1(k) = ...
        pair_direction_j_i(idx);

end

InteractionTable = table( ...
    Rank, ...
    Parameter1, ...
    Parameter2, ...
    InteractionStrength, ...
    Directional_1_to_2, ...
    Directional_2_to_1);


%% ============================================================
% SECTION 19 - SAVE INTERACTION TABLE
% ============================================================

interaction_csv = fullfile( ...
    interaction_dir, ...
    'SHAP_Interaction_Ranking.csv');

writetable( ...
    InteractionTable, ...
    interaction_csv);

fprintf('\nSaved interaction ranking:\n%s\n', ...
    interaction_csv);


%% ============================================================
% SECTION 20 - CREATE HEATMAP
% ============================================================

fprintf('\n============================================\n');
fprintf('          CREATING INTERACTION HEATMAP\n');
fprintf('============================================\n\n');

fig_heatmap = figure( ...
    'Name', ...
    'SHAP Interaction Heatmap', ...
    'NumberTitle', ...
    'off');

imagesc(InteractionMatrix);

axis square;

colorbar;

xticks(1:nSelected);
yticks(1:nSelected);

xticklabels(selected_features);
yticklabels(selected_features);

xlabel('Parameter');
ylabel('Parameter');

title( ...
    'Pairwise SHAP Interaction Strength');

for i = 1:nSelected

    for j = 1:nSelected

        text( ...
            j, ...
            i, ...
            sprintf('%.2f',InteractionMatrix(i,j)), ...
            'HorizontalAlignment','center');

    end

end

drawnow;

heatmap_file = fullfile( ...
    interaction_dir, ...
    'SHAP_Interaction_Heatmap.png');

exportgraphics( ...
    fig_heatmap, ...
    heatmap_file, ...
    'Resolution',200);

fprintf('Saved:\n%s\n', ...
    heatmap_file);

close(fig_heatmap);


%% ============================================================
% SECTION 21 - TOP INTERACTION BAR PLOT
% ============================================================

fprintf('\n============================================\n');
fprintf('       CREATING TOP INTERACTION PLOT\n');
fprintf('============================================\n\n');

nTop = min(10,nPairs);

top_strength = sorted_strength(1:nTop);

top_labels = strings(nTop,1);

for k = 1:nTop

    idx = order(k);

    top_labels(k) = ...
        string(pair_name_i{idx}) + ...
        " - " + ...
        string(pair_name_j{idx});

end


fig_bar = figure( ...
    'Name', ...
    'Top SHAP Interactions', ...
    'NumberTitle', ...
    'off');

barh( ...
    1:nTop, ...
    flip(top_strength));

yticks(1:nTop);

yticklabels(flip(top_labels));

xlabel('Interaction Strength');

ylabel('Parameter Pair');

title( ...
    'Top SHAP Parameter Interactions');

grid on;

drawnow;

bar_file = fullfile( ...
    interaction_dir, ...
    'SHAP_Top_Interactions.png');

exportgraphics( ...
    fig_bar, ...
    bar_file, ...
    'Resolution',200);

fprintf('Saved:\n%s\n', ...
    bar_file);

close(fig_bar);


%% ============================================================
% SECTION 22 - SAVE MATLAB RESULTS
% ============================================================

Results = struct();

Results.DatasetFile = dataset_file;

Results.ModelFile = model_file;

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

Results.InteractionDirectional = ...
    InteractionDirectional;

Results.InteractionMatrix = ...
    InteractionMatrix;

Results.InteractionTable = ...
    InteractionTable;

Results.SelectedIndices = ...
    selected_indices;


results_mat = fullfile( ...
    interaction_dir, ...
    'SHAP_Interaction_Results.mat');

save( ...
    results_mat, ...
    'Results', ...
    '-v7.3');

fprintf('\nSaved MATLAB results:\n%s\n', ...
    results_mat);


%% ============================================================
% SECTION 23 - FINAL SUMMARY
% ============================================================

fprintf('\n============================================\n');
fprintf('       SHAP INTERACTION ANALYSIS COMPLETE\n');
fprintf('============================================\n\n');

fprintf('Dataset rows          : %d\n', nRows);

fprintf('Total features        : %d\n', nFeatures);

fprintf('Interaction features  : %d\n', nSelected);

fprintf('Parameter pairs       : %d\n', nPairs);

fprintf('\nTop interactions:\n');

for k = 1:min(5,nPairs)

    idx = order(k);

    fprintf( ...
        '  %d. %s <-> %s : %.5f\n', ...
        k, ...
        pair_name_i{idx}, ...
        pair_name_j{idx}, ...
        sorted_strength(k));

end

fprintf('\nOutput directory:\n%s\n', ...
    interaction_dir);

fprintf('\nGenerated files:\n');

fprintf('  SHAP_Interaction_Ranking.csv\n');

fprintf('  SHAP_Interaction_Results.mat\n');

fprintf('  SHAP_Interaction_Heatmap.png\n');

fprintf('  SHAP_Top_Interactions.png\n');

fprintf('\n============================================\n');
fprintf('                  DONE\n');
fprintf('============================================\n');
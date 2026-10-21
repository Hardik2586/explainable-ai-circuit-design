clear;
clc;
close all;

fprintf('\n');
fprintf('============================================\n');
fprintf('LOCAL SHAP ANALYSIS - CE AMPLIFIER\n');
fprintf('============================================\n');


%% ============================================================
% 1. PATHS
% ============================================================

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

dataset_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');

model_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_Boosted_Model.mat');

shap_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_SHAP_Results.mat');

output_dir = fullfile( ...
    project_dir, ...
    'output', ...
    'local_shap');

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end


%% ============================================================
% 2. CHECK FILES
% ============================================================

fprintf('\nChecking files...\n');

if ~exist(dataset_file,'file')
    error('Dataset not found:\n%s',dataset_file);
end

if ~exist(model_file,'file')
    error('ML model not found:\n%s',model_file);
end

if ~exist(shap_file,'file')
    error('SHAP results not found:\n%s',shap_file);
end

fprintf('Dataset       : OK\n');
fprintf('ML model      : OK\n');
fprintf('SHAP results  : OK\n');


%% ============================================================
% 3. LOAD DATASET
% ============================================================

fprintf('\nLoading dataset...\n');

T = readtable(dataset_file);

fprintf('Dataset rows = %d\n',height(T));

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

target_name = 'Gain_dB';

X = T(:,features);
Y = T.(target_name);

fprintf('Features = %d\n',numel(features));

fprintf('\nGain range:\n');
fprintf('Minimum = %.4f dB\n',min(Y));
fprintf('Maximum = %.4f dB\n',max(Y));
fprintf('Mean    = %.4f dB\n',mean(Y));
fprintf('Median  = %.4f dB\n',median(Y));


%% ============================================================
% 4. LOAD ML MODEL
% ============================================================

fprintf('\nLoading ML model...\n');

M = load(model_file);

fprintf('Variables in model file:\n');
disp(fieldnames(M));

% -------------------------------------------------------------
% The trained model is stored in the variable named "model"
% -------------------------------------------------------------

if ~isfield(M,'model')

    error( ...
        'Variable "model" was not found in ML model MAT file.');

end

model = M.model;

fprintf('\nML model loaded successfully.\n');

fprintf('Model class:\n');
disp(class(model));


%% ============================================================
% 5. PREPARE FEATURES FOR ML MODEL
% ============================================================


X_model = zeros(height(T),9);

for k = 1:8

    X_model(:,k) = ...
        log10(T.(features{k}));

end

X_model(:,9) = T.VCC;


%% ============================================================
% 6. VERIFY MODEL PREDICTIONS
% ============================================================

fprintf('\nGenerating ML predictions...\n');

Y_pred = predict(model,X_model);

prediction_error = Y_pred - Y;

RMSE = sqrt(mean(prediction_error.^2));

MAE = mean(abs(prediction_error));

R2 = 1 - ...
    sum((Y-Y_pred).^2) / ...
    sum((Y-mean(Y)).^2);

fprintf('\nModel verification:\n');
fprintf('R2   = %.4f\n',R2);
fprintf('RMSE = %.4f dB\n',RMSE);
fprintf('MAE  = %.4f dB\n',MAE);


%% ============================================================
% 7. SELECT THREE REPRESENTATIVE CIRCUITS
% ============================================================

% We select:
%
%   Low gain    = minimum gain
%   Medium gain = median gain
%   High gain   = maximum gain
%
% These are deliberately chosen from the valid dataset.

[~,idx_low] = min(Y);

[~,idx_high] = max(Y);

[~,sort_idx] = sort(Y);

idx_medium = ...
    sort_idx(round((height(T)+1)/2));

selected_indices = [ ...
    idx_low, ...
    idx_medium, ...
    idx_high];

case_names = { ...
    'Low_Gain', ...
    'Medium_Gain', ...
    'High_Gain'};


fprintf('\n');
fprintf('============================================\n');
fprintf('SELECTED CIRCUITS\n');
fprintf('============================================\n');

for c = 1:3

    idx = selected_indices(c);

    fprintf( ...
        '%d. %-12s Row = %d   SPICE Gain = %.4f dB\n', ...
        c, ...
        case_names{c}, ...
        idx, ...
        Y(idx));

end


%% ============================================================
% 8. LOAD GLOBAL SHAP RESULTS
% ============================================================

fprintf('\nLoading SHAP results...\n');

S = load(shap_file);

fprintf('SHAP variables:\n');
disp(fieldnames(S));


%% ============================================================
% 9. EXTRACT SHAP VALUES
% ============================================================

% We use SHAPResults for global values only.
%
% Local SHAP values are recalculated below for the selected
% circuits using MATLAB's shapley function.

if isfield(S,'SHAPResults')

    fprintf('\nGlobal SHAP results loaded.\n');

    disp(S.SHAPResults);

end


%% ============================================================
% 10. PREPARE LOCAL SHAP STORAGE
% ============================================================

LocalSHAP = ...
    NaN(3,9);

ActualGain = ...
    NaN(3,1);

PredictedGain = ...
    NaN(3,1);

PredictionError = ...
    NaN(3,1);

CircuitIndex = ...
    NaN(3,1);


%% ============================================================
% 11. CALCULATE LOCAL SHAP VALUES
% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('CALCULATING LOCAL SHAP VALUES\n');
fprintf('============================================\n');

for c = 1:3

    idx = selected_indices(c);

    fprintf('\n');
    fprintf('--------------------------------------------\n');
    fprintf('%s\n',case_names{c});
    fprintf('--------------------------------------------\n');

    fprintf('Dataset row       = %d\n',idx);

    ActualGain(c) = Y(idx);

    PredictedGain(c) = Y_pred(idx);

    PredictionError(c) = ...
        PredictedGain(c) - ActualGain(c);

    CircuitIndex(c) = idx;

    fprintf( ...
        'Actual gain      = %.6f dB\n', ...
        ActualGain(c));

    fprintf( ...
        'Predicted gain   = %.6f dB\n', ...
        PredictedGain(c));

    fprintf( ...
        'Prediction error = %.6f dB\n', ...
        PredictionError(c));

    %% --------------------------------------------------------
    % Query point
    % ---------------------------------------------------------

    query_point = X_model(idx,:);

    %% --------------------------------------------------------
    % Calculate SHAP
    % ---------------------------------------------------------

    fprintf('Calculating SHAP...\n');

    explainer = shapley( ...
        model, ...
        'QueryPoint',query_point);

    % ---------------------------------------------------------
    % Extract local SHAP values
    % ---------------------------------------------------------

    local_values = [];

    if isprop(explainer,'ShapleyValues')

        local_values = ...
            explainer.ShapleyValues;

    elseif isprop(explainer,'ShapleyValue')

        local_values = ...
            explainer.ShapleyValue;

    end

    if isempty(local_values)

        error( ...
            'Could not extract local SHAP values for %s.', ...
            case_names{c});

    end

    %% --------------------------------------------------------
    % Convert to numeric vector
    % ---------------------------------------------------------

    if istable(local_values)

        value_vars = ...
            local_values.Properties.VariableNames;

        % Find contribution column

        contribution_column = '';

        possible_columns = { ...
            'ShapleyValue', ...
            'ShapleyValues', ...
            'Value', ...
            'Contribution'};

        for j = 1:numel(possible_columns)

            if ismember( ...
                    possible_columns{j}, ...
                    value_vars)

                contribution_column = ...
                    possible_columns{j};

                break;

            end

        end

        if isempty(contribution_column)

            error( ...
                'Could not find SHAP contribution column.');

        end

        local_values = ...
            local_values.(contribution_column);

    end

    local_values = local_values(:);

    %% --------------------------------------------------------
    % Verify number of features
    % ---------------------------------------------------------

    if numel(local_values) ~= 9

        error( ...
            ['Expected 9 local SHAP values, but found %d ' ...
             'for %s.'], ...
            numel(local_values), ...
            case_names{c});

    end

    LocalSHAP(c,:) = local_values';

    %% --------------------------------------------------------
    % Display values
    % ---------------------------------------------------------

    fprintf('\nLocal SHAP contributions:\n');

    for k = 1:9

        fprintf( ...
            '  %-6s = %+10.6f dB\n', ...
            features{k}, ...
            LocalSHAP(c,k));

    end

    %% --------------------------------------------------------
    % Verify SHAP sum
    % ---------------------------------------------------------

    shap_sum = ...
        sum(LocalSHAP(c,:));

    fprintf('\n');
    fprintf( ...
        'Sum of SHAP values = %+0.6f dB\n', ...
        shap_sum);

end


%% ============================================================
% 12. CREATE LOCAL SHAP TABLE
% ============================================================

ResultsTable = table();

ResultsTable.Circuit_Type = ...
    string(case_names(:));

ResultsTable.Dataset_Row = ...
    CircuitIndex;

ResultsTable.Actual_Gain_dB = ...
    ActualGain;

ResultsTable.Predicted_Gain_dB = ...
    PredictedGain;

ResultsTable.Prediction_Error_dB = ...
    PredictionError;

for k = 1:9

    ResultsTable.( ...
        ['SHAP_' features{k}]) = ...
        LocalSHAP(:,k);

end


%% ============================================================
% 13. DISPLAY LOCAL SHAP SUMMARY
% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('LOCAL SHAP SUMMARY\n');
fprintf('============================================\n\n');

disp(ResultsTable);


%% ============================================================
% 14. SAVE RESULTS
% ============================================================

csv_file = fullfile( ...
    output_dir, ...
    'Local_SHAP_Results.csv');

mat_file = fullfile( ...
    output_dir, ...
    'Local_SHAP_Results.mat');

writetable( ...
    ResultsTable, ...
    csv_file);

save( ...
    mat_file, ...
    'ResultsTable', ...
    'LocalSHAP', ...
    'ActualGain', ...
    'PredictedGain', ...
    'PredictionError', ...
    'selected_indices', ...
    'features');


fprintf('\nResults saved:\n');
fprintf('%s\n',csv_file);
fprintf('%s\n',mat_file);


%% ============================================================
% 15. CREATE INDIVIDUAL LOCAL SHAP BAR PLOTS
% ============================================================

fprintf('\nGenerating local SHAP plots...\n');

for c = 1:3

    figure('Color','w');

    values = LocalSHAP(c,:);

    [sorted_values,order] = ...
        sort(values);

    labels = ...
        categorical( ...
            features(order), ...
            features(order));

    barh(labels,sorted_values);

    xlabel('SHAP contribution to predicted Gain (dB)');

    ylabel('Circuit Parameter');

    title( ...
        sprintf( ...
        'Local SHAP Explanation - %s', ...
        strrep(case_names{c},'_',' ')));

    grid on;

    % Add zero reference line

    hold on;

    xline(0,'k--','LineWidth',1);

    hold off;

    plot_file = fullfile( ...
        output_dir, ...
        [case_names{c} '_SHAP.png']);

    saveas( ...
        gcf, ...
        plot_file);

    close(gcf);

    fprintf( ...
        'Saved: %s\n', ...
        plot_file);

end


%% ============================================================
% 16. CREATE COMBINED COMPARISON PLOT
% ============================================================

figure('Color','w');

% Use mean absolute local SHAP across the 3 circuits

mean_local_shap = ...
    mean(abs(LocalSHAP),1);

[sorted_mean,order] = ...
    sort(mean_local_shap,'descend');

bar(sorted_mean);

xticks(1:9);

xticklabels(features(order));

xlabel('Parameter');

ylabel('Mean |Local SHAP| (dB)');

title( ...
    'Local SHAP Importance Across Selected Circuits');

grid on;

plot_file = fullfile( ...
    output_dir, ...
    'Local_SHAP_Overall.png');

saveas( ...
    gcf, ...
    plot_file);

close(gcf);


%% ============================================================
% 17. FINAL SUMMARY
% ============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('LOCAL SHAP ANALYSIS COMPLETE\n');
fprintf('============================================\n');

fprintf('\nSelected circuits:\n');

for c = 1:3

    fprintf( ...
        '%-12s | Actual = %8.4f dB | Predicted = %8.4f dB | Error = %+8.4f dB\n', ...
        case_names{c}, ...
        ActualGain(c), ...
        PredictedGain(c), ...
        PredictionError(c));

end

fprintf('\nOutput directory:\n');
fprintf('%s\n',output_dir);

fprintf('\nGenerated files:\n');
fprintf('  Local_SHAP_Results.csv\n');
fprintf('  Local_SHAP_Results.mat\n');
fprintf('  Low_Gain_SHAP.png\n');
fprintf('  Medium_Gain_SHAP.png\n');
fprintf('  High_Gain_SHAP.png\n');
fprintf('  Local_SHAP_Overall.png\n');

fprintf('\n============================================\n');
fprintf('DONE\n');
fprintf('============================================\n');
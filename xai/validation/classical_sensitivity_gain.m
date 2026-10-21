clear;
clc;
close all;


%% ============================================================
% 1. HEADER
% =============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('CLASSICAL SPICE SENSITIVITY ANALYSIS\n');
fprintf('============================================\n\n');


%% ============================================================
% 2. PROJECT PATHS
% =============================================================

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);


dataset_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');


model_path = fullfile( ...
    project_dir, ...
    'models', ...
    '2N3904.lib');


output_dir = fullfile( ...
    project_dir, ...
    'output', ...
    'classical_sensitivity');


ngspice_exe = ...
    'C:\ngspice-47_64\bin\ngspice_con.exe';


%% ============================================================
% 3. CONFIGURATION
% =============================================================

perturbation = 0.01;

ac_points_per_decade = 20;

ac_fstart = 10;

ac_fstop = 1e9;

temperature = 27;


%% ============================================================
% 4. CREATE OUTPUT DIRECTORY
% =============================================================

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end


%% ============================================================
% 5. CHECK FILES
% =============================================================

fprintf('Checking files...\n');

if exist(dataset_file,'file')

    fprintf('Dataset       : OK\n');

else

    error( ...
        'Dataset not found:\n%s', ...
        dataset_file);

end


if exist(model_path,'file')

    fprintf('2N3904 model  : OK\n');

else

    error( ...
        '2N3904 model not found:\n%s', ...
        model_path);

end


if exist(ngspice_exe,'file')

    fprintf('ngspice       : OK\n');

else

    error( ...
        'ngspice executable not found:\n%s', ...
        ngspice_exe);

end


%% ============================================================
% 6. LOAD DATASET
% =============================================================

D = readtable(dataset_file);


fprintf('\n');
fprintf('Dataset rows: %d\n',height(D));


fprintf('\nDataset columns:\n');
disp(D.Properties.VariableNames);


%% ============================================================
% 7. DESIGN PARAMETERS
% =============================================================

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


n_features = numel(features);


%% ============================================================
% 8. CHECK DATASET COLUMNS
% =============================================================

for k = 1:n_features

    if ~ismember( ...
            features{k}, ...
            D.Properties.VariableNames)

        error( ...
            'Required dataset column not found: %s', ...
            features{k});

    end

end


if ~ismember( ...
        'Gain_dB', ...
        D.Properties.VariableNames)

    error( ...
        'Required dataset column not found: Gain_dB');

end


%% ============================================================
% 9. REMOVE NON-FINITE ROWS
% =============================================================

valid_rows = true(height(D),1);


for k = 1:n_features

    x = D.(features{k});

    valid_rows = ...
        valid_rows & ...
        isfinite(x);

end


valid_rows = ...
    valid_rows & ...
    isfinite(D.Gain_dB);


D = D(valid_rows,:);


fprintf('\n');
fprintf('Finite rows available: %d\n',height(D));


if height(D) < 5

    error( ...
        'Not enough valid dataset rows.');

end


%% ============================================================
% 10. SORT BY GAIN
% =============================================================

D = sortrows(D,'Gain_dB');


%% ============================================================
% 11. SELECT REPRESENTATIVE CIRCUITS
%
% Minimum
% ~25th percentile
% Median
% ~75th percentile
% Maximum
%
%% ============================================================

n = height(D);


rep_indices = [ ...
    1, ...
    round(0.25*n), ...
    round(0.50*n), ...
    round(0.75*n), ...
    n];


rep_indices = ...
    unique(rep_indices,'stable');


n_circuits = ...
    numel(rep_indices);


fprintf('\n');
fprintf('Selected representative circuits:\n');
fprintf('--------------------------------------------\n');


for c = 1:n_circuits

    fprintf( ...
        '%d. Representative_%d     Gain = %.4f dB\n', ...
        c, ...
        c, ...
        D.Gain_dB(rep_indices(c)));

end


%% ============================================================
% 12. SIMULATION PLAN
% =============================================================

baseline_runs = n_circuits;

plus_runs = ...
    n_circuits*n_features;

minus_runs = ...
    n_circuits*n_features;

total_runs = ...
    baseline_runs + ...
    plus_runs + ...
    minus_runs;


fprintf('\n');
fprintf('============================================\n');
fprintf('SIMULATION PLAN\n');
fprintf('============================================\n');


fprintf( ...
    'Representative circuits : %d\n', ...
    n_circuits);


fprintf( ...
    'Parameters              : %d\n', ...
    n_features);


fprintf( ...
    'Baseline simulations    : %d\n', ...
    baseline_runs);


fprintf( ...
    '+1%% simulations         : %d\n', ...
    plus_runs);


fprintf( ...
    '-1%% simulations         : %d\n', ...
    minus_runs);


fprintf( ...
    'Total SPICE runs        : %d\n', ...
    total_runs);


fprintf( ...
    'Perturbation            : +/- %.1f%%\n', ...
    perturbation*100);


fprintf( ...
    'Frequency range         : %.4g Hz - %.4g Hz\n', ...
    ac_fstart, ...
    ac_fstop);


%% ============================================================
% 13. PREALLOCATE RESULTS
% =============================================================

DatasetGain_dB = ...
    nan(n_circuits,1);


BaselineGain_dB = ...
    nan(n_circuits,1);


PlusGain_dB = ...
    nan(n_circuits,n_features);


MinusGain_dB = ...
    nan(n_circuits,n_features);


Sensitivity = ...
    nan(n_circuits,n_features);


%% ============================================================
% 14. MAIN REPRESENTATIVE CIRCUIT LOOP
% =============================================================

for c = 1:n_circuits

    fprintf('\n');
    fprintf('============================================\n');

    fprintf( ...
        'CIRCUIT %d/%d: Representative_%d\n', ...
        c, ...
        n_circuits, ...
        c);

    fprintf('============================================\n\n');


    %% --------------------------------------------------------
    % Extract dataset row
    % ---------------------------------------------------------

    row = ...
        D(rep_indices(c),:);


    %% --------------------------------------------------------
    % Build parameter structure
    % ---------------------------------------------------------

    p = struct();


    for k = 1:n_features

        parameter_name = ...
            features{k};

        p.(parameter_name) = ...
            row.(parameter_name);

    end


    p.Temperature = temperature;


    %% --------------------------------------------------------
    % Display parameters
    % ---------------------------------------------------------

    fprintf('Circuit parameters:\n');


    fprintf( ...
        'R1   = %.8g Ohm\n', ...
        p.R1);


    fprintf( ...
        'R2   = %.8g Ohm\n', ...
        p.R2);


    fprintf( ...
        'RC   = %.8g Ohm\n', ...
        p.RC);


    fprintf( ...
        'RE   = %.8g Ohm\n', ...
        p.RE);


    fprintf( ...
        'RL   = %.8g Ohm\n', ...
        p.RL);


    fprintf( ...
        'Cin  = %.8g F\n', ...
        p.Cin);


    fprintf( ...
        'Cout = %.8g F\n', ...
        p.Cout);


    fprintf( ...
        'Ce   = %.8g F\n', ...
        p.Ce);


    fprintf( ...
        'VCC  = %.8g V\n', ...
        p.VCC);


    %% --------------------------------------------------------
    % Dataset gain
    % ---------------------------------------------------------

    DatasetGain_dB(c) = ...
        row.Gain_dB;


    DatasetGainLinear = ...
        10^(DatasetGain_dB(c)/20);


    fprintf('\n');


    fprintf( ...
        'Dataset Gain = %.6f dB\n', ...
        DatasetGain_dB(c));


    fprintf( ...
        'Dataset linear Gain = %.6f\n', ...
        DatasetGainLinear);


    %% --------------------------------------------------------
    % Dedicated directory
    % ---------------------------------------------------------

    circuit_dir = ...
        fullfile( ...
            output_dir, ...
            sprintf( ...
                'Representative_%d', ...
                c));


    if ~exist(circuit_dir,'dir')
        mkdir(circuit_dir);
    end


    %% ========================================================
    % BASELINE SIMULATION
    % ========================================================

    fprintf('\n');
    fprintf('Running baseline SPICE...\n');


    run_id = sprintf( ...
        'Representative_%d_baseline', ...
        c);


    result = run_spice_direct( ...
        p, ...
        run_id, ...
        circuit_dir, ...
        model_path, ...
        ngspice_exe, ...
        ac_points_per_decade, ...
        ac_fstart, ...
        ac_fstop);


    if ~result.success

        fprintf('\n');
        fprintf('BASELINE FAILED:\n');
        fprintf('%s\n',result.message);

        continue;

    end


    BaselineGain_dB(c) = ...
        result.gain_dB;


    %% --------------------------------------------------------
    % Compare baseline to dataset
    % ---------------------------------------------------------

    difference = ...
        BaselineGain_dB(c) - ...
        DatasetGain_dB(c);


    fprintf('\n');


    fprintf( ...
        'Baseline SPICE Gain = %.6f dB\n', ...
        BaselineGain_dB(c));


    fprintf( ...
        'Dataset Gain        = %.6f dB\n', ...
        DatasetGain_dB(c));


    fprintf( ...
        'Difference          = %.6f dB\n', ...
        difference);


    %% ========================================================
    % PARAMETER LOOP
    % ========================================================

    for k = 1:n_features

        parameter_name = ...
            features{k};


        fprintf('\n');


        fprintf( ...
            'Parameter %d/%d: %s\n', ...
            k, ...
            n_features, ...
            parameter_name);


        original_value = ...
            p.(parameter_name);


        %% ====================================================
        % +1%
        % ====================================================

        p_plus = p;


        p_plus.(parameter_name) = ...
            original_value * ...
            (1 + perturbation);


        run_id_plus = sprintf( ...
            'Representative_%d_%s_plus1pct', ...
            c, ...
            parameter_name);


        fprintf('+1%% simulation...\n');


        result_plus = ...
            run_spice_direct( ...
                p_plus, ...
                run_id_plus, ...
                circuit_dir, ...
                model_path, ...
                ngspice_exe, ...
                ac_points_per_decade, ...
                ac_fstart, ...
                ac_fstop);


        if result_plus.success

            PlusGain_dB(c,k) = ...
                result_plus.gain_dB;


            fprintf( ...
                '  Gain = %.6f dB\n', ...
                PlusGain_dB(c,k));

        else

            fprintf( ...
                '  FAILED: %s\n', ...
                result_plus.message);

        end


        %% ====================================================
        % -1%
        % ====================================================

        p_minus = p;


        p_minus.(parameter_name) = ...
            original_value * ...
            (1 - perturbation);


        run_id_minus = sprintf( ...
            'Representative_%d_%s_minus1pct', ...
            c, ...
            parameter_name);


        fprintf('-1%% simulation...\n');


        result_minus = ...
            run_spice_direct( ...
                p_minus, ...
                run_id_minus, ...
                circuit_dir, ...
                model_path, ...
                ngspice_exe, ...
                ac_points_per_decade, ...
                ac_fstart, ...
                ac_fstop);


        if result_minus.success

            MinusGain_dB(c,k) = ...
                result_minus.gain_dB;


            fprintf( ...
                '  Gain = %.6f dB\n', ...
                MinusGain_dB(c,k));

        else

            fprintf( ...
                '  FAILED: %s\n', ...
                result_minus.message);

        end


        %% ====================================================
        % CALCULATE CLASSICAL NORMALIZED SENSITIVITY
        % ====================================================

        if ...
            isfinite( ...
            PlusGain_dB(c,k)) && ...
            isfinite( ...
            MinusGain_dB(c,k)) && ...
            isfinite( ...
            BaselineGain_dB(c))


            % Convert dB gain to linear voltage gain.

            A_plus = ...
                10^(PlusGain_dB(c,k)/20);


            A_minus = ...
                10^(MinusGain_dB(c,k)/20);


            A0 = ...
                10^(BaselineGain_dB(c)/20);


            % Normalized sensitivity:
            %
            % Sx = (x/y)*(dy/dx)
            %
            % Central finite difference:
            %
            % Sx ~= (A+ - A-) /
            %       (2*delta*A0)

            Sensitivity(c,k) = ...
                (A_plus - A_minus) / ...
                (2 * perturbation * A0);


            fprintf( ...
                '  Sensitivity = %+ .6f\n', ...
                Sensitivity(c,k));

        end

    end

end


%% ============================================================
% 15. BASELINE RESULTS
% =============================================================

successful_baselines = ...
    sum(isfinite(BaselineGain_dB));


fprintf('\n');
fprintf('============================================\n');
fprintf('BASELINE RESULTS\n');
fprintf('============================================\n');


fprintf( ...
    'Successful baselines: %d / %d\n', ...
    successful_baselines, ...
    n_circuits);


if successful_baselines == 0

    fprintf('\n');
    fprintf('NO BASELINE SPICE SIMULATION SUCCEEDED.\n');

    fprintf('\n');
    fprintf('Inspect the generated files in:\n');

    fprintf( ...
        '%s\n', ...
        output_dir);

    error( ...
        'All baseline SPICE simulations failed.');

end


%% ============================================================
% 16. BASELINE COMPARISON
% =============================================================

Representative = ...
    strings(n_circuits,1);


for c = 1:n_circuits

    Representative(c) = ...
        sprintf( ...
            'Representative_%d', ...
            c);

end


BaselineDifference_dB = ...
    BaselineGain_dB - ...
    DatasetGain_dB;


BaselineTable = table( ...
    Representative, ...
    DatasetGain_dB, ...
    BaselineGain_dB, ...
    BaselineDifference_dB, ...
    'VariableNames', ...
    { ...
    'Circuit', ...
    'Dataset_Gain_dB', ...
    'SPICE_Gain_dB', ...
    'Difference_dB'});


fprintf('\n');
fprintf('Baseline comparison:\n');


disp(BaselineTable);


writetable( ...
    BaselineTable, ...
    fullfile( ...
        output_dir, ...
        'Baseline_Comparison.csv'));


%% ============================================================
% 17. GLOBAL CLASSICAL SENSITIVITY
% =============================================================

GlobalSensitivity = ...
    nan(n_features,1);


for k = 1:n_features

    values = ...
        Sensitivity(:,k);


    values = ...
        values(isfinite(values));


    if ~isempty(values)

        GlobalSensitivity(k) = ...
            mean(abs(values));

    end

end


%% ============================================================
% 18. CLASSICAL SENSITIVITY RANK
% =============================================================

[sorted_sensitivity,order] = ...
    sort( ...
        GlobalSensitivity, ...
        'descend', ...
        'MissingPlacement', ...
        'last');


ClassicalRank = ...
    nan(n_features,1);


for k = 1:n_features

    ClassicalRank(order(k)) = k;

end


fprintf('\n');
fprintf('============================================\n');
fprintf('GLOBAL CLASSICAL SENSITIVITY RANKING\n');
fprintf('============================================\n\n');


for k = 1:n_features

    idx = order(k);


    fprintf( ...
        '%d. %-6s Mean |Sensitivity| = %.6f\n', ...
        k, ...
        features{idx}, ...
        sorted_sensitivity(k));

end


%% ============================================================
% 19. SAVE CLASSICAL SENSITIVITY CSV
% =============================================================

SensitivityTable = table( ...
    string(features(:)), ...
    GlobalSensitivity, ...
    ClassicalRank, ...
    'VariableNames', ...
    { ...
    'Parameter', ...
    'MeanAbsSensitivity', ...
    'Rank'});


SensitivityTable = ...
    sortrows( ...
        SensitivityTable, ...
        'Rank');


writetable( ...
    SensitivityTable, ...
    fullfile( ...
        output_dir, ...
        'Classical_Sensitivity_Importance.csv'));


%% ============================================================
% 20. REPRESENTATIVE SENSITIVITY CSV
% =============================================================

RepresentativeSensitivity = ...
    table(Representative);


for k = 1:n_features

    RepresentativeSensitivity.( ...
        features{k}) = ...
        Sensitivity(:,k);

end


writetable( ...
    RepresentativeSensitivity, ...
    fullfile( ...
        output_dir, ...
        'Representative_Sensitivities.csv'));


%% ============================================================
% 21. SHAP COMPARISON
% =============================================================

%% ============================================================
% SHAP COMPARISON
% ============================================================

shap_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_SHAP_Results.mat');

rho = NaN;
ComparisonTable = table();

if exist(shap_file,'file')

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('SHAP COMPARISON\n');
    fprintf('============================================\n');

    %% --------------------------------------------------------
    % Load SHAP results
    % ---------------------------------------------------------

    S = load(shap_file);

    fprintf('\nVariables found in SHAP result file:\n');
    disp(fieldnames(S));

    %% --------------------------------------------------------
    % Initialize SHAP importance
    % ---------------------------------------------------------

    SHAPImportance = nan(n_features,1);

    %% ========================================================
    % CASE 1:
    % SHAPResults is a table
    % ========================================================

    if isfield(S,'SHAPResults') && istable(S.SHAPResults)

        SHAPResults = S.SHAPResults;

        fprintf('\nSHAPResults columns:\n');
        disp(SHAPResults.Properties.VariableNames);

        vars = SHAPResults.Properties.VariableNames;

        %% ----------------------------------------------------
        % Find parameter column
        % -----------------------------------------------------

        parameter_column = '';

        possible_parameter_columns = { ...
            'Parameter', ...
            'Feature', ...
            'FeatureName', ...
            'Variable', ...
            'VariableName', ...
            'Name'};

        for i = 1:numel(possible_parameter_columns)

            candidate_name = ...
                possible_parameter_columns{i};

            if ismember(candidate_name,vars)

                parameter_column = ...
                    candidate_name;

                break;

            end

        end

        %% ----------------------------------------------------
        % Find SHAP importance column
        % -----------------------------------------------------

        importance_column = '';

        possible_importance_columns = { ...
            'MeanAbsSHAP', ...
            'MeanAbsShap', ...
            'MeanAbsoluteSHAP', ...
            'MeanAbsoluteShap', ...
            'MeanAbsImportance', ...
            'SHAPImportance', ...
            'Importance', ...
            'MeanAbsValue', ...
            'MeanAbsoluteValue'};

        for i = 1:numel(possible_importance_columns)

            candidate_name = ...
                possible_importance_columns{i};

            if ismember(candidate_name,vars)

                importance_column = ...
                    candidate_name;

                break;

            end

        end

        %% ----------------------------------------------------
        % Display detected columns
        % -----------------------------------------------------

        fprintf('\nDetected parameter column:\n');

        if isempty(parameter_column)

            fprintf('  NONE\n');

        else

            fprintf( ...
                '  %s\n', ...
                parameter_column);

        end

        fprintf('Detected SHAP importance column:\n');

        if isempty(importance_column)

            fprintf('  NONE\n');

        else

            fprintf( ...
                '  %s\n', ...
                importance_column);

        end

        %% ====================================================
        % EXTRACT SHAP VALUES
        % ====================================================

        if ~isempty(parameter_column) && ...
           ~isempty(importance_column)

            parameter_values = ...
                string( ...
                SHAPResults.(parameter_column));

            importance_values = ...
                SHAPResults.(importance_column);

            % Convert possible nonnumeric values
            if ~isnumeric(importance_values)

                importance_values = ...
                    str2double( ...
                    string(importance_values));

            end

            %% ------------------------------------------------
            % IMPORTANT:
            % MATLAB SHAP file uses x1...x9.
            %
            % x1 = R1
            % x2 = R2
            % x3 = RC
            % x4 = RE
            % x5 = RL
            % x6 = Cin
            % x7 = Cout
            % x8 = Ce
            % x9 = VCC
            % -------------------------------------------------

            fprintf('\nSHAP parameter mapping:\n');
            fprintf('  x1 -> R1\n');
            fprintf('  x2 -> R2\n');
            fprintf('  x3 -> RC\n');
            fprintf('  x4 -> RE\n');
            fprintf('  x5 -> RL\n');
            fprintf('  x6 -> Cin\n');
            fprintf('  x7 -> Cout\n');
            fprintf('  x8 -> Ce\n');
            fprintf('  x9 -> VCC\n');

            %% ------------------------------------------------
            % Explicit mapping
            % -------------------------------------------------

            shap_names = { ...
                'x1', ...
                'x2', ...
                'x3', ...
                'x4', ...
                'x5', ...
                'x6', ...
                'x7', ...
                'x8', ...
                'x9'};

            actual_names = { ...
                'R1', ...
                'R2', ...
                'RC', ...
                'RE', ...
                'RL', ...
                'Cin', ...
                'Cout', ...
                'Ce', ...
                'VCC'};

            %% ------------------------------------------------
            % Match SHAP x-values to actual parameters
            % -------------------------------------------------

            for k = 1:n_features

                parameter_name = ...
                    string(actual_names{k});

                shap_name = ...
                    string(shap_names{k});

                idx = strcmpi( ...
                    strtrim(parameter_values), ...
                    shap_name);

                if any(idx)

                    first_match = ...
                        find(idx,1);

                    SHAPImportance(k) = ...
                        importance_values(first_match);

                end

            end

        end

    %% ========================================================
    % CASE 2:
    % SHAP importance is stored as a standalone vector
    % ========================================================

    else

        fprintf('\n');
        fprintf('SHAPResults table not found.\n');

        fprintf( ...
            'Searching for SHAP importance vector...\n');

        possible_vectors = { ...
            'MeanAbsSHAP', ...
            'SHAPImportance', ...
            'GlobalSHAPImportance', ...
            'meanAbsSHAP', ...
            'mean_abs_shap', ...
            'MeanAbsoluteSHAP', ...
            'Importance'};

        for i = 1:numel(possible_vectors)

            variable_name = ...
                possible_vectors{i};

            if isfield(S,variable_name)

                candidate = ...
                    S.(variable_name);

                if isnumeric(candidate) && ...
                   numel(candidate) == n_features

                    SHAPImportance = ...
                        candidate(:);

                    fprintf('\n');
                    fprintf( ...
                        'SHAP vector found in variable:\n');

                    fprintf( ...
                        '  %s\n', ...
                        variable_name);

                    break;

                end

            end

        end

    end

    %% ========================================================
    % CHECK SHAP EXTRACTION
    % ========================================================

    fprintf('\n');
    fprintf('Extracted SHAP importance:\n');

    for k = 1:n_features

        fprintf( ...
            '  %-6s = %.8f\n', ...
            features{k}, ...
            SHAPImportance(k));

    end

    %% ========================================================
    % CHECK FOR MISSING VALUES
    % ========================================================

    shap_valid = ...
        isfinite(SHAPImportance);

    if sum(shap_valid) < 3

        fprintf('\n');
        fprintf( ...
            'ERROR: Not enough SHAP values were extracted.\n');

        fprintf( ...
            'Valid SHAP parameters = %d / %d\n', ...
            sum(shap_valid), ...
            n_features);

        fprintf('\nAvailable variables in MAT file:\n');
        disp(fieldnames(S));

        if isfield(S,'SHAPResults')

            fprintf('\nSHAPResults content:\n');
            disp(S.SHAPResults);

        end

    else

        %% ====================================================
        % SHAP RANKING
        % ====================================================

        [~,shap_order] = ...
            sort( ...
                SHAPImportance, ...
                'descend', ...
                'MissingPlacement','last');

        SHAPRank = ...
            nan(n_features,1);

        for k = 1:n_features

            idx = ...
                shap_order(k);

            if isfinite(SHAPImportance(idx))

                SHAPRank(idx) = k;

            end

        end

        %% ====================================================
        % DISPLAY SHAP RANKING
        % ====================================================

        fprintf('\n');
        fprintf('============================================\n');
        fprintf('GLOBAL SHAP IMPORTANCE RANKING\n');
        fprintf('============================================\n\n');

        for k = 1:n_features

            idx = ...
                shap_order(k);

            if isfinite(SHAPImportance(idx))

                fprintf( ...
                    '%d. %-6s Mean |SHAP| = %.6f\n', ...
                    k, ...
                    features{idx}, ...
                    SHAPImportance(idx));

            end

        end

        %% ====================================================
        % CREATE COMPARISON TABLE
        % ====================================================

        ComparisonTable = table( ...
            string(features(:)), ...
            GlobalSensitivity, ...
            ClassicalRank, ...
            SHAPImportance, ...
            SHAPRank, ...
            'VariableNames', ...
            { ...
            'Parameter', ...
            'Classical_MeanAbsSensitivity', ...
            'Classical_Rank', ...
            'SHAP_MeanAbs', ...
            'SHAP_Rank'});

        %% ====================================================
        % SORT BY CLASSICAL RANK
        % ====================================================

        ComparisonTable = ...
            sortrows( ...
                ComparisonTable, ...
                'Classical_Rank');

        %% ====================================================
        % DISPLAY COMPARISON
        % ====================================================

        fprintf('\n');
        fprintf('============================================\n');
        fprintf('CLASSICAL SENSITIVITY VS SHAP\n');
        fprintf('============================================\n\n');

        disp(ComparisonTable);

        %% ====================================================
        % SAVE COMPARISON CSV
        % ====================================================

        comparison_file = ...
            fullfile( ...
                output_dir, ...
                'Sensitivity_vs_SHAP.csv');

        writetable( ...
            ComparisonTable, ...
            comparison_file);

        fprintf('\n');
        fprintf('Comparison saved to:\n');
        fprintf('%s\n',comparison_file);

        %% ====================================================
        % SPEARMAN RANK CORRELATION
        % ====================================================

        comparison_valid = ...
            isfinite(ClassicalRank) & ...
            isfinite(SHAPRank);

        n_compared = ...
            sum(comparison_valid);

        if n_compared >= 3

            rho = corr( ...
                ClassicalRank(comparison_valid), ...
                SHAPRank(comparison_valid), ...
                'Type','Spearman');

            fprintf('\n');
            fprintf('============================================\n');
            fprintf('RANK CORRELATION\n');
            fprintf('============================================\n\n');

            fprintf( ...
                'Spearman rank correlation = %.4f\n', ...
                rho);

            fprintf( ...
                'Parameters compared       = %d\n', ...
                n_compared);

            %% ------------------------------------------------
            % Interpretation
            % -------------------------------------------------

            if rho >= 0.80

                interpretation = ...
                    'Strong agreement';

            elseif rho >= 0.60

                interpretation = ...
                    'Moderate-to-strong agreement';

            elseif rho >= 0.40

                interpretation = ...
                    'Moderate agreement';

            elseif rho >= 0

                interpretation = ...
                    'Weak agreement';

            else

                interpretation = ...
                    'Inverse/poor agreement';

            end

            fprintf( ...
                'Interpretation             = %s\n', ...
                interpretation);

        else

            fprintf('\n');
            fprintf( ...
                'Spearman correlation unavailable.\n');

            fprintf( ...
                'Fewer than 3 valid parameters.\n');

        end

    end

else

    fprintf('\n');
    fprintf( ...
        'SHAP results not found:\n%s\n', ...
        shap_file);

end


%% ============================================================
% 22. SAVE COMPLETE RESULTS
% =============================================================

save( ...
    fullfile( ...
        output_dir, ...
        'Classical_Sensitivity_Gain_Results.mat'), ...
    'features', ...
    'Representative', ...
    'rep_indices', ...
    'DatasetGain_dB', ...
    'BaselineGain_dB', ...
    'PlusGain_dB', ...
    'MinusGain_dB', ...
    'Sensitivity', ...
    'GlobalSensitivity', ...
    'ClassicalRank', ...
    'BaselineTable', ...
    'SensitivityTable', ...
    'rho');


%% ============================================================
% 23. CLASSICAL SENSITIVITY PLOT
% =============================================================

figure;


bar(GlobalSensitivity);


set(gca, ...
    'XTick',1:n_features, ...
    'XTickLabel',features);


xlabel( ...
    'Circuit Parameter');


ylabel( ...
    'Mean Absolute Normalized Sensitivity');


title( ...
    'Classical SPICE Sensitivity of CE Amplifier Gain');


grid on;


classical_plot = ...
    fullfile( ...
        output_dir, ...
        'Classical_Sensitivity_Bar.png');


saveas( ...
    gcf, ...
    classical_plot);


fprintf('\n');
fprintf('Classical sensitivity plot saved to:\n');
fprintf('%s\n',classical_plot);


%% ============================================================
% 24. SHAP VS CLASSICAL RANK PLOT
% =============================================================

if exist('ComparisonTable','var') && ...
   height(ComparisonTable) >= 3


    figure;


    %% --------------------------------------------------------
    % Actual rank points
    % ---------------------------------------------------------

    plot( ...
        ComparisonTable.Classical_Rank, ...
        ComparisonTable.SHAP_Rank, ...
        'o', ...
        'MarkerSize',8);


    hold on;


    %% --------------------------------------------------------
    % Perfect agreement line
    % ---------------------------------------------------------

    plot( ...
        1:n_features, ...
        1:n_features, ...
        '--');


    hold off;


    %% --------------------------------------------------------
    % Axis labels
    % ---------------------------------------------------------

    xlabel( ...
        'Classical SPICE Sensitivity Rank');


    ylabel( ...
        'SHAP Importance Rank');


    title( ...
        'Classical Sensitivity Rank vs SHAP Rank');


    %% --------------------------------------------------------
    % Axis limits
    % ---------------------------------------------------------

    xlim([0.5 n_features+0.5]);

    ylim([0.5 n_features+0.5]);


    xticks(1:n_features);

    yticks(1:n_features);


    %% --------------------------------------------------------
    % Grid
    % ---------------------------------------------------------

    grid on;


    %% --------------------------------------------------------
    % Save figure
    % ---------------------------------------------------------

    shap_rank_plot = ...
        fullfile( ...
            output_dir, ...
            'Sensitivity_vs_SHAP_Rank.png');


    saveas( ...
        gcf, ...
        shap_rank_plot);


    fprintf('\n');
    fprintf('SHAP vs classical rank plot saved to:\n');
    fprintf('%s\n',shap_rank_plot);

end


%% ============================================================
% 25. FINAL SUMMARY
% =============================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('============================================\n\n');


fprintf( ...
    'Output directory:\n%s\n\n', ...
    output_dir);


fprintf('Generated files:\n');


fprintf( ...
    '  Baseline_Comparison.csv\n');


fprintf( ...
    '  Classical_Sensitivity_Importance.csv\n');


fprintf( ...
    '  Representative_Sensitivities.csv\n');


fprintf( ...
    '  Classical_Sensitivity_Gain_Results.mat\n');


fprintf( ...
    '  Classical_Sensitivity_Bar.png\n');


if exist( ...
        fullfile( ...
        output_dir, ...
        'Sensitivity_vs_SHAP.csv'), ...
        'file')

    fprintf( ...
        '  Sensitivity_vs_SHAP.csv\n');

end


if exist( ...
        fullfile( ...
        output_dir, ...
        'Sensitivity_vs_SHAP_Rank.png'), ...
        'file')

    fprintf( ...
        '  Sensitivity_vs_SHAP_Rank.png\n');

end


if isfinite(rho)

    fprintf('\n');

    fprintf( ...
        'Spearman rank correlation = %.4f\n', ...
        rho);

end


fprintf('\n');


%% ============================================================
% LOCAL FUNCTION
% DIRECT NGSPICE SIMULATION
% =============================================================

function result = run_spice_direct( ...
    p, ...
    run_id, ...
    work_dir, ...
    model_path, ...
    ngspice_exe, ...
    ac_points_per_decade, ...
    ac_fstart, ...
    ac_fstop)


%% ============================================================
% INITIALIZE
% =============================================================

result.success = false;

result.gain_dB = NaN;

result.message = '';


%% ============================================================
% FILE NAMES
% =============================================================

netlist_file = ...
    [run_id '.cir'];


gain_file = ...
    [run_id '_gain.txt'];


phase_file = ...
    [run_id '_phase.txt'];


log_file = ...
    [run_id '_ngspice.log'];


netlist_path = ...
    fullfile(work_dir,netlist_file);


gain_path = ...
    fullfile(work_dir,gain_file);


phase_path = ...
    fullfile(work_dir,phase_file);


log_path = ...
    fullfile(work_dir,log_file);


%% ============================================================
% DELETE OLD OUTPUTS
% =============================================================

if exist(gain_path,'file')
    delete(gain_path);
end


if exist(phase_path,'file')
    delete(phase_path);
end


if exist(netlist_path,'file')
    delete(netlist_path);
end


%% ============================================================
% SPICE-SAFE MODEL PATH
% =============================================================

model_spice = ...
    strrep(model_path,'\','/');


%% ============================================================
% WRITE NETLIST
% =============================================================

fid = fopen(netlist_path,'w');


if fid < 0

    result.message = ...
        ['Could not create netlist: ' ...
         netlist_path];

    return;

end


%% ------------------------------------------------------------
% Header
% ------------------------------------------------------------

fprintf( ...
    fid, ...
    '* Classical sensitivity simulation - %s\n', ...
    run_id);


fprintf( ...
    fid, ...
    '.include "%s"\n', ...
    model_spice);


fprintf( ...
    fid, ...
    '.options TEMP=27 TNOM=27\n\n');


%% ============================================================
% CIRCUIT
% =============================================================

fprintf( ...
    fid, ...
    'Vcc VCC 0 DC %.12e\n', ...
    p.VCC);


fprintf( ...
    fid, ...
    'Vin IN 0 DC 0 AC 1\n');


fprintf( ...
    fid, ...
    'Cin IN BASE %.12e\n', ...
    p.Cin);


fprintf( ...
    fid, ...
    'R1 VCC BASE %.12e\n', ...
    p.R1);


fprintf( ...
    fid, ...
    'R2 BASE 0 %.12e\n', ...
    p.R2);


fprintf( ...
    fid, ...
    'Q1 COLL BASE EMIT 2N3904\n');


fprintf( ...
    fid, ...
    'RC1 VCC COLL %.12e\n', ...
    p.RC);


fprintf( ...
    fid, ...
    'RE1 EMIT 0 %.12e\n', ...
    p.RE);


fprintf( ...
    fid, ...
    'CE1 EMIT 0 %.12e\n', ...
    p.Ce);


fprintf( ...
    fid, ...
    'Cout COLL OUT %.12e\n', ...
    p.Cout);


fprintf( ...
    fid, ...
    'RL1 OUT 0 %.12e\n\n', ...
    p.RL);


%% ============================================================
% CONTROL
% =============================================================

fprintf(fid,'.control\n');


fprintf( ...
    fid, ...
    'set noaskquit\n');


fprintf( ...
    fid, ...
    'op\n');


fprintf( ...
    fid, ...
    'print v(base)\n');


fprintf( ...
    fid, ...
    'print v(emit)\n');


fprintf( ...
    fid, ...
    'print v(coll)\n');


fprintf( ...
    fid, ...
    'print @q1[ib]\n');


fprintf( ...
    fid, ...
    'print @q1[ic]\n');


fprintf( ...
    fid, ...
    'print @q1[ie]\n');


fprintf( ...
    fid, ...
    'ac dec %d %.12g %.12g\n', ...
    ac_points_per_decade, ...
    ac_fstart, ...
    ac_fstop);


%% ============================================================
% CRITICAL:
%
% DO NOT PUT QUOTES AROUND THE wrdata FILENAMES.
%
% This matches the syntax that worked in the original
% dataset generator.
%% ============================================================

fprintf( ...
    fid, ...
    'wrdata %s vdb(out)\n', ...
    gain_file);


fprintf( ...
    fid, ...
    'wrdata %s vp(out)\n', ...
    phase_file);


fprintf( ...
    fid, ...
    'quit\n');


fprintf( ...
    fid, ...
    '.endc\n');


fprintf( ...
    fid, ...
    '.end\n');


%% ============================================================
% CLOSE NETLIST
% =============================================================

fclose(fid);


%% ============================================================
% RUN NGSPICE
% =============================================================

cmd = sprintf( ...
    'cd /d "%s" && "%s" -b "%s"', ...
    work_dir, ...
    ngspice_exe, ...
    netlist_path);


try

    [status,cmdout] = ...
        system(cmd);

catch ME

    result.message = ...
        ['Could not execute ngspice: ' ...
         ME.message];

    return;

end


%% ============================================================
% SAVE LOG
% =============================================================

fidlog = fopen(log_path,'w');


if fidlog >= 0

    fprintf( ...
        fidlog, ...
        '%s\n', ...
        cmdout);

    fclose(fidlog);

end


%% ============================================================
% CHECK NGSPICE STATUS
% =============================================================

if status ~= 0

    result.message = sprintf( ...
        ['ngspice returned status %d.\n' ...
         'Log: %s'], ...
        status, ...
        log_path);

    return;

end


%% ============================================================
% CHECK GAIN FILE
% =============================================================

if ~exist(gain_path,'file')

    result.message = sprintf( ...
        ['ngspice completed successfully but gain ' ...
         'file was not created.\n\n' ...
         'Expected:\n%s\n\n' ...
         'Netlist:\n%s\n\n' ...
         'Log:\n%s'], ...
        gain_path, ...
        netlist_path, ...
        log_path);

    return;

end


%% ============================================================
% CHECK PHASE FILE
% =============================================================

if ~exist(phase_path,'file')

    result.message = sprintf( ...
        ['Gain file exists but phase file was not ' ...
         'created.\n\n' ...
         'Expected:\n%s\n\n' ...
         'Log:\n%s'], ...
        phase_path, ...
        log_path);

    return;

end


%% ============================================================
% READ GAIN FILE
% =============================================================

try

    gain_data = ...
        readmatrix(gain_path);

catch ME

    result.message = ...
        ['Could not read gain file: ' ...
         ME.message];

    return;

end


%% ============================================================
% READ PHASE FILE
% =============================================================

try

    phase_data = ...
        readmatrix(phase_path);

catch ME

    result.message = ...
        ['Could not read phase file: ' ...
         ME.message];

    return;

end


%% ============================================================
% VALIDATE GAIN DATA
% =============================================================

if isempty(gain_data)

    result.message = ...
        'Gain output file is empty.';

    return;

end


if size(gain_data,2) < 2

    result.message = sprintf( ...
        ['Gain output contains only %d columns. ' ...
         'Expected at least 2.'], ...
        size(gain_data,2));

    return;

end


%% ============================================================
% VALIDATE PHASE DATA
% =============================================================

if isempty(phase_data)

    result.message = ...
        'Phase output file is empty.';

    return;

end


if size(phase_data,2) < 2

    result.message = sprintf( ...
        ['Phase output contains only %d columns. ' ...
         'Expected at least 2.'], ...
        size(phase_data,2));

    return;

end


%% ============================================================
% EXTRACT GAIN COLUMNS
% =============================================================

frequency = ...
    gain_data(:,1);


gain_dB = ...
    gain_data(:,2);


%% ============================================================
% REMOVE INVALID VALUES
% =============================================================

valid = ...
    isfinite(frequency) & ...
    isfinite(gain_dB) & ...
    frequency > 0;


frequency = ...
    frequency(valid);


gain_dB = ...
    gain_dB(valid);


if numel(gain_dB) < 5

    result.message = ...
        'Too few valid AC gain points.';

    return;

end


%% ============================================================
% SORT FREQUENCY
% =============================================================

[frequency,idx] = ...
    sort(frequency);


gain_dB = ...
    gain_dB(idx);


%% ============================================================
% REMOVE DUPLICATE FREQUENCIES
% =============================================================

[frequency,unique_idx] = ...
    unique(frequency);


gain_dB = ...
    gain_dB(unique_idx);


%% ============================================================
% MIDBAND GAIN EXTRACTION
%
% Maximum gain
%       |
%       v
% max - 1 dB threshold
%       |
%       v
% longest contiguous region
%       |
%       v
% median gain = midband gain
%
%% ============================================================

max_gain = ...
    max(gain_dB);


threshold = ...
    max_gain - 1.0;


near_peak = ...
    gain_dB >= threshold;


%% ============================================================
% FIND LONGEST CONTIGUOUS REGION
% =============================================================

best_start = NaN;

best_end = NaN;

best_length = 0;

i = 1;


while i <= numel(near_peak)

    if near_peak(i)

        start_idx = i;


        while ...
                i <= numel(near_peak) && ...
                near_peak(i)

            i = i + 1;

        end


        end_idx = i - 1;


        current_length = ...
            end_idx - ...
            start_idx + 1;


        if current_length > best_length

            best_length = ...
                current_length;


            best_start = ...
                start_idx;


            best_end = ...
                end_idx;

        end

    else

        i = i + 1;

    end

end


%% ============================================================
% CHECK PLATEAU
% =============================================================

if isnan(best_start)

    result.message = ...
        'Could not identify gain plateau.';

    return;

end


%% ============================================================
% MIDBAND GAIN
% =============================================================

plateau = ...
    gain_dB( ...
        best_start:best_end);


midband_gain = ...
    median(plateau);


if ~isfinite(midband_gain)

    result.message = ...
        'Extracted midband gain is not finite.';

    return;

end


%% ============================================================
% SUCCESS
% =============================================================

result.success = true;


result.gain_dB = ...
    midband_gain;


result.message = ...
    'OK';


%% ============================================================
% DEBUG FOR BASELINE
% =============================================================

if contains(run_id,'baseline')

    fprintf('\n');
    fprintf('DEBUG:\n');


    fprintf( ...
        'Gain file: %s\n', ...
        gain_path);


    fprintf( ...
        'Phase file: %s\n', ...
        phase_path);


    fprintf( ...
        'AC points: %d\n', ...
        numel(gain_dB));


    fprintf( ...
        'Maximum gain: %.6f dB\n', ...
        max_gain);


    fprintf( ...
        'Plateau points: %d\n', ...
        best_length);


    fprintf( ...
        'Midband gain: %.6f dB\n', ...
        midband_gain);


    fprintf('\n');


    fprintf( ...
        'First 5 AC gain rows:\n');


    nshow = ...
        min(5,numel(gain_dB));


    disp( ...
        [ ...
        frequency(1:nshow), ...
        gain_dB(1:nshow) ...
        ]);

end

end
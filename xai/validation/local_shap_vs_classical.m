%% ============================================================
% LOCAL SHAP VS CLASSICAL SENSITIVITY
% CE AMPLIFIER
%
% Compares:
%   1. Local SHAP contribution from ML surrogate
%   2. Classical normalized sensitivity from SPICE
%
% Selected circuits:
%   Low Gain    -> Row 450
%   Medium Gain -> Row 253
%   High Gain   -> Row 259
%
% Classical sensitivity:
%   +/- 1% central finite difference
%
% Total SPICE simulations:
%   3 baseline + 3*9*2 perturbations = 57
%% ============================================================

clear;
clc;
close all;

fprintf('\n============================================\n');
fprintf('LOCAL SHAP VS CLASSICAL SENSITIVITY\n');
fprintf('============================================\n\n');

%% ============================================================
% 1. PATHS
% ============================================================

script_dir  = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

dataset_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');

local_shap_file = fullfile( ...
    project_dir, ...
    'output', ...
    'local_shap', ...
    'Local_SHAP_Results.mat');

model_file = fullfile( ...
    project_dir, ...
    'output', ...
    'Gain_Boosted_Model.mat');

model_path = fullfile( ...
    project_dir, ...
    'models', ...
    '2N3904.lib');

output_dir = fullfile( ...
    project_dir, ...
    'output', ...
    'local_shap_vs_classical');

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

% SPICE executable
ngspice_exe = 'C:\ngspice-47_64\bin\ngspice_con.exe';

%% ============================================================
% 2. CHECK FILES
% ============================================================

fprintf('Checking files...\n');

fprintf('Dataset       : ');
if exist(dataset_file,'file')
    fprintf('OK\n');
else
    fprintf('MISSING\n');
    error('Dataset not found:\n%s',dataset_file);
end

fprintf('Local SHAP    : ');
if exist(local_shap_file,'file')
    fprintf('OK\n');
else
    fprintf('MISSING\n');
    error('Local SHAP results not found:\n%s',local_shap_file);
end

fprintf('ML model      : ');
if exist(model_file,'file')
    fprintf('OK\n');
else
    fprintf('MISSING\n');
    error('ML model not found:\n%s',model_file);
end

fprintf('BJT model     : ');
if exist(model_path,'file')
    fprintf('OK\n');
else
    fprintf('MISSING\n');
    error('2N3904 model not found:\n%s',model_path);
end

%% ============================================================
% 3. LOAD DATASET
% ============================================================

fprintf('\nLoading dataset...\n');

T = readtable(dataset_file);

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

fprintf('\nDataset rows = %d\n',height(T));

%% ============================================================
% 4. SELECT EXACT SAME CIRCUITS AS LOCAL SHAP
% ============================================================

row_ids = [450 253 259];

circuit_names = { ...
    'Low_Gain', ...
    'Medium_Gain', ...
    'High_Gain'};

nCircuits = numel(row_ids);

actual_gain = T.Gain_dB(row_ids);

fprintf('\n============================================\n');
fprintf('SELECTED CIRCUITS\n');
fprintf('============================================\n');

for c = 1:nCircuits

    fprintf( ...
        '%d. %-12s Row = %d   Gain = %.4f dB\n', ...
        c, ...
        circuit_names{c}, ...
        row_ids(c), ...
        actual_gain(c));

end

%% ============================================================
% 5. LOAD LOCAL SHAP RESULTS
% ============================================================

fprintf('\nLoading local SHAP results...\n');

S = load(local_shap_file);

fprintf('Variables in SHAP file:\n');
disp(fieldnames(S));

% Your MAT file contains:
%
% ActualGain
% LocalSHAP
% PredictedGain
% PredictionError
% ResultsTable
% features
% selected_indices

if ~isfield(S,'LocalSHAP')

    error( ...
        ['Variable "LocalSHAP" was not found in ', ...
         'Local_SHAP_Results.mat']);

end

local_shap = S.LocalSHAP;

fprintf('\nLocal SHAP matrix size:\n');
disp(size(local_shap));

fprintf( ...
    'Expected size = %d circuits x %d features\n', ...
    nCircuits, ...
    nFeatures);

%% ============================================================
% 6. EXTRACT LOCAL SHAP MATRIX
% ============================================================

fprintf('\nExtracting local SHAP values...\n');

if isnumeric(local_shap)

    SHAP = local_shap;

elseif istable(local_shap)

    SHAP = table2array(local_shap);

else

    error( ...
        'Unsupported LocalSHAP type: %s', ...
        class(local_shap));

end

fprintf( ...
    'Actual LocalSHAP size = %d x %d\n', ...
    size(SHAP,1), ...
    size(SHAP,2));

if size(SHAP,1) ~= nCircuits

    error( ...
        ['LocalSHAP has %d rows, but %d circuits ', ...
         'are expected.'], ...
        size(SHAP,1), ...
        nCircuits);

end

if size(SHAP,2) ~= nFeatures

    error( ...
        ['LocalSHAP has %d columns, but %d features ', ...
         'are expected.'], ...
        size(SHAP,2), ...
        nFeatures);

end

if any(~isfinite(SHAP(:)))

    error('LocalSHAP contains NaN or Inf values.');

end

fprintf('\nLocal SHAP values successfully loaded.\n');

%% ============================================================
% 7. DISPLAY LOCAL SHAP
% ============================================================

fprintf('\nLocal SHAP values:\n');

for c = 1:nCircuits

    fprintf('\n%s\n',circuit_names{c});

    for k = 1:nFeatures

        fprintf( ...
            '  %-5s = %+9.5f dB\n', ...
            features{k}, ...
            SHAP(c,k));

    end

end

%% ============================================================
% 8. SPICE SETTINGS
% ============================================================

perturbation = 0.01;       % +/- 1%

ac_points_per_decade = 20;
ac_fstart = 10;
ac_fstop  = 1e9;

fprintf('\n============================================\n');
fprintf('CLASSICAL SENSITIVITY SETTINGS\n');
fprintf('============================================\n');

fprintf('Perturbation = +/- %.1f%%\n', ...
    perturbation*100);

fprintf( ...
    'Total SPICE runs = %d\n', ...
    nCircuits*(1 + 2*nFeatures));

%% ============================================================
% 9. SPICE WORK DIRECTORY
% ============================================================

work_dir = fullfile( ...
    output_dir, ...
    'spice_work');

if ~exist(work_dir,'dir')
    mkdir(work_dir);
end

%% ============================================================
% 10. PREALLOCATE
% ============================================================

BaselineGain = NaN(nCircuits,1);

PlusGain = NaN( ...
    nCircuits, ...
    nFeatures);

MinusGain = NaN( ...
    nCircuits, ...
    nFeatures);

Sensitivity = NaN( ...
    nCircuits, ...
    nFeatures);

SPICE_Status_Plus = strings( ...
    nCircuits, ...
    nFeatures);

SPICE_Status_Minus = strings( ...
    nCircuits, ...
    nFeatures);

%% ============================================================
% 11. RUN CLASSICAL SENSITIVITY
% ============================================================

fprintf('\n============================================\n');
fprintf('CLASSICAL SENSITIVITY ANALYSIS\n');
fprintf('============================================\n');

for c = 1:nCircuits

    fprintf('\n--------------------------------------------\n');
    fprintf('%s\n',circuit_names{c});
    fprintf('Dataset row = %d\n',row_ids(c));
    fprintf('--------------------------------------------\n');

    %% --------------------------------------------------------
    % Convert dataset row to parameter structure
    %% --------------------------------------------------------

    p = table_row_to_struct( ...
        T, ...
        row_ids(c), ...
        features);

    %% --------------------------------------------------------
    % BASELINE
    %% --------------------------------------------------------

    fprintf('\nRunning baseline SPICE...\n');

    prefix = sprintf( ...
        '%s_baseline', ...
        circuit_names{c});

    [gain_db,ok,spice_output] = run_one_spice( ...
        p, ...
        prefix, ...
        model_path, ...
        ngspice_exe, ...
        work_dir, ...
        ac_points_per_decade, ...
        ac_fstart, ...
        ac_fstop);

    if ~ok

        fprintf('\n============================================\n');
        fprintf('BASELINE SPICE FAILED\n');
        fprintf('============================================\n');

        fprintf('\nCircuit: %s\n', ...
            circuit_names{c});

        fprintf('\nngspice output:\n');
        fprintf('%s\n',spice_output);

        error( ...
            'Baseline SPICE simulation failed for %s.', ...
            circuit_names{c});

    end

    BaselineGain(c) = gain_db;

    fprintf( ...
        'Baseline SPICE gain = %.6f dB\n', ...
        gain_db);

    fprintf( ...
        'Dataset gain        = %.6f dB\n', ...
        actual_gain(c));

    fprintf( ...
        'Difference           = %.9f dB\n', ...
        gain_db - actual_gain(c));

    %% --------------------------------------------------------
    % PARAMETER PERTURBATIONS
    %% --------------------------------------------------------

    for k = 1:nFeatures

        parameter_name = features{k};

        fprintf('\n  Parameter: %s\n', ...
            parameter_name);

        x0 = p.(parameter_name);

        %% ====================================================
        % +1%
        %% ====================================================

        p_plus = p;

        p_plus.(parameter_name) = ...
            x0*(1 + perturbation);

        prefix_plus = sprintf( ...
            '%s_%s_plus', ...
            circuit_names{c}, ...
            parameter_name);

        fprintf( ...
            '    Running +1%% perturbation...\n');

        [g_plus,ok_plus,plus_output] = run_one_spice( ...
            p_plus, ...
            prefix_plus, ...
            model_path, ...
            ngspice_exe, ...
            work_dir, ...
            ac_points_per_decade, ...
            ac_fstart, ...
            ac_fstop);

        if ok_plus

            PlusGain(c,k) = g_plus;

            SPICE_Status_Plus(c,k) = ...
                "Valid";

            fprintf( ...
                '    +1%% gain = %.6f dB\n', ...
                g_plus);

        else

            SPICE_Status_Plus(c,k) = ...
                "Failed";

            fprintf( ...
                '    +1%% SPICE FAILED\n');

            fprintf('%s\n',plus_output);

        end

        %% ====================================================
        % -1%
        %% ====================================================

        p_minus = p;

        p_minus.(parameter_name) = ...
            x0*(1 - perturbation);

        prefix_minus = sprintf( ...
            '%s_%s_minus', ...
            circuit_names{c}, ...
            parameter_name);

        fprintf( ...
            '    Running -1%% perturbation...\n');

        [g_minus,ok_minus,minus_output] = run_one_spice( ...
            p_minus, ...
            prefix_minus, ...
            model_path, ...
            ngspice_exe, ...
            work_dir, ...
            ac_points_per_decade, ...
            ac_fstart, ...
            ac_fstop);

        if ok_minus

            MinusGain(c,k) = g_minus;

            SPICE_Status_Minus(c,k) = ...
                "Valid";

            fprintf( ...
                '    -1%% gain = %.6f dB\n', ...
                g_minus);

        else

            SPICE_Status_Minus(c,k) = ...
                "Failed";

            fprintf( ...
                '    -1%% SPICE FAILED\n');

            fprintf('%s\n',minus_output);

        end

        %% ====================================================
        % NORMALIZED CLASSICAL SENSITIVITY
        %
        % S_y^x = (x/y)*(dy/dx)
        %
        % Central difference:
        %
        % S ≈ (A+ - A-) /
        %       (2*delta*A0)
        %
        % Gain is converted from dB to
        % linear voltage gain.
        %% ====================================================

        if ok_plus && ok_minus

            A_plus = ...
                10^(g_plus/20);

            A_minus = ...
                10^(g_minus/20);

            A0 = ...
                10^(gain_db/20);

            Sensitivity(c,k) = ...
                (A_plus - A_minus) / ...
                (2*perturbation*A0);

            fprintf( ...
                '    Classical sensitivity = %+10.6f\n', ...
                Sensitivity(c,k));

        else

            Sensitivity(c,k) = NaN;

        end

    end

end

%% ============================================================
% 12. CLASSICAL SENSITIVITY SUMMARY
% ============================================================

fprintf('\n============================================\n');
fprintf('CLASSICAL SENSITIVITY SUMMARY\n');
fprintf('============================================\n');

for c = 1:nCircuits

    fprintf('\n%s\n', ...
        circuit_names{c});

    fprintf( ...
        'Baseline gain = %.6f dB\n\n', ...
        BaselineGain(c));

    for k = 1:nFeatures

        fprintf( ...
            '  %-5s = %+10.6f\n', ...
            features{k}, ...
            Sensitivity(c,k));

    end

end

%% ============================================================
% 13. CREATE COMPARISON TABLE
% ============================================================

fprintf('\nCreating comparison table...\n');

nRows = nCircuits*nFeatures;

Circuit = strings(nRows,1);
Dataset_Row = zeros(nRows,1);
Parameter = strings(nRows,1);

Actual_Gain_dB = zeros(nRows,1);
Baseline_SPICE_Gain_dB = zeros(nRows,1);

SHAP_Value_dB = zeros(nRows,1);
Abs_SHAP_dB = zeros(nRows,1);

Classical_Sensitivity = zeros(nRows,1);
Abs_Classical_Sensitivity = zeros(nRows,1);

SHAP_Rank = zeros(nRows,1);
Classical_Rank = zeros(nRows,1);

idx = 0;

for c = 1:nCircuits

    [~,shap_order] = sort( ...
        abs(SHAP(c,:)), ...
        'descend');

    [~,sens_order] = sort( ...
        abs(Sensitivity(c,:)), ...
        'descend');

    temp_shap_rank = zeros(1,nFeatures);
    temp_sens_rank = zeros(1,nFeatures);

    for r = 1:nFeatures

        temp_shap_rank(shap_order(r)) = r;
        temp_sens_rank(sens_order(r)) = r;

    end

    for k = 1:nFeatures

        idx = idx + 1;

        Circuit(idx) = ...
            circuit_names{c};

        Dataset_Row(idx) = ...
            row_ids(c);

        Parameter(idx) = ...
            features{k};

        Actual_Gain_dB(idx) = ...
            actual_gain(c);

        Baseline_SPICE_Gain_dB(idx) = ...
            BaselineGain(c);

        SHAP_Value_dB(idx) = ...
            SHAP(c,k);

        Abs_SHAP_dB(idx) = ...
            abs(SHAP(c,k));

        Classical_Sensitivity(idx) = ...
            Sensitivity(c,k);

        Abs_Classical_Sensitivity(idx) = ...
            abs(Sensitivity(c,k));

        SHAP_Rank(idx) = ...
            temp_shap_rank(k);

        Classical_Rank(idx) = ...
            temp_sens_rank(k);

    end

end

Comparison = table( ...
    Circuit, ...
    Dataset_Row, ...
    Parameter, ...
    Actual_Gain_dB, ...
    Baseline_SPICE_Gain_dB, ...
    SHAP_Value_dB, ...
    Abs_SHAP_dB, ...
    Classical_Sensitivity, ...
    Abs_Classical_Sensitivity, ...
    SHAP_Rank, ...
    Classical_Rank);

comparison_file = fullfile( ...
    output_dir, ...
    'Local_SHAP_vs_Classical.csv');

writetable( ...
    Comparison, ...
    comparison_file);

fprintf('\nSaved:\n%s\n', ...
    comparison_file);

%% ============================================================
% 14. LOCAL RANK COMPARISON
% ============================================================

fprintf('\n============================================\n');
fprintf('LOCAL RANK COMPARISON\n');
fprintf('============================================\n');

Rank_SHAP = zeros(nCircuits,nFeatures);
Rank_Sensitivity = zeros(nCircuits,nFeatures);

for c = 1:nCircuits

    [~,order_shap] = sort( ...
        abs(SHAP(c,:)), ...
        'descend');

    [~,order_sens] = sort( ...
        abs(Sensitivity(c,:)), ...
        'descend');

    Rank_SHAP(c,order_shap) = ...
        1:nFeatures;

    Rank_Sensitivity(c,order_sens) = ...
        1:nFeatures;

    fprintf('\n%s\n', ...
        circuit_names{c});

    fprintf('\n  SHAP ranking:\n');

    for r = 1:nFeatures

        k = order_shap(r);

        fprintf( ...
            '    %d. %-5s | %.6f dB\n', ...
            r, ...
            features{k}, ...
            abs(SHAP(c,k)));

    end

    fprintf('\n  Classical sensitivity ranking:\n');

    for r = 1:nFeatures

        k = order_sens(r);

        fprintf( ...
            '    %d. %-5s | %.6f\n', ...
            r, ...
            features{k}, ...
            abs(Sensitivity(c,k)));

    end

end

%% ============================================================
% 15. SPEARMAN RANK CORRELATION
% ============================================================

fprintf('\n============================================\n');
fprintf('LOCAL SHAP VS CLASSICAL AGREEMENT\n');
fprintf('============================================\n');

rho = NaN(nCircuits,1);

for c = 1:nCircuits

    valid = ...
        isfinite(SHAP(c,:)) & ...
        isfinite(Sensitivity(c,:));

    if sum(valid) >= 3

        rho(c) = corr( ...
            abs(SHAP(c,valid))', ...
            abs(Sensitivity(c,valid))', ...
            'Type','Spearman');

    end

    fprintf( ...
        '%-12s : rho = %.4f\n', ...
        circuit_names{c}, ...
        rho(c));

end

%% ============================================================
% 16. SIGN AGREEMENT
% ============================================================

fprintf('\n============================================\n');
fprintf('SIGN AGREEMENT\n');
fprintf('============================================\n');

Sign_Agreement = NaN(nCircuits,1);

for c = 1:nCircuits

    valid = ...
        isfinite(SHAP(c,:)) & ...
        isfinite(Sensitivity(c,:)) & ...
        SHAP(c,:) ~= 0 & ...
        Sensitivity(c,:) ~= 0;

    same_sign = ...
        sign(SHAP(c,valid)) == ...
        sign(Sensitivity(c,valid));

    if any(valid)

        Sign_Agreement(c) = ...
            100*sum(same_sign)/sum(valid);

    end

    fprintf( ...
        '%-12s : %.1f%% sign agreement\n', ...
        circuit_names{c}, ...
        Sign_Agreement(c));

end

%% ============================================================
% 17. SUMMARY TABLE
% ============================================================

Summary = table( ...
    string(circuit_names(:)), ...
    row_ids(:), ...
    actual_gain(:), ...
    BaselineGain(:), ...
    rho, ...
    Sign_Agreement, ...
    'VariableNames',{ ...
    'Circuit_Type', ...
    'Dataset_Row', ...
    'Dataset_Gain_dB', ...
    'SPICE_Baseline_Gain_dB', ...
    'Spearman_Rho', ...
    'Sign_Agreement_Percent'});

summary_file = fullfile( ...
    output_dir, ...
    'Local_SHAP_Classical_Summary.csv');

writetable( ...
    Summary, ...
    summary_file);

fprintf('\nSaved:\n%s\n', ...
    summary_file);

%% ============================================================
% 18. SAVE COMPLETE MAT FILE
% ============================================================

mat_file = fullfile( ...
    output_dir, ...
    'Local_SHAP_vs_Classical.mat');

save( ...
    mat_file, ...
    'Comparison', ...
    'Summary', ...
    'SHAP', ...
    'Sensitivity', ...
    'BaselineGain', ...
    'PlusGain', ...
    'MinusGain', ...
    'Rank_SHAP', ...
    'Rank_Sensitivity', ...
    'rho', ...
    'Sign_Agreement', ...
    'features', ...
    'row_ids', ...
    'circuit_names');

fprintf('\nSaved:\n%s\n', ...
    mat_file);

%% ============================================================
% 19. PLOT — LOCAL SHAP VS CLASSICAL
% ============================================================

figure( ...
    'Name','Local SHAP vs Classical Sensitivity', ...
    'NumberTitle','off');

for c = 1:nCircuits

    subplot(nCircuits,1,c);

    values = [ ...
        abs(SHAP(c,:))' ...
        abs(Sensitivity(c,:))'];

    bar(values);

    xticks(1:nFeatures);
    xticklabels(features);

    ylabel('Magnitude');

    title(sprintf( ...
        '%s — Gain = %.2f dB', ...
        circuit_names{c}, ...
        actual_gain(c)));

    legend( ...
        'Absolute SHAP (dB)', ...
        'Absolute Classical Sensitivity', ...
        'Location','best');

    grid on;

end

sgtitle( ...
    'Local XAI vs Classical Sensitivity');

plot1 = fullfile( ...
    output_dir, ...
    'Local_SHAP_vs_Classical_Importance.png');

exportgraphics( ...
    gcf, ...
    plot1, ...
    'Resolution',200);

fprintf('\nSaved:\n%s\n',plot1);

%% ============================================================
% 20. SCATTER PLOT
% ============================================================

fig2 = figure( ...
    'Name','SHAP vs Classical Sensitivity', ...
    'NumberTitle','off');

hold on;

for c = 1:nCircuits

    x = abs(Sensitivity(c,:));
    y = abs(SHAP(c,:));

    scatter( ...
        x, ...
        y, ...
        70, ...
        'filled');

end

xlabel( ...
    'Absolute Classical Sensitivity');

ylabel( ...
    'Absolute SHAP Contribution (dB)');

title( ...
    'Local SHAP vs Classical Sensitivity');

legend( ...
    circuit_names, ...
    'Location','best');

grid on;

hold off;

drawnow;

plot2 = fullfile( ...
    output_dir, ...
    'Local_SHAP_vs_Classical_Scatter.png');

exportgraphics( ...
    fig2, ...
    plot2, ...
    'Resolution',200);

fprintf('Saved:\n%s\n',plot2);

close(fig2);

%% ============================================================
% 21. FINAL OUTPUT
% ============================================================

fprintf('\n============================================\n');
fprintf('LOCAL SHAP VS CLASSICAL ANALYSIS COMPLETE\n');
fprintf('============================================\n');

fprintf('\nSelected circuits:\n');

for c = 1:nCircuits

    fprintf( ...
        '%-12s | Dataset = %8.4f dB | SPICE = %8.4f dB | rho = %.4f | Sign = %.1f%%\n', ...
        circuit_names{c}, ...
        actual_gain(c), ...
        BaselineGain(c), ...
        rho(c), ...
        Sign_Agreement(c));

end

fprintf('\nOutput directory:\n%s\n', ...
    output_dir);

fprintf('\nGenerated files:\n');
fprintf('  Local_SHAP_vs_Classical.csv\n');
fprintf('  Local_SHAP_Classical_Summary.csv\n');
fprintf('  Local_SHAP_vs_Classical.mat\n');
fprintf('  Local_SHAP_vs_Classical_Importance.png\n');
fprintf('  Local_SHAP_vs_Classical_Scatter.png\n');

fprintf('\n============================================\n');
fprintf('DONE\n');
fprintf('============================================\n');


%% ============================================================
% LOCAL FUNCTION 1
% Convert dataset row into parameter structure
%% ============================================================

function p = table_row_to_struct(T,row_id,features)

    p = struct();

    for k = 1:numel(features)

        name = features{k};

        p.(name) = ...
            T.(name)(row_id);

    end

end


%% ============================================================
% LOCAL FUNCTION 2
% Run one ngspice simulation
%% ============================================================

function [gain_db,ok,cmdout] = run_one_spice( ...
    p, ...
    prefix, ...
    model_path, ...
    ngspice_exe, ...
    work_dir, ...
    ac_points_per_decade, ...
    ac_fstart, ...
    ac_fstop)

    gain_db = NaN;
    ok = false;
    cmdout = '';

    %% --------------------------------------------------------
    % File names
    %% --------------------------------------------------------

    netlist_path = fullfile( ...
        work_dir, ...
        [prefix '.cir']);

    gain_file = fullfile( ...
        work_dir, ...
        [prefix '_gain.txt']);

    phase_file = fullfile( ...
        work_dir, ...
        [prefix '_phase.txt']);

    %% --------------------------------------------------------
    % Delete old output files
    %
    % This prevents an old successful result from being
    % accidentally reused after a failed SPICE run.
    %% --------------------------------------------------------

    if exist(gain_file,'file')
        delete(gain_file);
    end

    if exist(phase_file,'file')
        delete(phase_file);
    end

    if exist(netlist_path,'file')
        delete(netlist_path);
    end

    %% --------------------------------------------------------
    % SPICE-safe model path
    %% --------------------------------------------------------

    model_spice = ...
        strrep(model_path,'\','/');

    %% --------------------------------------------------------
    % WRITE NETLIST
    %% --------------------------------------------------------

    fid = fopen( ...
        netlist_path, ...
        'w');

    if fid < 0

        cmdout = sprintf( ...
            'Could not create netlist:\n%s', ...
            netlist_path);

        return;

    end

    cleanup = onCleanup( ...
        @() fclose(fid));

    fprintf( ...
        fid, ...
        '* CE amplifier local sensitivity: %s\n', ...
        prefix);

    fprintf( ...
        fid, ...
        '.include "%s"\n', ...
        model_spice);

    fprintf( ...
        fid, ...
        '.options TEMP=27 TNOM=27\n\n');

    %% --------------------------------------------------------
    % CIRCUIT
    %% --------------------------------------------------------

    fprintf( ...
        fid, ...
        'Vcc VCC 0 DC %.12g\n', ...
        p.VCC);

    fprintf( ...
        fid, ...
        'Vin IN 0 DC 0 AC 1\n');

    fprintf( ...
        fid, ...
        'Cin IN BASE %.12g\n', ...
        p.Cin);

    fprintf( ...
        fid, ...
        'R1 VCC BASE %.12g\n', ...
        p.R1);

    fprintf( ...
        fid, ...
        'R2 BASE 0 %.12g\n', ...
        p.R2);

    fprintf( ...
        fid, ...
        'Q1 COLL BASE EMIT 2N3904\n');

    fprintf( ...
        fid, ...
        'RC1 VCC COLL %.12g\n', ...
        p.RC);

    fprintf( ...
        fid, ...
        'RE1 EMIT 0 %.12g\n', ...
        p.RE);

    fprintf( ...
        fid, ...
        'CE1 EMIT 0 %.12g\n', ...
        p.Ce);

    fprintf( ...
        fid, ...
        'Cout COLL OUT %.12g\n', ...
        p.Cout);

    fprintf( ...
        fid, ...
        'RL1 OUT 0 %.12g\n\n', ...
        p.RL);

    %% --------------------------------------------------------
    % CONTROL BLOCK
    %% --------------------------------------------------------

    fprintf(fid,'.control\n');

    fprintf(fid,'set noaskquit\n');

    fprintf(fid,'op\n');

    fprintf(fid,'print v(base)\n');
    fprintf(fid,'print v(emit)\n');
    fprintf(fid,'print v(coll)\n');

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
        'ac dec %d %.6g %.6g\n', ...
        ac_points_per_decade, ...
        ac_fstart, ...
        ac_fstop);

    %% --------------------------------------------------------
    % IMPORTANT:
    %
    % wrdata uses SIMPLE FILENAMES.
    %
    % ngspice is executed from work_dir, so these files will
    % be written directly into work_dir.
    %
    % Do NOT put quotes around the filenames.
    %% --------------------------------------------------------

    fprintf( ...
        fid, ...
        'wrdata %s_gain.txt vdb(out)\n', ...
        prefix);

    fprintf( ...
        fid, ...
        'wrdata %s_phase.txt vp(out)\n', ...
        prefix);

    fprintf(fid,'quit\n');

    fprintf(fid,'.endc\n');
    fprintf(fid,'.end\n');

    clear cleanup;

    %% --------------------------------------------------------
    % RUN NGSPICE
    %% --------------------------------------------------------

    cmd = sprintf( ...
        'cd /d "%s" && "%s" -b "%s"', ...
        work_dir, ...
        ngspice_exe, ...
        netlist_path);

    [status,cmdout] = system(cmd);

    %% --------------------------------------------------------
    % CHECK NGSPICE STATUS
    %% --------------------------------------------------------

    if status ~= 0

        return;

    end

    %% --------------------------------------------------------
    % CHECK OUTPUT FILES
    %% --------------------------------------------------------

    if ~exist(gain_file,'file')

        cmdout = sprintf( ...
            '%s\n\nNGSPICE ran, but gain file was not created:\n%s', ...
            cmdout, ...
            gain_file);

        return;

    end

    if ~exist(phase_file,'file')

        cmdout = sprintf( ...
            '%s\n\nNGSPICE ran, but phase file was not created:\n%s', ...
            cmdout, ...
            phase_file);

        return;

    end

    %% --------------------------------------------------------
    % READ AC DATA
    %% --------------------------------------------------------

    try

        gain_data = readmatrix(gain_file);
        phase_data = readmatrix(phase_file);

    catch ME

        cmdout = sprintf( ...
            '%s\n\nMATLAB could not read SPICE output:\n%s', ...
            cmdout, ...
            ME.message);

        return;

    end

    %% --------------------------------------------------------
    % CHECK DATA
    %% --------------------------------------------------------

    if isempty(gain_data)

        cmdout = sprintf( ...
            '%s\n\nGain output file is empty.', ...
            cmdout);

        return;

    end

    if isempty(phase_data)

        cmdout = sprintf( ...
            '%s\n\nPhase output file is empty.', ...
            cmdout);

        return;

    end

    %% --------------------------------------------------------
    % Remove invalid rows
    %% --------------------------------------------------------

    if size(gain_data,2) < 2

        cmdout = sprintf( ...
            '%s\n\nGain output does not contain two columns.', ...
            cmdout);

        return;

    end

    if size(phase_data,2) < 2

        cmdout = sprintf( ...
            '%s\n\nPhase output does not contain two columns.', ...
            cmdout);

        return;

    end

    gain_data = ...
        gain_data( ...
        all(isfinite(gain_data),2),:);

    phase_data = ...
        phase_data( ...
        all(isfinite(phase_data),2),:);

    if size(gain_data,1) < 5

        cmdout = sprintf( ...
            '%s\n\nToo few valid gain points.', ...
            cmdout);

        return;

    end

    %% --------------------------------------------------------
    % Extract columns
    %% --------------------------------------------------------

    freq_gain = gain_data(:,1);
    gain_db_vec = gain_data(:,2);

    freq_phase = phase_data(:,1);
    phase_vec = phase_data(:,2);

    %% --------------------------------------------------------
    % Sort frequency
    %% --------------------------------------------------------

    [freq_gain,idx1] = sort(freq_gain);

    gain_db_vec = ...
        gain_db_vec(idx1);

    [freq_phase,idx2] = sort(freq_phase);

    phase_vec = ...
        phase_vec(idx2);

    %% --------------------------------------------------------
    % Remove duplicate frequencies
    %% --------------------------------------------------------

    [freq_gain,unique_idx] = ...
        unique(freq_gain);

    gain_db_vec = ...
        gain_db_vec(unique_idx);

    [freq_phase,unique_idx] = ...
        unique(freq_phase);

    phase_vec = ...
        phase_vec(unique_idx);

    %% --------------------------------------------------------
    % Remove unused phase variable warning
    %% --------------------------------------------------------

    %#ok<NASGU>
    phase_vec = phase_vec;
    freq_phase = freq_phase;

    %% --------------------------------------------------------
    % Determine midband gain
    %
    % Same plateau-based concept used in the dataset
    % extraction:
    %
    % 1. Find maximum gain.
    % 2. Select points within 1 dB of maximum.
    % 3. Find longest contiguous region.
    % 4. Median gain of that region = midband gain.
    %% --------------------------------------------------------

    max_gain = ...
        max(gain_db_vec);

    mask = ...
        gain_db_vec >= max_gain - 1;

    d = diff( ...
        [false; mask; false]);

    starts = ...
        find(d == 1);

    ends = ...
        find(d == -1) - 1;

    if isempty(starts)

        cmdout = sprintf( ...
            '%s\n\nCould not identify midband gain region.', ...
            cmdout);

        return;

    end

    lengths = ...
        ends - starts + 1;

    [~,best] = ...
        max(lengths);

    region = ...
        starts(best):ends(best);

    gain_db = ...
        median(gain_db_vec(region));

    %% --------------------------------------------------------
    % Final validation
    %% --------------------------------------------------------

    if ~isfinite(gain_db)

        cmdout = sprintf( ...
            '%s\n\nExtracted gain is not finite.', ...
            cmdout);

        return;

    end

    ok = true;

end
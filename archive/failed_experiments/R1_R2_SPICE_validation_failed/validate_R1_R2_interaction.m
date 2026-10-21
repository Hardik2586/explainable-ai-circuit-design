clear;
clc;
close all;

fprintf('\n============================================\n');
fprintf('     R1-R2 INTERACTION SPICE VALIDATION\n');
fprintf('============================================\n\n');


%% ============================================================
% SECTION 1 - PATH SETUP
% ============================================================

script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);

output_dir = fullfile(project_dir,'output');

validation_dir = fullfile( ...
    output_dir, ...
    'R1_R2_SPICE_Validation');

if ~exist(validation_dir,'dir')
    mkdir(validation_dir);
end


%% ============================================================
% SECTION 2 - FILES
% ============================================================

dataset_file = fullfile( ...
    output_dir, ...
    'CE_Amplifier_ML_Valid.csv');

model_file = fullfile( ...
    output_dir, ...
    'Gain_Boosted_Model.mat');

model_path = fullfile( ...
    project_dir, ...
    'models', ...
    '2N3904.lib');

ngspice_exe = ...
    'C:\ngspice-47_64\bin\ngspice_con.exe';


fprintf('Checking files...\n');

if ~isfile(dataset_file)
    error('Dataset not found:\n%s',dataset_file);
end

if ~isfile(model_file)
    error('ML model not found:\n%s',model_file);
end

if ~isfile(model_path)
    error('2N3904 model not found:\n%s',model_path);
end

if ~isfile(ngspice_exe)
    error('ngspice executable not found:\n%s',ngspice_exe);
end

fprintf('Dataset    : OK\n');
fprintf('ML model   : OK\n');
fprintf('SPICE model: OK\n');
fprintf('ngspice    : OK\n');


%% ============================================================
% SECTION 3 - LOAD DATASET
% ============================================================

fprintf('\n============================================\n');
fprintf('          LOADING DATASET\n');
fprintf('============================================\n\n');

data = readtable(dataset_file);

nRows = height(data);

fprintf('Valid dataset rows = %d\n',nRows);


%% ============================================================
% SECTION 4 - LOAD ML MODEL
% ============================================================

M = load(model_file);

if ~isfield(M,'model')
    error('Variable "model" not found in ML model.');
end

model = M.model;

fprintf('ML model class: %s\n',class(model));


%% ============================================================
% SECTION 5 - DEFINE FEATURES
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


%% ============================================================
% SECTION 6 - SELECT REPRESENTATIVE CIRCUITS
% ============================================================

Gain = double(data.Gain_dB);

[GainSorted,sortIdx] = sort(Gain);

% ------------------------------------------------------------
% Low gain
% ------------------------------------------------------------

idx_low = sortIdx(1);

% ------------------------------------------------------------
% Medium gain
% ------------------------------------------------------------

idx_medium = sortIdx(round(numel(sortIdx)/2));

% ------------------------------------------------------------
% High gain
% ------------------------------------------------------------

idx_high = sortIdx(end);

selected_indices = [ ...
    idx_low, ...
    idx_medium, ...
    idx_high];

circuit_names = { ...
    'Low_Gain', ...
    'Medium_Gain', ...
    'High_Gain'};

fprintf('\n============================================\n');
fprintf('       SELECTED REPRESENTATIVE CIRCUITS\n');
fprintf('============================================\n\n');

for k = 1:3

    idx = selected_indices(k);

    fprintf('%s:\n',circuit_names{k});

    fprintf('  Dataset row = %d\n',idx);

    fprintf('  Gain_dB     = %.6f\n', ...
        data.Gain_dB(idx));

end


%% ============================================================
% SECTION 7 - DEFINE R1/R2 SWEEP
% ============================================================

% ------------------------------------------------------------
% Use a ±50% logarithmic range around each representative
% circuit.
%
% This is wide enough to reveal nonlinear interaction while
% remaining close to the selected operating region.
% ------------------------------------------------------------

nSweep = 15;

relative_min = 0.5;
relative_max = 2.0;

fprintf('\n============================================\n');
fprintf('          SWEEP CONFIGURATION\n');
fprintf('============================================\n\n');

fprintf('R1/R2 sweep points = %d x %d\n', ...
    nSweep,nSweep);

fprintf('Relative range     = %.2fx to %.2fx\n', ...
    relative_min,relative_max);


%% ============================================================
% SECTION 8 - STORAGE
% ============================================================

SPICE_Gain = NaN(nSweep,nSweep,3);

ML_Gain = NaN(nSweep,nSweep,3);

Error_Gain = NaN(nSweep,nSweep,3);

R1_Values = cell(3,1);

R2_Values = cell(3,1);

Baseline_SPICE = NaN(3,1);

Baseline_ML = NaN(3,1);


%% ============================================================
% SECTION 9 - MAIN SWEEP
% ============================================================

total_runs = 0;

successful_runs = 0;

fprintf('\n============================================\n');
fprintf('          RUNNING SPICE SWEEPS\n');
fprintf('============================================\n\n');


for c = 1:3

    idx = selected_indices(c);

    p = struct();

    p.R1   = double(data.R1(idx));
    p.R2   = double(data.R2(idx));
    p.RC   = double(data.RC(idx));
    p.RE   = double(data.RE(idx));
    p.RL   = double(data.RL(idx));
    p.Cin  = double(data.Cin(idx));
    p.Cout = double(data.Cout(idx));
    p.Ce   = double(data.Ce(idx));
    p.VCC  = double(data.VCC(idx));

    % --------------------------------------------------------
    % Logarithmic sweep
    % --------------------------------------------------------

    R1_vec = logspace( ...
        log10(p.R1*relative_min), ...
        log10(p.R1*relative_max), ...
        nSweep);

    R2_vec = logspace( ...
        log10(p.R2*relative_min), ...
        log10(p.R2*relative_max), ...
        nSweep);

    R1_Values{c} = R1_vec;

    R2_Values{c} = R2_vec;


    fprintf('\n%s\n',circuit_names{c});

    fprintf('Baseline R1 = %.6g ohm\n',p.R1);

    fprintf('Baseline R2 = %.6g ohm\n',p.R2);

    fprintf('Baseline Gain = %.6f dB\n', ...
        data.Gain_dB(idx));


    %% --------------------------------------------------------
    % Run sweep
    % ---------------------------------------------------------

    for i = 1:nSweep

        for j = 1:nSweep

            total_runs = total_runs + 1;

            p_sweep = p;

            p_sweep.R1 = R1_vec(i);

            p_sweep.R2 = R2_vec(j);

            run_id = sprintf( ...
                '%s_R1_%02d_R2_%02d', ...
                circuit_names{c}, ...
                i,j);

            netlist_path = fullfile( ...
                validation_dir, ...
                [run_id '.cir']);

            gain_file = fullfile( ...
                validation_dir, ...
                [run_id '_gain.txt']);

            phase_file = fullfile( ...
                validation_dir, ...
                [run_id '_phase.txt']);

            % ------------------------------------------------
            % Write netlist
            % ------------------------------------------------

            write_validation_netlist( ...
                netlist_path, ...
                model_path, ...
                p_sweep, ...
                gain_file, ...
                phase_file);


            % ------------------------------------------------
            % Run ngspice
            % ------------------------------------------------

            cmd = sprintf( ...
                'cd /d "%s" && "%s" -b "%s"', ...
                validation_dir, ...
                ngspice_exe, ...
                netlist_path);

            [status,cmdout] = system(cmd);

            if status ~= 0

                fprintf( ...
                    'SPICE failed: %s\n', ...
                    run_id);

                continue;

            end


            % ------------------------------------------------
            % Read AC gain
            % ------------------------------------------------

            try

                gain_data = readmatrix(gain_file);

            catch

                continue;

            end


            if isempty(gain_data)

                continue;

            end


            % ------------------------------------------------
            % Extract frequency and gain
            % ------------------------------------------------

            if size(gain_data,2) < 2

                continue;

            end

            freq = gain_data(:,1);

            gain_db = gain_data(:,2);


            valid = ...
                isfinite(freq) & ...
                isfinite(gain_db) & ...
                freq > 0;

            freq = freq(valid);

            gain_db = gain_db(valid);


            if numel(freq) < 5

                continue;

            end


            % ------------------------------------------------
            % Extract plateau gain
            % ------------------------------------------------

            gain_value = extract_plateau_gain( ...
                freq, ...
                gain_db);


            if ~isfinite(gain_value)

                continue;

            end


            SPICE_Gain(i,j,c) = gain_value;

            successful_runs = successful_runs + 1;


            % ------------------------------------------------
            % ML prediction
            % ------------------------------------------------

            x_ml = [ ...
                log10(p_sweep.R1), ...
                log10(p_sweep.R2), ...
                log10(p_sweep.RC), ...
                log10(p_sweep.RE), ...
                log10(p_sweep.RL), ...
                log10(p_sweep.Cin), ...
                log10(p_sweep.Cout), ...
                log10(p_sweep.Ce), ...
                p_sweep.VCC];

            ml_value = predict(model,x_ml);

            ml_value = double(ml_value);

            ML_Gain(i,j,c) = ml_value;

            Error_Gain(i,j,c) = ...
                gain_value - ml_value;


            % ------------------------------------------------
            % Progress
            % ------------------------------------------------

            if mod(total_runs,25) == 0

                fprintf( ...
                    'Runs: %d / %d\n', ...
                    total_runs, ...
                    3*nSweep*nSweep);

            end

        end

    end


    %% --------------------------------------------------------
    % Baseline comparison
    % ---------------------------------------------------------

    % Find nearest sweep point to baseline R1/R2

    [~,i0] = min(abs(R1_vec - p.R1));

    [~,j0] = min(abs(R2_vec - p.R2));

    Baseline_SPICE(c) = ...
        SPICE_Gain(i0,j0,c);

    x_baseline = [ ...
        log10(p.R1), ...
        log10(p.R2), ...
        log10(p.RC), ...
        log10(p.RE), ...
        log10(p.RL), ...
        log10(p.Cin), ...
        log10(p.Cout), ...
        log10(p.Ce), ...
        p.VCC];

    Baseline_ML(c) = ...
        double(predict(model,x_baseline));

end


%% ============================================================
% SECTION 10 - SWEEP SUMMARY
% ============================================================

fprintf('\n============================================\n');
fprintf('             SWEEP SUMMARY\n');
fprintf('============================================\n\n');

fprintf('Total SPICE runs attempted : %d\n', ...
    total_runs);

fprintf('Successful SPICE runs      : %d\n', ...
    successful_runs);

fprintf('Failed SPICE runs          : %d\n', ...
    total_runs-successful_runs);


for c = 1:3

    fprintf('\n%s\n',circuit_names{c});

    fprintf('Dataset baseline : %.6f dB\n', ...
        data.Gain_dB(selected_indices(c)));

    fprintf('SPICE baseline   : %.6f dB\n', ...
        Baseline_SPICE(c));

    fprintf('ML baseline      : %.6f dB\n', ...
        Baseline_ML(c));

end


%% ============================================================
% SECTION 11 - SURFACE ERROR
% ============================================================

fprintf('\n============================================\n');
fprintf('          SPICE vs ML ERROR\n');
fprintf('============================================\n\n');

for c = 1:3

    err = Error_Gain(:,:,c);

    valid_err = ...
        err(isfinite(err));

    if isempty(valid_err)

        fprintf('%s: no valid error data\n', ...
            circuit_names{c});

        continue;

    end

    MAE_surface = ...
        mean(abs(valid_err));

    RMSE_surface = ...
        sqrt(mean(valid_err.^2));

    MaxError = ...
        max(abs(valid_err));

    fprintf('%s:\n',circuit_names{c});

    fprintf('  MAE  = %.4f dB\n',MAE_surface);

    fprintf('  RMSE = %.4f dB\n',RMSE_surface);

    fprintf('  Max  = %.4f dB\n',MaxError);

end


%% ============================================================
% SECTION 12 - CREATE SPICE SURFACE PLOTS
% ============================================================

fprintf('\n============================================\n');
fprintf('          CREATING SPICE SURFACES\n');
fprintf('============================================\n\n');

for c = 1:3

    R1_vec = R1_Values{c};

    R2_vec = R2_Values{c};

    [R1Grid,R2Grid] = meshgrid( ...
        R1_vec, ...
        R2_vec);

    Z = SPICE_Gain(:,:,c).';

    fig = figure( ...
        'Name', ...
        ['SPICE R1-R2 Surface - ' circuit_names{c}], ...
        'NumberTitle','off');

    surf( ...
        R1Grid, ...
        R2Grid, ...
        Z, ...
        'EdgeColor','none');

    xlabel('R1 (\Omega)');

    ylabel('R2 (\Omega)');

    zlabel('Gain (dB)');

    title( ...
        ['SPICE Gain Surface: ' ...
         circuit_names{c}], ...
        'Interpreter','none');

    set(gca,'XScale','log');
    set(gca,'YScale','log');

    colorbar;

    grid on;

    view(135,30);

    drawnow;

    filename = fullfile( ...
        validation_dir, ...
        ['SPICE_R1_R2_Surface_' ...
         circuit_names{c} '.png']);

    exportgraphics( ...
        fig, ...
        filename, ...
        'Resolution',200);

    close(fig);

    fprintf('Saved: %s\n',filename);

end


%% ============================================================
% SECTION 13 - CREATE ML SURFACES
% ============================================================

fprintf('\n============================================\n');
fprintf('          CREATING ML SURFACES\n');
fprintf('============================================\n\n');

for c = 1:3

    R1_vec = R1_Values{c};

    R2_vec = R2_Values{c};

    [R1Grid,R2Grid] = meshgrid( ...
        R1_vec, ...
        R2_vec);

    Z = ML_Gain(:,:,c).';

    fig = figure( ...
        'Name', ...
        ['ML R1-R2 Surface - ' circuit_names{c}], ...
        'NumberTitle','off');

    surf( ...
        R1Grid, ...
        R2Grid, ...
        Z, ...
        'EdgeColor','none');

    xlabel('R1 (\Omega)');

    ylabel('R2 (\Omega)');

    zlabel('Predicted Gain (dB)');

    title( ...
        ['ML Predicted Gain Surface: ' ...
         circuit_names{c}], ...
        'Interpreter','none');

    set(gca,'XScale','log');
    set(gca,'YScale','log');

    colorbar;

    grid on;

    view(135,30);

    drawnow;

    filename = fullfile( ...
        validation_dir, ...
        ['ML_R1_R2_Surface_' ...
         circuit_names{c} '.png']);

    exportgraphics( ...
        fig, ...
        filename, ...
        'Resolution',200);

    close(fig);

    fprintf('Saved: %s\n',filename);

end


%% ============================================================
% SECTION 14 - CREATE ERROR SURFACES
% ============================================================

fprintf('\n============================================\n');
fprintf('          CREATING ERROR SURFACES\n');
fprintf('============================================\n\n');

for c = 1:3

    R1_vec = R1_Values{c};

    R2_vec = R2_Values{c};

    [R1Grid,R2Grid] = meshgrid( ...
        R1_vec, ...
        R2_vec);

    Z = Error_Gain(:,:,c).';

    fig = figure( ...
        'Name', ...
        ['SPICE ML Error - ' circuit_names{c}], ...
        'NumberTitle','off');

    surf( ...
        R1Grid, ...
        R2Grid, ...
        Z, ...
        'EdgeColor','none');

    xlabel('R1 (\Omega)');

    ylabel('R2 (\Omega)');

    zlabel('SPICE - ML Gain (dB)');

    title( ...
        ['SPICE - ML Error Surface: ' ...
         circuit_names{c}], ...
        'Interpreter','none');

    set(gca,'XScale','log');
    set(gca,'YScale','log');

    colorbar;

    grid on;

    view(135,30);

    drawnow;

    filename = fullfile( ...
        validation_dir, ...
        ['SPICE_ML_Error_Surface_' ...
         circuit_names{c} '.png']);

    exportgraphics( ...
        fig, ...
        filename, ...
        'Resolution',200);

    close(fig);

    fprintf('Saved: %s\n',filename);

end


%% ============================================================
% SECTION 15 - 2D CONTOUR PLOTS
% ============================================================

fprintf('\n============================================\n');
fprintf('          CREATING CONTOUR PLOTS\n');
fprintf('============================================\n\n');

for c = 1:3

    R1_vec = R1_Values{c};

    R2_vec = R2_Values{c};

    [R1Grid,R2Grid] = meshgrid( ...
        R1_vec, ...
        R2_vec);

    Z = SPICE_Gain(:,:,c).';

    fig = figure( ...
        'Name', ...
        ['SPICE R1-R2 Contour - ' circuit_names{c}], ...
        'NumberTitle','off');

    contourf( ...
        R1Grid, ...
        R2Grid, ...
        Z, ...
        20);

    set(gca,'XScale','log');
    set(gca,'YScale','log');

    xlabel('R1 (\Omega)');

    ylabel('R2 (\Omega)');

    title( ...
        ['SPICE Gain Contour: ' ...
         circuit_names{c}], ...
        'Interpreter','none');

    colorbar;

    grid on;

    drawnow;

    filename = fullfile( ...
        validation_dir, ...
        ['SPICE_R1_R2_Contour_' ...
         circuit_names{c} '.png']);

    exportgraphics( ...
        fig, ...
        filename, ...
        'Resolution',200);

    close(fig);

    fprintf('Saved: %s\n',filename);

end


%% ============================================================
% SECTION 16 - SAVE NUMERICAL RESULTS
% ============================================================

Results = struct();

Results.DatasetFile = dataset_file;

Results.ModelFile = model_file;

Results.ValidationDirectory = validation_dir;

Results.Features = features;

Results.SelectedIndices = selected_indices;

Results.CircuitNames = circuit_names;

Results.BaselineDatasetGain = ...
    Gain(selected_indices);

Results.BaselineSPICEGain = ...
    Baseline_SPICE;

Results.BaselineMLGain = ...
    Baseline_ML;

Results.R1_Values = R1_Values;

Results.R2_Values = R2_Values;

Results.SPICE_Gain = SPICE_Gain;

Results.ML_Gain = ML_Gain;

Results.Error_Gain = Error_Gain;

Results.TotalRuns = total_runs;

Results.SuccessfulRuns = successful_runs;


results_file = fullfile( ...
    validation_dir, ...
    'R1_R2_SPICE_Validation_Results.mat');

save( ...
    results_file, ...
    'Results', ...
    '-v7.3');

fprintf('\nSaved MATLAB results:\n%s\n', ...
    results_file);


%% ============================================================
% SECTION 17 - SAVE BASELINE TABLE
% ============================================================

Circuit = string(circuit_names');

DatasetGain_dB = ...
    Gain(selected_indices);

SPICEGain_dB = ...
    Baseline_SPICE;

MLGain_dB = ...
    Baseline_ML;

SPICE_Dataset_Error_dB = ...
    SPICEGain_dB - DatasetGain_dB;

SPICE_ML_Error_dB = ...
    SPICEGain_dB - MLGain_dB;

BaselineTable = table( ...
    Circuit, ...
    DatasetGain_dB, ...
    SPICEGain_dB, ...
    MLGain_dB, ...
    SPICE_Dataset_Error_dB, ...
    SPICE_ML_Error_dB);


baseline_file = fullfile( ...
    validation_dir, ...
    'R1_R2_Baseline_Comparison.csv');

writetable( ...
    BaselineTable, ...
    baseline_file);

fprintf('\nSaved baseline comparison:\n%s\n', ...
    baseline_file);


%% ============================================================
% SECTION 18 - FINAL SUMMARY
% ============================================================

fprintf('\n============================================\n');
fprintf('      R1-R2 SPICE VALIDATION COMPLETE\n');
fprintf('============================================\n\n');

fprintf('Strongest SHAP interaction:\n');

fprintf('  R1 <-> R2 = 0.61441\n');

fprintf('\nSPICE sweep:\n');

fprintf('  %d x %d points\n', ...
    nSweep,nSweep);

fprintf('  3 representative circuits\n');

fprintf('  Total possible simulations = %d\n', ...
    3*nSweep*nSweep);

fprintf('\nSuccessful simulations = %d\n', ...
    successful_runs);

fprintf('\nOutput directory:\n%s\n', ...
    validation_dir);

fprintf('\n============================================\n');
fprintf('                  DONE\n');
fprintf('============================================\n');


%% ============================================================
% LOCAL FUNCTION - WRITE VALIDATION NETLIST
% ============================================================

function write_validation_netlist( ...
    netlist_path, ...
    model_path, ...
    p, ...
    gain_file, ...
    phase_file)

    model_spice = ...
        strrep(model_path,'\','/');

    gain_spice = ...
        strrep(gain_file,'\','/');

    phase_spice = ...
        strrep(phase_file,'\','/');


    fid = fopen(netlist_path,'w');

    if fid < 0
        error( ...
            'Could not open netlist: %s', ...
            netlist_path);
    end

    cleanup = onCleanup(@() fclose(fid));


    fprintf(fid, ...
        '* R1-R2 interaction validation\n');


    fprintf(fid, ...
        '.include "%s"\n', ...
        model_spice);


    fprintf(fid, ...
        '.options TEMP=27 TNOM=27\n\n');


    fprintf(fid, ...
        'Vcc VCC 0 DC %.10e\n', ...
        p.VCC);


    fprintf(fid, ...
        'Vin IN 0 DC 0 AC 1\n');


    fprintf(fid, ...
        'Cin IN BASE %.10e\n', ...
        p.Cin);


    fprintf(fid, ...
        'R1 VCC BASE %.10e\n', ...
        p.R1);


    fprintf(fid, ...
        'R2 BASE 0 %.10e\n', ...
        p.R2);


    fprintf(fid, ...
        'Q1 COLL BASE EMIT 2N3904\n');


    fprintf(fid, ...
        'RC1 VCC COLL %.10e\n', ...
        p.RC);


    fprintf(fid, ...
        'RE1 EMIT 0 %.10e\n', ...
        p.RE);


    fprintf(fid, ...
        'CE1 EMIT 0 %.10e\n', ...
        p.Ce);


    fprintf(fid, ...
        'Cout COLL OUT %.10e\n', ...
        p.Cout);


    fprintf(fid, ...
        'RL1 OUT 0 %.10e\n\n', ...
        p.RL);


    fprintf(fid,'.control\n');

    fprintf(fid,'set noaskquit\n');

    fprintf(fid,'ac dec 20 10 1e9\n');

    % IMPORTANT:
    % Do not put quotes around wrdata filenames.

    fprintf(fid, ...
        'wrdata %s vdb(out)\n', ...
        gain_spice);

    fprintf(fid, ...
        'wrdata %s vp(out)\n', ...
        phase_spice);

    fprintf(fid,'quit\n');

    fprintf(fid,'.endc\n');

    fprintf(fid,'.end\n');

end


%% ============================================================
% LOCAL FUNCTION - EXTRACT PLATEAU GAIN
% ============================================================

function gain_dB = extract_plateau_gain( ...
    freq, ...
    gain_db)

    gain_dB = NaN;


    valid = ...
        isfinite(freq) & ...
        isfinite(gain_db) & ...
        freq > 0;


    freq = freq(valid);

    gain_db = gain_db(valid);


    if numel(freq) < 5
        return;
    end


    [freq,order] = sort(freq);

    gain_db = gain_db(order);


    global_max = max(gain_db);


    threshold = global_max - 1.0;


    in_band = ...
        gain_db >= threshold;


    % --------------------------------------------------------
    % Find contiguous near-peak regions
    % --------------------------------------------------------

    d = diff([false; in_band; false]);

    starts = find(d == 1);

    ends = find(d == -1) - 1;


    if isempty(starts)

        gain_dB = median(gain_db);

        return;

    end


    lengths = ends - starts + 1;

    [~,idx] = max(lengths);


    selected = ...
        starts(idx):ends(idx);


    if isempty(selected)

        gain_dB = median(gain_db);

    else

        gain_dB = median( ...
            gain_db(selected));

    end

end
 powercfg /batteryreport
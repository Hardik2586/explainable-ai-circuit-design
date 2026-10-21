clear; clc;

root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir, fullfile(root_dir, 'functions'));

cfg = config();

fprintf('Generating %d CE amplifier configurations (seed=%d)...\n', ...
    cfg.N, cfg.seed);

P = sample_ce_parameters(cfg);

N = cfg.N;

% ================================================================
% Preallocate DC quantities
% ================================================================
Circuit_ID = P.Circuit_ID;

VB  = nan(N,1);
VE  = nan(N,1);
VC  = nan(N,1);

VBE = nan(N,1);
VCB = nan(N,1);
VCE = nan(N,1);

IB  = nan(N,1);
IC  = nan(N,1);
IE  = nan(N,1);

% ================================================================
% Preallocate AC quantities
% ================================================================
Gain = nan(N,1);
Gain_dB = nan(N,1);

fL = nan(N,1);
fH = nan(N,1);
Bandwidth = nan(N,1);

% ================================================================
% Other quantities
% ================================================================
Power = nan(N,1);

% Separate DC and AC status
DC_Status = strings(N,1);
AC_Status = strings(N,1);

% Overall status for compatibility with existing scripts
Simulation_Status = strings(N,1);

t_start = tic;

% ================================================================
% Main simulation loop
% ================================================================
for i = 1:N

    id = char(Circuit_ID(i));

    try

        % ------------------------------------------------------------
        % Convert current parameter row to structure
        % ------------------------------------------------------------
        p = table2struct(P(i, ...
            {'R1','R2','RC','RE','RL', ...
             'Cin','Cout','Ce','VCC','Temperature'}));

        % ------------------------------------------------------------
        % File paths
        % ------------------------------------------------------------
        netlist_path = fullfile( ...
            cfg.netlist_dir, [id '.cir']);

        ac_gain_file = fullfile( ...
            cfg.raw_dir, [id '_ac_gain.txt']);

        ac_phase_file = fullfile( ...
            cfg.raw_dir, [id '_ac_phase.txt']);

        % ------------------------------------------------------------
        % Generate SPICE netlist
        % ------------------------------------------------------------
        write_ce_netlist( ...
            netlist_path, ...
            cfg.model_path, ...
            p, ...
            id, ...
            ac_gain_file, ...
            ac_phase_file, ...
            cfg);

        % ------------------------------------------------------------
        % Run ngspice
        % ------------------------------------------------------------
        [status, cmdout] = run_ngspice_single( ...
            netlist_path, cfg.ngspice_exe);

        if status ~= 0

            DC_Status(i) = "NGSPICE_NONZERO_EXIT";
            AC_Status(i) = "Not_Run";
            Simulation_Status(i) = "NGSPICE_NONZERO_EXIT";

            continue;
        end

        % ============================================================
        % DC OPERATING POINT
        % ============================================================
        [vb, ve, vc, ib, ic, ie, op_ok] = ...
            parse_op_point(cmdout);

        if ~op_ok

            DC_Status(i) = "OP_PARSE_FAILED";
            AC_Status(i) = "Not_Run";
            Simulation_Status(i) = "OP_PARSE_FAILED";

            continue;
        end

        % Store DC quantities
        VB(i) = vb;
        VE(i) = ve;
        VC(i) = vc;

        VBE(i) = vb - ve;
        VCB(i) = vc - vb;
        VCE(i) = vc - ve;

        IB(i) = ib;
        IC(i) = ic;
        IE(i) = ie;

        % ------------------------------------------------------------
        % Classify operating region
        % ------------------------------------------------------------
        [is_valid, op_status] = ...
            validate_operating_point( ...
                vb, vc, ve, ic, ib, p.VCC, cfg);

        DC_Status(i) = string(op_status);

        % ============================================================
        % AC ANALYSIS
        % ============================================================

        % AC analysis is only meaningful for a usable amplifier
        if ~is_valid

            AC_Status(i) = "Not_Applicable";

        else

            % --------------------------------------------------------
            % Read AC gain
            % --------------------------------------------------------
            [freq_g, gain_dB_vec, gain_ok] = ...
                read_wrdata_file(ac_gain_file);

            % --------------------------------------------------------
            % Read AC phase
            % --------------------------------------------------------
            [freq_p, phase_vec, phase_ok] = ...
                read_wrdata_file(ac_phase_file);

            % --------------------------------------------------------
            % Check AC data
            % --------------------------------------------------------
            if ~gain_ok || ~phase_ok

                AC_Status(i) = "AC_PARSE_FAILED";

            elseif numel(freq_g) ~= numel(freq_p)

                AC_Status(i) = "AC_LENGTH_MISMATCH";

            else

                % ----------------------------------------------------
                % Extract AC performance metrics
                % ----------------------------------------------------
                [av, av_db, f_l, f_h, bw, ac_ok] = ...
                    extract_ac_metrics( ...
                        freq_g, ...
                        gain_dB_vec, ...
                        phase_vec);

                if ac_ok

                    Gain(i) = av;
                    Gain_dB(i) = av_db;

                    fL(i) = f_l;
                    fH(i) = f_h;
                    Bandwidth(i) = bw;

                    AC_Status(i) = "Valid";

                else

                    AC_Status(i) = "Extraction_Failed";

                end

            end

        end

        % ============================================================
        % POWER
        % ============================================================

        % Current supplied through R1
        i_r1 = (p.VCC - vb) / p.R1;

        % Current supplied through RC
        i_rc = (p.VCC - vc) / p.RC;

        % Total approximate DC power from VCC
        Power(i) = p.VCC * (i_r1 + i_rc);

        % ============================================================
        % OVERALL STATUS
        % ============================================================

        if is_valid && AC_Status(i) == "Valid"

            Simulation_Status(i) = "Valid";

        elseif ~is_valid

            % Preserve physical operating region
            Simulation_Status(i) = string(op_status);

        else

            % DC valid but AC failed
            Simulation_Status(i) = AC_Status(i);

        end

    catch ME

        DC_Status(i) = "MATLAB_ERROR";
        AC_Status(i) = "Not_Run";

        Simulation_Status(i) = ...
            "MATLAB_ERROR:" + string(ME.message);

    end

    % ------------------------------------------------------------
    % Progress
    % ------------------------------------------------------------
    if mod(i, 250) == 0

        fprintf('  %d / %d done (%.1f s elapsed)\n', ...
            i, N, toc(t_start));

    end

end

% ================================================================
% Build final dataset
% ================================================================

Dataset = P(:, ...
    {'Circuit_ID','R1','R2','RC','RE','RL', ...
     'Cin','Cout','Ce','VCC','Temperature'});

% DC quantities
Dataset.VB = VB;
Dataset.VE = VE;
Dataset.VC = VC;

Dataset.VBE = VBE;
Dataset.VCB = VCB;
Dataset.VCE = VCE;

Dataset.IB = IB;
Dataset.IC = IC;
Dataset.IE = IE;

% AC quantities
Dataset.Gain = Gain;
Dataset.Gain_dB = Gain_dB;

Dataset.fL = fL;
Dataset.fH = fH;
Dataset.Bandwidth = Bandwidth;

% Power
Dataset.Power = Power;

% Status information
Dataset.DC_Status = DC_Status;
Dataset.AC_Status = AC_Status;
Dataset.Simulation_Status = Simulation_Status;

% Device information
Dataset.Transistor_Model = ...
    repmat("2N3904", N, 1);

% ================================================================
% Save
% ================================================================

mat_path = fullfile( ...
    cfg.output_dir, ...
    sprintf('CE_Amplifier_Dataset_%s.mat', ...
    cfg.version_tag));

csv_path = fullfile( ...
    cfg.output_dir, ...
    sprintf('CE_Amplifier_Dataset_%s.csv', ...
    cfg.version_tag));

save(mat_path, 'Dataset', 'cfg');

writetable(Dataset, csv_path);

% ================================================================
% Summary
% ================================================================

fprintf('\nDone. %d rows written.\n', height(Dataset));

fprintf('  MAT: %s\n', mat_path);
fprintf('  CSV: %s\n', csv_path);

fprintf('\n===== DATASET STATUS =====\n');

fprintf('DC Valid: %d / %d\n', ...
    sum(Dataset.DC_Status == "Valid"), N);

fprintf('AC Valid: %d / %d\n', ...
    sum(Dataset.AC_Status == "Valid"), N);

fprintf('\n-- DC Status --\n');

dc_unique = unique(Dataset.DC_Status);

for k = 1:numel(dc_unique)

    fprintf('  %-25s %d\n', ...
        dc_unique(k), ...
        sum(Dataset.DC_Status == dc_unique(k)));

end

fprintf('\n-- AC Status --\n');

ac_unique = unique(Dataset.AC_Status);

for k = 1:numel(ac_unique)

    fprintf('  %-25s %d\n', ...
        ac_unique(k), ...
        sum(Dataset.AC_Status == ac_unique(k)));

end

fprintf('\n-- Overall Status --\n');

status_unique = unique(Dataset.Simulation_Status);

for k = 1:numel(status_unique)

    fprintf('  %-25s %d\n', ...
        status_unique(k), ...
        sum(Dataset.Simulation_Status == status_unique(k)));

end

fprintf('===========================\n\n');

% ================================================================
% Existing quality checks and visualization
% ================================================================

dataset_quality_checks(Dataset);

visualize_ce_dataset(Dataset);
%% test_spice_baseline.m
% Verification script for single baseline circuit SPICE execution & perturbation
clear; clc;

root_dir = setup_project_paths();
dataset_path = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
model_path = fullfile(root_dir, 'spice', 'models', '2N3904.lib');
ngspice_exe = 'C:\ngspice-47_64\bin\ngspice_con.exe';

fprintf('========================================\n');
fprintf('SPICE BASELINE & PERTURBATION TEST\n');
fprintf('========================================\n');

assert(isfile(dataset_path), 'Dataset file not found');
assert(isfile(model_path), '2N3904 SPICE model not found');
assert(isfile(ngspice_exe), 'ngspice executable not found at: %s', ngspice_exe);

% Load baseline circuit from dataset row 1
tbl = readtable(dataset_path);
p_base = table2struct(tbl(1, :));

fprintf('Baseline Circuit (Row 1):\n');
fprintf('  R1=%.2f kOhm, R2=%.2f kOhm, RC=%.2f Ohm, RE=%.2f Ohm, RL=%.2f kOhm, VCC=%.2f V\n', ...
    p_base.R1/1e3, p_base.R2/1e3, p_base.RC, p_base.RE, p_base.RL/1e3, p_base.VCC);
fprintf('  Dataset Stored Gain: %.4f dB\n', p_base.Gain_dB);

% Setup temporary test directory
test_dir = fullfile(root_dir, 'tests', 'spice', 'temp_run');
if ~exist(test_dir, 'dir')
    mkdir(test_dir);
end

% 1. BASELINE SPICE SIMULATION
netlist_base = fullfile(test_dir, 'baseline_test.cir');
gain_file_base = fullfile(test_dir, 'baseline_gain.txt');
phase_file_base = fullfile(test_dir, 'baseline_phase.txt');

write_test_netlist(netlist_base, model_path, p_base, 'baseline_gain.txt', 'baseline_phase.txt');

[status_base, cmdout_base] = run_ngspice_cmd(test_dir, ngspice_exe, 'baseline_test.cir');
assert(status_base == 0, 'Baseline SPICE execution failed!\nLog:\n%s', cmdout_base);

[freq_g, gain_base_vec, gok] = read_wrdata_file(gain_file_base);
assert(gok == 1, 'Failed to parse baseline gain from wrdata output');

% Extract max AC gain
gain_base_dB = max(gain_base_vec);
fprintf('Baseline Simulated Gain: %.4f dB (Diff from dataset: %.4f dB)\n', ...
    gain_base_dB, abs(gain_base_dB - p_base.Gain_dB));

% 2. PERTURBED SPICE SIMULATION (RE + 5%)
p_pert = p_base;
p_pert.RE = p_base.RE * 1.05;

netlist_pert = fullfile(test_dir, 'perturbed_test.cir');
gain_file_pert = fullfile(test_dir, 'perturbed_gain.txt');
phase_file_pert = fullfile(test_dir, 'perturbed_phase.txt');

write_test_netlist(netlist_pert, model_path, p_pert, 'perturbed_gain.txt', 'perturbed_phase.txt');

[status_pert, cmdout_pert] = run_ngspice_cmd(test_dir, ngspice_exe, 'perturbed_test.cir');
assert(status_pert == 0, 'Perturbed SPICE execution failed!\nLog:\n%s', cmdout_pert);

[~, gain_pert_vec, pok] = read_wrdata_file(gain_file_pert);
assert(pok == 1, 'Failed to parse perturbed gain from wrdata output');

gain_pert_dB = max(gain_pert_vec);
delta_gain = gain_pert_dB - gain_base_dB;

fprintf('Perturbed (RE +5%%) Simulated Gain: %.4f dB (Delta Gain: %.4f dB)\n', ...
    gain_pert_dB, delta_gain);

% Clean up temp test directory
rmdir(test_dir, 's');

fprintf('>>> SPICE BASELINE & PERTURBATION TEST PASSED SUCCESSFULLY! <<<\n\n');


%% Helper Functions
function write_test_netlist(netlist_path, model_path, p, gain_filename, phase_filename)
    fid = fopen(netlist_path, 'w');
    assert(fid > 0, 'Could not open netlist file');
    c = onCleanup(@() fclose(fid));

    model_p = strrep(model_path, '\', '/');

    fprintf(fid, '* CE Amplifier Test Netlist\n');
    fprintf(fid, '.include "%s"\n', model_p);
    fprintf(fid, '.options TEMP=27 TNOM=27\n\n');

    fprintf(fid, 'Vcc VCC 0 DC %.8e\n', p.VCC);
    fprintf(fid, 'Vin IN 0 DC 0 AC 1\n');
    fprintf(fid, 'Cin IN BASE %.8e\n', p.Cin);
    fprintf(fid, 'R1 VCC BASE %.8e\n', p.R1);
    fprintf(fid, 'R2 BASE 0 %.8e\n', p.R2);
    fprintf(fid, 'Q1 COLL BASE EMIT 2N3904\n');
    fprintf(fid, 'RC1 VCC COLL %.8e\n', p.RC);
    fprintf(fid, 'RE1 EMIT 0 %.8e\n', p.RE);
    fprintf(fid, 'CE1 EMIT 0 %.8e\n', p.Ce);
    fprintf(fid, 'Cout COLL OUT %.8e\n', p.Cout);
    fprintf(fid, 'RL1 OUT 0 %.8e\n\n', p.RL);

    fprintf(fid, '.control\n');
    fprintf(fid, 'set noaskquit\n');
    fprintf(fid, 'ac dec 20 10 1e9\n');
    % Use relative filenames inside working directory to avoid path spaces / quote issues in ngspice
    fprintf(fid, 'wrdata %s vdb(out)\n', gain_filename);
    fprintf(fid, 'wrdata %s vp(out)\n', phase_filename);
    fprintf(fid, 'quit\n');
    fprintf(fid, '.endc\n');
    fprintf(fid, '.end\n');
end

function [status, cmdout] = run_ngspice_cmd(work_dir, ngspice_exe, netlist_filename)
    cmd = sprintf('cd /d "%s" && "%s" -b "%s"', work_dir, ngspice_exe, netlist_filename);
    [status, cmdout] = system(cmd);
end

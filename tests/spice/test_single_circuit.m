
clear;
clc;
root_dir = fileparts(mfilename('fullpath'));
addpath(root_dir, fullfile(root_dir, 'functions'));
cfg = config();

p.R1 = 47e3;
p.R2 = 10e3;
p.RC = 2.2e3;
p.RE = 1e3;
p.RL = 10e3;

p.Cin = 10e-6;
p.Cout = 10e-6;
p.Ce = 100e-6;

p.VCC = 12;
p.Temperature = 27;

id = 'SMOKETEST';
netlist_path  = fullfile(cfg.netlist_dir, [id '.cir']);
ac_gain_file  = fullfile(cfg.raw_dir, [id '_ac_gain.txt']);
ac_phase_file = fullfile(cfg.raw_dir, [id '_ac_phase.txt']);

write_ce_netlist(netlist_path, cfg.model_path, p, id, ac_gain_file, ac_phase_file, cfg);
fprintf('Wrote netlist: %s\n', netlist_path);
fprintf('--- netlist contents ---\n');
type(netlist_path);
fprintf('------------------------\n\n');

[status, cmdout] = run_ngspice_single(netlist_path, cfg.ngspice_exe);
fprintf('ngspice exit status: %d\n', status);
fprintf('--- ngspice stdout ---\n%s\n----------------------\n\n', cmdout);

[vb, ve, vc, ib, ic, ie, ok] = parse_op_point(cmdout);
if ~ok
    error(['Could not parse the operating point from ngspice output above. ' ...
           'Check that ngspice is installed and on cfg.ngspice_exe, and that ' ...
           'the printed lines look like "v(base) = ...".']);
end
fprintf('VB=%.4f VE=%.4f VC=%.4f  IB=%.4g IC=%.4g IE=%.4g\n', vb, ve, vc, ib, ic, ie);

[freq_g, gain_dB, gok] = read_wrdata_file(ac_gain_file);
[freq_p, phase, pok]   = read_wrdata_file(ac_phase_file);
if ~gok || ~pok
    error('Could not read the AC sweep files at %s / %s.', ac_gain_file, ac_phase_file);
end

[av, av_db, fl, fh, bw, aok] = extract_ac_metrics(freq_g, gain_dB, phase);
fprintf('Av=%.3f (%.2f dB)  fL=%.1f Hz  fH=%.3g Hz  BW=%.3g Hz\n', av, av_db, fl, fh, bw);

[is_valid, status] = validate_operating_point( ...
    vb, vc, ve, ic, ib, p.VCC, cfg);
fprintf('Operating point status: %s\n', status);

if is_valid && aok
    fprintf('\nSmoke test PASSED - safe to run main_generate_dataset.m\n');
else
    fprintf('\nSmoke test ran, but flagged the point as "%s". Check the values above.\n', op_status);
end

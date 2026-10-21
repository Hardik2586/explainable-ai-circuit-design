function write_ce_netlist(netlist_path, model_path, p, circuit_id, ac_gain_file, ac_phase_file, cfg)

    model_path_spice = strrep(model_path, '\', '/');   % SPICE-safe path
    ac_gain_spice     = strrep(ac_gain_file, '\', '/');
    ac_phase_spice    = strrep(ac_phase_file, '\', '/');

    fid = fopen(netlist_path, 'w');
    if fid < 0
        error('Could not open %s for writing.', netlist_path);
    end
    c = onCleanup(@() fclose(fid));

    fprintf(fid, '* CE Amplifier - %s (auto-generated, do not edit by hand)\n', circuit_id);
    fprintf(fid, '.include "%s"\n', model_path_spice);
    fprintf(fid, '.options TEMP=%.4f TNOM=27\n\n', p.Temperature);

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
    fprintf(fid, 'op\n');
    fprintf(fid, 'print v(base)\n');
    fprintf(fid, 'print v(emit)\n');
    fprintf(fid, 'print v(coll)\n');
    fprintf(fid, 'print @q1[ib]\n');
    fprintf(fid, 'print @q1[ic]\n');
    fprintf(fid, 'print @q1[ie]\n');
    fprintf(fid, 'ac dec %d %.6g %.6g\n', cfg.ac_points_per_decade, cfg.ac_fstart, cfg.ac_fstop);
    fprintf(fid, 'wrdata spice_raw/%s_ac_gain.txt vdb(out)\n', circuit_id);
    fprintf(fid, 'wrdata spice_raw/%s_ac_phase.txt vp(out)\n', circuit_id);
    fprintf(fid, 'quit\n');
    fprintf(fid, '.endc\n');
    fprintf(fid, '.end\n');
end

function result = runSpice(params, workDir, options)
% RUNSPICE Execute a single CE amplifier SPICE simulation and parse results.
%
%   result = runSpice(params, workDir)
%   result = runSpice(params, workDir, options)
%
%   INPUTS:
%     params  - struct with fields: R1, R2, RC, RE, RL, Cin, Cout, Ce, VCC
%     workDir - absolute path to temporary working directory for this run
%     options - optional struct with fields:
%       .ngspice_exe          - path to ngspice (default: 'C:\ngspice-47_64\bin\ngspice_con.exe')
%       .model_path           - path to 2N3904.lib (default: auto-detect from project)
%       .temperature          - simulation temperature in C (default: 27)
%       .ac_fstart            - AC sweep start frequency (default: 10 Hz)
%       .ac_fstop             - AC sweep stop frequency (default: 1e9 Hz)
%       .ac_points_per_decade - points per decade (default: 20)
%       .cleanup              - delete workDir after success (default: false)
%
%   OUTPUT:
%     result - struct with fields:
%       .success      - boolean
%       .gain_dB      - midband gain in dB (NaN if failed)
%       .phase_deg    - midband phase in degrees (NaN if failed)
%       .fL           - lower -3dB frequency in Hz (NaN if failed)
%       .fH           - upper -3dB frequency in Hz (NaN if failed)
%       .bandwidth    - bandwidth in Hz (NaN if failed)
%       .freq         - frequency vector from AC sweep
%       .gain_curve   - gain vs frequency curve in dB
%       .phase_curve  - phase vs frequency curve in degrees
%       .exit_code    - ngspice exit code
%       .log          - ngspice stdout/stderr text
%       .error_msg    - error description if failed
%       .netlist_path - path to generated netlist

    %% ---- Initialize default result (failure state) ----
    result = struct();
    result.success      = false;
    result.gain_dB      = NaN;
    result.phase_deg    = NaN;
    result.fL           = NaN;
    result.fH           = NaN;
    result.bandwidth    = NaN;
    result.VB           = NaN;
    result.VE           = NaN;
    result.VC           = NaN;
    result.IB           = NaN;
    result.IC           = NaN;
    result.IE           = NaN;
    result.VCE          = NaN;
    result.freq         = [];
    result.gain_curve   = [];
    result.phase_curve  = [];
    result.exit_code    = -1;
    result.log          = '';
    result.error_msg    = '';
    result.netlist_path = '';

    %% ---- Validate params struct ----
    requiredFields = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
    for i = 1:length(requiredFields)
        if ~isfield(params, requiredFields{i})
            result.error_msg = sprintf('Missing required param field: %s', requiredFields{i});
            return;
        end
    end

    %% ---- Apply default options ----
    if nargin < 3 || isempty(options)
        options = struct();
    end

    if ~isfield(options, 'ngspice_exe')
        options.ngspice_exe = 'C:\ngspice-47_64\bin\ngspice_con.exe';
    end
    if ~isfield(options, 'model_path')
        % Auto-detect: look relative to this function's location
        thisDir = fileparts(mfilename('fullpath'));
        % Navigate from src/spice/ up to project root, then into spice/models/
        projRoot = fileparts(fileparts(thisDir));
        options.model_path = fullfile(projRoot, 'spice', 'models', '2N3904.lib');
    end
    if ~isfield(options, 'temperature')
        options.temperature = 27;
    end
    if ~isfield(options, 'ac_fstart')
        options.ac_fstart = 10;
    end
    if ~isfield(options, 'ac_fstop')
        options.ac_fstop = 1e9;
    end
    if ~isfield(options, 'ac_points_per_decade')
        options.ac_points_per_decade = 20;
    end
    if ~isfield(options, 'cleanup')
        options.cleanup = false;
    end

    %% ---- Verify ngspice executable exists ----
    if ~isfile(options.ngspice_exe)
        result.error_msg = sprintf('ngspice executable not found: %s', options.ngspice_exe);
        return;
    end

    %% ---- Verify model file exists ----
    if ~isfile(options.model_path)
        result.error_msg = sprintf('SPICE model file not found: %s', options.model_path);
        return;
    end

    %% ---- Create workDir if it doesn't exist ----
    if ~isfolder(workDir)
        [mkStatus, mkMsg] = mkdir(workDir);
        if ~mkStatus
            result.error_msg = sprintf('Failed to create workDir: %s - %s', workDir, mkMsg);
            return;
        end
    end

    %% ---- Generate netlist ----
    netlistFile = fullfile(workDir, 'sim.cir');
    result.netlist_path = netlistFile;

    try
        writeNetlist(netlistFile, params, options);
    catch ME
        result.error_msg = sprintf('Failed to write netlist: %s', ME.message);
        return;
    end

    %% ---- Run ngspice ----
    % CRITICAL: cd into workDir so wrdata relative filenames resolve there
    % Use cmd /c to chain cd and ngspice in one shell invocation
    ngspiceCmd = sprintf('cmd /c "cd /d "%s" && "%s" -b "sim.cir""', ...
        workDir, options.ngspice_exe);

    [exitCode, cmdOutput] = system(ngspiceCmd);
    result.exit_code = exitCode;
    result.log = cmdOutput;

    % Parse DC operating point from log
    try
        [VB, VE, VC, IB, IC, IE, op_ok] = parse_op_point(cmdOutput);
        if op_ok
            result.VB  = VB;
            result.VE  = VE;
            result.VC  = VC;
            result.IB  = IB;
            result.IC  = IC;
            result.IE  = IE;
            result.VCE = VC - VE;
        end
    catch
        % Continue even if OP parsing fails
    end

    %% ---- Verify output files exist ----
    gainFile  = fullfile(workDir, 'ac_gain.txt');
    phaseFile = fullfile(workDir, 'ac_phase.txt');

    if ~isfile(gainFile)
        result.error_msg = sprintf('ngspice did not produce ac_gain.txt (exit code %d)', exitCode);
        return;
    end
    if ~isfile(phaseFile)
        result.error_msg = sprintf('ngspice did not produce ac_phase.txt (exit code %d)', exitCode);
        return;
    end

    %% ---- Check files are non-empty ----
    gainInfo  = dir(gainFile);
    phaseInfo = dir(phaseFile);
    if gainInfo.bytes == 0
        result.error_msg = 'ac_gain.txt is empty';
        return;
    end
    if phaseInfo.bytes == 0
        result.error_msg = 'ac_phase.txt is empty';
        return;
    end

    %% ---- Parse gain file ----
    try
        [freq_gain, gain_dB_curve] = parseWrdata(gainFile);
    catch ME
        result.error_msg = sprintf('Failed to parse ac_gain.txt: %s', ME.message);
        return;
    end

    %% ---- Parse phase file ----
    try
        [freq_phase, phase_deg_curve] = parseWrdata(phaseFile);
    catch ME
        result.error_msg = sprintf('Failed to parse ac_phase.txt: %s', ME.message);
        return;
    end

    %% ---- Validate parsed data ----
    if isempty(freq_gain) || isempty(gain_dB_curve)
        result.error_msg = 'Parsed gain data is empty';
        return;
    end
    if isempty(freq_phase) || isempty(phase_deg_curve)
        result.error_msg = 'Parsed phase data is empty';
        return;
    end

    %% ---- Store curves ----
    result.freq        = freq_gain;
    result.gain_curve  = gain_dB_curve;
    result.phase_curve = phase_deg_curve;

    %% ---- Calculate midband gain (maximum of gain curve) ----
    [midband_gain, midIdx] = max(gain_dB_curve);
    result.gain_dB  = midband_gain;
    result.phase_deg = phase_deg_curve(midIdx);

    %% ---- Calculate -3dB frequencies ----
    threshold = midband_gain - 3.0;

    % Lower -3dB frequency: find where gain crosses threshold from below
    % (left side of the peak)
    fL = NaN;
    if midIdx > 1
        leftGain = gain_dB_curve(1:midIdx);
        leftFreq = freq_gain(1:midIdx);
        % Find last crossing below threshold going left from peak
        idxBelow = find(leftGain < threshold, 1, 'last');
        if ~isempty(idxBelow) && idxBelow < length(leftGain)
            % Linear interpolation between idxBelow and idxBelow+1
            f1 = leftFreq(idxBelow);
            f2 = leftFreq(idxBelow + 1);
            g1 = leftGain(idxBelow);
            g2 = leftGain(idxBelow + 1);
            if g2 ~= g1
                fL = f1 * (f2/f1) ^ ((threshold - g1) / (g2 - g1));
            else
                fL = f1;
            end
        end
    end

    % Upper -3dB frequency: find where gain drops below threshold
    % (right side of the peak)
    fH = NaN;
    if midIdx < length(gain_dB_curve)
        rightGain = gain_dB_curve(midIdx:end);
        rightFreq = freq_gain(midIdx:end);
        % Find first crossing below threshold going right from peak
        idxBelow = find(rightGain < threshold, 1, 'first');
        if ~isempty(idxBelow) && idxBelow > 1
            % Linear interpolation between idxBelow-1 and idxBelow
            f1 = rightFreq(idxBelow - 1);
            f2 = rightFreq(idxBelow);
            g1 = rightGain(idxBelow - 1);
            g2 = rightGain(idxBelow);
            if g2 ~= g1
                fH = f1 * (f2/f1) ^ ((threshold - g1) / (g2 - g1));
            else
                fH = f1;
            end
        end
    end

    result.fL = fL;
    result.fH = fH;
    if ~isnan(fL) && ~isnan(fH)
        result.bandwidth = fH - fL;
    end

    %% ---- Mark success ----
    result.success = true;

    %% ---- Cleanup if requested ----
    if options.cleanup && result.success
        try
            rmdir(workDir, 's');
        catch
            % Silently ignore cleanup failures
        end
    end
end


%% ========================================================================
%  LOCAL FUNCTION: writeNetlist
%  Generates the CE amplifier netlist file in the exact canonical format.
%  ========================================================================
function writeNetlist(netlistFile, params, options)
    % Convert model path to forward slashes for ngspice compatibility
    modelPath = strrep(options.model_path, '\', '/');

    fid = fopen(netlistFile, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', netlistFile);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    % ---- Title line ----
    fprintf(fid, 'CE Amplifier - AC Analysis\n');
    fprintf(fid, '\n');

    % ---- Include transistor model ----
    fprintf(fid, '.include "%s"\n', modelPath);
    fprintf(fid, '\n');

    % ---- Power supply ----
    fprintf(fid, '* Power Supply\n');
    fprintf(fid, 'Vcc VCC 0 DC %.10g\n', params.VCC);
    fprintf(fid, '\n');

    % ---- Input AC source ----
    fprintf(fid, '* Input AC Source\n');
    fprintf(fid, 'Vin IN 0 DC 0 AC 1\n');
    fprintf(fid, '\n');

    % ---- Input coupling capacitor ----
    fprintf(fid, '* Input Coupling Capacitor\n');
    fprintf(fid, 'Cin IN BASE %.10g\n', params.Cin);
    fprintf(fid, '\n');

    % ---- Bias resistors ----
    fprintf(fid, '* Bias Network\n');
    fprintf(fid, 'R1 VCC BASE %.10g\n', params.R1);
    fprintf(fid, 'R2 BASE 0 %.10g\n', params.R2);
    fprintf(fid, '\n');

    % ---- Transistor ----
    fprintf(fid, '* Transistor\n');
    fprintf(fid, 'Q1 COLL BASE EMIT 2N3904\n');
    fprintf(fid, '\n');

    % ---- Collector resistor ----
    fprintf(fid, '* Collector Resistor\n');
    fprintf(fid, 'RC1 VCC COLL %.10g\n', params.RC);
    fprintf(fid, '\n');

    % ---- Emitter resistor and bypass capacitor ----
    fprintf(fid, '* Emitter Resistor and Bypass\n');
    fprintf(fid, 'RE1 EMIT 0 %.10g\n', params.RE);
    fprintf(fid, 'CE1 EMIT 0 %.10g\n', params.Ce);
    fprintf(fid, '\n');

    % ---- Output coupling capacitor ----
    fprintf(fid, '* Output Coupling Capacitor\n');
    fprintf(fid, 'Cout COLL OUT %.10g\n', params.Cout);
    fprintf(fid, '\n');

    % ---- Load resistor ----
    fprintf(fid, '* Load Resistor\n');
    fprintf(fid, 'RL1 OUT 0 %.10g\n', params.RL);
    fprintf(fid, '\n');

    % ---- Temperature setting ----
    fprintf(fid, '* Temperature\n');
    fprintf(fid, '.options TEMP=%.1f\n', options.temperature);
    fprintf(fid, '\n');

    % ---- DC Operating Point & AC analysis ----
    fprintf(fid, '* DC Operating Point & AC Analysis\n');
    fprintf(fid, '.control\n');
    fprintf(fid, 'op\n');
    fprintf(fid, 'print v(base)\n');
    fprintf(fid, 'print v(emit)\n');
    fprintf(fid, 'print v(coll)\n');
    fprintf(fid, 'print @q1[ib]\n');
    fprintf(fid, 'print @q1[ic]\n');
    fprintf(fid, 'print @q1[ie]\n');
    fprintf(fid, 'ac dec %d %.10g %.10g\n', options.ac_points_per_decade, ...
        options.ac_fstart, options.ac_fstop);
    fprintf(fid, 'wrdata ac_gain.txt vdb(out)\n');
    fprintf(fid, 'wrdata ac_phase.txt vp(out)\n');
    fprintf(fid, 'quit\n');
    fprintf(fid, '.endc\n');
    fprintf(fid, '\n');
    fprintf(fid, '.end\n');
end


%% ========================================================================
%  LOCAL FUNCTION: parseWrdata
%  Parses ngspice wrdata output (two columns: index/frequency, value).
%  ngspice wrdata format: each line has "freq\tvalue" or "freq  value"
%  Note: wrdata can produce lines with index numbers or frequency values
%  in column 1 depending on ngspice version.
%  ========================================================================
function [freq, values] = parseWrdata(filepath)
    % Read raw text
    fid = fopen(filepath, 'r');
    if fid == -1
        error('Cannot open file: %s', filepath);
    end
    rawText = fread(fid, '*char')';
    fclose(fid);

    % Split into lines
    lines = strsplit(rawText, {'\r\n', '\n', '\r'});

    freq   = [];
    values = [];

    for i = 1:length(lines)
        line = strtrim(lines{i});
        if isempty(line)
            continue;
        end

        % Parse whitespace-separated numeric columns
        tokens = strsplit(line);
        nums = str2double(tokens);

        % We expect at least 2 numeric columns
        if length(nums) >= 2 && ~isnan(nums(1)) && ~isnan(nums(2))
            freq(end+1)   = nums(1);    %#ok<AGROW>
            values(end+1) = nums(2);    %#ok<AGROW>
        end
    end

    freq   = freq(:);
    values = values(:);
end

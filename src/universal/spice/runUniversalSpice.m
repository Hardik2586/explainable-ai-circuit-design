function result = runUniversalSpice(circuit, modelManager, options)

    %% ============================================================
    % INITIALIZE
    % =============================================================

    result = SimulationResult();

    %% ============================================================
    % INPUT VALIDATION
    % =============================================================

    if nargin < 1 || isempty(circuit)

        result.ErrorMessage = ...
            "Circuit input is required.";

        result.Success = false;
        return;

    end

    if nargin < 2 || isempty(modelManager)

        modelManager = ModelManager();

    end

    if nargin < 3 || isempty(options)

        options = struct();

    end

    %% ============================================================
    % EXECUTION DEFAULTS
    % =============================================================

    execution.NgspiceExe = ...
        "C:\ngspice-47_64\bin\ngspice_con.exe";

    execution.WorkDir = "";

    execution.KeepFiles = false;

    %% ============================================================
    % ANALYSIS DEFAULTS
    % =============================================================

    analysisOptions = struct();

    analysisOptions.Analysis = "AC";

    analysisOptions.ACStart = 10;

    analysisOptions.ACStop = 1e6;

    analysisOptions.PointsPerDecade = 50;

    analysisOptions.TimeStep = [];

    analysisOptions.StopTime = [];

    analysisOptions.StartTime = [];

    analysisOptions.PrintExpressions = strings(0,1);

    %% ============================================================
    % HANDLE ANALYSIS SPEC
    % =============================================================

    if isa(options, "AnalysisSpec")

        % ---------------------------------------------------------
        % Resolve AnalysisSpec
        % ---------------------------------------------------------

        spec = resolveAnalysisSpec(options);

        analysisOptions.Analysis = ...
            string(spec.Type);

        analysisOptions.ACStart = ...
            spec.ACStart;

        analysisOptions.ACStop = ...
            spec.ACStop;

        analysisOptions.PointsPerDecade = ...
            spec.PointsPerDecade;

        analysisOptions.TimeStep = ...
            spec.TimeStep;

        analysisOptions.StopTime = ...
            spec.StopTime;

        analysisOptions.StartTime = ...
            spec.StartTime;

        analysisOptions.PrintExpressions = ...
            buildPrintExpressions(options);

    elseif isstruct(options)

        % ---------------------------------------------------------
        % Legacy options structure
        % ---------------------------------------------------------

        if isfield(options, "NgspiceExe") && ...
                ~isempty(options.NgspiceExe)

            execution.NgspiceExe = ...
                string(options.NgspiceExe);

        end

        if isfield(options, "WorkDir") && ...
                ~isempty(options.WorkDir)

            execution.WorkDir = ...
                string(options.WorkDir);

        end

        if isfield(options, "KeepFiles")

            execution.KeepFiles = ...
                logical(options.KeepFiles);

        end

        if isfield(options, "Analysis")

            analysisOptions.Analysis = ...
                string(options.Analysis);

        end

        if isfield(options, "ACStart")

            analysisOptions.ACStart = ...
                options.ACStart;

        end

        if isfield(options, "ACStop")

            analysisOptions.ACStop = ...
                options.ACStop;

        end

        if isfield(options, "PointsPerDecade")

            analysisOptions.PointsPerDecade = ...
                options.PointsPerDecade;

        end

        if isfield(options, "TimeStep")

            analysisOptions.TimeStep = ...
                options.TimeStep;

        end

        if isfield(options, "StopTime")

            analysisOptions.StopTime = ...
                options.StopTime;

        end

        if isfield(options, "StartTime")

            analysisOptions.StartTime = ...
                options.StartTime;

        end

        if isfield(options, "PrintExpressions")

            analysisOptions.PrintExpressions = ...
                string(options.PrintExpressions);

        end

    else

        result.ErrorMessage = ...
            "Third input must be an AnalysisSpec or options struct.";

        result.Success = false;

        return;

    end

    %% ============================================================
    % VALIDATE NGSPICE
    % =============================================================

    ngspiceExe = char(execution.NgspiceExe);

    if ~isfile(ngspiceExe)

        result.ErrorMessage = ...
            "ngspice executable not found: " + ...
            string(ngspiceExe);

        result.Success = false;

        return;

    end

    %% ============================================================
    % CREATE WORK DIRECTORY
    % =============================================================

    if strlength(string(execution.WorkDir)) == 0

        workDir = fullfile( ...
            tempdir, ...
            "UniversalSPICE_" + ...
            char(string(java.util.UUID.randomUUID)));

        if ~exist(workDir, "dir")

            mkdir(workDir);

        end

        ownsWorkDir = true;

    else

        workDir = char(execution.WorkDir);

        if ~exist(workDir, "dir")

            mkdir(workDir);

        end

        ownsWorkDir = false;

    end

    %% ============================================================
    % GENERATE NETLIST
    % =============================================================

    try

        analysisSpec = createAnalysisSpec( ...
            analysisOptions.Analysis);

        analysisSpec.ACStart = ...
            analysisOptions.ACStart;

        analysisSpec.ACStop = ...
            analysisOptions.ACStop;

        analysisSpec.PointsPerDecade = ...
            analysisOptions.PointsPerDecade;

        analysisSpec.TimeStep = ...
            analysisOptions.TimeStep;

        analysisSpec.StopTime = ...
            analysisOptions.StopTime;

        analysisSpec.StartTime = ...
            analysisOptions.StartTime;

        analysisSpec.CustomExpressions = ...
            analysisOptions.PrintExpressions;

        netlist = generateNetlist( ...
            circuit, ...
            modelManager, ...
            analysisSpec);

    catch ME

        result.ErrorMessage = ...
            "Netlist generation failed: " + ...
            string(ME.message);

        result.Success = false;

        if ownsWorkDir && ~execution.KeepFiles

            if exist(workDir, "dir")

                rmdir(workDir, "s");

            end

        end

        return;

    end

    %% ============================================================
    % WRITE NETLIST
    % =============================================================

    netlistPath = ...
        fullfile(workDir, "circuit.cir");

    outputPath = ...
        fullfile(workDir, "spice_output.txt");

    fid = fopen(netlistPath, "w");

    if fid < 0

        result.ErrorMessage = ...
            "Could not create netlist file.";

        result.Success = false;

        return;

    end

    fprintf(fid, "%s\n", netlist);

    fclose(fid);

    %% ============================================================
    % RUN NGSPICE
    % =============================================================

    oldDir = pwd;

    cleanupObj = onCleanup(@() cd(oldDir));

    try

        cd(workDir);

        command = sprintf( ...
            '"%s" -b circuit.cir -o spice_output.txt', ...
            ngspiceExe);

        [exitCode, commandOutput] = system(command);

    catch ME

        result.ErrorMessage = ...
            "ngspice execution failed: " + ...
            string(ME.message);

        result.Success = false;

        return;

    end

    %% ============================================================
    % STORE EXECUTION INFORMATION
    % =============================================================

    result.CircuitName = ...
        circuit.Name;

    result.Topology = ...
        string(circuit.Metadata.Topology);

    result.Analysis = ...
        upper(string(analysisOptions.Analysis));

    result.ExitCode = ...
        exitCode;

    result.WorkDir = ...
        string(workDir);

    result.NetlistPath = ...
        string(netlistPath);

    result.OutputPath = ...
        string(outputPath);

    %% ============================================================
    % READ OUTPUT
    % =============================================================

    if exist(outputPath, "file")

        rawOutput = fileread(outputPath);

    else

        rawOutput = commandOutput;

    end

    result.RawOutput = ...
        string(rawOutput);

    %% ============================================================
    % PARSE OUTPUT
    % ============================================================

    %% ============================================================
    % PARSE OUTPUT
    % ============================================================

    executionResult = struct();

    executionResult.Success = ...
        exitCode == 0;

    executionResult.CircuitName = ...
        result.CircuitName;

    executionResult.Topology = ...
        result.Topology;

    executionResult.Analysis = ...
        result.Analysis;

    executionResult.ExitCode = ...
        result.ExitCode;

    executionResult.WorkDir = ...
        result.WorkDir;

    executionResult.NetlistPath = ...
        result.NetlistPath;

    executionResult.OutputPath = ...
        result.OutputPath;

    executionResult.RawOutput = ...
        result.RawOutput;
  
    executionResult.ErrorMessage = "";

    %% ============================================================
    % PARSE OUTPUT
    % ============================================================

    executionResult = struct();

    executionResult.Success = ...
        (exitCode == 0);

    executionResult.ExitCode = ...
        exitCode;

    executionResult.WorkDir = ...
        string(workDir);

    executionResult.NetlistPath = ...
        string(netlistPath);

    executionResult.OutputPath = ...
        string(outputPath);

    executionResult.CircuitName = ...
        string(circuit.Name);

    executionResult.Topology = ...
        string(circuit.Metadata.Topology);

    executionResult.Analysis = ...
        upper(string(analysisOptions.Analysis));

    executionResult.RawOutput = ...
        string(rawOutput);

    executionResult.ErrorMessage = "";

    %% ============================================================
    % PARSE WITH UNIVERSAL SPICE PARSER
    % ============================================================

    result = parseSpiceOutput(executionResult);
    %% ============================================================
    % CLEANUP
    % =============================================================

    if ownsWorkDir && ~execution.KeepFiles

        if exist(workDir, "dir")

            try
                rmdir(workDir, "s");
            catch
            end

        end

    end

end
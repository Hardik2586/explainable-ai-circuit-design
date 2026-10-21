function netlist = generateNetlist(circuit, modelManager, options)

    %% ============================================================
    % INPUT VALIDATION
    % =============================================================

    if ~isa(circuit,"Circuit")

        error( ...
            "generateNetlist:InvalidCircuit", ...
            "Input must be a Circuit object.");

    end


    if ~isa(modelManager,"ModelManager")

        error( ...
            "generateNetlist:InvalidModelManager", ...
            "Second input must be a ModelManager object.");

    end


    %% ============================================================
    % THIRD ARGUMENT
    % =============================================================

    if nargin < 3 || isempty(options)

        % Default universal AC specification.
        options = createAnalysisSpec("AC");

    end


    %% ============================================================
    % ANALYSIS SPECIFICATION
    % =============================================================

    if isa(options,"AnalysisSpec")

        analysisSpec = options;

        % ---------------------------------------------------------
        % Validate AnalysisSpec
        % ---------------------------------------------------------

        validation = validateAnalysisSpec(analysisSpec);

        if ~validation.Valid

            error( ...
                "generateNetlist:InvalidAnalysisSpec", ...
                "%s", ...
                strjoin(validation.Errors,newline));

        end


        % ---------------------------------------------------------
        % Resolve AnalysisSpec
        % ---------------------------------------------------------

        resolvedSpec = ...
            resolveAnalysisSpec(analysisSpec);


        % ---------------------------------------------------------
        % Build SPICE print expressions
        % ---------------------------------------------------------

        printExpressions = ...
            buildPrintExpressions(analysisSpec);


        % ---------------------------------------------------------
        % Convert to internal options structure
        % ---------------------------------------------------------

        netlistOptions = struct();

        netlistOptions.Title = ...
            char(circuit.Name);

        netlistOptions.Analysis = ...
            resolvedSpec.Type;

        netlistOptions.ACStart = ...
            resolvedSpec.ACStart;

        netlistOptions.ACStop = ...
            resolvedSpec.ACStop;

        netlistOptions.PointsPerDecade = ...
            resolvedSpec.PointsPerDecade;

        netlistOptions.TimeStep = ...
            resolvedSpec.TimeStep;

        netlistOptions.StopTime = ...
            resolvedSpec.StopTime;

        netlistOptions.StartTime = ...
            resolvedSpec.StartTime;

        netlistOptions.PrintExpressions = ...
            printExpressions;


    elseif isstruct(options)

        % ---------------------------------------------------------
        % LEGACY OPTIONS SUPPORT
        % ---------------------------------------------------------

        netlistOptions = options;


        if ~isfield(netlistOptions,"Title")

            netlistOptions.Title = ...
                char(circuit.Name);

        end


        if ~isfield(netlistOptions,"Analysis")

            netlistOptions.Analysis = ...
                "AC";

        end


        if ~isfield(netlistOptions,"ACStart")

            netlistOptions.ACStart = 10;

        end


        if ~isfield(netlistOptions,"ACStop")

            netlistOptions.ACStop = 1e9;

        end


        if ~isfield(netlistOptions,"PointsPerDecade")

            netlistOptions.PointsPerDecade = 100;

        end


    else

        error( ...
            "generateNetlist:InvalidOptions", ...
            "Third input must be an AnalysisSpec object or an options struct.");

    end


    %% ============================================================
    % CIRCUIT VALIDATION
    % =============================================================

    validation = validateCircuit(circuit);

    if ~validation.Valid

        error( ...
            "generateNetlist:InvalidCircuit", ...
            "Circuit validation failed:%s%s", ...
            newline, ...
            strjoin(validation.Errors,newline));

    end


    %% ============================================================
    % REQUIRED MODEL VALIDATION
    % =============================================================

    validateRequiredModels( ...
        circuit, ...
        modelManager);


    %% ============================================================
    % INITIALIZE NETLIST
    % =============================================================

    lines = strings(0,1);


    %% ============================================================
    % HEADER
    % =============================================================

    lines(end+1,1) = ...
        "* ==================================================";

    lines(end+1,1) = ...
        "* Universal Circuit-XAI SPICE Netlist";

    lines(end+1,1) = ...
        "* ==================================================";

    lines(end+1,1) = ...
        "* Circuit: " + ...
        string(netlistOptions.Title);


    % -------------------------------------------------------------
    % Topology
    % -------------------------------------------------------------

    if isfield(circuit.Metadata,"Topology")

        lines(end+1,1) = ...
            "* Topology: " + ...
            string(circuit.Metadata.Topology);

    end


    % -------------------------------------------------------------
    % Timestamp
    % -------------------------------------------------------------

    lines(end+1,1) = ...
        "* Generated: " + ...
        string(datetime("now"));

    lines(end+1,1) = ...
        "* ==================================================";

    lines(end+1,1) = "";


%% ============================================================
% EXTERNAL SUBCIRCUIT LIBRARIES
% ============================================================

libraryPaths = strings(0,1);

for k = 1:numel(circuit.Components)

    comp = circuit.Components(k);

    if upper(string(comp.Type)) ~= "MOSFET"
        continue;
    end

    % Check whether this MOSFET uses a subcircuit.
    useSubcircuit = false;

    if isstruct(comp.Parameters) && ...
            isfield(comp.Parameters, "UseSubcircuit")
        useSubcircuit = logical(comp.Parameters.UseSubcircuit);
    end

    if ~useSubcircuit
        continue;
    end

    % Retrieve the registered subcircuit library.
    model = modelManager.getModel(string(comp.Model));

    if upper(string(model.Source)) ~= "FILE"
        error( ...
            "generateNetlist:SubcircuitMustBeFileModel", ...
            "Subcircuit '%s' must be registered as a file model.", ...
            comp.Model);
    end

    libraryPath = string(model.Path);

    if strlength(libraryPath) == 0 || ~isfile(libraryPath)
        error( ...
            "generateNetlist:LibraryNotFound", ...
            "Subcircuit library not found: %s", ...
            libraryPath);
    end

    % Normalize Windows paths for SPICE.
    libraryPath = replace(libraryPath, "\", "/");

    % Avoid duplicate includes.
    if ~any(strcmpi(libraryPaths, libraryPath))
        libraryPaths(end+1,1) = libraryPath;
    end

end

% Emit each external library before the component instances.
for k = 1:numel(libraryPaths)
    if k == 1
        lines(end+1,1) = "";
        lines(end+1,1) = "* EXTERNAL SUBCIRCUIT LIBRARIES";
    end

    lines(end+1,1) = ...
        ".include " + '"' + libraryPaths(k) + '"';
end

if ~isempty(libraryPaths)
    lines(end+1,1) = "";
end



    %% ============================================================
    % COMPONENTS
    % =============================================================

    for k = 1:numel(circuit.Components)

        component = ...
            circuit.Components(k);

        spiceLine = ...
            componentToSpice(component);

        lines(end+1,1) = ...
            string(spiceLine);

    end


    %% ============================================================
    % MODEL DEFINITIONS
    % =============================================================

    modelLines = ...
        generateRegisteredModelSection( ...
            circuit, ...
            modelManager);


    if ~isempty(modelLines)

        lines(end+1,1) = "";

        lines(end+1,1) = ...
            "* ==================================================";

        lines(end+1,1) = ...
            "* MODEL DEFINITIONS";

        lines(end+1,1) = ...
            "* ==================================================";


        modelLines = ...
            string(modelLines(:));


        for k = 1:numel(modelLines)

            lines(end+1,1) = ...
                modelLines(k);

        end

    end


    %% ============================================================
    % ANALYSIS
    % =============================================================

    lines(end+1,1) = "";

    lines(end+1,1) = ...
        "* ==================================================";

    lines(end+1,1) = ...
        "* ANALYSIS";

    lines(end+1,1) = ...
        "* ==================================================";


    analysisType = ...
        upper(string(netlistOptions.Analysis));


    switch analysisType

        %% ========================================================
        % AC
        % ========================================================

        case "AC"

            lines(end+1,1) = ...
                string(sprintf( ...
                    ".ac dec %d %.12g %.12g", ...
                    netlistOptions.PointsPerDecade, ...
                    netlistOptions.ACStart, ...
                    netlistOptions.ACStop));


            if isfield( ...
                    netlistOptions, ...
                    "PrintExpressions") && ...
                    ~isempty(netlistOptions.PrintExpressions)

                
               expressions = string(netlistOptions.PrintExpressions);

               % Handle legacy comma-separated expression strings
               if isscalar(expressions) && contains(expressions, ",")
                  expressions = split(expressions, ",");
               end

               % Normalize expressions
               expressions = strip(expressions(:));
               expressions(expressions == "") = [];
              

                lines(end+1,1) = ...
                    ".print ac " + ...
                    strjoin(expressions," ");

            else

                % Universal fallback.
                lines(end+1,1) = ...
                    ".print ac frequency";

            end


        %% ========================================================
        % DC
        % ========================================================

        case "DC"
            lines(end+1,1) = ...
                ".op";


            % -----------------------------------------------------
            % Optional requested DC outputs
            % -----------------------------------------------------

            if isfield( ...
                    netlistOptions, ...
                    "PrintExpressions") && ...
                    ~isempty(netlistOptions.PrintExpressions)

                expressions = ...
                    string(netlistOptions.PrintExpressions);

                expressions = ...
                    expressions(:);

                lines(end+1,1) = ...
                    ".print dc " + ...
                    strjoin(expressions," ");

            end


        %% ========================================================
        % TRANSIENT
        % ========================================================

        case "TRAN"

            if ~isfield(netlistOptions,"TimeStep") || ...
                    isempty(netlistOptions.TimeStep)

                error( ...
                    "generateNetlist:MissingTimeStep", ...
                    "Transient analysis requires TimeStep.");

            end


            if ~isfield(netlistOptions,"StopTime") || ...
                    isempty(netlistOptions.StopTime)

                error( ...
                    "generateNetlist:MissingStopTime", ...
                    "Transient analysis requires StopTime.");

            end


            lines(end+1,1) = ...
                string(sprintf( ...
                    ".tran %.12g %.12g", ...
                    netlistOptions.TimeStep, ...
                    netlistOptions.StopTime));


            if isfield( ...
                    netlistOptions, ...
                    "PrintExpressions") && ...
                    ~isempty(netlistOptions.PrintExpressions)

                expressions = ...
                    string(netlistOptions.PrintExpressions);

                expressions = ...
                    expressions(:);

                lines(end+1,1) = ...
                    ".print tran " + ...
                    strjoin(expressions," ");

            end


        %% ========================================================
        % UNSUPPORTED
        % ========================================================

        otherwise

            error( ...
                "generateNetlist:UnsupportedAnalysis", ...
                "Unsupported analysis type '%s'.", ...
                analysisType);

    end


    %% ============================================================
    % END
    % =============================================================

    lines(end+1,1) = "";

    lines(end+1,1) = ".end";


    %% ============================================================
    % RETURN
    % =============================================================

    netlist = ...
        strjoin(lines,newline);

end
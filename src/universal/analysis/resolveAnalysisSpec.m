function resolved = resolveAnalysisSpec(spec)


    if ~isa(spec,"AnalysisSpec")

        error( ...
            "resolveAnalysisSpec:InvalidInput", ...
            "Input must be an AnalysisSpec object.");

    end


    validation = validateAnalysisSpec(spec);


    if ~validation.Valid

        error( ...
            "resolveAnalysisSpec:InvalidSpec", ...
            "%s", ...
            strjoin(validation.Errors,newline));

    end


    resolved = struct();

    resolved.Type = upper(string(spec.Type));

    resolved.OutputNodes = ...
        unique(string(spec.OutputNodes),"stable");

    resolved.DCNodes = ...
        unique(string(spec.DCNodes),"stable");

    resolved.Branches = ...
        unique(string(spec.Branches),"stable");

    resolved.Signals = ...
        unique(lower(string(spec.Signals)),"stable");

    resolved.CustomExpressions = ...
        unique(string(spec.CustomExpressions),"stable");

    resolved.Warnings = ...
        validation.Warnings;


    %% ============================================================
    % NORMALIZE DEFAULT SIGNALS
    % ============================================================

    switch resolved.Type

        case "AC"

            if isempty(resolved.Signals)

                resolved.Signals = [
                    "magnitude"
                    "phase"
                ];

            end


        case "DC"

            if isempty(resolved.Signals)

                resolved.Signals = [
                    "voltage"
                    "current"
                ];

            end


        case "TRAN"

            if isempty(resolved.Signals)

                resolved.Signals = [
                    "voltage"
                    "current"
                ];

            end

    end


    %% ============================================================
    % COPY ANALYSIS SETTINGS
    % ============================================================

    resolved.ACStart = spec.ACStart;

    resolved.ACStop = spec.ACStop;

    resolved.PointsPerDecade = ...
        spec.PointsPerDecade;

    resolved.TimeStep = ...
        spec.TimeStep;

    resolved.StopTime = ...
        spec.StopTime;

    resolved.StartTime = ...
        spec.StartTime;


    %% ============================================================
    % METADATA
    % ============================================================

    resolved.Name = spec.Name;

    resolved.Description = spec.Description;

    resolved.Metadata = spec.Metadata;

end
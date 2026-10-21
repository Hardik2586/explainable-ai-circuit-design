function result = validateAnalysisSpec(spec)
%VALIDATEANALYSISSPEC Validate a universal AnalysisSpec.
%
% Returns:
%
%   result.Valid
%   result.Errors
%   result.Warnings

    if ~isa(spec,"AnalysisSpec")

        error( ...
            "validateAnalysisSpec:InvalidInput", ...
            "Input must be an AnalysisSpec object.");

    end


    result = struct();

    result.Valid = true;

    result.Errors = strings(0,1);

    result.Warnings = strings(0,1);


    type = upper(string(spec.Type));


    %% ============================================================
    % TYPE
    % ============================================================

    validTypes = ["AC","DC","TRAN"];

    if ~ismember(type,validTypes)

        result.Valid = false;

        result.Errors(end+1,1) = ...
            "Unsupported analysis type: " + type;

        return;

    end


    %% ============================================================
    % AC
    % ============================================================

    if type == "AC"

        if ~isscalar(spec.ACStart) || ...
                ~isfinite(spec.ACStart) || ...
                spec.ACStart <= 0

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "ACStart must be a positive finite scalar.";

        end


        if ~isscalar(spec.ACStop) || ...
                ~isfinite(spec.ACStop) || ...
                spec.ACStop <= 0

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "ACStop must be a positive finite scalar.";

        end


        if isfinite(spec.ACStart) && ...
                isfinite(spec.ACStop) && ...
                spec.ACStop <= spec.ACStart

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "ACStop must be greater than ACStart.";

        end


        if ~isscalar(spec.PointsPerDecade) || ...
                ~isfinite(spec.PointsPerDecade) || ...
                spec.PointsPerDecade <= 0

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "PointsPerDecade must be positive.";

        end


        if isempty(spec.OutputNodes) && ...
                isempty(spec.CustomExpressions)

            result.Warnings(end+1,1) = ...
                "No AC output node or custom expression was specified.";

        end

    end


    %% ============================================================
    % DC
    % ============================================================

    if type == "DC"

        if isempty(spec.DCNodes) && ...
                isempty(spec.Branches) && ...
                isempty(spec.CustomExpressions)

            result.Warnings(end+1,1) = ...
                "No DC nodes, branches or custom expressions were specified.";

        end

    end


    %% ============================================================
    % TRAN
    % ============================================================

    if type == "TRAN"

        if isempty(spec.TimeStep) || ...
                ~isscalar(spec.TimeStep) || ...
                ~isfinite(spec.TimeStep) || ...
                spec.TimeStep <= 0

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "TRAN TimeStep must be a positive finite scalar.";

        end


        if isempty(spec.StopTime) || ...
                ~isscalar(spec.StopTime) || ...
                ~isfinite(spec.StopTime) || ...
                spec.StopTime <= 0

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "TRAN StopTime must be a positive finite scalar.";

        end


        if ~isempty(spec.StartTime)

            if ~isscalar(spec.StartTime) || ...
                    ~isfinite(spec.StartTime) || ...
                    spec.StartTime < 0

                result.Valid = false;

                result.Errors(end+1,1) = ...
                    "TRAN StartTime must be non-negative.";

            end

        end


        if ~isempty(spec.StartTime) && ...
                isfinite(spec.StartTime) && ...
                spec.StopTime <= spec.StartTime

            result.Valid = false;

            result.Errors(end+1,1) = ...
                "TRAN StopTime must be greater than StartTime.";

        end

    end

end
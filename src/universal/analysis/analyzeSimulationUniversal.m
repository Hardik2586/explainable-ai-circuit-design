function result = analyzeSimulationUniversal(simResult)

    %% ============================================================
    %  INITIALIZE
    % =============================================================

    result = AnalysisResult();

    %% ============================================================
    %  INPUT VALIDATION
    % =============================================================

    if nargin < 1 || isempty(simResult)

        result = result.addError( ...
            "SimulationResult input is required.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  TYPE VALIDATION
    % =============================================================

    if ~isa(simResult, "SimulationResult")

        result = result.addError( ...
            "Input must be a SimulationResult object.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  CHECK SIMULATION STATUS
    % =============================================================

    if ~simResult.Success

        result.CircuitName = simResult.CircuitName;
        result.Topology = simResult.Topology;

        try
            result.AnalysisType = simResult.Analysis;
        catch
            result.AnalysisType = "Unknown";
        end

        result = result.addError( ...
            "SPICE simulation was not successful.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  GET ANALYSIS TYPE
    % =============================================================

    try

        analysisType = upper(strtrim(string(simResult.Analysis)));

    catch

        result = result.addError( ...
            "Unable to determine simulation analysis type.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  DISPATCH
    % =============================================================

    try

        switch analysisType

            %% ----------------------------------------------------
            % AC ANALYSIS
            % -----------------------------------------------------

            case "AC"

                result = analyzeAC(simResult);

            %% ----------------------------------------------------
            % DC ANALYSIS
            % -----------------------------------------------------

            case "DC"

                result = analyzeDC(simResult);

            %% ----------------------------------------------------
            % TRANSIENT ANALYSIS
            % -----------------------------------------------------

            case {"TRAN", "TRANSIENT"}

                result = analyzeTRAN(simResult);

            %% ----------------------------------------------------
            % UNSUPPORTED
            % -----------------------------------------------------

            otherwise

                result.CircuitName = simResult.CircuitName;
                result.Topology = simResult.Topology;
                result.AnalysisType = analysisType;

                result = result.addError( ...
                    "Unsupported simulation analysis type: " + ...
                    analysisType);

                result.Success = false;

        end

    catch ME

        %% ========================================================
        %  CONTROLLED ERROR
        % =========================================================

        result.CircuitName = simResult.CircuitName;
        result.Topology = simResult.Topology;
        result.AnalysisType = analysisType;

        result = result.addError( ...
            "Analysis engine failed: " + string(ME.message));

        result.Success = false;

    end

end
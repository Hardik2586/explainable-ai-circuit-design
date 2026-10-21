function result = analyzeTopology(circuit, simResult, genericResult)
    result = AnalysisResult();

    %% ============================================================
    % INPUT VALIDATION
    % =============================================================

    if nargin < 1 || isempty(circuit)

        result = result.addError( ...
            "Circuit input is required.");

        return;

    end

    if nargin < 2 || isempty(simResult)

        result = result.addError( ...
            "SimulationResult input is required.");

        return;

    end

    if nargin < 3 || isempty(genericResult)

        result = result.addError( ...
            "Generic AnalysisResult input is required.");

        return;

    end

    %% ============================================================
    % GET TOPOLOGY
    % =============================================================

    topology = "";

    try
        topology = string(circuit.Metadata.Topology);
    catch
    end

    if strlength(strtrim(topology)) == 0

        try
            topology = string(simResult.Topology);
        catch
            topology = "";
        end

    end

    topology = strtrim(topology);

    %% ============================================================
    % VALIDATE TOPOLOGY
    % =============================================================

    if topology == ""

        result.CircuitName = simResult.CircuitName;
        result.Topology = "Unknown";

        try
            result.AnalysisType = simResult.Analysis;
        catch
            result.AnalysisType = "Unknown";
        end

        result = result.addError( ...
            "Circuit topology is not defined.");

        result.Success = false;

        return;

    end

    %% ============================================================
    % DISPATCH
    % =============================================================

    try

        switch lower(topology)

            case "ce_amplifier"

                result = analyzeCEAmplifier( ...
                    circuit, ...
                    simResult, ...
                    genericResult);

            case "rc_lowpass"

                result = analyzeRCLowPass( ...
                    circuit, ...
                    simResult, ...
                    genericResult);
                
            case "common_source"
               result = analyzeCommonSource( ...
                   circuit, simResult, genericResult);


            case "opamp_noninverting"
                result = analyzeOpAmp( ...
                    circuit, simResult, genericResult);
   
                
            otherwise

                result.CircuitName = ...
                    simResult.CircuitName;

                result.Topology = ...
                    topology;

                try
                    result.AnalysisType = ...
                        string(simResult.Analysis);
                catch
                    result.AnalysisType = "Unknown";
                end

                result = result.addError( ...
                    "Unsupported topology: " + topology);

                result.Success = false;

        end

    catch ME

        result.CircuitName = ...
            simResult.CircuitName;

        result.Topology = ...
            topology;

        try
            result.AnalysisType = ...
                string(simResult.Analysis);
        catch
            result.AnalysisType = "Unknown";
        end

        result = result.addError( ...
            "Topology analysis failed: " + ...
            string(ME.message));

        result.Success = false;

    end

end
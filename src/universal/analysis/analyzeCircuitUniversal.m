
function output = analyzeCircuitUniversal(circuit, simResult, registry)
%ANALYZECIRCUITUNIVERSAL Integrated universal analysis pipeline.
%
% Runs:
%   1. Automatic measurement selection
%   2. Generic simulation analysis
%   3. Topology-specific analysis
%
% This function does not run SPICE.

    output = struct();
    output.Success = false;
    output.Selection = [];
    output.GenericResult = [];
    output.TopologyResult = [];
    output.Warnings = strings(0,1);
    output.Errors = strings(0,1);

    %% Validate inputs

    if nargin < 2 || isempty(circuit) || isempty(simResult)
        output.Errors = "Circuit and SimulationResult are required.";
        return;
    end

    if ~isa(simResult, "SimulationResult")
        output.Errors = "simResult must be a SimulationResult object.";
        return;
    end

    if nargin < 3 || isempty(registry)
        registry = MeasurementRegistry();
    end

    if ~simResult.Success
        output.Errors = "SPICE simulation was not successful.";
        return;
    end

    %% Step 1: Automatic measurement selection

    try
        output.Selection = selectMeasurements( ...
            circuit, simResult.Analysis, registry);
    catch ME
        output.Errors = "Measurement selection failed: " + string(ME.message);
        return;
    end

    if ~output.Selection.Success
        output.Errors = ...
            "Measurement selection reported unsupported dependencies.";
        output.Warnings = output.Selection.Warnings;
        return;
    end

    output.Warnings = output.Selection.Warnings;

    %% Step 2: Generic analysis

    output.GenericResult = analyzeSimulationUniversal(simResult);

    if ~output.GenericResult.Success
        output.Errors = "Generic simulation analysis failed.";

        if ~isempty(output.GenericResult.Errors)
            output.Errors = [
                output.Errors
                string(output.GenericResult.Errors(:))
            ];
        end

        return;
    end

    %% Step 3: Topology-specific analysis

    output.TopologyResult = analyzeTopology( ...
        circuit, simResult, output.GenericResult);

    if ~output.TopologyResult.Success
        output.Errors = "Topology-specific analysis failed.";

        if ~isempty(output.TopologyResult.Errors)
            output.Errors = [
                output.Errors
                string(output.TopologyResult.Errors(:))
            ];
        end

        return;
    end

    %% Complete

    output.Success = true;

end

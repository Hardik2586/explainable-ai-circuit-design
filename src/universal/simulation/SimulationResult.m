
classdef SimulationResult
    %SIMULATIONRESULT Universal container for SPICE simulation results.

    properties
        % Simulation identity
        Success logical = false
        CircuitName string = ""
        Topology string = "Unknown"
        Analysis string = ""

        % Execution information
        ExitCode double = NaN
        ErrorMessage string = ""
        WorkDir string = ""
        NetlistPath string = ""
        OutputPath string = ""

        % AC data. These legacy properties remain available.
        Frequency double = []
        Magnitude double = []
        Phase double = []

        % Per-signal AC data, indexed by valid MATLAB field names.
        % Each entry has Name, Frequency, Magnitude, and Phase fields.
        % Example: obj.ACSignals.IN.Magnitude
        ACSignals struct = struct()

        % DC data
        NodeNames string = strings(0,1)
        NodeVoltages double = []
        BranchNames string = strings(0,1)
        BranchCurrents double = []

        % Transient data
        Time double = []
        TransientSignals double = []

        % Raw information
        RawOutput string = ""
        RawData = []

        % Generic measurements
        Measurements struct = struct()
    end

    methods
        function obj = SimulationResult()
        end

        function tf = isSuccessful(obj)
            tf = logical(obj.Success) && ...
                strlength(string(obj.ErrorMessage)) == 0;
        end

        function displaySummary(obj)
            fprintf("\n");
            fprintf("============================================\n");
            fprintf(" Universal Simulation Result\n");
            fprintf("============================================\n");
            fprintf("Circuit   : %s\n", char(obj.CircuitName));
            fprintf("Topology  : %s\n", char(obj.Topology));
            fprintf("Analysis  : %s\n", char(obj.Analysis));
            fprintf("Success   : %d\n", obj.Success);
            fprintf("Exit Code : %g\n", obj.ExitCode);
            if strlength(string(obj.ErrorMessage)) > 0
                fprintf("Error     : %s\n", char(obj.ErrorMessage));
            end
            fprintf("============================================\n\n");
        end
    end
end

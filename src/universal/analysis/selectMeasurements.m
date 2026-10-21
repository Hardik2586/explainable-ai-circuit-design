
function selection = selectMeasurements(circuit, analysisType, registry)
%SELECTMEASUREMENTS Automatically select measurements for a circuit.
%
% Inputs:
%   circuit     - Universal Circuit object
%   analysisType - "AC", "DC", or "TRAN"
%   registry    - MeasurementRegistry object (optional)
%
% Output:
%   selection structure containing:
%       Topology
%       AnalysisType
%       TopologyMeasurements
%       GenericMeasurements
%       RawDataRequirements
%       UnsupportedMeasurements
%       Warnings
%       Success
%
% This function selects measurements only. It does not run SPICE.

    %% INITIALIZE

    if nargin < 2 || isempty(analysisType)
        error("selectMeasurements:MissingAnalysis", ...
            "An analysis type is required.");
    end

    if nargin < 3 || isempty(registry)
        registry = MeasurementRegistry();
    end

    analysisType = upper(string(analysisType));

    if ~ismember(analysisType, ["AC", "DC", "TRAN"])
        error("selectMeasurements:InvalidAnalysis", ...
            "Analysis must be AC, DC, or TRAN.");
    end

    if ~isprop(circuit, "Metadata") || ...
            ~isfield(circuit.Metadata, "Topology")
        error("selectMeasurements:MissingTopology", ...
            "Circuit topology metadata is missing.");
    end

    topology = string(circuit.Metadata.Topology);

    %% DEFAULT SELECTION

    topologyMeasurements = strings(0,1);
    genericMeasurements = strings(0,1);
    rawDataRequirements = strings(0,1);
    warnings = strings(0,1);

    %% TOPOLOGY AND ANALYSIS RULES

    switch topology

        % =========================================================
        % RC LOW-PASS FILTER
        % =========================================================

        case "RC_LowPass"

            switch analysisType

                case "AC"
                    topologyMeasurements = [
                        "PassbandMagnitude"
                        "MinimumMagnitude"
                        "CutoffFrequency"
                        "Upper3dBFrequency"
                        "Bandwidth"
                    ];

                    genericMeasurements = [
                        "MaxMagnitude"
                        "MinMagnitude"
                        "FUpper3dB"
                        "PeakFrequency"
                    ];

                    rawDataRequirements = [
                        "Frequency"
                        "Magnitude"
                    ];

                case "DC"
                    topologyMeasurements = [
                        "NodeVoltages"
                    ];

                    rawDataRequirements = [
                        "NodeNames"
                        "NodeVoltages"
                    ];

                case "TRAN"
                    topologyMeasurements = [
                        "PeakToPeak"
                        "RMS"
                        "SettlingBehavior"
                    ];

                    genericMeasurements = [
                        "StartTime"
                        "EndTime"
                        "Duration"
                        "PeakToPeak"
                        "RMS"
                    ];

                    rawDataRequirements = [
                        "Time"
                        "TransientSignals"
                    ];
            end

        % =========================================================
        % COMMON-EMITTER BJT AMPLIFIER
        % =========================================================

        case "CE_Amplifier"

            switch analysisType

                case "AC"
                    topologyMeasurements = [
                        "Gain_dB"
                        "fL"
                        "fH"
                        "Bandwidth"
                        "PeakFrequency"
                    ];

                    genericMeasurements = [
                        "MaxMagnitude"
                        "FLower3dB"
                        "FUpper3dB"
                        "Bandwidth3dB"
                        "PeakFrequency"
                        "PhaseAtPeak"
                    ];

                    rawDataRequirements = [
                        "Frequency"
                        "Magnitude"
                        "Phase"
                    ];

                case "DC"
                    topologyMeasurements = [
                        "VB"
                        "VE"
                        "VC"
                        "VCE"
                        "VCB"
                        "IC"
                        "OperatingRegion"
                    ];

                    genericMeasurements = [
                        "MinNodeVoltage"
                        "MaxNodeVoltage"
                        "NodeVoltageRange"
                        "MinBranchCurrent"
                        "MaxBranchCurrent"
                    ];

                    rawDataRequirements = [
                        "NodeNames"
                        "NodeVoltages"
                        "BranchNames"
                        "BranchCurrents"
                    ];

                case "TRAN"
                    topologyMeasurements = [
                        "OutputPeakToPeak"
                        "OutputRMS"
                    ];

                    genericMeasurements = [
                        "StartTime"
                        "EndTime"
                        "Duration"
                        "PeakToPeak"
                        "RMS"
                    ];

                    rawDataRequirements = [
                        "Time"
                        "TransientSignals"
                    ];
            end

        % =========================================================
        % COMMON-SOURCE MOSFET AMPLIFIER
        % =========================================================

        case "Common_Source"

            switch analysisType

                case "AC"
                    topologyMeasurements = [
                        "Gain_dB"
                        "fL"
                        "fH"
                        "Bandwidth"
                        "PeakFrequency"
                    ];

                    genericMeasurements = [
                        "MaxMagnitude"
                        "FLower3dB"
                        "FUpper3dB"
                        "Bandwidth3dB"
                        "PeakFrequency"
                    ];

                    rawDataRequirements = [
                        "Frequency"
                        "Magnitude"
                        "Phase"
                    ];

                case "DC"
                    topologyMeasurements = [
                        "VGS"
                        "VDS"
                        "ID"
                        "OperatingRegion"
                    ];

                    rawDataRequirements = [
                        "NodeNames"
                        "NodeVoltages"
                        "BranchNames"
                        "BranchCurrents"
                    ];

                case "TRAN"
                    topologyMeasurements = [
                        "OutputPeakToPeak"
                        "OutputRMS"
                    ];

                    genericMeasurements = [
                        "StartTime"
                        "EndTime"
                        "Duration"
                        "PeakToPeak"
                        "RMS"
                    ];

                    rawDataRequirements = [
                        "Time"
                        "TransientSignals"
                    ];
            end

        % =========================================================
        % NON-INVERTING OP-AMP
        % =========================================================

        case "OpAmp_NonInverting"

            switch analysisType

                case "AC"
                    topologyMeasurements = [
                        "ClosedLoopGain_dB"
                        "Bandwidth"
                        "PeakFrequency"
                    ];

                    genericMeasurements = [
                        "MaxMagnitude"
                        "FUpper3dB"
                        "PeakFrequency"
                    ];

                    rawDataRequirements = [
                        "Frequency"
                        "Magnitude"
                        "Phase"
                    ];

                case "DC"
                    topologyMeasurements = [
                        "InputVoltage"
                        "OutputVoltage"
                        "VoltageGain"
                    ];

                    rawDataRequirements = [
                        "NodeNames"
                        "NodeVoltages"
                    ];

                case "TRAN"
                    topologyMeasurements = [
                        "OutputPeakToPeak"
                        "OutputRMS"
                    ];

                    genericMeasurements = [
                        "StartTime"
                        "EndTime"
                        "Duration"
                        "PeakToPeak"
                        "RMS"
                    ];

                    rawDataRequirements = [
                        "Time"
                        "TransientSignals"
                    ];
            end

        % =========================================================
        % UNKNOWN OR UNREGISTERED TOPOLOGY
        % =========================================================

        otherwise
            warnings(end+1,1) = ...
                "No topology-specific measurement profile exists for " ...
                + topology + ".";

            switch analysisType
                case "AC"
                    genericMeasurements = [
                        "MaxMagnitude"
                        "MinMagnitude"
                        "PeakFrequency"
                        "PhaseAtPeak"
                    ];

                    rawDataRequirements = [
                        "Frequency"
                        "Magnitude"
                        "Phase"
                    ];

                case "DC"
                    genericMeasurements = [
                        "MinNodeVoltage"
                        "MaxNodeVoltage"
                        "NodeVoltageRange"
                        "MinBranchCurrent"
                        "MaxBranchCurrent"
                    ];

                    rawDataRequirements = [
                        "NodeNames"
                        "NodeVoltages"
                        "BranchNames"
                        "BranchCurrents"
                    ];

                case "TRAN"
                    genericMeasurements = [
                        "StartTime"
                        "EndTime"
                        "Duration"
                        "PeakToPeak"
                        "RMS"
                    ];

                    rawDataRequirements = [
                        "Time"
                        "TransientSignals"
                    ];
            end
    end

    %% CHECK GENERIC MEASUREMENTS AGAINST THE REGISTRY

    unsupportedMeasurements = strings(0,1);

    for k = 1:numel(genericMeasurements)

        measurementName = genericMeasurements(k);

        if ~registry.contains(measurementName)
            unsupportedMeasurements(end+1,1) = measurementName;
        end
    end

    if ~isempty(unsupportedMeasurements)
        warnings(end+1,1) = ...
            "Some requested generic measurements are not registered.";
    end

    %% BUILD RESULT

    selection = struct();

    selection.Topology = topology;
    selection.AnalysisType = analysisType;

    selection.TopologyMeasurements = topologyMeasurements;
    selection.GenericMeasurements = genericMeasurements;
    selection.RawDataRequirements = rawDataRequirements;

    selection.UnsupportedMeasurements = unsupportedMeasurements;
    selection.Warnings = warnings;

    % Success means selection completed, not that measurements
    % have already been calculated or physically validated.
    selection.Success = isempty(unsupportedMeasurements);

end


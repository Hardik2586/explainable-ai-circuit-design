function result = analyzeCEAmplifier(circuit, simResult, genericResult)
%ANALYZECEAMPLIFIER Topology-specific analysis for a CE amplifier.
%
% Uses already-computed generic simulation results.
% Does not run SPICE.

    %% ============================================================
    % INITIALIZE
    % =============================================================

    result = AnalysisResult();

    result.CircuitName = simResult.CircuitName;
    result.Topology = "CE_Amplifier";
    result.AnalysisType = string(simResult.Analysis);

    %% ============================================================
    % VALIDATE GENERIC RESULT
    % =============================================================

    if ~genericResult.Success

        result = result.addError( ...
            "Generic simulation analysis was not successful.");

        result.Success = false;
        return;

    end

    analysisType = upper(string(simResult.Analysis));

    %% ============================================================
    % AC ANALYSIS
    % =============================================================

    if analysisType == "AC"

        % ---------------------------------------------------------
        % Gain
        % ---------------------------------------------------------

        if genericResult.hasMeasurement("MaxMagnitude")

            gainDB = genericResult.getMeasurement("MaxMagnitude");

            % Ensure scalar
            gainDB = gainDB(1);

            result = result.setMeasurement( ...
                "Gain_dB", gainDB);

        end

        % ---------------------------------------------------------
        % Lower cutoff
        % ---------------------------------------------------------

        if genericResult.hasMeasurement("FLower3dB")

            fL = genericResult.getMeasurement("FLower3dB");

            fL = fL(1);

            result = result.setMeasurement( ...
                "fL", fL);

        end

        % ---------------------------------------------------------
        % Upper cutoff
        % ---------------------------------------------------------

        if genericResult.hasMeasurement("FUpper3dB")

            fH = genericResult.getMeasurement("FUpper3dB");

            fH = fH(1);

            result = result.setMeasurement( ...
                "fH", fH);

        end

        % ---------------------------------------------------------
        % Bandwidth
        % ---------------------------------------------------------

        if genericResult.hasMeasurement("Bandwidth3dB")

            bandwidth = ...
                genericResult.getMeasurement("Bandwidth3dB");

            bandwidth = bandwidth(1);

            result = result.setMeasurement( ...
                "Bandwidth", bandwidth);

        end

        % ---------------------------------------------------------
        % Peak frequency
        % ---------------------------------------------------------

        if genericResult.hasMeasurement("PeakFrequency")

            peakFrequency = ...
                genericResult.getMeasurement("PeakFrequency");

            peakFrequency = peakFrequency(1);

            result = result.setMeasurement( ...
                "PeakFrequency", peakFrequency);

        end

        % ---------------------------------------------------------
        % Upper cutoff warning
        % ---------------------------------------------------------

        if ~genericResult.hasMeasurement("FUpper3dB")

            result = result.addWarning( ...
                "Upper cutoff frequency could not be determined from the available AC range.");

        end

        % ---------------------------------------------------------
        % Success
        % ---------------------------------------------------------

        if result.hasMeasurement("Gain_dB")

            result.Success = true;

        else

            result = result.addError( ...
                "CE AC analysis could not determine gain.");

            result.Success = false;

        end

        return;

    end

    %% ============================================================
    % DC ANALYSIS
    % =============================================================

    if analysisType == "DC"

        %% --------------------------------------------------------
        % Extract node data
        % ---------------------------------------------------------

        nodeNames = string(simResult.NodeNames(:));
        nodeVoltages = double(simResult.NodeVoltages(:));

        %% --------------------------------------------------------
        % Find CE node voltages
        % ---------------------------------------------------------

        VB = getNodeVoltage( ...
            nodeNames, nodeVoltages, "BASE");

        VE = getNodeVoltage( ...
            nodeNames, nodeVoltages, "EMITTER");

        VC = getNodeVoltage( ...
            nodeNames, nodeVoltages, "COLLECTOR");

        VCC = getNodeVoltage( ...
            nodeNames, nodeVoltages, "VCC");

        %% --------------------------------------------------------
        % Store node voltages
        % ---------------------------------------------------------

        if ~isnan(VB)
            result = result.setMeasurement("VB", VB);
        end

        if ~isnan(VE)
            result = result.setMeasurement("VE", VE);
        end

        if ~isnan(VC)
            result = result.setMeasurement("VC", VC);
        end

        if ~isnan(VCC)
            result = result.setMeasurement("VCC", VCC);
        end

        %% --------------------------------------------------------
        % VCE
        % ---------------------------------------------------------

        if isfinite(VB) && isfinite(VC) && isfinite(VE)

            VCE = VC - VE;

            result = result.setMeasurement( ...
                "VCE", VCE);

        else

            VCE = NaN;

        end

        %% --------------------------------------------------------
        % VCB
        % ---------------------------------------------------------

        if isfinite(VB) && isfinite(VC)

            VCB = VC - VB;

            result = result.setMeasurement( ...
                "VCB", VCB);

        else

            VCB = NaN;

        end

        %% --------------------------------------------------------
        % Collector current
        % ---------------------------------------------------------

        IC = getCollectorCurrent(simResult);

        if isfinite(IC)

            result = result.setMeasurement( ...
                "IC", IC);

        end

        %% --------------------------------------------------------
        % Operating region
        % ---------------------------------------------------------

        if isfinite(VB) && ...
                isfinite(VC) && ...
                isfinite(VE)

            region = classifyCERegion( ...
                VB, VC, VE, VCC);

            result = result.setMeasurement( ...
                "OperatingRegion", region);

        end

        %% --------------------------------------------------------
        % Success
        % ---------------------------------------------------------

        hasBiasData = ...
            result.hasMeasurement("VB") || ...
            result.hasMeasurement("VC") || ...
            result.hasMeasurement("VE");

        if hasBiasData

            result.Success = true;

        else

            result = result.addError( ...
                "CE DC analysis could not identify transistor bias nodes.");

            result.Success = false;

        end

        return;

    end

    %% ============================================================
    % TRAN ANALYSIS
    % =============================================================

    if analysisType == "TRAN"

        genericMeasurements = genericResult.Measurements;

        fields = fieldnames(genericMeasurements);

        for k = 1:numel(fields)

            fieldName = fields{k};

            result = result.setMeasurement( ...
                fieldName, ...
                genericMeasurements.(fieldName));

        end

        result = result.addWarning( ...
            "CE-specific transient interpretation is not yet enabled.");

        result.Success = genericResult.Success;

        return;

    end

    %% ============================================================
    % UNKNOWN ANALYSIS
    % =============================================================

    result = result.addError( ...
        "Unsupported analysis type for CE amplifier: " + ...
        analysisType);

    result.Success = false;

end


%% =================================================================
% NODE VOLTAGE HELPER
% =================================================================

function voltage = getNodeVoltage(nodeNames, nodeVoltages, target)

    voltage = NaN;

    nodeNames = string(nodeNames(:));
    nodeVoltages = double(nodeVoltages(:));

    target = upper(strtrim(string(target)));

    count = min(numel(nodeNames), numel(nodeVoltages));

    for k = 1:count

        currentName = ...
            upper(strtrim(nodeNames(k)));

        if currentName == target

            voltage = nodeVoltages(k);

            % Explicitly return scalar
            voltage = voltage(1);

            return;

        end

    end

end


%% =================================================================
% COLLECTOR CURRENT HELPER
% =================================================================

function current = getCollectorCurrent(simResult)

    current = NaN;

    if isempty(simResult.BranchNames) || ...
            isempty(simResult.BranchCurrents)

        return;

    end

    branchNames = ...
        lower(string(simResult.BranchNames(:)));

    branchCurrents = ...
        double(simResult.BranchCurrents(:));

    count = min(numel(branchNames), ...
                numel(branchCurrents));

    for k = 1:count

        name = branchNames(k);

        if contains(name, "collector") || ...
                contains(name, "ic")

            current = branchCurrents(k);
            current = current(1);

            return;

        end

    end

    % Do not interpret vcc#branch as IC.
    current = NaN;

end


%% =================================================================
% CE OPERATING REGION
% =================================================================

function region = classifyCERegion(VB, VC, VE, VCC)

    VBE = VB - VE;
    VCE = VC - VE;
    VCB = VC - VB;

    %% Cutoff

    if VBE < 0.55

        region = "Cutoff";
        return;

    end

    %% Saturation

    if VCE <= 0.20 || VCB <= 0

        region = "Saturation";
        return;

    end

    %% Near cutoff

    if isfinite(VCC)

        if VCE >= 0.90 * VCC

            region = "NearCutoff";
            return;

        end

    end

    %% Forward active

    region = "ForwardActive";

end
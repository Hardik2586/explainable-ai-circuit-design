
function result = analyzeAC(simResult, signalName)


    result = AnalysisResult();

    % ------------------------------------------------------------
    % Basic simulation validation
    % ------------------------------------------------------------

    if nargin < 1 || isempty(simResult)
        result = result.addError( ...
            "SimulationResult is empty.");
        return;
    end

    if ~isa(simResult, "SimulationResult")
        result = result.addError( ...
            "Input must be a SimulationResult object.");
        return;
    end

    result.CircuitName = simResult.CircuitName;
    result.Topology = simResult.Topology;
    result.AnalysisType = "AC";

    if ~simResult.Success
        result = result.addError( ...
            "SimulationResult indicates unsuccessful simulation.");
        return;
    end
    
% ------------------------------------------------------------
% Signal selection: explicit override or topology default
% ------------------------------------------------------------

if nargin < 2
    signalName = "";
end

frequency = simResult.Frequency;
magnitude = simResult.Magnitude;
phase = simResult.Phase;

selectedSignal = "Legacy";

if isprop(simResult, "ACSignals") && ...
        ~isempty(simResult.ACSignals)

    signals = simResult.ACSignals;
    availableNames = string(fieldnames(signals));

    % Explicit selection takes priority.
    if strlength(strtrim(string(signalName))) > 0
        candidates = string(signalName);
    else
        % Automatic topology-specific selection.
        topology = string(simResult.Topology);

        switch topology
            case "Common_Source"
                candidates = ["drain", "out", "output"];

            case "CE_Amplifier"
                candidates = ["out", "output", "collector"];

            case "RC_LowPass"
                candidates = ["out", "output"];

            case "OpAmp_NonInverting"
                candidates = ["out", "output"];

            otherwise
                candidates = ["out", "output", ...
                              "drain", "collector"];
        end
    end

    chosen = "";

    for k = 1:numel(candidates)
        idx = find(strcmpi(availableNames, candidates(k)), 1);

        if ~isempty(idx)
            chosen = availableNames(idx);
            break;
        end
    end

    if strlength(chosen) > 0
        signal = signals.(char(chosen));

        if isfield(signal, "Frequency") && ...
                isfield(signal, "Magnitude")

            candidateFrequency = signal.Frequency;
            candidateMagnitude = signal.Magnitude;
            candidatePhase = [];

            if isfield(signal, "Phase")
                candidatePhase = signal.Phase;
            end

            if ~isempty(candidateFrequency) && ...
                    ~isempty(candidateMagnitude) && ...
                    numel(candidateFrequency) == ...
                    numel(candidateMagnitude)

                frequency = candidateFrequency;
                magnitude = candidateMagnitude;
                phase = candidatePhase;
                selectedSignal = chosen;
            else
                result = result.addWarning( ...
                    "Selected signal has invalid AC vectors.");
            end
        end
    elseif strlength(strtrim(string(signalName))) > 0
        result = result.addWarning( ...
            "Requested signal was not found; legacy data is used.");
    end
end

result = result.setMeasurement( ...
    "SelectedSignal", selectedSignal);


    % ------------------------------------------------------------
    % Validate AC vectors
    % ------------------------------------------------------------

    if isempty(frequency)
        result = result.addError( ...
            "AC frequency data is empty.");
        return;
    end

    if isempty(magnitude)
        result = result.addError( ...
            "AC magnitude data is empty.");
        return;
    end

    if numel(frequency) ~= numel(magnitude)
        result = result.addError( ...
            "Frequency and magnitude vectors have different lengths.");
        return;
    end

    if ~isempty(phase) && ...
            numel(phase) ~= numel(frequency)

        result = result.addError( ...
            "Frequency and phase vectors have different lengths.");
        return;
    end

    % Convert to column vectors.
    frequency = frequency(:);
    magnitude = magnitude(:);

    if ~isempty(phase)
        phase = phase(:);
    end

    % ------------------------------------------------------------
    % Remove invalid points
    % ------------------------------------------------------------

    valid = isfinite(frequency) & ...
            isfinite(magnitude) & ...
            frequency > 0 & magnitude >= 0;

    if ~isempty(phase)
        valid = valid & isfinite(phase);
    end

    if ~any(valid)
        result = result.addError( ...
            "No finite, valid AC data points are available.");
        return;
    end

    if nnz(~valid) > 0
        result = result.addWarning( ...
            sprintf("%d invalid AC data points were ignored.", ...
            nnz(~valid)));
    end

    frequency = frequency(valid);
    magnitude = magnitude(valid);

    if ~isempty(phase)
        phase = phase(valid);
    end

    % ------------------------------------------------------------
    % Sort by frequency
    % ------------------------------------------------------------

    [frequency, order] = sort(frequency);
    magnitude = magnitude(order);

    if ~isempty(phase)
        phase = phase(order);
    end

    % ------------------------------------------------------------
    % Basic measurements
    % ------------------------------------------------------------

    pointCount = numel(frequency);

    [maxMagnitude, peakIndex] = max(magnitude);
    minMagnitude = min(magnitude);
    peakFrequency = frequency(peakIndex);

    if ~isempty(phase)
        phaseAtPeak = phase(peakIndex);
    else
        phaseAtPeak = NaN;

        result = result.addWarning( ...
            "Phase data is unavailable.");
    end

    result = result.setMeasurement( ...
        "PointCount", pointCount);

    result = result.setMeasurement( ...
        "StartFrequency", frequency(1));

    result = result.setMeasurement( ...
        "StopFrequency", frequency(end));

    result = result.setMeasurement( ...
        "MaxMagnitude", maxMagnitude);

    result = result.setMeasurement( ...
        "MinMagnitude", minMagnitude);

    result = result.setMeasurement( ...
        "PeakFrequency", peakFrequency);

    result = result.setMeasurement( ...
        "PhaseAtPeak", phaseAtPeak);

    % Store vectors for plotting and downstream analysis.
    result = result.setMeasurement( ...
        "Frequency", frequency);

    result = result.setMeasurement( ...
        "Magnitude", magnitude);

    if ~isempty(phase)
        result = result.setMeasurement( ...
            "Phase", phase);
    end

    % ------------------------------------------------------------
    % -3 dB analysis relative to the peak magnitude
    % ------------------------------------------------------------

    magnitude3dB = maxMagnitude / sqrt(2);

    result = result.setMeasurement( ...
        "Magnitude3dB", magnitude3dB);

    % Find the last point below the threshold before the peak.
    lowerIndex = find( ...
        magnitude(1:peakIndex) < magnitude3dB, ...
        1, "last");

    % Find the first point below the threshold after the peak.
    upperRelative = find( ...
        magnitude(peakIndex:end) < magnitude3dB, ...
        1, "first");

    % Lower -3 dB crossing.
    if isempty(lowerIndex)
        fLower3dB = NaN;
        result = result.addWarning( ...
            "Lower -3 dB crossing could not be determined.");
    else
        if lowerIndex < peakIndex
            fLower3dB = interpolateCrossing( ...
                frequency(lowerIndex), ...
                magnitude(lowerIndex), ...
                frequency(lowerIndex + 1), ...
                magnitude(lowerIndex + 1), ...
                magnitude3dB);
        else
            fLower3dB = frequency(lowerIndex);
        end
    end

    % Upper -3 dB crossing.
    if isempty(upperRelative)
        fUpper3dB = NaN;
        result = result.addWarning( ...
            "Upper -3 dB crossing could not be determined.");
    else
        upperIndex = peakIndex + upperRelative - 1;

        if upperIndex > peakIndex
            fUpper3dB = interpolateCrossing( ...
                frequency(upperIndex - 1), ...
                magnitude(upperIndex - 1), ...
                frequency(upperIndex), ...
                magnitude(upperIndex), ...
                magnitude3dB);
        else
            fUpper3dB = frequency(upperIndex);
        end
    end

    % ------------------------------------------------------------
    % Bandwidth
    % ------------------------------------------------------------

    if isfinite(fLower3dB) && isfinite(fUpper3dB)
        bandwidth3dB = fUpper3dB - fLower3dB;

        if bandwidth3dB < 0
            bandwidth3dB = NaN;

            result = result.addWarning( ...
                "Computed -3 dB bandwidth is invalid.");
        end
    else
        bandwidth3dB = NaN;

        result = result.addWarning( ...
            "3-dB bandwidth could not be determined.");
    end

    result = result.setMeasurement( ...
        "FLower3dB", fLower3dB);

    result = result.setMeasurement( ...
        "FUpper3dB", fUpper3dB);

    result = result.setMeasurement( ...
        "Bandwidth3dB", bandwidth3dB);

    % ------------------------------------------------------------
    % Final status
    % ------------------------------------------------------------

    result.Success = true;

end


% ================================================================
% Helper: interpolate a threshold crossing
% ================================================================

function crossingFrequency = interpolateCrossing( ...
    f1, m1, f2, m2, targetMagnitude)

    if m2 == m1
        crossingFrequency = (f1 + f2) / 2;
    else
        alpha = (targetMagnitude - m1) / (m2 - m1);

        crossingFrequency = f1 + alpha * (f2 - f1);
    end

end

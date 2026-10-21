function analysis = analyzeSimulation(simResult)
%ANALYZESIMULATION Universal simulation analysis engine.
%
%   analysis = analyzeSimulation(simResult)
%
% Performs topology-independent analysis of a SimulationResult.
%
% Supported:
%   AC
%   DC
%   TRAN
%
% This function intentionally does NOT perform topology-specific
% analysis such as transistor operating-region classification,
% amplifier gain extraction, etc.
%
% Those belong to topology-specific analyzers.

    %% ============================================================
    % INPUT VALIDATION
    % =============================================================

    if ~isa(simResult,"SimulationResult")

        error( ...
            "analyzeSimulation:InvalidInput", ...
            "Input must be a SimulationResult object.");

    end


    %% ============================================================
    % INITIALIZE
    % =============================================================

    analysis = struct();

    analysis.Success = false;

    analysis.Status = "Unknown";

    analysis.AnalysisType = ...
        upper(string(simResult.Analysis));

    analysis.CircuitName = ...
        simResult.CircuitName;

    analysis.Topology = ...
        simResult.Topology;


    %% ============================================================
    % SIMULATION FAILURE
    % =============================================================

    if ~simResult.Success

        analysis.Status = "SimulationFailed";

        analysis.ErrorMessage = ...
            simResult.ErrorMessage;

        return;

    end


    analysis.Success = true;


    %% ============================================================
    % ANALYSIS DISPATCH
    % =============================================================

    switch upper(string(simResult.Analysis))

        case "AC"

            analysis = analyzeAC( ...
                simResult, ...
                analysis);


        case "DC"

            analysis = analyzeDC( ...
                simResult, ...
                analysis);


        case "TRAN"

            analysis = analyzeTransient( ...
                simResult, ...
                analysis);


        otherwise

            analysis.Status = ...
                "UnsupportedAnalysis";

            analysis.Success = false;

            analysis.ErrorMessage = ...
                "Unsupported simulation analysis type: " + ...
                string(simResult.Analysis);

            return;

    end

end


%% ========================================================================
% AC ANALYSIS
% ========================================================================

function analysis = analyzeAC(simResult,analysis)

    frequency = simResult.Frequency(:);
    magnitude = simResult.Magnitude(:);
    phase = simResult.Phase(:);


    %% ------------------------------------------------------------
    % Validate
    % ------------------------------------------------------------

    if isempty(frequency) || isempty(magnitude)

        analysis.Status = "NoACData";
        analysis.Success = false;

        analysis.ErrorMessage = ...
            "No valid AC frequency/magnitude data available.";

        return;

    end


    n = min( ...
        numel(frequency), ...
        numel(magnitude));


    frequency = frequency(1:n);
    magnitude = magnitude(1:n);


    valid = isfinite(frequency) & ...
            isfinite(magnitude);


    frequency = frequency(valid);
    magnitude = magnitude(valid);


    if isempty(frequency)

        analysis.Status = "NoValidACData";
        analysis.Success = false;

        analysis.ErrorMessage = ...
            "AC data contains no finite samples.";

        return;

    end


    %% ------------------------------------------------------------
    % Basic measurements
    % ------------------------------------------------------------

    [maxMagnitude,peakIndex] = ...
        max(magnitude);

    minMagnitude = ...
        min(magnitude);


    analysis.Status = "Valid";

    analysis.PointCount = ...
        numel(frequency);

    analysis.StartFrequency = ...
        min(frequency);

    analysis.StopFrequency = ...
        max(frequency);

    analysis.MaxMagnitude = ...
        maxMagnitude;

    analysis.MinMagnitude = ...
        minMagnitude;

    analysis.PeakFrequency = ...
        frequency(peakIndex);


    %% ------------------------------------------------------------
    % Phase
    % ------------------------------------------------------------

    if ~isempty(phase)

        phase = phase(:);

        if numel(phase) >= n

            phase = phase(1:n);

            phase = phase(valid);

            if numel(phase) >= peakIndex

                analysis.PhaseAtPeak = ...
                    phase(peakIndex);

            else

                analysis.PhaseAtPeak = NaN;

            end

        else

            analysis.PhaseAtPeak = NaN;

        end

    else

        analysis.PhaseAtPeak = NaN;

    end


    %% ------------------------------------------------------------
    % -3 dB bandwidth
    %
    % Reference = maximum magnitude.
    %
    % This is a generic magnitude-response definition.
    %
    % It does NOT assume that the circuit is an amplifier.
    % ------------------------------------------------------------

    threshold = ...
        maxMagnitude - 3.01029995664;


    analysis.Magnitude3dB = ...
        threshold;


    below = magnitude <= threshold;


    % -------------------------------------------------------------
    % Lower crossing
    % -------------------------------------------------------------

    lowerCrossing = ...
        find(below(1:peakIndex),1,"last");


    if isempty(lowerCrossing)

        analysis.FLower3dB = NaN;

    else

        if lowerCrossing < peakIndex

            f1 = frequency(lowerCrossing);
            f2 = frequency(lowerCrossing + 1);

            m1 = magnitude(lowerCrossing);
            m2 = magnitude(lowerCrossing + 1);

            analysis.FLower3dB = ...
                interpolateCrossing( ...
                    f1,f2,m1,m2,threshold);

        else

            analysis.FLower3dB = ...
                frequency(lowerCrossing);

        end

    end


    % -------------------------------------------------------------
    % Upper crossing
    % -------------------------------------------------------------

    upperRelative = ...
        find(below(peakIndex:end),1,"first");


    if isempty(upperRelative)

        analysis.FUpper3dB = NaN;

    else

        upperCrossing = ...
            peakIndex + upperRelative - 1;


        if upperCrossing > peakIndex

            f1 = frequency(upperCrossing - 1);
            f2 = frequency(upperCrossing);

            m1 = magnitude(upperCrossing - 1);
            m2 = magnitude(upperCrossing);

            analysis.FUpper3dB = ...
                interpolateCrossing( ...
                    f1,f2,m1,m2,threshold);

        else

            analysis.FUpper3dB = ...
                frequency(upperCrossing);

        end

    end


    % -------------------------------------------------------------
    % Bandwidth
    % -------------------------------------------------------------

    if isfinite(analysis.FLower3dB) && ...
            isfinite(analysis.FUpper3dB)

        analysis.Bandwidth3dB = ...
            analysis.FUpper3dB - ...
            analysis.FLower3dB;

    else

        analysis.Bandwidth3dB = NaN;

    end


    %% ------------------------------------------------------------
    % Store response vectors
    % ------------------------------------------------------------

    analysis.Frequency = ...
        frequency;

    analysis.Magnitude = ...
        magnitude;

    analysis.Phase = ...
        phase;

end


%% ========================================================================
% DC ANALYSIS
% ========================================================================

function analysis = analyzeDC(simResult,analysis)

    voltages = simResult.NodeVoltages(:);


    if isempty(voltages)

        analysis.Status = "NoDCData";
        analysis.Success = false;

        analysis.ErrorMessage = ...
            "No DC node-voltage data available.";

        return;

    end


    valid = ...
        isfinite(voltages);


    voltages = ...
        voltages(valid);


    if isempty(voltages)

        analysis.Status = "NoValidDCData";
        analysis.Success = false;

        analysis.ErrorMessage = ...
            "DC data contains no finite node voltages.";

        return;

    end


    analysis.Status = "Valid";

    analysis.NodeCount = ...
        numel(voltages);

    analysis.MinNodeVoltage = ...
        min(voltages);

    analysis.MaxNodeVoltage = ...
        max(voltages);

    analysis.NodeVoltageRange = ...
        analysis.MaxNodeVoltage - ...
        analysis.MinNodeVoltage;


    %% ------------------------------------------------------------
    % Branch currents
    % ------------------------------------------------------------

    currents = ...
        simResult.BranchCurrents(:);


    if ~isempty(currents)

        currents = ...
            currents(isfinite(currents));

    end


    analysis.BranchCurrentCount = ...
        numel(currents);


    if isempty(currents)

        analysis.MinBranchCurrent = NaN;
        analysis.MaxBranchCurrent = NaN;

    else

        analysis.MinBranchCurrent = ...
            min(currents);

        analysis.MaxBranchCurrent = ...
            max(currents);

    end

end


%% ========================================================================
% TRANSIENT ANALYSIS
% ========================================================================

function analysis = analyzeTransient(simResult,analysis)

    time = simResult.Time(:);

    signals = simResult.TransientSignals;


    if isempty(time)

        analysis.Status = "NoTransientData";
        analysis.Success = false;

        analysis.ErrorMessage = ...
            "No transient time data available.";

        return;

    end


    time = ...
        time(isfinite(time));


    if isempty(time)

        analysis.Status = "NoValidTransientData";
        analysis.Success = false;

        analysis.ErrorMessage = ...
            "Transient time vector contains no finite values.";

        return;

    end


    analysis.Status = "Valid";

    analysis.PointCount = ...
        numel(time);

    analysis.StartTime = ...
        min(time);

    analysis.EndTime = ...
        max(time);

    analysis.Duration = ...
        analysis.EndTime - ...
        analysis.StartTime;


    %% ------------------------------------------------------------
    % Signal statistics
    % ------------------------------------------------------------

    if isempty(signals)

        analysis.MinSignal = NaN;
        analysis.MaxSignal = NaN;
        analysis.PeakToPeak = NaN;
        analysis.RMS = NaN;

        return;

    end


    values = ...
        signals(isfinite(signals));


    if isempty(values)

        analysis.MinSignal = NaN;
        analysis.MaxSignal = NaN;
        analysis.PeakToPeak = NaN;
        analysis.RMS = NaN;

        return;

    end


    analysis.MinSignal = ...
        min(values);

    analysis.MaxSignal = ...
        max(values);

    analysis.PeakToPeak = ...
        analysis.MaxSignal - ...
        analysis.MinSignal;

    analysis.RMS = ...
        sqrt(mean(values.^2));

end


%% ========================================================================
% LINEAR INTERPOLATION
% ========================================================================

function crossing = interpolateCrossing( ...
    f1,f2,m1,m2,target)

    if m2 == m1

        crossing = ...
            mean([f1 f2]);

        return;

    end


    alpha = ...
        (target - m1) / ...
        (m2 - m1);


    alpha = ...
        max(0,min(1,alpha));


    crossing = ...
        f1 + alpha * (f2 - f1);

end
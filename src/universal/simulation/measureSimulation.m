function measurements = measureSimulation(simResult)


    if ~isa(simResult,"SimulationResult")

        error( ...
            "measureSimulation:InvalidInput", ...
            "Input must be a SimulationResult object.");

    end


    measurements = struct();


    % ============================================================
    % FAILURE
    % ============================================================

    if ~simResult.Success

        measurements.Status = "SimulationFailed";

        return;

    end


    if strlength(string(simResult.ErrorMessage)) > 0

        measurements.Status = "ParseError";
        measurements.ErrorMessage = simResult.ErrorMessage;

        return;

    end


    measurements.Status = "Valid";


    % ============================================================
    % AC
    % ============================================================

    if strcmpi(simResult.Analysis,"AC")

        frequency = simResult.Frequency(:);
        magnitude = simResult.Magnitude(:);
        phase = simResult.Phase(:);


        if isempty(frequency)

            measurements.Status = "NoACData";

            measurements.MaxMagnitude = NaN;
            measurements.MinMagnitude = NaN;
            measurements.PeakFrequency = NaN;
            measurements.PhaseAtPeak = NaN;

            return;

        end


        % --------------------------------------------------------
        % Only use finite magnitude samples.
        % --------------------------------------------------------

        validMagnitude = isfinite(magnitude);


        if any(validMagnitude)

            validIndices = find(validMagnitude);

            validMagnitudeValues = magnitude(validMagnitude);


            [maxMagnitude,localIndex] = ...
                max(validMagnitudeValues);

            minMagnitude = ...
                min(validMagnitudeValues);


            peakIndex = ...
                validIndices(localIndex);


            measurements.MaxMagnitude = ...
                maxMagnitude;

            measurements.MinMagnitude = ...
                minMagnitude;


            if peakIndex <= numel(frequency)

                measurements.PeakFrequency = ...
                    frequency(peakIndex);

            else

                measurements.PeakFrequency = NaN;

            end


            if peakIndex <= numel(phase) && ...
                    isfinite(phase(peakIndex))

                measurements.PhaseAtPeak = ...
                    phase(peakIndex);

            else

                measurements.PhaseAtPeak = NaN;

            end

        else

            measurements.MaxMagnitude = NaN;
            measurements.MinMagnitude = NaN;
            measurements.PeakFrequency = NaN;
            measurements.PhaseAtPeak = NaN;

        end


        % --------------------------------------------------------
        % Additional generic AC information
        % --------------------------------------------------------

        measurements.PointCount = ...
            numel(frequency);

        measurements.StartFrequency = ...
            min(frequency);

        measurements.StopFrequency = ...
            max(frequency);

    end


    % ============================================================
    % DC
    % ============================================================

    if strcmpi(simResult.Analysis,"DC")

        voltages = simResult.NodeVoltages(:);

        measurements.NodeCount = ...
            numel(voltages);


        validVoltages = ...
            voltages(isfinite(voltages));


        if ~isempty(validVoltages)

            measurements.MinNodeVoltage = ...
                min(validVoltages);

            measurements.MaxNodeVoltage = ...
                max(validVoltages);

        else

            measurements.MinNodeVoltage = NaN;
            measurements.MaxNodeVoltage = NaN;

        end

    end


    % ============================================================
    % TRANSIENT
    % ============================================================

    if strcmpi(simResult.Analysis,"TRAN") || ...
            strcmpi(simResult.Analysis,"TRANSIENT")

        time = simResult.Time(:);

        if ~isempty(time)

            validTime = ...
                time(isfinite(time));

            if ~isempty(validTime)

                measurements.StartTime = ...
                    min(validTime);

                measurements.EndTime = ...
                    max(validTime);

                measurements.Duration = ...
                    max(validTime) - min(validTime);

            else

                measurements.StartTime = NaN;
                measurements.EndTime = NaN;
                measurements.Duration = NaN;

            end

        else

            measurements.StartTime = NaN;
            measurements.EndTime = NaN;
            measurements.Duration = NaN;

        end


        signals = simResult.TransientSignals(:);

        validSignals = ...
            signals(isfinite(signals));


        if ~isempty(validSignals)

            measurements.MinSignal = ...
                min(validSignals);

            measurements.MaxSignal = ...
                max(validSignals);

        else

            measurements.MinSignal = NaN;
            measurements.MaxSignal = NaN;

        end

    end

end
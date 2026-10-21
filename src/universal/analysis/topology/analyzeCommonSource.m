
function result = analyzeCommonSource(circuit, simResult, genericResult)
%ANALYZECOMMONSOURCE Analyze a common-source MOSFET amplifier.
% AC gain is calculated from output/input magnitudes.
% Parsed SPICE phase values are assumed to be in radians.

    result = AnalysisResult();
    result.CircuitName = string(circuit.Name);
    result.Topology = "Common_Source";
    result.AnalysisType = upper(string(simResult.Analysis));
    result.Success = false;

    if result.AnalysisType ~= "AC"
        result = result.addError( ...
            "Common-source analysis currently supports AC only.");
        return;
    end

    if ~simResult.Success
        result = result.addError( ...
            "SPICE simulation was unsuccessful.");
        return;
    end

    if isempty(genericResult) || ~genericResult.Success
        result = result.addError( ...
            "Generic AC analysis is unsuccessful.");
        return;
    end

    try
        signals = simResult.ACSignals;

        if ~isfield(signals, "in") || ~isfield(signals, "drain")
            result = result.addError( ...
                "Required AC signals 'in' and 'drain' were not found.");
            return;
        end

        inputSignal = signals.in;
        outputSignal = signals.drain;

        % Calculate voltage gain using the shared utility.
        gainResult = calculateVoltageGain(inputSignal, outputSignal);

        if ~gainResult.Success
            result = result.addError( ...
                "Voltage gain calculation failed: " + ...
                strjoin(string(gainResult.Errors(:)), "; "));
            return;
        end

        % Store gain curve and peak measurements.
        frequency = gainResult.Frequency(:);
        gainVV = gainResult.Gain_VV(:);
        gainDB = gainResult.Gain_dB(:);

        result = result.setMeasurement( ...
            "Frequency", frequency);
        result = result.setMeasurement( ...
            "VoltageGain", gainVV);
        result = result.setMeasurement( ...
            "VoltageGain_dB", gainDB);

        result = result.setMeasurement( ...
            "PeakVoltageGain", gainResult.PeakGain_VV);
        result = result.setMeasurement( ...
            "PeakGain_dB", gainResult.PeakGain_dB);
        result = result.setMeasurement( ...
            "PeakGainFrequency", gainResult.PeakGainFrequency);

        % Peak output magnitude, evaluated on the same frequency grid.
        outputMagnitude = outputSignal.Magnitude(:);

        if numel(outputMagnitude) ~= numel(frequency)
            result = result.addError( ...
                "Output magnitude and gain frequency vectors differ in length.");
            return;
        end

        validOutput = isfinite(outputMagnitude) & ...
                      isfinite(frequency) & frequency > 0;

        if any(validOutput)
            outputIndices = find(validOutput);
            [peakOutput, localIndex] = max( ...
                outputMagnitude(validOutput));
            peakIndex = outputIndices(localIndex);

            result = result.setMeasurement( ...
                "PeakOutputMagnitude", peakOutput);
            result = result.setMeasurement( ...
                "PeakOutputFrequency", frequency(peakIndex));
        end

        % Gain at the first valid frequency.
        firstValid = find(isfinite(gainVV) & isfinite(gainDB), 1);

        if ~isempty(firstValid)
            result = result.setMeasurement( ...
                "GainAtStart_VV", gainVV(firstValid));
            result = result.setMeasurement( ...
                "GainAtStart_dB", gainDB(firstValid));
        end

        % Phase difference: output phase minus input phase.
        if isfield(inputSignal, "Phase") && ...
                isfield(outputSignal, "Phase")

            inputPhase = inputSignal.Phase(:);
            outputPhase = outputSignal.Phase(:);

            if numel(inputPhase) == numel(frequency) && ...
                    numel(outputPhase) == numel(frequency)

                phaseValid = isfinite(inputPhase) & ...
                             isfinite(outputPhase) & ...
                             isfinite(frequency) & frequency > 0;

                if any(phaseValid)
                    phaseDifferenceRad = angle(exp(1i .* ...
                        (outputPhase(phaseValid) - ...
                         inputPhase(phaseValid))));

                    phaseDifferenceDeg = rad2deg(phaseDifferenceRad);
                    phaseFrequencies = frequency(phaseValid);

                    result = result.setMeasurement( ...
                        "PhaseDifference_deg", phaseDifferenceDeg);

                    [~, nearestIndex] = min(abs( ...
                        phaseFrequencies - gainResult.PeakGainFrequency));

                    result = result.setMeasurement( ...
                        "PhaseDifferenceAtPeakGain_deg", ...
                        phaseDifferenceDeg(nearestIndex));
                end
            end
        end

        result.Success = true;

    catch ME
        result = result.addError( ...
            "Common-source AC analysis failed: " + string(ME.message));
    end
end

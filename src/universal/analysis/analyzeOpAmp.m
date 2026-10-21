
function result = analyzeOpAmp(circuit, simResult, genericResult)
%ANALYZEOPAMP Analyze an idealized non-inverting op-amp.
% Requires AC signals named "in" and "out".
% Theoretical gain is calculated from RF and RG.

    result = AnalysisResult();
    result.CircuitName = string(circuit.Name);
    result.Topology = "OpAmp_NonInverting";
    result.AnalysisType = upper(string(simResult.Analysis));
    result.Success = false;

    if result.AnalysisType ~= "AC"
        result = result.addError( ...
            "Op-amp analysis currently supports AC only.");
        return;
    end

    if ~simResult.Success
        result = result.addError("SPICE simulation was unsuccessful.");
        return;
    end

    if isempty(genericResult) || ~genericResult.Success
        result = result.addError("Generic AC analysis is unsuccessful.");
        return;
    end

    try
        signals = simResult.ACSignals;

        if ~isfield(signals, "in") || ~isfield(signals, "out")
            result = result.addError( ...
                "Required AC signals 'in' and 'out' were not found.");
            return;
        end

        gainResult = calculateVoltageGain(signals.in, signals.out);

        if ~gainResult.Success
            result = result.addError( ...
                "Gain calculation failed: " + ...
                strjoin(string(gainResult.Errors(:)), "; "));
            return;
        end

        frequency = gainResult.Frequency(:);
        gainVV = gainResult.Gain_VV(:);
        gainDB = gainResult.Gain_dB(:);

        result = result.setMeasurement("Frequency", frequency);
        result = result.setMeasurement("VoltageGain", gainVV);
        result = result.setMeasurement("VoltageGain_dB", gainDB);
        result = result.setMeasurement( ...
            "PeakVoltageGain", gainResult.PeakGain_VV);
        result = result.setMeasurement( ...
            "PeakGain_dB", gainResult.PeakGain_dB);
        result = result.setMeasurement( ...
            "PeakGainFrequency", gainResult.PeakGainFrequency);

        % Record the theoretical non-inverting gain.
        componentNames = string({circuit.Components.Name});
        idxRF = find(componentNames == "RF", 1);
        idxRG = find(componentNames == "RG", 1);

        if ~isempty(idxRF) && ~isempty(idxRG)
            RF = double(circuit.Components(idxRF).Value);
            RG = double(circuit.Components(idxRG).Value);

            if isscalar(RF) && isscalar(RG) && ...
                    isfinite(RF) && isfinite(RG) && RF > 0 && RG > 0

                theoreticalGain = 1 + RF/RG;
                errorPercent = abs( ...
                    gainResult.PeakGain_VV - theoreticalGain) ...
                    / theoreticalGain * 100;

                result = result.setMeasurement( ...
                    "TheoreticalGain_VV", theoreticalGain);
                result = result.setMeasurement( ...
                    "GainErrorPercent", errorPercent);
            else
                result = result.addWarning( ...
                    "RF/RG values are not valid positive resistances.");
            end
        else
            result = result.addWarning( ...
                "RF or RG was not found; theoretical gain was omitted.");
        end

        % Calculate wrapped output-to-input phase difference.
        inputSignal = signals.in;
        outputSignal = signals.out;

        if isfield(inputSignal, "Phase") && ...
                isfield(outputSignal, "Phase")

            inputPhase = inputSignal.Phase(:);
            outputPhase = outputSignal.Phase(:);

            if numel(inputPhase) == numel(frequency) && ...
                    numel(outputPhase) == numel(frequency)

                valid = isfinite(inputPhase) & ...
                        isfinite(outputPhase) & ...
                        isfinite(frequency) & frequency > 0;

                if any(valid)
                    phaseRad = angle(exp(1i * ...
                        (outputPhase(valid) - inputPhase(valid))));
                    phaseDeg = rad2deg(phaseRad);
                    phaseFreq = frequency(valid);

                    result = result.setMeasurement( ...
                        "PhaseDifference_deg", phaseDeg);

                    [~, nearest] = min(abs( ...
                        phaseFreq - gainResult.PeakGainFrequency));

                    result = result.setMeasurement( ...
                        "PhaseDifferenceAtPeakGain_deg", ...
                        phaseDeg(nearest));
                end
            end
        end

        result.Success = true;

    catch ME
        result = result.addError( ...
            "Op-amp analysis failed: " + string(ME.message));
    end
end

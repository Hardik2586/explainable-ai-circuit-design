
function result = analyzeRCLowPass(circuit, simResult, genericResult)
%ANALYZERCLowPASS Topology-specific analysis for an RC low-pass filter.
%
% Uses generic AC simulation results.
% Does not rerun SPICE.
%
% For a low-pass filter, the cutoff frequency is the upper -3 dB
% crossing relative to the passband magnitude.

    %% INITIALIZE

    result = AnalysisResult();

    result.CircuitName = string(simResult.CircuitName);
    result.Topology = "RC_LowPass";
    result.AnalysisType = upper(string(simResult.Analysis));

    %% VALIDATE GENERIC RESULT

    if ~genericResult.Success
        result = result.addError( ...
            "Generic simulation analysis was not successful.");
        result.Success = false;
        return;
    end

    analysisType = upper(string(simResult.Analysis));

    %% AC ANALYSIS

    if analysisType == "AC"

        % Passband magnitude
        if genericResult.hasMeasurement("MaxMagnitude")
            value = genericResult.getMeasurement("MaxMagnitude");

            if ~isempty(value) && isfinite(value(1))
                result = result.setMeasurement( ...
                    "PassbandMagnitude", value(1));
            end
        end

        % Minimum magnitude
        if genericResult.hasMeasurement("MinMagnitude")
            value = genericResult.getMeasurement("MinMagnitude");

            if ~isempty(value) && isfinite(value(1))
                result = result.setMeasurement( ...
                    "MinimumMagnitude", value(1));
            end
        end

        % Peak frequency
        if genericResult.hasMeasurement("PeakFrequency")
            value = genericResult.getMeasurement("PeakFrequency");

            if ~isempty(value) && isfinite(value(1))
                result = result.setMeasurement( ...
                    "PeakFrequency", value(1));
            end
        end

        % Lower -3 dB crossing, if available
        if genericResult.hasMeasurement("FLower3dB")
            value = genericResult.getMeasurement("FLower3dB");

            if ~isempty(value) && isfinite(value(1))
                result = result.setMeasurement( ...
                    "Lower3dBFrequency", value(1));
            end
        end

        % Upper -3 dB crossing
        % This is the cutoff for a conventional RC low-pass filter.
        cutoffFrequency = NaN;

        if genericResult.hasMeasurement("FUpper3dB")
            value = genericResult.getMeasurement("FUpper3dB");

            if ~isempty(value) && isfinite(value(1)) && value(1) > 0
                cutoffFrequency = value(1);

                result = result.setMeasurement( ...
                    "Upper3dBFrequency", cutoffFrequency);

                result = result.setMeasurement( ...
                    "CutoffFrequency", cutoffFrequency);

                % For a low-pass response whose passband starts at DC,
                % bandwidth is approximately the cutoff frequency.
                result = result.setMeasurement( ...
                    "Bandwidth", cutoffFrequency);
            end
        end

        % Preserve generic bandwidth when available and finite.
        % The topology-specific value above takes precedence for a
        % conventional low-pass response.
        if ~isfinite(cutoffFrequency) && ...
                genericResult.hasMeasurement("Bandwidth3dB")

            value = genericResult.getMeasurement("Bandwidth3dB");

            if ~isempty(value) && isfinite(value(1))
                result = result.setMeasurement( ...
                    "Bandwidth", value(1));
            end
        end

        % Warnings
        if ~isfinite(cutoffFrequency)
            result = result.addWarning( ...
                ["The RC cutoff frequency could not be determined. " ...
                 "Check that the AC sweep crosses the -3 dB point."]);
        end

        % Success
        if result.hasMeasurement("PassbandMagnitude")
            result.Success = true;
        else
            result = result.addError( ...
                "RC low-pass analysis could not determine passband magnitude.");
            result.Success = false;
        end

        return;
    end

    %% DC ANALYSIS

    if analysisType == "DC"

        result = result.addWarning( ...
            "RC low-pass topology-specific DC interpretation is not currently enabled.");

        result.Success = genericResult.Success;
        return;
    end

    %% TRANSIENT ANALYSIS

    if analysisType == "TRAN"

        genericMeasurements = genericResult.Measurements;
        fields = fieldnames(genericMeasurements);

        for k = 1:numel(fields)
            fieldName = fields{k};

            result = result.setMeasurement( ...
                fieldName, genericMeasurements.(fieldName));
        end

        result = result.addWarning( ...
            "RC low-pass transient-specific interpretation is not currently enabled.");

        result.Success = genericResult.Success;
        return;
    end

    %% UNSUPPORTED ANALYSIS

    result = result.addError( ...
        "Unsupported analysis type for RC low-pass: " + analysisType);

    result.Success = false;

end

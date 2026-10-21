
function result = calculateVoltageGain(inputSignal, outputSignal)
%CALCULATEVOLTAGEGAIN Calculate AC voltage gain from two signals.
%
% Inputs:
%   inputSignal  - struct with Frequency and Magnitude fields
%   outputSignal - struct with Frequency and Magnitude fields
%
% Output:
%   result.Success
%   result.Frequency
%   result.Gain_VV
%   result.Gain_dB
%   result.PeakGain_VV
%   result.PeakGain_dB
%   result.PeakGainFrequency
%   result.Errors

    result = struct( ...
        "Success", false, ...
        "Frequency", [], ...
        "Gain_VV", [], ...
        "Gain_dB", [], ...
        "PeakGain_VV", NaN, ...
        "PeakGain_dB", NaN, ...
        "PeakGainFrequency", NaN, ...
        "Errors", strings(0,1));

    % Validate required fields.
    requiredFields = ["Frequency", "Magnitude"];

    for k = 1:numel(requiredFields)
        field = char(requiredFields(k));

        if ~isstruct(inputSignal) || ...
                ~isfield(inputSignal, field)
            result.Errors(end+1) = ...
                "Input signal missing field: " + requiredFields(k);
            return;
        end

        if ~isstruct(outputSignal) || ...
                ~isfield(outputSignal, field)
            result.Errors(end+1) = ...
                "Output signal missing field: " + requiredFields(k);
            return;
        end
    end

    fin = inputSignal.Frequency(:);
    fout = outputSignal.Frequency(:);
    vin = inputSignal.Magnitude(:);
    vout = outputSignal.Magnitude(:);

    % Validate vector dimensions.
    if isempty(fin) || isempty(fout) || ...
            isempty(vin) || isempty(vout)
        result.Errors(end+1) = "Signal vectors cannot be empty.";
        return;
    end

    if numel(fin) ~= numel(vin) || ...
            numel(fout) ~= numel(vout)
        result.Errors(end+1) = ...
            "Frequency and magnitude vector lengths must match.";
        return;
    end

    if numel(fin) ~= numel(fout) || ...
            any(abs(fin-fout) > ...
            1e-9 .* max(1,abs(fin)))
        result.Errors(end+1) = ...
            "Input and output frequency grids do not match.";
        return;
    end

    if any(~isfinite(fin)) || any(~isfinite(vin)) || ...
            any(~isfinite(vout)) || ...
            any(fin <= 0) || any(vin < 0) || any(vout < 0)
        result.Errors(end+1) = ...
            "Signals contain invalid frequency or magnitude values.";
        return;
    end

    % Avoid division by zero.
    validInput = vin > 0;

    if ~any(validInput)
        result.Errors(end+1) = ...
            "Input magnitude is zero at every frequency.";
        return;
    end

    gain = NaN(size(vin));
    gain(validInput) = vout(validInput) ./ vin(validInput);

    gainDB = NaN(size(gain));
    validGain = isfinite(gain) & gain > 0;
    gainDB(validGain) = 20 .* log10(gain(validGain));

    % Find peak gain among valid samples.
    [peakGain, idx] = max(gain(validInput));
    validIndices = find(validInput);
    peakIndex = validIndices(idx);

    result.Frequency = fin;
    result.Gain_VV = gain;
    result.Gain_dB = gainDB;
    result.PeakGain_VV = peakGain;
    result.PeakGain_dB = 20 * log10(peakGain);
    result.PeakGainFrequency = fin(peakIndex);
    result.Success = true;
end

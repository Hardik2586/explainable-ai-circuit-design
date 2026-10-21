function [Av, Av_dB, fL, fH, BW, ok] = extract_ac_metrics(freq, gain_dB, phase_deg)
% EXTRACT_AC_METRICS
% Extract voltage gain and bandwidth from an AC sweep.
%
% Outputs:
%   Av      - signed midband voltage gain
%   Av_dB   - midband gain in dB
%   fL      - lower -3 dB frequency
%   fH      - upper -3 dB frequency
%   BW      - bandwidth = fH - fL
%   ok      - true when valid bandwidth was found
%
% Method:
%   1. Clean and sort AC data.
%   2. Locate a contiguous near-maximum gain region.
%   3. Estimate midband gain from that region.
%   4. Find -3.0103 dB crossings.
%   5. Interpolate crossings in log-frequency.

    Av = NaN;
    Av_dB = NaN;
    fL = NaN;
    fH = NaN;
    BW = NaN;
    ok = false;

    % ---------------------------------------------------------------
    % 1. Validate input
    % ---------------------------------------------------------------
    if isempty(freq) || isempty(gain_dB)
        return;
    end

    if numel(freq) ~= numel(gain_dB)
        return;
    end

    freq = freq(:);
    gain_dB = gain_dB(:);

    if ~isempty(phase_deg)
        phase_deg = phase_deg(:);

        if numel(phase_deg) ~= numel(freq)
            return;
        end
    end

    % ---------------------------------------------------------------
    % 2. Remove invalid data
    % ---------------------------------------------------------------
    valid = isfinite(freq) & ...
            isfinite(gain_dB) & ...
            (freq > 0);

    if ~isempty(phase_deg)
        valid = valid & isfinite(phase_deg);
    end

    freq = freq(valid);
    gain_dB = gain_dB(valid);

    if ~isempty(phase_deg)
        phase_deg = phase_deg(valid);
    end

    if numel(freq) < 10
        return;
    end

    % ---------------------------------------------------------------
    % 3. Sort by frequency
    % ---------------------------------------------------------------
    [freq, order] = sort(freq);
    gain_dB = gain_dB(order);

    if ~isempty(phase_deg)
        phase_deg = phase_deg(order);
    end

    % ---------------------------------------------------------------
    % 4. Find near-peak region
    %
    % Points within 1 dB of the maximum are considered candidates
    % for the midband plateau.
    % ---------------------------------------------------------------
    global_max = max(gain_dB);

    if ~isfinite(global_max)
        return;
    end

    near_peak = gain_dB >= (global_max - 1.0);

    % Find contiguous regions
    d = diff([false; near_peak; false]);

    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    if isempty(starts)
        return;
    end

    % Select longest contiguous near-peak region
    lengths = ends - starts + 1;

    [~, k] = max(lengths);

    mid_start = starts(k);
    mid_end   = ends(k);

    % Need at least 3 points for a meaningful plateau
    if (mid_end - mid_start + 1) < 3

        % Fall back to a small neighborhood around the maximum
        [~, idx_max] = max(gain_dB);

        mid_start = max(1, idx_max - 2);
        mid_end   = min(numel(gain_dB), idx_max + 2);
    end

    % ---------------------------------------------------------------
    % 5. Calculate midband gain
    % ---------------------------------------------------------------
    Av_dB = median(gain_dB(mid_start:mid_end));

    if ~isfinite(Av_dB)
        return;
    end

    % ---------------------------------------------------------------
    % 6. Determine gain sign from phase
    % ---------------------------------------------------------------
    if isempty(phase_deg)

        % CE amplifier is normally inverting
        sign_val = -1;

    else

        phase_mid = median(phase_deg(mid_start:mid_end));

        % Wrap to [-180, 180]
        normalized_phase = ...
            mod(phase_mid + 180, 360) - 180;

        if abs(normalized_phase) > 90
            sign_val = -1;
        else
            sign_val = 1;
        end
    end

    Av = sign_val * 10^(Av_dB / 20);

    % ---------------------------------------------------------------
    % 7. -3 dB target
    % ---------------------------------------------------------------
    target = Av_dB - 3.0103;

    % ---------------------------------------------------------------
    % 8. Lower cutoff
    % ---------------------------------------------------------------
    fL = NaN;

    for i = mid_start:-1:2

        if gain_dB(i) >= target && ...
           gain_dB(i-1) < target

            fL = log_interp( ...
                freq(i-1), ...
                freq(i), ...
                gain_dB(i-1), ...
                gain_dB(i), ...
                target);

            break;
        end
    end

    % ---------------------------------------------------------------
    % 9. Upper cutoff
    % ---------------------------------------------------------------
    fH = NaN;

    for i = mid_end:numel(gain_dB)-1

        if gain_dB(i) >= target && ...
           gain_dB(i+1) < target

            fH = log_interp( ...
                freq(i), ...
                freq(i+1), ...
                gain_dB(i), ...
                gain_dB(i+1), ...
                target);

            break;
        end
    end

    % ---------------------------------------------------------------
    % 10. Validate bandwidth
    % ---------------------------------------------------------------
    if isfinite(fL) && ...
       isfinite(fH) && ...
       fH > fL

        BW = fH - fL;
        ok = true;

    else

        fL = NaN;
        fH = NaN;
        BW = NaN;
        ok = false;

    end

end


function f = log_interp(f1, f2, g1, g2, target)
% LOG_INTERP
% Interpolate a gain crossing on a logarithmic frequency axis.

    if f1 <= 0 || ...
       f2 <= 0 || ...
       f1 == f2 || ...
       g1 == g2

        f = NaN;
        return;
    end

    frac = (target - g1) / (g2 - g1);

    % Prevent numerical extrapolation
    frac = max(0, min(1, frac));

    logf1 = log10(f1);
    logf2 = log10(f2);

    f = 10^(logf1 + ...
        frac * (logf2 - logf1));

end
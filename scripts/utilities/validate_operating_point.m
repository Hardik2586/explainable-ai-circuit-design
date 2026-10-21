function [is_valid, status] = validate_operating_point( ...
    VB, VC, VE, IC, IB, VCC, cfg)
% VALIDATE_OPERATING_POINT
% Classify the DC operating region of an NPN BJT CE amplifier.
%
% Outputs:
%   is_valid : true only for a usable forward-active amplifier point
%   status   : operating-region label
%
% Physical criteria:
%   VBE = VB - VE
%   VCB = VC - VB
%
% Forward-active operation requires:
%   VBE > VBE_on
%   VBE < VBE_max
%   VCB > 0
%   IC > cutoff
%
% A forward-active point with VCE close to VCC is classified as
% NEAR_CUTOFF rather than a usable amplifier operating point.

    % Calculate junction voltages
    VBE = VB - VE;
    VCB = VC - VB;
    VCE = VC - VE;

    % ---------------------------------------------------------------
    % 1. Basic numerical validity
    % ---------------------------------------------------------------
    if any(isnan([VB VC VE IC IB])) || ...
       any(isinf([VB VC VE IC IB]))

        is_valid = false;
        status = 'Invalid';
        return;
    end

    % ---------------------------------------------------------------
    % 2. Cutoff
    % ---------------------------------------------------------------
    if IC <= cfg.ic_cutoff_a
        is_valid = false;
        status = 'Cutoff';
        return;
    end

    % ---------------------------------------------------------------
    % 3. Saturation
    %
    % For an NPN transistor in forward-active operation:
    %       VC > VB
    %
    % Therefore VCB <= 0 indicates the collector-base junction
    % is forward biased and the transistor has entered saturation.
    % ---------------------------------------------------------------
    if VCB <= 0
        is_valid = false;
        status = 'Saturation';
        return;
    end

    % ---------------------------------------------------------------
    % 4. Check base-emitter junction
    % ---------------------------------------------------------------
    if VBE < cfg.vbe_on_v
        is_valid = false;
        status = 'Cutoff';
        return;
    end

    if VBE > cfg.vbe_max_v
        is_valid = false;
        status = 'Invalid';
        return;
    end

    % ---------------------------------------------------------------
    % 5. Near-cutoff / insufficient collector-emitter headroom
    % ---------------------------------------------------------------
    if VCE >= cfg.vce_hi_frac * VCC
        is_valid = false;
        status = 'NearCutoff_HighVCE';
        return;
    end

    % ---------------------------------------------------------------
    % 6. Forward-active amplifier operating point
    % ---------------------------------------------------------------
    if VCE > cfg.vce_sat_v && VCB > 0 && IB > 0
        is_valid = true;
        status = 'Valid';
        return;
    end

    % ---------------------------------------------------------------
    % 7. Fallback
    % ---------------------------------------------------------------
    is_valid = false;
    status = 'Invalid';

end
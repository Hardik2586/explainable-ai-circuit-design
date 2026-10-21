function [VB, VE, VC, IB, IC, IE, ok] = parse_op_point(cmdout)
% PARSE_OP_POINT  Pull VB/VE/VC/IB/IC/IE out of ngspice's "print" output.
%   ngspice prints lines like:
%       v(base) = 7.234000e-01
%       @q1[ic] = 1.234000e-03
%   ok is false (and values NaN) if any of the six could not be found -
%   this is how a convergence failure or a parsing surprise gets caught
%   before it silently pollutes the dataset.

    VB = extract_val(cmdout, 'v\(base\)');
    VE = extract_val(cmdout, 'v\(emit\)');
    VC = extract_val(cmdout, 'v\(coll\)');
    IB = extract_val(cmdout, '@q1\[ib\]');
    IC = extract_val(cmdout, '@q1\[ic\]');
    IE = extract_val(cmdout, '@q1\[ie\]');

    ok = ~any(isnan([VB VE VC IB IC IE]));
end

function val = extract_val(text, pattern)
    val = NaN;
    tok = regexp(text, [pattern '\s*=\s*([\-+0-9.eE]+)'], 'tokens', 'once');
    if ~isempty(tok)
        v = str2double(tok{1});
        if isfinite(v)
            val = v;
        end
    end
end

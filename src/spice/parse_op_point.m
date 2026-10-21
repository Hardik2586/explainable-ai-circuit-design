function [VB, VE, VC, IB, IC, IE, success] = parse_op_point(logText)
% PARSE_OP_POINT Parse DC operating point values from ngspice log.
%
% Expected ngspice output:
%
%   v(base) = 2.120984e+00
%   v(emit) = 1.480793e+00
%   v(coll) = 1.428226e+01
%   @q1[ib] = 3.228923e-06
%   @q1[ic] = 4.372323e-04
%   @q1[ie] = -4.40461e-04
%
% Returns:
%   VB, VE, VC  : node voltages
%   IB, IC, IE  : transistor currents
%   success     : true if all six values were parsed

    %% --------------------------------------------------------
    % Initialize
    % ---------------------------------------------------------

    VB = NaN;
    VE = NaN;
    VC = NaN;

    IB = NaN;
    IC = NaN;
    IE = NaN;

    success = false;


    %% --------------------------------------------------------
    % Validate input
    % ---------------------------------------------------------

    if isempty(logText)
        return;
    end

    if isstring(logText)
        logText = char(logText);
    end


    %% --------------------------------------------------------
    % Parse node voltages
    % ---------------------------------------------------------

    token = regexp( ...
        logText, ...
        'v\(base\)\s*=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        VB = str2double(token{1});
    end


    token = regexp( ...
        logText, ...
        'v\(emit\)\s*=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        VE = str2double(token{1});
    end


    token = regexp( ...
        logText, ...
        'v\(coll\)\s*=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        VC = str2double(token{1});
    end


    %% --------------------------------------------------------
    % Parse transistor currents
    % ---------------------------------------------------------

    token = regexp( ...
        logText, ...
        '@q1\[ib\]\s*=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        IB = str2double(token{1});
    end


    token = regexp( ...
        logText, ...
        '@q1\[ic\]\s*=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        IC = str2double(token{1});
    end


    token = regexp( ...
        logText, ...
        '@q1\[ie\]\s*=\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)', ...
        'tokens', ...
        'once');

    if ~isempty(token)
        IE = str2double(token{1});
    end


    %% --------------------------------------------------------
    % Success condition
    % ---------------------------------------------------------

    success = all(isfinite([VB VE VC IB IC IE]));

end
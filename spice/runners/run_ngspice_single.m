function [status, cmdout] = run_ngspice_single(netlist_path, ngspice_exe)
% RUN_NGSPICE_SINGLE  Run ngspice -b on one netlist, capture stdout.
%   status  : process exit code (0 = ngspice ran without a fatal error;
%             it does NOT by itself mean the circuit converged cleanly -
%             always sanity-check the parsed values too)
%   cmdout  : full captured stdout+stderr text, used later to pull the
%             operating-point numbers back out with regexp.

    if nargin < 2 || isempty(ngspice_exe)
        ngspice_exe = 'ngspice';
    end

    cmd = sprintf('"%s" -b "%s"', ngspice_exe, netlist_path);
    [status, cmdout] = system(cmd);
end

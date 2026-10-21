function results = runSpiceSensitivity(baseParams, paramName, delta, workDir, options)
% RUNSPICESENSITIVITY Run baseline, +delta, and -delta simulations for one parameter.
%
%   results = runSpiceSensitivity(baseParams, paramName, delta, workDir)
%   results = runSpiceSensitivity(baseParams, paramName, delta, workDir, options)
%
%   INPUTS:
%     baseParams - struct with R1, R2, RC, RE, RL, Cin, Cout, Ce, VCC
%     paramName  - string, e.g. 'R1'
%     delta      - fractional perturbation, e.g. 0.01 for +/-1%
%     workDir    - working directory for simulation files
%     options    - optional options struct (passed to runSpice)
%
%   OUTPUT:
%     results - struct with:
%       .baseline     - runSpice result for unperturbed circuit
%       .plus         - runSpice result for +delta perturbation
%       .minus        - runSpice result for -delta perturbation
%       .sensitivity  - normalized sensitivity coefficient:
%                       S = (G_plus - G_minus) / (2*delta*G_baseline)
%                       where G values are in LINEAR scale (voltage gain)
%       .success      - true only if all 3 simulations succeeded
%       .paramName    - the parameter that was perturbed
%       .delta        - the perturbation fraction used

    if nargin < 5
        options = struct();
    end

    %% ---- Validate paramName ----
    if ~isfield(baseParams, paramName)
        error('runSpiceSensitivity:invalidParam', ...
            'Parameter "%s" not found in baseParams struct.', paramName);
    end

    %% ---- Initialize output ----
    results = struct();
    results.paramName   = paramName;
    results.delta       = delta;
    results.sensitivity = NaN;
    results.success     = false;

    %% ---- Create perturbed parameter structs ----
    baseValue = baseParams.(paramName);

    paramsPlus  = baseParams;
    paramsMinus = baseParams;
    paramsPlus.(paramName)  = baseValue * (1 + delta);
    paramsMinus.(paramName) = baseValue * (1 - delta);

    %% ---- Create subdirectories for each simulation ----
    dirBase  = fullfile(workDir, 'baseline');
    dirPlus  = fullfile(workDir, 'plus');
    dirMinus = fullfile(workDir, 'minus');

    %% ---- Run baseline simulation ----
    results.baseline = runSpice(baseParams, dirBase, options);

    %% ---- Run +delta simulation ----
    results.plus = runSpice(paramsPlus, dirPlus, options);

    %% ---- Run -delta simulation ----
    results.minus = runSpice(paramsMinus, dirMinus, options);

    %% ---- Check if all 3 succeeded ----
    if results.baseline.success && results.plus.success && results.minus.success
        results.success = true;

        % Convert dB gains to linear voltage gains: G_linear = 10^(G_dB/20)
        G_base  = 10^(results.baseline.gain_dB / 20);
        G_plus  = 10^(results.plus.gain_dB / 20);
        G_minus = 10^(results.minus.gain_dB / 20);

        % Normalized sensitivity coefficient:
        %   S_x = (G_plus - G_minus) / (2 * delta * G_baseline)
        if G_base ~= 0
            results.sensitivity = (G_plus - G_minus) / (2 * delta * G_base);
        else
            results.sensitivity = NaN;
        end
    end
end

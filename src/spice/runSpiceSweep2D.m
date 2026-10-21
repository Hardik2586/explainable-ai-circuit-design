function results = runSpiceSweep2D(baseParams, param1Name, param1Values, param2Name, param2Values, workDir, options)
% RUNSPICESWEEP2D Run a 2D parameter sweep in SPICE.
%
%   results = runSpiceSweep2D(baseParams, param1Name, param1Values, ...
%                             param2Name, param2Values, workDir)
%   results = runSpiceSweep2D(baseParams, param1Name, param1Values, ...
%                             param2Name, param2Values, workDir, options)
%
%   INPUTS:
%     baseParams    - struct with baseline circuit parameters
%     param1Name    - string, first parameter name (e.g., 'R1')
%     param1Values  - vector of values for first parameter
%     param2Name    - string, second parameter name (e.g., 'R2')
%     param2Values  - vector of values for second parameter
%     workDir       - base working directory
%     options       - optional options struct (passed to runSpice)
%
%   OUTPUT:
%     results - struct with:
%       .gain_surface  - nP1 x nP2 matrix of gain_dB values (NaN for failed)
%       .phase_surface - nP1 x nP2 matrix of phase values (NaN for failed)
%       .param1_values - the param1 values used
%       .param2_values - the param2 values used
%       .param1_name   - name of param1
%       .param2_name   - name of param2
%       .n_attempted   - total simulations attempted
%       .n_success     - total successful simulations
%       .n_failed      - total failed simulations
%       .success_rate  - n_success / n_attempted
%       .details       - nP1 x nP2 cell array of individual runSpice results

    if nargin < 7
        options = struct();
    end

    %% ---- Validate parameter names ----
    if ~isfield(baseParams, param1Name)
        error('runSpiceSweep2D:invalidParam', ...
            'Parameter "%s" not found in baseParams struct.', param1Name);
    end
    if ~isfield(baseParams, param2Name)
        error('runSpiceSweep2D:invalidParam', ...
            'Parameter "%s" not found in baseParams struct.', param2Name);
    end

    %% ---- Setup dimensions ----
    nP1 = length(param1Values);
    nP2 = length(param2Values);
    nTotal = nP1 * nP2;

    %% ---- Initialize output ----
    results = struct();
    results.gain_surface  = NaN(nP1, nP2);
    results.phase_surface = NaN(nP1, nP2);
    results.param1_values = param1Values(:)';
    results.param2_values = param2Values(:)';
    results.param1_name   = param1Name;
    results.param2_name   = param2Name;
    results.n_attempted   = nTotal;
    results.n_success     = 0;
    results.n_failed      = 0;
    results.success_rate  = 0;
    results.details       = cell(nP1, nP2);

    %% ---- Create base workDir ----
    if ~isfolder(workDir)
        mkdir(workDir);
    end

    %% ---- Run sweep ----
    fprintf('Starting 2D sweep: %s (%d values) x %s (%d values) = %d simulations\n', ...
        param1Name, nP1, param2Name, nP2, nTotal);

    runCount = 0;
    for i = 1:nP1
        for j = 1:nP2
            runCount = runCount + 1;

            % Create perturbed params
            sweepParams = baseParams;
            sweepParams.(param1Name) = param1Values(i);
            sweepParams.(param2Name) = param2Values(j);

            % Each simulation gets its own subdirectory
            simDir = fullfile(workDir, sprintf('sweep_i%02d_j%02d', i, j));

            % Run simulation
            simResult = runSpice(sweepParams, simDir, options);
            results.details{i, j} = simResult;

            if simResult.success
                results.gain_surface(i, j)  = simResult.gain_dB;
                results.phase_surface(i, j) = simResult.phase_deg;
                results.n_success = results.n_success + 1;
            else
                results.n_failed = results.n_failed + 1;
            end

            % Progress report every 10 simulations or at the end
            if mod(runCount, 10) == 0 || runCount == nTotal
                fprintf('  Progress: %d/%d (%.0f%% success so far)\n', ...
                    runCount, nTotal, 100 * results.n_success / runCount);
            end
        end
    end

    %% ---- Final statistics ----
    results.success_rate = results.n_success / results.n_attempted;
    fprintf('2D Sweep complete: %d attempted, %d success, %d failed (%.1f%% success rate)\n', ...
        results.n_attempted, results.n_success, results.n_failed, ...
        100 * results.success_rate);
end

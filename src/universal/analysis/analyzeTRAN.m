function result = analyzeTRAN(simResult)

    %% ============================================================
    %  INITIALIZE RESULT
    % =============================================================

    result = AnalysisResult();

    % Copy metadata when available
    try
        result.CircuitName = simResult.CircuitName;
    catch
    end

    try
        result.Topology = simResult.Topology;
    catch
    end

    result.AnalysisType = "TRAN";

    %% ============================================================
    %  INPUT VALIDATION
    % =============================================================

    if isempty(simResult)

        result = result.addError( ...
            "Transient simulation result is empty.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  CHECK SIMULATION SUCCESS
    % =============================================================

    try
        if ~simResult.Success

            result = result.addError( ...
                "Transient simulation was not successful.");

            result.Success = false;
            return;

        end
    catch

        result = result.addError( ...
            "Unable to determine transient simulation status.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  EXTRACT TIME VECTOR
    % =============================================================

    try
        time = simResult.Time;
    catch

        result = result.addError( ...
            "SimulationResult does not contain a Time vector.");

        result.Success = false;
        return;

    end

    if isempty(time)

        result = result.addError( ...
            "No transient time data was found.");

        result.Success = false;
        return;

    end

    time = double(time(:));

    %% ============================================================
    %  EXTRACT TRANSIENT SIGNAL
    % ============================================================

    signal = [];

    try

        transientSignals = simResult.TransientSignals;

        if isempty(transientSignals)

            result = result.addError( ...
                "No transient signals were found.");

            result.Success = false;
            return;
        end

        % --------------------------------------------------------
        % Case 1: Numeric matrix/vector
        % --------------------------------------------------------

        if isnumeric(transientSignals)

            data = double(transientSignals);

            if isvector(data)

                signal = data(:);

            else

                % Use first signal column as the generic
                % primary signal.
                signal = data(:,1);

            end

        % --------------------------------------------------------
        % Case 2: Struct
        % --------------------------------------------------------

        elseif isstruct(transientSignals)

            fields = fieldnames(transientSignals);

            foundSignal = false;

            for k = 1:numel(fields)

                candidate = transientSignals.(fields{k});

                if isnumeric(candidate) && ~isempty(candidate)

                    candidate = double(candidate(:));

                    if numel(candidate) == numel(time)

                        signal = candidate;
                        foundSignal = true;
                        break;

                    end

                end

            end

            if ~foundSignal

                result = result.addError( ...
                    "No valid numeric transient signal matched the time vector.");

                result.Success = false;
                return;

            end

        % --------------------------------------------------------
        % Case 3: Cell
        % --------------------------------------------------------

        elseif iscell(transientSignals)

            foundSignal = false;

            for k = 1:numel(transientSignals)

                candidate = transientSignals{k};

                if isnumeric(candidate) && ~isempty(candidate)

                    candidate = double(candidate(:));

                    if numel(candidate) == numel(time)

                        signal = candidate;
                        foundSignal = true;
                        break;

                    end

                end

            end

            if ~foundSignal

                result = result.addError( ...
                    "No valid numeric transient signal matched the time vector.");

                result.Success = false;
                return;

            end

        else

            result = result.addError( ...
                "Unsupported TransientSignals data type.");

            result.Success = false;
            return;

        end

    catch ME

        result = result.addError( ...
            "Failed to extract transient signal: " + string(ME.message));

        result.Success = false;
        return;

    end

    %% ============================================================
    %  VALIDATE SIGNAL LENGTH
    % =============================================================

    if isempty(signal)

        result = result.addError( ...
            "Transient signal is empty.");

        result.Success = false;
        return;

    end

    if numel(signal) ~= numel(time)

        result = result.addError( ...
            "Transient time and signal vectors have different lengths.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  REMOVE INVALID VALUES
    % =============================================================

    valid = isfinite(time) & isfinite(signal);

    time = time(valid);
    signal = signal(valid);

    if isempty(time)

        result = result.addError( ...
            "No valid numeric transient samples remain.");

        result.Success = false;
        return;

    end

    %% ============================================================
    %  SORT BY TIME
    % =============================================================

    [time, order] = sort(time);

    signal = signal(order);

    %% ============================================================
    %  BASIC MEASUREMENTS
    % =============================================================

    pointCount = numel(signal);

    startTime = time(1);

    endTime = time(end);

    duration = endTime - startTime;

    minSignal = min(signal);

    maxSignal = max(signal);

    peakToPeak = maxSignal - minSignal;

    %% ============================================================
    %  RMS
    % =============================================================

    rmsValue = sqrt(mean(signal.^2));

    %% ============================================================
    %  STORE MEASUREMENTS
    % =============================================================

    result = result.setMeasurement( ...
        "PointCount", pointCount);

    result = result.setMeasurement( ...
        "StartTime", startTime);

    result = result.setMeasurement( ...
        "EndTime", endTime);

    result = result.setMeasurement( ...
        "Duration", duration);

    result = result.setMeasurement( ...
        "MinSignal", minSignal);

    result = result.setMeasurement( ...
        "MaxSignal", maxSignal);

    result = result.setMeasurement( ...
        "PeakToPeak", peakToPeak);

    result = result.setMeasurement( ...
        "RMS", rmsValue);

    %% ============================================================
    %  STORE SUCCESS
    % =============================================================

    result.Success = true;

end
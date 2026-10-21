function result = analyzeDC(simResult)

    result = AnalysisResult();

    result.CircuitName = simResult.CircuitName;
    result.Topology = simResult.Topology;
    result.AnalysisType = "DC";

    % ------------------------------------------------------------
    % Basic validation
    % ------------------------------------------------------------

    if isempty(simResult)

        result = result.addError( ...
            "SimulationResult is empty.");

        return;
    end

    if ~simResult.Success

        result = result.addError( ...
            "SimulationResult indicates unsuccessful simulation.");

        return;
    end

    % ------------------------------------------------------------
    % Node voltages
    % ------------------------------------------------------------

    nodeVoltages = simResult.NodeVoltages;

    if isempty(nodeVoltages)

        result = result.addWarning( ...
            "No DC node-voltage data is available.");

    else

        % Convert supported numeric representations to vector.

        if isnumeric(nodeVoltages)

            values = nodeVoltages(:);

        elseif istable(nodeVoltages)

            values = table2array(nodeVoltages);
            values = values(:);

        elseif isstruct(nodeVoltages)

            fields = fieldnames(nodeVoltages);

            values = [];

            for k = 1:numel(fields)

                fieldValue = nodeVoltages.(fields{k});

                if isnumeric(fieldValue)

                    values(end+1,1) = fieldValue; %#ok<AGROW>
                end
            end

        else

            values = [];
        end

        values = values(isfinite(values));

        if isempty(values)

            result = result.addWarning( ...
                "No finite DC node-voltage values are available.");

        else

            result = result.setMeasurement( ...
                "NodeCount",numel(values));

            result = result.setMeasurement( ...
                "MinNodeVoltage",min(values));

            result = result.setMeasurement( ...
                "MaxNodeVoltage",max(values));

            result = result.setMeasurement( ...
                "NodeVoltageRange", ...
                max(values) - min(values));
        end
    end

    % ------------------------------------------------------------
    % Branch currents
    % ------------------------------------------------------------

    branchCurrents = simResult.BranchCurrents;

    if isempty(branchCurrents)

        result = result.addWarning( ...
            "No DC branch-current data is available.");

    else

        if isnumeric(branchCurrents)

            currentValues = branchCurrents(:);

        elseif istable(branchCurrents)

            currentValues = table2array(branchCurrents);
            currentValues = currentValues(:);

        elseif isstruct(branchCurrents)

            fields = fieldnames(branchCurrents);

            currentValues = [];

            for k = 1:numel(fields)

                fieldValue = branchCurrents.(fields{k});

                if isnumeric(fieldValue)

                    currentValues(end+1,1) = ...
                        fieldValue; %#ok<AGROW>
                end
            end

        else

            currentValues = [];
        end

        currentValues = ...
            currentValues(isfinite(currentValues));

        if isempty(currentValues)

            result = result.addWarning( ...
                "No finite DC branch-current values are available.");

        else

            result = result.setMeasurement( ...
                "BranchCurrentCount", ...
                numel(currentValues));

            result = result.setMeasurement( ...
                "MinBranchCurrent", ...
                min(currentValues));

            result = result.setMeasurement( ...
                "MaxBranchCurrent", ...
                max(currentValues));
        end
    end

    % ------------------------------------------------------------
    % Final status
    % ------------------------------------------------------------

    hasNodeData = result.hasMeasurement("NodeCount");
    hasCurrentData = result.hasMeasurement("BranchCurrentCount");

    if ~hasNodeData && ~hasCurrentData

        result = result.addError( ...
           "No usable DC measurements were extracted from the simulation.");

    else

        result.Success = true;

    end

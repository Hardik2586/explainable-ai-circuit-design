function simResult = parseSpiceOutput(executionResult)
    % INPUT VALIDATION
    if ~isstruct(executionResult)
        error( ...
            "parseSpiceOutput:InvalidInput", ...
            "executionResult must be a struct.");
    end

    % CREATE RESULT
    simResult = SimulationResult();

    % COPY EXECUTION METADATA
    if isfield(executionResult,"Success")
        simResult.Success = logical(executionResult.Success);
    end
    if isfield(executionResult,"ExitCode")
        simResult.ExitCode = executionResult.ExitCode;
    end
    if isfield(executionResult,"WorkDir")
        simResult.WorkDir = string(executionResult.WorkDir);
    end
    if isfield(executionResult,"NetlistPath")
        simResult.NetlistPath = string(executionResult.NetlistPath);
    end
    if isfield(executionResult,"OutputPath")
        simResult.OutputPath = string(executionResult.OutputPath);
    end
    if isfield(executionResult,"CircuitName")
        simResult.CircuitName = string(executionResult.CircuitName);
    end
    if isfield(executionResult,"Topology")
        simResult.Topology = string(executionResult.Topology);
    end
    if isfield(executionResult,"Analysis")
        simResult.Analysis = upper(string(executionResult.Analysis));
    end

    % READ RAW OUTPUT
    rawText = "";
    if isfield(executionResult,"Output") && ...
            ~isempty(executionResult.Output)
        rawText = string(executionResult.Output);
    elseif isfield(executionResult,"RawOutput") && ...
            ~isempty(executionResult.RawOutput)
        rawText = string(executionResult.RawOutput);
    elseif isfield(executionResult,"OutputPath") && ...
            strlength(string(executionResult.OutputPath)) > 0
        outputPath = char(string(executionResult.OutputPath));
        if isfile(outputPath)
            rawText = string(fileread(outputPath));
        end
    end

    simResult.RawOutput = rawText;

    % EXECUTION FAILURE CHECK
    if ~isfield(executionResult,"Success") || ...
            ~logical(executionResult.Success)
        if isfield(executionResult,"ErrorMessage")
            simResult.ErrorMessage = string(executionResult.ErrorMessage);
        else
            simResult.ErrorMessage = "SPICE execution failed.";
        end
        simResult.Success = false;
        return;
    end

    % DETERMINE ANALYSIS
    analysisType = upper(string(simResult.Analysis));

    if analysisType == "" || analysisType == "UNKNOWN"
        lowerText = lower(char(rawText));

        if contains(lowerText,"ac analysis")
            analysisType = "AC";
        elseif contains(lowerText,"node") && ...
                contains(lowerText,"voltage")
            analysisType = "DC";
        elseif contains(lowerText,"transient analysis")
            analysisType = "TRAN";
        elseif contains(lowerText,"transient")
            analysisType = "TRAN";
        end
    end

    simResult.Analysis = analysisType;

    % PARSE BY ANALYSIS
    switch analysisType
        case "AC"
            parseAC();

        case "DC"
            parseDC();

        case {"TRAN","TRANSIENT"}
            simResult.Analysis = "TRAN";
            parseTransient();

        otherwise
            simResult.Success = false;
            simResult.ErrorMessage = ...
                "Unable to determine SPICE analysis type.";
    end

    % ============================================================
    % NESTED AC PARSER
    % ============================================================
    function parseAC()
        % ngspice may repeat AC headers when output is paginated.
        lines = regexp(char(rawText), '\r\n|\n|\r', 'split');
        simResult.ACSignals = struct();

        % Locate every printed AC table header.
        headerIndices = [];

        for ii = 1:numel(lines)
            headerLine = lower(strtrim(lines{ii}));

            if contains(headerLine,'frequency') && ...
                    (contains(headerLine,'vm(') || ...
                     contains(headerLine,'vp('))
                headerIndices(end+1) = ii; %#ok<AGROW>
            end
        end

        % Legacy output fallback.
        if isempty(headerIndices)
            [freq,mag,phase,ok] = parseNumericACTable(lines);

            if ok
                simResult.Frequency = freq;
                simResult.Magnitude = mag;
                simResult.Phase = phase;
                simResult.Success = true;
                simResult.ErrorMessage = "";
            else
                simResult.Success = false;
                simResult.ErrorMessage = ...
                    "No valid AC data table was found in ngspice output.";
            end
            return;
        end

        parsedSignalCount = 0;

        % Process every table header and append its data.
        for hh = 1:numel(headerIndices)
            headerIndex = headerIndices(hh);

            headerTokens = regexp( ...
                lower(strtrim(lines{headerIndex})), ...
                '[^\s,]+', 'match');

            frequencyColumn = find( ...
                strcmp(headerTokens,'frequency'),1);

            if isempty(frequencyColumn)
                continue;
            end

            % Match magnitude and phase columns by node name.
            signalNames = {};
            magnitudeColumns = [];
            phaseColumns = [];

            for cc = 1:numel(headerTokens)
                token = headerTokens{cc};

                magToken = regexp( ...
                    token,'^vm\(([^)]+)\)$','tokens','once');

                phaseToken = regexp( ...
                    token,'^vp\(([^)]+)\)$','tokens','once');

                if ~isempty(magToken)
                    nodeName = magToken{1};
                    idx = find(strcmpi(signalNames,nodeName),1);

                    if isempty(idx)
                        signalNames{end+1} = nodeName; %#ok<AGROW>
                        magnitudeColumns(end+1) = cc; %#ok<AGROW>
                        phaseColumns(end+1) = NaN; %#ok<AGROW>
                    else
                        magnitudeColumns(idx) = cc;
                    end

                elseif ~isempty(phaseToken)
                    nodeName = phaseToken{1};
                    idx = find(strcmpi(signalNames,nodeName),1);

                    if isempty(idx)
                        signalNames{end+1} = nodeName; %#ok<AGROW>
                        magnitudeColumns(end+1) = NaN; %#ok<AGROW>
                        phaseColumns(end+1) = cc; %#ok<AGROW>
                    else
                        phaseColumns(idx) = cc;
                    end
                end
            end

            if isempty(signalNames)
                continue;
            end

            tableFrequency = [];
            tableMagnitude = cell(1,numel(signalNames));
            tablePhase = cell(1,numel(signalNames));

            for ss = 1:numel(signalNames)
                tableMagnitude{ss} = [];
                tablePhase{ss} = [];
            end

            % Read rows until the next AC header or analysis section.
            % Blank lines and nonnumeric headings are ignored.
            for rr = headerIndex+1:numel(lines)
                rowText = strtrim(lines{rr});

                if isempty(rowText)
                    continue;
                end

                lowerRow = lower(rowText);

                if contains(lowerRow,'frequency') && ...
                        (contains(lowerRow,'vm(') || ...
                         contains(lowerRow,'vp('))
                    break;
                end

                if contains(lowerRow,'dc analysis') || ...
                        contains(lowerRow,'transient analysis')
                    break;
                end

                if all(ismember(rowText,'-='))
                    continue;
                end

                tokens = regexp(rowText,'[^\s,]+','match');

                if isempty(tokens)
                    continue;
                end

                values = str2double(tokens);

                if frequencyColumn > numel(values) || ...
                        ~isfinite(values(frequencyColumn))
                    continue;
                end

                tableFrequency(end+1,1) = ...
                    values(frequencyColumn); %#ok<AGROW>

                for ss = 1:numel(signalNames)
                    mc = magnitudeColumns(ss);
                    pc = phaseColumns(ss);

                    if ~isnan(mc) && mc <= numel(values) && ...
                            isfinite(values(mc))
                        tableMagnitude{ss}(end+1,1) = ...
                            values(mc); %#ok<AGROW>
                    else
                        tableMagnitude{ss}(end+1,1) = ...
                            NaN; %#ok<AGROW>
                    end

                    if ~isnan(pc) && pc <= numel(values) && ...
                            isfinite(values(pc))
                        tablePhase{ss}(end+1,1) = ...
                            values(pc); %#ok<AGROW>
                    else
                        tablePhase{ss}(end+1,1) = ...
                            NaN; %#ok<AGROW>
                    end
                end
            end

            if isempty(tableFrequency)
                continue;
            end


            % Append parsed data for each signal, avoiding duplicate
            % frequency samples from repeated/paginated output.
            for ss = 1:numel(signalNames)
                fieldName = matlab.lang.makeValidName(signalNames{ss});

                newFrequency = tableFrequency(:);
                newMagnitude = tableMagnitude{ss}(:);
                newPhase = tablePhase{ss}(:);

                if isfield(simResult.ACSignals, fieldName)
                    oldSignal = simResult.ACSignals.(fieldName);

                    newFrequency = [oldSignal.Frequency(:); newFrequency];
                    newMagnitude = [oldSignal.Magnitude(:); newMagnitude];
                    newPhase = [oldSignal.Phase(:); newPhase];
                end

                % Retain the first occurrence of each frequency.
                [~, uniqueIndices] = unique(newFrequency, 'stable');
 
                signalData = struct( ...
                    'Name', string(signalNames{ss}), ...
                    'Frequency', newFrequency(uniqueIndices), ...
                    'Magnitude', newMagnitude(uniqueIndices), ...
                    'Phase', newPhase(uniqueIndices));

                simResult.ACSignals.(fieldName) = signalData;
                parsedSignalCount = parsedSignalCount + 1;
             end

        end

        % Populate legacy fields after all table chunks are accumulated.
        signalFields = fieldnames(simResult.ACSignals);

        if parsedSignalCount == 0 || isempty(signalFields)
            simResult.Success = false;
            simResult.ErrorMessage = ...
                "AC tables were detected, but no numeric signal rows were parsed.";
            return;
        end

        firstSignal = simResult.ACSignals.(signalFields{1});

        simResult.Frequency = firstSignal.Frequency;
        simResult.Magnitude = firstSignal.Magnitude;
        simResult.Phase = firstSignal.Phase;

        simResult.Success = true;
        simResult.ErrorMessage = "";
    end

    % ============================================================
    % NESTED DC PARSER
    % ============================================================
    function parseDC()
        text = char(rawText);
        lines = regexp(text,"\r\n|\n|\r","split");

        % Reset DC containers.
        simResult.NodeNames = strings(0,1);
        simResult.NodeVoltages = [];
        simResult.BranchNames = strings(0,1);
        simResult.BranchCurrents = [];

        % Find the node-voltage section.
        nodeHeaderIndex = [];

        for i = 1:numel(lines)
            current = lower(strtrim(lines{i}));

            if strcmp(current,"node voltage") || ...
                    (contains(current,"node") && ...
                     contains(current,"voltage"))
                nodeHeaderIndex = i;
                break;
            end
        end

        % Parse node voltages.
        if ~isempty(nodeHeaderIndex)
            nodeNames = strings(0,1);
            nodeVoltages = [];
            dataStart = nodeHeaderIndex + 1;

            for i = dataStart:numel(lines)
                lineText = strtrim(lines{i});

                if isempty(lineText)
                    continue;
                end

                lowerLine = lower(lineText);

                if contains(lowerLine,"source") && ...
                        contains(lowerLine,"current")
                    break;
                end

                if all(ismember(lineText,"-="))
                    continue;
                end

                tokens = regexp(lineText,"[^\s,]+","match");

                if numel(tokens) < 2
                    continue;
                end

                nodeName = string(tokens{1});
                voltage = str2double(tokens{2});

                if ~isfinite(voltage)
                    continue;
                end

                nodeNames(end+1,1) = nodeName; %#ok<AGROW>
                nodeVoltages(end+1,1) = voltage; %#ok<AGROW>
            end

            simResult.NodeNames = nodeNames;
            simResult.NodeVoltages = nodeVoltages;
        end

        % Find the source-current section.
        sourceHeaderIndex = [];

        for i = 1:numel(lines)
            current = lower(strtrim(lines{i}));

            if contains(current,"source") && ...
                    contains(current,"current")
                sourceHeaderIndex = i;
                break;
            end
        end

        % Parse source currents.
        if ~isempty(sourceHeaderIndex)
            branchNames = strings(0,1);
            branchCurrents = [];
            dataStart = sourceHeaderIndex + 1;

            for i = dataStart:numel(lines)
                lineText = strtrim(lines{i});

                if isempty(lineText)
                    continue;
                end

                lowerLine = lower(lineText);

                if contains(lowerLine,"bjt models") || ...
                        contains(lowerLine,"mosfet") || ...
                        contains(lowerLine,"capacitor models") || ...
                        contains(lowerLine,"resistor models") || ...
                        contains(lowerLine,"vsource") || ...
                        contains(lowerLine,"current controlled") || ...
                        contains(lowerLine,"device")
                    break;
                end

                if all(ismember(lineText,"-="))
                    continue;
                end

                tokens = regexp(lineText,"[^\s,]+","match");

                if numel(tokens) < 2
                    continue;
                end

                branchName = string(tokens{1});
                currentValue = str2double(tokens{2});

                if ~isfinite(currentValue)
                    continue;
                end

                branchNames(end+1,1) = branchName; %#ok<AGROW>
                branchCurrents(end+1,1) = currentValue; %#ok<AGROW>
            end

            simResult.BranchNames = branchNames;
            simResult.BranchCurrents = branchCurrents;
        end

        % Determine DC parser success.
        hasNodes = ~isempty(simResult.NodeVoltages);
        hasBranches = ~isempty(simResult.BranchCurrents);

        if hasNodes || hasBranches
            simResult.Success = true;
            simResult.ErrorMessage = "";
        else
            simResult.Success = false;
            simResult.ErrorMessage = ...
                "No recognizable DC node-voltage or branch-current data was found.";
        end
    end

    % ============================================================
    % NESTED TRANSIENT PARSER
    % ============================================================
    function parseTransient()
        % Parse native ngspice transient output.
        % The time column is located by its header, not assumed to be
        % the first numeric column.

        text = char(rawText);
        lines = regexp(text,"\r\n|\n|\r","split");

        % Find transient table headers.
        headerIndices = [];

        for i = 1:numel(lines)
            current = lower(strtrim(lines{i}));

            if contains(current,"index") && contains(current,"time")
                headerIndices(end+1) = i; %#ok<AGROW>
            end
        end

        if isempty(headerIndices)
            simResult.Success = false;
            simResult.ErrorMessage = ...
                "No recognizable transient output table was found.";
            return;
        end

        timeValues = [];
        signalValues = [];
        signalName = "";

        % Parse each transient table.
        for h = 1:numel(headerIndices)
            headerIndex = headerIndices(h);
            headerLine = strtrim(lines{headerIndex});

            headerTokens = regexp( ...
                headerLine,"[^\s,]+","match");

            if numel(headerTokens) < 2
                continue;
            end

            % Locate the time column.
            timeColumn = [];

            for k = 1:numel(headerTokens)
                token = lower(strtrim(headerTokens{k}));

                if strcmp(token,"time")
                    timeColumn = k;
                    break;
                end
            end

            if isempty(timeColumn)
                continue;
            end

            % Locate the first signal column.
            signalColumn = [];

            for k = 1:numel(headerTokens)
                token = lower(strtrim(headerTokens{k}));

                if startsWith(token,"v(") || ...
                        startsWith(token,"i(") || contains(token,"(")
                    signalColumn = k;
                    break;
                end
            end

            % Fallback signal column.
            if isempty(signalColumn)
                signalColumn = timeColumn + 1;
            end

            % Store signal name.
            if signalColumn <= numel(headerTokens)
                signalName = string(headerTokens{signalColumn});
            end

            localTime = [];
            localSignal = [];

            % Read table rows.
            for i = headerIndex+1:numel(lines)
                lineText = strtrim(lines{i});

                if isempty(lineText)
                    continue;
                end

                lowerLine = lower(lineText);

                % Stop at another analysis section.
                if contains(lowerLine,"ac analysis") || ...
                        contains(lowerLine,"dc analysis") || ...
                        (contains(lowerLine,"transient analysis") && ...
                         i ~= headerIndex)
                    break;
                end

                % Stop at another transient table header.
                if contains(lowerLine,"index") && ...
                        contains(lowerLine,"time") && ...
                        i ~= headerIndex
                    break;
                end

                if all(ismember(lineText,"-="))
                    continue;
                end

                tokens = regexp(lineText,"[^\s,]+","match");

                if isempty(tokens)
                    continue;
                end

                % Convert tokens to numeric values.
                numericValues = nan(1,numel(tokens));

                for j = 1:numel(tokens)
                    value = str2double(tokens{j});

                    if isfinite(value)
                        numericValues(j) = value;
                    end
                end

                if timeColumn > numel(numericValues) || ...
                        signalColumn > numel(numericValues)
                    continue;
                end

                t = numericValues(timeColumn);
                y = numericValues(signalColumn);

                if isfinite(t) && isfinite(y)
                    localTime(end+1,1) = t; %#ok<AGROW>
                    localSignal(end+1,1) = y; %#ok<AGROW>
                end
            end

            % Append the parsed table.
            if ~isempty(localTime)
                timeValues = [timeValues; localTime]; %#ok<AGROW>
                signalValues = [signalValues; localSignal]; %#ok<AGROW>
            end
        end

        % Validate parsed data.
        if isempty(timeValues)
            simResult.Success = false;
            simResult.ErrorMessage = ...
                "Transient analysis was detected, but no numeric time/signal data was parsed.";
            return;
        end

        % Remove non-finite values.
        valid = isfinite(timeValues) & isfinite(signalValues);
        timeValues = timeValues(valid);
        signalValues = signalValues(valid);

        % Remove duplicate time samples.
        [timeValues,uniqueIndices] = unique(timeValues,"stable");
        signalValues = signalValues(uniqueIndices);

        % Sort by time.
        [timeValues,sortIndices] = sort(timeValues);
        signalValues = signalValues(sortIndices);

        % Store result.
        simResult.Time = timeValues;
        simResult.TransientSignals = signalValues;

        % Store signal name if available.
        if strlength(signalName) > 0 && ...
                startsWith(lower(signalName),"v(")
            simResult.NodeNames = string(signalName);
        end

        simResult.Success = true;
        simResult.ErrorMessage = "";
    end

    % ============================================================
    % HELPER: FIND COLUMN
    % ============================================================
    function column = findColumn(headerText,target)
        tokens = regexp(headerText,"[^\s,]+","match");
        column = [];

        for k = 1:numel(tokens)
            if strcmpi(tokens{k},target)
                column = k;
                return;
            end
        end
    end

    % ============================================================
    % HELPER: FIND MAGNITUDE COLUMN
    % ============================================================
    function column = findMagnitudeColumn(headerText)
        tokens = regexp(headerText,"[^\s,]+","match");
        column = [];

        % Prefer vm(node).
        for k = 1:numel(tokens)
            token = lower(tokens{k});

            if startsWith(token,"vm(")
                column = k;
                return;
            end
        end

        % Support vdb(node).
        for k = 1:numel(tokens)
            token = lower(tokens{k});

            if startsWith(token,"vdb(")
                column = k;
                return;
            end
        end

        % Generic magnitude fallback.
        for k = 1:numel(tokens)
            token = lower(tokens{k});

            if contains(token,"mag(")
                column = k;
                return;
            end
        end
    end

    % ============================================================
    % HELPER: FIND PHASE COLUMN
    % ============================================================
    function column = findPhaseColumn(headerText)
        tokens = regexp(headerText,"[^\s,]+","match");
        column = [];

        for k = 1:numel(tokens)
            token = lower(tokens{k});

            if startsWith(token,"vp(")
                column = k;
                return;
            end
        end
    end

    % ============================================================
    % HELPER: LEGACY NUMERIC AC TABLE
    % ============================================================
    function [frequency,magnitude,phase,ok] = ...
            parseNumericACTable(lines)

        frequency = [];
        magnitude = [];
        phase = [];
        ok = false;

        for i = 1:numel(lines)
            tokens = regexp(strtrim(lines{i}),"[^\s,]+","match");

            if numel(tokens) < 3
                continue;
            end

            numericRow = nan(1,numel(tokens));

            for j = 1:numel(tokens)
                numericRow(j) = str2double(tokens{j});
            end

            if sum(isfinite(numericRow)) < 3
                continue;
            end

            % Typical ngspice AC format:
            % index, frequency, magnitude, phase.
            if numel(numericRow) >= 4
                f = numericRow(2);
                m = numericRow(3);
                p = numericRow(4);
            else
                f = numericRow(1);
                m = numericRow(2);
                p = numericRow(3);
            end

            if ~isfinite(f)
                continue;
            end

            frequency(end+1,1) = f; %#ok<AGROW>
            magnitude(end+1,1) = m; %#ok<AGROW>
            phase(end+1,1) = p; %#ok<AGROW>
        end

        ok = numel(frequency) >= 2;
    end
end
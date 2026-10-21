function expressions = buildPrintExpressions(spec)

    if ~isa(spec,"AnalysisSpec")

        error( ...
            "buildPrintExpressions:InvalidInput", ...
            "Input must be an AnalysisSpec object.");

    end


    resolved = ...
        resolveAnalysisSpec(spec);


    expressions = strings(0,1);


    %% ============================================================
    % CUSTOM EXPRESSIONS
    %
    % Custom expressions are preserved exactly.
    % ============================================================

    if ~isempty(resolved.CustomExpressions)

        expressions = [
            expressions
            resolved.CustomExpressions(:)
        ];

    end


    %% ============================================================
    % AC
    % ============================================================

    if resolved.Type == "AC"

        % Frequency is required to interpret the response.

        expressions(end+1,1) = ...
            "frequency";


        for k = 1:numel(resolved.OutputNodes)

            node = char(resolved.OutputNodes(k));


            if any( ...
                    strcmpi(resolved.Signals,"magnitude"))

                expressions(end+1,1) = ...
                    "vm(" + string(node) + ")";

            end


            if any( ...
                    strcmpi(resolved.Signals,"phase"))

                expressions(end+1,1) = ...
                    "vp(" + string(node) + ")";

            end

        end

    end


    %% ============================================================
    % DC
    % ============================================================

    if resolved.Type == "DC"

        % A generic DC table needs an independent row identifier.
        %
        % The default expression is the requested node voltage.

        for k = 1:numel(resolved.DCNodes)

            node = char(resolved.DCNodes(k));

            expressions(end+1,1) = ...
                "v(" + string(node) + ")";

        end


        for k = 1:numel(resolved.Branches)

            branch = char(resolved.Branches(k));

            expressions(end+1,1) = ...
                "i(" + string(branch) + ")";

        end

    end


    %% ============================================================
    % TRAN
    % ============================================================

    if resolved.Type == "TRAN"

        expressions(end+1,1) = ...
            "time";


        for k = 1:numel(resolved.OutputNodes)

            node = char(resolved.OutputNodes(k));


            if any( ...
                    strcmpi(resolved.Signals,"voltage"))

                expressions(end+1,1) = ...
                    "v(" + string(node) + ")";

            end

        end


        for k = 1:numel(resolved.Branches)

            branch = char(resolved.Branches(k));


            if any( ...
                    strcmpi(resolved.Signals,"current"))

                expressions(end+1,1) = ...
                    "i(" + string(branch) + ")";

            end

        end

    end


    %% ============================================================
    % CLEANUP
    % ============================================================

    expressions = ...
        unique(expressions,"stable");

end
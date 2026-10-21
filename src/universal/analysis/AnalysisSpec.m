classdef AnalysisSpec
  
    properties

        % =========================================================
        % ANALYSIS TYPE
        % =========================================================

        Type string = "AC"


        % =========================================================
        % AC SETTINGS
        % =========================================================

        ACStart double = 10

        ACStop double = 1e6

        PointsPerDecade double = 50


        % =========================================================
        % TRAN SETTINGS
        % =========================================================

        TimeStep double = []

        StopTime double = []

        StartTime double = []


        % =========================================================
        % OUTPUT NODES
        % =========================================================

        OutputNodes string = strings(0,1)


        % =========================================================
        % DC NODES
        % =========================================================

        DCNodes string = strings(0,1)


        % =========================================================
        % BRANCHES
        % =========================================================

        Branches string = strings(0,1)


        Signals string = strings(0,1)


        CustomExpressions string = strings(0,1)


        % =========================================================
        % METADATA
        % =========================================================

        Name string = ""

        Description string = ""

        Metadata struct = struct()

    end


    methods

        function obj = AnalysisSpec(type)

            if nargin >= 1 && ~isempty(type)

                obj.Type = upper(string(type));

            end

        end


        function obj = addOutputNode(obj,node)

            node = string(node);

            if strlength(node) == 0
                return;
            end

            obj.OutputNodes(end+1,1) = node;

        end


        function obj = addDCNode(obj,node)

            node = string(node);

            if strlength(node) == 0
                return;
            end

            obj.DCNodes(end+1,1) = node;

        end


        function obj = addBranch(obj,branch)

            branch = string(branch);

            if strlength(branch) == 0
                return;
            end

            obj.Branches(end+1,1) = branch;

        end


        function obj = addSignal(obj,signal)

            signal = lower(string(signal));

            if strlength(signal) == 0
                return;
            end

            obj.Signals(end+1,1) = signal;

        end


        function obj = addCustomExpression(obj,expression)

            expression = string(expression);

            if strlength(expression) == 0
                return;
            end

            obj.CustomExpressions(end+1,1) = expression;

        end

    end

end
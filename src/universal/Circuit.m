classdef Circuit
    properties
        Name string
        Components
        Nodes string
        Sources
        Metadata struct
    end

    methods

        function obj = Circuit(name)

            if nargin < 1
                name = "UnnamedCircuit";
            end

            obj.Name = string(name);

            obj.Components = Component.empty;

            obj.Nodes = strings(0,1);

            obj.Sources = Component.empty;

            obj.Metadata = struct();

            obj.Metadata.Created = datetime("now");
            obj.Metadata.Version = "1.0";
            obj.Metadata.Topology = "Unknown";
        end


        function obj = addComponent(obj, component)

            if ~isa(component, "Component")
                error("Circuit:InvalidComponent", ...
                    "Input must be a Component object.");
            end

            obj.Components(end+1) = component;

            % Register nodes
            for k = 1:numel(component.Nodes)

                node = component.Nodes(k);

                if ~any(obj.Nodes == node)
                    obj.Nodes(end+1,1) = node;
                end

            end

            % Sources are separately indexed
            if ismember(component.Type, ...
                    ["VOLTAGE","CURRENT","VOLTAGE_SOURCE","CURRENT_SOURCE"])

                obj.Sources(end+1) = component;
            end

        end


        function names = componentNames(obj)

            if isempty(obj.Components)
                names = strings(0,1);
                return;
            end

            names = string({obj.Components.Name})';

        end


        function types = componentTypes(obj)

            if isempty(obj.Components)
                types = strings(0,1);
                return;
            end

            types = string({obj.Components.Type})';

        end

    end
end
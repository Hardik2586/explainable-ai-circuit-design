classdef Component

    properties
        Name string
        Type string
        Nodes string
        Value
        Model string
        Parameters struct
        Metadata struct
    end

    methods

        function obj = Component(name, type, nodes, value, model)

            if nargin < 1
                name = "";
            end

            if nargin < 2
                type = "";
            end

            if nargin < 3
                nodes = strings(1,0);
            end

            if nargin < 4
                value = [];
            end

            if nargin < 5
                model = "";
            end

            obj.Name = string(name);
            obj.Type = upper(string(type));
            obj.Nodes = string(nodes);
            obj.Value = value;
            obj.Model = string(model);

            % Universal parameter container.
            obj.Parameters = struct();

            % Optional metadata container.
            obj.Metadata = struct();

        end


        function obj = setParameter(obj, name, value)
            %SETPARAMETER Set a named component parameter.

            if nargin < 3
                error( ...
                    "Component:MissingParameter", ...
                    "Parameter name and value are required.");
            end

            parameterName = char(string(name));

            if ~isvarname(parameterName)
                error( ...
                    "Component:InvalidParameterName", ...
                    "Invalid parameter name: %s", ...
                    parameterName);
            end

            obj.Parameters.(parameterName) = value;

        end


        function [value, exists] = getParameter(obj, name, defaultValue)
            %GETPARAMETER Read a parameter safely.
            %
            %   value = getParameter(obj,name)
            %   [value,exists] = getParameter(obj,name)
            %   value = getParameter(obj,name,defaultValue)

            parameterName = char(string(name));

            exists = isfield(obj.Parameters, parameterName);

            if exists
                value = obj.Parameters.(parameterName);
                return;
            end

            if nargin >= 3
                value = defaultValue;
            else
                value = [];
            end

        end


        function tf = hasParameter(obj, name)
            %HASPARAMETER True when the parameter exists.

            parameterName = char(string(name));

            tf = isfield(obj.Parameters, parameterName);

        end

    end

end
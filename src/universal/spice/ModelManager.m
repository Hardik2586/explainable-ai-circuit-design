classdef ModelManager
    %MODELMANAGER Manage SPICE device models for universal circuits.
    
    properties
        Models
    end

    methods

        function obj = ModelManager()

            obj.Models = struct( ...
                'Name', {}, ...
                'Type', {}, ...
                'Source', {}, ...
                'Path', {}, ...
                'Definition', {});

        end


        function obj = registerInlineModel( ...
                obj, name, type, definition)

            entry.Name = string(name);
            entry.Type = upper(string(type));
            entry.Source = "inline";
            entry.Path = "";
            entry.Definition = string(definition);

            obj = obj.addModel(entry);

        end


        function obj = registerFileModel( ...
                obj, name, type, filepath)

            if ~isfile(filepath)

                error("ModelManager:FileNotFound", ...
                    "SPICE model file not found: %s", ...
                    filepath);

            end

            entry.Name = string(name);
            entry.Type = upper(string(type));
            entry.Source = "file";
            entry.Path = string(filepath);
            entry.Definition = "";

            obj = obj.addModel(entry);

        end


        function model = getModel(obj, name)

            name = string(name);

            idx = find( ...
                string({obj.Models.Name}) == name, ...
                1);

            if isempty(idx)

                error("ModelManager:ModelNotFound", ...
                    "No SPICE model registered for '%s'.", ...
                    name);

            end

            model = obj.Models(idx);

        end


        function tf = hasModel(obj, name)

            name = string(name);

            if isempty(obj.Models)
                tf = false;
                return;
            end

            tf = any( ...
                string({obj.Models.Name}) == name);

        end


        function names = listModels(obj)

            if isempty(obj.Models)
                names = strings(0,1);
                return;
            end

            names = string({obj.Models.Name})';

        end

    end


    methods (Access = private)

        function obj = addModel(obj, entry)

            if obj.hasModel(entry.Name)

                error("ModelManager:DuplicateModel", ...
                    "Model '%s' is already registered.", ...
                    entry.Name);

            end

            obj.Models(end+1) = entry;

        end

    end

end
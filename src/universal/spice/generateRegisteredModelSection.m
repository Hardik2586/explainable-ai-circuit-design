function modelSection = generateRegisteredModelSection(circuit, modelManager)
%GENERATEREGISTEREDMODELSECTION Generate inline .MODEL definitions.
%
% File-backed MOSFET subcircuits are not copied into this section; their
% .include directives are generated separately by generateNetlist.

    if nargin < 2
        error("generateRegisteredModelSection:NotEnoughInputs", ...
            "Both circuit and modelManager are required.");
    end

    modelSection = strings(0,1);
    components = circuit.Components;
    emittedModels = strings(0,1);

    for k = 1:numel(components)
        comp = components(k);
        type = upper(string(comp.Type));

        if ~any(type == ["BJT", "MOSFET"])
            continue;
        end

        modelName = strtrim(string(comp.Model));
        if strlength(modelName) == 0
            continue;
        end

        useSubcircuit = false;
        if type == "MOSFET" && isstruct(comp.Parameters) && ...
                isfield(comp.Parameters, "UseSubcircuit")
            flag = comp.Parameters.UseSubcircuit;
            if ~isscalar(flag) || ...
                    ~(islogical(flag) || (isnumeric(flag) && isfinite(flag)))
                error("generateRegisteredModelSection:InvalidSubcircuitFlag", ...
                    "Parameters.UseSubcircuit for component '%s' must be a logical scalar.", ...
                    comp.Name);
            end
            useSubcircuit = logical(flag);
        end

        if useSubcircuit
            % The .SUBCKT library is included separately by generateNetlist.
            continue;
        end

        if any(strcmpi(emittedModels, modelName))
            continue;
        end

        model = modelManager.getModel(modelName);

        if upper(string(model.Source)) == "FILE"
            error("generateRegisteredModelSection:UnexpectedFileModel", ...
                "File-backed model '%s' must be used as a subcircuit and included separately.", ...
                modelName);
        end

        definition = string(model.Definition);
        if strlength(strtrim(definition)) == 0
            error("generateRegisteredModelSection:EmptyDefinition", ...
                "Registered model '%s' has an empty SPICE definition.", ...
                modelName);
        end

        definitionLines = splitlines(definition);
        for j = 1:numel(definitionLines)
            line = strtrim(definitionLines(j));
            if strlength(line) == 0
                continue;
            end
            modelSection(end+1,1) = line; %#ok<AGROW>
        end

        emittedModels(end+1,1) = modelName; %#ok<AGROW>
    end
end

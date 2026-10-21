function validateRequiredModels(circuit, modelManager)
%VALIDATEREQUIREDMODELS Validate registered models needed by a circuit.
%
% Traditional BJT/MOSFET .MODEL devices require a registered model.
% MOSFET subcircuit devices (Parameters.UseSubcircuit=true) require a
% registered model whose Source is "file" and whose Path exists.
%
% NOTE: This validates registration and file existence. It does not prove
% that the model file is ngspice-compatible or that it defines the expected
% .SUBCKT name/pin order; validate those with a single ngspice test.

    if nargin < 2
        error("validateRequiredModels:NotEnoughInputs", ...
            "Both circuit and modelManager are required.");
    end

    if isempty(circuit)
        error("validateRequiredModels:EmptyCircuit", ...
            "Circuit cannot be empty.");
    end

    if isempty(modelManager)
        error("validateRequiredModels:EmptyModelManager", ...
            "ModelManager cannot be empty.");
    end

    components = circuit.Components;

    for k = 1:numel(components)
        comp = components(k);
        type = upper(string(comp.Type));
        modelName = strtrim(string(comp.Model));

        if ~any(type == ["BJT", "MOSFET"])
            continue;
        end

        if strlength(modelName) == 0
            error("validateRequiredModels:MissingModelName", ...
                "Component '%s' of type '%s' requires a model name.", ...
                comp.Name, comp.Type);
        end

        useSubcircuit = false;
        if type == "MOSFET" && isstruct(comp.Parameters) && ...
                isfield(comp.Parameters, "UseSubcircuit")
            flag = comp.Parameters.UseSubcircuit;
            if ~isscalar(flag) || ...
                    ~(islogical(flag) || (isnumeric(flag) && isfinite(flag)))
                error("validateRequiredModels:InvalidSubcircuitFlag", ...
                    "Parameters.UseSubcircuit for component '%s' must be a logical scalar.", ...
                    comp.Name);
            end
            useSubcircuit = logical(flag);
        end

        if useSubcircuit
            if ~modelManager.hasModel(modelName)
                error("validateRequiredModels:ModelNotRegistered", ...
                    "Subcircuit '%s' for component '%s' is not registered.", ...
                    modelName, comp.Name);
            end

            model = modelManager.getModel(modelName);
            if upper(string(model.Source)) ~= "FILE"
                error("validateRequiredModels:SubcircuitMustBeFileModel", ...
                    "Subcircuit '%s' must be registered using registerFileModel.", ...
                    modelName);
            end
            if strlength(string(model.Path)) == 0 || ~isfile(model.Path)
                error("validateRequiredModels:SubcircuitFileMissing", ...
                    "Library file for subcircuit '%s' is missing: %s", ...
                    modelName, model.Path);
            end
        else
            if ~modelManager.hasModel(modelName)
                error("validateRequiredModels:ModelNotRegistered", ...
                    "Required model '%s' for component '%s' is not registered.", ...
                    modelName, comp.Name);
            end

            model = modelManager.getModel(modelName);
            if upper(string(model.Source)) == "FILE"
                error("validateRequiredModels:FileModelNeedsSubcircuitMode", ...
                    "Model '%s' is registered as a file model. For a MOSFET subcircuit, set Parameters.UseSubcircuit=true.", ...
                    modelName);
            end
        end
    end
end

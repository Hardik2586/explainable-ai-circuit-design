function report = validateCircuit(circuit)

    if ~isa(circuit, "Circuit")
        error("validateCircuit:InvalidInput", ...
            "Input must be a Circuit object.");
    end

    errors = strings(0,1);
    warnings = strings(0,1);


    %% Basic circuit check

    if isempty(circuit.Components)

        errors(end+1) = ...
            "Circuit contains no components.";

    end
    
    if ~isfield(circuit.Metadata, "Topology")

    warnings(end+1) = ...
        "Circuit topology is not specified.";

    elseif strlength(string(circuit.Metadata.Topology)) == 0 || ...
        string(circuit.Metadata.Topology) == "Unknown"

    warnings(end+1) = ...
        "Circuit topology is unknown.";

    end

    %% Duplicate component names

    names = circuit.componentNames();

    if numel(unique(names)) ~= numel(names)

        errors(end+1) = ...
            "Duplicate component names detected.";

    end


    %% Component checks

    for k = 1:numel(circuit.Components)

        comp = circuit.Components(k);


        % Name
        if strlength(comp.Name) == 0

            errors(end+1) = ...
                "Component has no name.";

        end


        % Type
        if strlength(comp.Type) == 0

            errors(end+1) = ...
                "Component " + comp.Name + ...
                " has no type.";

        end


        % Nodes
        if isempty(comp.Nodes)

            errors(end+1) = ...
                "Component " + comp.Name + ...
                " has no nodes.";

        end


        % Resistors
        if comp.Type == "R"

            if isempty(comp.Value) || ...
                    ~isnumeric(comp.Value) || ...
                    comp.Value <= 0

                errors(end+1) = ...
                    "Invalid resistance for " + comp.Name;

            end

        end


        % Capacitors
        if comp.Type == "C"

            if isempty(comp.Value) || ...
                    ~isnumeric(comp.Value) || ...
                    comp.Value <= 0

                errors(end+1) = ...
                    "Invalid capacitance for " + comp.Name;

            end

        end


        % BJT
        if comp.Type == "BJT"

            if numel(comp.Nodes) ~= 3

                errors(end+1) = ...
                    "BJT " + comp.Name + ...
                    " must have exactly 3 nodes.";

            end

            if strlength(comp.Model) == 0

                warnings(end+1) = ...
                    "BJT " + comp.Name + ...
                    " has no SPICE model.";

            end

        end

    end


    %% Ground check

    if ~any(circuit.Nodes == "GND")

        warnings(end+1) = ...
            "Circuit does not contain a GND node.";

    end


    %% Report

    report = struct();

    report.Valid = isempty(errors);

    report.Errors = errors;

    report.Warnings = warnings;

    report.NumComponents = numel(circuit.Components);

    report.NumNodes = numel(circuit.Nodes);

    report.ComponentNames = names;

    report.ComponentTypes = circuit.componentTypes();

end
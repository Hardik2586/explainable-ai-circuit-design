function spec = createAnalysisSpec(type)

    if nargin < 1 || isempty(type)

        type = "AC";

    end


    type = upper(string(type));


    switch type

        case "AC"

            spec = AnalysisSpec("AC");

            spec.Name = "AC Analysis";

            spec.Description = ...
                "Small-signal frequency-domain analysis.";

            spec.Signals = [
                "magnitude"
                "phase"
            ];


        case "DC"

            spec = AnalysisSpec("DC");

            spec.Name = "DC Analysis";

            spec.Description = ...
                "DC operating-point analysis.";

            spec.Signals = [
                "voltage"
                "current"
            ];


        case "TRAN"

            spec = AnalysisSpec("TRAN");

            spec.Name = "Transient Analysis";

            spec.Description = ...
                "Time-domain transient analysis.";

            spec.Signals = [
                "voltage"
                "current"
            ];


        otherwise

            error( ...
                "createAnalysisSpec:UnsupportedType", ...
                "Unsupported analysis type '%s'. Supported types are AC, DC and TRAN.", ...
                type);

    end

end
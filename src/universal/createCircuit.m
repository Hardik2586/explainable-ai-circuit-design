function circuit = createCircuit(name)

    if nargin < 1
        name = "UnnamedCircuit";
    end

    circuit = Circuit(name);

end
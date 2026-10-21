
clearvars;
clc;

root = 'C:\Internship Project';
addpath(genpath(fullfile(root, 'src')));
rehash;

% Register external 2N7000 model
modelPath = fullfile(root, 'models', 'mosfet', ...
    '2N7000.onsemi.lib');

assert(isfile(modelPath), ...
    'Model file not found: %s', modelPath);

modelManager = ModelManager();
modelManager = modelManager.registerFileModel( ...
    "2N7000", "MOSFET", modelPath);

% Create one common-source amplifier
ckt = createCircuit("External_2N7000_Test");
ckt.Metadata.Topology = "Common_Source";

ckt = circuitAddComponent(ckt, "VDD", ...
    "VOLTAGE_SOURCE", ["VDD","GND"], 12);

ckt = circuitAddComponent(ckt, "VIN", ...
    "VOLTAGE_SOURCE", ["IN","GND"], 0);

ckt = circuitAddComponent(ckt, "RD", ...
    "R", ["VDD","DRAIN"], 2200);

ckt = circuitAddComponent(ckt, "RS", ...
    "R", ["SOURCE","GND"], 820);

ckt = circuitAddComponent(ckt, "RGU", ...
    "R", ["VDD","GATE"], 100000);

ckt = circuitAddComponent(ckt, "M1", ...
    "MOSFET", ["DRAIN","GATE","SOURCE"], [], "2N7000");

ckt = circuitAddComponent(ckt, "RGL", ...
    "R", ["GATE","GND"], 56000);

ckt = circuitAddComponent(ckt, "CIN", ...
    "C", ["IN","GATE"], 10e-6);

% Enable external subcircuit instantiation
idxM1 = find(arrayfun(@(c) ...
    string(c.Name) == "M1", ckt.Components), 1);

assert(~isempty(idxM1), 'M1 was not found.');

m1 = ckt.Components(idxM1);
m1 = m1.setParameter("UseSubcircuit", true);
ckt.Components(idxM1) = m1;

% Configure AC input
idxVIN = find(arrayfun(@(c) ...
    string(c.Name) == "VIN", ckt.Components), 1);

vin = ckt.Components(idxVIN);
vin.Parameters.DC = 0;
vin.Parameters.AC = 1;
vin.Parameters.ACPhase = 0;
ckt.Components(idxVIN) = vin;

% Generate netlist
opts = struct();
opts.Analysis = "AC";
opts.ACStart = 10;
opts.ACStop = 1e6;
opts.PointsPerDecade = 50;
opts.PrintExpressions = [
    "vm(IN)", "vp(IN)", ...
    "vm(GATE)", "vp(GATE)", ...
    "vm(DRAIN)", "vp(DRAIN)"
];

netlist = generateNetlist(ckt, modelManager, opts);

% Save netlist
outDir = fullfile(root, 'diagnostics');
if ~isfolder(outDir)
    mkdir(outDir);
end

netlistPath = fullfile(outDir, ...
    'External_2N7000_Test.cir');

fid = fopen(netlistPath, 'w');
assert(fid >= 0, 'Could not write netlist.');

fprintf(fid, '%s\n', netlist);
fclose(fid);

fprintf('SUCCESS: Netlist generated at:\n%s\n', ...
    netlistPath);
disp(netlist);

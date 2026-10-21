clear;
clc;
close all;

%% 1. PROJECT PATHS
projectRoot = 'C:\Internship Project';

if ~isfolder(projectRoot)
    error('Project folder not found: %s', projectRoot);
end

cd(projectRoot);

addpath(genpath(fullfile(projectRoot, 'src', 'universal')));

fprintf('\n========================================\n');
fprintf(' COMMON-SOURCE SINGLE-CIRCUIT VALIDATION\n');
fprintf('========================================\n');

%% 2. CHECK REQUIRED FUNCTIONS AND CLASSES
requiredItems = {
    'createCircuit'
    'circuitAddComponent'
    'runUniversalSpice'
    'ModelManager'
};

for k = 1:numel(requiredItems)
    item = requiredItems{k};

    if exist(item, 'file') == 0 && exist(item, 'class') == 0
        error(['Required function/class not found: %s\n' ...
               'Check the project paths and source folders.'], item);
    end
end

fprintf('Required functions/classes found.\n');

%% 3. INITIALIZE APPROXIMATE MOSFET MODEL
% This is a simplified Level-1 model for pipeline testing.
% It is NOT a validated manufacturer model for a real 2N7000.

modelManager = ModelManager();

modelCard = ...
    '.model 2N7000 NMOS (LEVEL=1 VTO=2 KP=0.05 LAMBDA=0.02)';

modelManager = modelManager.registerInlineModel( ...
    "2N7000", "MOSFET", modelCard);

fprintf('\nMOSFET model registered:\n%s\n', modelCard);

%% 4. DEFINE ONE FIXED CIRCUIT CONFIGURATION
VDD = 12;
RGU = 100e3;
RGL = 68e3;
RD  = 2.2e3;
RS  = 1e3;
CIN = 10e-6;

fprintf('\nCircuit parameters:\n');
fprintf('VDD = %.3f V\n', VDD);
fprintf('RGU = %.3f kohm\n', RGU/1e3);
fprintf('RGL = %.3f kohm\n', RGL/1e3);
fprintf('RD  = %.3f kohm\n', RD/1e3);
fprintf('RS  = %.3f kohm\n', RS/1e3);
fprintf('CIN = %.3f uF\n', CIN*1e6);

%% 5. BUILD CIRCUIT
circuit = createCircuit("CS_Validation_One");
circuit.Metadata.Topology = "Common_Source";

% DC supply
circuit = circuitAddComponent( ...
    circuit, "VDD", "VOLTAGE_SOURCE", ["VDD","GND"], VDD);

% Input source
circuit = circuitAddComponent( ...
    circuit, "VIN", "VOLTAGE_SOURCE", ["IN","GND"], 0);

% Configure input source for AC analysis.
% Components are handled as value objects in this project,
% so assign the modified component back to the circuit.
componentNames = string({circuit.Components.Name});
idxVIN = find(componentNames == "VIN", 1);

if isempty(idxVIN)
    error('VIN component was not found in circuit.Components.');
end

vin = circuit.Components(idxVIN);
vin = vin.setParameter("DC", 0);
vin = vin.setParameter("AC", 1);
vin = vin.setParameter("ACPhase", 0);
circuit.Components(idxVIN) = vin;

% Drain resistor
circuit = circuitAddComponent( ...
    circuit, "RD", "R", ["VDD","DRAIN"], RD);

% Source resistor
circuit = circuitAddComponent( ...
    circuit, "RS", "R", ["SOURCE","GND"], RS);

% Gate-bias divider
circuit = circuitAddComponent( ...
    circuit, "RGU", "R", ["VDD","GATE"], RGU);

circuit = circuitAddComponent( ...
    circuit, "RGL", "R", ["GATE","GND"], RGL);

% Input coupling capacitor
circuit = circuitAddComponent( ...
    circuit, "CIN", "C", ["IN","GATE"], CIN);

% NMOS transistor: drain, gate, source
circuit = circuitAddComponent( ...
    circuit, "M1", "MOSFET", ...
    ["DRAIN","GATE","SOURCE"], [], "2N7000");

fprintf('\nCircuit components:\n');

for k = 1:numel(circuit.Components)
    comp = circuit.Components(k);

    fprintf('%-6s | %-16s | Nodes: %s\n', ...
        char(comp.Name), ...
        char(comp.Type), ...
        strjoin(string(comp.Nodes), ', '));
end

%% 6. RUN DC OPERATING-POINT ANALYSIS
fprintf('\n========================================\n');
fprintf(' DC OPERATING POINT\n');
fprintf('========================================\n');

optionsDC = struct();
optionsDC.Analysis = "DC";
optionsDC.KeepFiles = true;

dc = runUniversalSpice(circuit, modelManager, optionsDC);

fprintf('\nDC result properties:\n');
disp(properties(dc));

fprintf('\nDC result summary:\n');
disp(dc);

if ~dc.Success
    error('DC simulation failed: %s', ...
        char(string(dc.ErrorMessage)));
end

%% 7. VALIDATE DC NODE VOLTAGES
if isempty(dc.NodeNames) || isempty(dc.NodeVoltages)
    error(['DC result has empty NodeNames or NodeVoltages. ' ...
           'Inspect the SPICE output parser.']);
end

nodeNames = lower(strtrim(string(dc.NodeNames(:))));
nodeVoltages = double(dc.NodeVoltages(:));

if numel(nodeNames) ~= numel(nodeVoltages)
    error('DC node names and voltages have different lengths.');
end

fprintf('\nParsed DC node voltages:\n');

for k = 1:numel(nodeNames)
    fprintf('%-15s = % .8f V\n', ...
        char(nodeNames(k)), nodeVoltages(k));
end

% These are helper-function calls defined at the bottom.
VG = getNodeVoltageLocal(nodeNames, nodeVoltages, "gate");
VS = getNodeVoltageLocal(nodeNames, nodeVoltages, "source");
VD = getNodeVoltageLocal(nodeNames, nodeVoltages, "drain");

VGS = VG - VS;
VDS = VD - VS;

% Approximate current through RS.
ID = VS / RS;

fprintf('\nCalculated DC values:\n');
fprintf('VG  = %.8f V\n', VG);
fprintf('VS  = %.8f V\n', VS);
fprintf('VD  = %.8f V\n', VD);
fprintf('VGS = %.8f V\n', VGS);
fprintf('VDS = %.8f V\n', VDS);
fprintf('ID  = %.8f A (%.5f mA)\n', ID, ID*1e3);

% Basic physical consistency checks.
if VG < -0.1 || VG > VDD + 0.1
    warning('Gate voltage is outside the expected supply range.');
end

if VS < -0.1 || VS > VDD + 0.1
    warning('Source voltage is outside the expected supply range.');
end

if VD < -0.1 || VD > VDD + 0.1
    warning('Drain voltage is outside the expected supply range.');
end

if ID < -1e-9
    warning('Calculated source current is negative; check node signs.');
end

if VD < VS
    warning('Drain voltage is below source voltage; inspect biasing.');
end

%% 8. RUN AC ANALYSIS
fprintf('\n========================================\n');
fprintf(' AC ANALYSIS\n');
fprintf('========================================\n');

optionsAC = struct();
optionsAC.Analysis = "AC";
optionsAC.ACStart = 10;
optionsAC.ACStop = 1e6;
optionsAC.PointsPerDecade = 50;
optionsAC.KeepFiles = true;

% Request magnitude and phase for input and drain nodes.
optionsAC.PrintExpressions = ...
    "vm(IN), vp(IN), vm(DRAIN), vp(DRAIN)";

fprintf('Requested AC expressions:\n%s\n', ...
    char(optionsAC.PrintExpressions));

ac = runUniversalSpice(circuit, modelManager, optionsAC);

fprintf('\nAC result properties:\n');
disp(properties(ac));

fprintf('\nAC result summary:\n');
disp(ac);

if ~ac.Success
    error('AC simulation failed: %s', ...
        char(string(ac.ErrorMessage)));
end

%% 9. INSPECT AC SIGNAL MAPPING
if isempty(ac.ACSignals)
    error(['ACSignals is empty. Inspect the AC parser and ' ...
           'buildPrintExpressions implementation.']);
end

fprintf('\nACSignals fields returned by parser:\n');
disp(fieldnames(ac.ACSignals));

if ~isfield(ac.ACSignals, 'in')
    error(['ACSignals.in is missing. Check whether the parser ' ...
           'maps the IN node to the field "in".']);
end

if ~isfield(ac.ACSignals, 'drain')
    error(['ACSignals.drain is missing. Check whether the parser ' ...
           'maps the DRAIN node to the field "drain".']);
end

fprintf('\nInput signal structure:\n');
disp(ac.ACSignals.in);

fprintf('\nDrain signal structure:\n');
disp(ac.ACSignals.drain);

requiredSignalFields = {'Magnitude', 'Frequency'};

for k = 1:numel(requiredSignalFields)
    fieldName = requiredSignalFields{k};

    if ~isfield(ac.ACSignals.in, fieldName)
        error('AC input signal lacks field: %s', fieldName);
    end

    if ~isfield(ac.ACSignals.drain, fieldName)
        error('AC drain signal lacks field: %s', fieldName);
    end
end

%% 10. CALCULATE AND VALIDATE GAIN
inputMagnitude = double(ac.ACSignals.in.Magnitude(:));
drainMagnitude = double(ac.ACSignals.drain.Magnitude(:));

frequency = double(ac.ACSignals.in.Frequency(:));
drainFrequency = double(ac.ACSignals.drain.Frequency(:));

if isempty(frequency)
    error('AC frequency vector is empty.');
end

if numel(frequency) ~= numel(inputMagnitude) || ...
   numel(frequency) ~= numel(drainMagnitude) || ...
   numel(frequency) ~= numel(drainFrequency)

    error('AC frequency and magnitude arrays have mismatched lengths.');
end

if any(~isfinite(frequency)) || any(frequency <= 0)
    error('AC frequency vector contains invalid values.');
end

if any(~isfinite(inputMagnitude)) || any(inputMagnitude <= 0)
    error('Input AC magnitude contains invalid or zero values.');
end

if any(~isfinite(drainMagnitude)) || any(drainMagnitude < 0)
    error('Drain AC magnitude contains invalid values.');
end

frequencyTolerance = max(1e-9, 1e-9 .* abs(frequency));

if any(abs(frequency - drainFrequency) > frequencyTolerance)
    error('Input and drain frequency grids do not match.');
end

gainLinear = drainMagnitude ./ inputMagnitude;
gainDB = 20 .* log10(max(gainLinear, realmin));

valid = isfinite(frequency) & isfinite(gainDB) & frequency > 0;

if ~any(valid)
    error('No valid AC gain points were returned.');
end

validFrequency = frequency(valid);
validGainDB = gainDB(valid);

[peakGainDB, peakIndex] = max(validGainDB);
peakFrequency = validFrequency(peakIndex);

% Gain at the point closest to 1 kHz.
[~, idx1k] = min(abs(validFrequency - 1e3));
gainAt1kHz = validGainDB(idx1k);

fprintf('\nAC verification results:\n');
fprintf('Number of valid AC points = %d\n', numel(validFrequency));
fprintf('Peak gain                 = %.4f dB\n', peakGainDB);
fprintf('Peak-gain frequency       = %.4f Hz\n', peakFrequency);
fprintf('Gain nearest 1 kHz        = %.4f dB\n', gainAt1kHz);

%% 11. PLOT AC RESPONSE
figure('Name', 'Common-Source AC Validation');

semilogx(validFrequency, validGainDB, 'LineWidth', 1.5);
grid on;

xlabel('Frequency (Hz)');
ylabel('Voltage Gain (dB)');
title('Common-Source MOSFET AC Gain');

hold on;
plot(peakFrequency, peakGainDB, 'o', 'MarkerSize', 7);

text(peakFrequency, peakGainDB, ...
    sprintf('  Peak %.2f dB at %.2f Hz', ...
    peakGainDB, peakFrequency), ...
    'VerticalAlignment', 'bottom');

hold off;

%% 12. SAVE DIAGNOSTIC OUTPUTS
% Save only this single-circuit diagnostic, not a training dataset.

diagnostic = struct();
diagnostic.Parameters = struct( ...
    'VDD', VDD, ...
    'RGU', RGU, ...
    'RGL', RGL, ...
    'RD', RD, ...
    'RS', RS, ...
    'CIN', CIN);

diagnostic.DC = struct( ...
    'NodeNames', nodeNames, ...
    'NodeVoltages', nodeVoltages, ...
    'VG', VG, ...
    'VS', VS, ...
    'VD', VD, ...
    'VGS', VGS, ...
    'VDS', VDS, ...
    'ID_A', ID);

diagnostic.AC = struct( ...
    'Frequency_Hz', validFrequency, ...
    'Gain_dB', validGainDB, ...
    'PeakGain_dB', peakGainDB, ...
    'PeakGainFrequency_Hz', peakFrequency, ...
    'GainAt1kHz_dB', gainAt1kHz);

diagnostic.ACSignalFields = fieldnames(ac.ACSignals);

outputDir = fullfile(projectRoot, 'diagnostics');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

save(fullfile(outputDir, 'CS_OneCircuit_Diagnostic.mat'), ...
    'diagnostic');

writetable(table( ...
    validFrequency, validGainDB, ...
    'VariableNames', {'Frequency_Hz', 'Gain_dB'}), ...
    fullfile(outputDir, 'CS_OneCircuit_AC_Response.csv'));

fprintf('\nDiagnostic files saved in:\n%s\n', outputDir);

fprintf('\n========================================\n');
fprintf(' VALIDATION SCRIPT COMPLETED\n');
fprintf('========================================\n');

%% LOCAL HELPER FUNCTION
function value = getNodeVoltageLocal(nodeNames, nodeVoltages, targetNode)

    nodeNames = lower(strtrim(string(nodeNames(:))));
    nodeVoltages = double(nodeVoltages(:));
    targetNode = lower(strtrim(string(targetNode)));

    if numel(nodeNames) ~= numel(nodeVoltages)
        error('Node names and voltage arrays have different lengths.');
    end

    idx = find(nodeNames == targetNode, 1);

    if isempty(idx)
        error('Node "%s" was not found in the DC result.', ...
            char(targetNode));
    end

    value = nodeVoltages(idx);

end

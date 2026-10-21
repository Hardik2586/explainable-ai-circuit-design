clearvars;
clc;

%% 1. Project paths

root = 'C:\Internship Project';

addpath(genpath(fullfile(root, 'src')));
rehash;

assert(exist('runUniversalSpice', 'file') == 2, ...
    'runUniversalSpice was not found. Check the project path.');

assert(exist('ModelManager', 'class') == 8 || ...
       exist('ModelManager', 'file') == 2, ...
    'ModelManager was not found. Check the project path.');

% Use a separate timestamped directory for this dataset version.
stamp = string(datetime("now", ...
    "Format", "yyyyMMdd_HHmmss"));

outputDir = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'external_model_validation', char(stamp));

if ~isfolder(outputDir)
    mkdir(outputDir);
end

fprintf('Output directory:\n%s\n', outputDir);

%% 2. Reproducible sampling: 100 unique configurations

rng(42, 'twister');

N = 100;

% Resistance values in ohms; capacitance values in farads.
RGU_values = [82e3, 100e3, 120e3];
RGL_values = [56e3, 68e3, 75e3, 82e3, 100e3];
RD_values  = [1.8e3, 2.2e3, 2.7e3];
RS_values  = [820, 1e3, 1.2e3];
CIN_values = [4.7e-6, 10e-6, 22e-6];

VDD = 12;
VTO = 2;

% Enumerate the full design space, then sample without replacement.
[A, B, C, D, E] = ndgrid( ...
    1:numel(RGU_values), ...
    1:numel(RGL_values), ...
    1:numel(RD_values), ...
    1:numel(RS_values), ...
    1:numel(CIN_values));

allCombos = [A(:), B(:), C(:), D(:), E(:)];

assert(size(allCombos, 1) >= N, ...
    'Not enough unique component combinations for N=%d.', N);

selected = randperm(size(allCombos, 1), N);
sampledCombos = allCombos(selected, :);

assert(size(unique(sampledCombos, 'rows'), 1) == N, ...
    'Duplicate component combinations were detected.');

fprintf('Available combinations: %d\n', size(allCombos, 1));
fprintf('Unique configurations selected: %d\n', N);

%% 3. Register the external 2N7000 subcircuit model

modelManager = ModelManager();

modelPath = fullfile(root, ...
    'models', 'mosfet', '2N7000.onsemi.lib');

assert(isfile(modelPath), ...
    'External 2N7000 model file not found: %s', modelPath);

modelManager = modelManager.registerFileModel( ...
    "2N7000", "MOSFET", modelPath);

fprintf('Registered external MOSFET model:\n%s\n', modelPath);

%% 4. Configure simulations

optionsDC = struct();
optionsDC.Analysis = "DC";
optionsDC.KeepFiles = true;

optionsAC = struct();
optionsAC.Analysis = "AC";
optionsAC.ACStart = 10;
optionsAC.ACStop = 1e6;
optionsAC.PointsPerDecade = 50;

% The AC parser expects magnitude and phase expressions.
optionsAC.PrintExpressions = [
    "vm(IN)",    "vp(IN)", ...
    "vm(GATE)",  "vp(GATE)", ...
    "vm(DRAIN)", "vp(DRAIN)"
];

optionsAC.KeepFiles = true;

% Common reference frequency for configuration comparisons.
referenceFrequency_Hz = 1000;

%% 5. Prepare result storage

rows = table();

% Each successful AC run stores its full response in this cell array.
acResponses = cell(N, 1);

for i = 1:N

    fprintf('\n========================================\n');
    fprintf('Configuration %d/%d\n', i, N);
    fprintf('========================================\n');

    %% 5A. Get this configuration's component values

    RGU = RGU_values(sampledCombos(i, 1));
    RGL = RGL_values(sampledCombos(i, 2));
    RD  = RD_values(sampledCombos(i, 3));
    RS  = RS_values(sampledCombos(i, 4));
    CIN = CIN_values(sampledCombos(i, 5));

    %% 5B. Initialize a complete result row

    row = table( ...
        i, RGU, RGL, RD, RS, CIN, VDD, ...
        NaN, NaN, NaN, NaN, NaN, NaN, ...
        NaN, NaN, NaN, NaN, ...
        NaN, NaN, NaN, ...
        false, false, false, false, ...
        "NOT_RUN", "NOT_RUN", "NOT_RUN", "", ...
        'VariableNames', { ...
        'CircuitID', ...
        'RGU_Ohm', 'RGL_Ohm', 'RD_Ohm', 'RS_Ohm', ...
        'CIN_F', 'VDD_V', ...
        'Vgate_V', 'Vsource_V', 'Vdrain_V', ...
        'VGS_V', 'VDS_V', 'ID_A', ...
        'PeakGain_VV', 'PeakGain_dB', ...
        'PeakGainFrequency_Hz', 'PhaseDiffAtPeak_deg', ...
        'GainAt1kHz_VV', 'GainAt1kHz_dB', ...
        'PhaseAt1kHz_deg', ...
        'DCSuccess', 'ACSuccess', ...
        'SimulationValid', 'AmplifierCandidate', ...
        'BiasRegion', 'DCStatus', 'ACStatus', ...
        'ErrorMessage'});

    try

        %% 6. Build the common-source circuit

        circuit = createCircuit( ...
            "Common_Source_V2_" + string(i));

        circuit.Metadata.Topology = "Common_Source";

        circuit = circuitAddComponent( ...
            circuit, "VDD", "VOLTAGE_SOURCE", ...
            ["VDD", "GND"], VDD);

        circuit = circuitAddComponent( ...
            circuit, "VIN", "VOLTAGE_SOURCE", ...
            ["IN", "GND"], 0);

        circuit = circuitAddComponent( ...
            circuit, "RD", "R", ...
            ["VDD", "DRAIN"], RD);

        circuit = circuitAddComponent( ...
            circuit, "RS", "R", ...
            ["SOURCE", "GND"], RS);

        circuit = circuitAddComponent( ...
            circuit, "RGU", "R", ...
            ["VDD", "GATE"], RGU);

        circuit = circuitAddComponent( ...
            circuit, "M1", "MOSFET", ...
            ["DRAIN", "GATE", "SOURCE"], [], "2N7000");
        %% Enable external MOSFET subcircuit mode

      idxM1 = find(arrayfun(@(c) ...
          string(c.Name) == "M1", circuit.Components), 1);

      assert(~isempty(idxM1), 'MOSFET M1 was not found.');

      mosfet = circuit.Components(idxM1);

      mosfet = mosfet.setParameter("UseSubcircuit", true);

      circuit.Components(idxM1) = mosfet;

      disp('M1 parameters:');
      disp(circuit.Components(idxM1).Parameters);

        circuit = circuitAddComponent( ...
            circuit, "RGL", "R", ...
            ["GATE", "GND"], RGL);

        circuit = circuitAddComponent( ...
            circuit, "CIN", "C", ...
            ["IN", "GATE"], CIN);

        % Configure the independent input source.
        idx = find(arrayfun(@(c) ...
            string(c.Name) == "VIN", circuit.Components), 1);

        if isempty(idx)
            error("Could not find the VIN component.");
        end

        vin = circuit.Components(idx);
        vin.Parameters.DC = 0;
        vin.Parameters.AC = 1;
        vin.Parameters.ACPhase = 0;
        circuit.Components(idx) = vin;

        %% 7. Run DC operating-point simulation

        dc = runUniversalSpice(circuit, modelManager, optionsDC);

        row.DCSuccess = logical(dc.Success);

        if ~dc.Success
            row.DCStatus = "FAILED";
            row.ACStatus = "SKIPPED_DC_FAILURE";
            row.ErrorMessage = string(dc.ErrorMessage);

            rows = appendRow(rows, row);

            fprintf('DC failed: %s\n', row.ErrorMessage);
            continue;
        end

        row.DCStatus = "SUCCESS";

        % Read node voltages from the simulation result.
        row.Vgate_V = getNodeVoltage(dc, "gate");
        row.Vsource_V = getNodeVoltage(dc, "source");
        row.Vdrain_V = getNodeVoltage(dc, "drain");

        row.VGS_V = row.Vgate_V - row.Vsource_V;
        row.VDS_V = row.Vdrain_V - row.Vsource_V;

        % Estimate drain current from the source resistor.
        row.ID_A = row.Vsource_V / RS;

        % Preliminary region label based on the simplified model.
        row.BiasRegion = "UNCLASSIFIED_EXTERNAL_MODEL";
        %% 8. Run AC simulation

        ac = runUniversalSpice(circuit, modelManager, optionsAC);

        row.ACSuccess = logical(ac.Success);

        if ~ac.Success
            row.ACStatus = "FAILED";
            row.ErrorMessage = appendError( ...
                row.ErrorMessage, string(ac.ErrorMessage));

            rows = appendRow(rows, row);

            fprintf('AC failed: %s\n', row.ErrorMessage);
            continue;
        end

        %% 9. Validate and extract AC signals

        if isempty(ac.ACSignals)
            error("AC simulation returned no parsed AC signals.");
        end

        available = string(fieldnames(ac.ACSignals));
        required = ["in", "drain"];

        if ~all(ismember(required, available))
            error("Required AC signals 'in' and 'drain' are missing.");
        end

        inputSignal = ac.ACSignals.in;
        outputSignal = ac.ACSignals.drain;

        f = inputSignal.Frequency(:);
        fOut = outputSignal.Frequency(:);

        if isempty(f) || isempty(fOut)
            error("The AC frequency response is empty.");
        end

        if numel(f) ~= numel(fOut) || ...
                any(abs(f - fOut) > 1e-9)
            error("Input/output frequency grids do not match.");
        end

        Vin = inputSignal.Magnitude(:);
        Vout = outputSignal.Magnitude(:);

        phaseIn_rad = inputSignal.Phase(:);
        phaseOut_rad = outputSignal.Phase(:);

        if numel(Vin) ~= numel(f) || ...
                numel(Vout) ~= numel(f) || ...
                numel(phaseIn_rad) ~= numel(f) || ...
                numel(phaseOut_rad) ~= numel(f)
            error("AC signal arrays have inconsistent lengths.");
        end

        if any(~isfinite(f)) || any(f <= 0) || ...
                any(~isfinite(Vin)) || ...
                any(~isfinite(Vout)) || ...
                any(~isfinite(phaseIn_rad)) || ...
                any(~isfinite(phaseOut_rad)) || ...
                any(Vin <= 0) || any(Vout < 0)
            error("AC response contains invalid values.");
        end

        % Sort by frequency in case the parser returns unordered points.
        [f, order] = sort(f);

        Vin = Vin(order);
        Vout = Vout(order);
        phaseIn_rad = phaseIn_rad(order);
        phaseOut_rad = phaseOut_rad(order);

        if numel(unique(f)) ~= numel(f)
            error("Duplicate frequency points remain after parsing.");
        end

        % Voltage gain and gain in decibels.
        gainVV = Vout ./ Vin;
        gainDB = 20 * log10(max(gainVV, realmin));

        % Phase difference, converted from radians to degrees.
        phaseDifference_deg = rad2deg( ...
            unwrap(phaseOut_rad - phaseIn_rad));

        % Wrap phase values into [-180, 180).
        phaseDifferenceWrapped_deg = ...
            mod(phaseDifference_deg + 180, 360) - 180;

        % Peak gain.
        [row.PeakGain_VV, k] = max(gainVV);

        row.PeakGain_dB = gainDB(k);
        row.PeakGainFrequency_Hz = f(k);
        row.PhaseDiffAtPeak_deg = phaseDifferenceWrapped_deg(k);

        %% 10. Interpolate gain and phase at 1 kHz

        if referenceFrequency_Hz < min(f) || ...
                referenceFrequency_Hz > max(f)
            error("The 1 kHz reference is outside the AC sweep.");
        end

        % Log-frequency interpolation is appropriate for logarithmic sweeps.
        logF = log10(f);
        logFReference = log10(referenceFrequency_Hz);

        row.GainAt1kHz_dB = interp1( ...
            logF, gainDB, logFReference, 'linear');

        row.GainAt1kHz_VV = ...
            10^(row.GainAt1kHz_dB / 20);

        phase1kHz_unwrapped = interp1( ...
            logF, phaseDifference_deg, ...
            logFReference, 'linear');

        row.PhaseAt1kHz_deg = ...
            mod(phase1kHz_unwrapped + 180, 360) - 180;

        %% 11. Preserve the full AC response

        acResponses{i} = struct( ...
            'CircuitID', i, ...
            'Frequency_Hz', f, ...
            'InputMagnitude_V', Vin, ...
            'OutputMagnitude_V', Vout, ...
            'Gain_VV', gainVV, ...
            'Gain_dB', gainDB, ...
            'InputPhase_rad', phaseIn_rad, ...
            'OutputPhase_rad', phaseOut_rad, ...
            'PhaseDifference_deg', phaseDifferenceWrapped_deg);

        row.ACStatus = "SUCCESS";

        %% 12. Apply validity and candidate screening rules

        requiredMetrics = [ ...
            row.Vgate_V, row.Vsource_V, row.Vdrain_V, ...
            row.VGS_V, row.VDS_V, row.ID_A, ...
            row.PeakGain_VV, row.PeakGain_dB, ...
            row.PeakGainFrequency_Hz, ...
            row.PhaseDiffAtPeak_deg, ...
            row.GainAt1kHz_VV, row.GainAt1kHz_dB, ...
            row.PhaseAt1kHz_deg];

        row.SimulationValid = ...
            row.DCSuccess && row.ACSuccess && ...
            all(isfinite(requiredMetrics));

        % This is a heuristic screening label, not a guarantee of
        % real-device performance or a complete amplifier specification.
        row.AmplifierCandidate = false;
            

    catch ME

        row.ErrorMessage = appendError( ...
            row.ErrorMessage, string(ME.message));

        if row.DCSuccess && row.ACStatus == "NOT_RUN"
            row.ACStatus = "FAILED";
        end

        % Failed or incomplete rows remain in the dataset.
    end

    % Retain every attempted configuration.
    rows = appendRow(rows, row);

    fprintf('DC: %s | AC: %s | Bias: %s | Valid: %d | Candidate: %d\n', ...
        string(row.DCStatus), ...
        string(row.ACStatus), ...
        string(row.BiasRegion), ...
        row.SimulationValid, ...
        row.AmplifierCandidate);

end

%% 13. Save the new dataset and metadata

csvPath = fullfile(outputDir, 'CS_Dataset_v2_100.csv');
matPath = fullfile(outputDir, 'CS_Dataset_v2_100.mat');

writetable(rows, csvPath);

config = struct();

config.DatasetName = "Common-Source Dataset v2";
config.ConfigurationCount = N;
config.RandomSeed = 42;
config.Simulator = "ngspice";
config.ModelName = "2N7000";
config.ModelType = "External SPICE subcircuit";
config.ModelPath = modelPath;
config.ModelSource = "2N7000.onsemi.lib";

config.ComponentCandidates = struct( ...
    'RGU_Ohm', RGU_values, ...
    'RGL_Ohm', RGL_values, ...
    'RD_Ohm', RD_values, ...
    'RS_Ohm', RS_values, ...
    'CIN_F', CIN_values);

config.VDD_V = VDD;
config.VTO_V = VTO;

config.ACStart_Hz = optionsAC.ACStart;
config.ACStop_Hz = optionsAC.ACStop;
config.PointsPerDecade = optionsAC.PointsPerDecade;
config.ReferenceFrequency_Hz = referenceFrequency_Hz;

config.BiasRegionMethod = ...
     "Unclassified; external model operating region not yet verified";
config.AmplifierCandidateRule = ...
    "SimulationValid AND heuristic SATURATION AND PeakGain_dB > 0";

config.GeneratedAt = datetime("now");

save(matPath, "rows", "config", "acResponses", "-v7.3");

%% 14. Print summary

fprintf('\n========================================\n');
fprintf('COMMON-SOURCE DATASET V2 SUMMARY\n');
fprintf('========================================\n');

fprintf('Configurations attempted: %d\n', height(rows));
fprintf('Unique configurations selected: %d\n', ...
    size(unique(sampledCombos, 'rows'), 1));

fprintf('DC successful: %d / %d\n', ...
    sum(rows.DCSuccess), height(rows));

fprintf('AC successful: %d / %d\n', ...
    sum(rows.ACSuccess), height(rows));

fprintf('Simulation-valid: %d\n', sum(rows.SimulationValid));
fprintf('Amplifier candidates: %d\n', sum(rows.AmplifierCandidate));

validGain = rows.SimulationValid & isfinite(rows.PeakGain_dB);

if any(validGain)
    fprintf('Median peak gain: %.3f dB\n', ...
        median(rows.PeakGain_dB(validGain)));

    fprintf('Minimum peak gain: %.3f dB\n', ...
        min(rows.PeakGain_dB(validGain)));

    fprintf('Maximum peak gain: %.3f dB\n', ...
        max(rows.PeakGain_dB(validGain)));

    fprintf('Median gain at 1 kHz: %.3f dB\n', ...
        median(rows.GainAt1kHz_dB(validGain)));
end

fprintf('\nCSV saved to:\n%s\n', csvPath);
fprintf('\nMAT saved to:\n%s\n', matPath);

fprintf('\nStatus and bias distribution:\n');

disp(groupsummary(rows, ...
    {'DCStatus', 'ACStatus', 'BiasRegion'}));

%% 15. Local helper functions

function value = getNodeVoltage(result, nodeName)

    names = lower(strtrim(string(result.NodeNames)));

    idx = find(names == lower(string(nodeName)), 1);

    if isempty(idx)
        error("Node voltage not found: %s", nodeName);
    end

    value = result.NodeVoltages(idx);

    if ~isscalar(value) || ~isfinite(value)
        error("Invalid node voltage returned for %s.", nodeName);
    end

end

function rows = appendRow(rows, row)

    if isempty(rows)
        rows = row;
    else
        rows = [rows; row];
    end

end

function out = appendError(existing, newError)

    existing = string(existing);
    newError = string(newError);

    if strlength(existing) == 0
        out = newError;
    elseif strlength(newError) == 0
        out = existing;
    else
        out = existing + " | " + newError;
    end

end

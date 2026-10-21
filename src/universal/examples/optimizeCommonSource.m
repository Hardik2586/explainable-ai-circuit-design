
%% Common-Source Amplifier Optimizer
% ML-ranked candidates + ngspice verification
% Existing datasets, model, and CE-XAI Lab are not modified.

clear; clc;

projectRoot = 'C:\Internship Project';

modelFile = fullfile(projectRoot, 'models', 'Common_Source', ...
    '20261013_022802', 'CommonSourceModel.mat');

assert(isfile(modelFile), 'Trained model not found: %s', modelFile);

S = load(modelFile);

assert(isfield(S, 'selectedModel') && ...
       isfield(S, 'modelInfo') && ...
       isfield(S, 'featureColumns'), ...
       'Required fields are missing from the saved model.');

model = S.selectedModel;
modelName = string(S.modelInfo.SelectedModelName);
featureColumns = string(S.featureColumns(:))';

%% 1. User-defined target gain

targetGain_dB = input('Enter target peak gain in dB: ');

if ~isnumeric(targetGain_dB) || ...
        ~isscalar(targetGain_dB) || ~isfinite(targetGain_dB)
    error('Target gain must be a finite numeric scalar.');
end

%% 2. Search space

RGU_values = [82e3, 100e3, 120e3];
RGL_values = [56e3, 68e3, 75e3, 82e3, 100e3];
RD_values  = [1.8e3, 2.2e3, 2.7e3];
RS_values  = [820, 1e3, 1.2e3];
CIN_values = [4.7e-6, 10e-6, 22e-6];
VDD_values = [9, 12, 15];

[RGU, RGL, RD, RS, CIN, VDD] = ndgrid( ...
    RGU_values, RGL_values, RD_values, RS_values, ...
    CIN_values, VDD_values);

Candidates = table( ...
    RGU(:), RGL(:), RD(:), RS(:), CIN(:), VDD(:), ...
    'VariableNames', ...
    {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V'});

%% 3. ML ranking

missingFeatures = setdiff(featureColumns, ...
    string(Candidates.Properties.VariableNames));

if ~isempty(missingFeatures)
    error('Missing model features: %s', ...
        strjoin(missingFeatures, ', '));
end

X = Candidates{:, cellstr(featureColumns)};

% Standardize only when the selected model is RidgeLinear.
% The BoostedTrees model uses unscaled input features.
if modelName == "RidgeLinear"

    if ~isfield(S, 'muX') || ~isfield(S, 'sigmaX')
        error('RidgeLinear requires muX and sigmaX in the model file.');
    end

    sigma = S.sigmaX;
    sigma(sigma == 0 | ~isfinite(sigma)) = 1;

    X = (X - S.muX) ./ sigma;
end

Candidates.ML_PredictedGain_dB = predict(model, X);
Candidates.ML_AbsoluteError_dB = ...
    abs(Candidates.ML_PredictedGain_dB - targetGain_dB);

% Shortlist the eight best predictions at each supply voltage.
% Final ranking will use ngspice results, not ML predictions.

shortlistPerSupply = 8;
shortlist = table();

for v = VDD_values

    idx = find(Candidates.VDD_V == v);

    group = sortrows(Candidates(idx, :), ...
        'ML_AbsoluteError_dB', 'ascend');

    shortlist = [shortlist; ...
        group(1:min(shortlistPerSupply, height(group)), :)]; %#ok<AGROW>
end

fprintf('\nTotal candidates: %d\n', height(Candidates));
fprintf('Candidates shortlisted for SPICE: %d\n', height(shortlist));
fprintf('Target peak gain: %.3f dB\n', targetGain_dB);
fprintf('ML model: %s\n', modelName);

% Note: the ML model was trained with VDD fixed at 12 V.
% Predictions at 9 V and 15 V are extrapolations.

%% 4. Initialize ngspice model manager

% Approximate Level-1 model for workflow testing only.
% Replace with a validated device model before physical design use.

modelManager = ModelManager();

modelManager = modelManager.registerInlineModel( ...
    "2N7000", "MOSFET", ...
    ".model 2N7000 NMOS (LEVEL=1 VTO=2 KP=0.05 LAMBDA=0.02)");

%% 5. Prepare verification results

n = height(shortlist);

shortlist.SPICE_Success = false(n,1);
shortlist.SPICE_PeakGain_dB = nan(n,1);
shortlist.SPICE_PeakGainFrequency_Hz = nan(n,1);
shortlist.SPICE_VGate_V = nan(n,1);
shortlist.SPICE_VSource_V = nan(n,1);
shortlist.SPICE_VDrain_V = nan(n,1);
shortlist.SPICE_VGS_V = nan(n,1);
shortlist.SPICE_VDS_V = nan(n,1);
shortlist.SPICE_GainError_dB = nan(n,1);
shortlist.SPICE_ErrorMessage = strings(n,1);

%% 6. Verify candidates using ngspice

for k = 1:n

    c = shortlist(k,:);

    fprintf('\nVerifying candidate %d/%d...\n', k, n);

    try

        %% Build circuit

        circuit = createCircuit("CS_Optimizer_Candidate");
        circuit.Metadata.Topology = "Common_Source";

        circuit = circuitAddComponent(circuit, "VDD", ...
            "VOLTAGE_SOURCE", ["VDD","GND"], c.VDD_V);

        circuit = circuitAddComponent(circuit, "VIN", ...
            "VOLTAGE_SOURCE", ["IN","GND"], 0);

        % Configure VIN with DC=0 V and AC=1 V.
        % Component is a value object, so assign it back after editing.

        componentNames = string({circuit.Components.Name});
        idxVIN = find(componentNames == "VIN", 1);

        if isempty(idxVIN)
            error('VIN component was not found.');
        end

        vin = circuit.Components(idxVIN);
        vin = vin.setParameter("DC", 0);
        vin = vin.setParameter("AC", 1);
        vin = vin.setParameter("ACPhase", 0);

        circuit.Components(idxVIN) = vin;

        %% Add bias and amplifier components

        circuit = circuitAddComponent(circuit, "RGU", ...
            "R", ["VDD","GATE"], c.RGU_Ohm);

        circuit = circuitAddComponent(circuit, "RGL", ...
            "R", ["GATE","GND"], c.RGL_Ohm);

        circuit = circuitAddComponent(circuit, "RD", ...
            "R", ["VDD","DRAIN"], c.RD_Ohm);

        circuit = circuitAddComponent(circuit, "RS", ...
            "R", ["SOURCE","GND"], c.RS_Ohm);

        circuit = circuitAddComponent(circuit, "CIN", ...
            "C", ["IN","GATE"], c.CIN_F);

        circuit = circuitAddComponent(circuit, "M1", ...
            "MOSFET", ["DRAIN","GATE","SOURCE"], [], "2N7000");

        %% DC operating point

        optionsDC = struct();
        optionsDC.Analysis = "DC";
        optionsDC.KeepFiles = true;

        dc = runUniversalSpice(circuit, modelManager, optionsDC);

        if ~dc.Success
            error('DC simulation failed: %s', ...
                char(string(dc.ErrorMessage)));
        end

        % Extract node voltages from SimulationResult.
        % Do not use the nonexistent getNodeVoltage function.

        nodeNames = lower(strtrim(string(dc.NodeNames(:))));
        nodeVoltages = double(dc.NodeVoltages(:));

        if numel(nodeNames) ~= numel(nodeVoltages)
            error('DC node names and voltages have different lengths.');
        end

        vg = getNodeVoltageLocal( ...
            nodeNames, nodeVoltages, "gate");

        vs = getNodeVoltageLocal( ...
            nodeNames, nodeVoltages, "source");

        vd = getNodeVoltageLocal( ...
            nodeNames, nodeVoltages, "drain");

        %% AC analysis

        optionsAC = struct();
        optionsAC.Analysis = "AC";
        optionsAC.ACStart = 10;
        optionsAC.ACStop = 1e6;
        optionsAC.PointsPerDecade = 50;
        optionsAC.KeepFiles = true;

        optionsAC.PrintExpressions = [
            "vm(IN)"
            "vp(IN)"
            "vm(DRAIN)"
            "vp(DRAIN)"
        ];

        ac = runUniversalSpice(circuit, modelManager, optionsAC);

        if ~ac.Success
            error('AC simulation failed: %s', ...
                char(string(ac.ErrorMessage)));
        end

        if ~isfield(ac.ACSignals, 'in') || ...
                ~isfield(ac.ACSignals, 'drain')
            error('AC output is missing IN or DRAIN signals.');
        end

        inputMagnitude = ac.ACSignals.in.Magnitude(:);
        drainMagnitude = ac.ACSignals.drain.Magnitude(:);

        frequency = ac.ACSignals.in.Frequency(:);
        drainFrequency = ac.ACSignals.drain.Frequency(:);

        if isempty(frequency) || ...
                numel(frequency) ~= numel(inputMagnitude) || ...
                numel(frequency) ~= numel(drainMagnitude) || ...
                numel(frequency) ~= numel(drainFrequency)

            error('AC signal arrays are empty or have mismatched lengths.');
        end

        if any(abs(frequency - drainFrequency) > ...
                max(1e-9, 1e-9 .* abs(frequency)))

            error('IN and DRAIN AC frequency grids do not match.');
        end

        if any(~isfinite(inputMagnitude)) || ...
                any(inputMagnitude <= 0)

            error('Input AC magnitude contains invalid or zero values.');
        end

        %% Calculate voltage gain

        gain = drainMagnitude ./ inputMagnitude;

        gain_dB = 20 .* log10(max(gain, realmin));

        good = isfinite(gain_dB) & ...
               isfinite(frequency) & frequency > 0;

        if ~any(good)
            error('No valid AC gain points were returned.');
        end

        validGain = gain_dB(good);
        validFrequency = frequency(good);

        [peakGain, peakIdx] = max(validGain);

        %% Store successful results

        shortlist.SPICE_Success(k) = true;

        shortlist.SPICE_PeakGain_dB(k) = peakGain;
        shortlist.SPICE_PeakGainFrequency_Hz(k) = ...
            validFrequency(peakIdx);

        shortlist.SPICE_VGate_V(k) = vg;
        shortlist.SPICE_VSource_V(k) = vs;
        shortlist.SPICE_VDrain_V(k) = vd;

        shortlist.SPICE_VGS_V(k) = vg - vs;
        shortlist.SPICE_VDS_V(k) = vd - vs;

        shortlist.SPICE_GainError_dB(k) = ...
            abs(peakGain - targetGain_dB);

        fprintf('ML predicted gain: %.3f dB\n', ...
            c.ML_PredictedGain_dB);

        fprintf('SPICE peak gain: %.3f dB\n', peakGain);

        fprintf('Absolute target error: %.3f dB\n', ...
            shortlist.SPICE_GainError_dB(k));

    catch ME

        shortlist.SPICE_Success(k) = false;
        shortlist.SPICE_ErrorMessage(k) = string(ME.message);

        fprintf('Candidate failed: %s\n', ME.message);

    end
end

%% 7. Rank successful candidates by actual SPICE error

verified = shortlist(shortlist.SPICE_Success, :);

if ~isempty(verified)

    verified = sortrows(verified, ...
        'SPICE_GainError_dB', 'ascend');

    fprintf('\n========== VERIFIED RECOMMENDATIONS ==========\n');

    disp(verified(:, { ...
        'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V', ...
        'ML_PredictedGain_dB','SPICE_PeakGain_dB', ...
        'SPICE_GainError_dB','SPICE_PeakGainFrequency_Hz', ...
        'SPICE_VGS_V','SPICE_VDS_V'}));

else

    warning(['No candidates were successfully verified. ' ...
        'Inspect SPICE_ErrorMessage in the saved CSV.']);

end

%% 8. Save results without overwriting previous runs

timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

outputFolder = fullfile(projectRoot, 'results', ...
    'Optimization', 'Common_Source', timestamp);

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

writetable(Candidates, fullfile(outputFolder, ...
    'all_ml_ranked_candidates.csv'));

writetable(shortlist, fullfile(outputFolder, ...
    'ngspice_verification_results.csv'));

if ~isempty(verified)

    writetable(verified, fullfile(outputFolder, ...
        'verified_recommendations.csv'));

end

save(fullfile(outputFolder, 'OptimizerResults.mat'), ...
    'Candidates', 'shortlist', 'verified', ...
    'targetGain_dB', 'modelName', 'VDD_values', 'modelFile');

fprintf('\nOptimization complete.\n');
fprintf('Results folder:\n%s\n', outputFolder);

fprintf('Successful SPICE verifications: %d/%d\n', ...
    nnz(shortlist.SPICE_Success), height(shortlist));

%% Local helper: case-insensitive DC node lookup

function voltage = getNodeVoltageLocal( ...
        nodeNames, nodeVoltages, targetNode)

    idx = find(nodeNames == lower(string(targetNode)), 1);

    if isempty(idx)
        error('Node "%s" was not found in SimulationResult.NodeNames.', ...
            char(targetNode));
    end

    voltage = nodeVoltages(idx);

    if ~isfinite(voltage)
        error('Node "%s" has an invalid voltage.', char(targetNode));
    end
end

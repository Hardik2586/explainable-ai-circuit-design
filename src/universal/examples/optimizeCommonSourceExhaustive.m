clear; clc;

projectRoot = 'C:\Internship Project';

%% 1. User target

targetGain_dB = input('Enter target peak gain in dB: ');

if ~isnumeric(targetGain_dB) || ...
        ~isscalar(targetGain_dB) || ~isfinite(targetGain_dB)
    error('Target gain must be a finite numeric scalar.');
end

%% 2. Define search space

RGU_values = [82e3, 100e3, 120e3];
RGL_values = [56e3, 68e3, 75e3, 82e3, 100e3];
RD_values  = [1.8e3, 2.2e3, 2.7e3];
RS_values  = [820, 1e3, 1.2e3];
CIN_values = [4.7e-6, 10e-6, 22e-6];
VDD_values = [9, 12, 15];

[RGU, RGL, RD, RS, CIN, VDD] = ndgrid( ...
    RGU_values, RGL_values, RD_values, ...
    RS_values, CIN_values, VDD_values);

Candidates = table( ...
    RGU(:), RGL(:), RD(:), RS(:), CIN(:), VDD(:), ...
    'VariableNames', ...
    {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V'});

n = height(Candidates);

fprintf('\n============================================\n');
fprintf('EXHAUSTIVE COMMON-SOURCE OPTIMIZATION\n');
fprintf('============================================\n');
fprintf('Total candidate circuits: %d\n', n);
fprintf('Target peak gain: %.3f dB\n', targetGain_dB);

%% 3. Initialize approximate MOSFET model

% Same simplified model used in the existing workflow.
% Results are simulation-based estimates, not validated hardware results.

modelManager = ModelManager();

modelManager = modelManager.registerInlineModel( ...
    "2N7000", "MOSFET", ...
    ".model 2N7000 NMOS (LEVEL=1 VTO=2 KP=0.05 LAMBDA=0.02)");

%% 4. Initialize result columns

Candidates.DCSuccess = false(n,1);
Candidates.ACSuccess = false(n,1);
Candidates.SimulationValid = false(n,1);

Candidates.VGate_V = nan(n,1);
Candidates.VSource_V = nan(n,1);
Candidates.VDrain_V = nan(n,1);

Candidates.VGS_V = nan(n,1);
Candidates.VDS_V = nan(n,1);
Candidates.ID_A = nan(n,1);

Candidates.PeakGain_VV = nan(n,1);
Candidates.PeakGain_dB = nan(n,1);
Candidates.PeakGainFrequency_Hz = nan(n,1);

Candidates.GainAt1kHz_dB = nan(n,1);
Candidates.TargetError_dB = nan(n,1);

Candidates.ErrorMessage = strings(n,1);

%% 5. Simulate every candidate

for k = 1:n

    c = Candidates(k,:);

    if mod(k,25) == 1 || k == n
        fprintf('\nProgress: %d/%d candidates (%.1f%%)\n', ...
            k, n, 100*k/n);
    end

    try

        %% Build circuit

        circuit = createCircuit("CS_Exhaustive_Candidate");
        circuit.Metadata.Topology = "Common_Source";

        circuit = circuitAddComponent(circuit, "VDD", ...
            "VOLTAGE_SOURCE", ["VDD","GND"], c.VDD_V);

        circuit = circuitAddComponent(circuit, "VIN", ...
            "VOLTAGE_SOURCE", ["IN","GND"], 0);

        % Configure AC input magnitude to 1 V.

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
        optionsDC.KeepFiles = false;

        dc = runUniversalSpice(circuit, modelManager, optionsDC);

        if ~dc.Success
            error('DC simulation failed: %s', ...
                char(string(dc.ErrorMessage)));
        end

        Candidates.DCSuccess(k) = true;

        nodeNames = lower(strtrim(string(dc.NodeNames(:))));
        nodeVoltages = double(dc.NodeVoltages(:));

        if numel(nodeNames) ~= numel(nodeVoltages)
            error('DC node names and voltages have different lengths.');
        end

        vg = getNodeVoltageLocal(nodeNames,nodeVoltages,"gate");
        vs = getNodeVoltageLocal(nodeNames,nodeVoltages,"source");
        vd = getNodeVoltageLocal(nodeNames,nodeVoltages,"drain");

        Candidates.VGate_V(k) = vg;
        Candidates.VSource_V(k) = vs;
        Candidates.VDrain_V(k) = vd;

        Candidates.VGS_V(k) = vg - vs;
        Candidates.VDS_V(k) = vd - vs;

        % Estimate drain current from the source resistor.
        Candidates.ID_A(k) = vs / c.RS_Ohm;

        %% AC analysis

        optionsAC = struct();
        optionsAC.Analysis = "AC";
        optionsAC.ACStart = 10;
        optionsAC.ACStop = 1e6;
        optionsAC.PointsPerDecade = 50;
        optionsAC.KeepFiles = false;

        optionsAC.PrintExpressions = ...
            "vm(IN), vp(IN), vm(DRAIN), vp(DRAIN)";

        ac = runUniversalSpice(circuit, modelManager, optionsAC);

        if ~ac.Success
            error('AC simulation failed: %s', ...
                char(string(ac.ErrorMessage)));
        end

        Candidates.ACSuccess(k) = true;

        if ~isfield(ac.ACSignals,'in') || ...
                ~isfield(ac.ACSignals,'drain')
            error('AC results are missing IN or DRAIN signals.');
        end

        inputMag = ac.ACSignals.in.Magnitude(:);
        drainMag = ac.ACSignals.drain.Magnitude(:);
        frequency = ac.ACSignals.in.Frequency(:);
        drainFrequency = ac.ACSignals.drain.Frequency(:);

        if isempty(frequency) || ...
                numel(frequency) ~= numel(inputMag) || ...
                numel(frequency) ~= numel(drainMag) || ...
                numel(frequency) ~= numel(drainFrequency)
            error('AC output arrays are empty or mismatched.');
        end

        if any(abs(frequency-drainFrequency) > ...
                max(1e-9,1e-9.*abs(frequency)))
            error('Input and output frequency grids do not match.');
        end

        if any(~isfinite(inputMag)) || any(inputMag <= 0)
            error('Input AC magnitude contains invalid values.');
        end

        %% Calculate gain

        gainVV = drainMag ./ inputMag;
        gainDB = 20 .* log10(max(gainVV,realmin));

        valid = isfinite(gainDB) & ...
                isfinite(frequency) & frequency > 0;

        if ~any(valid)
            error('No valid AC gain points returned.');
        end

        validFrequency = frequency(valid);
        validGainDB = gainDB(valid);
        validGainVV = gainVV(valid);

        [peakGainDB, peakIdx] = max(validGainDB);

        Candidates.PeakGain_dB(k) = peakGainDB;
        Candidates.PeakGain_VV(k) = validGainVV(peakIdx);
        Candidates.PeakGainFrequency_Hz(k) = ...
            validFrequency(peakIdx);

        % Interpolate gain at 1 kHz in log-frequency space.
        if 1000 >= min(validFrequency) && ...
                1000 <= max(validFrequency)

            gainAt1k = interp1( ...
                log10(validFrequency), validGainDB, ...
                log10(1000), 'linear');

            Candidates.GainAt1kHz_dB(k) = gainAt1k;
        end

        Candidates.TargetError_dB(k) = ...
            abs(peakGainDB - targetGain_dB);

        Candidates.SimulationValid(k) = true;

    catch ME

        Candidates.ErrorMessage(k) = string(ME.message);

        % Keep failed rows for auditability and debugging.
        fprintf('Candidate %d failed: %s\n', k, ME.message);

    end
end

%% 6. Rank successful simulations

validResults = Candidates(Candidates.SimulationValid,:);

if isempty(validResults)
    error(['No valid candidate simulations. Inspect ErrorMessage ' ...
        'and check ngspice configuration.']);
end

validResults = sortrows(validResults,'TargetError_dB','ascend');

fprintf('\n============================================\n');
fprintf('EXHAUSTIVE OPTIMIZATION SUMMARY\n');
fprintf('============================================\n');

fprintf('Total candidates: %d\n',n);
fprintf('DC successful: %d\n',nnz(Candidates.DCSuccess));
fprintf('AC successful: %d\n',nnz(Candidates.ACSuccess));
fprintf('Fully valid: %d\n',nnz(Candidates.SimulationValid));
fprintf('Failed/invalid: %d\n',nnz(~Candidates.SimulationValid));

fprintf('\nBest simulated candidate:\n');

disp(validResults(1:min(10,height(validResults)), { ...
    'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V', ...
    'PeakGain_dB','TargetError_dB','PeakGainFrequency_Hz', ...
    'VGS_V','VDS_V'}));

%% 7. Compare with the previous 24-candidate optimizer run

previousFolder = fullfile(projectRoot, ...
    'results','Optimization','Common_Source');

previousFiles = dir(fullfile(previousFolder, ...
    '**','ngspice_verification_results.csv'));

% Exclude the current output location by creating it only after this step.
% The existing shortlist CSV should contain SPICE_Success and
% SPICE_GainError_dB columns.

previousBestGain = NaN;
previousBestError = NaN;
previousBestFile = "";

if ~isempty(previousFiles)

    [~, newestIdx] = max([previousFiles.datenum]);
    previousFile = fullfile( ...
        previousFiles(newestIdx).folder, ...
        previousFiles(newestIdx).name);

    try
        previousTable = readtable(previousFile);

        if all(ismember( ...
                {'SPICE_Success','SPICE_PeakGain_dB', ...
                 'SPICE_GainError_dB'}, ...
                 previousTable.Properties.VariableNames))

            previousTable = previousTable(previousTable.SPICE_Success,:);

            if ~isempty(previousTable)
                [previousBestError, bestIdx] = ...
                    min(previousTable.SPICE_GainError_dB);

                previousBestGain = ...
                    previousTable.SPICE_PeakGain_dB(bestIdx);

                previousBestFile = string(previousFile);
            end
        end

    catch ME
        warning('Could not read previous shortlist: %s', ME.message);
    end
end

fprintf('\n============================================\n');
fprintf('ML SHORTLIST VS EXHAUSTIVE SEARCH\n');
fprintf('============================================\n');

fprintf('Best exhaustive gain: %.4f dB\n', ...
    validResults.PeakGain_dB(1));

fprintf('Best exhaustive target error: %.4f dB\n', ...
    validResults.TargetError_dB(1));

if isfinite(previousBestError)

    fprintf('Best previous shortlist gain: %.4f dB\n', ...
        previousBestGain);

    fprintf('Best previous shortlist error: %.4f dB\n', ...
        previousBestError);

    fprintf('Previous shortlist file: %s\n', previousBestFile);

    fprintf('Improvement in absolute target error: %.4f dB\n', ...
        previousBestError - validResults.TargetError_dB(1));

else
    fprintf(['Previous shortlist could not be loaded automatically. ' ...
        'Compare with your saved ngspice_verification_results.csv.\n']);
end

%% 8. Save results in a new timestamped folder

timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outputFolder = fullfile(projectRoot, ...
    'results','Optimization','Common_Source_Exhaustive',timestamp);

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

writetable(Candidates,fullfile(outputFolder, ...
    'all_1215_candidate_results.csv'));

writetable(validResults,fullfile(outputFolder, ...
    'valid_candidates_ranked.csv'));

writetable(validResults(1:min(10,height(validResults)),:), ...
    fullfile(outputFolder,'top_10_candidates.csv'));

summary = table( ...
    n, nnz(Candidates.DCSuccess), ...
    nnz(Candidates.ACSuccess), ...
    nnz(Candidates.SimulationValid), ...
    nnz(~Candidates.SimulationValid), ...
    validResults.PeakGain_dB(1), ...
    validResults.TargetError_dB(1), ...
    'VariableNames', ...
    {'TotalCandidates','DCSuccess','ACSuccess', ...
     'SimulationValid','Failed','BestPeakGain_dB', ...
     'BestTargetError_dB'});

writetable(summary,fullfile(outputFolder,'run_summary.csv'));

save(fullfile(outputFolder,'ExhaustiveOptimization.mat'), ...
    'Candidates','validResults','summary', ...
    'targetGain_dB','RGU_values','RGL_values', ...
    'RD_values','RS_values','CIN_values','VDD_values');

fprintf('\n============================================\n');
fprintf('EXHAUSTIVE RUN COMPLETE\n');
fprintf('Results saved to:\n%s\n',outputFolder);
fprintf('============================================\n');

%% Local helper: retrieve DC node voltage

function voltage = getNodeVoltageLocal(nodeNames,nodeVoltages,targetNode)

    idx = find(nodeNames == lower(string(targetNode)),1);

    if isempty(idx)
        error('Node "%s" not found in SimulationResult.', ...
            char(targetNode));
    end

    voltage = nodeVoltages(idx);

    if ~isfinite(voltage)
        error('Node "%s" has an invalid voltage.', ...
            char(targetNode));
    end
end

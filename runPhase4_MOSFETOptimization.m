
clear; clc; close all;
rng(42,'twister');

%% PHASE 4: MOSFET OPTIMIZATION + NGSPICE

root = 'C:\Internship Project';

modelFile = fullfile(root,'models','Common_Source', ...
    'Phase2_MOSFET','MOSFET_GainModel_Phase2.mat');

dataFile = fullfile(root,'data','universal','Common_Source', ...
    'training_ready','MOSFET_TrainingReady_GainAt1kHz.csv');

spiceModel = fullfile(root,'models','mosfet','2N7000.onsemi.lib');

ngspiceExe = fullfile(root,'models','mosfet','ngspice-47_64', ...
    'Spice64','bin','ngspice.exe');

outDir = fullfile(root,'results','Phase4_MOSFET_Optimization');

VDD_VALUE = 12;
N_CANDIDATES = 250;
N_TO_VERIFY = 25;
TARGET_FREQ_HZ = 1000;

features = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F'};

assert(isfile(modelFile),'ML model not found: %s',modelFile);
assert(isfile(dataFile),'Training dataset not found: %s',dataFile);
assert(isfile(spiceModel),'MOSFET library not found: %s',spiceModel);
assert(isfile(ngspiceExe),'ngspice not found: %s',ngspiceExe);

if ~isfolder(outDir)
    mkdir(outDir);
end

fprintf('\n============================================\n');
fprintf(' PHASE 4 - MOSFET OPTIMIZATION + NGSPICE\n');
fprintf('============================================\n');

%% 1. Inspect the MOSFET subcircuit

libText = fileread(spiceModel);

subcktMatch = regexp(libText, ...
    '(?im)^\s*\.subckt\s+2N7000(?:\s+[^\r\n]*)?', ...
    'match','once');

if isempty(subcktMatch)
    error('No .SUBCKT 2N7000 declaration found.');
end

fprintf('Model declaration: %s\n',strtrim(subcktMatch));
fprintf(['IMPORTANT: Verify the subcircuit terminal order against ' ...
    'the vendor documentation before interpreting results.\n']);

%% 2. Load the Phase 2 model bundle

S = load(modelFile);

if isfield(S,'bundle')
    bundle = S.bundle;
else
    names = fieldnames(S);
    bundle = [];

    for k = 1:numel(names)
        candidateBundle = S.(names{k});

        if isstruct(candidateBundle) && ...
                isfield(candidateBundle,'Model')
            bundle = candidateBundle;
            break;
        end
    end

    if isempty(bundle)
        error('Could not find the saved Phase 2 model bundle.');
    end
end

if ~isfield(bundle,'Model') || ~isfield(bundle,'ModelName')
    error('Model bundle must contain Model and ModelName.');
end

mlModel = bundle.Model;
modelName = string(bundle.ModelName);

fprintf('Loaded ML model: %s\n',modelName);

%% 3. Read development data and derive search bounds

T = readtable(dataFile);

for k = 1:numel(features)
    if ~ismember(features{k},T.Properties.VariableNames)
        error('Missing feature column: %s',features{k});
    end
end

Xdata = T{:,features};
validRows = all(isfinite(Xdata),2) & all(Xdata > 0,2);
Xdata = Xdata(validRows,:);

if size(Xdata,1) < 10
    error('Insufficient valid training-data rows.');
end

lowerBound = min(Xdata,[],1);
upperBound = max(Xdata,[],1);

fprintf('\nSearch bounds:\n');

for k = 1:numel(features)
    fprintf('  %-12s %.6g to %.6g\n', ...
        features{k},lowerBound(k),upperBound(k));
end

%% 4. Generate candidate circuits

Xcand = zeros(N_CANDIDATES,numel(features));

for j = 1:numel(features)
    if upperBound(j) > lowerBound(j)
        Xcand(:,j) = exp( ...
            log(lowerBound(j)) + rand(N_CANDIDATES,1) .* ...
            (log(upperBound(j))-log(lowerBound(j))));
    else
        Xcand(:,j) = lowerBound(j);
    end
end

% Include a representative development-data configuration.
Xcand(1,:) = median(Xdata,1);

%% 5. Rank candidates using the ML model

predictedGain = phase4Predict(mlModel,bundle,modelName,Xcand);

validPred = isfinite(predictedGain);
Xcand = Xcand(validPred,:);
predictedGain = predictedGain(validPred);

if isempty(predictedGain)
    error('The ML model returned no finite predictions.');
end

[~,rankOrder] = sort(predictedGain,'descend');

Xcand = Xcand(rankOrder,:);
predictedGain = predictedGain(rankOrder);

nVerify = min(N_TO_VERIFY,size(Xcand,1));

Xverify = Xcand(1:nVerify,:);
predVerify = predictedGain(1:nVerify);

fprintf('\nGenerated candidates: %d\n',N_CANDIDATES);
fprintf('Finite predictions: %d\n',numel(predictedGain));
fprintf('Candidates selected for SPICE: %d\n',nVerify);

%% 6. Initialize result arrays

Candidate = (1:nVerify)';

RGU_Ohm = Xverify(:,1);
RGL_Ohm = Xverify(:,2);
RD_Ohm = Xverify(:,3);
RS_Ohm = Xverify(:,4);
CIN_F = Xverify(:,5);

MLPredictedGain_dB = predVerify;

SpiceGain_dB = nan(nVerify,1);

VDD_V = nan(nVerify,1);
VGate_V = nan(nVerify,1);
VDrain_V = nan(nVerify,1);
VSource_V = nan(nVerify,1);

VGS_V = nan(nVerify,1);
VDS_V = nan(nVerify,1);
DrainCurrent_A = nan(nVerify,1);

SpiceStatus = strings(nVerify,1);
VerificationStatus = strings(nVerify,1);
SpiceLogPath = strings(nVerify,1);

%% 7. Simulate each candidate using ngspice

for i = 1:nVerify

    fprintf('\n--------------------------------------------\n');
    fprintf('Candidate %d of %d\n',i,nVerify);

    candidateDir = fullfile(outDir,sprintf('candidate_%03d',i));

    if ~isfolder(candidateDir)
        mkdir(candidateDir);
    end

    candidateModel = fullfile(candidateDir,'2N7000.onsemi.lib');
    netlistFile = fullfile(candidateDir,'candidate.cir');
    logFile = fullfile(candidateDir,'ngspice.log');

    SpiceLogPath(i) = string(logFile);

    % Remove stale output before running this candidate.
    if isfile(logFile)
        delete(logFile);
    end

    debugLog = fullfile(candidateDir,'ngspice_debug.log');

    if isfile(debugLog)
        delete(debugLog);
    end

    [copyOK,copyMessage] = copyfile(spiceModel,candidateModel);

    if ~copyOK
        SpiceStatus(i) = "MODEL_COPY_FAILED";
        VerificationStatus(i) = "REJECT";
        fprintf('Model copy failed: %s\n',copyMessage);
        continue;
    end

    try
        writeCandidateNetlist(netlistFile,VDD_VALUE, ...
            '2N7000',Xverify(i,:),TARGET_FREQ_HZ);
    catch ME
        SpiceStatus(i) = "NETLIST_WRITE_FAILED";
        VerificationStatus(i) = "REJECT";
        fprintf('Netlist creation failed: %s\n',ME.message);
        continue;
    end

    % Execute from the candidate directory so the relative
    % .include "2N7000.onsemi.lib" resolves correctly.
    command = sprintf( ...
        'cd /d "%s" && "%s" -b -o ngspice.log candidate.cir', ...
        candidateDir,ngspiceExe);

    [exitStatus,consoleOutput] = system(command);

    if ~isfile(logFile)
        SpiceStatus(i) = "LOG_CREATION_FAILED";
        VerificationStatus(i) = "REVIEW";

        fprintf('No ngspice log was created.\n');
        fprintf('%s\n',consoleOutput);
        continue;
    end

    logText = fileread(logFile);

    % Keep a separate debug copy for troubleshooting.
    fidDebug = fopen(debugLog,'w');

    if fidDebug >= 0
        fprintf(fidDebug,'%s\n',consoleOutput);
        fprintf(fidDebug,'\n--- NGSPICE LOG ---\n%s\n',logText);
        fclose(fidDebug);
    end

    logLower = lower(logText);

    errorPatterns = {
        'fatal error'
        'error:'
        'unknown subckt'
        'no such parameter'
        'unknown parameter'
        'singular matrix'
        'cannot open'
        'incomplete or empty netlist'
        'no simulations run'
    };

    hasSpiceError = false;

    for p = 1:numel(errorPatterns)
        if contains(logLower,errorPatterns{p})
            hasSpiceError = true;
            fprintf('ngspice reported: %s\n',errorPatterns{p});
            break;
        end
    end

    if exitStatus ~= 0 || hasSpiceError
        SpiceStatus(i) = "NGSPICE_OR_MODEL_ERROR";
        VerificationStatus(i) = "REJECT";
        fprintf('Simulation failed. Inspect:\n%s\n',logFile);
        continue;
    end

    %% Parse the scalar values printed by the .control block.

    vdd = parseMarkedValue(logText,'v(vdd)');
    vg  = parseMarkedValue(logText,'v(gate)');
    vd  = parseMarkedValue(logText,'v(drain)');
    vs  = parseMarkedValue(logText,'v(source)');
    gain = parseMarkedValue(logText,'ph4gain');

    parsed = all(isfinite([vdd,vg,vd,vs,gain]));

    if ~parsed
        SpiceStatus(i) = "OUTPUT_PARSE_FAILED";
        VerificationStatus(i) = "REVIEW";

        fprintf('Could not parse DC values or AC gain.\n');
        fprintf('Parsed values: VDD=%g VG=%g VD=%g VS=%g Gain=%g\n', ...
            vdd,vg,vd,vs,gain);
        fprintf('Inspect: %s\n',logFile);
        continue;
    end

    % ph4gain is already expressed in dB by ngspice.
    % Do not calculate gain again using voltage magnitudes.

    VDD_V(i) = vdd;
    VGate_V(i) = vg;
    VDrain_V(i) = vd;
    VSource_V(i) = vs;

    VGS_V(i) = vg-vs;
    VDS_V(i) = vd-vs;

    SpiceGain_dB(i) = gain;

    % Approximate drain current from the drain resistor drop.
    DrainCurrent_A(i) = (VDD_VALUE-vd)/Xverify(i,3);

    SpiceStatus(i) = "SIMULATION_COMPLETED";

    %% Basic electrical screening checks

    supplyOK = abs(vdd-VDD_VALUE) < 0.1;

    voltageOK = vd > 0 && vd < VDD_VALUE && ...
                vs >= 0 && vs < vd;

    currentOK = isfinite(DrainCurrent_A(i)) && ...
                DrainCurrent_A(i) > 0;

    gainOK = isfinite(gain);

    if supplyOK && voltageOK && currentOK && gainOK
        VerificationStatus(i) = "SPICE_PASS_BASIC_CHECKS";
    else
        VerificationStatus(i) = "REJECT_BASIC_CHECKS";
    end

    fprintf('ML predicted gain: %.3f dB\n',MLPredictedGain_dB(i));
    fprintf('SPICE gain       : %.3f dB\n',gain);
    fprintf('VDD %.3f V | VG %.3f V | VD %.3f V | VS %.3f V\n', ...
        vdd,vg,vd,vs);
    fprintf('VGS %.3f V | VDS %.3f V | ID(est) %.6g A\n', ...
        VGS_V(i),VDS_V(i),DrainCurrent_A(i));
    fprintf('SPICE status: %s\n',SpiceStatus(i));
    fprintf('Verification: %s\n',VerificationStatus(i));

end

%% 8. Save all candidate results

Results = table(Candidate,RGU_Ohm,RGL_Ohm,RD_Ohm,RS_Ohm,CIN_F, ...
    MLPredictedGain_dB,SpiceGain_dB,VDD_V,VGate_V,VDrain_V, ...
    VSource_V,VGS_V,VDS_V,DrainCurrent_A,SpiceStatus, ...
    VerificationStatus,SpiceLogPath);

allResultsFile = fullfile(outDir,'Phase4_AllCandidateResults.csv');
writetable(Results,allResultsFile);

%% 9. Save candidates passing basic checks

passed = Results.VerificationStatus == "SPICE_PASS_BASIC_CHECKS" & ...
         isfinite(Results.SpiceGain_dB);

Verified = Results(passed,:);

if ~isempty(Verified)
    Verified = sortrows(Verified,'SpiceGain_dB','descend');
end

verifiedFile = fullfile(outDir,'Phase4_SPICEVerifiedCandidates.csv');
writetable(Verified,verifiedFile);

%% 10. Save ML-versus-SPICE comparison

simulated = Results.SpiceStatus == "SIMULATION_COMPLETED" & ...
            isfinite(Results.SpiceGain_dB);

Comparison = Results(simulated, ...
    {'Candidate','MLPredictedGain_dB','SpiceGain_dB', ...
     'VerificationStatus'});

Comparison.MLMinusSPICE_dB = ...
    Comparison.MLPredictedGain_dB-Comparison.SpiceGain_dB;

comparisonFile = fullfile(outDir,'Phase4_ML_vs_SPICE.csv');
writetable(Comparison,comparisonFile);

%% 11. Summary

fprintf('\n============================================\n');
fprintf(' PHASE 4 SUMMARY\n');
fprintf('============================================\n');

fprintf('Candidates selected: %d\n',nVerify);
fprintf('Completed simulations: %d\n',sum(simulated));
fprintf('Passed basic checks: %d\n',height(Verified));

fprintf('All results: %s\n',allResultsFile);
fprintf('Basic-check results: %s\n',verifiedFile);
fprintf('ML/SPICE comparison: %s\n',comparisonFile);

if ~isempty(Verified)
    fprintf('\nTop candidate by simulated gain (basic checks only):\n');
    disp(Verified(1,:));
else
    fprintf('\nNo candidates passed the basic checks.\n');
    fprintf('Inspect candidate-specific ngspice.log files.\n');
end

fprintf('\nPhase 4 finished.\n');

%% ================= LOCAL FUNCTIONS =================

function writeCandidateNetlist(file,VDD,subcktName,x,targetFreq)

    RGU = x(1);
    RGL = x(2);
    RD  = x(3);
    RS  = x(4);
    CIN = x(5);

    fid = fopen(file,'w');

    if fid < 0
        error('Could not create netlist: %s',file);
    end

    try
        fprintf(fid,'* Phase 4 common-source candidate\n');
        fprintf(fid,'.include "2N7000.onsemi.lib"\n');

        fprintf(fid,'VDD vdd 0 DC %.12g\n',VDD);
        fprintf(fid,'VIN in 0 DC 0 AC 1\n');

        fprintf(fid,'RGU vdd gate %.12g\n',RGU);
        fprintf(fid,'RGL gate 0 %.12g\n',RGL);
        fprintf(fid,'RD vdd drain %.12g\n',RD);
        fprintf(fid,'RS source 0 %.12g\n',RS);
        fprintf(fid,'CIN in gate %.12g\n',CIN);

        fprintf(fid,'XM1 drain gate source %s\n',subcktName);

        fprintf(fid,'.control\n');
        fprintf(fid,'set noaskquit\n');

        fprintf(fid,'op\n');
        fprintf(fid,'echo PH4_DC_BEGIN\n');
        fprintf(fid,'print v(vdd)\n');
        fprintf(fid,'print v(gate)\n');
        fprintf(fid,'print v(drain)\n');
        fprintf(fid,'print v(source)\n');
        fprintf(fid,'echo PH4_DC_END\n');

        fprintf(fid,'ac lin 1 %.12g %.12g\n', ...
            targetFreq,targetFreq);

        fprintf(fid,'let ph4gain = vdb(drain) - vdb(in)\n');
        fprintf(fid,'echo PH4_GAIN_BEGIN\n');
        fprintf(fid,'print ph4gain\n');
        fprintf(fid,'echo PH4_GAIN_END\n');

        fprintf(fid,'quit\n');
        fprintf(fid,'.endc\n');
        fprintf(fid,'.end\n');

    catch ME
        fclose(fid);
        rethrow(ME);
    end

    fclose(fid);
end

function value = parseMarkedValue(logText,variableName)

    value = NaN;

    % Handles ngspice scalar output such as:
    % v(vdd) = 1.200000e+01
    % ph4gain = 8.244776e+00

    escapedName = regexptranslate('escape',variableName);

    numberPattern = ...
        '([-+]?(?:\d+\.?\d*|\.\d+)(?:[eEdD][-+]?\d+)?)';

    pattern = ['(?im)^\s*' escapedName ...
        '\s*=\s*' numberPattern];

    token = regexp(logText,pattern,'tokens','once');

    if isempty(token)
        return;
    end

    numericText = regexprep(token{1},'[dD]','E');
    value = str2double(numericText);
end

function y = phase4Predict(model,bundle,modelName,X)

    if contains(lower(modelName),'ridge')

        mu = [];
        sigma = [];

        if isfield(bundle,'RidgeMu')
            mu = bundle.RidgeMu;
        elseif isfield(bundle,'Mu')
            mu = bundle.Mu;
        end

        if isfield(bundle,'RidgeSigma')
            sigma = bundle.RidgeSigma;
        elseif isfield(bundle,'Sigma')
            sigma = bundle.Sigma;
        end

        if isempty(mu) || isempty(sigma)
            error(['Ridge model selected, but scaling metadata ' ...
                'was not found in the saved bundle.']);
        end

        sigma(sigma == 0) = 1;
        X = (X-mu)./sigma;
    end

    y = predict(model,X);
    y = y(:);
end

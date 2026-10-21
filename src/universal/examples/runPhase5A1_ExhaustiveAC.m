%% PHASE 5A.1: EXHAUSTIVE AC VERIFICATION OF ALL DC-FEASIBLE CANDIDATES
% Evaluation only: does not retrain models, alter thresholds, or use Phase 4H
% targets. Runs AC ngspice on every DC-feasible row from Phase 5A's ranked CSV.
clearvars; clc; close all;
root = 'C:\Internship Project';
addpath(genpath(fullfile(root,'src'))); rehash;
assert(exist('runUniversalSpice','file')==2,'runUniversalSpice not found. Check src folder.');

%% Locate latest completed Phase 5A run
resultsRoot = fullfile(root,'results');
runs = dir(fullfile(resultsRoot,'Phase5A_Optimization_*'));
runs = runs([runs.isdir]);
assert(~isempty(runs),'No Phase5A_Optimization_* results folder found.');
[~,ord] = sort([runs.datenum],'descend'); runs = runs(ord);
phase5aDir = fullfile(runs(1).folder,runs(1).name);
rankedFile = fullfile(phase5aDir,'Phase5A_AllRankedCandidates.csv');
shortlistFile = fullfile(phase5aDir,'Phase5A_AC_Verification.csv');
assert(isfile(rankedFile),'Ranked candidates file not found: %s',rankedFile);
R = readtable(rankedFile);
assert(all(ismember({'CandidateID','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A','PredictedGain_dB','DCFeasible'},R.Properties.VariableNames)), ...
    'Ranked CSV does not contain expected Phase 5A columns.');

% MATLAB may read CSV booleans as logical, categorical, or numeric.
feasibleMask = R.DCFeasible;
if iscell(feasibleMask) || isstring(feasibleMask) || iscategorical(feasibleMask)
    feasibleMask = strcmpi(string(feasibleMask),'true') | string(feasibleMask)=='1';
else
    feasibleMask = logical(feasibleMask);
end
F = R(feasibleMask,:);
assert(~isempty(F),'No DC-feasible candidates found in ranked CSV.');
F = sortrows(F,{'PredictedGain_dB'},{'descend'});
fprintf('Phase 5A source: %s\n',phase5aDir);
fprintf('DC-feasible candidates to AC-verify: %d\n',height(F));

%% ngspice setup (same 2N7000 model and AC sweep as Phase 5A)
modelPath = fullfile(root,'models','mosfet','2N7000.onsemi.lib');
assert(isfile(modelPath),'2N7000 model not found: %s',modelPath);
mm = ModelManager(); mm = mm.registerFileModel("2N7000","MOSFET",modelPath);
optAC = struct('Analysis',"AC",'ACStart',10,'ACStop',1e6, ...
    'PointsPerDecade',50,'PrintExpressions',["vm(IN)","vp(IN)", ...
    "vm(GATE)","vp(GATE)","vm(DRAIN)","vp(DRAIN)"],'KeepFiles',true);
VDD = 12; fref = 1000;
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase5A_ExhaustiveAC_' stamp]);
if ~isfolder(outDir), mkdir(outDir); end

%% AC simulate every DC-feasible candidate
AC = table(); responses = cell(height(F),1);
for k = 1:height(F)
    q = F(k,:);
    row = table(q.CandidateID,q.RGU_Ohm,q.RGL_Ohm,q.RD_Ohm,q.RS_Ohm,q.CIN_F, ...
        q.VGS_V,q.VDS_V,q.ID_A,q.PredictedGain_dB,NaN,NaN,NaN,false, ...
        "NOT_RUN","", ...
        'VariableNames',{'CandidateID','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
        'CIN_F','VGS_V','VDS_V','ID_A','PredictedGain_dB', ...
        'ActualGainAt1kHz_dB','PeakGain_dB','PeakGainFrequency_Hz', ...
        'ACSuccess','ACStatus','ErrorMessage'});
    try
        c = makeCircuit(q.CandidateID,q.RGU_Ohm,q.RGL_Ohm,q.RD_Ohm,q.RS_Ohm,q.CIN_F,VDD);
        vi = find(arrayfun(@(z) string(z.Name)=="VIN",c.Components),1);
        assert(~isempty(vi),'VIN component not found.');
        vin = c.Components(vi); vin.Parameters.DC=0; vin.Parameters.AC=1; vin.Parameters.ACPhase=0;
        c.Components(vi)=vin;
        a = runUniversalSpice(c,mm,optAC);
        row.ACSuccess = logical(a.Success);
        if ~a.Success
            row.ACStatus = "FAILED";
            row.ErrorMessage = string(a.ErrorMessage);
        else
            assert(~isempty(a.ACSignals),'AC signals empty.');
            assert(isfield(a.ACSignals,'in') && isfield(a.ACSignals,'drain'), ...
                'IN/DRAIN AC signals missing.');
            si=a.ACSignals.in; so=a.ACSignals.drain;
            f=si.Frequency(:); fo=so.Frequency(:); vinMag=si.Magnitude(:); voutMag=so.Magnitude(:);
            assert(~isempty(f) && numel(f)==numel(fo) && all(abs(f-fo)<1e-9), ...
                'Input/output frequency grids differ.');
            assert(numel(vinMag)==numel(f) && numel(voutMag)==numel(f) && ...
                all(isfinite(f)) && all(f>0) && all(isfinite(vinMag)) && ...
                all(isfinite(voutMag)) && all(vinMag>0) && all(voutMag>=0), ...
                'Invalid AC signal values.');
            [f,ix]=sort(f); vinMag=vinMag(ix); voutMag=voutMag(ix);
            assert(numel(unique(f))==numel(f),'Duplicate AC frequency points.');
            gainDB=20*log10(max(voutMag./vinMag,realmin));
            [row.PeakGain_dB,ip]=max(gainDB);
            row.PeakGainFrequency_Hz=f(ip);
            assert(fref>=min(f) && fref<=max(f),'1 kHz outside AC sweep.');
            row.ActualGainAt1kHz_dB=interp1(log10(f),gainDB,log10(fref),'linear');
            row.ACStatus="SUCCESS";
            responses{k}=struct('CandidateID',q.CandidateID,'Frequency_Hz',f,'Gain_dB',gainDB);
        end
    catch ME
        row.ACStatus="ERROR"; row.ErrorMessage=string(ME.message);
    end
    AC=[AC;row]; %#ok<AGROW>
    if mod(k,10)==0 || k==height(F)
        fprintf('AC exhaustive %d/%d | latest ID=%g | status=%s\n', ...
            k,height(F),q.CandidateID,row.ACStatus);
    end
    % Checkpoint every 10 simulations so interrupted runs retain progress.
    if mod(k,10)==0 || k==height(F)
        writetable(AC,fullfile(outDir,'Phase5A1_Exhaustive_AC_Progress.csv'));
        save(fullfile(outDir,'Phase5A1_Exhaustive_AC_Progress.mat'),'AC','responses','-v7.3');
    end
end

%% Save exhaustive ranking
validAC = AC.ACSuccess & isfinite(AC.ActualGainAt1kHz_dB);
Verified = AC(validAC,:);
if ~isempty(Verified)
    Verified.PredictionError_dB = Verified.ActualGainAt1kHz_dB - Verified.PredictedGain_dB;
    Verified.AbsolutePredictionError_dB = abs(Verified.PredictionError_dB);
    Verified.MeetsActualGainTarget = Verified.ActualGainAt1kHz_dB >= 3;
    Verified = sortrows(Verified,{'ActualGainAt1kHz_dB'},{'descend'});
    Verified.ActualGainRank = (1:height(Verified))';
    writetable(Verified,fullfile(outDir,'Phase5A1_Exhaustive_AC_Ranking.csv'));
else
    warning('No AC simulations completed successfully.');
    Verified = table();
end
writetable(AC,fullfile(outDir,'Phase5A1_All_AC_Results.csv'));
save(fullfile(outDir,'Phase5A1_Exhaustive_AC_Responses.mat'),'AC','Verified','responses','-v7.3');

%% Compare the original 15-candidate Phase 5A shortlist with exhaustive truth
Comparison = table(); Metrics = table();
if isfile(shortlistFile) && ~isempty(Verified)
    Short = readtable(shortlistFile);
    if ismember('CandidateID',Short.Properties.VariableNames)
        [found,loc] = ismember(Short.CandidateID,Verified.CandidateID);
        Short.ActualGainExhaustive_dB = nan(height(Short),1);
        Short.ExhaustiveActualRank = nan(height(Short),1);
        Short.ExhaustivePredictionError_dB = nan(height(Short),1);
        Short.ExhaustiveAbsoluteError_dB = nan(height(Short),1);
        Short.ActualGainExhaustive_dB(found) = Verified.ActualGainAt1kHz_dB(loc(found));
        Short.ExhaustiveActualRank(found) = Verified.ActualGainRank(loc(found));
        Short.ExhaustivePredictionError_dB(found) = Verified.PredictionError_dB(loc(found));
        Short.ExhaustiveAbsoluteError_dB(found) = Verified.AbsolutePredictionError_dB(loc(found));
        Comparison = Short;
        writetable(Comparison,fullfile(outDir,'Phase5A1_OriginalShortlist_vs_Exhaustive.csv'));
        successfulShort = found & isfinite(Short.ActualGainExhaustive_dB);
        if any(successfulShort)
            bestShortGain = max(Short.ActualGainExhaustive_dB(successfulShort));
            bestAllGain = max(Verified.ActualGainAt1kHz_dB);
            topK = min(15,height(Verified));
            shortlistIds = Short.CandidateID(successfulShort);
            shortlistRecallAtK = sum(ismember(Verified.CandidateID(1:topK),shortlistIds))/topK;
            meanAbsErr = mean(Short.ExhaustiveAbsoluteError_dB(successfulShort),'omitnan');
            medianAbsErr = median(Short.ExhaustiveAbsoluteError_dB(successfulShort),'omitnan');
            Metrics = table(height(F),sum(AC.ACSuccess),height(Verified),bestAllGain, ...
                bestShortGain,bestAllGain-bestShortGain,shortlistRecallAtK,meanAbsErr,medianAbsErr, ...
                'VariableNames',{'DCFeasibleCandidates','ACSuccessCount','ValidACCount', ...
                'BestExhaustiveGain_dB','BestOriginalShortlistGain_dB','ShortlistGainRegret_dB', ...
                'Top15RecallOfActualTop15','ShortlistMeanAbsolutePredictionError_dB', ...
                'ShortlistMedianAbsolutePredictionError_dB'});
            writetable(Metrics,fullfile(outDir,'Phase5A1_Summary_Metrics.csv'));
            disp(Metrics);
        end
    end
end

summary=struct('Phase5ASourceFolder',phase5aDir,'DCFeasibleCandidates',height(F), ...
    'ACAttempted',height(AC),'ACSuccessCount',sum(AC.ACSuccess), ...
    'ValidACCount',height(Verified),'OutputFolder',outDir, ...
    'Note','Evaluation-only exhaustive AC verification. No model retraining. Phase 4H data is not used for fitting.');
save(fullfile(outDir,'Phase5A1_Summary.mat'),'summary','Metrics');
fprintf('\nPhase 5A.1 exhaustive AC verification complete.\nResults: %s\n',outDir);
if ~isempty(Verified)
    disp(Verified(1:min(15,height(Verified)),{'CandidateID','RGU_Ohm','RGL_Ohm', ...
        'RD_Ohm','RS_Ohm','CIN_F','VDS_V','ID_A','PredictedGain_dB', ...
        'ActualGainAt1kHz_dB','PredictionError_dB','ActualGainRank'}));
end

%% Local helper: exact same common-source topology used in Phase 5A
function c=makeCircuit(id,RGU,RGL,RD,RS,CIN,VDD)
c=createCircuit("Phase5A1_CS_"+string(id)); c.Metadata.Topology="Common_Source";
c=circuitAddComponent(c,"VDD","VOLTAGE_SOURCE",["VDD","GND"],VDD);
c=circuitAddComponent(c,"VIN","VOLTAGE_SOURCE",["IN","GND"],0);
c=circuitAddComponent(c,"RD","R",["VDD","DRAIN"],RD);
c=circuitAddComponent(c,"RS","R",["SOURCE","GND"],RS);
c=circuitAddComponent(c,"RGU","R",["VDD","GATE"],RGU);
c=circuitAddComponent(c,"M1","MOSFET",["DRAIN","GATE","SOURCE"],[],"2N7000");
i=find(arrayfun(@(x) string(x.Name)=="M1",c.Components),1);
assert(~isempty(i),'MOSFET M1 not found.'); m=c.Components(i);
m=m.setParameter("UseSubcircuit",true); c.Components(i)=m;
c=circuitAddComponent(c,"RGL","R",["GATE","GND"],RGL);
c=circuitAddComponent(c,"CIN","C",["IN","GATE"],CIN);
end

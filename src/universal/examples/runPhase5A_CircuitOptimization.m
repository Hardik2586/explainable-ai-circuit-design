clearvars; clc; close all; rng(42,'twister');
root = 'C:\Internship Project';
addpath(genpath(fullfile(root,'src'))); rehash;
assert(exist('runUniversalSpice','file')==2,'runUniversalSpice not found.');

%% Development dataset and frozen-model architecture
 devMat = fullfile(root,'data','universal','Common_Source', ...
    'external_model_validation','20261020_000113','CS_Dataset_v2_100.mat');
assert(isfile(devMat),'Development MAT file not found: %s',devMat);
S = load(devMat); T = S.rows;
features = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VGS_V','VDS_V','ID_A'};
target = 'GainAt1kHz_dB'; lowCut = -10; routeCut = 0.5;
ok = logical(T.SimulationValid) & isfinite(T.(target));
for j=1:numel(features), ok = ok & isfinite(T.(features{j})); end
T = T(ok,:); X = tableFeatures(T,features); Y = T.(target); low = Y < lowCut;
assert(sum(low)>=3 && any(~low),'Need both target groups and >=3 low-gain examples.');
fprintf('Training data: %d rows; low-gain: %d\n',height(T),sum(low));
globalModel = fitrensemble(X,Y,'Method','Bag','NumLearningCycles',100, ...
    'Learners',templateTree('MinLeafSize',5));
routerModel = fitcensemble(X,categorical(low,[false true],{'Other','LowGain'}), ...
    'Method','Bag','NumLearningCycles',100,'Learners',templateTree('MinLeafSize',3));
Xlow=X(low,:); Ylow=Y(low); mu=mean(Xlow,1); sig=std(Xlow,0,1);
sig(~isfinite(sig)|sig<1e-12)=1;
ridgeModel=fitrlinear((Xlow-mu)./sig,Ylow,'Learner','leastsquares', ...
    'Regularization','ridge','Lambda',1);
frozen=struct('GlobalModel',globalModel,'RouterModel',routerModel, ...
    'RidgeModel',ridgeModel,'FeatureNames',{features},'TargetName',target, ...
    'LowGainThreshold_dB',lowCut,'RoutingProbabilityThreshold',routeCut, ...
    'RidgeMean',mu,'RidgeStd',sig,'DevelopmentDataset',devMat, ...
    'DevelopmentRows',height(T),'FrozenAt',datetime('now'));

%% Enumerate discrete design grid
RGUvals=[82e3 100e3 120e3]; RGLvals=[56e3 68e3 75e3 82e3 100e3];
RDvals=[1.8e3 2.2e3 2.7e3]; RSvals=[820 1e3 1.2e3]; CINvals=[4.7e-6 10e-6 22e-6];
gridVals={RGUvals,RGLvals,RDvals,RSvals,CINvals};
compNames={'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F'};
[A,B,C,D,E]=ndgrid(1:numel(RGUvals),1:numel(RGLvals),1:numel(RDvals), ...
    1:numel(RSvals),1:numel(CINvals)); allIdx=[A(:),B(:),C(:),D(:),E(:)];
devIdx=toGridIndices(T,compNames,gridVals);
% Keep Phase 4H independent validation isolated from the optimization search.
holdIdx=zeros(0,5); hroot=fullfile(root,'data','universal','Common_Source','Phase4H_IndependentValidation');
if isfolder(hroot)
    hf=dir(fullfile(hroot,'**','Phase4H_FreshCircuitDataset.mat'));
    for k=1:numel(hf)
        try
            H=load(fullfile(hf(k).folder,hf(k).name),'rows');
            if isfield(H,'rows'), holdIdx=[holdIdx;toGridIndices(H.rows,compNames,gridVals)]; end %#ok<AGROW>
        catch ME, warning('Could not read Phase 4H holdout: %s',ME.message);
        end
    end
end
excluded=unique([devIdx;holdIdx],'rows'); searchIdx=allIdx(~ismember(allIdx,excluded,'rows'),:);
fprintf('Grid=%d; dev excluded=%d; Phase 4H holdout excluded=%d; search=%d\n', ...
    size(allIdx,1),size(devIdx,1),size(unique(holdIdx,'rows'),1),size(searchIdx,1));
assert(~isempty(searchIdx),'No candidate combinations remain.');

%% SPICE setup
modelPath=fullfile(root,'models','mosfet','2N7000.onsemi.lib');
assert(isfile(modelPath),'2N7000 model missing: %s',modelPath);
mm=ModelManager(); mm=mm.registerFileModel("2N7000","MOSFET",modelPath);
optDC=struct('Analysis',"DC",'KeepFiles',true);
optAC=struct('Analysis',"AC",'ACStart',10,'ACStop',1e6, ...
    'PointsPerDecade',50,'PrintExpressions',["vm(IN)","vp(IN)", ...
    "vm(GATE)","vp(GATE)","vm(DRAIN)","vp(DRAIN)"],'KeepFiles',true);
VDD=12; fref=1000;
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(root,'results',['Phase5A_Optimization_' stamp]);
dataDir=fullfile(root,'data','universal','Common_Source','Phase5A_Optimization',stamp);
if ~isfolder(outDir),mkdir(outDir);end; if ~isfolder(dataDir),mkdir(dataDir);end
save(fullfile(outDir,'Phase5A_FrozenDevelopmentModels.mat'),'frozen','-v7.3');

%% DC-simulate candidates
n=size(searchIdx,1); Cand=table();
for i=1:n
    RGU=RGUvals(searchIdx(i,1)); RGL=RGLvals(searchIdx(i,2));
    RD=RDvals(searchIdx(i,3)); RS=RSvals(searchIdx(i,4)); CIN=CINvals(searchIdx(i,5));
    row=table(i,RGU,RGL,RD,RS,CIN,VDD,NaN,NaN,NaN,NaN,NaN,NaN, ...
        false,"NOT_RUN","",'VariableNames',{'CandidateID','RGU_Ohm','RGL_Ohm', ...
        'RD_Ohm','RS_Ohm','CIN_F','VDD_V','Vgate_V','Vsource_V','Vdrain_V', ...
        'VGS_V','VDS_V','ID_A','DCSuccess','DCStatus','ErrorMessage'});
    try
        c=makeCircuit(i,RGU,RGL,RD,RS,CIN,VDD); d=runUniversalSpice(c,mm,optDC);
        row.DCSuccess=logical(d.Success);
        if d.Success
            row.DCStatus="SUCCESS"; row.Vgate_V=nodeV(d,"gate");
            row.Vsource_V=nodeV(d,"source"); row.Vdrain_V=nodeV(d,"drain");
            row.VGS_V=row.Vgate_V-row.Vsource_V; row.VDS_V=row.Vdrain_V-row.Vsource_V;
            row.ID_A=row.Vsource_V/RS;
        else, row.DCStatus="FAILED"; row.ErrorMessage=string(d.ErrorMessage);
        end
    catch ME, row.DCStatus="ERROR"; row.ErrorMessage=string(ME.message);
    end
    Cand=[Cand;row]; %#ok<AGROW>
    if mod(i,10)==0||i==n, fprintf('DC candidate %d/%d\n',i,n); end
end
writetable(Cand,fullfile(dataDir,'Phase5A_DC_Candidates.csv'));
save(fullfile(dataDir,'Phase5A_DC_Candidates.mat'),'Cand','searchIdx','-v7.3');

%% ML ranking and DC feasibility screen
ok=Cand.DCSuccess & isfinite(Cand.VGS_V)&isfinite(Cand.VDS_V)&isfinite(Cand.ID_A);
D=Cand(ok,:); assert(height(D)>0,'No successful DC simulations.'); Xc=tableFeatures(D,features);
pGlobal=predict(globalModel,Xc); [~,sc]=predict(routerModel,Xc);
cn=string(routerModel.ClassNames); lc=find(cn=="LowGain",1); assert(~isempty(lc));
pLow=sc(:,lc); route=pLow>=routeCut;
pRidge=predict(ridgeModel,(Xc-mu)./sig); pFinal=pGlobal; pFinal(route)=pRidge(route);
% Explicit screening constraints; tune only with engineering justification.
minVDS=1.0; minDrainRatio=0.15; maxDrainRatio=0.85; minID=1e-6;
drainRatio=D.Vdrain_V./VDD;
feasible=D.VDS_V>=minVDS & drainRatio>=minDrainRatio & ...
    drainRatio<=maxDrainRatio & D.ID_A>=minID & D.ID_A<(VDD./D.RD_Ohm) & isfinite(pFinal);
Ranked=D; Ranked.PredictedGlobalGain_dB=pGlobal; Ranked.PredictedLowGainProbability=pLow;
Ranked.RoutedToRidge=route; Ranked.PredictedGain_dB=pFinal;
Ranked.DrainVoltageRatio=drainRatio; Ranked.DCFeasible=feasible;
Ranked.MeetsPredictedGainTarget=pFinal>=3;
Ranked=sortrows(Ranked,{'DCFeasible','PredictedGain_dB'},{'descend','descend'});
writetable(Ranked,fullfile(outDir,'Phase5A_AllRankedCandidates.csv'));
F=Ranked(Ranked.DCFeasible,:); Nverify=min(15,height(F)); Short=F(1:Nverify,:);
fprintf('DC success=%d/%d; feasible=%d; AC shortlist=%d\n',height(D),n,height(F),height(Short));

%% AC verification of top feasible candidates
AC=table(); responses=cell(height(Short),1);
for k=1:height(Short)
    q=Short(k,:); c=makeCircuit(q.CandidateID,q.RGU_Ohm,q.RGL_Ohm,q.RD_Ohm,q.RS_Ohm,q.CIN_F,VDD);
    row=table(q.CandidateID,q.RGU_Ohm,q.RGL_Ohm,q.RD_Ohm,q.RS_Ohm,q.CIN_F, ...
        q.VGS_V,q.VDS_V,q.ID_A,q.PredictedGain_dB,q.PredictedLowGainProbability, ...
        NaN,NaN,NaN,false,"NOT_RUN","",'VariableNames',{'CandidateID','RGU_Ohm', ...
        'RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VGS_V','VDS_V','ID_A', ...
        'PredictedGain_dB','PredictedLowGainProbability','ActualGainAt1kHz_dB', ...
        'PeakGain_dB','PeakGainFrequency_Hz','ACSuccess','ACStatus','ErrorMessage'});
    try
        vi=find(arrayfun(@(z) string(z.Name)=="VIN",c.Components),1); vin=c.Components(vi);
        vin.Parameters.DC=0; vin.Parameters.AC=1; vin.Parameters.ACPhase=0; c.Components(vi)=vin;
        a=runUniversalSpice(c,mm,optAC); row.ACSuccess=logical(a.Success);
        if ~a.Success, row.ACStatus="FAILED"; row.ErrorMessage=string(a.ErrorMessage);
        else
            assert(~isempty(a.ACSignals),'AC signals empty.');
            assert(isfield(a.ACSignals,'in')&&isfield(a.ACSignals,'drain'),'IN/DRAIN AC signals missing.');
            si=a.ACSignals.in; so=a.ACSignals.drain; f=si.Frequency(:); fo=so.Frequency(:);
            vi=si.Magnitude(:); vo=so.Magnitude(:);
            assert(numel(f)==numel(fo)&&all(abs(f-fo)<1e-9),'Frequency grids differ.');
            [f,ord]=sort(f); vi=vi(ord); vo=vo(ord); g=20*log10(max(vo./vi,realmin));
            [row.PeakGain_dB,ip]=max(g); row.PeakGainFrequency_Hz=f(ip);
            row.ActualGainAt1kHz_dB=interp1(log10(f),g,log10(fref),'linear');
            row.ACStatus="SUCCESS"; responses{k}=struct('CandidateID',q.CandidateID, ...
                'Frequency_Hz',f,'Gain_dB',g);
        end
    catch ME, row.ACStatus="ERROR"; row.ErrorMessage=string(ME.message);
    end
    AC=[AC;row]; %#ok<AGROW>
    fprintf('AC %d/%d | ID=%d | predicted %.2f dB | actual %.2f dB | %s\n', ...
        k,height(Short),q.CandidateID,row.PredictedGain_dB,row.ActualGainAt1kHz_dB,row.ACStatus);
end
writetable(AC,fullfile(outDir,'Phase5A_AC_Verification.csv'));
save(fullfile(outDir,'Phase5A_AC_Responses.mat'),'responses','AC','-v7.3');
if isempty(AC)
    Verified=table();
else
    validAC=AC.ACSuccess & isfinite(AC.ActualGainAt1kHz_dB); Verified=AC(validAC,:);
end
if ~isempty(Verified)
    Verified.PredictionError_dB=Verified.ActualGainAt1kHz_dB-Verified.PredictedGain_dB;
    Verified.MeetsActualGainTarget=Verified.ActualGainAt1kHz_dB>=3;
    Verified=sortrows(Verified,{'MeetsActualGainTarget','ActualGainAt1kHz_dB'},{'descend','descend'});
    writetable(Verified,fullfile(outDir,'Phase5A_AC_Verified_Ranking.csv'));
    disp(Verified(1:min(10,height(Verified)),{'CandidateID','RGU_Ohm','RGL_Ohm','RD_Ohm', ...
        'RS_Ohm','CIN_F','VDS_V','ID_A','PredictedGain_dB','ActualGainAt1kHz_dB', ...
        'PredictionError_dB','MeetsActualGainTarget'}));
else, warning('No shortlisted candidate completed AC verification.'); end
summary=struct('DevelopmentDataset',devMat,'DevelopmentRows',height(T), ...
    'FullGridCount',size(allIdx,1),'SearchCandidateCount',size(searchIdx,1), ...
    'DCSuccessCount',height(D),'DCFeasibleCount',height(F),'ACShortlistCount',height(Short), ...
    'TargetGain_dB',3,'Note','Common-source 2N7000 pilot; final ranking is AC-SPICE based.');
save(fullfile(outDir,'Phase5A_Summary.mat'),'summary');
fprintf('\nPhase 5A complete.\nData: %s\nResults: %s\n',dataDir,outDir);

%% Local helpers
function X=tableFeatures(T,names)
X=zeros(height(T),numel(names)); for j=1:numel(names), X(:,j)=T.(names{j}); end
end
function idx=toGridIndices(T,names,gv)
idx=zeros(0,numel(names)); if isempty(T)||height(T)==0, return; end
for r=1:height(T)
    z=zeros(1,numel(names)); good=true;
    for j=1:numel(names)
        if ~ismember(names{j},T.Properties.VariableNames)||~isfinite(T.(names{j})(r)), good=false; break; end
        v=T.(names{j})(r); q=find(abs(gv{j}-v)<=max(1e-12,abs(v)*1e-10),1);
        if isempty(q), good=false; break; end; z(j)=q;
    end
    if good, idx(end+1,:)=z; end %#ok<AGROW>
end
idx=unique(idx,'rows');
end
function c=makeCircuit(id,RGU,RGL,RD,RS,CIN,VDD)
c=createCircuit("Phase5A_CS_"+string(id)); c.Metadata.Topology="Common_Source";
c=circuitAddComponent(c,"VDD","VOLTAGE_SOURCE",["VDD","GND"],VDD);
c=circuitAddComponent(c,"VIN","VOLTAGE_SOURCE",["IN","GND"],0);
c=circuitAddComponent(c,"RD","R",["VDD","DRAIN"],RD);
c=circuitAddComponent(c,"RS","R",["SOURCE","GND"],RS);
c=circuitAddComponent(c,"RGU","R",["VDD","GATE"],RGU);
c=circuitAddComponent(c,"M1","MOSFET",["DRAIN","GATE","SOURCE"],[],"2N7000");
i=find(arrayfun(@(x) string(x.Name)=="M1",c.Components),1); m=c.Components(i);
m=m.setParameter("UseSubcircuit",true); c.Components(i)=m;
c=circuitAddComponent(c,"RGL","R",["GATE","GND"],RGL);
c=circuitAddComponent(c,"CIN","C",["IN","GATE"],CIN);
end
function v=nodeV(r,n)
names=lower(strtrim(string(r.NodeNames))); i=find(names==lower(string(n)),1);
if isempty(i), error('Node voltage not found: %s',n); end; v=r.NodeVoltages(i);
if ~isscalar(v)||~isfinite(v), error('Invalid node voltage for %s',n); end
end

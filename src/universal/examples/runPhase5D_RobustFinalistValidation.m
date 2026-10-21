%% PHASE 5D: 200-TRIAL ROBUST FINALIST VALIDATION
% Uses the existing ngspice wrapper; no ML retraining and no Phase 4H tuning.
clear; clc; close all; rng(20261021,'twister');
root='C:\Internship Project'; addpath(genpath(fullfile(root,'src'))); rehash;
assert(exist('runUniversalSpice','file')==2,'runUniversalSpice not found.');
resultsRoot=fullfile(root,'results'); candidateIDs=[152 156 150]; Ntrials=200;
VDDnom=12; tolR=.05; tolC=.10; tolVDD=.05; fref=1000;
d=dir(fullfile(resultsRoot,'Phase5A_ExhaustiveAC_*')); d=d([d.isdir]);
assert(~isempty(d),'No Phase5A exhaustive AC folder.'); [~,ix]=max([d.datenum]);
src=fullfile(d(ix).folder,d(ix).name);
T=readtable(fullfile(src,'Phase5A1_Exhaustive_AC_Ranking.csv'));
[found,loc]=ismember(candidateIDs,T.CandidateID); assert(all(found),'A finalist ID is missing from exhaustive ranking.'); sel=T(loc,:);
modelPath=fullfile(root,'models','mosfet','2N7000.onsemi.lib'); assert(isfile(modelPath),'2N7000 model missing.');
mm=ModelManager(); mm=mm.registerFileModel("2N7000","MOSFET",modelPath);
optDC=struct('Analysis',"DC",'KeepFiles',true);
optAC=struct('Analysis',"AC",'ACStart',10,'ACStop',1e6,'PointsPerDecade',50, ...
 'PrintExpressions',["vm(IN)","vp(IN)","vm(GATE)","vp(GATE)","vm(DRAIN)","vp(DRAIN)"],'KeepFiles',true);
outDir=fullfile(resultsRoot,['Phase5D_RobustFinalists_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]); mkdir(outDir);
Trial=table();
for ci=1:height(sel)
 q=sel(ci,:); fprintf('\nCandidate %d (%d/%d)\n',q.CandidateID,ci,height(sel));
 for t=1:Ntrials
  RGU=q.RGU_Ohm*(1+uniformTol(tolR)); RGL=q.RGL_Ohm*(1+uniformTol(tolR));
  RD=q.RD_Ohm*(1+uniformTol(tolR)); RS=q.RS_Ohm*(1+uniformTol(tolR));
  CIN=q.CIN_F*(1+uniformTol(tolC)); VDD=VDDnom*(1+uniformTol(tolVDD));
  r=table(q.CandidateID,t,RGU,RGL,RD,RS,CIN,VDD,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
   false,false,false,false,"NOT_RUN","",'VariableNames',{'CandidateID','Trial','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V', ...
   'Vsource_V','Vdrain_V','VGS_V','VDS_V','ID_A','GainAt1kHz_dB','SupplyPower_mW', ...
   'DCSuccess','ACSuccess','DCFeasible','MeetsAllConstraints','Status','ErrorMessage'});
  try
   c=makeCircuit(q.CandidateID*10000+t,RGU,RGL,RD,RS,CIN,VDD);
   dc=runUniversalSpice(c,mm,optDC); if ~dc.Success, error('DC simulation failed: %s',string(dc.ErrorMessage)); end
   r.Vsource_V=nodeV(dc,"source"); r.Vdrain_V=nodeV(dc,"drain"); r.VGS_V=nodeV(dc,"gate")-r.Vsource_V;
   r.VDS_V=r.Vdrain_V-r.Vsource_V; r.ID_A=r.Vsource_V/RS; r.DCSuccess=true;
   ratio=r.Vdrain_V/VDD; r.SupplyPower_mW=1000*VDD*(r.ID_A+VDD/(RGU+RGL));
   r.DCFeasible=r.VDS_V>=1 && ratio>=.15 && ratio<=.85 && r.ID_A>=1e-6 && r.ID_A<VDD/RD;
   i=find(arrayfun(@(z)string(z.Name)=="VIN",c.Components),1); vin=c.Components(i);
   vin.Parameters.DC=0; vin.Parameters.AC=1; vin.Parameters.ACPhase=0; c.Components(i)=vin;
   ac=runUniversalSpice(c,mm,optAC); if ~ac.Success, error('AC simulation failed: %s',string(ac.ErrorMessage)); end
   assert(isfield(ac.ACSignals,'in')&&isfield(ac.ACSignals,'drain'),'AC input/drain signals missing.');
   si=ac.ACSignals.in; so=ac.ACSignals.drain; f=si.Frequency(:); fo=so.Frequency(:);
   assert(numel(f)==numel(fo)&&all(abs(f-fo)<1e-9),'AC frequency grids differ.');
   [f,ord]=sort(f); g=20*log10(max(so.Magnitude(ord)./si.Magnitude(ord),realmin));
   r.GainAt1kHz_dB=interp1(log10(f),g,log10(fref),'linear'); r.ACSuccess=true;
   r.MeetsAllConstraints=r.DCFeasible && r.GainAt1kHz_dB>=3; r.Status="SUCCESS";
  catch ME
   r.Status="ERROR"; r.ErrorMessage=string(ME.message);
  end
  Trial=[Trial;r]; %#ok<AGROW>
  if mod(t,10)==0 || t==Ntrials
   fprintf(' trial %d/%d | DC feasible %d | AC success %d\n',t,Ntrials, ...
    sum(Trial.DCFeasible(Trial.CandidateID==q.CandidateID)),sum(Trial.ACSuccess(Trial.CandidateID==q.CandidateID)));
   writetable(Trial,fullfile(outDir,'Phase5D_Progress.csv'));
   save(fullfile(outDir,'Phase5D_Progress.mat'),'Trial','sel','Ntrials','-v7.3');
  end
 end
end
writetable(Trial,fullfile(outDir,'Phase5D_AllTrials.csv'));
Summary=summarizeResults(Trial); Summary=sortrows(Summary,{'RobustFeasibilityRate','P05Gain_dB','MeanGain_dB'},{'descend','descend','descend'});
writetable(Summary,fullfile(outDir,'Phase5D_FinalistRanking.csv')); save(fullfile(outDir,'Phase5D_Results.mat'),'Trial','Summary','sel','Ntrials','-v7.3');
fig=figure('Color','w'); ax=axes(fig); hold(ax,'on');
for k=1:height(Summary), z=Trial(Trial.CandidateID==Summary.CandidateID(k)&Trial.ACSuccess,:); scatter(ax,repmat(k,height(z),1),z.GainAt1kHz_dB,12,'filled'); end
xticks(ax,1:height(Summary)); xticklabels(ax,string(Summary.CandidateID)); xlabel(ax,'Candidate ID'); ylabel(ax,'Gain at 1 kHz (dB)'); grid(ax,'on'); ax.Toolbar.Visible='off';
exportgraphics(fig,fullfile(outDir,'Phase5D_GainDistribution.png'),'Resolution',200);
fprintf('\nPhase 5D complete. Results: %s\n',outDir); disp(Summary);
function x=uniformTol(t), x=(2*rand-1)*t; end
function c=makeCircuit(id,RGU,RGL,RD,RS,CIN,VDD)
c=createCircuit("Phase5D_CS_"+string(id)); c.Metadata.Topology="Common_Source";
c=circuitAddComponent(c,"VDD","VOLTAGE_SOURCE",["VDD","GND"],VDD);
c=circuitAddComponent(c,"VIN","VOLTAGE_SOURCE",["IN","GND"],0);
c=circuitAddComponent(c,"RD","R",["VDD","DRAIN"],RD); c=circuitAddComponent(c,"RS","R",["SOURCE","GND"],RS);
c=circuitAddComponent(c,"RGU","R",["VDD","GATE"],RGU);
c=circuitAddComponent(c,"M1","MOSFET",["DRAIN","GATE","SOURCE"],[],"2N7000");
i=find(arrayfun(@(x)string(x.Name)=="M1",c.Components),1); m=c.Components(i); m=m.setParameter("UseSubcircuit",true); c.Components(i)=m;
c=circuitAddComponent(c,"RGL","R",["GATE","GND"],RGL); c=circuitAddComponent(c,"CIN","C",["IN","GATE"],CIN);
end
function v=nodeV(r,n)
s=lower(strtrim(string(r.NodeNames))); i=find(s==lower(string(n)),1); if isempty(i), error('Node not found: %s',n); end
v=r.NodeVoltages(i); if ~isscalar(v)||~isfinite(v), error('Invalid node voltage: %s',n); end
end
function S=summarizeResults(T)
ids=unique(T.CandidateID,'stable'); S=table();
for k=1:numel(ids)
 z=T(T.CandidateID==ids(k),:); g=z.GainAt1kHz_dB(z.ACSuccess&isfinite(z.GainAt1kHz_dB));
 if isempty(g), m=NaN; sd=NaN; worst=NaN; p05=NaN; med=NaN; p95=NaN; else, m=mean(g); sd=std(g); worst=min(g); p05=prctile(g,5); med=median(g); p95=prctile(g,95); end
 row=table(ids(k),height(z),mean(z.DCSuccess),mean(z.ACSuccess),mean(z.DCFeasible),mean(z.MeetsAllConstraints),m,sd,worst,p05,med,p95,mean(z.SupplyPower_mW,'omitnan'), ...
 'VariableNames',{'CandidateID','Trials','DCSuccessRate','ACSuccessRate','DCFeasibilityRate','RobustFeasibilityRate','MeanGain_dB','StdGain_dB','WorstObservedGain_dB','P05Gain_dB','MedianGain_dB','P95Gain_dB','MeanSupplyPower_mW'});
 S=[S;row]; %#ok<AGROW>
end
end

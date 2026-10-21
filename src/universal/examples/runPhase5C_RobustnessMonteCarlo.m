%% PHASE 5C: COMPONENT-TOLERANCE MONTE CARLO ROBUSTNESS
% Requires the existing Universal Circuit-XAI MATLAB/ngspice framework.
% No model retraining; does not read/use Phase 4H data.
clear; clc; close all; rng(20261020,'twister');
root='C:\Internship Project'; addpath(genpath(fullfile(root,'src'))); rehash;
assert(exist('runUniversalSpice','file')==2,'runUniversalSpice not found.');
assert(exist('ModelManager','class')==8 || exist('ModelManager','file')==2,'ModelManager not found.');
rr=fullfile(root,'results'); d=dir(fullfile(rr,'Phase5B_Multiobjective_*')); d=d([d.isdir]);
assert(~isempty(d),'No Phase5B_Multiobjective_* folder found. Run Phase 5B first.');
[~,ix]=max([d.datenum]); bdir=fullfile(d(ix).folder,d(ix).name);
pf=fullfile(bdir,'Phase5B_Pareto_Front.csv'); assert(isfile(pf),'Pareto CSV not found: %s',pf);
P=readtable(pf); assert(height(P)>0,'Pareto front empty.'); P=sortrows(P,'ActualGainAt1kHz_dB','descend');
% Test the 10 highest-gain Pareto designs, plus lowest-power and highest-margin points when available.
sel=P(1:min(10,height(P)),:);
if ismember('EstimatedSupplyPower_mW',P.Properties.VariableNames), [~,j]=min(P.EstimatedSupplyPower_mW); sel=[sel;P(j,:)]; end
if ismember('DCOperatingMargin_V',P.Properties.VariableNames), [~,j]=max(P.DCOperatingMargin_V); sel=[sel;P(j,:)]; end
[~,ia]=unique(sel.CandidateID,'stable'); sel=sel(sort(ia),:);
Ntrials=30; tolR=.05; tolC=.10; tolVDD=.05; VDDnom=12; fref=1000;
modelPath=fullfile(root,'models','mosfet','2N7000.onsemi.lib'); assert(isfile(modelPath),'Missing model: %s',modelPath);
mm=ModelManager(); mm=mm.registerFileModel("2N7000","MOSFET",modelPath);
optDC=struct('Analysis',"DC",'KeepFiles',true);
optAC=struct('Analysis',"AC",'ACStart',10,'ACStop',1e6,'PointsPerDecade',50, ...
 'PrintExpressions',["vm(IN)","vp(IN)","vm(GATE)","vp(GATE)","vm(DRAIN)","vp(DRAIN)"],'KeepFiles',true);
outDir=fullfile(rr,['Phase5C_Robustness_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]); if ~isfolder(outDir),mkdir(outDir);end
Trial=table();
for ci=1:height(sel)
 q=sel(ci,:); fprintf('\nCandidate %g (%d/%d)\n',q.CandidateID,ci,height(sel));
 for ti=1:Ntrials
  RGU=q.RGU_Ohm*(1+uTol(tolR)); RGL=q.RGL_Ohm*(1+uTol(tolR));
  RD=q.RD_Ohm*(1+uTol(tolR)); RS=q.RS_Ohm*(1+uTol(tolR)); CIN=q.CIN_F*(1+uTol(tolC)); VDD=VDDnom*(1+uTol(tolVDD));
  r=table(q.CandidateID,ti,RGU,RGL,RD,RS,CIN,VDD,NaN,NaN,NaN,NaN,false,false,"NOT_RUN","", ...
   'VariableNames',{'CandidateID','Trial','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V','VGS_V','VDS_V','ID_A','GainAt1kHz_dB','DCSuccess','ACSuccess','Status','ErrorMessage'});
  try
   c=makeCS(q.CandidateID*1000+ti,RGU,RGL,RD,RS,CIN,VDD);
   dc=runUniversalSpice(c,mm,optDC); if ~dc.Success,error('DC failed: %s',string(dc.ErrorMessage));end
   vg=nodeV(dc,'gate'); vs=nodeV(dc,'source'); vd=nodeV(dc,'drain');
   r.VGS_V=vg-vs; r.VDS_V=vd-vs; r.ID_A=vs/RS; r.DCSuccess=true;
   k=find(arrayfun(@(z)string(z.Name)=="VIN",c.Components),1); vin=c.Components(k);
   vin.Parameters.DC=0; vin.Parameters.AC=1; vin.Parameters.ACPhase=0; c.Components(k)=vin;
   ac=runUniversalSpice(c,mm,optAC); if ~ac.Success,error('AC failed: %s',string(ac.ErrorMessage));end
   assert(isfield(ac.ACSignals,'in')&&isfield(ac.ACSignals,'drain'),'Missing AC input/drain signals.');
   si=ac.ACSignals.in; so=ac.ACSignals.drain; f=si.Frequency(:); fo=so.Frequency(:);
   assert(numel(f)==numel(fo)&&all(abs(f-fo)<1e-9),'Frequency grid mismatch.');
   [f,ord]=sort(f); vi=si.Magnitude(ord); vo=so.Magnitude(ord); g=20*log10(max(vo./vi,realmin));
   r.GainAt1kHz_dB=interp1(log10(f),g,log10(fref),'linear'); r.ACSuccess=true; r.Status="SUCCESS";
  catch ME, r.Status="ERROR"; r.ErrorMessage=string(ME.message); end
  Trial=[Trial;r]; %#ok<AGROW>
  if mod(ti,5)==0||ti==Ntrials
   fprintf('  trial %d/%d | DC=%d AC=%d\n',ti,Ntrials,r.DCSuccess,r.ACSuccess);
   writetable(Trial,fullfile(outDir,'Phase5C_Progress.csv')); save(fullfile(outDir,'Phase5C_Progress.mat'),'Trial','sel','-v7.3');
  end
 end
end
writetable(Trial,fullfile(outDir,'Phase5C_AllTrials.csv')); ids=unique(Trial.CandidateID,'stable'); Summary=table();
for k=1:numel(ids)
 z=Trial(Trial.CandidateID==ids(k),:); good=z.ACSuccess&isfinite(z.GainAt1kHz_dB); x=z.GainAt1kHz_dB(good);
 if isempty(x), m=NaN;s=NaN;mn=NaN;p05=NaN;p95=NaN; else,m=mean(x);s=std(x);mn=min(x);p05=prctile(x,5);p95=prctile(x,95);end
 row=table(ids(k),height(z),sum(z.DCSuccess),sum(good),mean(z.DCSuccess),mean(good),m,s,mn,p05,p95, ...
 'VariableNames',{'CandidateID','Trials','DCSuccessCount','ACSuccessCount','DCSuccessRate','ACSuccessRate','MeanGain_dB','StdGain_dB','WorstObservedGain_dB','GainP05_dB','GainP95_dB'});
 Summary=[Summary;row]; %#ok<AGROW>
end
Summary=sortrows(Summary,{'ACSuccessRate','GainP05_dB'},{'descend','descend'}); writetable(Summary,fullfile(outDir,'Phase5C_Robustness_Summary.csv'));
fig=figure('Color','w'); hold on; for k=1:height(Summary), z=Trial(Trial.CandidateID==Summary.CandidateID(k)&Trial.ACSuccess,:); scatter(repmat(k,height(z),1),z.GainAt1kHz_dB,18,'filled'); end
xticks(1:height(Summary)); xticklabels(string(Summary.CandidateID)); xtickangle(45); xlabel('Candidate ID'); ylabel('Gain at 1 kHz (dB)'); title('Phase 5C tolerance Monte Carlo'); grid on;
exportgraphics(fig,fullfile(outDir,'Phase5C_Gain_Distribution.png'),'Resolution',200);
fprintf('\nPhase 5C complete. Results: %s\n',outDir); disp(Summary);
function x=uTol(t), x=(2*rand-1)*t; end
function c=makeCS(id,RGU,RGL,RD,RS,CIN,VDD)
c=createCircuit("Phase5C_CS_"+string(id)); c.Metadata.Topology="Common_Source";
c=circuitAddComponent(c,"VDD","VOLTAGE_SOURCE",["VDD","GND"],VDD);
c=circuitAddComponent(c,"VIN","VOLTAGE_SOURCE",["IN","GND"],0);
c=circuitAddComponent(c,"RD","R",["VDD","DRAIN"],RD);
c=circuitAddComponent(c,"RS","R",["SOURCE","GND"],RS);
c=circuitAddComponent(c,"RGU","R",["VDD","GATE"],RGU);
c=circuitAddComponent(c,"M1","MOSFET",["DRAIN","GATE","SOURCE"],[],"2N7000");
i=find(arrayfun(@(x)string(x.Name)=="M1",c.Components),1); m=c.Components(i); m=m.setParameter("UseSubcircuit",true); c.Components(i)=m;
c=circuitAddComponent(c,"RGL","R",["GATE","GND"],RGL); c=circuitAddComponent(c,"CIN","C",["IN","GATE"],CIN);
end
function v=nodeV(r,n)
names=lower(strtrim(string(r.NodeNames))); i=find(names==lower(string(n)),1); if isempty(i),error('Node voltage not found: %s',n);end
v=r.NodeVoltages(i); if ~isscalar(v)||~isfinite(v),error('Invalid node voltage: %s',n);end
end

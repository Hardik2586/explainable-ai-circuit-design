%% PHASE 5B: MULTIOBJECTIVE OPTIMIZATION (GAIN, POWER, DC MARGIN)
% Uses exhaustive AC results from Phase 5A.1. No model fitting; Phase 4H
% holdout is not used for training or tuning.
clear; clc; close all;
root = 'C:\Internship Project';
resultsRoot = fullfile(root,'results');
d = dir(fullfile(resultsRoot,'Phase5A_ExhaustiveAC_*')); d=d([d.isdir]);
assert(~isempty(d),'No Phase5A_ExhaustiveAC_* results folder found.');
[~,ix]=max([d.datenum]); sourceDir=fullfile(d(ix).folder,d(ix).name);
inputFile=fullfile(sourceDir,'Phase5A1_Exhaustive_AC_Ranking.csv');
assert(isfile(inputFile),'Missing exhaustive ranking: %s',inputFile);
T=readtable(inputFile);
required={'CandidateID','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDS_V','ID_A','ActualGainAt1kHz_dB'};
for k=1:numel(required)
    assert(ismember(required{k},T.Properties.VariableNames),'Required column missing: %s',required{k});
end
VDD=12; minVDS=1.0; minDrainRatio=0.15; maxDrainRatio=0.85; minID=1e-6;
% First-order DC supply-power proxy (not detailed per-device power accounting).
T.I_Divider_A=VDD./(T.RGU_Ohm+T.RGL_Ohm);
T.EstimatedSupplyCurrent_A=T.ID_A+T.I_Divider_A;
T.EstimatedSupplyPower_W=VDD.*T.EstimatedSupplyCurrent_A;
T.EstimatedSupplyPower_mW=1000.*T.EstimatedSupplyPower_W;
% In this topology VS ~= ID*RS, so VD ~= VDS + ID*RS.
T.ReconstructedVsource_V=T.ID_A.*T.RS_Ohm;
T.ReconstructedVdrain_V=T.VDS_V+T.ReconstructedVsource_V;
T.DrainVoltageRatio=T.ReconstructedVdrain_V./VDD;
% Larger margin means further from the selected DC screening boundaries.
T.MarginVDS_V=T.VDS_V-minVDS;
T.MarginDrainLow_V=T.ReconstructedVdrain_V-minDrainRatio*VDD;
T.MarginDrainHigh_V=maxDrainRatio*VDD-T.ReconstructedVdrain_V;
T.DCOperatingMargin_V=min([T.MarginVDS_V,T.MarginDrainLow_V,T.MarginDrainHigh_V],[],2);
T.DCFeasible=isfinite(T.ActualGainAt1kHz_dB)&isfinite(T.EstimatedSupplyPower_W)& ...
    isfinite(T.DCOperatingMargin_V)&T.VDS_V>=minVDS& ...
    T.DrainVoltageRatio>=minDrainRatio&T.DrainVoltageRatio<=maxDrainRatio& ...
    T.ID_A>=minID&T.ID_A<(VDD./T.RD_Ohm);
T.MeetsGainTarget=T.ActualGainAt1kHz_dB>=3;
F=T(T.DCFeasible,:); assert(~isempty(F),'No candidates meet DC feasibility rules.');
% Pareto: maximize actual gain, minimize supply power, maximize DC margin.
% Minimize transformed objectives [-gain, power, -margin].
obj=[-F.ActualGainAt1kHz_dB,F.EstimatedSupplyPower_W,-F.DCOperatingMargin_V];
n=height(F); isPareto=true(n,1); tol=1e-12;
for i=1:n
    for j=1:n
        if i==j, continue; end
        if all(obj(j,:)<=obj(i,:)+tol)&&any(obj(j,:)<obj(i,:)-tol)
            isPareto(i)=false; break;
        end
    end
end
F.IsParetoOptimal=isPareto; Pareto=F(isPareto,:);
Pareto=sortrows(Pareto,'ActualGainAt1kHz_dB','descend');
F=sortrows(F,'ActualGainAt1kHz_dB','descend');
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir=fullfile(resultsRoot,['Phase5B_Multiobjective_' stamp]);
if ~isfolder(outDir), mkdir(outDir); end
writetable(T,fullfile(outDir,'Phase5B_AllCandidates_WithObjectives.csv'));
writetable(F,fullfile(outDir,'Phase5B_DCFeasible_RankedByGain.csv'));
writetable(Pareto,fullfile(outDir,'Phase5B_Pareto_Front.csv'));
fig=figure('Color','w');
scatter(F.EstimatedSupplyPower_mW,F.ActualGainAt1kHz_dB,32,'filled'); hold on;
scatter(Pareto.EstimatedSupplyPower_mW,Pareto.ActualGainAt1kHz_dB,58,'filled');
xlabel('Estimated DC supply power (mW)'); ylabel('Actual ngspice gain at 1 kHz (dB)');
title('Phase 5B: Gain vs Power Pareto Analysis');
legend('DC-feasible candidates','Pareto-optimal candidates','Location','best'); grid on;
exportgraphics(fig,fullfile(outDir,'Phase5B_Gain_vs_Power.png'),'Resolution',200);
fig=figure('Color','w');
scatter(F.DCOperatingMargin_V,F.ActualGainAt1kHz_dB,32,'filled'); hold on;
scatter(Pareto.DCOperatingMargin_V,Pareto.ActualGainAt1kHz_dB,58,'filled');
xlabel('DC operating margin (V; larger is better)'); ylabel('Actual ngspice gain at 1 kHz (dB)');
title('Phase 5B: Gain vs DC Operating Margin');
legend('DC-feasible candidates','Pareto-optimal candidates','Location','best'); grid on;
exportgraphics(fig,fullfile(outDir,'Phase5B_Gain_vs_DC_Margin.png'),'Resolution',200);
if ~isempty(Pareto)
    bestGain=max(Pareto.ActualGainAt1kHz_dB); minPower=min(Pareto.EstimatedSupplyPower_mW);
    maxMargin=max(Pareto.DCOperatingMargin_V);
else
    bestGain=NaN; minPower=NaN; maxMargin=NaN;
end
Summary=table(string(sourceDir),height(T),sum(T.DCFeasible),height(Pareto),bestGain,minPower,maxMargin,sum(F.MeetsGainTarget), ...
 'VariableNames',{'SourceResultsFolder','ExhaustiveCandidates','DCFeasibleCandidates','ParetoCandidateCount', ...
 'BestParetoGain_dB','MinimumParetoPower_mW','MaximumParetoDCMargin_V','FeasibleGainTargetCount'});
writetable(Summary,fullfile(outDir,'Phase5B_Summary.csv'));
save(fullfile(outDir,'Phase5B_Results.mat'),'T','F','Pareto','Summary','VDD','minVDS','minDrainRatio','maxDrainRatio','minID','-v7.3');
fprintf('\nPhase 5B complete.\nSource: %s\nResults: %s\n',sourceDir,outDir);
fprintf('Exhaustive rows: %d | DC-feasible: %d | Pareto candidates: %d\n',height(T),sum(T.DCFeasible),height(Pareto));
fprintf('\nTop Pareto candidates by gain:\n');
disp(Pareto(1:min(15,height(Pareto)),{'CandidateID','RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDS_V','ID_A','ActualGainAt1kHz_dB','EstimatedSupplyPower_mW','DCOperatingMargin_V'}));

clearvars; clc; close all; rng(42,'twister');

%% Paths and development data
root = 'C:\Internship Project';
addpath(genpath(fullfile(root,'src'))); rehash;
assert(exist('runUniversalSpice','file')==2,'runUniversalSpice not found.');
assert(exist('ModelManager','class')==8 || exist('ModelManager','file')==2, ...
    'ModelManager not found.');

devMat = fullfile(root,'data','universal','Common_Source', ...
    'external_model_validation','20261020_000113','CS_Dataset_v2_100.mat');
assert(isfile(devMat),'Development dataset not found: %s',devMat);
S = load(devMat); Tdev = S.rows;

featureNames = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'CIN_F','VGS_V','VDS_V','ID_A'};
targetName = 'GainAt1kHz_dB';
lowThreshold = -10;
routingThreshold = 0.5;

validDev = logical(Tdev.SimulationValid);
for j=1:numel(featureNames)
    validDev = validDev & isfinite(Tdev.(featureNames{j}));
end
validDev = validDev & isfinite(Tdev.(targetName));
Tdev = Tdev(validDev,:);
assert(height(Tdev)>=20,'Too few valid development rows.');

Xdev = tableToFeatures(Tdev,featureNames);
Ydev = Tdev.(targetName);
isLowDev = Ydev < lowThreshold;
fprintf('Development rows: %d; low-gain rows: %d\n',height(Tdev),sum(isLowDev));

%% Fit models using development data only, then freeze them
globalModel = fitrensemble(Xdev,Ydev,'Method','Bag', ...
    'NumLearningCycles',100,'Learners',templateTree('MinLeafSize',5));
assert(numel(unique(isLowDev))==2,'Both routing classes are required.');
devClass = categorical(isLowDev,[false true],{'Other','LowGain'});
routerModel = fitcensemble(Xdev,devClass,'Method','Bag', ...
    'NumLearningCycles',100,'Learners',templateTree('MinLeafSize',3));

Xlow = Xdev(isLowDev,:); Ylow = Ydev(isLowDev);
assert(numel(Ylow)>=3,'Too few low-gain examples for ridge specialist.');
ridgeMu = mean(Xlow,1);
ridgeSigma = std(Xlow,0,1);
ridgeSigma(~isfinite(ridgeSigma) | ridgeSigma<1e-12) = 1;
ridgeModel = fitrlinear((Xlow-ridgeMu)./ridgeSigma,Ylow, ...
    'Learner','leastsquares','Regularization','ridge','Lambda',1);

frozen = struct('GlobalModel',globalModel,'RouterModel',routerModel, ...
    'RidgeModel',ridgeModel,'FeatureNames',{featureNames}, ...
    'TargetName',targetName,'LowGainThreshold_dB',lowThreshold, ...
    'RoutingProbabilityThreshold',routingThreshold,'RidgeMean',ridgeMu, ...
    'RidgeStd',ridgeSigma,'DevelopmentDataset',devMat, ...
    'DevelopmentRows',height(Tdev),'FrozenAt',datetime('now'));

%% Enumerate original grid and exclude every development configuration
RGU_values = [82e3,100e3,120e3];
RGL_values = [56e3,68e3,75e3,82e3,100e3];
RD_values = [1.8e3,2.2e3,2.7e3];
RS_values = [820,1e3,1.2e3];
CIN_values = [4.7e-6,10e-6,22e-6];
VDD = 12;

[A,B,C,D,E] = ndgrid(1:numel(RGU_values),1:numel(RGL_values), ...
    1:numel(RD_values),1:numel(RS_values),1:numel(CIN_values));
allCombos = [A(:),B(:),C(:),D(:),E(:)];
gridVals = {RGU_values,RGL_values,RD_values,RS_values,CIN_values};
devCols = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F'};
devIdx = zeros(height(Tdev),5);
for j=1:5
    for r=1:height(Tdev)
        q = find(gridVals{j}==Tdev.(devCols{j})(r),1);
        assert(~isempty(q),'Development value outside the configured grid.');
        devIdx(r,j)=q;
    end
end
devIdx = unique(devIdx,'rows');
freshCombos = allCombos(~ismember(allCombos,devIdx,'rows'),:);
fprintf('Full grid: %d; excluded development configs: %d; fresh available: %d\n', ...
    size(allCombos,1),size(devIdx,1),size(freshCombos,1));

Ntest = min(100,size(freshCombos,1));
assert(Ntest>=20,'Not enough fresh configurations.');
rng(20261020,'twister');
freshCombos = freshCombos(randperm(size(freshCombos,1),Ntest),:);

%% Register model and configure simulator
modelPath = fullfile(root,'models','mosfet','2N7000.onsemi.lib');
assert(isfile(modelPath),'2N7000 model file not found: %s',modelPath);
modelManager = ModelManager();
modelManager = modelManager.registerFileModel("2N7000","MOSFET",modelPath);

optionsDC = struct('Analysis',"DC",'KeepFiles',true);
optionsAC = struct();
optionsAC.Analysis = "AC"; optionsAC.ACStart = 10;
optionsAC.ACStop = 1e6; optionsAC.PointsPerDecade = 50;
optionsAC.PrintExpressions = ["vm(IN)","vp(IN)","vm(GATE)","vp(GATE)", ...
    "vm(DRAIN)","vp(DRAIN)"];
optionsAC.KeepFiles = true;
referenceFrequency_Hz = 1000;

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
testDir = fullfile(root,'data','universal','Common_Source', ...
    'Phase4H_IndependentValidation',stamp);
outDir = fullfile(root,'results',['Phase4H_IndependentValidation_' stamp]);
if ~isfolder(testDir), mkdir(testDir); end
if ~isfolder(outDir), mkdir(outDir); end

rows = table(); acResponses = cell(Ntest,1);

%% Simulate fresh configurations
for i=1:Ntest
    fprintf('\nFresh configuration %d/%d\n',i,Ntest);
    RGU=RGU_values(freshCombos(i,1));
    RGL=RGL_values(freshCombos(i,2));
    RD=RD_values(freshCombos(i,3));
    RS=RS_values(freshCombos(i,4));
    CIN=CIN_values(freshCombos(i,5));

    row = table(i,RGU,RGL,RD,RS,CIN,VDD,NaN,NaN,NaN,NaN,NaN,NaN, ...
        NaN,NaN,NaN,NaN,NaN,NaN,false,false,false, ...
        "NOT_RUN","NOT_RUN","", ...
        'VariableNames',{'CircuitID','RGU_Ohm','RGL_Ohm','RD_Ohm', ...
        'RS_Ohm','CIN_F','VDD_V','Vgate_V','Vsource_V','Vdrain_V', ...
        'VGS_V','VDS_V','ID_A','PeakGain_VV','PeakGain_dB', ...
        'PeakGainFrequency_Hz','GainAt1kHz_VV','GainAt1kHz_dB', ...
        'PhaseAt1kHz_deg','DCSuccess','ACSuccess','SimulationValid', ...
        'DCStatus','ACStatus','ErrorMessage'});

    try
        circuit = createCircuit("Phase4H_CS_"+string(i));
        circuit.Metadata.Topology = "Common_Source";
        circuit = circuitAddComponent(circuit,"VDD","VOLTAGE_SOURCE",["VDD","GND"],VDD);
        circuit = circuitAddComponent(circuit,"VIN","VOLTAGE_SOURCE",["IN","GND"],0);
        circuit = circuitAddComponent(circuit,"RD","R",["VDD","DRAIN"],RD);
        circuit = circuitAddComponent(circuit,"RS","R",["SOURCE","GND"],RS);
        circuit = circuitAddComponent(circuit,"RGU","R",["VDD","GATE"],RGU);
        circuit = circuitAddComponent(circuit,"M1","MOSFET", ...
            ["DRAIN","GATE","SOURCE"],[],"2N7000");

        idxM1 = find(arrayfun(@(c) string(c.Name)=="M1",circuit.Components),1);
        assert(~isempty(idxM1),'MOSFET M1 not found.');
        mosfet = circuit.Components(idxM1);
        mosfet = mosfet.setParameter("UseSubcircuit",true);
        circuit.Components(idxM1)=mosfet;
        circuit = circuitAddComponent(circuit,"RGL","R",["GATE","GND"],RGL);
        circuit = circuitAddComponent(circuit,"CIN","C",["IN","GATE"],CIN);

        idxVIN = find(arrayfun(@(c) string(c.Name)=="VIN",circuit.Components),1);
        assert(~isempty(idxVIN),'VIN not found.');
        vin = circuit.Components(idxVIN);
        vin.Parameters.DC=0; vin.Parameters.AC=1; vin.Parameters.ACPhase=0;
        circuit.Components(idxVIN)=vin;

        dc = runUniversalSpice(circuit,modelManager,optionsDC);
        row.DCSuccess = logical(dc.Success);
        if ~dc.Success
            row.DCStatus="FAILED"; row.ACStatus="SKIPPED_DC_FAILURE";
            row.ErrorMessage=string(dc.ErrorMessage);
            rows=appendRow(rows,row); continue;
        end
        row.DCStatus="SUCCESS";
        row.Vgate_V=getNodeVoltage(dc,"gate");
        row.Vsource_V=getNodeVoltage(dc,"source");
        row.Vdrain_V=getNodeVoltage(dc,"drain");
        row.VGS_V=row.Vgate_V-row.Vsource_V;
        row.VDS_V=row.Vdrain_V-row.Vsource_V;
        row.ID_A=row.Vsource_V/RS;

        ac = runUniversalSpice(circuit,modelManager,optionsAC);
        row.ACSuccess=logical(ac.Success);
        if ~ac.Success
            row.ACStatus="FAILED";
            row.ErrorMessage=appendError(row.ErrorMessage,string(ac.ErrorMessage));
            rows=appendRow(rows,row); continue;
        end
        assert(~isempty(ac.ACSignals),'AC signals empty.');
        sigNames=lower(string(fieldnames(ac.ACSignals)));
        assert(all(ismember(["in","drain"],sigNames)),'IN/DRAIN AC signals missing.');
        inSig=ac.ACSignals.in; outSig=ac.ACSignals.drain;
        f=inSig.Frequency(:); fOut=outSig.Frequency(:);
        Vin=inSig.Magnitude(:); Vout=outSig.Magnitude(:);
        phaseIn=inSig.Phase(:); phaseOut=outSig.Phase(:);
        assert(~isempty(f) && numel(f)==numel(fOut),'Frequency arrays invalid.');
        assert(all(abs(f-fOut)<=1e-9),'Input/output frequency grids differ.');
        assert(numel(Vin)==numel(f) && numel(Vout)==numel(f) && ...
            numel(phaseIn)==numel(f) && numel(phaseOut)==numel(f), ...
            'AC array lengths differ.');
        assert(all(isfinite(f)) && all(f>0) && all(isfinite(Vin)) && ...
            all(isfinite(Vout)) && all(isfinite(phaseIn)) && ...
            all(isfinite(phaseOut)) && all(Vin>0) && all(Vout>=0), ...
            'AC response has invalid values.');
        [f,ord]=sort(f); Vin=Vin(ord); Vout=Vout(ord);
        phaseIn=phaseIn(ord); phaseOut=phaseOut(ord);
        assert(numel(unique(f))==numel(f),'Duplicate frequencies.');
        gainVV=Vout./Vin; gainDB=20*log10(max(gainVV,realmin));
        phaseDiff=rad2deg(unwrap(phaseOut-phaseIn));
        phaseWrapped=mod(phaseDiff+180,360)-180;
        [row.PeakGain_VV,kPeak]=max(gainVV);
        row.PeakGain_dB=gainDB(kPeak);
        row.PeakGainFrequency_Hz=f(kPeak);
        assert(referenceFrequency_Hz>=min(f) && referenceFrequency_Hz<=max(f), ...
            '1 kHz outside AC sweep.');
        row.GainAt1kHz_dB=interp1(log10(f),gainDB,log10(referenceFrequency_Hz),'linear');
        row.GainAt1kHz_VV=10^(row.GainAt1kHz_dB/20);
        phaseRef=interp1(log10(f),phaseDiff,log10(referenceFrequency_Hz),'linear');
        row.PhaseAt1kHz_deg=mod(phaseRef+180,360)-180;
        acResponses{i}=struct('CircuitID',i,'Frequency_Hz',f, ...
            'InputMagnitude_V',Vin,'OutputMagnitude_V',Vout,'Gain_VV',gainVV, ...
            'Gain_dB',gainDB,'InputPhase_rad',phaseIn,'OutputPhase_rad',phaseOut, ...
            'PhaseDifference_deg',phaseWrapped);
        row.ACStatus="SUCCESS";
        row.SimulationValid=all(isfinite([row.VGS_V,row.VDS_V,row.ID_A, ...
            row.GainAt1kHz_dB,row.PeakGain_dB]));
    catch ME
        row.ErrorMessage=appendError(row.ErrorMessage,string(ME.message));
        if row.DCSuccess && row.ACStatus=="NOT_RUN", row.ACStatus="FAILED"; end
        fprintf('Circuit %d error: %s\n',i,ME.message);
    end
    rows=appendRow(rows,row);
    fprintf('DC=%s | AC=%s | Valid=%d\n',row.DCStatus,row.ACStatus,row.SimulationValid);
end

%% Save raw test data before model evaluation
writetable(rows,fullfile(testDir,'Phase4H_FreshCircuitDataset.csv'));
config = struct('DatasetPurpose',"Independent configuration validation", ...
    'DevelopmentDataset',devMat,'RandomSeed',20261020,'NRequested',Ntest, ...
    'VDD_V',VDD,'ModelPath',modelPath,'ModelName',"2N7000", ...
    'ACStart_Hz',optionsAC.ACStart,'ACStop_Hz',optionsAC.ACStop, ...
    'PointsPerDecade',optionsAC.PointsPerDecade, ...
    'ReferenceFrequency_Hz',referenceFrequency_Hz);
save(fullfile(testDir,'Phase4H_FreshCircuitDataset.mat'), ...
    'rows','acResponses','config','-v7.3');

%% Evaluate frozen models once on valid fresh simulations
validTest=logical(rows.SimulationValid);
for j=1:numel(featureNames), validTest=validTest & isfinite(rows.(featureNames{j})); end
validTest=validTest & isfinite(rows.(targetName));
Ttest=rows(validTest,:);
fprintf('\nAttempted: %d | Valid fresh circuits: %d | Failed/invalid: %d\n', ...
    height(rows),height(Ttest),height(rows)-height(Ttest));
assert(height(Ttest)>=1,'No valid fresh circuits to evaluate.');

Xtest=tableToFeatures(Ttest,featureNames);
Ytest=Ttest.(targetName);
predGlobal=predict(frozen.GlobalModel,Xtest);
[~,scores]=predict(frozen.RouterModel,Xtest);
classNames=string(frozen.RouterModel.ClassNames);
lowColumn=find(classNames=="LowGain",1);
assert(~isempty(lowColumn),'LowGain class missing from router.');
probLow=scores(:,lowColumn);
route=probLow>=frozen.RoutingProbabilityThreshold;
predLow=predict(frozen.RidgeModel,(Xtest-frozen.RidgeMean)./frozen.RidgeStd);
predRouted=predGlobal;
predRouted(route)=predLow(route);

eGlobal=Ytest-predGlobal; eRouted=Ytest-predRouted;
SST=sum((Ytest-mean(Ytest)).^2);
Model=["Frozen_Global_BaggedTrees";"Frozen_Routed_Ridge_Specialist"];
MAE=[mean(abs(eGlobal));mean(abs(eRouted))];
RMSE=[sqrt(mean(eGlobal.^2));sqrt(mean(eRouted.^2))];
if SST>0, R2=[1-sum(eGlobal.^2)/SST;1-sum(eRouted.^2)/SST];
else, R2=[NaN;NaN]; end
Overall=table(Model,MAE,RMSE,R2);
fprintf('\n===== PHASE 4H INDEPENDENT TEST METRICS =====\n'); disp(Overall);

actualLow=Ytest<lowThreshold;
Group=["Actual gain below -10 dB";"Actual gain at least -10 dB"];
Count=[sum(actualLow);sum(~actualLow)];
GlobalMAE=[groupMAE(eGlobal,actualLow);groupMAE(eGlobal,~actualLow)];
RoutedMAE=[groupMAE(eRouted,actualLow);groupMAE(eRouted,~actualLow)];
GlobalRMSE=[groupRMSE(eGlobal,actualLow);groupRMSE(eGlobal,~actualLow)];
RoutedRMSE=[groupRMSE(eRouted,actualLow);groupRMSE(eRouted,~actualLow)];
ByGroup=table(Group,Count,GlobalMAE,RoutedMAE,GlobalRMSE,RoutedRMSE);
fprintf('\n===== METRICS BY ACTUAL TARGET GROUP =====\n'); disp(ByGroup);

TP=sum(route & actualLow); FP=sum(route & ~actualLow);
FN=sum(~route & actualLow); TN=sum(~route & ~actualLow);
Recall=TP/max(TP+FN,1); Precision=TP/max(TP+FP,1);
Specificity=TN/max(TN+FP,1);
RoutingMetrics=table(TP,FP,FN,TN,Recall,Precision,Specificity);
fprintf('\n===== FRESH TEST ROUTING METRICS =====\n'); disp(RoutingMetrics);

Predictions=table(Ttest.CircuitID,Ytest,predGlobal,predRouted,abs(eGlobal), ...
    abs(eRouted),probLow,route,actualLow,'VariableNames', ...
    {'CircuitID','ActualGain_dB','GlobalPrediction_dB','RoutedPrediction_dB', ...
    'GlobalAbsoluteError_dB','RoutedAbsoluteError_dB', ...
    'PredictedLowGainProbability','RoutedToSpecialist','ActualLowGain'});
Predictions.ErrorImprovement_dB=Predictions.GlobalAbsoluteError_dB- ...
    Predictions.RoutedAbsoluteError_dB;

save(fullfile(outDir,'Phase4H_FrozenDevelopmentModels.mat'),'frozen','-v7.3');
writetable(Overall,fullfile(outDir,'Phase4H_Overall_Metrics.csv'));
writetable(ByGroup,fullfile(outDir,'Phase4H_Group_Metrics.csv'));
writetable(RoutingMetrics,fullfile(outDir,'Phase4H_Routing_Metrics.csv'));
writetable(Predictions,fullfile(outDir,'Phase4H_FreshTest_Predictions.csv'));
summary=struct('DevelopmentDataset',devMat, ...
    'FreshTestDataset',fullfile(testDir,'Phase4H_FreshCircuitDataset.mat'), ...
    'RequestedFreshCircuits',Ntest,'ValidFreshCircuits',height(Ttest), ...
    'FailedOrInvalidFreshCircuits',height(rows)-height(Ttest), ...
    'FreshLowGainCount',sum(actualLow),'RoutingThreshold',routingThreshold, ...
    'LowGainThreshold_dB',lowThreshold, ...
    'Notes',["Models fitted only on development data."; ...
    "Fresh targets not used for model fitting or threshold selection."; ...
    "Validation is within common-source topology and the discrete design grid."]);
save(fullfile(outDir,'Phase4H_Summary.mat'),'summary');

fig=figure('Color','w');
scatter(Ytest,predGlobal,45,'filled'); hold on;
scatter(Ytest,predRouted,45,'filled');
lo=min([Ytest;predGlobal;predRouted]); hi=max([Ytest;predGlobal;predRouted]);
plot([lo hi],[lo hi],'k--','LineWidth',1.4);
xlabel('Actual gain at 1 kHz (dB)'); ylabel('Predicted gain at 1 kHz (dB)');
title('Phase 4H: Fresh Configuration Validation');
legend('Frozen global model','Frozen routed specialist','Ideal prediction','Location','best');
grid on;
exportgraphics(fig,fullfile(outDir,'Phase4H_Actual_vs_Predicted.png'),'Resolution',200);

fig=figure('Color','w');
scatter(Ytest,abs(eGlobal),45,'filled'); hold on;
scatter(Ytest,abs(eRouted),45,'filled');
xlabel('Actual gain at 1 kHz (dB)'); ylabel('Absolute error (dB)');
title('Phase 4H: Fresh Test Absolute Errors');
legend('Frozen global model','Frozen routed specialist','Location','best');
grid on;
exportgraphics(fig,fullfile(outDir,'Phase4H_Absolute_Errors.png'),'Resolution',200);

fprintf('\nPhase 4H complete.\nFresh dataset: %s\nResults: %s\n',testDir,outDir);

%% Local helpers
function X=tableToFeatures(T,names)
    X=zeros(height(T),numel(names));
    for ii=1:numel(names), X(:,ii)=T.(names{ii}); end
end
function value=getNodeVoltage(result,nodeName)
    names=lower(strtrim(string(result.NodeNames)));
    idx=find(names==lower(string(nodeName)),1);
    if isempty(idx), error('Node voltage not found: %s',nodeName); end
    value=result.NodeVoltages(idx);
    if ~isscalar(value) || ~isfinite(value)
        error('Invalid node voltage returned for %s.',nodeName);
    end
end
function outRows=appendRow(outRows,row)
    if isempty(outRows), outRows=row; else, outRows=[outRows;row]; end
end
function out=appendError(existing,newError)
    existing=string(existing); newError=string(newError);
    if strlength(existing)==0, out=newError;
    elseif strlength(newError)==0, out=existing;
    else, out=existing+" | "+newError; end
end
function value=groupMAE(errors,mask)
    if any(mask), value=mean(abs(errors(mask))); else, value=NaN; end
end
function value=groupRMSE(errors,mask)
    if any(mask), value=sqrt(mean(errors(mask).^2)); else, value=NaN; end
end

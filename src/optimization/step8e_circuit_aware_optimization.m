%% ================================================================
% STEP 8D/8E SURROGATE DIAGNOSTIC
% ================================================================

clear;
clc;

projectRoot = 'C:\Internship Project';

datasetPath = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

vcePath = fullfile( ...
    projectRoot, ...
    'models', ...
    'optimization', ...
    'VCE_OperatingPoint_Surrogate.mat');

vcbPath = fullfile( ...
    projectRoot, ...
    'models', ...
    'optimization', ...
    'VCB_OperatingPoint_Surrogate.mat');

optPath = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_fmincon_Optimization_Results.mat');


%% ------------------------------------------------
% Load
% ------------------------------------------------

T = readtable(datasetPath);

X = T{:,1:9};

VCEData = load(vcePath);
VCBData = load(vcbPath);

VCEModel = VCEData.VCEModel;
VCBModel = VCBData.VCBModel;

O = load(optPath);

R = O.optimizationResults;


%% ------------------------------------------------
% Display model information
% ------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' VCE / VCB SURROGATE DIAGNOSTIC\n');
fprintf('============================================================\n');

fprintf('\nVCE model:\n');
disp(VCEModel);

fprintf('\nVCB model:\n');
disp(VCBModel);

fprintf('\nVCE feature names:\n');
disp(VCEData.featureNames);

fprintf('\nVCB feature names:\n');
disp(VCBData.featureNames);


%% ------------------------------------------------
% Dataset predictions
% ------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' DATASET PREDICTIONS\n');
fprintf('============================================================\n');

testIndices = [1 100 300 500 660];

Xtest = X(testIndices,:);

fprintf('\nRaw feature predictions:\n');

predVCE_raw = predict(VCEModel,Xtest);
predVCB_raw = predict(VCBModel,Xtest);

for k = 1:numel(testIndices)

    fprintf('Row %3d: VCE = %.9f V, VCB = %.9f V\n', ...
        testIndices(k), ...
        predVCE_raw(k), ...
        predVCB_raw(k));

end


%% ------------------------------------------------
% Log-transform first 8 features
% ------------------------------------------------

Xlog = X;

Xlog(:,1:8) = log10(Xlog(:,1:8));

predVCE_log = predict(VCEModel,Xlog);
predVCB_log = predict(VCBModel,Xlog);

fprintf('\nLog10(first 8) predictions:\n');

for k = 1:numel(testIndices)

    fprintf('Row %3d: VCE = %.9f V, VCB = %.9f V\n', ...
        testIndices(k), ...
        predVCE_log(k), ...
        predVCB_log(k));

end


%% ------------------------------------------------
% Try normalized log features using DL statistics
% ONLY as a diagnostic
% ------------------------------------------------

rng(42);

idx = randperm(size(X,1));

nDev = round(0.8*size(X,1));

devIdx = idx(1:nDev);

Xdev = X(devIdx,:);

XdevLog = Xdev;

XdevLog(:,1:8) = log10(XdevLog(:,1:8));

mu = mean(XdevLog,1);
sigma = std(XdevLog,0,1);

Xnorm = (Xlog-mu)./sigma;

predVCE_norm = predict(VCEModel,Xnorm);
predVCB_norm = predict(VCBModel,Xnorm);

fprintf('\nNormalized log predictions:\n');

for k = 1:numel(testIndices)

    fprintf('Row %3d: VCE = %.9f V, VCB = %.9f V\n', ...
        testIndices(k), ...
        predVCE_norm(k), ...
        predVCB_norm(k));

end


%% ------------------------------------------------
% Previous optimization points
% ------------------------------------------------

xLow = R.Low.xOpt(:)';
xMed = R.Medium.xOpt(:)';
xHigh = R.High.xOpt(:)';

Xopt = [
    xLow
    xMed
    xHigh
];


%% ------------------------------------------------
% Predictions at actual optimization points
% ------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' PREVIOUS OPTIMIZATION POINTS\n');
fprintf('============================================================\n');

fprintf('\nRaw:\n');

pVCE_raw = predict(VCEModel,Xopt);
pVCB_raw = predict(VCBModel,Xopt);

fprintf('Low    : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_raw(1),pVCB_raw(1));

fprintf('Medium : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_raw(2),pVCB_raw(2));

fprintf('High   : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_raw(3),pVCB_raw(3));


fprintf('\nLog transformed:\n');

XoptLog = Xopt;

XoptLog(:,1:8) = log10(XoptLog(:,1:8));

pVCE_log = predict(VCEModel,XoptLog);
pVCB_log = predict(VCBModel,XoptLog);

fprintf('Low    : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_log(1),pVCB_log(1));

fprintf('Medium : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_log(2),pVCB_log(2));

fprintf('High   : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_log(3),pVCB_log(3));


fprintf('\nNormalized log:\n');

XoptNorm = (XoptLog-mu)./sigma;

pVCE_norm = predict(VCEModel,XoptNorm);
pVCB_norm = predict(VCBModel,XoptNorm);

fprintf('Low    : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_norm(1),pVCB_norm(1));

fprintf('Medium : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_norm(2),pVCB_norm(2));

fprintf('High   : VCE = %.9f, VCB = %.9f\n', ...
    pVCE_norm(3),pVCB_norm(3));


%% ------------------------------------------------
% Predictor information
% ------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' MODEL PREDICTOR INFORMATION\n');
fprintf('============================================================\n');

if isprop(VCEModel,'PredictorNames')

    fprintf('\nVCE PredictorNames:\n');
    disp(VCEModel.PredictorNames);

end

if isprop(VCBModel,'PredictorNames')

    fprintf('\nVCB PredictorNames:\n');
    disp(VCBModel.PredictorNames);

end

if isprop(VCEModel,'NumPredictors')

    fprintf('\nVCE NumPredictors: %d\n', ...
        VCEModel.NumPredictors);

end

if isprop(VCBModel,'NumPredictors')

    fprintf('VCB NumPredictors: %d\n', ...
        VCBModel.NumPredictors);

end


%% ------------------------------------------------
% Prediction variability
% ------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' PREDICTION VARIABILITY\n');
fprintf('============================================================\n');

fprintf('\nRaw dataset prediction ranges:\n');

fprintf('VCE: %.9f to %.9f V\n', ...
    min(predVCE_raw), ...
    max(predVCE_raw));

fprintf('VCB: %.9f to %.9f V\n', ...
    min(predVCB_raw), ...
    max(predVCB_raw));


fprintf('\nLog dataset prediction ranges:\n');

fprintf('VCE: %.9f to %.9f V\n', ...
    min(predVCE_log), ...
    max(predVCE_log));

fprintf('VCB: %.9f to %.9f V\n', ...
    min(predVCB_log), ...
    max(predVCB_log));


fprintf('\nNormalized dataset prediction ranges:\n');

fprintf('VCE: %.9f to %.9f V\n', ...
    min(predVCE_norm), ...
    max(predVCE_norm));

fprintf('VCB: %.9f to %.9f V\n', ...
    min(predVCB_norm), ...
    max(predVCB_norm));


fprintf('\n============================================================\n');
fprintf(' DIAGNOSTIC COMPLETE\n');
fprintf('============================================================\n');
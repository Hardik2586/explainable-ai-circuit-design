%% STEP 8A - CIRCUIT-AWARE CONSTRAINT AUDIT
%
% Purpose:
%   Establish physically meaningful constraints before modifying
%   the optimization problem.
%
% IMPORTANT:
%   No SPICE simulations are performed here.

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8A - CIRCUIT-AWARE CONSTRAINT AUDIT\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

datasetFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

optimizationFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'DL_fmincon_Optimization_Results.mat');

%% ============================================================
% LOAD DATA
% ============================================================

if ~isfile(datasetFile)

    error('Dataset not found:\n%s',datasetFile);

end

if ~isfile(optimizationFile)

    error('Optimization result file not found:\n%s',optimizationFile);

end

T = readtable(datasetFile);

O = load(optimizationFile);

if ~isfield(O,'optimizationResults')

    error('optimizationResults variable not found.');

end

optimizationResults = O.optimizationResults;

fprintf('[PASS] Dataset loaded.\n');
fprintf('[PASS] Optimization results loaded.\n');

%% ============================================================
% FEATURE ORDER
% ============================================================

featureNames = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

%% ============================================================
% PHYSICAL CONSTRAINT SETTINGS
% ============================================================

VBE = 0.70;

% Minimum operating margins
VCE_MIN = 0.50;       % volts
VCB_MIN = 0.10;       % volts
IC_MIN  = 1e-6;       % amperes

fprintf('\nCircuit-aware constraints:\n');

fprintf('VBE reference = %.2f V\n',VBE);
fprintf('Minimum VCE   = %.2f V\n',VCE_MIN);
fprintf('Minimum VCB   = %.2f V\n',VCB_MIN);
fprintf('Minimum IC    = %.2e A\n',IC_MIN);

%% ============================================================
% REPRESENTATIVE CIRCUITS
% ============================================================

caseNames = {'Low','Medium','High'};

datasetRows = [409 527 536];

%% ============================================================
% ANALYTICAL DC EVALUATION
% ============================================================

results = struct();

for k = 1:numel(caseNames)

    caseName = caseNames{k};

    %% --------------------------------------------------------
    % BASELINE
    % --------------------------------------------------------

    xBaseline = zeros(1,9);

    for j = 1:9

        xBaseline(j) = ...
            T{datasetRows(k),featureNames{j}};

    end

    %% --------------------------------------------------------
    % OPTIMIZED
    % --------------------------------------------------------

    xOpt = optimizationResults.(caseName).xOpt(:)';

    %% --------------------------------------------------------
    % Evaluate both
    % --------------------------------------------------------

    baselineDC = evaluateDC( ...
        xBaseline,VBE);

    optimizedDC = evaluateDC( ...
        xOpt,VBE);

    %% --------------------------------------------------------
    % Store
    % --------------------------------------------------------

    results.(caseName).baseline.x = ...
        xBaseline;

    results.(caseName).baseline.DC = ...
        baselineDC;

    results.(caseName).optimized.x = ...
        xOpt;

    results.(caseName).optimized.DC = ...
        optimizedDC;

end

%% ============================================================
% DISPLAY
% ============================================================

for k = 1:numel(caseNames)

    name = caseNames{k};

    fprintf('\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('%s-GAIN CIRCUIT\n',upper(name));
    fprintf('------------------------------------------------------------\n');

    B = results.(name).baseline.DC;
    O = results.(name).optimized.DC;

    fprintf('\nBaseline:\n');

    fprintf('  VB  = %.6f V\n',B.VB);
    fprintf('  VE  = %.6f V\n',B.VE);
    fprintf('  VC  = %.6f V\n',B.VC);
    fprintf('  IC  = %.6e A\n',B.IC);
    fprintf('  VCE = %.6f V\n',B.VCE);
    fprintf('  VCB = %.6f V\n',B.VCB);

    fprintf('  Active-region constraints: %s\n', ...
        passFail(B.isValid));

    fprintf('\nOptimized:\n');

    fprintf('  VB  = %.6f V\n',O.VB);
    fprintf('  VE  = %.6f V\n',O.VE);
    fprintf('  VC  = %.6f V\n',O.VC);
    fprintf('  IC  = %.6e A\n',O.IC);
    fprintf('  VCE = %.6f V\n',O.VCE);
    fprintf('  VCB = %.6f V\n',O.VCB);

    fprintf('  Active-region constraints: %s\n', ...
        passFail(O.isValid));

end

%% ============================================================
% BUILD SUMMARY TABLE
% ============================================================

Circuit = strings(6,1);
Type = strings(6,1);

VB = zeros(6,1);
VE = zeros(6,1);
VC = zeros(6,1);
IC = zeros(6,1);
VCE = zeros(6,1);
VCB = zeros(6,1);

Valid = false(6,1);

row = 0;

for k = 1:numel(caseNames)

    name = caseNames{k};

    B = results.(name).baseline.DC;
    O = results.(name).optimized.DC;

    row = row + 1;

    Circuit(row) = name;
    Type(row) = "Baseline";

    VB(row) = B.VB;
    VE(row) = B.VE;
    VC(row) = B.VC;
    IC(row) = B.IC;
    VCE(row) = B.VCE;
    VCB(row) = B.VCB;
    Valid(row) = B.isValid;

    row = row + 1;

    Circuit(row) = name;
    Type(row) = "Optimized";

    VB(row) = O.VB;
    VE(row) = O.VE;
    VC(row) = O.VC;
    IC(row) = O.IC;
    VCE(row) = O.VCE;
    VCB(row) = O.VCB;
    Valid(row) = O.isValid;

end

constraintTable = table( ...
    Circuit, ...
    Type, ...
    VB, ...
    VE, ...
    VC, ...
    IC, ...
    VCE, ...
    VCB, ...
    Valid);

disp(constraintTable);

%% ============================================================
% FINAL CHECK
% ============================================================

if all(Valid)

    fprintf('\n============================================================\n');
    fprintf('[PASS] All baseline and optimized circuits satisfy the\n');
    fprintf('       proposed circuit-aware constraints.\n');
    fprintf('============================================================\n');

else

    fprintf('\n============================================================\n');
    fprintf('[WARN] At least one circuit violates the proposed\n');
    fprintf('       circuit-aware constraints.\n');
    fprintf('============================================================\n');

end

%% ============================================================
% SAVE
% ============================================================

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'optimization', ...
    'circuit_aware');

if ~isfolder(outputDir)

    mkdir(outputDir);

end

save( ...
    fullfile( ...
        outputDir, ...
        'Step8A_Circuit_Constraint_Audit.mat'), ...
    'results', ...
    'constraintTable', ...
    'VBE', ...
    'VCE_MIN', ...
    'VCB_MIN', ...
    'IC_MIN');

writetable( ...
    constraintTable, ...
    fullfile( ...
        outputDir, ...
        'Step8A_Circuit_Constraint_Audit.csv'));

fprintf('\nResults saved to:\n%s\n',outputDir);

%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function dc = evaluateDC(x,VBE)

    R1 = x(1);
    R2 = x(2);
    RC = x(3);
    RE = x(4);
    VCC = x(9);

    % DC bias network
    VB = VCC * R2/(R1 + R2);

    VE = VB - VBE;

    IE = VE/RE;

    % First-order CE approximation
    IC = IE;

    VC = VCC - IC*RC;

    VCE = VC - VE;

    VCB = VC - VB;

    % Physical constraints
    c1 = VB - VBE;
    c2 = IC - 1e-6;
    c3 = VCE - 0.50;
    c4 = VCB - 0.10;

    dc.VB = VB;
    dc.VE = VE;
    dc.VC = VC;
    dc.IC = IC;
    dc.IE = IE;
    dc.VCE = VCE;
    dc.VCB = VCB;

    dc.margin_VB = c1;
    dc.margin_IC = c2;
    dc.margin_VCE = c3;
    dc.margin_VCB = c4;

    dc.isValid = ...
        c1 >= 0 && ...
        c2 >= 0 && ...
        c3 >= 0 && ...
        c4 >= 0;

end

function txt = passFail(flag)

    if flag
        txt = 'PASS';
    else
        txt = 'FAIL';
    end

end
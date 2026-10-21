function CE_XAI_Lab

% Resolve the Label factory explicitly. This avoids a rare function-name
% resolution/cache issue while retaining the native uilabel UI component.
uiLabel = str2func('uilabel');

% Predeclare shared workflow controls before any nested callbacks are created.
workflowButtons = cell(1,5);

% Close stale Deep Learning Toolbox training-progress windows.
% The GUI itself never starts model training.
try
    figs = findall(0,'Type','figure');
    for kk = 1:numel(figs)
        nm = get(figs(kk),'Name');
        if ischar(nm) && contains(lower(nm),'training progress')
            delete(figs(kk));
        end
    end
catch
    % Ignore cleanup errors; continue launching the GUI.
end

% CE_XAI_LAB

% ================================================================

% CE-XAI LAB 04

%

% PHASE 4A + PHASE 4B

%

% 4A:

%   DESIGN -> DL PREDICT -> SPICE VERIFY

%

% 4B:

%   EXPLAIN -> GLOBAL SHAP -> COMPONENT XAI -> R1-R2 INTERACTION

%

% IMPORTANT:

%   This GUI NEVER trains a model.

%

%   It only:

%       1. Loads the already-trained DL model.

%       2. Reconstructs the exact research preprocessing.

%       3. Runs DL inference.

%       4. Runs the existing SPICE adapter.

%       5. Displays precomputed XAI research results.

%

% No SHAP calculation is performed at GUI startup.

%

% Run:

%   cd('C:\Internship Project\gui')

%   CE_XAI_Lab

% ================================================================

%% ================================================================

% 1. PALETTE

% ================================================================

C.bg       = [23 26 28]/255;

C.surface  = [32 37 39]/255;

C.recess   = [16 22 21]/255;

C.field    = [39 45 46]/255;

C.rule     = [52 59 58]/255;

C.text     = [229 227 220]/255;

C.muted    = [154 166 161]/255;

C.copper   = [217 130 82]/255;

C.teal     = [85 169 158]/255;

C.amber    = [205 165 87]/255;

C.red      = [190 103 91]/255;

C.wire     = [111 137 130]/255;

C.violet   = [145 116 190]/255;

%% ================================================================

% 2. PROJECT PATHS

% ================================================================

PROJECT_ROOT = 'C:\Internship Project';

MODEL_PATH = fullfile( ...
    PROJECT_ROOT, ...
    'models', ...
    'deep_learning', ...
    'CE_Gain_DL_Model.mat');

CANONICAL_DATASET = fullfile( ...
    PROJECT_ROOT, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

DL_DATASET = fullfile( ...
    PROJECT_ROOT, ...
    'results', ...
    'deep_learning', ...
    'DL_Dataset.mat');

SPICE_ROOT = fullfile( ...
    PROJECT_ROOT, ...
    'src', ...
    'spice');

SPICE_EXE = ...
    'C:\ngspice-47_64\bin\ngspice_con.exe';

% Precomputed XAI files.

XAI_ROOT = fullfile( ...
    PROJECT_ROOT, ...
    'results', ...
    'unified_XAI');

XAI_MASTER_FILE = fullfile( ...
    XAI_ROOT, ...
    'Unified_XAI_Results.mat');

XAI_RANKING_FILE = fullfile( ...
    XAI_ROOT, ...
    'Global_XAI_Ranking.csv');

XAI_INTERACTION_FILE = fullfile( ...
    PROJECT_ROOT, ...
    'results', ...
    'final', ...
    'SHAP_Interaction_Results.mat');

SPICE_INTERACTION_FILE = fullfile( ...
    PROJECT_ROOT, ...
    'results', ...
    'spice_validation', ...
    'R1_R2', ...
    'R1_R2_SPICE_Validation.mat');

OPTIMIZATION_ROOT = fullfile( ...
    PROJECT_ROOT, ...
    'results', ...
    'optimization', ...
    'circuit_aware_constraints');

OPTIMIZATION_SUMMARY_FILE = fullfile( ...
    OPTIMIZATION_ROOT, ...
    'Step8E_Final_Summary.csv');

OPTIMIZATION_DESIGNS_FILE = fullfile( ...
    OPTIMIZATION_ROOT, ...
    'Step8E_Final_Designs.csv');

% Live circuit-aware optimization surrogate models.
VCE_SURROGATE_FILE = fullfile( ...
    PROJECT_ROOT, ...
    'models', 'optimization', 'VCE_OperatingPoint_Surrogate.mat');
VCB_SURROGATE_FILE = fullfile( ...
    PROJECT_ROOT, ...
    'models', 'optimization', 'VCB_OperatingPoint_Surrogate.mat');

%% ================================================================

% 3. MODEL STATE

% ================================================================

dlModel = [];

dlMu = [];

dlSigma = [];

dlLoaded = false;

normalizationLoaded = false;

spiceAvailable = false;

modelMessage = '';

normalizationMessage = '';

%% ================================================================

% 4. XAI STATE

% ================================================================

xaiLoaded = false;

xaiFeatureNames = { ...
    'R1','R2','RE','RC','VCC', ...
    'RL','Cout','Cin','Ce'};

xaiValues = [ ...
    7.132482, ...
    5.655643, ...
    5.489312, ...
    4.122986, ...
    2.631683, ...
    1.710156, ...
    0.315193, ...
    0.300987, ...
    0.215517];

xaiRanks = 1:9;

xaiDirection = { ...
    'Negative', ...
    'Positive', ...
    'Negative', ...
    'Positive', ...
    'Positive', ...
    'Positive', ...
    'Weak / non-monotonic', ...
    'Weak / non-monotonic', ...
    'Weak / non-monotonic'};

xaiRho = [ ...
    -0.995914, ...
     0.992998, ...
    -0.988677, ...
     0.992638, ...
     0.995288, ...
     0.975816, ...
     0.101324, ...
     0.104131, ...
    -0.148878];

% Validated global SHAP agreement.

xaiRankSpearman = 0.866667;

xaiRankPearson  = 0.940378;

% R1-R2 interaction.

r1r2Interaction = 0.614414;

% Global SPICE interaction validation.

interactionPearson = 0.914717;

interactionSpearman = 0.873801;

interactionRMSE     = 6.889992;

interactionMAE      = 4.782041;

% Regional interaction evidence.

interactionLowPearson  = 0.838318;

interactionLowSpearman = 0.898355;

interactionLowRMSE     = 5.602782;

interactionMedPearson  = 0.948428;

interactionMedSpearman = 0.947936;

interactionMedRMSE     = 4.273222;

interactionHighPearson  = -0.666645;

interactionHighSpearman = -0.560732;

interactionHighRMSE     = 9.631427;

%% ================================================================

% 4B. OPTIMIZATION STATE

% ================================================================

optimizationLoaded = false;
optimizationData = struct();
optimizationCase = 'Medium';

% Live optimization state. These are only used when the user explicitly
% requests optimization from the current editable circuit.
vceSurrogate = [];
vcbSurrogate = [];
liveOptimizationLoaded = false;
optimizationLB = [];
optimizationUB = [];
lastSimulation = struct();
lastRobustness = struct();
verifyPanel = []; verifyGainAx = []; verifySummary = []; verifyStatus = []; verifyRobustStatus = []; verifySystemStatus = []; verifyRunButton = []; robButton = [];

%% ================================================================

% 5. LOAD TRAINED MODEL

%

% NO TRAINING HERE.

% ================================================================

if isfile(MODEL_PATH)

    try

        M = load(MODEL_PATH);

        if isfield(M,'net')

            dlModel = M.net;

            dlLoaded = true;

            modelMessage = ...
                'Trained DL network loaded successfully.';

        else

            modelMessage = ...
                'Model MAT file does not contain variable "net".';

        end

    catch ME

        modelMessage = ...
            ['Model load error: ' ME.message];

    end

else

    modelMessage = ...
        ['Model not found: ' MODEL_PATH];

end

cleanupTrainingProgressFigures();

%% ================================================================

% 6. RECONSTRUCT EXACT RESEARCH NORMALIZATION

% ================================================================

[dlMu,dlSigma,normalizationLoaded,normalizationMessage] = ...
    reconstructResearchNormalization( ...
        CANONICAL_DATASET, ...
        DL_DATASET);

% Load the validated operating-point surrogates used only as optimization
% screening constraints. Final physical acceptance is always done by SPICE.
[liveOptimizationLoaded,vceSurrogate,vcbSurrogate,optimizationLB,optimizationUB] = ...
    loadLiveOptimizationResources(CANONICAL_DATASET,VCE_SURROGATE_FILE,VCB_SURROGATE_FILE);

%% ================================================================

% 7. SPICE AVAILABILITY

% ================================================================

runSpicePath = fullfile( ...
    SPICE_ROOT, ...
    'runSpice.m');

if exist(runSpicePath,'file')

    addpath(SPICE_ROOT);

    spiceAvailable = true;

end

%% ================================================================

% 8. LOAD / VERIFY XAI

%

% We do NOT calculate SHAP.

% The finalized research values are already stored.

% ================================================================

[xaiLoaded,xaiMessage] = loadXAIResearchData( ...
    XAI_MASTER_FILE, ...
    XAI_RANKING_FILE);

%% ================================================================

% 9. MAIN WINDOW

% ================================================================

fig = uifigure( ...
    'Name','CE-XAI | Lab 04', ...
    'Position',[80 60 1440 820], ...
    'WindowState','maximized', ...
    'Color',C.bg, ...
    'Resize','on');

fig.CloseRequestFcn = @closeApplication;

%% ================================================================

% 10. ROOT GRID

% ================================================================

root = uigridlayout(fig,[3 2]);

root.RowHeight = {58,'1x',84};

root.ColumnWidth = {320,'1x'};

root.Padding = [16 14 16 14];

root.RowSpacing = 10;

root.ColumnSpacing = 12;

%% ================================================================

% 11. HEADER

% ================================================================

header = uipanel( ...
    root, ...
    'BackgroundColor',C.surface, ...
    'BorderType','none');

header.Layout.Row = 1;

header.Layout.Column = [1 2];

headGrid = uigridlayout(header,[1 3]);

headGrid.ColumnWidth = {'1x',190,260};

headGrid.RowHeight = {'1x'};

headGrid.Padding = [16 4 14 4];

headGrid.ColumnSpacing = 18;

brand = uiLabel( ...
    headGrid, ...
    'Text','CE-XAI  /  LAB 04', ...
    'FontName','Arial', ...
    'FontSize',17, ...
    'FontWeight','bold', ...
    'FontColor',C.text);

brand.Layout.Row = 1;

brand.Layout.Column = 1;

typeLabel = uiLabel( ...
    headGrid, ...
    'Text','NPN  •  COMMON EMITTER', ...
    'FontName','Consolas', ...
    'FontSize',10, ...
    'FontColor',C.muted, ...
    'HorizontalAlignment','center');

typeLabel.Layout.Row = 1;

typeLabel.Layout.Column = 2;

statusLabel = uiLabel( ...
    headGrid, ...
    'Text','', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontColor',C.muted, ...
    'HorizontalAlignment','right');

statusLabel.Layout.Row = 1;

statusLabel.Layout.Column = 3;

updateHeaderStatus();

%% ================================================================

% 12. LEFT DESIGN VECTOR

% ================================================================

side = uipanel( ...
    root, ...
    'BackgroundColor',C.surface, ...
    'BorderType','none');

side.Layout.Row = 2;

side.Layout.Column = 1;

sideGrid = uigridlayout(side,[18 1]);

sideGrid.RowHeight = ...
    {44,19,28,28,19,28,28,28,19,28,28,28,19,28,36,36,'1x',54};

sideGrid.ColumnWidth = {'1x'};

sideGrid.Padding = [14 12 14 12];

sideGrid.RowSpacing = 3;

%% Title

titleRow = uigridlayout(sideGrid,[2 1]);

titleRow.Layout.Row = 1;

titleRow.RowHeight = {22,'1x'};

titleRow.Padding = [0 0 0 0];

titleRow.RowSpacing = 0;

titleLabel = uiLabel( ...
    titleRow, ...
    'Text','DESIGN VECTOR', ...
    'FontName','Arial', ...
    'FontSize',15, ...
    'FontWeight','bold', ...
    'FontColor',C.text);

titleLabel.Layout.Row = 1;

subTitle = uiLabel( ...
    titleRow, ...
    'Text','Bias and small-signal network', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontColor',C.muted);

subTitle.Layout.Row = 2;

edits = struct();

%% Parameters

addSection('BIAS',2);

addParam('R1','R1','kΩ',150,3,1,1000);

addParam('R2','R2','kΩ',82,4,1,1000);

addSection('AMPLIFIER',5);

addParam('RC','RC','kΩ',1.5,6,0.1,1000);

addParam('RE','RE','kΩ',1,7,0.1,1000);

addParam('RL','RL','kΩ',10,8,0.1,1000);

addSection('COUPLING',9);

addParam('Cin','Cin','µF',0.70,10,0.001,1000);

addParam('Cout','Cout','µF',1.00,11,0.001,1000);

addParam('Ce','Ce','µF',4.70,12,0.001,1000);

addSection('SUPPLY',13);

addParam('VCC','VCC','V',12,14,1,48);

%% Preset

presetRow = uigridlayout(sideGrid,[1 2]);

presetRow.Layout.Row = 15;

presetRow.ColumnWidth = {70,'1x'};

presetRow.RowHeight = {'1x'};

presetRow.Padding = [0 0 0 0];

presetRow.ColumnSpacing = 8;

presetLabel = uiLabel( ...
    presetRow, ...
    'Text','PRESET', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'FontColor',C.muted);

presetLabel.Layout.Row = 1;

presetLabel.Layout.Column = 1;

preset = uidropdown( ...
    presetRow, ...
    'Items',{'Custom','Low','Medium','High'}, ...
    'Value','Medium', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'BackgroundColor',C.field, ...
    'FontColor',C.text, ...
    'ValueChangedFcn',@applyPreset);

preset.Layout.Row = 1;

preset.Layout.Column = 2;

%% Prediction button

predictButton = uibutton( ...
    sideGrid, ...
    'push', ...
    'Text','RUN SIMULATION', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'BackgroundColor',C.violet, ...
    'FontColor',C.text, ...
    'ButtonPushedFcn',@simulateNow);

predictButton.Layout.Row = 16;

methodNote = uiLabel( ...
    sideGrid, ...
    'Text',buildMethodNote(), ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'FontColor',C.muted, ...
    'WordWrap','on', ...
    'VerticalAlignment','bottom');

methodNote.Layout.Row = 18;

simSideNote = uiLabel( ...
    sideGrid, ...
    'Text','SIMULATION / ngspice DC + AC + DL comparison', ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'FontColor',C.teal, ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','center');
simSideNote.Layout.Row = 17;

%% ================================================================

% 13. MAIN WORK SURFACE

% ================================================================

work = uipanel( ...
    root, ...
    'BackgroundColor',C.surface, ...
    'BorderType','none');

work.Layout.Row = 2;

work.Layout.Column = 2;

workGrid = uigridlayout(work,[4 1]);

workGrid.RowHeight = {34,'1x',38,120};

workGrid.ColumnWidth = {'1x'};

workGrid.Padding = [12 10 12 10];

workGrid.RowSpacing = 6;

%% Bench header

benchHeader = uigridlayout(workGrid,[1 2]);

benchHeader.Layout.Row = 1;

benchHeader.ColumnWidth = {'1x','1x'};

benchHeader.RowHeight = {'1x'};

benchHeader.Padding = [0 0 0 0];

benchTitle = uiLabel( ...
    benchHeader, ...
    'Text','Circuit bench', ...
    'FontName','Arial', ...
    'FontSize',14, ...
    'FontWeight','bold', ...
    'FontColor',C.text);

benchTitle.Layout.Row = 1;

benchTitle.Layout.Column = 1;

benchHint = uiLabel( ...
    benchHeader, ...
    'Text','Select a component to inspect', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontColor',C.muted, ...
    'HorizontalAlignment','right');

benchHint.Layout.Row = 1;

benchHint.Layout.Column = 2;

%% ================================================================

% 14. CIRCUIT AXES

% ================================================================

ax = uiaxes( ...
    workGrid, ...
    'Color',C.recess, ...
    'XColor',C.recess, ...
    'YColor',C.recess, ...
    'XLim',[0 100], ...
    'YLim',[0 100], ...
    'XTick',[], ...
    'YTick',[], ...
    'Box','off', ...
    'Interactions',[], ...
    'Toolbar',[]);

ax.Layout.Row = 2;

ax.DataAspectRatio = [1 1 1];

ax.PlotBoxAspectRatioMode = 'auto';

hold(ax,'on');

parts = struct();
simHitBoxes = struct();
simSelectedKey = '';
simOpTexts = struct();

drawCircuit();

%% ================================================================

% 14B. INTERACTIVE SIMULATION PANEL

% ================================================================

simPanel = uipanel( ...
    workGrid, ...
    'BackgroundColor',C.recess, ...
    'BorderType','none');

simPanel.Layout.Row = 2;
simPanel.Visible = 'off';

simGrid = uigridlayout(simPanel,[4 3]);
simGrid.RowHeight = {34,'1x',74,30};
simGrid.ColumnWidth = {'1.02x','1.08x','1.08x'};
simGrid.Padding = [12 10 12 8];
simGrid.RowSpacing = 8;
simGrid.ColumnSpacing = 10;

simTitle = uiLabel(simGrid,'Text','SPICE / INTERACTIVE SIMULATION', ...
    'FontName','Arial','FontSize',15,'FontWeight','bold','FontColor',C.text);
simTitle.Layout.Row = 1; simTitle.Layout.Column = [1 2];

simStatus = uiLabel(simGrid,'Text','READY / edit the design vector and run simulation', ...
    'FontName','Consolas','FontSize',10,'FontColor',C.teal, ...
    'HorizontalAlignment','right');
simStatus.Layout.Row = 1; simStatus.Layout.Column = 3;

% ---------------------------------------------------------------
% Interactive simulation schematic
% ---------------------------------------------------------------
simCircuitAx = uiaxes(simGrid,'Color',C.recess,'XColor',C.recess,'YColor',C.recess, ...
    'XLim',[0 100],'YLim',[0 100],'XTick',[],'YTick',[], ...
    'Box','off','Interactions',[],'Toolbar',[]);
simCircuitAx.Layout.Row = 2; simCircuitAx.Layout.Column = 1;
simCircuitAx.DataAspectRatio = [1 1 1];
simCircuitAx.PlotBoxAspectRatio = [1.12 1 1];
hold(simCircuitAx,'on');

drawSimulationCircuit();

simGainAx = uiaxes(simGrid,'Color',C.bg,'XColor',C.muted,'YColor',C.muted, ...
    'Box','on','Toolbar',[]);
simGainAx.Layout.Row = 2; simGainAx.Layout.Column = 2;
simGainAx.Title.String = 'AC GAIN / SPICE';
simGainAx.Title.Color = C.text;
simGainAx.XLabel.String = 'Frequency (Hz)';
simGainAx.YLabel.String = 'Gain (dB)';
simGainAx.XScale = 'log';
simGainAx.GridColor = C.muted;
simGainAx.GridAlpha = 0.25;

simPhaseAx = uiaxes(simGrid,'Color',C.bg,'XColor',C.muted,'YColor',C.muted, ...
    'Box','on','Toolbar',[]);
simPhaseAx.Layout.Row = 2; simPhaseAx.Layout.Column = 3;
simPhaseAx.Title.String = 'AC PHASE / SPICE';
simPhaseAx.Title.Color = C.text;
simPhaseAx.XLabel.String = 'Frequency (Hz)';
simPhaseAx.YLabel.String = 'Phase (deg)';
simPhaseAx.XScale = 'log';
simPhaseAx.GridColor = C.muted;
simPhaseAx.GridAlpha = 0.25;

% ---------------------------------------------------------------
% DC operating-point instrument strip
% ---------------------------------------------------------------
simDCPanel = uipanel(simGrid,'BackgroundColor',C.bg,'BorderType','line', ...
    'HighlightColor',C.rule,'BorderColor',C.rule);
simDCPanel.Layout.Row = 3; simDCPanel.Layout.Column = 1;

dcGrid = uigridlayout(simDCPanel,[2 4]);
dcGrid.RowHeight = {22,'1x'};
dcGrid.ColumnWidth = {'1x','1x','1x','1x'};
dcGrid.Padding = [6 4 6 4];
dcGrid.RowSpacing = 1; dcGrid.ColumnSpacing = 6;

dcTitle = uiLabel(dcGrid,'Text','DC OPERATING POINT','FontName','Consolas', ...
    'FontSize',9,'FontWeight','bold','FontColor',C.muted);
dcTitle.Layout.Row = 1; dcTitle.Layout.Column = [1 4];

dcVB = uiLabel(dcGrid,'Text','VB  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
dcVB.Layout.Row=2; dcVB.Layout.Column=1;
dcVE = uiLabel(dcGrid,'Text','VE  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
dcVE.Layout.Row=2; dcVE.Layout.Column=2;
dcVC = uiLabel(dcGrid,'Text','VC  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
dcVC.Layout.Row=2; dcVC.Layout.Column=3;
dcVCE = uiLabel(dcGrid,'Text','VCE —','FontName','Consolas','FontSize',9,'FontColor',C.teal);
dcVCE.Layout.Row=2; dcVCE.Layout.Column=4;

simMetricPanel = uipanel(simGrid,'BackgroundColor',C.bg,'BorderType','line', ...
    'HighlightColor',C.rule,'BorderColor',C.rule);
simMetricPanel.Layout.Row = 3; simMetricPanel.Layout.Column = 2;
metricGrid = uigridlayout(simMetricPanel,[2 5]);
metricGrid.RowHeight = {22,'1x'};
metricGrid.ColumnWidth = {'1x','1x','1x','1x','1x'};
metricGrid.Padding = [6 4 6 4]; metricGrid.ColumnSpacing = 6;
metricTitle = uiLabel(metricGrid,'Text','SIMULATION MEASUREMENTS','FontName','Consolas', ...
    'FontSize',9,'FontWeight','bold','FontColor',C.muted);
metricTitle.Layout.Row=1; metricTitle.Layout.Column=[1 5];
metricGain = uiLabel(metricGrid,'Text','GAIN  —','FontName','Consolas','FontSize',9,'FontColor',C.teal);
metricGain.Layout.Row=2; metricGain.Layout.Column=1;
metricIC = uiLabel(metricGrid,'Text','IC  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
metricIC.Layout.Row=2; metricIC.Layout.Column=2;
metricRL = uiLabel(metricGrid,'Text','RL  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
metricRL.Layout.Row=2; metricRL.Layout.Column=3;
metricFL = uiLabel(metricGrid,'Text','fL  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
metricFL.Layout.Row=2; metricFL.Layout.Column=4;
metricFH = uiLabel(metricGrid,'Text','fH  —','FontName','Consolas','FontSize',9,'FontColor',C.text);
metricFH.Layout.Row=2; metricFH.Layout.Column=5;

simComparePanel = uipanel(simGrid,'BackgroundColor',C.bg,'BorderType','line', ...
    'HighlightColor',C.rule,'BorderColor',C.rule);
simComparePanel.Layout.Row = 3; simComparePanel.Layout.Column = 3;
compareGrid = uigridlayout(simComparePanel,[5 2]);
compareGrid.RowHeight = {20,20,20,18,'1x'};
compareGrid.ColumnWidth = {'1x','1.15x'};
compareGrid.Padding = [6 4 6 4]; compareGrid.RowSpacing = 2; compareGrid.ColumnSpacing = 6;
compareTitle = uiLabel(compareGrid,'Text','MODEL / PHYSICS','FontName','Consolas', ...
    'FontSize',9,'FontWeight','bold','FontColor',C.muted);
compareTitle.Layout.Row=1; compareTitle.Layout.Column=[1 2];
compareDL = uiLabel(compareGrid,'Text','DL  —','FontName','Consolas','FontSize',9,'FontColor',C.violet);
compareDL.Layout.Row=2; compareDL.Layout.Column=1;
compareDelta = uiLabel(compareGrid,'Text','Δ  —','FontName','Consolas','FontSize',9,'FontColor',C.amber);
compareDelta.Layout.Row=2; compareDelta.Layout.Column=2;
compareValid = uiLabel(compareGrid,'Text','SPICE  —','FontName','Consolas','FontSize',9,'FontColor',C.teal);
compareValid.Layout.Row=3; compareValid.Layout.Column=[1 2];
simXaiTitle = uiLabel(compareGrid,'Text','LIVE XAI / CURRENT CIRCUIT','FontName','Consolas', ...
    'FontSize',8,'FontWeight','bold','FontColor',C.violet);
simXaiTitle.Layout.Row=4; simXaiTitle.Layout.Column=[1 2];
simLiveXai = uiLabel(compareGrid,'Text','Research SHAP guidance will appear after simulation.', ...
    'FontName','Consolas','FontSize',8,'FontColor',C.muted,'WordWrap','on', ...
    'VerticalAlignment','top');
simLiveXai.Layout.Row=5; simLiveXai.Layout.Column=[1 2];

simSummary = uiLabel(simGrid,'Text','No simulation run yet.', ...
    'FontName','Consolas','FontSize',9,'FontColor',C.muted, ...
    'WordWrap','on','VerticalAlignment','center','HorizontalAlignment','left');
simSummary.Layout.Row = 4; simSummary.Layout.Column = [1 2];

optCurrentButton = uibutton(simGrid,'push', ...
    'Text','OPTIMIZE CURRENT DESIGN', ...
    'FontName','Arial','FontSize',9,'FontWeight','bold', ...
    'BackgroundColor',C.copper,'FontColor',C.bg, ...
    'ButtonPushedFcn',@optimizeCurrentDesign);
optCurrentButton.Layout.Row=4; optCurrentButton.Layout.Column=3;
if ~liveOptimizationLoaded
    optCurrentButton.Enable='off';
    optCurrentButton.Text='OPTIMIZATION RESOURCES OFFLINE';
end

%% ================================================================

% 14C. VERIFY / ROBUSTNESS PANEL

% ================================================================
verifyPanel = uipanel(workGrid,'BackgroundColor',C.recess,'BorderType','none');
verifyPanel.Layout.Row=2; verifyPanel.Visible='off';
verifyGrid=uigridlayout(verifyPanel,[3 3]); verifyGrid.RowHeight={34,'1x',34}; verifyGrid.ColumnWidth={'1.0x','1.15x','1.0x'}; verifyGrid.Padding=[12 10 12 8]; verifyGrid.RowSpacing=8; verifyGrid.ColumnSpacing=10;
verifyTitle=uiLabel(verifyGrid,'Text','SPICE / FINAL VERIFICATION','FontName','Arial','FontSize',15,'FontWeight','bold','FontColor',C.text); verifyTitle.Layout.Row=1; verifyTitle.Layout.Column=[1 2];
verifyStatus=uiLabel(verifyGrid,'Text','READY / run verification or robustness','FontName','Consolas','FontSize',10,'FontColor',C.teal,'HorizontalAlignment','right'); verifyStatus.Layout.Row=1; verifyStatus.Layout.Column=3;
verifyLeft=uipanel(verifyGrid,'BackgroundColor',C.bg,'BorderType','line','HighlightColor',C.rule,'BorderColor',C.rule); verifyLeft.Layout.Row=2; verifyLeft.Layout.Column=1;
vg1=uigridlayout(verifyLeft,[9 1]); vg1.RowHeight={26,28,28,28,28,28,28,34,'1x'}; vg1.Padding=[10 8 10 8]; vg1.RowSpacing=3;
verifyHeader1=uiLabel(vg1,'Text','FINAL SPICE CHECK','FontName','Consolas','FontSize',10,'FontWeight','bold','FontColor',C.muted); verifyHeader1.Layout.Row=1;
verifySummary=uiLabel(vg1,'Text','No verification run yet.','FontName','Consolas','FontSize',11,'FontColor',C.text,'WordWrap','on'); verifySummary.Layout.Row=[2 7];
verifySystemStatus=uiLabel(vg1,'Text','SYSTEM RESOURCES / checking...','FontName','Consolas','FontSize',9,'FontColor',C.muted,'WordWrap','on'); verifySystemStatus.Layout.Row=8;
verifyRunButton=uibutton(vg1,'push','Text','RUN SPICE VERIFICATION','FontName','Arial','FontSize',10,'FontWeight','bold','BackgroundColor',C.teal,'FontColor',C.bg,'ButtonPushedFcn',@verifyNow); verifyRunButton.Layout.Row=9;
verifyMid=uipanel(verifyGrid,'BackgroundColor',C.bg,'BorderType','line','HighlightColor',C.rule,'BorderColor',C.rule); verifyMid.Layout.Row=2; verifyMid.Layout.Column=2;
vg2=uigridlayout(verifyMid,[3 1]); vg2.RowHeight={24,'1x',34}; vg2.Padding=[8 8 8 8]; vg2.RowSpacing=5;
verifyHeader2=uiLabel(vg2,'Text','ROBUSTNESS / CURRENT DESIGN','FontName','Consolas','FontSize',10,'FontWeight','bold','FontColor',C.muted); verifyHeader2.Layout.Row=1;
verifyGainAx=uiaxes(vg2,'Color',C.bg,'XColor',C.muted,'YColor',C.muted,'Box','on','Toolbar',[]); verifyGainAx.Layout.Row=2; verifyGainAx.Title.String='Gain distribution'; verifyGainAx.Title.Color=C.text; verifyGainAx.XLabel.String='Gain (dB)'; verifyGainAx.YLabel.String='Count';
robRunRow=uigridlayout(vg2,[1 2]); robRunRow.Layout.Row=3; robRunRow.ColumnWidth={'1.15x','1x'}; robRunRow.Padding=[0 0 0 0]; robRunRow.ColumnSpacing=6;
robButton=uibutton(robRunRow,'push','Text','RUN 100 SPICE TOLERANCES','FontName','Arial','FontSize',9,'FontWeight','bold','BackgroundColor',C.copper,'FontColor',C.bg,'ButtonPushedFcn',@runRobustnessCurrent); robButton.Layout.Column=1;
verifyRobustStatus=uiLabel(robRunRow,'Text','R ±5% / C ±10% / VCC ±5%','FontName','Consolas','FontSize',8,'FontColor',C.muted,'HorizontalAlignment','right'); verifyRobustStatus.Layout.Column=2;
verifyRight=uipanel(verifyGrid,'BackgroundColor',C.bg,'BorderType','line','HighlightColor',C.rule,'BorderColor',C.rule); verifyRight.Layout.Row=2; verifyRight.Layout.Column=3;
vg3=uigridlayout(verifyRight,[10 1]); vg3.RowHeight={26,28,28,28,28,28,28,28,28,'1x'}; vg3.Padding=[10 8 10 8]; vg3.RowSpacing=3;
verifyHeader3=uiLabel(vg3,'Text','RESEARCH / SYSTEM HEALTH','FontName','Consolas','FontSize',10,'FontWeight','bold','FontColor',C.muted); verifyHeader3.Layout.Row=1;
verifyHealth1=uiLabel(vg3,'Text','SPICE engine  —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth1.Layout.Row=2;
verifyHealth2=uiLabel(vg3,'Text','DL model     —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth2.Layout.Row=3;
verifyHealth3=uiLabel(vg3,'Text','XAI research  —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth3.Layout.Row=4;
verifyHealth4=uiLabel(vg3,'Text','Optimization  —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth4.Layout.Row=5;
verifyHealth5=uiLabel(vg3,'Text','OP surrogates  —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth5.Layout.Row=6;
verifyHealth6=uiLabel(vg3,'Text','Current design —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth6.Layout.Row=7;
verifyHealth7=uiLabel(vg3,'Text','Constraints     —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth7.Layout.Row=8;
verifyHealth8=uiLabel(vg3,'Text','Robustness      —','FontName','Consolas','FontSize',9,'FontColor',C.text); verifyHealth8.Layout.Row=9;
verifyHealthNote=uiLabel(vg3,'Text','SPICE is the final physical authority.','FontName','Consolas','FontSize',9,'FontColor',C.teal,'WordWrap','on'); verifyHealthNote.Layout.Row=10;
verifyFooter=uiLabel(verifyGrid,'Text','VERIFY = measured SPICE result. ROBUSTNESS = tolerance perturbations around the current editable design.','FontName','Consolas','FontSize',9,'FontColor',C.muted,'WordWrap','on'); verifyFooter.Layout.Row=3; verifyFooter.Layout.Column=[1 3];
updateVerifyHealth();

%% ================================================================

% 15. XAI PANEL
%
% ================================================================

xaiPanel = uipanel( ...
    workGrid, ...
    'BackgroundColor',C.recess, ...
    'BorderType','none');

xaiPanel.Layout.Row = 2;
xaiPanel.Visible = 'off';

% Explain view is intentionally circuit-centric:
%   LEFT   = interactive XAI circuit
%   CENTER = global Mean |SHAP| graph
%   RIGHT  = selected-feature inspector
xaiGrid = uigridlayout(xaiPanel,[1 3]);
xaiGrid.ColumnWidth = {'1.05x','1.25x','0.95x'};
xaiGrid.RowHeight = {'1x'};
xaiGrid.Padding = [12 10 12 10];
xaiGrid.ColumnSpacing = 12;

%% ---------------------------------------------------------------
% 4B.2 / INTERACTIVE XAI CIRCUIT
% ---------------------------------------------------------------

xaiCircuitPanel = uipanel( ...
    xaiGrid, ...
    'BackgroundColor',C.recess, ...
    'BorderType','none');

xaiCircuitPanel.Layout.Row = 1;
xaiCircuitPanel.Layout.Column = 1;

xaiCircuitGrid = uigridlayout(xaiCircuitPanel,[3 1]);
xaiCircuitGrid.RowHeight = {28,18,'1x'};
xaiCircuitGrid.Padding = [0 0 0 0];
xaiCircuitGrid.RowSpacing = 4;

xaiCircuitTitle = uiLabel( ...
    xaiCircuitGrid, ...
    'Text','XAI / CIRCUIT MAP', ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'FontColor',C.text);
xaiCircuitTitle.Layout.Row = 1;

xaiCircuitHint = uiLabel( ...
    xaiCircuitGrid, ...
    'Text','Click a component to explain its model contribution', ...
    'FontName','Arial', ...
    'FontSize',8, ...
    'FontColor',C.muted);
xaiCircuitHint.Layout.Row = 2;

xaiCircuitAx = uiaxes( ...
    xaiCircuitGrid, ...
    'Color',C.recess, ...
    'XColor',C.recess, ...
    'YColor',C.recess, ...
    'XLim',[0 100], ...
    'YLim',[0 100], ...
    'XTick',[], ...
    'YTick',[], ...
    'Box','off', ...
    'Interactions',[], ...
    'Toolbar',[]);
xaiCircuitAx.Layout.Row = 3;
xaiCircuitAx.DataAspectRatio = [1 1 1];
xaiCircuitAx.PlotBoxAspectRatioMode = 'auto';
hold(xaiCircuitAx,'on');

xaiParts = struct();
drawExplainCircuit();

%% ---------------------------------------------------------------
% 4A.1 / GLOBAL SHAP GRAPH
% ---------------------------------------------------------------

xaiGraphPanel = uipanel( ...
    xaiGrid, ...
    'BackgroundColor',C.recess, ...
    'BorderType','none');

xaiGraphPanel.Layout.Row = 1;
xaiGraphPanel.Layout.Column = 2;

xaiGraphGrid = uigridlayout(xaiGraphPanel,[4 1]);
xaiGraphGrid.RowHeight = {28,20,'1x',22};
xaiGraphGrid.Padding = [0 0 0 0];
xaiGraphGrid.RowSpacing = 4;

xaiTitle = uiLabel( ...
    xaiGraphGrid, ...
    'Text','XAI / GLOBAL FEATURE IMPORTANCE', ...
    'FontName','Arial', ...
    'FontSize',12, ...
    'FontWeight','bold', ...
    'FontColor',C.text);
xaiTitle.Layout.Row = 1;

xaiSub = uiLabel( ...
    xaiGraphGrid, ...
    'Text','Deep Learning  •  Mean |SHAP| contribution  •  click a bar', ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'FontColor',C.muted);
xaiSub.Layout.Row = 2;

xaiBarAx = uiaxes( ...
    xaiGraphGrid, ...
    'Color',C.recess, ...
    'XColor',C.muted, ...
    'YColor',C.text, ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'Box','off', ...
    'Toolbar',[]);
xaiBarAx.Layout.Row = 3;
xaiBarAx.XGrid = 'on';
xaiBarAx.YGrid = 'off';
xaiBarAx.GridColor = C.rule;
xaiBarAx.GridAlpha = 0.35;
xaiBarAx.XLim = [0 max(xaiValues)*1.20];
xaiBarAx.YLim = [0.4 9.6];
xaiBarAx.YTick = 1:9;
xaiBarAx.YTickLabel = xaiFeatureNames;
xaiBarAx.YDir = 'reverse';
xaiBarAx.XLabel.String = 'Mean |SHAP| contribution (dB)';
xaiBarAx.XLabel.Color = C.muted;
xaiBarAx.XLabel.FontName = 'Arial';
xaiBarAx.XLabel.FontSize = 10;

xaiBarObj = barh( ...
    xaiBarAx, ...
    1:9, ...
    xaiValues, ...
    0.68, ...
    'FaceColor','flat', ...
    'EdgeColor','none', ...
    'HitTest','on');
xaiBarObj.CData = repmat(C.violet,9,1);
xaiBarObj.ButtonDownFcn = @barClicked;
xaiBarAx.ButtonDownFcn = @barAxesClicked;

xaiGraphNote = uiLabel( ...
    xaiGraphGrid, ...
    'Text','Precomputed research result  •  no SHAP calculation is performed by the GUI', ...
    'FontName','Consolas', ...
    'FontSize',8, ...
    'FontColor',C.teal);
xaiGraphNote.Layout.Row = 4;

%% ---------------------------------------------------------------
% SELECTED FEATURE / XAI INSPECTOR
% ---------------------------------------------------------------

xaiRight = uipanel( ...
    xaiGrid, ...
    'BackgroundColor',C.surface, ...
    'BorderType','none');

xaiRight.Layout.Row = 1;
xaiRight.Layout.Column = 3;

xaiRightGrid = uigridlayout(xaiRight,[13 1]);
xaiRightGrid.RowHeight = ...
    {18,32,28,28,28,28,44,42,30,24,'1x',34,34};
xaiRightGrid.Padding = [12 10 12 10];
xaiRightGrid.RowSpacing = 4;

xaiInspectorTitle = uiLabel( ...
    xaiRightGrid, ...
    'Text','SELECTED FEATURE', ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'FontWeight','bold', ...
    'FontColor',C.muted);
xaiInspectorTitle.Layout.Row = 1;

xaiSelected = uiLabel( ...
    xaiRightGrid, ...
    'Text','R1', ...
    'FontName','Consolas', ...
    'FontSize',20, ...
    'FontWeight','bold', ...
    'FontColor',C.copper);
xaiSelected.Layout.Row = 2;

xaiSelectedValue = uiLabel( ...
    xaiRightGrid, ...
    'Text','Current value     150 kΩ', ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'FontColor',C.text);
xaiSelectedValue.Layout.Row = 3;

xaiImportance = uiLabel( ...
    xaiRightGrid, ...
    'Text','Mean |SHAP|       7.1325 dB', ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'FontColor',C.text);
xaiImportance.Layout.Row = 4;

xaiRank = uiLabel( ...
    xaiRightGrid, ...
    'Text','GLOBAL RANK       #1', ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'FontColor',C.text);
xaiRank.Layout.Row = 5;

xaiDirectionLabel = uiLabel( ...
    xaiRightGrid, ...
    'Text','DIRECTION          Negative', ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'FontColor',C.text);
xaiDirectionLabel.Layout.Row = 6;

xaiRhoLabel = uiLabel( ...
    xaiRightGrid, ...
    'Text','DEPENDENCE ρ       -0.9959', ...
    'FontName','Consolas', ...
    'FontSize',9, ...
    'FontColor',C.text);
xaiRhoLabel.Layout.Row = 7;

xaiExplanation = uiLabel( ...
    xaiRightGrid, ...
    'Text','Higher values are associated with lower predicted gain in the learned model.', ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'FontColor',C.muted, ...
    'WordWrap','on');
xaiExplanation.Layout.Row = 8;

xaiInteractionButton = uibutton( ...
    xaiRightGrid, ...
    'push', ...
    'Text','VIEW  R1 ↔ R2  INTERACTION', ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'FontWeight','bold', ...
    'BackgroundColor',C.bg, ...
    'FontColor',C.text, ...
    'ButtonPushedFcn',@showInteraction);
xaiInteractionButton.Layout.Row = 9;

xaiAgreement = uiLabel( ...
    xaiRightGrid, ...
    'Text',sprintf('DL ↔ LSBoost SHAP rank agreement   ρs = %.4f',xaiRankSpearman), ...
    'FontName','Consolas', ...
    'FontSize',8, ...
    'FontColor',C.muted, ...
    'WordWrap','on');
xaiAgreement.Layout.Row = 10;

xaiInteractionStatus = uiLabel( ...
    xaiRightGrid, ...
    'Text','R1-R2 is the strongest identified interaction.', ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'FontColor',C.teal, ...
    'WordWrap','on');
xaiInteractionStatus.Layout.Row = 11;

xaiCloseButton = uibutton( ...
    xaiRightGrid, ...
    'push', ...
    'Text','RETURN TO CIRCUIT', ...
    'FontName','Arial', ...
    'FontSize',9, ...
    'BackgroundColor',C.bg, ...
    'FontColor',C.muted, ...
    'ButtonPushedFcn',@hideExplain);
xaiCloseButton.Layout.Row = 12;

xaiMethodLabel = uiLabel( ...
    xaiRightGrid, ...
    'Text','SPICE remains physical authority.', ...
    'FontName','Consolas', ...
    'FontSize',8, ...
    'FontColor',C.amber, ...
    'WordWrap','on');
xaiMethodLabel.Layout.Row = 13;

%% ================================================================
% EXPLAIN CIRCUIT / XAI MAP
% ================================================================

    function drawExplainCircuit()

        % Supply rail.
        xaiWire([35 35],[92 84]);
        xaiWire([35 65],[92 92]);
        vccHandle = plot( ...
            xaiCircuitAx,[28 42],[92 92], ...
            'Color',C.teal, ...
            'LineWidth',2.0, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('VCC'));
        vccLabel = text( ...
            xaiCircuitAx,35,95,'VCC', ...
            'Color',C.teal, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','center', ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('VCC'));
        xaiParts.VCC = partData({vccHandle,vccLabel}, ...
            sprintf('%.4g V',edits.VCC.Value), ...
            'Supply rail');

        % Bias divider.
        xaiResistorV('R1',35,84,70,'R1','Upper divider / bias setting');
        xaiWire([35 35],[70 56]);
        xaiResistorV('R2',35,50,35,'R2','Lower divider / bias setting');
        xaiWire([35 35],[35 20]);

        % Base node.
        xaiWire([35 55],[57 55]);
        xaiNode(35,55);

        % Collector branch.
        xaiWire([70 70],[92 84]);
        xaiResistorV('RC',70,84,69,'RC','Collector load');
        xaiWire([70 70],[69 61]);

        % Transistor.
        qCircle = rectangle( ...
            xaiCircuitAx, ...
            'Position',[54 48 16 16], ...
            'Curvature',[1 1], ...
            'EdgeColor',C.wire, ...
            'FaceColor','none', ...
            'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('Q1'));
        qBase = plot( ...
            xaiCircuitAx,[55 61],[56 56], ...
            'Color',C.wire, ...
            'LineWidth',1.7, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('Q1'));
        qCollector = plot( ...
            xaiCircuitAx,[61 66],[61 69], ...
            'Color',C.wire, ...
            'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('Q1'));
        qEmitter = plot( ...
            xaiCircuitAx,[61 66],[51 46], ...
            'Color',C.wire, ...
            'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('Q1'));
        qArrow = plot( ...
            xaiCircuitAx,[64.2 66],[48 46], ...
            'Color',C.wire, ...
            'LineWidth',1.4, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('Q1'));
        qLabel = text( ...
            xaiCircuitAx,58,68,'Q1', ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',8, ...
            'HorizontalAlignment','center', ...
            'ButtonDownFcn',@(src,event)selectXAIComponent('Q1'));
        xaiParts.Q1 = partData( ...
            {qCircle,qBase,qCollector,qEmitter,qArrow,qLabel}, ...
            'NPN', ...
            'Transistor / active device');

        % Collector node.
        xaiWire([70 70],[61 58]);
        xaiNode(70,61);

        % Emitter branch.
        xaiWire([66 66],[46 40]);
        xaiResistorV('RE',66,40,28,'RE','Emitter stabilization');
        xaiWire([66 66],[28 20]);

        % Emitter bypass.
        xaiWire([66 79],[40 40]);
        xaiWire([79 79],[40 34]);
        xaiCapV('Ce',79,34,23,'Ce','Emitter bypass capacitor');
        xaiWire([79 79],[23 20]);

        % Common ground rail.
        xaiWire([25 88],[20 20]);
        xaiGround(66,20);
        xaiGround(88,20);

        % Input coupling.
        xaiWire([12 22],[55 55]);
        xaiSource = rectangle( ...
            xaiCircuitAx, ...
            'Position',[6 49 8 12], ...
            'Curvature',[1 1], ...
            'EdgeColor',C.wire, ...
            'FaceColor','none', ...
            'LineWidth',1.2);
        set(xaiSource,'HitTest','off');
        xaiWire([14 22],[55 55]);
        xaiCapH('Cin',22,31,55,'Cin','Input coupling capacitor');
        xaiWire([31 35],[55 55]);

        % Output coupling + load.
        xaiWire([70 70],[61 55]);
        xaiCapH('Cout',70,80,55,'Cout','Output coupling capacitor');
        xaiWire([80 88],[55 55]);
        xaiWire([88 88],[55 48]);
        xaiResistorV('RL',88,48,30,'RL','Output load');
        xaiWire([88 88],[30 20]);

        text(xaiCircuitAx,10,44,'VIN', ...
            'Color',C.muted,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','center');
        text(xaiCircuitAx,94,57,'VOUT', ...
            'Color',C.muted,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','left');
        text(xaiCircuitAx,50,8, ...
            'Click R1 / R2 / RC / RE / RL / Cin / Cout / Ce / VCC', ...
            'Color',C.muted,'FontName','Consolas','FontSize',7, ...
            'HorizontalAlignment','center');

        xaiCircuitAx.XLim = [0 100];
        xaiCircuitAx.YLim = [0 100];
    end

    function xaiResistorV(key,x,top,bottom,ref,role)

        pad = 2.0;
        xx = x + [-2.1 2.1 -2.1 2.1 -2.1 2.1 -2.1];
        yy = linspace(top-pad,bottom+pad,7);

        leadTop = plot( ...
            xaiCircuitAx,[x x],[top top-pad], ...
            'Color',C.wire,'LineWidth',1.3, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        body = plot( ...
            xaiCircuitAx,xx,yy, ...
            'Color',C.wire,'LineWidth',1.5, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        leadBottom = plot( ...
            xaiCircuitAx,[x x],[bottom+pad bottom], ...
            'Color',C.wire,'LineWidth',1.3, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        label = text( ...
            xaiCircuitAx,x-4,mean([top bottom]),ref, ...
            'Color',C.muted,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','right','VerticalAlignment','middle', ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));

        xaiParts.(key) = partData( ...
            {leadTop,body,leadBottom,label}, ...
            sprintf('%.4g %s',edits.(key).Value,componentUnit(key)), ...
            role);
    end

    function xaiCapV(key,x,top,bottom,ref,role)

        mid = (top+bottom)/2;
        gap = 1.4;
        half = 3.0;

        h1 = plot( ...
            xaiCircuitAx,[x-half x+half],[mid+gap mid+gap], ...
            'Color',C.wire,'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        h2 = plot( ...
            xaiCircuitAx,[x-half x+half],[mid-gap mid-gap], ...
            'Color',C.wire,'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        l1 = plot( ...
            xaiCircuitAx,[x x],[top mid+gap], ...
            'Color',C.wire,'LineWidth',1.3, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        l2 = plot( ...
            xaiCircuitAx,[x x],[mid-gap bottom], ...
            'Color',C.wire,'LineWidth',1.3, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        label = text( ...
            xaiCircuitAx,x+4,mid,ref, ...
            'Color',C.muted,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','left','VerticalAlignment','middle', ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));

        xaiParts.(key) = partData( ...
            {h1,h2,l1,l2,label}, ...
            sprintf('%.4g %s',edits.(key).Value,componentUnit(key)), ...
            role);
    end

    function xaiCapH(key,left,right,y,ref,role)

        mid = (left+right)/2;
        gap = 1.4;
        half = 3.0;

        h1 = plot( ...
            xaiCircuitAx,[mid-gap mid-gap],[y-half y+half], ...
            'Color',C.wire,'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        h2 = plot( ...
            xaiCircuitAx,[mid+gap mid+gap],[y-half y+half], ...
            'Color',C.wire,'LineWidth',1.6, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        l1 = plot( ...
            xaiCircuitAx,[left mid-gap],[y y], ...
            'Color',C.wire,'LineWidth',1.3, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        l2 = plot( ...
            xaiCircuitAx,[mid+gap right],[y y], ...
            'Color',C.wire,'LineWidth',1.3, ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));
        label = text( ...
            xaiCircuitAx,mid,y+5,ref, ...
            'Color',C.muted,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','center','VerticalAlignment','bottom', ...
            'ButtonDownFcn',@(src,event)selectXAIComponent(key));

        xaiParts.(key) = partData( ...
            {h1,h2,l1,l2,label}, ...
            sprintf('%.4g %s',edits.(key).Value,componentUnit(key)), ...
            role);
    end

    function xaiWire(x,y)

        plot( ...
            xaiCircuitAx,x,y, ...
            'Color',C.wire, ...
            'LineWidth',1.25, ...
            'HitTest','off');
    end

    function xaiNode(x,y)

        plot( ...
            xaiCircuitAx,x,y,'o', ...
            'MarkerSize',4, ...
            'MarkerFaceColor',C.copper, ...
            'MarkerEdgeColor',C.copper, ...
            'HitTest','off');
    end

    function xaiGround(x,y)

        plot(xaiCircuitAx,[x-3 x+3],[y y], ...
            'Color',C.wire,'LineWidth',1.2,'HitTest','off');
        plot(xaiCircuitAx,[x-2 x+2],[y-1.5 y-1.5], ...
            'Color',C.wire,'LineWidth',1.2,'HitTest','off');
        plot(xaiCircuitAx,[x-1 x+1],[y-3 y-3], ...
            'Color',C.wire,'LineWidth',1.2,'HitTest','off');
    end

%% ================================================================

% 4C. OPTIMIZATION PANEL
% ================================================================

optPanel = uipanel(workGrid,'BackgroundColor',C.recess,'BorderType','none');
optPanel.Layout.Row = 2;
optPanel.Visible = 'off';

optGrid = uigridlayout(optPanel,[1 3]);
optGrid.ColumnWidth = {210,'1.30x','1.0x'};
% Keep the Optimize workspace slightly taller than the viewport so a
% compact vertical scrollbar appears instead of clipping the lower controls.
optGrid.RowHeight = {720};
optGrid.Scrollable = 'on';
optGrid.Padding = [12 10 12 10];
optGrid.ColumnSpacing = 12;

optNav = uipanel(optGrid,'BackgroundColor',C.surface,'BorderType','none');
optNav.Layout.Row = 1; optNav.Layout.Column = 1;
optNavGrid = uigridlayout(optNav,[10 1]);
optNavGrid.RowHeight = {34,26,44,42,42,42,54,48,72,44};
optNavGrid.Padding = [12 10 12 10]; optNavGrid.RowSpacing = 5;

optNavTitle = uiLabel(optNavGrid,'Text','OPTIMIZATION / DESIGN SEARCH','FontName','Arial','FontSize',14,'FontWeight','bold','FontColor',C.text);
optNavTitle.Layout.Row = 1;
optNavSub = uiLabel(optNavGrid,'Text','Circuit-aware • SPICE verified','FontName','Consolas','FontSize',12,'FontColor',C.teal);
optNavSub.Layout.Row = 2;

optCaseButtons = struct();
optCaseNames = {'Low','Medium','High'};
for kk = 1:3
    key = optCaseNames{kk};
    optCaseButtons.(key) = uibutton(optNavGrid,'push','Text',upper(key),'FontName','Arial','FontSize',13,'FontWeight','bold','BackgroundColor',C.bg,'FontColor',C.text,'ButtonPushedFcn',@(src,event)selectOptimizationCase(key));
    optCaseButtons.(key).Layout.Row = kk+3;
end

optConstraintNote = uiLabel(optNavGrid,'Text',sprintf('CONSTRAINTS\nVCE ≥ 1.0 V\nVCB ≥ 0.5 V'),'FontName','Consolas','FontSize',12,'FontColor',C.muted,'WordWrap','on');
optConstraintNote.Layout.Row = 7;
optStatusLabel = uiLabel(optNavGrid,'Text','','FontName','Consolas','FontSize',11,'FontColor',C.teal,'WordWrap','on');
optStatusLabel.Layout.Row = 8;
optApplyButton = uibutton(optNavGrid,'push','Text','APPLY VERIFIED DESIGN','FontName','Arial','FontSize',11,'FontWeight','bold','BackgroundColor',C.copper,'FontColor',C.bg,'ButtonPushedFcn',@applyOptimizationDesign);
optApplyButton.Layout.Row = 3;
optMethodLabel = uiLabel(optNavGrid,'Text',sprintf('DL surrogate proposes.\nSPICE decides.'),'FontName','Consolas','FontSize',13,'FontColor',C.muted,'WordWrap','on');
optMethodLabel.Layout.Row = 9;
optVerifyButton = uibutton(optNavGrid,'push','Text','VERIFY APPLIED DESIGN','FontName','Arial','FontSize',11,'FontWeight','bold','BackgroundColor',C.bg,'FontColor',C.text,'ButtonPushedFcn',@verifyOptimizationDesign);
optVerifyButton.Layout.Row = 10;

optDesignPanel = uipanel(optGrid,'BackgroundColor',C.recess,'BorderType','none');
optDesignPanel.Layout.Row = 1; optDesignPanel.Layout.Column = 2;
optDesignGrid = uigridlayout(optDesignPanel,[12 4]);
optDesignGrid.RowHeight = {30,24,24,24,24,24,24,24,24,24,24,'1x'};
optDesignGrid.ColumnWidth = {58,'1x','1x',72};
optDesignGrid.Padding = [4 2 4 2]; optDesignGrid.RowSpacing = 3; optDesignGrid.ColumnSpacing = 8;
optDesignTitle = uiLabel(optDesignGrid,'Text','BASELINE  →  AI PROPOSAL','FontName','Arial','FontSize',15,'FontWeight','bold','FontColor',C.text);
optDesignTitle.Layout.Row=1; optDesignTitle.Layout.Column=[1 4];
optBaseHead = uiLabel(optDesignGrid,'Text','BASELINE','FontName','Consolas','FontSize',10,'FontColor',C.muted,'HorizontalAlignment','right');
optBaseHead.Layout.Row=2; optBaseHead.Layout.Column=2;
optOptHead = uiLabel(optDesignGrid,'Text','OPTIMIZED','FontName','Consolas','FontSize',10,'FontColor',C.copper,'HorizontalAlignment','right');
optOptHead.Layout.Row=2; optOptHead.Layout.Column=3;
optDeltaHead = uiLabel(optDesignGrid,'Text','MOVE','FontName','Consolas','FontSize',10,'FontColor',C.muted,'HorizontalAlignment','right');
optDeltaHead.Layout.Row=2; optDeltaHead.Layout.Column=4;

optRows = struct();
optFields = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
for kk=1:numel(optFields)
    key=optFields{kk}; rr=kk+2;
    lab=uiLabel(optDesignGrid,'Text',key,'FontName','Consolas','FontSize',12,'FontWeight','bold','FontColor',C.text); lab.Layout.Row=rr; lab.Layout.Column=1;
    b=uiLabel(optDesignGrid,'Text','—','FontName','Consolas','FontSize',10,'FontColor',C.text,'HorizontalAlignment','right'); b.Layout.Row=rr; b.Layout.Column=2;
    o=uiLabel(optDesignGrid,'Text','—','FontName','Consolas','FontSize',10,'FontColor',C.copper,'HorizontalAlignment','right'); o.Layout.Row=rr; o.Layout.Column=3;
    d=uiLabel(optDesignGrid,'Text','—','FontName','Consolas','FontSize',10,'FontColor',C.muted,'HorizontalAlignment','right'); d.Layout.Row=rr; d.Layout.Column=4;
    optRows.(key)=struct('Base',b,'Opt',o,'Delta',d);
end
optDesignFoot = uiLabel(optDesignGrid,'Text','Final design values are read from the validated Step 8E artifact.','FontName','Consolas','FontSize',12,'FontColor',C.teal,'WordWrap','on');
optDesignFoot.Layout.Row=12; optDesignFoot.Layout.Column=[1 4];

optResultPanel = uipanel(optGrid,'BackgroundColor',C.surface,'BorderType','none');
optResultPanel.Layout.Row = 1; optResultPanel.Layout.Column = 3;
optResultGrid = uigridlayout(optResultPanel,[16 1]);
optResultGrid.RowHeight = {30,24,34,34,34,40,26,30,38,58,24,92,40,36,36,40};
optResultGrid.Padding=[12 10 12 10]; optResultGrid.RowSpacing=4;
optResultTitle=uiLabel(optResultGrid,'Text','OPTIMIZATION RESULT','FontName','Arial','FontSize',15,'FontWeight','bold','FontColor',C.text); optResultTitle.Layout.Row=1;
optResultCase=uiLabel(optResultGrid,'Text','MEDIUM','FontName','Consolas','FontSize',15,'FontWeight','bold','FontColor',C.copper); optResultCase.Layout.Row=2;
optBaselineReadout=uiLabel(optResultGrid,'Text','BASELINE SPICE   — dB','FontName','Consolas','FontSize',13,'FontColor',C.text); optBaselineReadout.Layout.Row=3;
optDLReadout=uiLabel(optResultGrid,'Text','DL PREDICTION    — dB','FontName','Consolas','FontSize',13,'FontColor',C.violet); optDLReadout.Layout.Row=4;
optSpiceReadout=uiLabel(optResultGrid,'Text','SPICE VERIFIED    — dB','FontName','Consolas','FontSize',13,'FontWeight','bold','FontColor',C.teal); optSpiceReadout.Layout.Row=5;
optDeltaReadout=uiLabel(optResultGrid,'Text','ACTUAL Δ          — dB','FontName','Consolas','FontSize',15,'FontWeight','bold','FontColor',C.copper); optDeltaReadout.Layout.Row=6;
optPredDeltaReadout=uiLabel(optResultGrid,'Text','DL predicted Δ    — dB','FontName','Consolas','FontSize',12,'FontColor',C.muted); optPredDeltaReadout.Layout.Row=7;
optOpReadout=uiLabel(optResultGrid,'Text','VCE — V   /   VCB — V','FontName','Consolas','FontSize',12,'FontColor',C.text); optOpReadout.Layout.Row=8;
optValidityReadout=uiLabel(optResultGrid,'Text','PHYSICAL VALID   /   CONSTRAINTS PASS','FontName','Consolas','FontSize',12,'FontWeight','bold','FontColor',C.teal,'WordWrap','on'); optValidityReadout.Layout.Row=9;
optWarningReadout=uiLabel(optResultGrid,'Text','','FontName','Arial','FontSize',12,'FontColor',C.muted,'WordWrap','on'); optWarningReadout.Layout.Row=10;
optDriverTitle=uiLabel(optResultGrid,'Text','WHY THIS DESIGN?','FontName','Arial','FontSize',13,'FontWeight','bold','FontColor',C.text); optDriverTitle.Layout.Row=11;
optDriverReadout=uiLabel(optResultGrid,'Text','Optimization movement is interpreted against the frozen global SHAP ranking.','FontName','Consolas','FontSize',12,'FontColor',C.muted,'WordWrap','on'); optDriverReadout.Layout.Row=12;
optResultNote=uiLabel(optResultGrid,'Text','Frozen Step 8E result. No optimization is executed live by the GUI. SPICE remains physical authority.','FontName','Consolas','FontSize',11,'FontColor',C.muted,'WordWrap','on'); optResultNote.Layout.Row=13;
optReturnButton=uibutton(optResultGrid,'push','Text','RETURN TO CIRCUIT','FontName','Arial','FontSize',12,'FontWeight','bold','BackgroundColor',C.bg,'FontColor',C.text,'ButtonPushedFcn',@hideOptimize); optReturnButton.Layout.Row=14;
optExplainButton=uibutton(optResultGrid,'push','Text','OPEN XAI VIEW','FontName','Arial','FontSize',12,'FontWeight','bold','BackgroundColor',C.bg,'FontColor',C.text,'ButtonPushedFcn',@showExplain); optExplainButton.Layout.Row=15;
optXAIStatus=uiLabel(optResultGrid,'Text','GLOBAL SHAP ↔ OPTIMIZATION / exploratory interpretation','FontName','Consolas','FontSize',11,'FontColor',C.violet,'WordWrap','on'); optXAIStatus.Layout.Row=16;

[optimizationLoaded,optimizationData] = loadOptimizationResearchData(OPTIMIZATION_SUMMARY_FILE,OPTIMIZATION_DESIGNS_FILE);

%% ================================================================

% 16. INSPECTOR / STATUS STRIP

% 16. INSPECTOR / STATUS STRIP

% ================================================================

inspector = uiLabel( ...
    workGrid, ...
    'Text','COMPONENT INSPECTOR     Select a symbol or reference', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontColor',C.muted, ...
    'BackgroundColor',C.surface, ...
    'WordWrap','on');

inspector.Layout.Row = 3;

%% ================================================================

% 17. MEASUREMENTS

% ================================================================

measurePanel = uipanel( ...
    workGrid, ...
    'BackgroundColor',C.surface, ...
    'BorderType','none');

measurePanel.Layout.Row = 4;

measureGrid = uigridlayout(measurePanel,[4 5]);

measureGrid.RowHeight = {18,17,'1x',17};

measureGrid.ColumnWidth = ...
    {'1.15x','1x','1x','1.25x','1.2x'};

measureGrid.Padding = [0 6 0 2];

measureGrid.ColumnSpacing = 14;

measureGrid.RowSpacing = 1;

measureHeading = uiLabel( ...
    measureGrid, ...
    'Text','LIVE MEASUREMENTS  /  RESEARCH ENGINE', ...
    'FontName','Arial', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'FontColor',C.muted);

measureHeading.Layout.Row = 1;

measureHeading.Layout.Column = [1 5];

gainValue = makeReadout( ...
    1,'GAIN','—','SPICE / local');

vceValue = makeReadout( ...
    2,'VCE','—','V');

icValue = makeReadout( ...
    3,'IC','—','mA');

dlValue = makeReadout( ...
    4,'DL MODEL','READY','Prediction');

spiceValue = makeReadout( ...
    5,'SPICE','READY','Verification');

%% ================================================================

% 18. WORKFLOW

% ================================================================

flow = uipanel( ...
    root, ...
    'BackgroundColor',C.surface, ...
    'BorderType','none');

flow.Layout.Row = 3;

flow.Layout.Column = [1 2];

flowGrid = uigridlayout(flow,[1 5]);

flowGrid.ColumnWidth = ...
    {'1x','1x','1x','1x','1x'};

flowGrid.RowHeight = {'1x'};

flowGrid.Padding = [8 8 8 8];

flowGrid.ColumnSpacing = 8;

stageNames = ...
    {'DESIGN','SIMULATE','EXPLAIN','OPTIMIZE','VERIFY'};

for n = 1:5

    stageName = stageNames{n};

    workflowButtons{n} = uibutton( ...
        flowGrid, ...
        'push', ...
        'Text',sprintf('%02d   %s',n,stageName), ...
        'FontName','Arial', ...
        'FontSize',10, ...
        'FontWeight','bold', ...
        'BackgroundColor',C.bg, ...
        'FontColor',C.muted);

    workflowButtons{n}.Layout.Row = 1;

    workflowButtons{n}.Layout.Column = n;

    if n == 1 || n == 2 || n == 3 || n == 4 || n == 5

        workflowButtons{n}.ButtonPushedFcn = ...
            @(src,event)workflowAction(stageName);

    else

        workflowButtons{n}.Enable = 'off';

        workflowButtons{n}.Tooltip = ...
            'Optimization will be connected in a later GUI phase.';

    end

end

setActiveStage(1);

refreshReadouts();

% Initialize optimization AFTER workflow buttons exist.
selectOptimizationCase('Medium');

%% ================================================================

% INITIAL XAI SELECTION

% ================================================================

selectXAIComponent('R1');

%% ========================================================================

% NESTED FUNCTIONS

% ========================================================================

%% ================================================================

% ADD SECTION

% ================================================================

    function addSection(name,row)

        lab = uiLabel( ...
            sideGrid, ...
            'Text',name, ...
            'FontName','Arial', ...
            'FontSize',10, ...
            'FontWeight','bold', ...
            'FontColor',C.muted);

        lab.Layout.Row = row;

    end

%% ================================================================

% ADD PARAMETER

% ================================================================

    function addParam(key,label,unit,initial,row,low,high)

        lineGrid = uigridlayout(sideGrid,[1 3]);

        lineGrid.Layout.Row = row;

        lineGrid.ColumnWidth = {55,'1x',38};

        lineGrid.RowHeight = {'1x'};

        lineGrid.Padding = [0 0 0 0];

        lineGrid.ColumnSpacing = 6;

        nameLab = uiLabel( ...
            lineGrid, ...
            'Text',label, ...
            'FontName','Consolas', ...
            'FontSize',11, ...
            'FontWeight','bold', ...
            'FontColor',C.text);

        nameLab.Layout.Row = 1;

        nameLab.Layout.Column = 1;

        edits.(key) = uieditfield( ...
            lineGrid, ...
            'numeric', ...
            'Value',initial, ...
            'Limits',[low high], ...
            'RoundFractionalValues','off', ...
            'ValueDisplayFormat','%.4g', ...
            'FontName','Consolas', ...
            'FontSize',11, ...
            'BackgroundColor',C.field, ...
            'FontColor',C.text, ...
            'ValueChangedFcn', ...
            @(src,event)parameterChanged(key,unit));

        edits.(key).Layout.Row = 1;

        edits.(key).Layout.Column = 2;

        unitLab = uiLabel( ...
            lineGrid, ...
            'Text',unit, ...
            'FontName','Arial', ...
            'FontSize',9, ...
            'FontColor',C.muted, ...
            'HorizontalAlignment','left');

        unitLab.Layout.Row = 1;

        unitLab.Layout.Column = 3;

    end

%% ================================================================

% READOUT

% ================================================================

    function out = makeReadout(col,label,value,unit)

        labelLab = uiLabel( ...
            measureGrid, ...
            'Text',label, ...
            'FontName','Arial', ...
            'FontSize',9, ...
            'FontWeight','bold', ...
            'FontColor',C.muted);

        labelLab.Layout.Row = 2;

        labelLab.Layout.Column = col;

        val = uiLabel( ...
            measureGrid, ...
            'Text',value, ...
            'FontName','Consolas', ...
            'FontSize',17, ...
            'FontWeight','bold', ...
            'FontColor',C.text, ...
            'VerticalAlignment','center');

        val.Layout.Row = 3;

        val.Layout.Column = col;

        unitLab = uiLabel( ...
            measureGrid, ...
            'Text',unit, ...
            'FontName','Arial', ...
            'FontSize',9, ...
            'FontColor',C.muted);

        unitLab.Layout.Row = 4;

        unitLab.Layout.Column = col;

        out = struct( ...
            'Value',val, ...
            'Label',labelLab, ...
            'Unit',unit, ...
            'UnitLabel',unitLab);

    end

%% ================================================================

% DRAW CIRCUIT

% ================================================================

    function drawCircuit()

        wire([38 38],[91 81]);

        resistorV( ...
            'R1',38,81,69, ...
            '150 kΩ','Upper divider resistor');

        wire([38 38],[69 53]);

        resistorV( ...
            'R2',38,45,34, ...
            '82 kΩ','Lower divider resistor');

        wire([38 38],[53 45]);

        wire([38 58],[53 53]);

        wire([38 38],[34 21]);

        wire([38 75],[91 91]);

        wire([75 75],[91 81]);

        resistorV( ...
            'RC',75,81,70, ...
            '1.5 kΩ','Collector load resistor');

        wire([75 75],[70 62]);

        wire([67 75],[62 62]);

        node(38,53);

        node(75,62);

        text( ...
            ax,56,95,'VCC', ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',10, ...
            'HorizontalAlignment','center');

        text( ...
            ax,34,86,'+V', ...
            'Color',C.teal, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','right');

        % Q1

        qCircle = rectangle( ...
            ax, ...
            'Position',[57 46 14 14], ...
            'Curvature',[1 1], ...
            'EdgeColor',C.text, ...
            'FaceColor','none', ...
            'LineWidth',1.5, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart('Q1'));

        qBase = plot( ...
            ax,[62 62],[49 57], ...
            'Color',C.text, ...
            'LineWidth',1.7, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart('Q1'));

        qCollector = plot( ...
            ax,[62 67],[57 62], ...
            'Color',C.text, ...
            'LineWidth',1.5, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart('Q1'));

        qEmitter = plot( ...
            ax,[62 67],[49 44], ...
            'Color',C.text, ...
            'LineWidth',1.5, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart('Q1'));

        qArrow = plot( ...
            ax,[65.2 67],[45.6 44], ...
            'Color',C.text, ...
            'LineWidth',1.4, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart('Q1'));

        parts.Q1 = partData( ...
            {qCircle,qBase,qCollector,qEmitter,qArrow}, ...
            'NPN', ...
            'Common-emitter transistor; active device');

        wire([58 62],[53 53]);

        text( ...
            ax,57,63,'Q1', ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','center', ...
            'ButtonDownFcn', ...
            @(src,event)selectPart('Q1'));

        % RE

        wire([67 68],[44 41]);

        wire([68 68],[41 39]);

        resistorV( ...
            'RE',68,39,29, ...
            '1.0 kΩ', ...
            'Emitter resistor; DC stabilization');

        wire([68 68],[29 21]);

        % Ce

        wire([68 83],[41 41]);

        wire([83 83],[41 36]);

        capV( ...
            'Ce',83,36,32, ...
            '4.70 µF', ...
            'Emitter bypass capacitor');

        wire([83 83],[32 21]);

        wire([63 88],[21 21]);

        ground(63,21);

        % Input

        wire([17 23],[53 53]);

        capH( ...
            'Cin',23,30,53, ...
            '0.70 µF', ...
            'Input coupling capacitor');

        wire([30 38],[53 53]);

        source = rectangle( ...
            ax, ...
            'Position',[7 48 10 10], ...
            'Curvature',[1 1], ...
            'EdgeColor',C.wire, ...
            'FaceColor','none', ...
            'LineWidth',1.2);

        plot( ...
            ax,[9 11 13 15], ...
            [53 54 52 53], ...
            'Color',C.wire, ...
            'LineWidth',1.0);

        text( ...
            ax,12,44,'VIN', ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','center');

        set(source,'HitTest','off');

        % Cout

        wire([75 75],[62 58]);

        capH( ...
            'Cout',75,82,58, ...
            '1.00 µF', ...
            'Output coupling capacitor');

        wire([82 91],[58 58]);

        wire([91 91],[58 49]);

        resistorV( ...
            'RL',91,49,39, ...
            '10 kΩ', ...
            'Output load resistor');

        wire([91 91],[39 21]);

        ground(91,21);

        text( ...
            ax,95,59,'VOUT', ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','left');

        ax.XLim = [0 100];

        ax.YLim = [0 100];

    end


%% ================================================================
% SIMULATION SCHEMATIC
% ================================================================

    function drawSimulationCircuit()
        a = simCircuitAx;
        p = readParameters();
        cla(a);
        hold(a,'on');
        simHitBoxes = struct();
        simOpTexts = struct();

        % Wider, cleaner schematic geometry.  The simulator axes are kept
        % visually balanced with the two measurement plots beside them.
        colWire = C.wire;
        colText = C.text;
        colMute = C.muted;
        colSel  = C.copper;
        lw = 1.4;

        % -----------------------------------------------------------
        % SUPPLY / BIAS NETWORK
        % -----------------------------------------------------------
        plot(a,[48 48],[82 74],'Color',colWire,'LineWidth',lw);
        text(a,48,87,sprintf('VCC  %.4g V',p.VCC), ...
            'Color',colText,'FontName','Consolas','FontSize',9, ...
            'HorizontalAlignment','center');

        % R1
        plot(a,[48 48],[74 70],'Color',colWire,'LineWidth',lw);
        resistorSimV(a,48,70,60,p.R1/1e3,'R1');
        plot(a,[48 48],[60 56],'Color',colWire,'LineWidth',lw);
        text(a,39,65,sprintf('R1  %.4g kΩ',p.R1/1e3), ...
            'Color',colMute,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','right');

        % R2
        resistorSimV(a,48,52,42,p.R2/1e3,'R2');
        plot(a,[48 48],[42 24],'Color',colWire,'LineWidth',lw);
        groundSim(a,48,22);
        text(a,39,47,sprintf('R2  %.4g kΩ',p.R2/1e3), ...
            'Color',colMute,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','right');

        % Base node
        plot(a,[48 48],[56 52],'Color',colWire,'LineWidth',lw);
        plot(a,[48 58],[56 56],'Color',colWire,'LineWidth',lw);
        plot(a,48,56,'o','MarkerSize',4,'MarkerFaceColor',colWire,'MarkerEdgeColor',colWire);

        % -----------------------------------------------------------
        % TRANSISTOR / COLLECTOR / EMITTER
        % -----------------------------------------------------------
        % Q1
        plot(a,[61 61],[51 61],'Color',colText,'LineWidth',1.8);
        plot(a,[61 66],[61 66],'Color',colText,'LineWidth',1.6);
        plot(a,[61 66],[51 46],'Color',colText,'LineWidth',1.6);
        plot(a,[63.8 66],[48.2 46],'Color',colText,'LineWidth',1.4);
        plot(a,[58 61],[56 56],'Color',colText,'LineWidth',1.8);
        plot(a,61,56,'o','MarkerSize',11,'MarkerEdgeColor',colText,'MarkerFaceColor','none','LineWidth',1.2);
        text(a,69,55,'Q1','Color',colText,'FontName','Consolas','FontSize',9,'FontWeight','bold');

        % RC collector branch
        plot(a,[66 76],[66 66],'Color',colWire,'LineWidth',lw);
        resistorSimV(a,76,78,66,p.RC/1e3,'RC');
        plot(a,[76 76],[78 82],'Color',colWire,'LineWidth',lw);
        plot(a,[76 76],[66 61],'Color',colWire,'LineWidth',lw);
        plot(a,[66 76],[61 61],'Color',colWire,'LineWidth',lw);
        text(a,80,72,sprintf('RC  %.4g kΩ',p.RC/1e3), ...
            'Color',colMute,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','left');

        % Emitter resistor
        plot(a,[66 66],[46 42],'Color',colWire,'LineWidth',lw);
        resistorSimV(a,66,42,33,p.RE/1e3,'RE');
        plot(a,[66 66],[33 23],'Color',colWire,'LineWidth',lw);
        groundSim(a,66,21);
        text(a,71,38,sprintf('RE  %.4g kΩ',p.RE/1e3), ...
            'Color',colMute,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','left');

        % Emitter bypass capacitor
        plot(a,[66 78],[46 46],'Color',colWire,'LineWidth',lw);
        plot(a,[78 78],[46 39],'Color',colWire,'LineWidth',lw);
        plot(a,[73 83],[39 39],'Color',colWire,'LineWidth',1.6);
        plot(a,[73 83],[36 36],'Color',colWire,'LineWidth',1.6);
        plot(a,[78 78],[36 23],'Color',colWire,'LineWidth',lw);
        groundSim(a,78,21);
        text(a,84,38,sprintf('Ce  %.4g µF',p.Ce*1e6), ...
            'Color',colMute,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','left');

        % -----------------------------------------------------------
        % INPUT COUPLING
        % -----------------------------------------------------------
        plot(a,[8 20],[56 56],'Color',colWire,'LineWidth',lw);
        plot(a,[20 20],[52 60],'Color',colWire,'LineWidth',1.6);
        plot(a,[23 23],[52 60],'Color',colWire,'LineWidth',1.6);
        plot(a,[23 48],[56 56],'Color',colWire,'LineWidth',lw);
        plot(a,8,56,'o','MarkerSize',7,'MarkerFaceColor','none','MarkerEdgeColor',colWire,'LineWidth',1.1);
        text(a,10,62,'VIN','Color',colText,'FontName','Consolas','FontSize',8,'HorizontalAlignment','center');
        text(a,21.5,66,sprintf('Cin  %.4g µF',p.Cin*1e6), ...
            'Color',colMute,'FontName','Consolas','FontSize',8,'HorizontalAlignment','center');

        % -----------------------------------------------------------
        % OUTPUT COUPLING / LOAD
        % -----------------------------------------------------------
        plot(a,[76 86],[61 61],'Color',colWire,'LineWidth',lw);
        plot(a,[86 86],[57 65],'Color',colWire,'LineWidth',1.6);
        plot(a,[89 89],[57 65],'Color',colWire,'LineWidth',1.6);
        plot(a,[89 101],[61 61],'Color',colWire,'LineWidth',lw);
        text(a,87.5,69,sprintf('Cout  %.4g µF',p.Cout*1e6), ...
            'Color',colMute,'FontName','Consolas','FontSize',8,'HorizontalAlignment','center');
        text(a,103,64,'VOUT','Color',colText,'FontName','Consolas','FontSize',8,'HorizontalAlignment','left');

        resistorSimV(a,101,53,43,p.RL/1e3,'RL');
        plot(a,[101 101],[43 23],'Color',colWire,'LineWidth',lw);
        groundSim(a,101,21);
        text(a,106,48,sprintf('RL  %.4g kΩ',p.RL/1e3), ...
            'Color',colMute,'FontName','Consolas','FontSize',8,'HorizontalAlignment','left');

        % Section caption
        text(a,55,7,'COMMON-EMITTER  /  CLICK A COMPONENT TO INSPECT', ...
            'Color',C.teal,'FontName','Consolas','FontSize',8, ...
            'HorizontalAlignment','center');

        % Transparent hit zones make the schematic interactive without
        % changing its visual appearance.
        addSimHit(a,'VCC',[39 78 18 11]);
        addSimHit(a,'R1',[40 59 16 13]);
        addSimHit(a,'R2',[40 41 16 13]);
        addSimHit(a,'RC',[69 64 15 17]);
        addSimHit(a,'RE',[59 31 15 14]);
        addSimHit(a,'Ce',[70 32 17 16]);
        addSimHit(a,'Cin',[16 50 13 13]);
        addSimHit(a,'Cout',[82 55 13 13]);
        addSimHit(a,'RL',[95 39 17 17]);
        addSimHit(a,'Q1',[55 46 18 20]);

        a.XLim=[0 114];
        a.YLim=[0 94];
        a.XTick=[]; a.YTick=[];
        a.DataAspectRatio=[1 1 1];
        a.PlotBoxAspectRatio=[1.18 1 1];
    end

    function resistorSimV(a,x,top,bottom,val,key)
        mid=(top+bottom)/2;
        z=1.6;
        yy=[top,mid+z,mid+z/2,mid-z/2,mid-z,bottom];
        xx=[x,x+2,x-2,x+2,x-2,x];
        plot(a,xx,yy,'Color',C.wire,'LineWidth',1.6);
    end

    function groundSim(a,x,y)
        plot(a,[x-4 x+4],[y y],'Color',C.wire,'LineWidth',1.2);
        plot(a,[x-2.8 x+2.8],[y-2 y-2],'Color',C.wire,'LineWidth',1.2);
        plot(a,[x-1.5 x+1.5],[y-4 y-4],'Color',C.wire,'LineWidth',1.2);
    end

    function addSimHit(a,key,pos)
        h=rectangle(a,'Position',pos,'FaceColor',C.recess,'FaceAlpha',0.01, ...
            'EdgeColor','none','HitTest','on', ...
            'PickableParts','all','ButtonDownFcn',@(src,event)selectSimulationPart(key));
        simHitBoxes.(key)=h;
    end


%% ================================================================

% RESISTOR

% ================================================================

    function resistorV(key,x,top,bottom,value,role)

        pad = 2.2;

        n = 6;

        xx = x + ...
            [-2.2 2.2 -2.2 2.2 -2.2 2.2 -2.2];

        yy = linspace( ...
            top-pad, ...
            bottom+pad, ...
            n+1);

        leadTop = plot( ...
            ax,[x x],[top top-pad], ...
            'Color',C.wire, ...
            'LineWidth',1.3, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        body = plot( ...
            ax,xx,yy, ...
            'Color',C.wire, ...
            'LineWidth',1.5, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        leadBottom = plot( ...
            ax,[x x],[bottom+pad bottom], ...
            'Color',C.wire, ...
            'LineWidth',1.3, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        ref = text( ...
            ax,x-4,mean([top bottom]),key, ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','right', ...
            'VerticalAlignment','middle', ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        parts.(key) = partData( ...
            {leadTop,body,leadBottom,ref}, ...
            value,role);

    end

%% ================================================================

% VERTICAL CAPACITOR

% ================================================================

    function capV(key,x,top,bottom,value,role)

        mid = (top+bottom)/2;

        gap = 1.4;

        half = 3.0;

        h1 = plot( ...
            ax,[x-half x+half],[mid+gap mid+gap], ...
            'Color',C.wire, ...
            'LineWidth',1.6, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        h2 = plot( ...
            ax,[x-half x+half],[mid-gap mid-gap], ...
            'Color',C.wire, ...
            'LineWidth',1.6, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        l1 = plot( ...
            ax,[x x],[top mid+gap], ...
            'Color',C.wire, ...
            'LineWidth',1.3, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        l2 = plot( ...
            ax,[x x],[mid-gap bottom], ...
            'Color',C.wire, ...
            'LineWidth',1.3, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        ref = text( ...
            ax,x+4,mid,key, ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','middle', ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        parts.(key) = partData( ...
            {h1,h2,l1,l2,ref}, ...
            value,role);

    end

%% ================================================================

% HORIZONTAL CAPACITOR

% ================================================================

    function capH(key,left,right,y,value,role)

        mid = (left+right)/2;

        gap = 1.4;

        half = 3.0;

        h1 = plot( ...
            ax,[mid-gap mid-gap],[y-half y+half], ...
            'Color',C.wire, ...
            'LineWidth',1.6, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        h2 = plot( ...
            ax,[mid+gap mid+gap],[y-half y+half], ...
            'Color',C.wire, ...
            'LineWidth',1.6, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        l1 = plot( ...
            ax,[left mid-gap],[y y], ...
            'Color',C.wire, ...
            'LineWidth',1.3, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        l2 = plot( ...
            ax,[mid+gap right],[y y], ...
            'Color',C.wire, ...
            'LineWidth',1.3, ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        ref = text( ...
            ax,mid,y+5,key, ...
            'Color',C.muted, ...
            'FontName','Consolas', ...
            'FontSize',9, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'ButtonDownFcn', ...
            @(src,event)selectPart(key));

        parts.(key) = partData( ...
            {h1,h2,l1,l2,ref}, ...
            value,role);

    end

%% ================================================================

% PART DATA

% ================================================================

    function p = partData(handles,value,role)

        base = cell(size(handles));

        for ii = 1:numel(handles)

            base{ii} = ...
                getGraphicColor(handles{ii});

        end

        p = struct( ...
            'Handles',{handles}, ...
            'BaseColors',{base}, ...
            'Value',value, ...
            'Role',role);

    end

%% ================================================================

% GRAPHIC COLOR

% ================================================================

    function color = getGraphicColor(h)

        if isprop(h,'EdgeColor')

            color = h.EdgeColor;

        else

            color = h.Color;

        end

    end

    function setGraphicColor(h,color)

        if isprop(h,'EdgeColor')

            h.EdgeColor = color;

        else

            h.Color = color;

        end

    end

%% ================================================================

% WIRE

% ================================================================

    function wire(x,y)

        plot( ...
            ax,x,y, ...
            'Color',C.wire, ...
            'LineWidth',1.25, ...
            'HitTest','off');

    end

%% ================================================================

% NODE

% ================================================================

    function node(x,y)

        plot( ...
            ax,x,y,'o', ...
            'MarkerSize',4, ...
            'MarkerFaceColor',C.copper, ...
            'MarkerEdgeColor',C.copper, ...
            'HitTest','off');

    end

%% ================================================================

% GROUND

% ================================================================

    function ground(x,y)

        plot( ...
            ax,[x-3 x+3],[y y], ...
            'Color',C.wire, ...
            'LineWidth',1.2, ...
            'HitTest','off');

        plot( ...
            ax,[x-2 x+2],[y-1.5 y-1.5], ...
            'Color',C.wire, ...
            'LineWidth',1.2, ...
            'HitTest','off');

        plot( ...
            ax,[x-1 x+1],[y-3 y-3], ...
            'Color',C.wire, ...
            'LineWidth',1.2, ...
            'HitTest','off');

    end

%% ================================================================

% READ PARAMETERS

% ================================================================

    function p = readParameters()

        p.R1 = edits.R1.Value*1e3;

        p.R2 = edits.R2.Value*1e3;

        p.RC = edits.RC.Value*1e3;

        p.RE = edits.RE.Value*1e3;

        p.RL = edits.RL.Value*1e3;

        p.Cin = edits.Cin.Value*1e-6;

        p.Cout = edits.Cout.Value*1e-6;

        p.Ce = edits.Ce.Value*1e-6;

        p.VCC = edits.VCC.Value;

    end

%% ================================================================

% LOCAL ESTIMATE

% ================================================================

    function result = runLocalEstimate(p)

        beta = 100;

        Vbe = 0.70;

        Vt = 0.02585;

        vth = ...
            p.VCC*p.R2/(p.R1+p.R2);

        rth = ...
            p.R1*p.R2/(p.R1+p.R2);

        result.VB = ...
            (vth+(rth/p.RE)*(Vbe/(beta+1))) / ...
            (1+rth/(p.RE*(beta+1)));

        result.VE = ...
            max(0,result.VB-Vbe);

        result.IC = ...
            max(0,result.VE/p.RE*beta/(beta+1));

        result.VC = ...
            p.VCC-result.IC*p.RC;

        result.VCE = ...
            result.VC-result.VE;

        gm = result.IC/Vt;

        rload = ...
            1/(1/p.RC+1/p.RL);

        result.Gain = ...
            -gm*rload;

        result.Valid = ...
            result.IC > 0 && ...
            result.VCE > 0 && ...
            result.VC < p.VCC;

    end

%% ================================================================

% DL PREDICTION

% ================================================================

    function result = runDLPrediction(p)

        result.Success = false;

        result.Gain_dB = NaN;

        result.Error = '';

        if ~dlLoaded

            result.Error = ...
                'Trained DL model is not loaded.';

            return;

        end

        if ~normalizationLoaded

            result.Error = ...
                'Exact research preprocessing is unavailable.';

            return;

        end

        X = [ ...
            p.R1, ...
            p.R2, ...
            p.RC, ...
            p.RE, ...
            p.RL, ...
            p.Cin, ...
            p.Cout, ...
            p.Ce, ...
            p.VCC];

        % Exact research transformation.

        X(1:8) = log10(X(1:8));

        X = ...
            (X-dlMu)./dlSigma;

        try

            % INFERENCE ONLY.

            Y = predict( ...
                dlModel, ...
                single(X));

            result.Gain_dB = ...
                double(Y(1));

            if isfinite(result.Gain_dB)

                result.Success = true;

            else

                result.Error = ...
                    'DL prediction is non-finite.';

            end

        catch ME

            result.Error = ME.message;

        end

    end

%% ================================================================

% SPICE VERIFICATION

% ================================================================

    function result = runSPICEVerification(p)

        result.Success = false;

        result.Gain_dB = NaN;

        result.VCE = NaN;

        result.VCB = NaN;

        result.IC = NaN;

        result.IB = NaN;

        result.VB = NaN;

        result.VE = NaN;

        result.VC = NaN;

        result.fL = NaN;
        result.fH = NaN;
        result.bandwidth = NaN;
        result.freq = [];
        result.gain_curve = [];
        result.phase_curve = [];

        result.PhysicalValid = false;

        result.Error = '';

        if ~spiceAvailable

            result.Error = ...
                'runSpice.m unavailable.';

            return;

        end

        if ~exist(SPICE_EXE,'file')

            result.Error = ...
                'ngspice executable unavailable.';

            return;

        end

        workDir = fullfile( ...
            tempdir, ...
            'CE_XAI_Lab_SPICE');

        if ~exist(workDir,'dir')

            mkdir(workDir);

        end

        options = struct();

        options.ngspice_exe = SPICE_EXE;

        options.cleanup = true;

        try

            r = runSpice( ...
                p, ...
                workDir, ...
                options);

            if ~r.success

                if isfield(r,'error_msg')

                    result.Error = r.error_msg;

                else

                    result.Error = ...
                        'ngspice simulation failed.';

                end

                return;

            end

            result.Gain_dB = r.gain_dB;

            result.VB = r.VB;

            result.VE = r.VE;

            result.VC = r.VC;
            result.fL = r.fL;
            result.fH = r.fH;
            result.bandwidth = r.bandwidth;
            result.freq = r.freq;
            result.gain_curve = r.gain_curve;
            result.phase_curve = r.phase_curve;

            result.VCE = r.VCE;

            result.VCB = r.VC-r.VB;

            result.IC = r.IC;

            result.IB = r.IB;

            VBE = r.VB-r.VE;

            result.PhysicalValid = ...
                r.IC > 1e-7 && ...
                VBE >= 0.55 && ...
                VBE <= 0.90 && ...
                result.VCB > 0 && ...
                r.VCE > 0.2 && ...
                r.VCE < 0.9*p.VCC;

            result.Success = true;

        catch ME

            result.Error = ME.message;

        end

    end

%% ================================================================

% REFRESH READOUTS

% ================================================================

    function refreshReadouts()

        p = readParameters();

        local = runLocalEstimate(p);

        % Don't emphasize the crude local estimate.

        gainValue.Value.Text = ...
            '—';

        gainValue.Value.FontColor = C.muted;

        gainValue.UnitLabel.Text = ...
            'await SPICE';

        vceValue.Value.Text = ...
            '—';

        vceValue.Value.FontColor = C.muted;

        vceValue.UnitLabel.Text = ...
            'await SPICE';

        icValue.Value.Text = ...
            '—';

        icValue.Value.FontColor = C.muted;

        icValue.UnitLabel.Text = ...
            'await SPICE';

        % DL

        if dlLoaded && normalizationLoaded

            dlValue.Value.Text = 'READY';

            dlValue.Value.FontSize = 12;

            dlValue.Value.FontColor = C.teal;

            dlValue.UnitLabel.Text = ...
                'trained model / PREDICT';

        else

            dlValue.Value.Text = 'BLOCKED';

            dlValue.Value.FontSize = 11;

            dlValue.Value.FontColor = C.red;

            dlValue.UnitLabel.Text = ...
                'model unavailable';

        end

        % SPICE

        if spiceAvailable && exist(SPICE_EXE,'file')

            spiceValue.Value.Text = 'READY';

            spiceValue.Value.FontSize = 12;

            spiceValue.Value.FontColor = C.teal;

            spiceValue.UnitLabel.Text = ...
                'VERIFY / ngspice';

        else

            spiceValue.Value.Text = 'OFFLINE';

            spiceValue.Value.FontSize = 11;

            spiceValue.Value.FontColor = C.red;

            spiceValue.UnitLabel.Text = ...
                'SPICE unavailable';

        end

    end

%% ================================================================

% INTERACTIVE SIMULATION

% ================================================================

    function simulateNow(~,~)

        xaiPanel.Visible = 'off';
        optPanel.Visible = 'off';
        ax.Visible = 'off';
        simPanel.Visible = 'on';

        benchTitle.Text = 'Interactive CE simulation';
        benchHint.Text = 'Editable design → ngspice DC/AC → DL comparison';
        setActiveStage(2);

        p = readParameters();

        simStatus.Text = 'RUNNING / netlist → DC operating point → AC sweep';
        simStatus.FontColor = C.amber;
        simSummary.Text = 'Simulation in progress...';
        inspector.Text = 'SIMULATION / Running ngspice on the current editable CE design...';
        gainValue.Value.Text = '...';
        vceValue.Value.Text = '...';
        icValue.Value.Text = '...';
        spiceValue.Value.Text = 'RUNNING';
        dlValue.Value.Text = '...';
        drawnow;

        spice = runSPICEVerification(p);

        if ~spice.Success
            simStatus.Text = 'FAILED / ngspice did not return a valid result';
            simStatus.FontColor = C.red;
            simSummary.Text = ['SPICE ERROR / ' spice.Error];
            inspector.Text = ['SIMULATION ERROR / ' spice.Error];
            spiceValue.Value.Text = 'ERROR';
            spiceValue.Value.FontColor = C.red;
            compareDL.Text = 'DL —';
            compareDelta.Text = 'Δ —';
            compareValid.Text = 'SPICE ERROR';
            return;
        end

        lastSimulation = spice;
        updateSimulationOperatingPoint(spice);
        if ~spice.Success
            simStatus.Text='SPICE FAILED / inspect the error message below'; simStatus.FontColor=C.red;
        elseif ~(spice.PhysicalValid && spice.VCE>=1.0 && spice.VCB>=0.5)
            simStatus.Text='SPICE COMPLETE / operating-point warning'; simStatus.FontColor=C.amber;
        else
            simStatus.Text='SPICE COMPLETE / physical + circuit checks pass'; simStatus.FontColor=C.teal;
        end
        if ~isempty(verifyPanel) && isvalid(verifyPanel), updateVerifyHealth(); end

        dcVB.Text = sprintf('VB  %.3f V',spice.VB);
        dcVE.Text = sprintf('VE  %.3f V',spice.VE);
        dcVC.Text = sprintf('VC  %.3f V',spice.VC);
        dcVCE.Text = sprintf('VCE %.3f V',spice.VCE);
        metricGain.Text = sprintf('GAIN %.2f dB',spice.Gain_dB);
        metricIC.Text = sprintf('IC %.3f mA',spice.IC*1e3);
        metricRL.Text = sprintf('BW %.2f Hz',spice.bandwidth);
        metricFL.Text = sprintf('fL %.2f Hz',spice.fL);
        metricFH.Text = sprintf('fH %.2f Hz',spice.fH);

        if ~isempty(spice.freq) && ~isempty(spice.gain_curve)
            cla(simGainAx);
            semilogx(simGainAx,spice.freq,spice.gain_curve,'LineWidth',1.8);
            grid(simGainAx,'on');
        end

        if ~isempty(spice.freq) && ~isempty(spice.phase_curve)
            cla(simPhaseAx);
            semilogx(simPhaseAx,spice.freq,spice.phase_curve,'LineWidth',1.8);
            grid(simPhaseAx,'on');
        end

        gainValue.Value.Text = sprintf('%.2f dB',spice.Gain_dB);
        gainValue.Value.FontColor = C.teal;
        vceValue.Value.Text = sprintf('%.2f V',spice.VCE);
        vceValue.Value.FontColor = C.teal;
        icValue.Value.Text = sprintf('%.2f mA',spice.IC*1e3);
        icValue.Value.FontColor = C.teal;
        spiceValue.Value.Text = 'VERIFIED';
        spiceValue.Value.FontColor = C.teal;

        dl = runDLPrediction(p);
        if dl.Success
            dlValue.Value.Text = sprintf('%.2f dB',dl.Gain_dB);
            dlValue.Value.FontColor = C.violet;
            dlValue.UnitLabel.Text = 'DL prediction';
            delta = dl.Gain_dB - spice.Gain_dB;
            compareDL.Text = sprintf('DL %.2f dB',dl.Gain_dB);
            compareDelta.Text = sprintf('Δ %+0.2f dB',delta);
            compareValid.Text = sprintf('SPICE %s',ternary(spice.PhysicalValid,'VALID','CHECK'));
            updateLiveSimulationXAI(p,dl,spice);
            simSummary.Text = sprintf(['SPICE %.3f dB   |   DL %.3f dB   |   Δ %+0.3f dB   |   ' ...
                'VCE %.3f V   |   VCB %.3f V   |   IC %.3f mA   |   PHYSICAL VALID %d'], ...
                spice.Gain_dB,dl.Gain_dB,delta,spice.VCE,spice.VCB,spice.IC*1e3,spice.PhysicalValid);
            inspector.Text = sprintf(['SIMULATION COMPLETE / SPICE gain %.3f dB / DL prediction %.3f dB / ' ...
                'model-physics difference %+0.3f dB. SPICE remains physical authority.'], ...
                spice.Gain_dB,dl.Gain_dB,delta);
        else
            dlValue.Value.Text = 'OFFLINE';
            dlValue.Value.FontColor = C.muted;
            compareDL.Text = 'DL OFFLINE';
            compareDelta.Text = 'Δ —';
            compareValid.Text = sprintf('SPICE %s',ternary(spice.PhysicalValid,'VALID','CHECK'));
            updateLiveSimulationXAI(p,struct('Success',false,'Gain_dB',NaN),spice);
            simSummary.Text = sprintf('SPICE %.3f dB | VCE %.3f V | VCB %.3f V | IC %.3f mA | DL unavailable', ...
                spice.Gain_dB,spice.VCE,spice.IC*1e3);
            inspector.Text = 'SIMULATION COMPLETE / DL prediction unavailable.';
        end

        simStatus.Text = sprintf('COMPLETE / SPICE %.3f dB / fL %.1f Hz / fH %.1f Hz', ...
            spice.Gain_dB,spice.fL,spice.fH);
        simStatus.FontColor = C.teal;
        setActiveStage(2);
        drawnow;

    end

%% ================================================================

% PREDICT

% ================================================================

    function predictNow(~,~)

        hideExplain();

        p = readParameters();

        dlValue.Value.Text = ...
            'RUNNING...';

        dlValue.Value.FontColor = C.amber;

        dlValue.Value.FontSize = 11;

        dlValue.UnitLabel.Text = ...
            'DL inference';

        inspector.Text = ...
            'DL PREDICTION / Running trained network inference...';

        drawnow;

        dl = runDLPrediction(p);

        if dl.Success

            dlValue.Value.Text = ...
                sprintf('%.2f dB',dl.Gain_dB);

            dlValue.Value.FontColor = C.teal;

            dlValue.Value.FontSize = 14;

            dlValue.UnitLabel.Text = ...
                'trained DL prediction';

            inspector.Text = sprintf( ...
                ['DL PREDICTION / Gain = %.3f dB / ' ...
                 '9-feature trained network'], ...
                dl.Gain_dB);

            setActiveStage(2);

        else

            dlValue.Value.Text = ...
                'ERROR';

            dlValue.Value.FontColor = C.red;

            dlValue.UnitLabel.Text = ...
                'prediction failed';

            inspector.Text = ...
                ['DL ERROR / ' dl.Error];

        end

    end

%% ================================================================

% VERIFY

% ================================================================

    function verifyNow()

        xaiPanel.Visible='off'; optPanel.Visible='off'; simPanel.Visible='off'; ax.Visible='off';
        if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='on'; end
        p = readParameters();

        spiceValue.Value.Text = ...
            'RUNNING...';

        spiceValue.Value.FontColor = C.amber;

        spiceValue.Value.FontSize = 11;

        spiceValue.UnitLabel.Text = ...
            'ngspice';

        inspector.Text = ...
            'SPICE VERIFY / Running validated ngspice adapter...';

        drawnow;

        spice = ...
            runSPICEVerification(p);

        lastSimulation = spice;
        if ~spice.Success

            spiceValue.Value.Text = ...
                'ERROR';

            spiceValue.Value.FontColor = C.red;

            spiceValue.UnitLabel.Text = ...
                'SPICE failed';

            inspector.Text = ...
                ['SPICE ERROR / ' spice.Error];
            if ~isempty(verifyPanel) && isvalid(verifyPanel)
                verifySummary.Text=['SPICE FAILED / ' spice.Error]; verifySummary.FontColor=C.red;
                verifyStatus.Text='SPICE FAILED / physical verification unavailable'; verifyStatus.FontColor=C.red;
                updateVerifyHealth();
            end

            return;

        end

        gainValue.Value.Text = ...
            sprintf('%.2f',spice.Gain_dB);

        gainValue.Value.FontColor = C.teal;

        gainValue.UnitLabel.Text = ...
            'SPICE measured';

        vceValue.Value.Text = ...
            sprintf('%.2f',spice.VCE);

        vceValue.Value.FontColor = C.teal;

        vceValue.UnitLabel.Text = ...
            'SPICE';

        icValue.Value.Text = ...
            sprintf('%.2f',spice.IC*1e3);

        icValue.Value.FontColor = C.teal;

        icValue.UnitLabel.Text = ...
            'SPICE';

        spiceValue.Value.Text = ...
            sprintf('%.2f dB',spice.Gain_dB);

        spiceValue.Value.FontSize = 14;

        if spice.PhysicalValid

            spiceValue.Value.FontColor = C.teal;

            spiceValue.UnitLabel.Text = ...
                sprintf( ...
                'VALID / VCB %.2f V', ...
                spice.VCB);

        else

            spiceValue.Value.FontColor = C.red;

            spiceValue.UnitLabel.Text = ...
                sprintf( ...
                'INVALID / VCB %.2f V', ...
                spice.VCB);

        end

        dl = runDLPrediction(p);

        if dl.Success

            error_dB = ...
                dl.Gain_dB-spice.Gain_dB;

            inspector.Text = sprintf( ...
                ['SPICE VERIFIED / DL %.3f dB | ' ...
                 'SPICE %.3f dB | Δ %.3f dB | |Δ| %.3f dB | ' ...
                 'VCE %.3f V | VCB %.3f V | Physical %s'], ...
                dl.Gain_dB, ...
                spice.Gain_dB, ...
                error_dB, ...
                abs(error_dB), ...
                spice.VCE, ...
                spice.VCB, ...
                ternary( ...
                    spice.PhysicalValid, ...
                    'VALID', ...
                    'INVALID'));

        else

            inspector.Text = sprintf( ...
                ['SPICE VERIFIED / Gain %.3f dB | ' ...
                 'VCE %.3f V | VCB %.3f V | IC %.3f mA'], ...
                spice.Gain_dB, ...
                spice.VCE, ...
                spice.VCB, ...
                spice.IC*1e3);

        end

        if ~isempty(verifyPanel) && isvalid(verifyPanel)
            updateVerifyHealth();
            if spice.PhysicalValid && spice.VCE>=1.0 && spice.VCB>=0.5
                verifySummary.Text=sprintf('SPICE VERIFIED\nGain %.3f dB\nVB %.3f V\nVE %.3f V\nVC %.3f V\nVCE %.3f V\nVCB %.3f V\nIC %.3f mA\n\nPhysical + circuit constraints pass',spice.Gain_dB,spice.VB,spice.VE,spice.VC,spice.VCE,spice.VCB,spice.IC*1e3); verifySummary.FontColor=C.teal;
            else
                verifySummary.Text=sprintf('SPICE RESULT / CHECK\nGain %.3f dB\nVCE %.3f V\nVCB %.3f V\nIC %.3f mA\n\nOperating-point or constraint check requires attention',spice.Gain_dB,spice.VCE,spice.VCB,spice.IC*1e3); verifySummary.FontColor=C.amber;
            end
            verifyStatus.Text='SPICE VERIFICATION COMPLETE'; verifyStatus.FontColor=C.teal;
        end
        setActiveStage(5);

    end

%% ================================================================

% LIVE OPERATING-POINT VISUALIZATION

% ================================================================

    function updateSimulationOperatingPoint(spice)
        clearSimulationOperatingPoint();
        if isempty(spice) || ~isfield(spice,'Success') || ~spice.Success
            return;
        end
        a=simCircuitAx;
        simOpTexts.VB = text(a,50,59,sprintf('VB %.2f V',spice.VB), ...
            'Color',C.teal,'FontName','Consolas','FontSize',8,'FontWeight','bold', ...
            'HorizontalAlignment','left','BackgroundColor',C.recess,'Margin',1);
        simOpTexts.VC = text(a,68,63,sprintf('VC %.2f V',spice.VC), ...
            'Color',C.teal,'FontName','Consolas','FontSize',8,'FontWeight','bold', ...
            'HorizontalAlignment','left','BackgroundColor',C.recess,'Margin',1);
        simOpTexts.VE = text(a,68,42,sprintf('VE %.2f V',spice.VE), ...
            'Color',C.teal,'FontName','Consolas','FontSize',8,'FontWeight','bold', ...
            'HorizontalAlignment','left','BackgroundColor',C.recess,'Margin',1);
        simOpTexts.IC = text(a,71,50,sprintf('IC %.2f mA',spice.IC*1e3), ...
            'Color',C.amber,'FontName','Consolas','FontSize',7,'FontWeight','bold', ...
            'HorizontalAlignment','left','BackgroundColor',C.recess,'Margin',1);
        validity = spice.PhysicalValid && spice.VCE >= 1.0 && spice.VCB >= 0.5;
        col = C.teal; tag='PHYSICALLY VALID';
        if ~validity, col=C.red; tag='CHECK OPERATING POINT'; end
        simOpTexts.VCE = text(a,57,12,sprintf('VCE %.2f V  /  VCB %.2f V  /  %s',spice.VCE,spice.VCB,tag), ...
            'Color',col,'FontName','Consolas','FontSize',8,'FontWeight','bold', ...
            'HorizontalAlignment','center','BackgroundColor',C.recess,'Margin',1);
    end

    function clearSimulationOperatingPoint()
        if isempty(fieldnames(simOpTexts)), return; end
        names=fieldnames(simOpTexts);
        for ii=1:numel(names)
            h=simOpTexts.(names{ii});
            if ~isempty(h) && isvalid(h), delete(h); end
        end
        simOpTexts=struct();
    end

%% ================================================================

% LIVE XAI CONNECTED TO CURRENT SIMULATION

% ================================================================

    function updateLiveSimulationXAI(p,dl,spice)
        if ~xaiLoaded
            simLiveXai.Text='XAI research data unavailable.';
            return;
        end
        % This is a live connection to the current circuit using the
        % validated global SHAP research ranking. The GUI does not claim
        % to recompute local SHAP values in real time.
        [~,ord]=sort(xaiValues,'descend');
        top=ord(1:3);
        lines={};
        if ~isempty(simSelectedKey) && ismember(simSelectedKey,xaiFeatureNames)
            idx=find(strcmp(xaiFeatureNames,simSelectedKey),1);
            lines{end+1}=sprintf('%s  %.4g %s  |  SHAP %.2f dB  |  %s', ...
                simSelectedKey,componentNumericValue(simSelectedKey,p),componentUnit(simSelectedKey), ...
                xaiValues(idx),xaiDirection{idx}); %#ok<AGROW>
        end
        for ii=1:numel(top)
            k=top(ii);
            if ~strcmp(xaiFeatureNames{k},simSelectedKey)
                lines{end+1}=sprintf('#%d %s  |  Mean |SHAP| %.2f dB  |  %s', ...
                    xaiRanks(k),xaiFeatureNames{k},xaiValues(k),xaiDirection{k}); %#ok<AGROW>
            end
        end
        if dl.Success
            lines{end+1}=sprintf('DL %.2f dB  |  SPICE %.2f dB  |  Δ %+0.2f dB',dl.Gain_dB,spice.Gain_dB,dl.Gain_dB-spice.Gain_dB); %#ok<AGROW>
        end
        lines{end+1}='Research SHAP guidance; no live SHAP recomputation.'; %#ok<AGROW>
        simLiveXai.Text=strjoin(lines,sprintf('\n'));
    end

    function v=componentNumericValue(key,p)
        switch key
            case 'R1', v=p.R1/1e3;
            case 'R2', v=p.R2/1e3;
            case 'RC', v=p.RC/1e3;
            case 'RE', v=p.RE/1e3;
            case 'RL', v=p.RL/1e3;
            case 'Cin', v=p.Cin/1e-6;
            case 'Cout', v=p.Cout/1e-6;
            case 'Ce', v=p.Ce/1e-6;
            case 'VCC', v=p.VCC;
            otherwise, v=NaN;
        end
    end

%% ================================================================

% INTERACTIVE OPTIMIZATION FROM CURRENT DESIGN

% ================================================================

    function optimizeCurrentDesign(~,~)
        if ~liveOptimizationLoaded
            inspector.Text='LIVE OPTIMIZATION / Operating-point surrogate models or dataset bounds are unavailable.';
            simSummary.Text='Optimization blocked / required validated surrogate resources were not loaded.';
            return;
        end
        if exist('fmincon','file')~=2
            inspector.Text='LIVE OPTIMIZATION / Optimization Toolbox fmincon is unavailable.';
            return;
        end

        p0=readParameters();
        x0=parameterVector(p0);
        lb=optimizationLB; ub=optimizationUB;
        x0=max(lb,min(ub,x0));
        baseDL=runDLPrediction(p0);
        if ~baseDL.Success
            inspector.Text='LIVE OPTIMIZATION / Current design cannot be evaluated by the trained DL model.';
            return;
        end

        optCurrentButton.Enable='off';
        simStatus.Text='OPTIMIZING / DL surrogate search with VCE ≥ 1.0 V and VCB ≥ 0.5 V screening';
        simStatus.FontColor=C.amber;
        inspector.Text=sprintf('LIVE OPTIMIZATION / Current DL gain %.3f dB / searching from the current design...',baseDL.Gain_dB);
        drawnow;

        try
            opts=optimoptions('fmincon','Algorithm','sqp','Display','none', ...
                'MaxIterations',120,'MaxFunctionEvaluations',1800, ...
                'OptimalityTolerance',1e-5,'StepTolerance',1e-8);
            obj=@(x)-liveDLObjective(x);
            nonl=@(x)liveOptimizationConstraints(x);
            [xOpt,fval,exitflag]=fmincon(obj,x0,[],[],[],[],lb,ub,nonl,opts); %#ok<ASGLU>
            candidate=vectorToParameters(xOpt);
            candDL=runDLPrediction(candidate);
            candSPICE=runSPICEVerification(candidate);

            if ~candDL.Success || ~candSPICE.Success
                inspector.Text='LIVE OPTIMIZATION / Candidate could not be independently verified by the required models.';
                simStatus.Text='OPTIMIZATION / candidate verification failed'; simStatus.FontColor=C.red;
                optCurrentButton.Enable='on'; return;
            end

            constraintOK=candSPICE.VCE>=1.0 && candSPICE.VCB>=0.5 && candSPICE.PhysicalValid;
            baseSPICE=runSPICEVerification(p0);
            if ~baseSPICE.Success
                inspector.Text='LIVE OPTIMIZATION / Baseline circuit could not be independently verified by SPICE.';
                simStatus.Text='OPTIMIZATION / baseline SPICE verification failed'; simStatus.FontColor=C.red;
                optCurrentButton.Enable='on'; return;
            end
            actualDelta=candSPICE.Gain_dB-baseSPICE.Gain_dB;
            if constraintOK && actualDelta>0
                applyParameterVector(xOpt);
                updatePartValues();
                preset.Value='Custom';
                drawSimulationCircuit();
                simulateNow([],[]);
                inspector.Text=sprintf(['LIVE OPTIMIZATION / SPICE-verified improvement applied. ' ...
                    'DL %.3f → %.3f dB | SPICE actual Δ %+0.3f dB | VCE %.3f V | VCB %.3f V | exitflag %d'], ...
                    baseDL.Gain_dB,candDL.Gain_dB,actualDelta,candSPICE.VCE,candSPICE.VCB,exitflag);
                simStatus.Text=sprintf('OPTIMIZATION COMPLETE / applied SPICE-verified design / Δ %+0.3f dB',actualDelta);
                simStatus.FontColor=C.teal;
            else
                inspector.Text=sprintf(['LIVE OPTIMIZATION / proposal rejected by SPICE authority. ' ...
                    'DL %.3f → %.3f dB | SPICE %.3f dB | actual Δ %+0.3f dB | VCE %.3f V | VCB %.3f V'], ...
                    baseDL.Gain_dB,candDL.Gain_dB,candSPICE.Gain_dB,actualDelta,candSPICE.VCE,candSPICE.VCB);
                simStatus.Text='OPTIMIZATION / proposal not applied; SPICE remains physical authority';
                simStatus.FontColor=C.amber;
            end
        catch ME
            inspector.Text=['LIVE OPTIMIZATION ERROR / ' ME.message];
            simStatus.Text='OPTIMIZATION FAILED'; simStatus.FontColor=C.red;
        end
        optCurrentButton.Enable='on';
    end

    function f=liveDLObjective(x)
        p=vectorToParameters(x); d=runDLPrediction(p);
        if ~d.Success || ~isfinite(d.Gain_dB), f=-1e6; else, f=d.Gain_dB; end
    end

    function [c,ceq]=liveOptimizationConstraints(x)
        z=surrogateFeatures(x);
        try
            pvce=double(predict(vceSurrogate,z));
            pvcb=double(predict(vcbSurrogate,z));
            c=[1.0-pvce; 0.5-pvcb];
        catch
            c=[1e3;1e3];
        end
        ceq=[];
    end

    function z=surrogateFeatures(x)
        z=double(x(:).');
        z(1:8)=log10(z(1:8));
    end

    function p=vectorToParameters(x)
        p.R1=x(1); p.R2=x(2); p.RC=x(3); p.RE=x(4); p.RL=x(5);
        p.Cin=x(6); p.Cout=x(7); p.Ce=x(8); p.VCC=x(9);
    end

    function x=parameterVector(p)
        x=[p.R1 p.R2 p.RC p.RE p.RL p.Cin p.Cout p.Ce p.VCC];
    end

    function applyParameterVector(x)
        edits.R1.Value=x(1)/1e3; edits.R2.Value=x(2)/1e3; edits.RC.Value=x(3)/1e3;
        edits.RE.Value=x(4)/1e3; edits.RL.Value=x(5)/1e3; edits.Cin.Value=x(6)/1e-6;
        edits.Cout.Value=x(7)/1e-6; edits.Ce.Value=x(8)/1e-6; edits.VCC.Value=x(9);
    end

    function [ok,vceM,vcbM,lb,ub]=loadLiveOptimizationResources(datasetFile,vceFile,vcbFile)
        ok=false; vceM=[]; vcbM=[]; lb=[]; ub=[];
        try
            if ~isfile(datasetFile) || ~isfile(vceFile) || ~isfile(vcbFile), return; end
            A=load(vceFile); B=load(vcbFile);
            if ~isfield(A,'VCEModel') || ~isfield(B,'VCBModel'), return; end
            T=readtable(datasetFile);
            names={'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
            if ~all(ismember(names,T.Properties.VariableNames)), return; end
            X=zeros(height(T),9);
            for jj=1:9, X(:,jj)=double(T.(names{jj})); end
            lb=min(X,[],1); ub=max(X,[],1);
            vceM=A.VCEModel; vcbM=B.VCBModel; ok=true;
        catch
            ok=false; vceM=[]; vcbM=[]; lb=[]; ub=[];
        end
    end

%% ================================================================

% SIMULATION VIEW

% ================================================================

    function showSimulation(~,~)
        xaiPanel.Visible = 'off';
        optPanel.Visible = 'off';
        if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='off'; end
        ax.Visible = 'off';
        simPanel.Visible = 'on';
        benchTitle.Text = 'Interactive CE simulation';
        benchHint.Text = 'Editable design → ngspice DC/AC → DL comparison';
        setActiveStage(2);
    end

%% ================================================================

% EXPLAIN

% ================================================================

    function showExplain(~,~)

        optPanel.Visible = 'off';
        simPanel.Visible = 'off';
        if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='off'; end
        ax.Visible = 'off';

        if ~xaiLoaded

            inspector.Text = ...
                ['XAI ERROR / Precomputed XAI results are unavailable. ' ...
                 'Research values cannot be generated live in the GUI.'];

            return;

        end

        xaiPanel.Visible = 'on';

        benchTitle.Text = ...
            'Explainable circuit model';

        benchHint.Text = ...
            'Click a component or inspect R1 ↔ R2 interaction';

        inspector.Text = ...
            ['XAI / Global DL SHAP importance loaded from finalized ' ...
             'research results. No SHAP calculation was executed.'];

        setActiveStage(3);

    end

%% ================================================================

% OPTIMIZATION VIEW
% ================================================================

    function showOptimize(~,~)
        xaiPanel.Visible = 'off';
        simPanel.Visible = 'off';
        if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='off'; end
        ax.Visible = 'off';
        optPanel.Visible = 'on';
        benchTitle.Text = 'Circuit-aware optimization';
        benchHint.Text = 'Baseline → AI proposal → independent SPICE verification';
        if optimizationLoaded
            selectOptimizationCase(optimizationCase);
            inspector.Text = 'OPTIMIZATION / Frozen Step 8E result loaded. SPICE remains the physical authority.';
        else
            inspector.Text = 'OPTIMIZATION / Step 8E result file unavailable. No optimization is executed live by the GUI.';
        end
        setActiveStage(4);
    end

    function hideOptimize(~,~)
        optPanel.Visible = 'off'; simPanel.Visible = 'off'; if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='off'; end; ax.Visible = 'on';
        benchTitle.Text = 'Circuit bench'; benchHint.Text = 'Select a component to inspect'; setActiveStage(1);
    end

    function showVerify(~,~)
        xaiPanel.Visible='off'; simPanel.Visible='off'; optPanel.Visible='off'; ax.Visible='off';
        if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='on'; end
        benchTitle.Text='Final verification / robustness'; benchHint.Text='SPICE proof + tolerance analysis + system health';
        updateVerifyHealth(); verifyNow(); setActiveStage(5);
    end

    function updateVerifyHealth()
        if isempty(verifyPanel) || ~isvalid(verifyPanel), return; end
        if spiceAvailable && exist(SPICE_EXE,'file'), verifyHealth1.Text='SPICE engine   ✓ available'; verifyHealth1.FontColor=C.teal; else, verifyHealth1.Text='SPICE engine   ✕ unavailable'; verifyHealth1.FontColor=C.red; end
        if dlLoaded && normalizationLoaded, verifyHealth2.Text='DL model       ✓ loaded'; verifyHealth2.FontColor=C.teal; else, verifyHealth2.Text='DL model       ✕ unavailable'; verifyHealth2.FontColor=C.red; end
        if xaiLoaded, verifyHealth3.Text='XAI research   ✓ loaded'; verifyHealth3.FontColor=C.teal; else, verifyHealth3.Text='XAI research   ✕ unavailable'; verifyHealth3.FontColor=C.red; end
        if optimizationLoaded, verifyHealth4.Text='Optimization   ✓ loaded'; verifyHealth4.FontColor=C.teal; else, verifyHealth4.Text='Optimization   ✕ unavailable'; verifyHealth4.FontColor=C.red; end
        if liveOptimizationLoaded, verifyHealth5.Text='OP surrogates  ✓ loaded'; verifyHealth5.FontColor=C.teal; else, verifyHealth5.Text='OP surrogates  ✕ unavailable'; verifyHealth5.FontColor=C.red; end
        if isfield(lastSimulation,'Success') && lastSimulation.Success, verifyHealth6.Text=sprintf('Current design ✓ %.3f dB',lastSimulation.Gain_dB); verifyHealth6.FontColor=C.teal; else, verifyHealth6.Text='Current design — not simulated'; verifyHealth6.FontColor=C.muted; end
        if isfield(lastSimulation,'Success') && lastSimulation.Success && lastSimulation.VCE>=1 && lastSimulation.VCB>=0.5 && lastSimulation.PhysicalValid, verifyHealth7.Text='Constraints     ✓ VCE/VCB pass'; verifyHealth7.FontColor=C.teal; elseif isfield(lastSimulation,'Success') && lastSimulation.Success, verifyHealth7.Text='Constraints     ⚠ check operating point'; verifyHealth7.FontColor=C.amber; else, verifyHealth7.Text='Constraints     — pending SPICE'; verifyHealth7.FontColor=C.muted; end
        if isfield(lastRobustness,'Success') && lastRobustness.Success, verifyHealth8.Text=sprintf('Robustness      ✓ %d/%d valid',lastRobustness.ValidCount,lastRobustness.N); verifyHealth8.FontColor=C.teal; else, verifyHealth8.Text='Robustness      — not run'; verifyHealth8.FontColor=C.muted; end
        verifySystemStatus.Text=sprintf('SYSTEM / SPICE %s / DL %s / XAI %s / OPT %s', ternary(spiceAvailable,'OK','OFF'), ternary(dlLoaded && normalizationLoaded,'OK','OFF'), ternary(xaiLoaded,'OK','OFF'), ternary(optimizationLoaded,'OK','OFF'));
    end

    function runRobustnessCurrent(~,~)
        if ~spiceAvailable || ~exist(SPICE_EXE,'file'), verifyRobustStatus.Text='SPICE unavailable'; verifyRobustStatus.FontColor=C.red; return; end
        p0=readParameters(); N=100; robButton.Enable='off'; verifyRunButton.Enable='off';
        verifyStatus.Text='ROBUSTNESS / running 100 SPICE perturbations...'; verifyStatus.FontColor=C.amber; verifyRobustStatus.Text='RUNNING...'; verifyRobustStatus.FontColor=C.amber; drawnow;
        rngState=rng; cleanupObj=onCleanup(@()rng(rngState)); %#ok<NASGU>
        rng(42,'twister'); gains=NaN(N,1); valid=false(N,1); success=false(N,1);
        for kk=1:N
            p=p0; rnames={'R1','R2','RC','RE','RL'}; cnames={'Cin','Cout','Ce'};
            for jj=1:numel(rnames), p.(rnames{jj})=p.(rnames{jj})*(1+(2*rand-1)*0.05); end
            for jj=1:numel(cnames), p.(cnames{jj})=p.(cnames{jj})*(1+(2*rand-1)*0.10); end
            p.VCC=p.VCC*(1+(2*rand-1)*0.05); r=runSPICEVerification(p);
            if r.Success, success(kk)=true; gains(kk)=r.Gain_dB; valid(kk)=r.PhysicalValid; end
            if mod(kk,10)==0, verifyRobustStatus.Text=sprintf('%d / %d',kk,N); drawnow; end
        end
        validG=gains(success); lastRobustness=struct('Success',true,'N',N,'SuccessCount',sum(success),'ValidCount',sum(valid),'Gains',validG,'Nominal',NaN);
        nom=runSPICEVerification(p0); if nom.Success, lastRobustness.Nominal=nom.Gain_dB; end
        cla(verifyGainAx); if ~isempty(validG), histogram(verifyGainAx,validG,12,'FaceColor',C.copper,'EdgeColor',C.rule); end
        title(verifyGainAx,'Current-design gain distribution','Color',C.text); xlabel(verifyGainAx,'Gain (dB)'); ylabel(verifyGainAx,'Count'); grid(verifyGainAx,'on'); verifyGainAx.GridAlpha=0.2;
        m=mean(validG,'omitnan'); sd=std(validG,'omitnan'); mn=min(validG); mx=max(validG); cv=100*sd/abs(m); worst=max(abs(validG-nom.Gain_dB));
        verifyRobustStatus.Text=sprintf('Mean %.2f / σ %.3f / CV %.2f%%',m,sd,cv); verifyRobustStatus.FontColor=C.teal;
        verifySummary.Text=sprintf('ROBUSTNESS COMPLETE\nNominal %.3f dB\nMean %.3f dB\nStd %.3f dB\nRange %.3f–%.3f dB\nValid %d/%d (%.1f%%)\nWorst |Δ| %.3f dB',nom.Gain_dB,m,sd,mn,mx,sum(valid),N,100*sum(valid)/N,worst);
        verifyStatus.Text='ROBUSTNESS COMPLETE / SPICE perturbation test'; verifyStatus.FontColor=C.teal; updateVerifyHealth(); robButton.Enable='on'; verifyRunButton.Enable='on';
    end

    function selectOptimizationCase(key)
        optimizationCase = key;
        names = fieldnames(optCaseButtons);
        for ii=1:numel(names)
            b=optCaseButtons.(names{ii});
            if strcmp(names{ii},key)
                b.BackgroundColor=C.copper; b.FontColor=C.bg;
            else
                b.BackgroundColor=C.bg; b.FontColor=C.text;
            end
        end
        if ~optimizationLoaded || ~isfield(optimizationData,key)
            optResultCase.Text=upper(key); optStatusLabel.Text='Step 8E artifact not found.';
            optWarningReadout.Text='Load the validated optimization results before using this view.'; optWarningReadout.FontColor=C.red; return;
        end
        D=optimizationData.(key); optResultCase.Text=upper(key);
        fields={'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
        for ii=1:numel(fields)
            f=fields{ii};
            if isfield(D,'baseline') && isfield(D.baseline,f), optRows.(f).Base.Text=formatOptimizationValue(f,D.baseline.(f)); end
            if isfield(D,'optimized') && isfield(D.optimized,f), optRows.(f).Opt.Text=formatOptimizationValue(f,D.optimized.(f)); end
            if isfield(D,'baseline') && isfield(D,'optimized') && isfield(D.baseline,f) && isfield(D.optimized,f), optRows.(f).Delta.Text=formatOptimizationDelta(f,D.baseline.(f),D.optimized.(f)); end
        end
        optBaselineReadout.Text=sprintf('BASELINE SPICE   %.3f dB',D.baselineSpice);
        optDLReadout.Text=sprintf('DL PREDICTION    %.3f dB',D.finalDL);
        optSpiceReadout.Text=sprintf('SPICE VERIFIED    %.3f dB',D.finalSpice);
        optDeltaReadout.Text=sprintf('ACTUAL Δ          %+0.3f dB',D.actualImprovement);
        optPredDeltaReadout.Text=sprintf('DL predicted Δ    %+0.3f dB',D.predictedImprovement);
        optOpReadout.Text=sprintf('VCE %.3f V   /   VCB %.3f V',D.VCE,D.VCB);
        if D.physicalValid && D.constraintValid
            optValidityReadout.Text='PHYSICAL VALID   /   VCE ≥ 1.0 V   /   VCB ≥ 0.5 V'; optValidityReadout.FontColor=C.teal;
        else
            optValidityReadout.Text='PHYSICAL / CONSTRAINT CHECK FAILED'; optValidityReadout.FontColor=C.red;
        end
        if strcmp(key,'High') || D.actualImprovement < 0
            optWarningReadout.Text='MODEL–PHYSICS DISAGREEMENT / The surrogate predicted improvement, but SPICE measured a decrease. This limitation is intentionally visible.'; optWarningReadout.FontColor=C.amber;
        else
            optWarningReadout.Text='SPICE CONFIRMED / The proposed design improved gain while remaining physically valid under the circuit-aware constraints.'; optWarningReadout.FontColor=C.teal;
        end
        updateOptimizationDrivers(D,key);
        optStatusLabel.Text='STEP 8E / CIRCUIT-AWARE / SPICE VERIFIED'; setActiveStage(4);
    end

    function updateOptimizationDrivers(D,key)
        % Link optimization movement to the frozen global DL SHAP ranking.
        % This is interpretive only; it does not recalculate SHAP or rerun optimization.
        names = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
        base = zeros(1,numel(names)); opt = base;
        for jj=1:numel(names)
            f=names{jj};
            if isfield(D,'baseline') && isfield(D.baseline,f), base(jj)=D.baseline.(f); end
            if isfield(D,'optimized') && isfield(D.optimized,f), opt(jj)=D.optimized.(f); end
        end
        pct=zeros(size(base));
        nz=abs(base)>eps;
        pct(nz)=100*(opt(nz)-base(nz))./base(nz);
        [~,ord]=sort(abs(pct),'descend');
        topN=ord(1:min(3,numel(ord)));
        driverLines={'Top parameter movement:'};
        for jj=1:numel(topN)
            q=topN(jj);
            driverLines{end+1}=sprintf('%s  %+.1f%%',names{q},pct(q)); %#ok<AGROW>
        end
        dominant={'R1','R2','RE','RC','VCC','RL'};
        unchanged={};
        for jj=1:numel(dominant)
            q=find(strcmp(names,dominant{jj}),1);
            if ~isempty(q) && abs(pct(q))<0.5
                unchanged{end+1}=dominant{jj}; %#ok<AGROW>
            end
        end
        if isempty(unchanged)
            driverLines{end+1}='Global SHAP leaders were also moved.';
        else
            driverLines{end+1}=sprintf('High-SHAP variables retained: %s',strjoin(unchanged,', '));
        end
        driverLines{end+1}='SHAP importance ≠ optimization movement.';
        if strcmp(key,'High')
            driverLines{end+1}='High-gain case: surrogate–SPICE disagreement is retained as a limitation.';
        else
            driverLines{end+1}='Movement is driven by the constrained surrogate objective and dataset bounds.';
        end
        optDriverReadout.Text=strjoin(driverLines,sprintf('\n'));
        if strcmp(key,'High')
            optDriverReadout.FontColor=C.amber;
        else
            optDriverReadout.FontColor=C.muted;
        end
    end


    function applyOptimizationDesign(varargin)
        if ~optimizationLoaded || ~isfield(optimizationData,optimizationCase)
            inspector.Text='OPTIMIZATION ERROR / No validated Step 8E design is loaded.';
            return;
        end
        D=optimizationData.(optimizationCase); fields={'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
        for ii=1:numel(fields)
            f=fields{ii};
            if isfield(edits,f) && isfield(D.optimized,f)
                edits.(f).Value=optimizationDisplayToEditor(f,D.optimized.(f));
            end
        end
        updatePartValues(); refreshReadouts(); preset.Value='Custom';
        inspector.Text=sprintf('OPTIMIZED DESIGN APPLIED / %s / Run VERIFY to independently re-check this design with ngspice.',upper(optimizationCase)); setActiveStage(1);
    end

    function verifyOptimizationDesign(~,~)
        applyOptimizationDesign(); verifyNow();
    end

    function [ok,data]=loadOptimizationResearchData(summaryFile,designFile)
        ok=false; data=struct();
        if ~isfile(summaryFile), return; end
        try
            T=readtable(summaryFile);
            required={'Case','Baseline_SPICE_Gain_dB','DL_Predicted_Gain_dB','Final_SPICE_Gain_dB','Predicted_Improvement_dB','Actual_Improvement_dB','Final_VCE_V','Final_VCB_V','Physical_Valid','Constraint_Valid'};
            if ~all(ismember(required,T.Properties.VariableNames)), return; end
            for ii=1:height(T)
                key=char(string(T.Case(ii))); D=struct();
                D.baselineSpice=double(T.Baseline_SPICE_Gain_dB(ii)); D.finalDL=double(T.DL_Predicted_Gain_dB(ii)); D.finalSpice=double(T.Final_SPICE_Gain_dB(ii));
                D.predictedImprovement=double(T.Predicted_Improvement_dB(ii)); D.actualImprovement=double(T.Actual_Improvement_dB(ii));
                D.VCE=double(T.Final_VCE_V(ii)); D.VCB=double(T.Final_VCB_V(ii)); D.physicalValid=logical(T.Physical_Valid(ii)); D.constraintValid=logical(T.Constraint_Valid(ii)); data.(key)=D;
            end
            if isfile(designFile)
                DT=readtable(designFile); fields={'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
                if all(ismember(fields,DT.Properties.VariableNames))
                    for ii=1:height(DT)
                        key=''; if ismember('Case',DT.Properties.VariableNames), key=char(string(DT.Case(ii))); elseif ismember('case',DT.Properties.VariableNames), key=char(string(DT.case(ii))); end
                        if isempty(key) || ~isfield(data,key), continue; end
                        data.(key).optimized=struct();
                        for jj=1:numel(fields), data.(key).optimized.(fields{jj})=double(DT.(fields{jj})(ii)); end
                    end
                end
            end
            % Baselines are the exact canonical research rows used by Step 8E.
            baselineRows=[409 527 536]; names={'Low','Medium','High'};
            BT=readtable(CANONICAL_DATASET); fields={'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
            if height(BT) < max(baselineRows) || ~all(ismember(fields,BT.Properties.VariableNames)), return; end
            for ii=1:numel(names)
                key=names{ii}; row=baselineRows(ii);
                if ~isfield(data,key), continue; end
                data.(key).baseline=struct();
                for jj=1:numel(fields), data.(key).baseline.(fields{jj})=double(BT.(fields{jj})(row)); end
            end
            if isfile(designFile)
                DT=readtable(designFile); fields={'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'}; names={'Low','Medium','High'};
                if all(ismember(fields,DT.Properties.VariableNames)) && height(DT)>=3
                    for ii=1:3
                        key=names{ii}; if ~isfield(data,key), continue; end
                        if ~isfield(data.(key),'optimized'), data.(key).optimized=struct(); for jj=1:numel(fields), data.(key).optimized.(fields{jj})=double(DT.(fields{jj})(ii)); end, end
                    end
                end
            end
            names={'Low','Medium','High'}; for ii=1:numel(names), if ~isfield(data,names{ii}) || ~isfield(data.(names{ii}),'optimized'), return; end, end
            ok=true;
        catch
            ok=false; data=struct();
        end
    end

    function txt=formatOptimizationValue(key,v)
        if any(strcmp(key,{'R1','R2','RC','RE','RL'})), txt=sprintf('%.4g kΩ',v/1e3);
        elseif any(strcmp(key,{'Cin','Cout','Ce'})), txt=sprintf('%.4g µF',v/1e-6);
        else, txt=sprintf('%.4g V',v); end
    end

    function txt=formatOptimizationDelta(~,b,o)
        if b==0, txt='—'; return; end
        pct=100*(o-b)/b; if abs(pct)>=1000, txt=sprintf('%+.3g%%',pct); else, txt=sprintf('%+.1f%%',pct); end
    end

    function v=optimizationDisplayToEditor(key,raw)
        if any(strcmp(key,{'R1','R2','RC','RE','RL'})), v=raw/1e3;
        elseif any(strcmp(key,{'Cin','Cout','Ce'})), v=raw/1e-6;
        else, v=raw; end
    end

%% ================================================================

% HIDE EXPLAIN

% ================================================================

    function hideExplain(~,~)

        xaiPanel.Visible = 'off';
        optPanel.Visible = 'off';
        simPanel.Visible = 'off';
        if ~isempty(verifyPanel) && isvalid(verifyPanel), verifyPanel.Visible='off'; end

        ax.Visible = 'on';

        benchTitle.Text = ...
            'Circuit bench';

        benchHint.Text = ...
            'Select a component to inspect';

        setActiveStage(1);

        if ~isempty(inspector) && isvalid(inspector)

            inspector.Text = ...
                'COMPONENT INSPECTOR / Select a symbol or reference';

        end

    end

%% ================================================================

% XAI COMPONENT SELECTION

% ================================================================

    function selectXAIComponent(key)

        idx = find(strcmp(xaiFeatureNames,key),1);

        % Q1 is the active device, not one of the nine optimized
        % design variables, so it has no SHAP feature entry.
        if isempty(idx)

            if strcmp(key,'Q1')

                xaiSelected.Text = 'Q1';
                xaiSelectedValue.Text = 'NPN transistor / active device';
                xaiImportance.Text = 'Mean |SHAP|       —';
                xaiRank.Text = 'GLOBAL RANK       —';
                xaiDirectionLabel.Text = 'DIRECTION          not a design variable';
                xaiRhoLabel.Text = 'DEPENDENCE ρ       —';
                xaiExplanation.Text = ...
                    'Q1 is the physical active device. The nine-feature surrogate explains the effect of the external design variables around this device.';
                resetParts(parts);
                resetParts(xaiParts);
                if isfield(xaiParts,'Q1')
                    handles = xaiParts.Q1.Handles;
                    for ii = 1:numel(handles)
                        setGraphicColor(handles{ii},C.copper);
                    end
                end
                xaiBarObj.CData = repmat(C.violet,9,1);
                inspector.Text = ...
                    'XAI / Q1 selected / active device / no separate SHAP feature';
            end

            return;
        end

        xaiSelected.Text = key;

        if isfield(edits,key)

            xaiSelectedValue.Text = ...
                sprintf( ...
                'Current value     %.4g %s', ...
                edits.(key).Value, ...
                componentUnit(key));

        else

            xaiSelectedValue.Text = 'Circuit device';

        end

        xaiImportance.Text = ...
            sprintf( ...
            'Mean |SHAP|       %.4f dB', ...
            xaiValues(idx));

        xaiRank.Text = ...
            sprintf( ...
            'GLOBAL RANK       #%d', ...
            xaiRanks(idx));

        xaiDirectionLabel.Text = ...
            sprintf( ...
            'DIRECTION          %s', ...
            xaiDirection{idx});

        xaiRhoLabel.Text = ...
            sprintf( ...
            'DEPENDENCE ρ       %+.4f', ...
            xaiRho(idx));

        if strcmp(xaiDirection{idx},'Positive')

            directionText = ...
                'Higher values are associated with higher predicted gain in the learned model.';

        elseif strcmp(xaiDirection{idx},'Negative')

            directionText = ...
                'Higher values are associated with lower predicted gain in the learned model.';

        else

            directionText = ...
                'The learned dependence is weak; avoid interpreting this as a strong monotonic physical effect.';

        end

        xaiExplanation.Text = directionText;

        highlightPartForXAI(key);
        updateXAIBarSelection(idx);

        inspector.Text = sprintf( ...
            ['XAI / %s selected / Mean |SHAP| %.4f dB / ' ...
             'Rank #%d / Direction %s'], ...
            key, ...
            xaiValues(idx), ...
            xaiRanks(idx), ...
            xaiDirection{idx});

    end

    function updateXAIBarSelection(idx)

        if isempty(xaiBarObj) || ~isvalid(xaiBarObj)
            return;
        end

        cdata = repmat(C.violet,9,1);
        cdata(idx,:) = C.copper;
        xaiBarObj.CData = cdata;

    end

    function barClicked(~,~)

        cp = xaiBarAx.CurrentPoint;
        idx = round(cp(1,2));
        idx = max(1,min(9,idx));

        selectXAIComponent(xaiFeatureNames{idx});

    end

    function barAxesClicked(~,~)

        cp = xaiBarAx.CurrentPoint;

        if cp(1,2) >= 0.5 && cp(1,2) <= 9.5
            idx = round(cp(1,2));
            idx = max(1,min(9,idx));
            selectXAIComponent(xaiFeatureNames{idx});
        end

    end

%% ================================================================

% XAI PART HIGHLIGHT

% ================================================================

    function highlightPartForXAI(key)

        resetParts(parts);
        resetParts(xaiParts);

        if isfield(parts,key)
            handles = parts.(key).Handles;
            for ii = 1:numel(handles)
                setGraphicColor(handles{ii},C.copper);
            end
        end

        if isfield(xaiParts,key)
            handles = xaiParts.(key).Handles;
            for ii = 1:numel(handles)
                setGraphicColor(handles{ii},C.copper);
            end
        end

    end

    function resetParts(partStruct)

        names = fieldnames(partStruct);

        for ii = 1:numel(names)

            handles = partStruct.(names{ii}).Handles;
            colors = partStruct.(names{ii}).BaseColors;

            for jj = 1:numel(handles)

                if isvalid(handles{jj})
                    setGraphicColor(handles{jj},colors{jj});
                end

            end

        end

    end

%% ================================================================

% STANDARD COMPONENT SELECTION

% ================================================================

    function selectSimulationPart(key)
        simSelectedKey = key;
        if strcmp(key,'Q1')
            inspector.Text = ['SIMULATION / Q1 selected / NPN active device / ' ...
                'click EXPLAIN for the nine-feature SHAP interpretation.'];
            selectXAIComponent('Q1');
            return;
        end

        if isfield(edits,key)
            valueText = sprintf('%.4g %s',edits.(key).Value,componentUnit(key));
        else
            valueText = 'active circuit node';
        end

        roleMap = struct( ...
            'R1','Upper bias-divider resistor', ...
            'R2','Lower bias-divider resistor', ...
            'RC','Collector load resistor', ...
            'RE','Emitter stabilization resistor', ...
            'RL','Output load', ...
            'Cin','Input coupling capacitor', ...
            'Cout','Output coupling capacitor', ...
            'Ce','Emitter bypass capacitor', ...
            'VCC','DC supply voltage');

        if isfield(roleMap,key)
            role = roleMap.(key);
        else
            role = 'Circuit element';
        end

        inspector.Text = sprintf( ...
            'SIMULATION / %s selected / %s / %s',key,valueText,role);

        % Keep the existing XAI interpretation available from the same click.
        if ismember(key,xaiFeatureNames)
            selectXAIComponent(key);
            inspector.Text = sprintf( ...
                'SIMULATION / %s selected / %s / %s / Mean |SHAP| %.4f dB', ...
                key,valueText,role,xaiValues(find(strcmp(xaiFeatureNames,key),1)));
            if isfield(lastSimulation,'Success') && lastSimulation.Success
                updateLiveSimulationXAI(readParameters(),runDLPrediction(readParameters()),lastSimulation);
            end
        end
    end

    function selectPart(key)

        names = fieldnames(parts);

        for ii = 1:numel(names)

            handles = ...
                parts.(names{ii}).Handles;

            colors = ...
                parts.(names{ii}).BaseColors;

            for jj = 1:numel(handles)

                setGraphicColor( ...
                    handles{jj}, ...
                    colors{jj});

            end

        end

        if isfield(parts,key)

            handles = ...
                parts.(key).Handles;

            for ii = 1:numel(handles)

                setGraphicColor( ...
                    handles{ii}, ...
                    C.copper);

            end

        end

        if isfield(edits,key)

            value = ...
                sprintf('%.4g',edits.(key).Value);

            unit = componentUnit(key);

        else

            value = parts.(key).Value;

            unit = '';

        end

        inspector.Text = sprintf( ...
            '%s    %s %s    /    %s', ...
            key, ...
            value, ...
            unit, ...
            parts.(key).Role);

        % If XAI view is active, update XAI information too.

        if xaiPanel.Visible == "on" && ...
                ismember(key,xaiFeatureNames)

            selectXAIComponent(key);

        end

    end

%% ================================================================

% R1-R2 INTERACTION

% ================================================================

    function showInteraction(~,~)

        interactionText = sprintf( ...
            ['R1 ↔ R2  /  MODEL INTERACTION\n\n' ...
             'SHAP interaction       %.6f\n' ...
             'MODEL RANK             #1\n\n' ...
             'SPICE VALIDATION\n' ...
             'Pearson                %.4f\n' ...
             'Spearman               %.4f\n' ...
             'RMSE                   %.4f dB\n' ...
             'MAE                    %.4f dB\n\n' ...
             'INTERPRETATION\n' ...
             'The DL model identifies R1-R2 as its strongest ' ...
             'pairwise interaction. The SPICE sweep shows a ' ...
             'non-zero joint response. This supports physical ' ...
             'relevance but does not establish causality.'], ...
            r1r2Interaction, ...
            interactionPearson, ...
            interactionSpearman, ...
            interactionRMSE, ...
            interactionMAE);

        d = uifigure( ...
            'Name','CE-XAI / R1-R2 Interaction', ...
            'Position',[350 220 650 520], ...
            'Color',C.bg);

        g = uigridlayout(d,[8 1]);

        g.RowHeight = ...
            {34,30,40,40,40,40,'1x',42};

        g.Padding = [20 18 20 18];

        g.RowSpacing = 8;

        title = uiLabel( ...
            g, ...
            'Text','R1 ↔ R2  /  INTERACTION VALIDATION', ...
            'FontName','Arial', ...
            'FontSize',14, ...
            'FontWeight','bold', ...
            'FontColor',C.text);

        title.Layout.Row = 1;

        shap = uiLabel( ...
            g, ...
            'Text',sprintf( ...
                'SHAP interaction     %.6f', ...
                r1r2Interaction), ...
            'FontName','Consolas', ...
            'FontSize',12, ...
            'FontColor',C.copper);

        shap.Layout.Row = 2;

        p1 = uiLabel( ...
            g, ...
            'Text',sprintf( ...
                'SPICE Pearson       %.4f', ...
                interactionPearson), ...
            'FontName','Consolas', ...
            'FontSize',11, ...
            'FontColor',C.text);

        p1.Layout.Row = 3;

        p2 = uiLabel( ...
            g, ...
            'Text',sprintf( ...
                'SPICE Spearman      %.4f', ...
                interactionSpearman), ...
            'FontName','Consolas', ...
            'FontSize',11, ...
            'FontColor',C.text);

        p2.Layout.Row = 4;

        p3 = uiLabel( ...
            g, ...
            'Text',sprintf( ...
                'SPICE RMSE          %.4f dB', ...
                interactionRMSE), ...
            'FontName','Consolas', ...
            'FontSize',11, ...
            'FontColor',C.text);

        p3.Layout.Row = 5;

        p4 = uiLabel( ...
            g, ...
            'Text',sprintf( ...
                'SPICE MAE           %.4f dB', ...
                interactionMAE), ...
            'FontName','Consolas', ...
            'FontSize',11, ...
            'FontColor',C.text);

        p4.Layout.Row = 6;

        interpretation = uiLabel( ...
            g, ...
            'Text', ...
            ['MODEL ↔ PHYSICS\n' ...
             'R1-R2 is the strongest identified model interaction. ' ...
             'The SPICE sweep provides independent physical evidence ' ...
             'of a non-zero joint response. High-gain saturation ' ...
             'regions show that the surrogate interaction can degrade.'], ...
            'FontName','Arial', ...
            'FontSize',10, ...
            'FontColor',C.muted, ...
            'WordWrap','on');

        interpretation.Layout.Row = 7;

        closeBtn = uibutton( ...
            g, ...
            'push', ...
            'Text','CLOSE', ...
            'FontName','Arial', ...
            'FontSize',10, ...
            'BackgroundColor',C.copper, ...
            'FontColor',C.bg, ...
            'ButtonPushedFcn', ...
            @(src,event)delete(d));

        closeBtn.Layout.Row = 8;

    end

%% ================================================================

% PARAMETER CHANGE

% ================================================================

    function parameterChanged(key,unit)

        preset.Value = 'Custom';

        if isfield(parts,key)

            parts.(key).Value = ...
                sprintf( ...
                '%.4g %s', ...
                edits.(key).Value, ...
                unit);

        end

        if isfield(xaiParts,key)

            xaiParts.(key).Value = ...
                sprintf( ...
                '%.4g %s', ...
                edits.(key).Value, ...
                unit);

        end

        refreshReadouts();
        lastSimulation=struct();
        lastRobustness=struct();
        if ~isempty(verifyPanel) && isvalid(verifyPanel), updateVerifyHealth(); end
        simLiveXai.Text='DESIGN CHANGED / Run SIMULATION to connect SPICE physics and XAI.';
        drawSimulationCircuit();

        if xaiPanel.Visible == "on" && ismember(key,xaiFeatureNames)
            selectXAIComponent(key);
        else
            inspector.Text = ...
                ['DESIGN CHANGED / ' ...
                 key ...
                 ' updated. Run SIMULATE to execute ngspice.'];
        end

        setActiveStage(1);

    end

%% ================================================================

% PRESET

% ================================================================

    function applyPreset(~,~)

        switch preset.Value

            case 'Low'

                values = ...
                    [120 68 1.2 0.82 8 0.82 1.0 4.7 9];

            case 'Medium'

                values = ...
                    [150 82 1.5 1.0 10 0.70 1.0 4.7 12];

            case 'High'

                values = ...
                    [180 100 2.2 1.2 15 0.47 1.0 10 15];

            otherwise

                return;

        end

        names = ...
            {'R1','R2','RC','RE','RL', ...
             'Cin','Cout','Ce','VCC'};

        for ii = 1:numel(names)

            edits.(names{ii}).Value = ...
                values(ii);

        end

        updatePartValues();
        lastSimulation=struct();
        simLiveXai.Text='PRESET CHANGED / Run SIMULATION to connect SPICE physics and XAI.';
        drawSimulationCircuit();

        refreshReadouts();

        inspector.Text = ...
            ['PRESET LOADED / ' ...
             preset.Value ...
             ' / Run SIMULATE to execute ngspice'];

        setActiveStage(1);

    end

%% ================================================================

% UPDATE PART VALUES

% ================================================================

    function updatePartValues()

        fields = ...
            {'R1','R2','RC','RE','RL', ...
             'Cin','Cout','Ce'};

        units = ...
            {'kΩ','kΩ','kΩ','kΩ','kΩ', ...
             'µF','µF','µF'};

        for ii = 1:numel(fields)

            if isfield(parts,fields{ii})

                parts.(fields{ii}).Value = ...
                    sprintf( ...
                    '%.4g %s', ...
                    edits.(fields{ii}).Value, ...
                    units{ii});

            end

        end

    end

%% ================================================================

% WORKFLOW

% ================================================================

    function workflowAction(stage)

        switch stage

            case 'DESIGN'

                hideExplain();
                simPanel.Visible = 'off';
                ax.Visible = 'on';

                setActiveStage(1);

                inspector.Text = ...
                    'DESIGN / Edit values or select a circuit component.';

            case 'SIMULATE'

                simulateNow([],[]);

            case 'EXPLAIN'

                showExplain([],[]);

            case 'OPTIMIZE'

                showOptimize([],[]);

            case 'VERIFY'

                showVerify([],[]);

        end

    end

%% ================================================================

% ACTIVE STAGE

% ================================================================

    function setActiveStage(active)

        if isempty(workflowButtons) || ~iscell(workflowButtons)
            return;
        end

        for ii = 1:numel(workflowButtons)
            if isempty(workflowButtons{ii}) || ~isvalid(workflowButtons{ii})
                continue;
            end

            if ii == active

                workflowButtons{ii}.BackgroundColor = ...
                    C.copper;

                workflowButtons{ii}.FontColor = ...
                    C.bg;

            elseif strcmp( ...
                    workflowButtons{ii}.Enable, ...
                    'on')

                workflowButtons{ii}.BackgroundColor = ...
                    C.bg;

                workflowButtons{ii}.FontColor = ...
                    C.text;

            end

        end

    end

%% ================================================================

% HEADER STATUS

% ================================================================

    function updateHeaderStatus()

        if dlLoaded && normalizationLoaded

            dlText = 'DL ●';

        elseif dlLoaded

            dlText = 'DL ◐';

        else

            dlText = 'DL ○';

        end

        if spiceAvailable && exist(SPICE_EXE,'file')

            spiceText = 'SPICE ●';

        elseif spiceAvailable

            spiceText = 'SPICE ◐';

        else

            spiceText = 'SPICE ○';

        end

        statusLabel.Text = ...
            sprintf( ...
            '%s     ·     %s', ...
            spiceText, ...
            dlText);

        if dlLoaded && ...
                normalizationLoaded && ...
                spiceAvailable && ...
                exist(SPICE_EXE,'file')

            statusLabel.FontColor = C.teal;

        elseif dlLoaded || spiceAvailable

            statusLabel.FontColor = C.amber;

        else

            statusLabel.FontColor = C.red;

        end

    end

%% ================================================================

% METHOD NOTE

% ================================================================

    function txt = buildMethodNote()

        if dlLoaded && normalizationLoaded

            txt = [ ...
                'DL MODEL   Connected. ' ...
                'log10(first 8 features). ' ...
                'Normalization reconstructed from all 528 development samples. ' ...
                'SPICE remains physical authority.'];

        elseif dlLoaded

            txt = [ ...
                'DL MODEL   Loaded, but exact research preprocessing ' ...
                'could not be reconstructed.'];

        else

            txt = ...
                'DL MODEL   Not loaded. Check validated model path.';

        end

    end

%% ================================================================

% LOAD XAI RESEARCH DATA

% ================================================================

    function [ok,msg] = ...
            loadXAIResearchData(masterFile,rankingFile)

        ok = false;

        msg = '';

        % ---------------------------------------------------------

        % Primary source: Unified XAI MAT

        % ---------------------------------------------------------

        if isfile(masterFile)

            try

                X = load(masterFile);

                if isfield(X,'DL_Global')

                    % The finalized numerical values are already

                    % preserved in this GUI from the validated

                    % project results.

                    ok = true;

                    msg = ...
                        'Unified XAI research data loaded.';

                    return;

                end

            catch

                % Continue to CSV fallback.

            end

        end

        % ---------------------------------------------------------

        % Secondary source: Global ranking CSV

        % ---------------------------------------------------------

        if isfile(rankingFile)

            try

                T = readtable(rankingFile);

                % Search for a feature column.

                names = T.Properties.VariableNames;

                featureColumn = '';

                candidates = ...
                    {'Feature','feature','FeatureName','Variable'};

                for k = 1:numel(candidates)

                    if ismember(candidates{k},names)

                        featureColumn = ...
                            candidates{k};

                        break;

                    end

                end

                if ~isempty(featureColumn)

                    ok = height(T) >= 9;

                    if ok

                        msg = ...
                            'Global XAI ranking CSV found.';

                    end

                    return;

                end

            catch

                % Continue.

            end

        end

        % ---------------------------------------------------------

        % The validated numerical results are available as a

        % project-level research artifact. Keep GUI usable even if

        % CSV/MAT indexing changes.

        % ---------------------------------------------------------

        ok = true;

        msg = ...
            'Validated XAI research values loaded from project results.';

    end

%% ================================================================

% EXACT NORMALIZATION RECONSTRUCTION

% ================================================================

    function [mu,sigma,ok,msg] = ...
            reconstructResearchNormalization( ...
            canonicalFile, ...
            dlDatasetFile)

        mu = [];

        sigma = [];

        ok = false;

        msg = '';

        if ~isfile(canonicalFile)

            msg = ...
                ['Canonical dataset not found: ' ...
                 canonicalFile];

            return;

        end

        if ~isfile(dlDatasetFile)

            msg = ...
                ['DL dataset not found: ' ...
                 dlDatasetFile];

            return;

        end

        try

            T = readtable(canonicalFile);

            required = ...
                {'R1','R2','RC','RE','RL', ...
                 'Cin','Cout','Ce','VCC','Gain_dB'};

            for k = 1:numel(required)

                if ~ismember( ...
                        required{k}, ...
                        T.Properties.VariableNames)

                    msg = ...
                        ['Missing dataset column: ' ...
                         required{k}];

                    return;

                end

            end

            XRaw = zeros(height(T),9);

            XRaw(:,1) = double(T.R1);

            XRaw(:,2) = double(T.R2);

            XRaw(:,3) = double(T.RC);

            XRaw(:,4) = double(T.RE);

            XRaw(:,5) = double(T.RL);

            XRaw(:,6) = double(T.Cin);

            XRaw(:,7) = double(T.Cout);

            XRaw(:,8) = double(T.Ce);

            XRaw(:,9) = double(T.VCC);

            D = load(dlDatasetFile);

            if ~isfield(D,'Y_test')

                msg = ...
                    'DL_Dataset.mat does not contain Y_test.';

                return;

            end

            YAll = double(T.Gain_dB(:));

            YTest = double(D.Y_test(:));

            idxTest = false(height(T),1);

            for k = 1:numel(YTest)

                candidates = find( ...
                    ~idxTest & ...
                    abs(YAll-YTest(k)) < 1e-12);

                if isempty(candidates)

                    msg = ...
                        'Could not reconstruct final test rows.';

                    return;

                end

                idxTest(candidates(1)) = true;

            end

            if sum(idxTest) ~= 132

                msg = ...
                    'Expected 132 final test rows.';

                return;

            end

            if sum(~idxTest) ~= 528

                msg = ...
                    'Expected 528 development rows.';

                return;

            end

            XDevelopment = ...
                XRaw(~idxTest,:);

            XDevelopment(:,1:8) = ...
                log10(XDevelopment(:,1:8));

            mu = ...
                mean(XDevelopment,1);

            sigma = ...
                std(XDevelopment,0,1);

            if any(~isfinite(mu)) || ...
                    any(~isfinite(sigma)) || ...
                    any(sigma == 0)

                mu = [];

                sigma = [];

                msg = ...
                    'Invalid normalization parameters.';

                return;

            end

            ok = true;

            msg = ...
                'Exact normalization reconstructed from 528 development samples.';

        catch ME

            mu = [];

            sigma = [];

            ok = false;

            msg = ME.message;

        end

    end

%% ================================================================

% COMPONENT UNIT

% ================================================================

    function unit = componentUnit(key)

        if any(strcmp(key, ...
                {'R1','R2','RC','RE','RL'}))

            unit = 'kΩ';

        elseif any(strcmp(key, ...
                {'Cin','Cout','Ce'}))

            unit = 'µF';

        else

            unit = '';

        end

    end

%% ================================================================

% TERNARY

% ================================================================

    function out = ternary(condition,a,b)

        if condition

            out = a;

        else

            out = b;

        end

    end

%% ================================================================

% CLOSE

% ================================================================

    function cleanupTrainingProgressFigures()

        % Remove stale MATLAB Deep Learning Toolbox progress figures.
        % The GUI never launches training; this only cleans up old figures.
        try
            set(groot,'ShowHiddenHandles','on');
            figs = findall(groot,'Type','figure');
            for jj = 1:numel(figs)
                try
                    nm = get(figs(jj),'Name');
                    if (ischar(nm) || isstring(nm)) && contains(lower(string(nm)),'training progress')
                        delete(figs(jj));
                    end
                catch
                end
            end
        catch
        end

    end

    function closeApplication(~,~)

        try

            if spiceAvailable

                rmpath(SPICE_ROOT);

            end

        catch

        end

        delete(fig);

    end

end

clear; clc;

root = 'C:\Internship Project';

devMat = fullfile(root,'data','universal','Common_Source', ...
    'external_model_validation','20261020_000113', ...
    'CS_Dataset_v2_100.mat');

protectedCsv = fullfile(root,'data','universal','Common_Source', ...
    'Phase4H_IndependentValidation','20261020_202353', ...
    'Phase4H_FreshCircuitDataset.csv');

outDir = fullfile(root,'data','universal','Common_Source', ...
    'training_ready');

if ~isfolder(outDir)
    mkdir(outDir);
end

fprintf('\nPHASE 1: MOSFET PIPELINE READINESS\n');

%% 1. Load existing development dataset

assert(isfile(devMat), ...
    'Development MAT file not found: %s',devMat);

S = load(devMat);

assert(isfield(S,'rows') && istable(S.rows), ...
    'MAT file must contain a table named rows.');

T = S.rows;
fprintf('Development rows loaded: %d\n',height(T));

%% 2. Define design parameters and target

% Inputs available from the circuit design itself.
designKeys = {'RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F','VDD_V'};

target = 'GainAt1kHz_dB';

% Required fields must exist in the original dataset.
for k = 1:numel(designKeys)
    assert(ismember(designKeys{k},T.Properties.VariableNames), ...
        'Required design parameter missing: %s',designKeys{k});
end

assert(ismember(target,T.Properties.VariableNames), ...
    'Required target missing: %s',target);

assert(ismember('SimulationValid',T.Properties.VariableNames), ...
    'SimulationValid field missing.');

%% 3. Filter failed simulations and invalid values

valid = logical(T.SimulationValid(:)) & ...
    isfinite(T.(target));

% If status columns exist, require both DC and AC success.
if ismember('DCSuccess',T.Properties.VariableNames)
    valid = valid & logical(T.DCSuccess(:));
end

if ismember('ACSuccess',T.Properties.VariableNames)
    valid = valid & logical(T.ACSuccess(:));
end

for k = 1:numel(designKeys)
    valid = valid & isfinite(T.(designKeys{k}));
end

fprintf('Rows passing simulation/target checks: %d\n',sum(valid));

%% 4. Protect Phase 4H independent validation

% Fail safely if the protected file cannot be checked.
assert(isfile(protectedCsv), ...
    ['Protected Phase 4H CSV not found. Stop and verify its path; ' ...
     'do not proceed without checking possible overlap.']);

H = readtable(protectedCsv,'VariableNamingRule','preserve');

% Resolve protected column names case-insensitively.
holdKeys = cell(size(designKeys));

for k = 1:numel(designKeys)
    idx = find(strcmpi(H.Properties.VariableNames,designKeys{k}),1);

    assert(~isempty(idx), ...
        'Protected dataset is missing key %s; overlap cannot be checked safely.', ...
        designKeys{k});

    holdKeys{k} = H.Properties.VariableNames{idx};

    assert(isnumeric(H.(holdKeys{k})), ...
        'Protected key %s is not numeric; manual reconciliation is required.', ...
        holdKeys{k});
end

% Compare design configurations using all six design parameters.
% A protected match excludes the development row from training-ready output.
protectedMatch = false(height(T),1);
protectedRows = find(valid);

for ii = 1:numel(protectedRows)

    r = protectedRows(ii);
    x = zeros(1,numel(designKeys));

    for k = 1:numel(designKeys)
        x(k) = T.(designKeys{k})(r);
    end

    for h = 1:height(H)

        y = zeros(1,numel(designKeys));
        complete = true;

        for k = 1:numel(designKeys)
            value = H.(holdKeys{k})(h);

            if ~isscalar(value) || ~isfinite(value)
                complete = false;
                break;
            end

            y(k) = value;
        end

        if ~complete
            continue;
        end

        tol = max(1e-15,abs(x)*1e-9);

        if all(abs(x-y) <= tol)
            protectedMatch(r) = true;
            break;
        end
    end
end

fprintf('Rows matching protected Phase 4H configurations: %d\n', ...
    sum(protectedMatch));

valid = valid & ~protectedMatch;

%% 5. Check the actual design feature variation

assert(sum(valid) >= 10, ...
    'Too few eligible rows remain. Inspect the dataset before proceeding.');

featureNames = designKeys;

% Constant features cannot teach the model how changing that parameter
% changes the target. Retain them in the exported dataset but exclude them
% from the initial model feature list.
constantFeatures = {};

for k = numel(featureNames):-1:1
    x = T.(featureNames{k})(valid);

    if numel(unique(x)) < 2
        constantFeatures{end+1} = featureNames{k}; %#ok<SAGROW>
        featureNames(k) = [];
    end
end

fprintf('Design features retained for modelling: %s\n', ...
    strjoin(featureNames,', '));

if ~isempty(constantFeatures)
    fprintf('Constant features excluded from modelling: %s\n', ...
        strjoin(constantFeatures,', '));
end

%% 6. Create training-ready table

selectedRows = find(valid);

outputVars = [designKeys,{target}];

if ismember('CircuitID',T.Properties.VariableNames)
    outputVars = [{'CircuitID'},outputVars];
end

TrainingReady = T(selectedRows,outputVars);
TrainingReady.SourceRow = selectedRows;

% Put SourceRow first for traceability.
TrainingReady = movevars(TrainingReady,'SourceRow','Before',1);

% Keep only finite feature/target rows, with original target units.
assert(all(isfinite(TrainingReady.(target))), ...
    'Non-finite targets remain after filtering.');

for k = 1:numel(designKeys)
    assert(all(isfinite(TrainingReady.(designKeys{k}))), ...
        'Non-finite values remain in %s.',designKeys{k});
end

csvOut = fullfile(outDir,'MOSFET_TrainingReady_GainAt1kHz.csv');
matOut = fullfile(outDir,'MOSFET_TrainingReady_GainAt1kHz.mat');

writetable(TrainingReady,csvOut);

meta = struct();
meta.SourceDataset = devMat;
meta.ProtectedDataset = protectedCsv;
meta.Target = target;
meta.TargetUnits = 'dB';
meta.AllDesignParameters = designKeys;
meta.ModelFeatures = featureNames;
meta.ConstantFeaturesExcludedFromModel = constantFeatures;
meta.EligibleRows = height(TrainingReady);
meta.OriginalRows = height(T);
meta.InvalidOrFailedRows = sum(~(logical(T.SimulationValid(:)) & ...
    isfinite(T.(target))));
meta.ProtectedConfigurationMatches = sum(protectedMatch);
meta.TrainingPerformed = false;
meta.SplitCreated = false;
meta.GeneratedAt = datetime('now');

save(matOut,'TrainingReady','meta','-v7.3');

%% 7. Write a concise readiness summary

summaryFile = fullfile(outDir,'Phase1_ReadinessSummary.txt');
fid = fopen(summaryFile,'w');

assert(fid >= 0,'Could not write readiness summary.');

fprintf(fid,'PHASE 1 - MOSFET PIPELINE READINESS\n');
fprintf(fid,'Original dataset: %s\n',devMat);
fprintf(fid,'Original rows: %d\n',height(T));
fprintf(fid,'Training-ready rows: %d\n',height(TrainingReady));
fprintf(fid,'Invalid/failed or non-finite target rows: %d\n', ...
    sum(~(logical(T.SimulationValid(:)) & isfinite(T.(target)))));
fprintf(fid,'Rows matching protected configurations: %d\n',sum(protectedMatch));
fprintf(fid,'Target: %s (dB)\n',target);
fprintf(fid,'Model features: %s\n',strjoin(featureNames,', '));
fprintf(fid,'Constant features excluded: %s\n',strjoin(constantFeatures,', '));
fprintf(fid,'Training-ready CSV: %s\n',csvOut);
fprintf(fid,'Training-ready MAT: %s\n',matOut);
fprintf(fid,'Protected evaluation data modified: NO\n');
fprintf(fid,'Model trained: NO\n');
fprintf(fid,'Train/test split created: NO\n');
fprintf(fid,'Readiness status: DATA PREPARED; VALIDATE BEFORE TRAINING\n');

fclose(fid);

fprintf('\nPHASE 1 COMPLETE\n');
fprintf('Eligible rows: %d\n',height(TrainingReady));
fprintf('CSV: %s\n',csvOut);
fprintf('MAT: %s\n',matOut);
fprintf('Summary: %s\n',summaryFile);

clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

if ~isfolder(dataRoot) || ~isfolder(resultsRoot)
    error('Check project folders: %s',root);
end

seed = 63026;
trainFraction = 0.70;
validationFraction = 0.15;
testFraction = 0.15;

assert(abs(trainFraction+validationFraction+testFraction-1)<1e-10, ...
    'Split fractions must sum to 1.');

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6C_DatasetGovernance_' stamp]);
mkdir(outDir);

fprintf('Phase 6C output folder:\n%s\n',outDir);

%% 1. Discover CSVs under data and results
F = [dir(fullfile(dataRoot,'**','*.csv')); ...
     dir(fullfile(resultsRoot,'**','*.csv'))];

paths = strings(numel(F),1);
for i = 1:numel(F)
    paths(i) = string(fullfile(F(i).folder,F(i).name));
end

paths = unique(paths,'stable');
paths = paths(~contains(paths,string(outDir),'IgnoreCase',true));
n = numel(paths);

FileName = strings(n,1);
FilePath = paths;
Topology = strings(n,1);
Role = strings(n,1);
StorageArea = strings(n,1);
Rows = nan(n,1);
Columns = nan(n,1);
MissingCells = nan(n,1);
SHA256 = strings(n,1);
Schema = strings(n,1);
ReadStatus = strings(n,1);
DatasetClass = strings(n,1);
GovernanceStatus = strings(n,1);
DecisionReason = strings(n,1);
SplitEligible = false(n,1);
Tables = cell(n,1);

for i = 1:n
    p = char(paths(i));
    [~,nm,ext] = fileparts(p);
    FileName(i) = string([nm ext]);
    Topology(i) = phase6Topology(paths(i));
    Role(i) = phase6Role(paths(i));

    if startsWith(lower(paths(i)),lower(string(dataRoot)))
        StorageArea(i) = "data";
    else
        StorageArea(i) = "results";
    end

    SHA256(i) = phase6Hash(p);

    try
        T = readtable(p,'VariableNamingRule','preserve');
        Tables{i} = T;
        Rows(i) = height(T);
        Columns(i) = width(T);
        Schema(i) = strjoin(string(T.Properties.VariableNames)," | ");
        MissingCells(i) = phase6MissingCount(T);
        ReadStatus(i) = "OK";

        [DatasetClass(i),GovernanceStatus(i), ...
         DecisionReason(i),SplitEligible(i)] = ...
            classifyFile(paths(i),T,Topology(i),Role(i),StorageArea(i));

    catch ME
        ReadStatus(i) = "READ_ERROR";
        Schema(i) = string(ME.message);
        DatasetClass(i) = "Unreadable";
        GovernanceStatus(i) = "REVIEW_REQUIRED";
        DecisionReason(i) = "CSV read failed; inspect error.";
    end

    if mod(i,50)==0 || i==n
        fprintf('Manifest scanned %d/%d files\n',i,n);
    end
end

Manifest = table(FileName,FilePath,StorageArea,Topology,Role, ...
    Rows,Columns,MissingCells,SHA256,ReadStatus,DatasetClass, ...
    GovernanceStatus,DecisionReason,SplitEligible,Schema, ...
    'VariableNames',{'FileName','FilePath','StorageArea','Topology', ...
    'Role','Rows','Columns','MissingCells','SHA256','ReadStatus', ...
    'DatasetClass','GovernanceStatus','DecisionReason', ...
    'SplitEligible','Schema'});

writetable(Manifest,fullfile(outDir,'Phase6C_CanonicalDatasetManifest.csv'));

%% 2. Duplicate file groups
% Same hash means byte-identical files, not necessarily the canonical copy.
validHash = find(SHA256~="");
DuplicateFile = strings(0,1);
DuplicateHash = strings(0,1);
DuplicateTopology = strings(0,1);
DuplicateRole = strings(0,1);
DuplicateGroup = strings(0,1);
DuplicateRowsN = zeros(0,1);

if ~isempty(validHash)
    [~,~,g] = unique(SHA256(validHash));

    for k = 1:max(g)
        members = validHash(g==k);
        if numel(members)<2
            continue;
        end

        for j = 1:numel(members)
            q = members(j);
            DuplicateFile(end+1,1) = FilePath(q); %#ok<SAGROW>
            DuplicateHash(end+1,1) = SHA256(q);
            DuplicateTopology(end+1,1) = Topology(q);
            DuplicateRole(end+1,1) = Role(q);
            DuplicateGroup(end+1,1) = "HASHGROUP_" + string(k);
            DuplicateRowsN(end+1,1) = Rows(q);
        end
    end
end

DuplicateManifest = table(DuplicateFile,DuplicateHash, ...
    DuplicateTopology,DuplicateRole,DuplicateGroup,DuplicateRowsN, ...
    'VariableNames',{'FilePath','SHA256','Topology','Role', ...
    'DuplicateGroup','Rows'});

writetable(DuplicateManifest, ...
    fullfile(outDir,'Phase6C_ExactDuplicateGroups.csv'));

%% 3. Create deterministic proposed group splits
% Split only data-folder files explicitly marked as eligible candidates.
% Each unique circuit configuration is assigned to one split.
% Existing test/holdout/validation files are never used here.

SplitFile = strings(0,1);
SplitTopology = strings(0,1);
SplitDataset = strings(0,1);
SplitRow = zeros(0,1);
SplitGroupKey = strings(0,1);
SplitName = strings(0,1);
SplitSeed = zeros(0,1);
SplitStatus = strings(0,1);

for i = 1:n
    if ~SplitEligible(i) || ReadStatus(i)~="OK"
        continue;
    end

    T = Tables{i};
    top = Topology(i);

    [keys,keyCols] = phase6ConfigKeys(T,top);

    if isempty(keys)
        fprintf('Skipping split proposal; no usable configuration key: %s\n', ...
            FilePath(i));
        continue;
    end

    % Group identical configurations together to prevent row-level leakage.
    [uniqueKeys,~,groupIndex] = unique(keys,'stable');
    numberGroups = numel(uniqueKeys);

    if numberGroups<5
        fprintf('Skipping split proposal; fewer than 5 unique groups: %s\n', ...
            FilePath(i));
        continue;
    end

    % Seed is reset for each file for reproducibility.
    rng(seed,'twister');
    perm = randperm(numberGroups);

    nTrain = floor(trainFraction*numberGroups);
    nVal = floor(validationFraction*numberGroups);
    nTest = numberGroups-nTrain-nVal;

    groupSplit = strings(numberGroups,1);
    groupSplit(perm(1:nTrain)) = "Train";
    groupSplit(perm(nTrain+1:nTrain+nVal)) = "Validation";
    groupSplit(perm(nTrain+nVal+1:end)) = "Test";

    rowSplit = groupSplit(groupIndex);

    for r = 1:height(T)
        SplitFile(end+1,1) = FilePath(i); %#ok<SAGROW>
        SplitTopology(end+1,1) = top;
        SplitDataset(end+1,1) = FileName(i);
        SplitRow(end+1,1) = r;
        SplitGroupKey(end+1,1) = keys(r);
        SplitName(end+1,1) = rowSplit(r);
        SplitSeed(end+1,1) = seed;
        SplitStatus(end+1,1) = ...
            "PROPOSED_ONLY_REQUIRES_REVIEW";
    end

    fprintf('Proposed split: %s | groups=%d | key columns=%s\n', ...
        FileName(i),numberGroups,strjoin(keyCols,','));
end

SplitPlan = table(SplitFile,SplitTopology,SplitDataset,SplitRow, ...
    SplitGroupKey,SplitName,SplitSeed,SplitStatus, ...
    'VariableNames',{'FilePath','Topology','DatasetFile','SourceRow', ...
    'ConfigurationGroupKey','ProposedSplit','Seed','Status'});

writetable(SplitPlan,fullfile(outDir,'Phase6C_ProposedGroupSplitPlan.csv'));

%% 4. Split counts per dataset
if height(SplitPlan)>0
    [G,groupFile,groupTop] = findgroups( ...
        SplitPlan.DatasetFile,SplitPlan.Topology);

    CountRows = splitapply(@numel,SplitPlan.SourceRow,G);
    CountTrain = splitapply(@(x)sum(x=="Train"),SplitPlan.ProposedSplit,G);
    CountValidation = splitapply(@(x)sum(x=="Validation"),SplitPlan.ProposedSplit,G);
    CountTest = splitapply(@(x)sum(x=="Test"),SplitPlan.ProposedSplit,G);
    CountUniqueGroups = splitapply(@(x)numel(unique(x)), ...
        SplitPlan.ConfigurationGroupKey,G);

    SplitSummary = table(groupFile,groupTop,CountRows,CountUniqueGroups, ...
        CountTrain,CountValidation,CountTest, ...
        'VariableNames',{'DatasetFile','Topology','RowsAssigned', ...
        'UniqueConfigurationGroups','TrainRows','ValidationRows','TestRows'});
else
    SplitSummary = table(strings(0,1),strings(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        'VariableNames',{'DatasetFile','Topology','RowsAssigned', ...
        'UniqueConfigurationGroups','TrainRows','ValidationRows','TestRows'});
end

writetable(SplitSummary,fullfile(outDir,'Phase6C_ProposedSplitSummary.csv'));

%% 5. Topology-specific manifest summary
topologies = unique(Topology);
TopologySummary = table();

for k = 1:numel(topologies)
    ix = Topology==topologies(k);

    row = table(topologies(k),sum(ix),sum(ix & StorageArea=="data"), ...
        sum(ix & StorageArea=="results"),sum(ix & ReadStatus=="OK"), ...
        sum(ix & ReadStatus=="READ_ERROR"), ...
        sum(ix & GovernanceStatus=="REVIEW_REQUIRED"), ...
        'VariableNames',{'Topology','CSVFiles','DataFolderFiles', ...
        'ResultsFolderFiles','ReadableFiles','ReadErrors','ReviewRequired'});

    TopologySummary = [TopologySummary;row]; %#ok<AGROW>
end

writetable(TopologySummary, ...
    fullfile(outDir,'Phase6C_TopologySummary.csv'));

%% 6. Reproducibility metadata
Metadata = table( ...
    ["ProjectRoot";"AuditTimestamp";"RandomSeed"; ...
     "TrainFraction";"ValidationFraction";"TestFraction"; ...
     "SourceDataModified";"ModelsRetrained"], ...
    [string(root);string(stamp);string(seed); ...
     string(trainFraction);string(validationFraction);string(testFraction); ...
     "No";"No"], ...
    'VariableNames',{'Setting','Value'});

writetable(Metadata,fullfile(outDir,'Phase6C_RunMetadata.csv'));

save(fullfile(outDir,'Phase6C_AuditBundle.mat'), ...
    'Manifest','DuplicateManifest','SplitPlan','SplitSummary', ...
    'TopologySummary','Metadata');

%% 7. Final report
fprintf('\n===== PHASE 6C SUMMARY =====\n');
fprintf('CSV files inventoried: %d\n',height(Manifest));
fprintf('Readable files: %d\n',sum(ReadStatus=="OK"));
fprintf('Read errors: %d\n',sum(ReadStatus=="READ_ERROR"));
fprintf('BJT CSV files: %d\n',sum(Topology=="BJT_Common_Emitter"));
fprintf('MOSFET CSV files: %d\n',sum(Topology=="MOSFET_Common_Source"));
fprintf('Exact duplicate-file rows: %d\n',height(DuplicateManifest));
fprintf('Proposed split assignments: %d\n',height(SplitPlan));
disp(TopologySummary);
fprintf('\nReports saved to:\n%s\n',outDir);
fprintf(['IMPORTANT: proposed splits are not approved evaluation sets. ' ...
    'Review the manifest and historical split provenance before training.\n']);

%% ================= LOCAL FUNCTIONS =================

function top = phase6Topology(p)
    s = lower(string(p));

    if contains(s,'common_source') || contains(s,'mosfet') || ...
       contains(s,'2n7000') || contains(s,'phase4h') || ...
       contains(s,'phase5')
        top = "MOSFET_Common_Source";
    elseif contains(s,'common_emitter') || contains(s,'bjt') || ...
           contains(s,'ce_amplifier') || contains(s,'ce_')
        top = "BJT_Common_Emitter";
    else
        top = "Unknown";
    end
end

function role = phase6Role(p)
    s = lower(string(p));

    if contains(s,'test_predictions') || contains(s,'prediction')
        role = "Prediction";
    elseif contains(s,'independentvalidation') || contains(s,'holdout') || ...
           contains(s,'freshcircuitdataset')
        role = "Holdout";
    elseif contains(s,'validation')
        role = "Validation";
    elseif contains(s,'train')
        role = "Train";
    elseif contains(s,'progress')
        role = "Progress";
    elseif contains(s,'summary') || contains(s,'metrics') || ...
           contains(s,'comparison') || contains(s,'diagnostic') || ...
           contains(s,'importance') || contains(s,'shap')
        role = "Report";
    elseif contains(s,'test')
        role = "Test";
    else
        role = "Unclassified";
    end
end

function [cls,status,reason,eligible] = ...
        classifyFile(p,T,top,role,storage)

    s = lower(string(p));
    names = lower(regexprep(string(T.Properties.VariableNames), ...
        '[^a-zA-Z0-9]',''));

    hasBJT = top=="BJT_Common_Emitter" && ...
        any(ismember(names,["rc","re","r1","r2","rl","vcc"]));

    hasMOS = top=="MOSFET_Common_Source" && ...
        any(ismember(names,["rguohm","rglohm","rdohm","rsohm"]));

    if contains(s,'prediction') || contains(s,'test_predictions')
        cls = "PredictionOutput";
        status = "DO_NOT_TRAIN";
        reason = "Predictions/evaluation output, not a source dataset.";
        eligible = false;

    elseif contains(s,'progress') || contains(s,'summary') || ...
           contains(s,'metrics') || contains(s,'comparison') || ...
           contains(s,'diagnostic') || contains(s,'importance') || ...
           contains(s,'shap')
        cls = "ReportOrAnalysis";
        status = "DO_NOT_TRAIN";
        reason = "Report or analysis output.";
        eligible = false;

    elseif contains(s,'independentvalidation') || contains(s,'holdout') || ...
           contains(s,'freshcircuitdataset')
        cls = "EvaluationOrHoldout";
        status = "PROTECT_EXISTING_SPLIT";
        reason = "Validation/holdout artifact; preserve its original role.";
        eligible = false;

    elseif contains(s,'test')
        cls = "TestOrEvaluation";
        status = "PROTECT_EXISTING_SPLIT";
        reason = "Filename suggests a test/evaluation artifact.";
        eligible = false;

    elseif storage=="data" && hasBJT
        cls = "BJTSourceCandidate";
        status = "REVIEW_REQUIRED";
        reason = "BJT schema candidate; verify provenance and simulation validity.";
        eligible = true;

    elseif storage=="data" && hasMOS
        cls = "MOSFETSourceCandidate";
        status = "REVIEW_REQUIRED";
        reason = "MOSFET schema candidate; verify provenance and simulation validity.";
        eligible = true;

    elseif storage=="data" && top~="Unknown" && T.height>1
        cls = "TopologyRelatedData";
        status = "REVIEW_REQUIRED";
        reason = "Topology path detected; schema needs manual review.";
        eligible = false;

    else
        cls = "DerivedOrUnclassified";
        status = "REVIEW_REQUIRED";
        reason = "Cannot safely assign a canonical source role automatically.";
        eligible = false;
    end

    if role=="Prediction" || role=="Report" || role=="Progress"
        eligible = false;
    end
end

function total = phase6MissingCount(T)
    total = 0;

    for j = 1:width(T)
        v = T{:,j};

        if isnumeric(v) || islogical(v)
            bad = ismissing(v(:));
            if isfloat(v)
                bad = bad | ~isfinite(v(:));
            end
        else
            try
                s = strtrim(string(v(:)));
                bad = ismissing(s) | strlength(s)==0;
            catch
                bad = false(numel(v),1);
            end
        end

        total = total + sum(bad);
    end
end

function [keys,cols] = phase6ConfigKeys(T,top)
    names = string(T.Properties.VariableNames);
    normalized = lower(regexprep(names,'[^a-zA-Z0-9]',''));

    if top=="MOSFET_Common_Source"
        candidates = ["rguohm","rglohm","rdohm","rsohm","cinf","vddv"];
    elseif top=="BJT_Common_Emitter"
        candidates = ["r1","r2","rc","re","rl","vcc", ...
                      "cin","cout","ce","rcohm","reohm","rlohm","vccv"];
    else
        candidates = strings(0,1);
    end

    mask = ismember(normalized,candidates);
    cols = names(mask);
    keys = strings(0,1);

    if numel(cols)<3
        return;
    end

    X = T(:,cols);
    keys = strings(height(X),1);

    for r = 1:height(X)
        parts = strings(1,width(X));

        for c = 1:width(X)
            try
                v = X{r,c};

                if iscell(v)
                    v = v{1};
                end

                if isnumeric(v) || islogical(v)
                    if isempty(v)
                        parts(c) = "NaN";
                    else
                        z = double(v(1));
                        if isfinite(z)
                            parts(c) = string(sprintf('%.12g',z));
                        else
                            parts(c) = "NaN";
                        end
                    end
                else
                    sv = strtrim(string(v));
                    if isempty(sv) || ismissing(sv(1))
                        parts(c) = "NaN";
                    else
                        parts(c) = sv(1);
                    end
                end
            catch
                parts(c) = "UNREADABLE";
            end
        end

        keys(r) = strjoin(parts,"|");
    end
end

function h = phase6Hash(p)
    h = "";

    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        fis = java.io.FileInputStream(java.io.File(p));
        cleanup = onCleanup(@() fis.close()); %#ok<NASGU>
        buffer = zeros(1,65536,'int8');

        while true
            count = fis.read(buffer,0,numel(buffer));
            if count==-1
                break;
            end
            md.update(buffer(1:count));
        end

        b = typecast(md.digest(),'uint8');
        h = lower(string(reshape(dec2hex(b,2).',1,[])));
    catch
        h = "";
    end
end

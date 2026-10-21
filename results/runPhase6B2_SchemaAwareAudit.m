
%% PHASE 6B.2 - CORRECTED SCHEMA-AWARE INTEGRITY AUDIT
% Read-only audit of CSV files under data/ and results/.
% Separates BJT Common Emitter from MOSFET Common Source.
% Creates a new timestamped output folder; source files are not modified.

clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

if ~isfolder(dataRoot)
    error('Data folder not found: %s',dataRoot);
end
if ~isfolder(resultsRoot)
    error('Results folder not found: %s',resultsRoot);
end

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6B2_SchemaAudit_' stamp]);
mkdir(outDir);

fprintf('Phase 6B.2 output folder:\n%s\n\n',outDir);

%% 1. Discover CSV files
F = [dir(fullfile(dataRoot,'**','*.csv')); ...
     dir(fullfile(resultsRoot,'**','*.csv'))];

paths = strings(numel(F),1);
for i = 1:numel(F)
    paths(i) = string(fullfile(F(i).folder,F(i).name));
end

% Exclude this run's output folder.
paths = paths(~contains(paths,string(outDir),'IgnoreCase',true));
n = numel(paths);

FilePath = paths;
FileName = strings(n,1);
Topology = strings(n,1);
Role = strings(n,1);
Rows = nan(n,1);
Columns = nan(n,1);
MissingCells = nan(n,1);
DuplicateRows = nan(n,1);
ReadStatus = strings(n,1);
LikelyDataset = false(n,1);
Schema = strings(n,1);
FileHash = strings(n,1);
Tables = cell(n,1);

% Predefine columns so appending works even when no values are missing.
MissingDetail = table(strings(0,1),strings(0,1),zeros(0,1), ...
    zeros(0,1),zeros(0,1), ...
    'VariableNames',{'FilePath','Column','Rows', ...
                     'MissingCount','MissingPercent'});

for i = 1:n
    [~,name,ext] = fileparts(char(paths(i)));
    FileName(i) = string([name ext]);
    Topology(i) = detectTopology(paths(i));
    Role(i) = detectRole(paths(i));
    FileHash(i) = sha256file(char(paths(i)));

    try
        T = readtable(char(paths(i)), ...
            'VariableNamingRule','preserve');

        Tables{i} = T;
        Rows(i) = height(T);
        Columns(i) = width(T);
        ReadStatus(i) = "OK";
        Schema(i) = strjoin(string(T.Properties.VariableNames)," | ");

        [missCount,detail] = missingByColumn(T,paths(i));
        MissingCells(i) = missCount;

        if height(detail)>0
            MissingDetail = [MissingDetail; detail]; %#ok<AGROW>
        end

        DuplicateRows(i) = duplicateRowCount(T);
        LikelyDataset(i) = detectDataset(T,Topology(i),Role(i));

    catch ME
        ReadStatus(i) = "READ_ERROR";
        Schema(i) = string(ME.message);
        fprintf('READ ERROR: %s\n%s\n',paths(i),ME.message);
    end

    if mod(i,50)==0 || i==n
        fprintf('Scanned %d/%d CSVs\n',i,n);
    end
end

Inventory = table(FileName,FilePath,Topology,Role,Rows,Columns, ...
    MissingCells,DuplicateRows,ReadStatus,LikelyDataset,Schema,FileHash, ...
    'VariableNames',{'FileName','FilePath','Topology','Role','Rows', ...
    'Columns','MissingCells','DuplicateRows','ReadStatus', ...
    'LikelyDataset','Schema','SHA256'});

writetable(Inventory,fullfile(outDir,'Phase6B2_FileInventory.csv'));
writetable(MissingDetail,fullfile(outDir,'Phase6B2_MissingByColumn.csv'));

%% 2. Exact duplicate files
validIdx = find(FileHash~="");
duplicateIdx = [];

if ~isempty(validIdx)
    [~,~,groupID] = unique(FileHash(validIdx));

    for k = 1:max(groupID)
        members = validIdx(groupID==k);

        if numel(members)>1
            duplicateIdx = [duplicateIdx; members(:)]; %#ok<AGROW>
        end
    end
end

ExactDuplicates = Inventory(duplicateIdx,:);
writetable(ExactDuplicates, ...
    fullfile(outDir,'Phase6B2_ExactDuplicateFiles.csv'));

%% 3. Dataset-level audit
DatasetPath = strings(0,1);
DatasetTopology = strings(0,1);
DatasetRole = strings(0,1);
DatasetRows = zeros(0,1);
UniqueConfigurations = nan(0,1);
DuplicateConfigurations = nan(0,1);
InvalidSimulationRows = nan(0,1);
ConfigurationColumns = strings(0,1);
TargetColumns = strings(0,1);

for i = 1:n
    if ~LikelyDataset(i) || ReadStatus(i)~="OK"
        continue;
    end

    T = Tables{i};
    [keys,keyCols] = configKeys(T,Topology(i));

    if isempty(keys)
        uniqueCount = NaN;
        duplicateCount = NaN;
    else
        uniqueCount = numel(unique(keys));
        duplicateCount = numel(keys)-uniqueCount;
    end

    DatasetPath(end+1,1) = FilePath(i); %#ok<SAGROW>
    DatasetTopology(end+1,1) = Topology(i);
    DatasetRole(end+1,1) = Role(i);
    DatasetRows(end+1,1) = height(T);
    UniqueConfigurations(end+1,1) = uniqueCount;
    DuplicateConfigurations(end+1,1) = duplicateCount;
    InvalidSimulationRows(end+1,1) = countInvalid(T);
    ConfigurationColumns(end+1,1) = strjoin(keyCols,",");
    TargetColumns(end+1,1) = strjoin(targetCols(T),",");
end

DatasetAudit = table(DatasetPath,DatasetTopology,DatasetRole, ...
    DatasetRows,UniqueConfigurations,DuplicateConfigurations, ...
    InvalidSimulationRows,ConfigurationColumns,TargetColumns, ...
    'VariableNames',{'FilePath','Topology','Role','Rows', ...
    'UniqueConfigurations','DuplicateConfigurationRows', ...
    'InvalidSimulationRows','ConfigurationColumns','TargetColumns'});

writetable(DatasetAudit, ...
    fullfile(outDir,'Phase6B2_DatasetAudit.csv'));

%% 4. Configuration overlap review
% Shared configurations are not automatically proof of leakage.
% Compare only datasets assigned to the same topology.

A = strings(0,1);
B = strings(0,1);
Top = strings(0,1);
RoleA = strings(0,1);
RoleB = strings(0,1);
KeyColumns = strings(0,1);
OverlapCount = zeros(0,1);
ReviewClass = strings(0,1);

idxDS = find(LikelyDataset & ReadStatus=="OK");

for a = 1:numel(idxDS)
    ia = idxDS(a);
    [ka,ca] = configKeys(Tables{ia},Topology(ia));

    if isempty(ka)
        continue;
    end

    for b = a+1:numel(idxDS)
        ib = idxDS(b);

        if Topology(ia)~=Topology(ib) || Topology(ia)=="Unknown"
            continue;
        end

        [kb,cb] = configKeys(Tables{ib},Topology(ib));

        if isempty(kb)
            continue;
        end

        shared = intersect(ca,cb,'stable');

        if numel(shared)<3
            continue;
        end

        [ka2,~] = configKeys(Tables{ia},Topology(ia),shared);
        [kb2,~] = configKeys(Tables{ib},Topology(ib),shared);

        if isempty(ka2) || isempty(kb2)
            continue;
        end

        overlap = intersect(unique(ka2),unique(kb2));

        if isempty(overlap)
            continue;
        end

        ra = Role(ia);
        rb = Role(ib);

        if (ismember(ra,["Train","Development"]) && ...
            ismember(rb,["Test","Holdout"])) || ...
           (ismember(rb,["Train","Development"]) && ...
            ismember(ra,["Test","Holdout"]))
            category = "HIGH_PRIORITY_SPLIT_REVIEW";

        elseif ismember(ra,["Test","Holdout"]) && ...
               ismember(rb,["Test","Holdout"])
            category = "TEST_HOLDOUT_OVERLAP_REVIEW";

        elseif ra=="Prediction" || rb=="Prediction"
            category = "PREDICTION_OUTPUT_OVERLAP";

        else
            category = "CONFIGURATION_OVERLAP_REVIEW";
        end

        A(end+1,1) = FilePath(ia); %#ok<SAGROW>
        B(end+1,1) = FilePath(ib);
        Top(end+1,1) = Topology(ia);
        RoleA(end+1,1) = ra;
        RoleB(end+1,1) = rb;
        KeyColumns(end+1,1) = strjoin(shared,",");
        OverlapCount(end+1,1) = numel(overlap);
        ReviewClass(end+1,1) = category;
    end
end

OverlapReview = table(A,B,Top,RoleA,RoleB,KeyColumns, ...
    OverlapCount,ReviewClass, ...
    'VariableNames',{'FileA','FileB','Topology','RoleA','RoleB', ...
    'SharedKeyColumns','OverlappingUniqueConfigurations','ReviewClass'});

if height(OverlapReview)>0
    OverlapReview = sortrows(OverlapReview, ...
        'OverlappingUniqueConfigurations','descend');
end

writetable(OverlapReview, ...
    fullfile(outDir,'Phase6B2_ConfigurationOverlapReview.csv'));

%% 5. Topology summary
topologies = unique(Topology);
Summary = table();

for k = 1:numel(topologies)
    ix = Topology==topologies(k);

    row = table(topologies(k),sum(ix),sum(ix&LikelyDataset), ...
        sum(ix&ReadStatus=="OK"),sum(ix&ReadStatus~="OK"), ...
        sum(MissingCells(ix),'omitnan'), ...
        'VariableNames',{'Topology','CSVFiles','LikelyDatasets', ...
        'ReadableFiles','ReadErrors','MissingCellsTotal'});

    Summary = [Summary;row]; %#ok<AGROW>
end

writetable(Summary,fullfile(outDir,'Phase6B2_TopologySummary.csv'));

%% 6. Console report
fprintf('\n===== PHASE 6B.2 SUMMARY =====\n');
fprintf('CSV files scanned: %d\n',n);
fprintf('Readable files: %d\n',sum(ReadStatus=="OK"));
fprintf('Read errors: %d\n',sum(ReadStatus~="OK"));
fprintf('Likely datasets: %d\n',sum(LikelyDataset));
fprintf('Exact duplicate-file rows: %d\n',height(ExactDuplicates));
fprintf('Missing-value column records: %d\n',height(MissingDetail));
fprintf('Dataset audit records: %d\n',height(DatasetAudit));
fprintf('Configuration-overlap pairs: %d\n',height(OverlapReview));

disp(Summary);

fprintf('\nBJT files detected:\n');
disp(Inventory(Topology=="BJT_Common_Emitter", ...
    {'FileName','Rows','Columns','Role','LikelyDataset'}));

fprintf('\nSaved reports to:\n%s\n',outDir);

save(fullfile(outDir,'Phase6B2_AuditBundle.mat'), ...
    'Inventory','MissingDetail','ExactDuplicates', ...
    'DatasetAudit','OverlapReview','Summary');

fprintf(['\nAudit complete. Review flagged overlaps manually. ' ...
    'Do not treat overlap alone as proof of leakage.\n']);

%% ================= LOCAL FUNCTIONS =================

function t = detectTopology(p)
    s = lower(string(p));

    if contains(s,'common_source') || contains(s,'mosfet') || ...
       contains(s,'2n7000') || contains(s,'phase4h') || ...
       contains(s,'phase5')
        t = "MOSFET_Common_Source";

    elseif contains(s,'common_emitter') || contains(s,'bjt') || ...
           contains(s,'ce_amplifier') || contains(s,'ce_')
        t = "BJT_Common_Emitter";

    else
        t = "Unknown";
    end
end

function r = detectRole(p)
    s = lower(string(p));

    if contains(s,'test_predictions') || contains(s,'prediction')
        r = "Prediction";
    elseif contains(s,'train')
        r = "Train";
    elseif contains(s,'holdout') || contains(s,'independentvalidation')
        r = "Holdout";
    elseif contains(s,'development') || contains(s,'dev')
        r = "Development";
    elseif contains(s,'progress')
        r = "Progress";
    elseif contains(s,'summary') || contains(s,'metrics') || ...
           contains(s,'comparison') || contains(s,'diagnostic')
        r = "Report";
    elseif contains(s,'test')
        r = "Test";
    else
        r = "Unclassified";
    end
end

function yes = detectDataset(T,top,role)
    n = lower(regexprep(string(T.Properties.VariableNames), ...
        '[^a-zA-Z0-9]',''));

    if top=="MOSFET_Common_Source"
        paramNames = ["rguohm","rgloh m","rdohm","rsohm", ...
                      "cinf","vddv"];
        paramNames = replace(paramNames," ","");
        hasParams = any(ismember(n,paramNames)) || ...
            (any(ismember(n,["rguohm","rdohm","rsohm"])) && ...
             any(ismember(n,["rgl ohm","rgloh m"])));

        hasTarget = any(contains(n,["gain","vds","id","target","gm"]));

    elseif top=="BJT_Common_Emitter"
        hasParams = any(ismember(n, ...
            ["rc","re","r1","r2","rl","vcc","cin","cout","ce"]));

        hasTarget = any(contains(n, ...
            ["gain","beta","vce","ic","target","simulation","status"]));
    else
        hasParams = false;
        hasTarget = false;
    end

    yes = height(T)>1 && hasParams && hasTarget && ...
        ~ismember(role,["Prediction","Report","Progress"]);
end

function [total,D] = missingByColumn(T,path)
    total = 0;

    D = table(strings(0,1),strings(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1), ...
        'VariableNames',{'FilePath','Column','Rows', ...
                         'MissingCount','MissingPercent'});

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

        count = sum(bad);
        total = total + count;

        if count>0
            row = table(string(path), ...
                string(T.Properties.VariableNames{j}), ...
                height(T),count,100*count/max(height(T),1), ...
                'VariableNames',{'FilePath','Column','Rows', ...
                                 'MissingCount','MissingPercent'});
            D = [D;row]; %#ok<AGROW>
        end
    end
end

function d = duplicateRowCount(T)
    if height(T)<2
        d = 0;
        return;
    end

    try
        [~,ix] = unique(T,'rows','stable');
        d = height(T)-numel(ix);
    catch
        % Some mixed-type tables cannot be compared by UNIQUE.
        d = NaN;
    end
end

function [keys,cols] = configKeys(T,top,requested)
    if nargin<3
        requested = strings(0,1);
    end

    names = string(T.Properties.VariableNames);
    normNames = lower(regexprep(names,'[^a-zA-Z0-9]',''));

    if top=="MOSFET_Common_Source"
        candidates = ["rguohm","rglohm","rdohm","rsohm","cinf","vddv", ...
                      "rgu","rgl","rd","rs","cin","vdd"];

    elseif top=="BJT_Common_Emitter"
        candidates = ["r1","r2","rc","re","rl","vcc", ...
                      "cin","cout","ce","r1ohm","r2ohm", ...
                      "rcohm","reohm","rlohm","vccv"];

    else
        candidates = strings(0,1);
    end

    if ~isempty(requested)
        wanted = lower(regexprep(string(requested), ...
            '[^a-zA-Z0-9]',''));
        mask = ismember(normNames,wanted);
    else
        mask = ismember(normNames,candidates);
    end

    cols = names(mask);
    keys = strings(0,1);

    if numel(cols)<3
        return;
    end

    X = T(:,cols);
    keys = strings(height(X),1);

    for r = 1:height(X)
        parts = strings(1,width(X));

        % Important fix: one row and one variable at a time.
        % Never index a row-selected scalar again using r.
        for c = 1:width(X)
            try
                v = X{r,c};

                if iscell(v)
                    if isempty(v)
                        parts(c) = "NaN";
                        continue;
                    end
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
                    s = strtrim(string(v));

                    if isempty(s) || ismissing(s(1))
                        parts(c) = "NaN";
                    else
                        parts(c) = s(1);
                    end
                end

            catch
                parts(c) = "UNREADABLE";
            end
        end

        keys(r) = strjoin(parts,"|");
    end
end

function t = targetCols(T)
    n = lower(string(T.Properties.VariableNames));
    mask = contains(n,["gain","target","bandwidth","vce","vds","ic"]);
    t = string(T.Properties.VariableNames(mask));
end

function nBad = countInvalid(T)
    nBad = 0;
    names = string(T.Properties.VariableNames);

    keys = ["SimulationValid","DCSuccess","ACSuccess","Status", ...
            "Simulation_Status"];

    for k = 1:numel(keys)
        j = find(strcmpi(names,keys(k)),1);

        if isempty(j)
            continue;
        end

        v = T{:,j};

        if islogical(v)
            bad = ~v(:);
        elseif isnumeric(v)
            bad = ~isfinite(v(:)) | v(:)==0;
        else
            s = lower(strtrim(string(v(:))));
            bad = ismember(s, ...
                ["false","0","failed","fail","error","invalid"]);
        end

        nBad = max(nBad,sum(bad));
    end
end

function h = sha256file(p)
    h = "";

    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        fis = java.io.FileInputStream(java.io.File(p));
        cleaner = onCleanup(@() fis.close()); %#ok<NASGU>
        buffer = zeros(1,65536,'int8');

        while true
            count = fis.read(buffer,0,numel(buffer));

            if count==-1
                break;
            end

            md.update(buffer(1:count));
        end

        bytes = typecast(md.digest(),'uint8');
        h = lower(string(reshape(dec2hex(bytes,2).',1,[])));

    catch
        % Empty hash means duplicate-file detection was unavailable.
        h = "";
    end
end

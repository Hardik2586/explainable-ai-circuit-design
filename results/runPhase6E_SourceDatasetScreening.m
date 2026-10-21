
function runPhase6E_SourceDatasetScreening()
clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

if ~isfolder(dataRoot) || ~isfolder(resultsRoot)
    error('Project data or results folder not found.');
end

% Use the latest Phase 6D registry.
d = dir(fullfile(resultsRoot,'Phase6D_Governance_*'));
d = d([d.isdir]);

if isempty(d)
    error('No Phase6D_Governance_* folder found.');
end

[~,ix] = max([d.datenum]);
phase6Dir = fullfile(resultsRoot,d(ix).name);
registryPath = fullfile(phase6Dir, ...
    'Phase6D_CanonicalDatasetRegistry.csv');

if ~isfile(registryPath)
    error('Phase 6D registry not found: %s',registryPath);
end

Registry = readtable(registryPath,'TextType','string');

required = ["FullPath","FileName","Topology", ...
    "RegistryStatus","Rows","MissingCells"];

for k = 1:numel(required)
    if ~any(strcmpi(string(Registry.Properties.VariableNames),required(k)))
        error('Registry missing required column: %s',required(k));
    end
end

fprintf('\n===== PHASE 6E: SOURCE DATASET SCREENING =====\n');
fprintf('Registry: %s\n',registryPath);
fprintf('Read-only mode enabled.\n');

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6E_SourceScreening_' stamp]);
mkdir(outDir);

%% Keep only files physically located under the data folder.

paths = string(Registry.FullPath);
isData = startsWith(lower(paths),lower(string(dataRoot) + filesep));

% Exclude any accidental results-folder entries.
CandidateIndex = find(isData);

n = numel(CandidateIndex);
rows = cell(n,12);
schemaRows = {};

for j = 1:n
    i = CandidateIndex(j);

    p = string(Registry.FullPath(i));
    fn = string(Registry.FileName(i));
    topology = string(Registry.Topology(i));
    oldStatus = string(Registry.RegistryStatus(i));

    nRows = NaN;
    nCols = NaN;
    missing = NaN;
    readable = false;
    columnNames = "";
    targetCandidates = "";
    errorText = "";

    try
        opts = detectImportOptions(char(p),'FileType','text');
        opts.VariableNamingRule = 'preserve';
        T = readtable(char(p),opts);

        readable = true;
        nRows = height(T);
        nCols = width(T);
        columnNames = strjoin(string(T.Properties.VariableNames),'|');
        missing = countMissingCells(T);

        targets = findPotentialTargets(T);
        targetCandidates = strjoin(targets,'|');

        for c = 1:width(T)
            col = string(T.Properties.VariableNames{c});
            v = T.(char(col));

            schemaRows(end+1,:) = {p,topology,col, ...
                string(class(v)),height(T),sumMissing(v)}; %#ok<AGROW>
        end

    catch ME
        errorText = string(ME.message);
    end

    [decision,reason] = screenDecision( ...
        p,fn,topology,oldStatus,readable,nRows,missing, ...
        targetCandidates);

    rows(j,:) = {p,fn,topology,oldStatus,nRows,nCols, ...
        missing,readable,columnNames,targetCandidates, ...
        decision,reason};

    if strlength(errorText)>0
        rows{j,12} = reason + " | Read error: " + errorText;
    end
end

Screening = cell2table(rows,'VariableNames',{ ...
    'FullPath','FileName','Topology','PreviousStatus', ...
    'Rows','Columns','MissingCells','Readable','ColumnNames', ...
    'PotentialTargetColumns','ScreeningDecision','Reason'});

writetable(Screening,fullfile(outDir, ...
    'Phase6E_SourceScreening.csv'));

%% Export column-level schema inventory.

if isempty(schemaRows)
    Schema = table();
else
    Schema = cell2table(schemaRows,'VariableNames',{ ...
        'FullPath','Topology','ColumnName','MATLABType', ...
        'Rows','MissingValues'});
end

writetable(Schema,fullfile(outDir, ...
    'Phase6E_ColumnSchemaInventory.csv'));

%% Export only the candidates needing human review.

mask = Screening.ScreeningDecision == "SOURCE_CANDIDATE_REVIEW";
Shortlist = Screening(mask,:);

writetable(Shortlist,fullfile(outDir, ...
    'Phase6E_CanonicalCandidateShortlist.csv'));

%% Summary by topology and decision.

decisions = unique(Screening.ScreeningDecision);
summaryRows = {};

for k = 1:numel(decisions)
    dec = decisions(k);
    summaryRows(end+1,:) = {dec,sum(Screening.ScreeningDecision==dec)}; %#ok<AGROW>
end

if isempty(summaryRows)
    Summary = table();
else
    Summary = cell2table(summaryRows,'VariableNames', ...
        {'ScreeningDecision','FileCount'});
end

writetable(Summary,fullfile(outDir, ...
    'Phase6E_ScreeningSummary.csv'));

%% Explicit governance record.

Policy = table( ...
    ["BJT_Common_Emitter";"MOSFET_Common_Source";"Unknown";"ALL"], ...
    ["Review CE source tables, measurements, and labels."; ...
     "Review CS source tables and compatible circuit parameter schemas."; ...
     "Do not mix unknown topology files into a training family."; ...
     "No source file or evaluation split is automatically approved."], ...
    'VariableNames',{'Scope','Rule'});

writetable(Policy,fullfile(outDir, ...
    'Phase6E_GovernanceRules.csv'));

fprintf('\n===== PHASE 6E SUMMARY =====\n');
fprintf('Data-folder CSV entries screened: %d\n',height(Screening));
fprintf('Readable files: %d\n',sum(Screening.Readable));
fprintf('Read errors: %d\n',sum(~Screening.Readable));
fprintf('Shortlist rows: %d\n',height(Shortlist));
fprintf('No source files modified.\n');
fprintf('No models trained. No splits approved or applied.\n');
fprintf('Reports saved to:\n%s\n\n',outDir);

end

%% ================= HELPERS =================

function n = countMissingCells(T)
n = 0;

for c = 1:width(T)
    n = n + sumMissing(T.(T.Properties.VariableNames{c}));
end
end

function n = sumMissing(v)
n = 0;

try
    if isnumeric(v) || islogical(v) || isstring(v) || ...
       iscategorical(v) || isdatetime(v) || isduration(v)
        n = sum(ismissing(v),'all');
    elseif iscell(v)
        for k = 1:numel(v)
            x = v{k};
            if isempty(x)
                n = n+1;
            elseif isnumeric(x) && isscalar(x) && isnan(x)
                n = n+1;
            end
        end
    end
catch
    % Leave unsupported data types for manual review.
end
end

function targets = findPotentialTargets(T)
% Heuristic name-based target discovery only.
% Does not decide whether a column is a valid scientific target.

names = string(T.Properties.VariableNames);
low = lower(names);

tokens = ["gain","bandwidth","cutoff","phase","vce", ...
    "vbe","ic","gm","region","status","valid", ...
    "frequency","freq","power","efficiency"];

mask = false(size(names));

for k = 1:numel(tokens)
    mask = mask | contains(low,tokens(k));
end

targets = names(mask);
end

function [decision,reason] = screenDecision( ...
    path,name,topology,oldStatus,readable,nRows,missing,targets)

s = lower(path + " " + name);

decision = "MANUAL_REVIEW";
reason = "Verify provenance, circuit parameters, and target meaning.";

if ~readable
    decision = "BLOCKED_READ_ERROR";
    reason = "CSV import failed; inspect the error before use.";
    return;
end

% Explicitly protect known evaluation artifacts.
if contains(s,"holdout") || contains(s,"test100") || ...
   contains(s,"freshcircuit") || contains(s,"test_predictions") || ...
   contains(s,"independentvalidation")

    decision = "PROTECTED_EVALUATION";
    reason = "Preserve the existing evaluation role.";
    return;
end

% Only files inside the data directory are considered here.
% Names alone are not enough to establish source provenance.
if topology == "Unknown"
    decision = "TOPOLOGY_REVIEW";
    reason = "Establish circuit topology before assigning a role.";
    return;
end

if contains(s,"prediction") || contains(s,"ranked") || ...
   contains(s,"summary") || contains(s,"metrics") || ...
   contains(s,"analysis") || contains(s,"report") || ...
   contains(s,"operatingpoint") || contains(s,"operating_point")
    decision = "LIKELY_DERIVED_REVIEW";
    reason = "Name suggests a derived output; trace it to source data.";
    return;
end

if isempty(nRows) || isnan(nRows) || nRows < 5
    decision = "INSUFFICIENT_ROWS_REVIEW";
    reason = "Too few rows for an initial source candidate.";
    return;
end

if missing > 0
    decision = "MISSING_DATA_REVIEW";
    reason = "Inspect missing values by column before eligibility review.";
    return;
end

if strlength(targets)==0
    decision = "TARGET_REVIEW";
    reason = "No obvious target-like column name; determine task and labels.";
    return;
end

decision = "SOURCE_CANDIDATE_REVIEW";
reason = "Promising structural candidate only; human approval required.";

end

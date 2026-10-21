function runPhase6C3_SourceLineageOverlapValidation()
clc;

root = 'C:\Internship Project';
resultsRoot = fullfile(root, 'results');

if ~isfolder(root)
    error('Project root does not exist: %s', root);
end

% Find the latest Phase 6C.2 output folder.
d = dir(fullfile(resultsRoot, 'Phase6C2_CanonicalLineage_*'));
d = d([d.isdir]);

if isempty(d)
    error('No Phase6C2_CanonicalLineage_* folder found.');
end

[~, order] = sort([d.datenum], 'descend');
inputDir = fullfile(resultsRoot, d(order(1)).name);

manifestPath = fullfile(inputDir, 'Phase6C2_FileManifest.csv');
pairPath = fullfile(inputDir, 'Phase6C2_OverlapPairSummary.csv');
detailPath = fullfile(inputDir, ...
    'Phase6C2_CrossDatasetConfigurationOverlap.csv');

if ~isfile(manifestPath) || ~isfile(pairPath)
    error('Required Phase 6C.2 reports are missing in %s', inputDir);
end

fprintf('\n===== PHASE 6C.3: SOURCE LINEAGE VALIDATION =====\n');
fprintf('Input folder: %s\n', inputDir);
fprintf('Read-only mode enabled.\n');

M = readtable(manifestPath, 'TextType', 'string');
P = readtable(pairPath, 'TextType', 'string');

% Resolve expected columns without relying on their order.
mPath = findColumn(M, ["FullPath","Path"]);
mName = findColumn(M, ["FileName","Filename"]);
mTopo = findColumn(M, ["Topology"]);
mRole = findColumn(M, ["ProvisionalRole","Role"]);
mRows = findColumn(M, ["Rows","RowCount"]);
mMissing = findColumn(M, ["MissingCells"]);
mReadable = findColumn(M, ["Readable"]);

pTopo = findColumn(P, ["Topology"]);
pA = findColumn(P, ["FileA"]);
pB = findColumn(P, ["FileB"]);
pShared = findColumn(P, ["SharedKeys","SharedConfigurationKeys"]);
pFracA = findColumn(P, [ ...
    "FractionAInSharedSet", ...
    "FractionOfAKeysShared", ...
    "FractionA", ...
    "FractionAKeysShared"]);

pFracB = findColumn(P, [ ...
    "FractionBInSharedSet", ...
    "FractionOfBKeysShared", ...
    "FractionB", ...
    "FractionBKeysShared"]);
% Create timestamped output folder.
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot, ...
    ['Phase6C3_SourceLineage_' stamp]);
mkdir(outDir);

%% 1. Classify every file conservatively

n = height(M);
fileReview = cell(n, 9);

for i = 1:n
    path = string(M.(mPath)(i));
    name = string(M.(mName)(i));
    topo = string(M.(mTopo)(i));
    role = string(M.(mRole)(i));

    nr = getNumeric(M, mRows, i);
    missing = getNumeric(M, mMissing, i);
    readable = getLogical(M, mReadable, i);

    [category, protection, reason] = ...
        classifyFile(path, name, topo, role, readable, missing);

    fileReview(i,:) = {path, name, topo, role, nr, missing, ...
        readable, category, protection + " | " + reason};
end

FileReview = cell2table(fileReview, 'VariableNames', ...
    {'FullPath','FileName','Topology','OriginalRole','Rows', ...
     'MissingCells','Readable','LineageCategory','ReviewReason'});

writetable(FileReview, fullfile(outDir, ...
    'Phase6C3_FileLineageReview.csv'));

%% 2. Review every overlap pair

np = height(P);
pairReview = cell(np, 11);

for i = 1:np
    topo = string(P.(pTopo)(i));
    a = string(P.(pA)(i));
    b = string(P.(pB)(i));

    shared = getNumeric(P, pShared, i);
    fracA = getNumeric(P, pFracA, i);
    fracB = getNumeric(P, pFracB, i);

    roleA = lookupRole(FileReview, a);
    roleB = lookupRole(FileReview, b);

    catA = lookupCategory(FileReview, a);
    catB = lookupCategory(FileReview, b);

    [risk, action, explanation] = classifyPair( ...
        topo, a, b, shared, fracA, fracB, ...
        roleA, roleB, catA, catB);

    pairReview(i,:) = {topo, a, b, shared, fracA, fracB, ...
        catA, catB, risk, action, explanation};
end

PairReview = cell2table(pairReview, 'VariableNames', ...
    {'Topology','FileA','FileB','SharedKeys','FractionA', ...
     'FractionB','CategoryA','CategoryB','RiskClass', ...
     'RecommendedAction','Explanation'});

writetable(PairReview, fullfile(outDir, ...
    'Phase6C3_OverlapRiskReview.csv'));

%% 3. Build a review queue for potential source datasets

isCandidate = FileReview.LineageCategory == "SOURCE_CANDIDATE" | ...
              FileReview.LineageCategory == "SOURCE_OR_DERIVED_REVIEW";

CandidateReview = FileReview(isCandidate, :);

if isempty(CandidateReview)
    CandidateReview = FileReview([], :);
end

writetable(CandidateReview, fullfile(outDir, ...
    'Phase6C3_SourceCandidateReview.csv'));

%% 4. Summarize risk classes by topology

topologies = unique(PairReview.Topology);
summaryRows = {};

for t = 1:numel(topologies)
    topo = topologies(t);
    ix = PairReview.Topology == topo;

    risks = PairReview.RiskClass(ix);

    summaryRows(end+1,:) = {topo, sum(ix), ...
        sum(risks == "HIGH_REVIEW"), ...
        sum(risks == "MEDIUM_REVIEW"), ...
        sum(risks == "LOWER_PRIORITY"), ...
        sum(risks == "UNCLASSIFIED"), ...
        "Overlap does not prove leakage."}; %#ok<AGROW>
end

if isempty(summaryRows)
    Summary = table();
else
    Summary = cell2table(summaryRows, 'VariableNames', ...
        {'Topology','PairCount','HighReviewPairs', ...
         'MediumReviewPairs','LowerPriorityPairs', ...
         'UnclassifiedPairs','Interpretation'});
end

writetable(Summary, fullfile(outDir, ...
    'Phase6C3_RiskSummary.csv'));

%% 5. Inspect the detailed configuration-overlap report

if isfile(detailPath)
    D = readtable(detailPath, 'TextType', 'string');

    % Record detail report dimensions, but do not treat each overlap row
    % as a unique circuit or as proof of train/test contamination.
    detailMeta = table(height(D), width(D), ...
        string(strjoin(string(D.Properties.VariableNames), '|')), ...
        'VariableNames', {'DetailRows','DetailColumns','ColumnNames'});

    writetable(detailMeta, fullfile(outDir, ...
        'Phase6C3_DetailReportMetadata.csv'));
else
    warning('Detailed overlap report not found: %s', detailPath);
end

%% 6. Write explicit governance rules

Policy = table( ...
    ["BJT"; "BJT"; "MOSFET"; "ALL"; "ALL"; "ALL"], ...
    ["Common-emitter datasets"; ...
     "Overlapping CE versions"; ...
     "Common-source datasets"; ...
     "Historical test/holdout files"; ...
     "Derived outputs and predictions"; ...
     "New train/validation/test splits"], ...
    ["Keep topology separate and inspect labels/features."; ...
     "Group shared circuit configurations across versions."; ...
     "Compare only compatible circuit parameter schemas."; ...
     "Preserve historical evaluation roles."; ...
     "Do not automatically treat derived files as source data."; ...
     "No split is approved by this audit."], ...
    'VariableNames', {'Scope','Area','Policy'});

writetable(Policy, fullfile(outDir, ...
    'Phase6C3_GovernanceRules.csv'));

%% 7. Save run metadata

metadata = table( ...
    string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    string(inputDir), string(outDir), height(M), height(P), ...
    'VariableNames', {'RunTime','InputFolder','OutputFolder', ...
                      'ManifestRows','OverlapPairRows'});

writetable(metadata, fullfile(outDir, ...
    'Phase6C3_RunMetadata.csv'));

fprintf('\n===== PHASE 6C.3 COMPLETE =====\n');
fprintf('Manifest files reviewed: %d\n', height(M));
fprintf('Overlap pairs reviewed: %d\n', height(P));
fprintf('Source candidate review rows: %d\n', height(CandidateReview));
fprintf('No source files modified.\n');
fprintf('No splits approved or applied.\n');
fprintf('Reports saved to:\n%s\n\n', outDir);

end

%% ================= HELPER FUNCTIONS =================

function col = findColumn(T, candidates)
names = string(T.Properties.VariableNames);
col = '';

for i = 1:numel(candidates)
    ix = find(strcmpi(names, candidates(i)), 1);
    if ~isempty(ix)
        col = char(names(ix));
        return;
    end
end

error('Required column not found. Tried: %s', ...
    strjoin(candidates, ', '));
end

function v = getNumeric(T, col, row)
v = NaN;

if isempty(col) || ~ismember(col, T.Properties.VariableNames)
    return;
end

x = T.(col);

try
    v = double(x(row));
catch
    try
        v = str2double(string(x(row)));
    catch
        v = NaN;
    end
end
end

function v = getLogical(T, col, row)
v = false;

if isempty(col) || ~ismember(col, T.Properties.VariableNames)
    return;
end

x = T.(col);

try
    v = logical(x(row));
catch
    s = lower(string(x(row)));
    v = any(s == ["true","1","yes"]);
end
end

function [category, protection, reason] = ...
    classifyFile(path, name, topo, role, readable, missing)

s = lower(path + " " + name);

category = "SOURCE_OR_DERIVED_REVIEW";
protection = "REVIEW";
reason = "Manual provenance and target review required.";

if ~readable
    category = "UNREADABLE";
    protection = "BLOCK";
    reason = "File could not be read in the manifest.";
    return;
end

% Evaluation artifacts get protected status first.
if contains(s,"holdout") || contains(s,"test100") || ...
   contains(s,"freshcircuit") || contains(s,"test_predictions") || ...
   contains(s,"independentvalidation")

    category = "PROTECTED_EVALUATION";
    protection = "PROTECT";
    reason = "Do not repurpose historical evaluation artifact.";
    return;
end

% Explicitly derived or report-like outputs.
derivedTokens = ["prediction","progress","report","summary", ...
    "metrics","audit","failure","ranked","operatingpoint", ...
    "operating_point","analysis","derived","candidate_results"];

for k = 1:numel(derivedTokens)
    if contains(s, derivedTokens(k))
        category = "DERIVED_OR_REPORT";
        protection = "REVIEW";
        reason = "Name/path suggests a derived or reporting artifact.";
        return;
    end
end

if topo == "Unknown"
    category = "TOPOLOGY_UNKNOWN";
    protection = "REVIEW";
    reason = "Topology must be established before use.";
    return;
end

if missing > 0
    category = "SOURCE_OR_DERIVED_REVIEW";
    protection = "REVIEW";
    reason = "Missing cells present; investigate schema and row validity.";
    return;
end

category = "SOURCE_CANDIDATE";
protection = "REVIEW";
reason = "Potential source only; verify provenance and label meaning.";

end

function v = lookupRole(T, path)
v = "UNKNOWN";
ix = find(strcmpi(string(T.FullPath), path), 1);

if ~isempty(ix)
    v = string(T.OriginalRole(ix));
end
end

function v = lookupCategory(T, path)
v = "UNKNOWN";
ix = find(strcmpi(string(T.FullPath), path), 1);

if ~isempty(ix)
    v = string(T.LineageCategory(ix));
end
end

function [risk, action, explanation] = classifyPair( ...
    topo, a, b, shared, fracA, fracB, ...
    roleA, roleB, catA, catB)

risk = "UNCLASSIFIED";
action = "MANUAL_REVIEW";
explanation = "Review source paths, compatible key columns, and provenance.";

if topo == "Unknown"
    explanation = "Unknown topology; do not combine with BJT or MOSFET.";
    return;
end

if catA == "PROTECTED_EVALUATION" || ...
   catB == "PROTECTED_EVALUATION" || ...
   contains(lower(a),"holdout") || contains(lower(b),"holdout") || ...
   contains(lower(a),"test100") || contains(lower(b),"test100") || ...
   contains(lower(a),"freshcircuit") || contains(lower(b),"freshcircuit")

    risk = "HIGH_REVIEW";
    action = "PROTECT_AND_TRACE";
    explanation = "Evaluation-related artifact overlaps another file. " + ...
        "Investigate possible contamination; overlap alone is not proof.";
    return;
end

if catA == "DERIVED_OR_REPORT" && catB == "DERIVED_OR_REPORT"
    risk = "LOWER_PRIORITY";
    action = "DOCUMENT_LINEAGE";
    explanation = "Both files appear derived/report-like. Do not count as " + ...
        "independent source datasets without evidence.";
    return;
end

if shared > 0 && fracA >= 0.99 && fracB >= 0.99
    risk = "HIGH_REVIEW";
    action = "GROUP_CONFIGURATIONS";
    explanation = "Nearly all keys overlap in both directions. " + ...
        "Treat as a shared configuration family until provenance is resolved.";
    return;
end

if shared > 0 && (fracA >= 0.10 || fracB >= 0.10)
    risk = "MEDIUM_REVIEW";
    action = "GROUP_SHARED_KEYS";
    explanation = "Partial configuration overlap; group shared keys across files.";
    return;
end

if shared > 0
    risk = "LOWER_PRIORITY";
    action = "RECORD_OVERLAP";
    explanation = "Overlap exists but reported fractions are small.";
end

end
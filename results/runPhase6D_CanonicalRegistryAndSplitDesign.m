
function runPhase6D_CanonicalRegistryAndSplitDesign()
clc;

root = 'C:\Internship Project';
resultsRoot = fullfile(root,'results');

if ~isfolder(root)
    error('Project root not found: %s',root);
end

lineageDir = latestFolder(resultsRoot,'Phase6C3_SourceLineage_*');
auditDir = latestFolder(resultsRoot,'Phase6C2_CanonicalLineage_*');

lineageFile = fullfile(lineageDir,'Phase6C3_FileLineageReview.csv');
riskFile = fullfile(lineageDir,'Phase6C3_OverlapRiskReview.csv');
riskSummaryFile = fullfile(lineageDir,'Phase6C3_RiskSummary.csv');
manifestFile = fullfile(auditDir,'Phase6C2_FileManifest.csv');
pairFile = fullfile(auditDir,'Phase6C2_OverlapPairSummary.csv');

requiredFiles = {lineageFile,riskFile,manifestFile,pairFile};

for k = 1:numel(requiredFiles)
    if ~isfile(requiredFiles{k})
        error('Required input report not found: %s',requiredFiles{k});
    end
end

fprintf('\n===== PHASE 6D: CANONICAL REGISTRY AND SPLIT DESIGN =====\n');
fprintf('Phase 6C.3 input: %s\n',lineageDir);
fprintf('Phase 6C.2 input: %s\n',auditDir);
fprintf('Read-only mode enabled.\n');

L = readtable(lineageFile,'TextType','string');
R = readtable(riskFile,'TextType','string');
M = readtable(manifestFile,'TextType','string');
P = readtable(pairFile,'TextType','string');

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6D_Governance_' stamp]);
mkdir(outDir);

%% 1. Validate the report schemas

requireColumns(L,["FullPath","FileName","Topology", ...
    "LineageCategory","ReviewReason"]);

requireColumns(R,["Topology","FileA","FileB","RiskClass", ...
    "RecommendedAction","Explanation"]);

requireColumns(M,["FullPath","FileName","Topology", ...
    "Rows","MissingCells","Readable"]);

requireColumns(P,["Topology","FileA","FileB","SharedKeys"]);

%% 2. Construct a canonical-dataset REVIEW registry

n = height(L);
registryRows = cell(n,12);

for i = 1:n
    path = string(L.FullPath(i));
    name = string(L.FileName(i));
    topology = string(L.Topology(i));
    category = string(L.LineageCategory(i));
    reason = string(L.ReviewReason(i));

    mi = find(strcmpi(string(M.FullPath),path),1);

    rows = NaN;
    missing = NaN;
    readable = false;

    if ~isempty(mi)
        rows = numericValue(M.Rows(mi));
        missing = numericValue(M.MissingCells(mi));
        readable = logicalValue(M.Readable(mi));
    end

    % Candidate status is deliberately conservative.
    [status,action,splitEligibility] = ...
        registryDecision(name,path,topology,category, ...
        reason,readable,missing);

    % Count overlap pairs that mention this file.
    if isempty(R)
        pairCount = 0;
    else
        pairCount = sum(strcmpi(string(R.FileA),path) | ...
                        strcmpi(string(R.FileB),path));
    end

    registryRows(i,:) = {path,name,topology,category,rows, ...
        missing,readable,pairCount,status,action, ...
        splitEligibility,reason};
end

Registry = cell2table(registryRows,'VariableNames',{ ...
    'FullPath','FileName','Topology','LineageCategory', ...
    'Rows','MissingCells','Readable','OverlapPairCount', ...
    'RegistryStatus','RecommendedAction','SplitEligibility', ...
    'ReviewEvidence'});

writetable(Registry,fullfile(outDir, ...
    'Phase6D_CanonicalDatasetRegistry.csv'));

%% 3. Create an overlap-based review queue

% Preserve the Phase 6C.3 classifications; do not silently reinterpret
% them as proven leakage.
ReviewQueue = R;

if height(ReviewQueue) > 0
    ReviewQueue.RequiresHumanReview = ...
        true(height(ReviewQueue),1);

    ReviewQueue.LeakageProven = ...
        false(height(ReviewQueue),1);

    ReviewQueue.GovernanceNote = repmat( ...
        "Configuration overlap requires provenance review; " + ...
        "overlap alone does not prove leakage.", ...
        height(ReviewQueue),1);
end

writetable(ReviewQueue,fullfile(outDir, ...
    'Phase6D_OverlapReviewQueue.csv'));

%% 4. Generate a leakage-aware split policy

policyRows = {
    "BJT_Common_Emitter", ...
    "Group by complete circuit configuration across related versions.", ...
    "Do not split overlapping versions independently.", ...
    "Pending lineage, target, and feature review";
    "MOSFET_Common_Source", ...
    "Group by compatible MOSFET circuit parameters.", ...
    "Keep configuration groups together across source and derived files.", ...
    "Pending source and label review";
    "Historical test/holdout", ...
    "Preserve the existing evaluation role.", ...
    "Do not use for fitting, feature selection, or model tuning.", ...
    "Protected";
    "Derived/prediction/report files", ...
    "Trace back to source configuration and generation process.", ...
    "Do not automatically promote to independent training data.", ...
    "Review required";
    "Files with missing values", ...
    "Inspect missingness by column and row.", ...
    "Do not silently impute or remove rows in this phase.", ...
    "Review required";
    "Unknown topology", ...
    "Establish topology and schema first.", ...
    "Do not mix with BJT or MOSFET families.", ...
    "Blocked pending classification";
    "New test partition", ...
    "Use only after dataset lineage is approved.", ...
    "Use group-aware partitioning with documented random seed.", ...
    "Not authorized by Phase 6D";
    "External independent evaluation", ...
    "Keep independent configurations and provenance records.", ...
    "Do not tune the model against the final evaluation set.", ...
    "Future evaluation design"
    };

SplitPolicy = cell2table(policyRows,'VariableNames',{ ...
    'Scope','GroupingRule','Restriction','Status'});

writetable(SplitPolicy,fullfile(outDir, ...
    'Phase6D_ProposedSplitPolicy.csv'));

%% 5. Summarize registry status correctly

categories = unique(Registry.RegistryStatus);
statusRows = cell(numel(categories),2);

for i = 1:numel(categories)
    statusRows(i,:) = {categories(i), ...
        sum(Registry.RegistryStatus == categories(i))};
end

RegistrySummary = cell2table(statusRows, ...
    'VariableNames', {'RegistryStatus','FileCount'});

writetable(RegistrySummary, ...
    fullfile(outDir,'Phase6D_RegistrySummary.csv'));

%% Count files requiring review, not just one specific status

reviewStatuses = [ ...
    "TOPOLOGY_REVIEW", ...
    "SOURCE_CANDIDATE_REVIEW", ...
    "DERIVED_OUTPUT_REVIEW", ...
    "MISSING_DATA_REVIEW", ...
    "BLOCKED_READ_ERROR", ...
    "REVIEW_REQUIRED"];

needsReview = ismember(Registry.RegistryStatus, reviewStatuses);

fprintf('Files requiring review: %d\n', sum(needsReview));

%% 6. Export unresolved lineage relationships

unresolvedStatuses = [ ...
    "TOPOLOGY_REVIEW", ...
    "SOURCE_CANDIDATE_REVIEW", ...
    "DERIVED_OUTPUT_REVIEW", ...
    "MISSING_DATA_REVIEW", ...
    "BLOCKED_READ_ERROR", ...
    "REVIEW_REQUIRED"];

unresolvedMask = ismember( ...
    Registry.RegistryStatus, unresolvedStatuses);

Unresolved = Registry(unresolvedMask,:);

writetable(Unresolved, ...
    fullfile(outDir,'Phase6D_UnresolvedDatasetLineage.csv'));

fprintf('Unresolved entries exported: %d\n', height(Unresolved));

%% 7. Export pair summaries for review

writetable(P,fullfile(outDir, ...
    'Phase6D_ConfigurationOverlapPairs.csv'));

%% 8. Write run metadata

metadata = table( ...
    string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    string(lineageDir),string(auditDir), ...
    height(Registry),height(R),height(P), ...
    sum(Registry.RegistryStatus == "REVIEW_REQUIRED"), ...
    sum(Registry.RegistryStatus == "PROTECTED_EVALUATION"), ...
    "No splits approved or applied", ...
    'VariableNames',{'RunTime','Phase6C3Folder','Phase6C2Folder', ...
    'RegistryRows','OverlapRiskRows','OverlapPairRows', ...
    'ReviewRequiredCount','ProtectedEvaluationCount','SplitStatus'});

writetable(metadata,fullfile(outDir, ...
    'Phase6D_RunMetadata.csv'));

fprintf('\n===== PHASE 6D COMPLETE =====\n');
fprintf('Registry rows: %d\n',height(Registry));
fprintf('Overlap-risk rows: %d\n',height(R));
fprintf('Configuration-pair rows: %d\n',height(P));
fprintf('Review required: %d\n', ...
    sum(Registry.RegistryStatus == "REVIEW_REQUIRED"));
fprintf('Protected evaluation artifacts: %d\n', ...
    sum(Registry.RegistryStatus == "PROTECTED_EVALUATION"));
fprintf('No source files modified.\n');
fprintf('No splits approved or applied.\n');
fprintf('Reports saved to:\n%s\n\n',outDir);

end

%% ================= HELPER FUNCTIONS =================

function folder = latestFolder(root,pattern)
d = dir(fullfile(root,pattern));
d = d([d.isdir]);

if isempty(d)
    error('No folder matching %s found under %s',pattern,root);
end

[~,ix] = max([d.datenum]);
folder = fullfile(root,d(ix).name);
end

function requireColumns(T,required)
names = string(T.Properties.VariableNames);

for i = 1:numel(required)
    if ~any(strcmpi(names,required(i)))
        error('Input report is missing required column: %s',required(i));
    end
end
end

function x = numericValue(v)
x = NaN;
try
    x = double(v);
catch
    try
        x = str2double(string(v));
    catch
        x = NaN;
    end
end
end

function x = logicalValue(v)
x = false;
try
    x = logical(v);
catch
    x = any(lower(string(v)) == ["true","1","yes"]);
end
end

function [status,action,eligibility] = registryDecision( ...
    name,path,topology,category,reason,readable,missing)

s = lower(name + " " + path);

status = "REVIEW_REQUIRED";
action = "Inspect provenance, schema, labels, and lineage.";
eligibility = "NOT_APPROVED";

if ~readable
    status = "BLOCKED_READ_ERROR";
    action = "Resolve file-read error.";
    eligibility = "BLOCKED";
    return;
end

% Protect historical evaluation artifacts before other heuristics.
if contains(s,"holdout") || contains(s,"test100") || ...
   contains(s,"freshcircuit") || contains(s,"test_predictions") || ...
   contains(s,"independentvalidation")

    status = "PROTECTED_EVALUATION";
    action = "Preserve existing evaluation role.";
    eligibility = "PROTECTED";
    return;
end

if topology == "Unknown" || category == "TOPOLOGY_UNKNOWN"
    status = "TOPOLOGY_REVIEW";
    action = "Determine topology before assigning a dataset role.";
    eligibility = "BLOCKED";
    return;
end

if category == "DERIVED_OR_REPORT"
    status = "DERIVED_OUTPUT_REVIEW";
    action = "Trace to source dataset; do not treat as independent source.";
    eligibility = "NOT_APPROVED";
    return;
end

if contains(s,"prediction") || contains(s,"ranked") || ...
   contains(s,"progress") || contains(s,"report") || ...
   contains(s,"summary") || contains(s,"analysis") || ...
   contains(s,"operatingpoint") || contains(s,"operating_point")

    status = "DERIVED_OUTPUT_REVIEW";
    action = "Verify whether this file is derived from another dataset.";
    eligibility = "NOT_APPROVED";
    return;
end

if missing > 0
    status = "MISSING_DATA_REVIEW";
    action = "Inspect missing columns and row validity.";
    eligibility = "NOT_APPROVED";
    return;
end

if category == "SOURCE_CANDIDATE"
    status = "SOURCE_CANDIDATE_REVIEW";
    action = "Verify provenance and target semantics before approval.";
    eligibility = "CANDIDATE_ONLY";
    return;
end

status = "REVIEW_REQUIRED";
action = "Manual lineage verification required.";
eligibility = "NOT_APPROVED";

end

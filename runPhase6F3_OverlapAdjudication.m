
%% PHASE 6F.3
% Overlap Adjudication and Grouping Proposal
% Read-only. No source modifications, model training, or data splitting.

clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(resultsRoot, ...
    ['Phase6F3_OverlapAdjudication_' stamp]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

fprintf('\nPHASE 6F.3 - OVERLAP ADJUDICATION\n');

%% A. Reconstruct the exact registered dataset list
% Keep this list in the same order as Phase 6F.2.

paths = {
    fullfile(dataRoot,'final','CE_Amplifier_ML_Valid.csv')
    fullfile(dataRoot,'processed','CE_Amplifier_Dataset_v2_test100.csv')
    fullfile(dataRoot,'processed','CE_Amplifier_Dataset_v3_500.csv')
    fullfile(dataRoot,'processed','CE_Amplifier_Dataset_v4_500_1GHz.csv')
    fullfile(dataRoot,'processed','CE_Amplifier_OperatingPoint_660.csv')
    fullfile(dataRoot,'raw','CE_Amplifier_Dataset_v5_2000_1GHz.csv')

    fullfile(dataRoot,'universal','Common_Source','pilot', ...
        'CS_Pilot_20261013_015305.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'external_model_validation','20261020_000113', ...
        'CS_Dataset_v2_100.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'external_model_validation','20261020_000113', ...
        'CS_Response_Diagnostics.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'external_model_validation','20261020_000113', ...
        'CS_DC_Analysis.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'external_model_validation','20261020_000113', ...
        'CS_AC_Performance_Labels.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'external_model_validation','20261020_000113', ...
        'CS_AC_Performance_Metrics.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'external_model_validation','20261020_000113', ...
        'CS_Bandwidth_Reference_Analysis.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'Phase4H_IndependentValidation','20261020_202353', ...
        'Phase4H_FreshCircuitDataset.csv')

    fullfile(dataRoot,'universal','Common_Source', ...
        'Phase5A_Optimization','20261020_203829', ...
        'Phase5A_DC_Candidates.csv')

    fullfile(dataRoot,'universal','Common_Source','external_model_pilot', ...
        '20261019_235224','CS_Dataset_v2_100.csv')

    fullfile(dataRoot,'universal','Common_Source','external_model_pilot', ...
        '20261019_235617','CS_Dataset_v2_100.csv')

    fullfile(dataRoot,'universal','Common_Source','v2_100', ...
        '20261013_020826','CS_Dataset_v2_100.csv')

    fullfile(dataRoot,'universal','Common_Source','v2_100', ...
        '20261019_215659','CS_Dataset_v2_100.csv')
};

paths = unique(paths,'stable');
N = numel(paths);

%% B. Find the latest Phase 6F.2 output folder

folders = dir(fullfile(resultsRoot, ...
    'Phase6F2_CrossDatasetOverlap_*'));

folders = folders([folders.isdir]);

if isempty(folders)
    error('No Phase6F.2 output folder found under results.');
end

[~,ix] = max([folders.datenum]);
phase6F2Dir = fullfile(resultsRoot,folders(ix).name);

pairFile = fullfile(phase6F2Dir,'Phase6F2_PairSummary.csv');
keyFile = fullfile(phase6F2Dir,'Phase6F2_KeyMapping.csv');

if ~isfile(pairFile)
    error('Missing Phase6F.2 PairSummary: %s',pairFile);
end

P = readtable(pairFile,'VariableNamingRule','preserve');

fprintf('Source Phase 6F.2 folder:\n%s\n',phase6F2Dir);

%% C. Build stable dataset IDs from full registered paths

DatasetID = strings(N,1);
FullPath = strings(N,1);
FileName = strings(N,1);
Topology = strings(N,1);
DatasetRole = strings(N,1);
Protected = false(N,1);
Registered = false(N,1);

for i = 1:N

    p = paths{i};
    FullPath(i) = string(p);

    [~,nm,ext] = fileparts(p);
    FileName(i) = string([nm ext]);

    if contains(lower(p),[filesep 'common_source' filesep])
        Topology(i) = "MOSFET_Common_Source";
    else
        Topology(i) = "BJT_Common_Emitter";
    end

    % ID is derived from the relative path, not the filename alone.
    rel = strrep(p,[root filesep],'');
    idPart = regexprep(rel,'[^A-Za-z0-9]+','_');
    DatasetID(i) = "DS_" + string(idPart);

    Registered(i) = isfile(p);

    lowerPath = lower(p);
    lowerName = lower(FileName(i));

    if contains(lowerName,'test100') || ...
            contains(lowerPath,'phase4h_independentvalidation')
        Protected(i) = true;
        DatasetRole(i) = "PROTECTED_EVALUATION";

    elseif contains(lowerName,'response_diagnostics') || ...
            contains(lowerName,'dc_analysis') || ...
            contains(lowerName,'performance_labels') || ...
            contains(lowerName,'performance_metrics') || ...
            contains(lowerName,'bandwidth_reference') || ...
            contains(lowerName,'phase5a_dc_candidates')
        DatasetRole(i) = "DERIVED_OUTPUT";

    elseif contains(lowerName,'dataset_v3_500') || ...
            contains(lowerName,'dataset_v4_500') || ...
            contains(lowerName,'operatingpoint_660') || ...
            contains(lowerName,'dataset_v5_2000') || ...
            contains(lowerName,'ml_valid')
        DatasetRole(i) = "OVERLAP_REVIEW";

    else
        DatasetRole(i) = "SOURCE_CANDIDATE_REVIEW";
    end
end

Registry = table(DatasetID,FileName,FullPath,Topology, ...
    Registered,Protected,DatasetRole);

writetable(Registry, ...
    fullfile(outDir,'Phase6F3_DatasetRegistry.csv'));

%% D. Reconstruct pair IDs from the Phase 6F.2 comparison order
% Phase 6F.2 incremented PairID for each same-topology pair.
% Validate names and topology before using a reconstructed pair.

mapA = zeros(height(P),1);
mapB = zeros(height(P),1);
pairMapStatus = strings(height(P),1);

pairID = 0;

for i = 1:N-1
    for j = i+1:N

        if Topology(i) ~= Topology(j)
            continue;
        end

        pairID = pairID + 1;

        r = find(P.PairID == pairID);

        if numel(r) ~= 1
            continue;
        end

        namesMatch = ...
            string(P.FileA(r)) == FileName(i) && ...
            string(P.FileB(r)) == FileName(j);

        topologyMatch = string(P.Topology(r)) == Topology(i);

        if namesMatch && topologyMatch
            mapA(r) = i;
            mapB(r) = j;
            pairMapStatus(r) = "RECONSTRUCTED_FROM_ORDER_AND_CHECKED";
        else
            pairMapStatus(r) = "IDENTITY_CHECK_FAILED";
        end
    end
end

%% E. Adjudicate every pair; no automatic approval

PairID = P.PairID;
TopologyPair = string(P.Topology);
FileA = string(P.FileA);
FileB = string(P.FileB);
SharedConfigurations = P.SharedConfigurations;
OverlapStatus = string(P.OverlapStatus);

DatasetIDA = strings(height(P),1);
DatasetIDB = strings(height(P),1);
PathA = strings(height(P),1);
PathB = strings(height(P),1);
EvidenceClass = strings(height(P),1);
GroupingDecision = strings(height(P),1);
AdjudicationNote = strings(height(P),1);

for r = 1:height(P)

    a = mapA(r);
    b = mapB(r);

    if a == 0 || b == 0 || ...
            pairMapStatus(r) == "IDENTITY_CHECK_FAILED"

        EvidenceClass(r) = "UNRESOLVED_IDENTITY";
        GroupingDecision(r) = "DO_NOT_AUTO_GROUP";
        AdjudicationNote(r) = ...
            "Could not safely reconstruct dataset identity from Phase 6F.2 pair order";
        continue;
    end

    DatasetIDA(r) = DatasetID(a);
    DatasetIDB(r) = DatasetID(b);
    PathA(r) = FullPath(a);
    PathB(r) = FullPath(b);

    if OverlapStatus(r) == "NOT_COMPARABLE"
        EvidenceClass(r) = "UNRESOLVED_SCHEMA";
        GroupingDecision(r) = "HOLD_FOR_REVIEW";
        AdjudicationNote(r) = ...
            "Missing or ambiguous key schema; no independence inference";

    elseif OverlapStatus(r) == "MATCHES_FOUND"

        if TopologyPair(r) == "MOSFET_Common_Source"
            EvidenceClass(r) = "PROVISIONAL_7_KEY_OVERLAP";
            GroupingDecision(r) = "PROPOSED_SAME_GROUP";
            AdjudicationNote(r) = ...
                "Seven-key match only; Cout_F and units remain unresolved";
        else
            EvidenceClass(r) = "BJT_9_KEY_SIGNATURE_OVERLAP";
            GroupingDecision(r) = "PROPOSED_SAME_GROUP";
            AdjudicationNote(r) = ...
                "Matching normalized signature; verify units, source lineage and row meaning";
        end

    else
        EvidenceClass(r) = "NO_MATCH_ON_TESTED_KEYS";
        GroupingDecision(r) = "NO_GROUP_DECISION";
        AdjudicationNote(r) = ...
            "Non-match is not proof of independence";
    end
end

PairAdjudication = table(PairID,TopologyPair, ...
    DatasetIDA,DatasetIDB,PathA,PathB, ...
    SharedConfigurations,OverlapStatus,EvidenceClass, ...
    GroupingDecision,AdjudicationNote);

writetable(PairAdjudication, ...
    fullfile(outDir,'Phase6F3_PairAdjudication.csv'));

%% F. Build provisional connected components from proposed overlap edges
% These components are grouping proposals only.
% Protected datasets remain protected even if an overlap is discovered.

global phase6F3_parent
phase6F3_parent = 1:N;

for r = 1:height(PairAdjudication)

    if PairAdjudication.GroupingDecision(r) ~= "PROPOSED_SAME_GROUP"
        continue;
    end

    a = mapA(r);
    b = mapB(r);

    if a == 0 || b == 0
        continue;
    end

    % Never connect different topologies.
    if Topology(a) ~= Topology(b)
        continue;
    end

    ra = findRoot(a);
    rb = findRoot(b);

    if ra ~= rb
        phase6F3_parent(rb) = ra;
    end
end

% Resolve roots after all unions.
GroupID = strings(N,1);
GroupConfidence = strings(N,1);
GroupDecision = strings(N,1);
GroupNote = strings(N,1);

for i = 1:N

    r = findRoot(i);

    if Topology(i) == "BJT_Common_Emitter"
        prefix = "BJT";
    else
        prefix = "MOSFET";
    end

    GroupID(i) = prefix + "_GROUP_" + sprintf('%03d',r);

    if Protected(i)
        GroupConfidence(i) = "PROTECTED";
        GroupDecision(i) = "EXCLUDED_FROM_FITTING_AND_TUNING";
        GroupNote(i) = ...
            "Preserve as protected evaluation data; do not use to select groups";
    elseif Topology(i) == "MOSFET_Common_Source"
        GroupConfidence(i) = "PROVISIONAL";
        GroupDecision(i) = "REVIEW_BEFORE_ANY_SPLIT";
        GroupNote(i) = ...
            "MOSFET grouping uses provisional seven-key overlap evidence";
    else
        GroupConfidence(i) = "PROPOSED";
        GroupDecision(i) = "REVIEW_BEFORE_ANY_SPLIT";
        GroupNote(i) = ...
            "BJT overlap component; source lineage and status differences still need review";
    end
end

GroupingProposal = table(DatasetID,FileName,FullPath,Topology, ...
    DatasetRole,Protected,GroupID,GroupConfidence, ...
    GroupDecision,GroupNote);

writetable(GroupingProposal, ...
    fullfile(outDir,'Phase6F3_GroupingProposal.csv'));

%% G. Explicit unresolved items

unresolved = {
    'BJT_v3_vs_v4', ...
    '500 shared configurations; 20 status discrepancy records', ...
    'Inspect affected rows and source-generation logic';

    'MOSFET_pilot_vs_validation', ...
    'Provisional overlap on seven tested keys', ...
    'Reconcile Cout_F, units, scales and exact source provenance';

    'Non-comparable dataset pairs', ...
    'Some datasets do not expose required configuration columns', ...
    'Trace derived outputs to their source datasets';

    'Protected evaluation artifacts', ...
    'Two registered protected datasets', ...
    'Keep out of training, feature selection and hyperparameter tuning';

    'Evaluation split', ...
    'Not approved', ...
    'Do not create a split until grouping and source eligibility are reviewed'
};

UnresolvedItems = cell2table(unresolved,'VariableNames',{ ...
    'Issue','CurrentEvidence','RequiredAction'});

writetable(UnresolvedItems, ...
    fullfile(outDir,'Phase6F3_UnresolvedItems.csv'));

%% H. Summary

fid = fopen(fullfile(outDir,'Phase6F3_RunSummary.txt'),'w');

if fid < 0
    error('Could not create Phase 6F.3 summary.');
end

fprintf(fid,'PHASE 6F.3 - OVERLAP ADJUDICATION\n');
fprintf(fid,'Timestamp: %s\n',stamp);
fprintf(fid,'Source folder: %s\n',phase6F2Dir);
fprintf(fid,'Read-only: YES\n');
fprintf(fid,'Registered datasets: %d\n',height(Registry));
fprintf(fid,'Registered paths found: %d\n',sum(Registered));
fprintf(fid,'Protected datasets: %d\n',sum(Protected));
fprintf(fid,'Phase 6F.2 pairs: %d\n',height(P));
fprintf(fid,'Reconstructed dataset pairs: %d\n',sum(mapA > 0 & mapB > 0));
fprintf(fid,'Proposed same-group decisions: %d\n', ...
    sum(GroupingDecision == "REVIEW_BEFORE_ANY_SPLIT"));
fprintf(fid,'Protected exclusions: %d\n',sum(Protected));
fprintf(fid,'No split created or approved.\n');
fprintf(fid,'No model training performed.\n');
fprintf(fid,'No source files modified.\n');

fprintf(fid,'\nCAUTIONS\n');
fprintf(fid,'Group IDs are proposals, not confirmed data provenance.\n');
fprintf(fid,'MOSFET grouping remains provisional due to seven-key matching.\n');
fprintf(fid,'Non-comparable pairs are unresolved, not independent.\n');
fprintf(fid,'Protected artifacts remain excluded from fitting and tuning.\n');

fclose(fid);

fprintf('\nPHASE 6F.3 COMPLETE\n');
fprintf('Output folder:\n%s\n',outDir);

%% Local function
function r = findRoot(i)
    global phase6F3_parent
    r = i;

    while phase6F3_parent(r) ~= r
        r = phase6F3_parent(r);
    end
end

clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(resultsRoot, ...
    ['Phase6E6_CanonicalLineage_' stamp]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% A. Register known datasets using explicit paths

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
    fullfile(dataRoot,'universal','Common_Source','pilot', ...
        'CS_Pilot_20261013_015305.csv')
    fullfile(dataRoot,'universal','Common_Source','external_model_pilot', ...
        '20261019_235224','CS_Dataset_v2_100.csv')
    fullfile(dataRoot,'universal','Common_Source','external_model_pilot', ...
        '20261019_235617','CS_Dataset_v2_100.csv')
    fullfile(dataRoot,'universal','Common_Source','pilot', ...
        'CS_Pilot_20261013_015305.csv')
    fullfile(dataRoot,'universal','Common_Source','v2_100', ...
        '20261013_020826','CS_Dataset_v2_100.csv')
    fullfile(dataRoot,'universal','Common_Source','v2_100', ...
        '20261019_215659','CS_Dataset_v2_100.csv')
};

% Remove repeated path entries while preserving order.
paths = unique(paths,'stable');

n = numel(paths);
fileNames = strings(n,1);
topologies = strings(n,1);
roles = strings(n,1);
decisions = strings(n,1);
reasons = strings(n,1);
rowCounts = nan(n,1);
columnCounts = nan(n,1);
readStatus = strings(n,1);
keyCoverage = strings(n,1);

%% B. Inspect files and assign conservative proposed roles

for i = 1:n
    p = paths{i};
    [~,nm,ext] = fileparts(p);
    fileNames(i) = string([nm ext]);

    if contains(p,[filesep 'processed' filesep]) || ...
       contains(p,[filesep 'final' filesep]) || ...
       contains(p,[filesep 'raw' filesep])
        topologies(i) = "BJT_Common_Emitter";
    elseif contains(p,[filesep 'Common_Source' filesep])
        topologies(i) = "MOSFET_Common_Source";
    else
        topologies(i) = "UNRESOLVED";
    end

    if ~isfile(p)
        readStatus(i) = "MISSING";
        roles(i) = "UNVERIFIED";
        decisions(i) = "HOLD";
        reasons(i) = "Explicit registered path not found";
        continue;
    end

    try
        T = readtable(p,'VariableNamingRule','preserve');
        rowCounts(i) = height(T);
        columnCounts(i) = width(T);
        readStatus(i) = "READABLE";

        % Conservative role assignment based on known provenance.
        if contains(fileNames(i),"test100",'IgnoreCase',true) || ...
           contains(p,'Phase4H_IndependentValidation')
            roles(i) = "PROTECTED_EVALUATION";
            decisions(i) = "PROTECT";
            reasons(i) = "Previously designated evaluation/validation artifact";

        elseif contains(fileNames(i),"OperatingPoint_660",'IgnoreCase',true) || ...
               contains(fileNames(i),"ML_Valid",'IgnoreCase',true)
            roles(i) = "OVERLAP_REVIEW";
            decisions(i) = "HOLD";
            reasons(i) = "Known overlapping BJT configuration lineage";

        elseif contains(fileNames(i),"Dataset_v3_500",'IgnoreCase',true) || ...
               contains(fileNames(i),"Dataset_v4_500",'IgnoreCase',true) || ...
               contains(fileNames(i),"Dataset_v5_2000",'IgnoreCase',true)
            roles(i) = "OVERLAP_REVIEW";
            decisions(i) = "HOLD";
            reasons(i) = "BJT versions require shared-configuration and provenance controls";

        elseif contains(fileNames(i),"Phase5A_DC_Candidates",'IgnoreCase',true)
            roles(i) = "DERIVED_CANDIDATES";
            decisions(i) = "NOT_CANONICAL";
            reasons(i) = "Optimization candidates are derived outputs";

        elseif contains(fileNames(i),"Response_Diagnostics",'IgnoreCase',true) || ...
               contains(fileNames(i),"DC_Analysis",'IgnoreCase',true) || ...
               contains(fileNames(i),"Performance_Labels",'IgnoreCase',true) || ...
               contains(fileNames(i),"Performance_Metrics",'IgnoreCase',true) || ...
               contains(fileNames(i),"Bandwidth_Reference",'IgnoreCase',true)
            roles(i) = "DERIVED_OUTPUT";
            decisions(i) = "NOT_CANONICAL";
            reasons(i) = "Analysis/diagnostic output, not a primary configuration source";

        elseif contains(fileNames(i),"CS_Pilot_",'IgnoreCase',true)
            roles(i) = "PILOT_SOURCE_CANDIDATE";
            decisions(i) = "REVIEW_REQUIRED";
            reasons(i) = "Pilot data; verify generation method and simulation provenance";

        elseif contains(fileNames(i),"CS_Dataset_v2_100",'IgnoreCase',true)
            roles(i) = "SOURCE_CANDIDATE_REVIEW";
            decisions(i) = "REVIEW_REQUIRED";
            reasons(i) = "Versioned dataset; establish origin and lineage before use";

        elseif contains(fileNames(i),"CE_Amplifier_Dataset_v2_test100",'IgnoreCase',true)
            roles(i) = "PROTECTED_EVALUATION";
            decisions(i) = "PROTECT";
            reasons(i) = "Protected test dataset";

        else
            roles(i) = "SOURCE_CANDIDATE_REVIEW";
            decisions(i) = "REVIEW_REQUIRED";
            reasons(i) = "No canonical approval granted by this audit";
        end

        keyCoverage(i) = summarizeKeys(T,topologies(i));

    catch ME
        readStatus(i) = "READ_ERROR";
        roles(i) = "UNVERIFIED";
        decisions(i) = "HOLD";
        reasons(i) = string(ME.message);
    end
end

Registry = table(fileNames,paths(:),topologies,readStatus, ...
    rowCounts,columnCounts,keyCoverage,roles,decisions,reasons, ...
    'VariableNames',{'FileName','FullPath','Topology','ReadStatus', ...
    'Rows','Columns','ConfigurationKeyCoverage','ProposedRole', ...
    'ProposedDisposition','Reason'});

writetable(Registry,fullfile(outDir,'Phase6E6_CanonicalRegistry.csv'));

%% C. Explicit known-lineage relationships

pairA = {
    'CE_Amplifier_Dataset_v3_500.csv'
    'CE_Amplifier_Dataset_v3_500.csv'
    'CE_Amplifier_Dataset_v4_500_1GHz.csv'
    'CE_Amplifier_OperatingPoint_660.csv'
    'CS_Pilot_20261013_015305.csv'
};

pairB = {
    'CE_Amplifier_Dataset_v4_500_1GHz.csv'
    'CE_Amplifier_OperatingPoint_660.csv'
    'CE_Amplifier_OperatingPoint_660.csv'
    'CE_Amplifier_Dataset_v5_2000_1GHz.csv'
    'CS_Dataset_v2_100.csv'
};

pairTopology = {
    'BJT_Common_Emitter'
    'BJT_Common_Emitter'
    'BJT_Common_Emitter'
    'BJT_Common_Emitter'
    'MOSFET_Common_Source'
};

evidence = {
    'Phase6E.4: 500 shared configurations; 20 status-field mismatch records'
    'Prior governance: OperatingPoint and v3 share 500 of 500 configurations'
    'Prior governance: v4 and OperatingPoint have documented overlapping lineage'
    'Prior governance: known shared BJT configurations; verify exact matching before final use'
    'Phase6E.4: zero shared keys; schema reconciliation required'
};

relationship = {
    'CONFIGURATION_OVERLAP_CONFIRMED'
    'CONFIGURATION_OVERLAP_REPORTED'
    'CONFIGURATION_OVERLAP_REPORTED'
    'CONFIGURATION_OVERLAP_REPORTED'
    'UNRESOLVED_SCHEMA_OR_VALUE_MISMATCH'
};

PairAudit = table(string(pairA),string(pairB),string(pairTopology), ...
    string(relationship),string(evidence), ...
    'VariableNames',{'FileA','FileB','Topology','Relationship','Evidence'});

writetable(PairAudit,fullfile(outDir,'Phase6E6_LineagePairReview.csv'));

%% D. Leakage-safe grouping proposal

groupRows = {
    'BJT_Common_Emitter', ...
    'Use normalized circuit configuration key across all versions', ...
    'R1;R2;RC;RE;RL;Cin;Cout;Ce;VCC', ...
    'All versions of the same configuration must remain in one group', ...
    'PROPOSED_NOT_APPROVED'
    'MOSFET_Common_Source', ...
    'Use reconciled physical parameter key after schema/units review', ...
    'RGU;RGL;RD;RS;VDD;VGS;Cin;Cout (verify actual aliases)', ...
    'Same physical circuit must not cross partitions', ...
    'PROPOSED_NOT_APPROVED'
    'ALL_TOPOLOGIES', ...
    'Keep topology-specific models and keys separate unless explicitly justified', ...
    'Topology plus canonical configuration identity', ...
    'Do not pool BJT and MOSFET samples as equivalent circuits', ...
    'PROPOSED_NOT_APPROVED'
    'PROTECTED_EVALUATION', ...
    'Keep protected validation/test artifacts out of fitting and tuning', ...
    'Preserve source path and evaluation provenance', ...
    'No reuse for training or hyperparameter selection without protocol review', ...
    'PROTECT'
};

GroupingProposal = cell2table(groupRows,'VariableNames', ...
    {'Scope','ProposedGroupingRule','CandidateKey','LeakageControl','Status'});

writetable(GroupingProposal, ...
    fullfile(outDir,'Phase6E6_GroupingProposal.csv'));

%% E. Unresolved review queue

reviewRows = {
    'R01','BJT','Investigate 10 configurations with status changes between v3 and v4', ...
    'Compare source netlists, simulator logs, extraction settings, and raw records','OPEN'
    'R02','MOSFET','Reconcile pilot and external-validation column aliases and units', ...
    'Inspect schema, parameter ranges, and actual row values; do not infer independence','OPEN'
    'R03','BJT','Establish primary source and derivation history for v3/v4/v5/OperatingPoint', ...
    'Review generator scripts and simulation provenance','OPEN'
    'R04','MOSFET','Verify whether pilot and validation rows originate from separate generation runs', ...
    'Check generation seeds, source scripts, configuration identity, and timestamps','OPEN'
    'R05','EVALUATION','Verify protected test/validation artifacts and usage restrictions', ...
    'Trace evaluation protocol and downstream dependencies','OPEN'
    'R06','ALL','Approve canonical dataset and split policy only after review', ...
    'Human review required; this script does not approve or apply a split','OPEN'
};

ReviewQueue = cell2table(reviewRows,'VariableNames', ...
    {'ReviewID','Scope','Question','RequiredEvidence','Status'});

writetable(ReviewQueue,fullfile(outDir,'Phase6E6_ReviewQueue.csv'));

%% F. Run summary

fid = fopen(fullfile(outDir,'Phase6E6_RunSummary.txt'),'w');
if fid < 0
    error('Cannot create run summary.');
end

fprintf(fid,'PHASE 6E.6 - CANONICAL LINEAGE AND GROUPING PROPOSAL\n');
fprintf(fid,'Timestamp: %s\n',stamp);
fprintf(fid,'Read-only: YES\n');
fprintf(fid,'Registered unique paths: %d\n',height(Registry));
fprintf(fid,'Readable files: %d\n',sum(Registry.ReadStatus=="READABLE"));
fprintf(fid,'Missing files: %d\n',sum(Registry.ReadStatus=="MISSING"));
fprintf(fid,'Read errors: %d\n',sum(Registry.ReadStatus=="READ_ERROR"));
fprintf(fid,'Protected evaluation entries: %d\n', ...
    sum(Registry.ProposedRole=="PROTECTED_EVALUATION"));
fprintf(fid,'Review queue items: %d\n',height(ReviewQueue));
fprintf(fid,'Known lineage pair rows: %d\n',height(PairAudit));
fprintf(fid,'\nNo source data modified.\n');
fprintf(fid,'No model training performed.\n');
fprintf(fid,'No train/test split created, applied, or approved.\n');
fprintf(fid,'No independence inferred from zero configuration overlap.\n');
fprintf(fid,'All canonical roles and grouping rules remain proposals.\n');
fclose(fid);

fprintf('\nPHASE 6E.6 COMPLETE\nOutput folder:\n%s\n',outDir);

%% Local helper functions

function s = summarizeKeys(T,topology)
    names = string(T.Properties.VariableNames);

    if topology == "BJT_Common_Emitter"
        expected = ["R1","R2","RC","RE","RL","Cin","Cout","Ce","VCC"];
    elseif topology == "MOSFET_Common_Source"
        expected = ["RGU_Ohm","RGL_Ohm","RD_Ohm","RS_Ohm", ...
                    "VDD_V","VGS_V","Cin_F","Cout_F"];
    else
        s = "UNKNOWN_TOPOLOGY";
        return;
    end

    found = strings(0,1);
    for k = 1:numel(expected)
        if any(strcmpi(names,expected(k)))
            found(end+1,1) = expected(k); %#ok<AGROW>
        end
    end

    s = strjoin(found,';');
    if isempty(found)
        s = "NO_EXPECTED_KEYS_FOUND";
    end
end

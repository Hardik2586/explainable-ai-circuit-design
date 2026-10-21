
clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(resultsRoot, ...
    ['Phase6F_DatasetEligibility_' stamp]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

%% A. Explicit dataset registry
% No ambiguous filename search is performed.

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

%% B. Inspect eligibility, schema, missingness and key availability

FileName = strings(N,1);
FullPath = strings(N,1);
Topology = strings(N,1);
Role = strings(N,1);
Eligibility = strings(N,1);
Reason = strings(N,1);
ReadStatus = strings(N,1);
Rows = nan(N,1);
Columns = nan(N,1);
MissingCells = nan(N,1);
MissingPercent = nan(N,1);
CompleteKeyRows = nan(N,1);
KeyColumnsFound = strings(N,1);
KeyColumnsExpected = strings(N,1);

schemaRows = cell(0,6);
riskRows = cell(0,4);

for i = 1:N

    p = paths{i};
    FullPath(i) = string(p);

    [~,nm,ext] = fileparts(p);
    FileName(i) = string([nm ext]);

    if contains(p,[filesep 'Common_Source' filesep])
        Topology(i) = "MOSFET_Common_Source";
        expectedKeys = ["RGU_Ohm","RGL_Ohm","RD_Ohm", ...
            "RS_Ohm","VDD_V","VGS_V","Cin_F","Cout_F"];
    else
        Topology(i) = "BJT_Common_Emitter";
        expectedKeys = ["R1","R2","RC","RE","RL", ...
            "Cin","Cout","Ce","VCC"];
    end

    KeyColumnsExpected(i) = strjoin(expectedKeys,';');

    if ~isfile(p)
        ReadStatus(i) = "MISSING";
        Role(i) = "UNVERIFIED";
        Eligibility(i) = "HOLD";
        Reason(i) = "Explicit registered path does not exist";
        riskRows(end+1,:) = {char(FileName(i)), ...
            'FILE_MISSING','Verify the intended exact source path','HIGH'};
        continue;
    end
    fn = lower(string(FileName(i)));
    fullLower = lower(string(p));

    if contains(fn,"test100") || ...
             contains(fullLower,"phase4h_independentvalidation")

       Role(i) = "PROTECTED_EVALUATION";
       Eligibility(i) = "PROTECT";
       Reason(i) = "Previously designated test or independent-validation artifact";

   end
    try
        T = readtable(p,'VariableNamingRule','preserve');
        ReadStatus(i) = "READABLE";

        Rows(i) = height(T);
        Columns(i) = width(T);

        names = string(T.Properties.VariableNames);

        missingTotal = 0;
        cellTotal = height(T)*width(T);

        for c = 1:width(T)
            x = T.(char(names(c)));

            if isnumeric(x) || islogical(x)
                miss = sum(~isfinite(double(x(:))));
            else
                sx = string(x(:));
                miss = sum(ismissing(sx) | ...
                    strlength(strtrim(sx)) == 0);
            end

            missingTotal = missingTotal + miss;

            % Safely format sample values, including missing entries.
            nShow = min(3, height(T));

            if nShow > 0
                sampleValues = string(x(1:nShow));
                sampleValues(ismissing(sampleValues)) = "<missing>";
                sampleText = char(strjoin(sampleValues, " | "));
            else
                sampleText = "";
            end
        end

        MissingCells(i) = missingTotal;

        if cellTotal > 0
            MissingPercent(i) = 100*missingTotal/cellTotal;
        else
            MissingPercent(i) = NaN;
        end

        found = strings(0,1);
        for k = 1:numel(expectedKeys)
            idx = find(strcmpi(names, expectedKeys(k)), 1, 'first');

            if ~isempty(idx)
                found(end+1,1) = names(idx); %#ok<SAGROW>
            end
        end

        KeyColumnsFound(i) = strjoin(found,';');

        if isempty(found)
            CompleteKeyRows(i) = 0;
        else
            mask = true(height(T),1);

            for k = 1:numel(found)
                col = T.(char(found(k)));

                if isnumeric(col) || islogical(col)
                    mask = mask & isfinite(double(col));
                else
                    sx = string(col);
                    mask = mask & ~ismissing(sx) & ...
                        strlength(strtrim(sx)) > 0;
                end
            end

            CompleteKeyRows(i) = sum(mask);
        end

        %% Conservative eligibility classifications

        fn = lower(FileName(i));
        fullLower = lower(string(p));

        if contains(fn,"test100") || contains(fullLower,"phase4h_independentvalidation")
            Role(i) = "PROTECTED_EVALUATION";
            Eligibility(i) = "PROTECT";
            Reason(i) = "Previously designated test or independent-validation artifact";

        elseif contains(fn,"response_diagnostics") || ...
               contains(fn,"dc_analysis") || ...
               contains(fn,"performance_labels") || ...
               contains(fn,"performance_metrics") || ...
               contains(fn,"bandwidth_reference") || ...
               contains(fn,"phase5a_dc_candidates")
            Role(i) = "DERIVED_OUTPUT";
            Eligibility(i) = "NOT_PRIMARY_DATA";
            Reason(i) = "Analysis, diagnostic, or optimization output; trace its source first";

        elseif contains(fn,"dataset_v3_500") || ...
               contains(fn,"dataset_v4_500") || ...
               contains(fn,"operatingpoint_660") || ...
               contains(fn,"dataset_v5_2000") || ...
               contains(fn,"ml_valid")
            Role(i) = "OVERLAP_REVIEW";
            Eligibility(i) = "HOLD";
            Reason(i) = "Known BJT overlap or version lineage requires adjudication";

        elseif contains(fn,"cs_pilot_")
            Role(i) = "PILOT_CANDIDATE";
            Eligibility(i) = "REVIEW_REQUIRED";
            Reason(i) = "Pilot provenance and parameter schema require review";

        elseif contains(fn,"cs_dataset_v2_100")
            Role(i) = "VERSIONED_CANDIDATE";
            Eligibility(i) = "REVIEW_REQUIRED";
            Reason(i) = "Confirm generation provenance, schema, and relationship to other versions";

        else
            Role(i) = "UNRESOLVED_SOURCE";
            Eligibility(i) = "REVIEW_REQUIRED";
            Reason(i) = "No canonical approval granted by this audit";
        end

        if CompleteKeyRows(i) < Rows(i)
            riskRows(end+1,:) = {char(FileName(i)), ...
                'INCOMPLETE_CONFIGURATION_KEYS', ...
                'Inspect missing key values before grouping or splitting','HIGH'}; %#ok<SAGROW>
        end

        if MissingPercent(i) > 0
            riskRows(end+1,:) = {char(FileName(i)), ...
                'MISSING_VALUES', ...
                'Determine whether missingness affects features, targets, or status labels','MEDIUM'}; %#ok<SAGROW>
        end

    catch ME
        ReadStatus(i) = "READ_ERROR";
        Role(i) = "UNVERIFIED";
        Eligibility(i) = "HOLD";
        Reason(i) = string(ME.message);

        riskRows(end+1,:) = {char(FileName(i)), ...
            'READ_ERROR',char(string(ME.message)),'HIGH'}; %#ok<SAGROW>
    end
end

EligibilityMatrix = table(FileName,FullPath,Topology,ReadStatus, ...
    Rows,Columns,MissingCells,MissingPercent, ...
    KeyColumnsExpected,KeyColumnsFound,CompleteKeyRows, ...
    Role,Eligibility,Reason);

writetable(EligibilityMatrix, ...
    fullfile(outDir,'Phase6F_EligibilityMatrix.csv'));

if isempty(schemaRows)
    SchemaInventory = table();
else
    SchemaInventory = cell2table(schemaRows,'VariableNames', ...
        {'FileName','ColumnName','MATLABType','RowCount', ...
         'MissingCount','FirstThreeExamples'});
end

writetable(SchemaInventory, ...
    fullfile(outDir,'Phase6F_SchemaInventory.csv'));

if isempty(riskRows)
    RiskRegister = table();
else
    RiskRegister = cell2table(riskRows,'VariableNames', ...
        {'FileName','RiskCode','RequiredAction','Severity'});
end

writetable(RiskRegister, ...
    fullfile(outDir,'Phase6F_RiskRegister.csv'));

%% C. Explicitly record known BJT lineage and status discrepancies

bjtV3 = fullfile(dataRoot,'processed', ...
    'CE_Amplifier_Dataset_v3_500.csv');

bjtV4 = fullfile(dataRoot,'processed', ...
    'CE_Amplifier_Dataset_v4_500_1GHz.csv');

bjtSummary = {
    'BJT_v3_vs_v4','500 configurations shared', ...
    'CONFIGURATION_OVERLAP_CONFIRMED', ...
    'Do not treat as independent datasets'
    'BJT_v3_vs_v4','20 status discrepancy records', ...
    'STATUS_DISCREPANCIES_CONFIRMED', ...
    'Investigate the 10 affected configurations and both status fields'
    'MOSFET_pilot_vs_validation','0 shared configurations under tested keys', ...
    'UNRESOLVED', ...
    'Zero overlap does not establish independence; reconcile aliases and units'
};

BJTLineage = cell2table(bjtSummary,'VariableNames', ...
    {'Comparison','Finding','EvidenceStatus','RequiredControl'});

writetable(BJTLineage, ...
    fullfile(outDir,'Phase6F_KnownLineageFindings.csv'));

%% D. Proposed evaluation protocol

protocolRows = {
    'P01','Topology separation', ...
    'Maintain separate BJT common-emitter and MOSFET common-source pipelines', ...
    'REQUIRED'
    'P02','Configuration grouping', ...
    'Group identical canonical circuit configurations before any partitioning', ...
    'REQUIRED'
    'P03','Version lineage', ...
    'Keep overlapping versions and derived copies in the same group', ...
    'REQUIRED'
    'P04','Protected evaluation', ...
    'Do not use protected test/validation artifacts for fitting, feature selection, or tuning', ...
    'REQUIRED'
    'P05','Status integrity', ...
    'Resolve simulation and extraction failures before defining eligible targets', ...
    'REQUIRED'
    'P06','Missingness policy', ...
    'Document missingness handling separately for features, labels, and diagnostics', ...
    'REQUIRED'
    'P07','Independent test', ...
    'Use a genuinely independent test source only after provenance is verified', ...
    'PENDING_EVIDENCE'
    'P08','Split creation', ...
    'Create no split until grouping, eligibility, and protected boundaries are reviewed', ...
    'NOT_APPLIED'
};

EvaluationProtocol = cell2table(protocolRows,'VariableNames', ...
    {'ProtocolID','Control','ProposedRule','Status'});

writetable(EvaluationProtocol, ...
    fullfile(outDir,'Phase6F_EvaluationProtocol.csv'));

%% E. Final run summary

fid = fopen(fullfile(outDir,'Phase6F_RunSummary.txt'),'w');

if fid < 0
    error('Cannot create run summary.');
end

fprintf(fid,'PHASE 6F - DATASET ELIGIBILITY VALIDATION\n');
fprintf(fid,'Timestamp: %s\n',stamp);
fprintf(fid,'Read-only: YES\n');
fprintf(fid,'Registered paths: %d\n',height(EligibilityMatrix));
fprintf(fid,'Readable files: %d\n',sum(ReadStatus=="READABLE"));
fprintf(fid,'Missing files: %d\n',sum(ReadStatus=="MISSING"));
fprintf(fid,'Read errors: %d\n',sum(ReadStatus=="READ_ERROR"));
fprintf(fid,'Protected entries: %d\n',sum(Role=="PROTECTED_EVALUATION"));
fprintf(fid,'Derived outputs: %d\n',sum(Role=="DERIVED_OUTPUT"));
fprintf(fid,'Review-required entries: %d\n',sum(Eligibility=="REVIEW_REQUIRED"));
fprintf(fid,'Hold entries: %d\n',sum(Eligibility=="HOLD"));
fprintf(fid,'Risk register rows: %d\n',size(riskRows,1));

fprintf(fid,'\nKNOWN EVIDENCE\n');
fprintf(fid,'BJT v3/v4: 500 shared configurations.\n');
fprintf(fid,'BJT status differences: 20 records across two fields.\n');
fprintf(fid,'MOSFET pilot/validation: zero matched tested keys; independence unresolved.\n');

fprintf(fid,'\nLIMITATIONS\n');
fprintf(fid,'This script performs eligibility screening, not final source approval.\n');
fprintf(fid,'Missing-value percentage is cell-based and is not a target-quality score.\n');
fprintf(fid,'Configuration key completeness does not prove unique configurations.\n');
fprintf(fid,'No training, split creation, split application, or split approval occurred.\n');
fprintf(fid,'All proposed roles require review against source provenance.\n');

fclose(fid);

fprintf('\nPHASE 6F COMPLETE\nOutput folder:\n%s\n',outDir);


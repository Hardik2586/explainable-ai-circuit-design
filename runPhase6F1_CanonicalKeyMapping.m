
clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(resultsRoot, ...
    ['Phase6F1_CanonicalKeyMapping_' stamp]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

fprintf('\n========================================\n');
fprintf('PHASE 6F.1: CANONICAL KEY MAPPING\n');
fprintf('========================================\n');

%% A. Explicit dataset registry

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

%% B. Define canonical parameter names and candidate aliases
% Aliases are proposals, not proof of equivalent physical units.
% Capacitance and resistance units must be verified separately.

bjtKeys = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};

bjtAliases = {
    {'R1'}
    {'R2'}
    {'RC'}
    {'RE'}
    {'RL'}
    {'Cin','CIN'}
    {'Cout','COUT'}
    {'Ce','CE'}
    {'VCC','Vcc'}
};

mosKeys = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'VDD_V','VGS_V','Cin_F','Cout_F'};

mosAliases = {
    {'RGU_Ohm','RGU_OHM'}
    {'RGL_Ohm','RGL_OHM'}
    {'RD_Ohm','RD_OHM'}
    {'RS_Ohm','RS_OHM'}
    {'VDD_V','VDD_v'}
    {'VGS_V','VGS_v'}
    {'Cin_F','CIN_F','cin_f'}
    {'Cout_F','COUT_F','cout_f'}
};

%% C. Initialize audit tables

fileRows = cell(0,14);
mapRows = cell(0,7);
duplicateRows = cell(0,5);
riskRows = cell(0,5);

for i = 1:N

    p = paths{i};
    [~,base,ext] = fileparts(p);
    fileName = [base ext];

    pathLower = lower(p);

    if contains(pathLower,[filesep 'common_source' filesep])
        topology = 'MOSFET_Common_Source';
        canonicalKeys = mosKeys;
        aliases = mosAliases;
    else
        topology = 'BJT_Common_Emitter';
        canonicalKeys = bjtKeys;
        aliases = bjtAliases;
    end

    % Determine protection and provisional role before reading the file.
    fileLower = lower(fileName);

    if contains(fileLower,'test100') || ...
            contains(pathLower,'phase4h_independentvalidation')
        role = 'PROTECTED_EVALUATION';
        eligibility = 'PROTECT';
        roleReason = 'Previously designated test/validation artifact';

    elseif contains(fileLower,'response_diagnostics') || ...
            contains(fileLower,'dc_analysis') || ...
            contains(fileLower,'performance_labels') || ...
            contains(fileLower,'performance_metrics') || ...
            contains(fileLower,'bandwidth_reference') || ...
            contains(fileLower,'phase5a_dc_candidates')
        role = 'DERIVED_OUTPUT';
        eligibility = 'NOT_PRIMARY_DATA';
        roleReason = 'Analysis, diagnostic, or optimization output';

    elseif contains(fileLower,'dataset_v3_500') || ...
            contains(fileLower,'dataset_v4_500') || ...
            contains(fileLower,'operatingpoint_660') || ...
            contains(fileLower,'dataset_v5_2000') || ...
            contains(fileLower,'ml_valid')
        role = 'OVERLAP_REVIEW';
        eligibility = 'HOLD';
        roleReason = 'Known BJT overlap/version lineage needs review';

    else
        role = 'SOURCE_CANDIDATE_REVIEW';
        eligibility = 'REVIEW_REQUIRED';
        roleReason = 'Source provenance and suitability not yet approved';
    end

    if ~isfile(p)
        fileRows(end+1,:) = {fileName,p,topology,'MISSING',NaN, ...
            NaN,NaN,0,'',role,eligibility, ...
            'File does not exist',roleReason,'NO_SIGNATURE'};

        riskRows(end+1,:) = {fileName,'FILE_MISSING', ...
            'Check the exact registered path','HIGH',p};
        continue;
    end

    try
        T = readtable(p,'VariableNamingRule','preserve');
    catch ME
        fileRows(end+1,:) = {fileName,p,topology,'READ_ERROR',NaN, ...
            NaN,NaN,0,'',role,'HOLD',char(ME.message), ...
            roleReason,'NO_SIGNATURE'};

        riskRows(end+1,:) = {fileName,'READ_ERROR', ...
            char(ME.message),'HIGH',p};
        continue;
    end

    nRows = height(T);
    nCols = width(T);
    names = T.Properties.VariableNames;

    mappedColumns = cell(size(canonicalKeys));
    keyStates = cell(size(canonicalKeys));
    allMapped = true;

    %% Map canonical keys to actual columns

    for k = 1:numel(canonicalKeys)

        aliasList = aliases{k};
        matched = {};

        for a = 1:numel(aliasList)
            idx = find(strcmpi(names,aliasList{a}));

            for q = 1:numel(idx)
                candidate = names{idx(q)};

                if ~any(strcmp(matched,candidate))
                    matched{end+1} = candidate; %#ok<SAGROW>
                end
            end
        end

        if isempty(matched)
            mappedColumns{k} = '';
            keyStates{k} = 'MISSING_KEY';
            allMapped = false;

        elseif numel(matched) > 1
            mappedColumns{k} = strjoin(matched,';');
            keyStates{k} = 'AMBIGUOUS_MULTIPLE_COLUMNS';
            allMapped = false;

        else
            mappedColumns{k} = matched{1};

            % Record mapping, but do not claim unit equivalence.
            keyStates{k} = 'MAPPED_UNIT_REVIEW';
        end

        mapRows(end+1,:) = {fileName,topology,canonicalKeys{k}, ...
            strjoin(aliasList,';'),mappedColumns{k}, ...
            keyStates{k}, ...
            'Verify units and semantic equivalence before approval'}; %#ok<SAGROW>

        if strcmp(keyStates{k},'MISSING_KEY')
            riskRows(end+1,:) = {fileName, ...
                ['MISSING_CANONICAL_KEY_' canonicalKeys{k}], ...
                'Determine whether the parameter is absent or differently named', ...
                'HIGH',p}; %#ok<SAGROW>
        elseif strcmp(keyStates{k},'AMBIGUOUS_MULTIPLE_COLUMNS')
            riskRows(end+1,:) = {fileName, ...
                ['AMBIGUOUS_CANONICAL_KEY_' canonicalKeys{k}], ...
                'Resolve which column represents the canonical parameter', ...
                'HIGH',p}; %#ok<SAGROW>
        end
    end

    %% Check complete key rows only if all canonical columns are mapped

    completeKeyRows = NaN;
    duplicateConfigRows = NaN;
    signatureStatus = 'NOT_COMPUTED';
    signatureText = cell(nRows,1);

    if allMapped

        keyMatrix = cell(nRows,numel(canonicalKeys));
        validMask = true(nRows,1);

        for k = 1:numel(canonicalKeys)

            colName = mappedColumns{k};
            x = T.(colName);

            if isnumeric(x) || islogical(x)
                x = double(x(:));
                valid = isfinite(x);

                for r = 1:nRows
                    if valid(r)
                        keyMatrix{r,k} = sprintf('%.15g',x(r));
                    else
                        keyMatrix{r,k} = '';
                    end
                end

            else
                sx = string(x(:));
                valid = ~ismissing(sx) & ...
                    strlength(strtrim(sx)) > 0;

                for r = 1:nRows
                    if valid(r)
                        keyMatrix{r,k} = char(strtrim(sx(r)));
                    else
                        keyMatrix{r,k} = '';
                    end
                end
            end

            validMask = validMask & valid;
        end

        completeKeyRows = sum(validMask);

        % Signatures are local to each file. Do not compare them across
        % files until units, scales, and semantic aliases are reviewed.
        for r = 1:nRows
            if validMask(r)
                parts = keyMatrix(r,:);
                signatureText{r} = strjoin(parts,'|');
            else
                signatureText{r} = '';
            end
        end

        goodSigs = signatureText(validMask);

        if isempty(goodSigs)
            duplicateConfigRows = 0;
            signatureStatus = 'NO_COMPLETE_KEYS';

        else
            [~,~,groupID] = unique(goodSigs);
            counts = accumarray(groupID,1);
            duplicateConfigRows = sum(counts(counts > 1));
            signatureStatus = 'LOCAL_SIGNATURES_ONLY';

            % Record repeated configurations within this file.
            uniqueSigs = unique(goodSigs);

            for u = 1:numel(uniqueSigs)
                countU = sum(strcmp(goodSigs,uniqueSigs{u}));

                if countU > 1
                    duplicateRows(end+1,:) = {fileName,topology, ...
                        uniqueSigs{u},countU, ...
                        'Within-file duplicate; inspect provenance and row meaning'}; %#ok<SAGROW>
                end
            end
        end

        if any(~validMask)
            riskRows(end+1,:) = {fileName,'INCOMPLETE_KEY_ROWS', ...
                'Rows with missing key values cannot be safely grouped', ...
                'HIGH',p}; %#ok<SAGROW>
        end

    else
        riskRows(end+1,:) = {fileName,'INCOMPLETE_KEY_SCHEMA', ...
            'Canonical signature not computed because one or more keys are missing or ambiguous', ...
            'HIGH',p}; %#ok<SAGROW>
    end

    % Unit equivalence is not established by this script.
    if allMapped
        riskRows(end+1,:) = {fileName,'UNIT_AND_SCALE_REVIEW', ...
            'Confirm parameter units, scales, and normalization before cross-file matching', ...
            'MEDIUM',p}; %#ok<SAGROW>
    end

    % Tighten provisional eligibility if key schema is incomplete.
    if ~allMapped && ~strcmp(eligibility,'PROTECT') && ...
            ~strcmp(eligibility,'NOT_PRIMARY_DATA')
        eligibility = 'HOLD';
    end

    fileRows(end+1,:) = {fileName,p,topology,'READABLE',nRows,nCols, ...
        completeKeyRows,duplicateConfigRows, ...
        strjoin(canonicalKeys,';'),role,eligibility, ...
        strjoin(keyStates,';'),roleReason,signatureStatus}; %#ok<SAGROW>

end

%% D. Write outputs

FileAudit = cell2table(fileRows,'VariableNames',{ ...
    'FileName','FullPath','Topology','ReadStatus','Rows','Columns', ...
    'CompleteKeyRows','DuplicateConfigurationRows','CanonicalKeys', ...
    'ProvisionalRole','Eligibility','KeyMappingStates', ...
    'RoleReason','SignatureStatus'});

KeyMapping = cell2table(mapRows,'VariableNames',{ ...
    'FileName','Topology','CanonicalKey','CandidateAliases', ...
    'ActualColumn','MappingStatus','RequiredVerification'});

if isempty(duplicateRows)
    DuplicateAudit = cell2table(cell(0,5),'VariableNames',{ ...
        'FileName','Topology','ConfigurationSignature','RowCount','Interpretation'});
else
    DuplicateAudit = cell2table(duplicateRows,'VariableNames',{ ...
        'FileName','Topology','ConfigurationSignature','RowCount','Interpretation'});
end

if isempty(riskRows)
    RiskRegister = cell2table(cell(0,5),'VariableNames',{ ...
        'FileName','RiskCode','RequiredAction','Severity','FullPath'});
else
    RiskRegister = cell2table(riskRows,'VariableNames',{ ...
        'FileName','RiskCode','RequiredAction','Severity','FullPath'});
end

writetable(FileAudit,fullfile(outDir,'Phase6F1_FileAudit.csv'));
writetable(KeyMapping,fullfile(outDir,'Phase6F1_KeyMapping.csv'));
writetable(DuplicateAudit,fullfile(outDir,'Phase6F1_WithinFileDuplicates.csv'));
writetable(RiskRegister,fullfile(outDir,'Phase6F1_RiskRegister.csv'));

%% E. Summary

fid = fopen(fullfile(outDir,'Phase6F1_RunSummary.txt'),'w');

if fid < 0
    error('Unable to create run summary.');
end

fprintf(fid,'PHASE 6F.1 - CANONICAL KEY MAPPING\n');
fprintf(fid,'Timestamp: %s\n',stamp);
fprintf(fid,'Read-only: YES\n');
fprintf(fid,'Registered files: %d\n',height(FileAudit));
fprintf(fid,'Readable files: %d\n',sum(strcmp(FileAudit.ReadStatus,'READABLE')));
fprintf(fid,'Missing files: %d\n',sum(strcmp(FileAudit.ReadStatus,'MISSING')));
fprintf(fid,'Read errors: %d\n',sum(strcmp(FileAudit.ReadStatus,'READ_ERROR')));
fprintf(fid,'Protected entries: %d\n',sum(strcmp(FileAudit.Eligibility,'PROTECT')));
fprintf(fid,'Hold entries: %d\n',sum(strcmp(FileAudit.Eligibility,'HOLD')));
fprintf(fid,'Review-required entries: %d\n',sum(strcmp(FileAudit.Eligibility,'REVIEW_REQUIRED')));
fprintf(fid,'Derived outputs: %d\n',sum(strcmp(FileAudit.Eligibility,'NOT_PRIMARY_DATA')));
fprintf(fid,'Key mapping rows: %d\n',height(KeyMapping));
fprintf(fid,'Within-file duplicate signature groups: %d\n',height(DuplicateAudit));
fprintf(fid,'Risk register rows: %d\n',height(RiskRegister));

fprintf(fid,'\nKNOWN LINEAGE CAVEATS\n');
fprintf(fid,'BJT v3/v4 have 500 shared configurations from prior audits.\n');
fprintf(fid,'BJT v3/v4 have 20 status discrepancy records from prior audits.\n');
fprintf(fid,'MOSFET pilot/validation independence remains unresolved.\n');

fprintf(fid,'\nIMPORTANT LIMITATIONS\n');
fprintf(fid,'Alias matching is case-insensitive but does not prove physical equivalence.\n');
fprintf(fid,'Units and scales must be independently verified.\n');
fprintf(fid,'Configuration signatures are computed within files only.\n');
fprintf(fid,'Cross-file matching is not performed in this phase.\n');
fprintf(fid,'No training or train/test split was created or approved.\n');
fprintf(fid,'Source CSVs were not modified.\n');

fclose(fid);

fprintf('\nPHASE 6F.1 COMPLETE\n');
fprintf('Output folder:\n%s\n',outDir);
fprintf('\nReview these first:\n');
fprintf('  Phase6F1_RunSummary.txt\n');
fprintf('  Phase6F1_KeyMapping.csv\n');
fprintf('  Phase6F1_FileAudit.csv\n');
fprintf('  Phase6F1_RiskRegister.csv\n');

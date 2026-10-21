clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(resultsRoot, ...
    ['Phase6F2_CrossDatasetOverlap_' stamp]);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

fprintf('\nPHASE 6F.2 - CROSS-DATASET OVERLAP AUDIT\n');

%% A. Explicit registry: no ambiguous filename searches

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

%% B. Canonical key definitions

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

% Seven provisional MOSFET keys.
% Cout_F is deliberately excluded from matching until reconciled.
mosKeys = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm', ...
    'VDD_V','VGS_V','Cin_F'};

mosAliases = {
    {'RGU_Ohm','RGU_OHM'}
    {'RGL_Ohm','RGL_OHM'}
    {'RD_Ohm','RD_OHM'}
    {'RS_Ohm','RS_OHM'}
    {'VDD_V','VDD_v'}
    {'VGS_V','VGS_v'}
    {'Cin_F','CIN_F','cin_f'}
};

%% C. Read and prepare each registered file

D = struct('path',{},'name',{},'topology',{}, ...
    'status',{},'rows',{},'keys',{},'signatures',{}, ...
    'complete',{},'mappingStatus',{});

fileAudit = cell(0,8);
keyAudit = cell(0,6);

for i = 1:N

    p = paths{i};
    [~,base,ext] = fileparts(p);
    fname = [base ext];

    if contains(lower(p),[filesep 'common_source' filesep])
        topology = 'MOSFET_Common_Source';
        canonicalKeys = mosKeys;
        aliases = mosAliases;
        matchMode = 'PROVISIONAL_7_KEY';
    else
        topology = 'BJT_Common_Emitter';
        canonicalKeys = bjtKeys;
        aliases = bjtAliases;
        matchMode = '9_KEY';
    end

    D(i).path = p;
    D(i).name = fname;
    D(i).topology = topology;
    D(i).rows = NaN;
    D(i).keys = {};
    D(i).signatures = {};
    D(i).complete = false(0,1);
    D(i).mappingStatus = 'NOT_CHECKED';

    if ~isfile(p)
        D(i).status = 'MISSING';
        D(i).mappingStatus = 'FILE_MISSING';

        fileAudit(end+1,:) = {fname,topology,'MISSING',NaN, ...
            matchMode,0,'NOT_COMPUTED',p}; %#ok<SAGROW>
        continue;
    end

    try
        T = readtable(p,'VariableNamingRule','preserve');
    catch ME
        D(i).status = 'READ_ERROR';
        D(i).mappingStatus = char(ME.message);

        fileAudit(end+1,:) = {fname,topology,'READ_ERROR',NaN, ...
            matchMode,0,'NOT_COMPUTED',p}; %#ok<SAGROW>
        continue;
    end

    D(i).status = 'READABLE';
    D(i).rows = height(T);
    names = T.Properties.VariableNames;

    mapped = cell(size(canonicalKeys));
    mapComplete = true;

    for k = 1:numel(canonicalKeys)

        hits = {};

        for a = 1:numel(aliases{k})
            idx = find(strcmpi(names,aliases{k}{a}));

            for j = 1:numel(idx)
                actual = names{idx(j)};

                if ~any(strcmp(hits,actual))
                    hits{end+1} = actual; %#ok<SAGROW>
                end
            end
        end

        if numel(hits) == 1
            mapped{k} = hits{1};
            mapStatus = 'MAPPED_CANDIDATE';

        elseif isempty(hits)
            mapped{k} = '';
            mapStatus = 'MISSING_KEY';
            mapComplete = false;

        else
            mapped{k} = '';
            mapStatus = 'AMBIGUOUS_KEY';
            mapComplete = false;
        end

        keyAudit(end+1,:) = {fname,topology,canonicalKeys{k}, ...
            strjoin(aliases{k},';'),strjoin(hits,';'), ...
            mapStatus}; %#ok<SAGROW>
    end

    if ~mapComplete
        D(i).mappingStatus = 'INCOMPLETE_OR_AMBIGUOUS';
        D(i).keys = mapped;
        D(i).signatures = repmat({''},height(T),1);
        D(i).complete = false(height(T),1);

        fileAudit(end+1,:) = {fname,topology,'READABLE',height(T), ...
            matchMode,0,D(i).mappingStatus,p}; %#ok<SAGROW>
        continue;
    end

    D(i).keys = mapped;
    D(i).complete = true(height(T),1);
    keyCells = cell(height(T),numel(mapped));

    %% Construct signatures from canonical parameter order
    % Numeric values use 10 significant digits to reduce inconsequential
    % text serialization differences. This is not a physical tolerance.

    for k = 1:numel(mapped)

        x = T.(mapped{k});

        if isnumeric(x) || islogical(x)
            x = double(x(:));
            valid = isfinite(x);

            for r = 1:height(T)
                if valid(r)
                    keyCells{r,k} = sprintf('%.10g',x(r));
                else
                    keyCells{r,k} = '';
                    D(i).complete(r) = false;
                end
            end

        else
            sx = string(x(:));
            valid = ~ismissing(sx) & strlength(strtrim(sx)) > 0;

            for r = 1:height(T)
                if valid(r)
                    keyCells{r,k} = char(strtrim(sx(r)));
                else
                    keyCells{r,k} = '';
                    D(i).complete(r) = false;
                end
            end
        end
    end

    sig = repmat({''},height(T),1);

    for r = 1:height(T)
        if D(i).complete(r)
            sig{r} = strjoin(keyCells(r,:),'|');
        end
    end

    D(i).signatures = sig;
    D(i).mappingStatus = 'MAPPED';

    if any(D(i).complete)
        fileSigStatus = 'SIGNATURES_READY';
    else
        fileSigStatus = 'NO_COMPLETE_ROWS';
    end

    fileAudit(end+1,:) = {fname,topology,'READABLE',height(T), ...
        matchMode,sum(D(i).complete),fileSigStatus,p}; %#ok<SAGROW>
end

%% D. Compare every pair within the same topology

pairRows = cell(0,12);
matchRows = cell(0,8);
pairID = 0;

for i = 1:N-1
    for j = i+1:N

        if ~strcmp(D(i).topology,D(j).topology)
            continue;
        end

        pairID = pairID + 1;

        nameA = D(i).name;
        nameB = D(j).name;
        topology = D(i).topology;

        mode = '9_KEY';
        if strcmp(topology,'MOSFET_Common_Source')
            mode = 'PROVISIONAL_7_KEY';
        end

        if ~strcmp(D(i).status,'READABLE') || ...
                ~strcmp(D(j).status,'READABLE') || ...
                ~strcmp(D(i).mappingStatus,'MAPPED') || ...
                ~strcmp(D(j).mappingStatus,'MAPPED')

            pairRows(end+1,:) = {pairID,topology,nameA,nameB, ...
                mode,NaN,NaN,NaN,NaN, ...
                'NOT_COMPARABLE','MISSING_OR_AMBIGUOUS_KEYS', ...
                'Resolve schemas before interpreting overlap'}; %#ok<SAGROW>
            continue;
        end

        sigA = D(i).signatures;
        sigB = D(j).signatures;

        validA = D(i).complete & ~cellfun(@isempty,sigA);
        validB = D(j).complete & ~cellfun(@isempty,sigB);

        goodA = sigA(validA);
        goodB = sigB(validB);

        uniqueA = unique(goodA);
        uniqueB = unique(goodB);
        shared = intersect(uniqueA,uniqueB);

        sharedConfigs = numel(shared);
        matchedRowsA = 0;
        matchedRowsB = 0;
        matchedRowPairs = 0;

        for s = 1:sharedConfigs

            thisSig = shared{s};
            rowsA = find(validA & strcmp(sigA,thisSig));
            rowsB = find(validB & strcmp(sigB,thisSig));

            matchedRowsA = matchedRowsA + numel(rowsA);
            matchedRowsB = matchedRowsB + numel(rowsB);
            matchedRowPairs = matchedRowPairs + ...
                numel(rowsA)*numel(rowsB);

            for ra = 1:numel(rowsA)
                for rb = 1:numel(rowsB)
                    matchRows(end+1,:) = {pairID,topology, ...
                        nameA,rowsA(ra),nameB,rowsB(rb), ...
                        thisSig,mode}; %#ok<SAGROW>
                end
            end
        end

        if sharedConfigs > 0
            overlapStatus = 'MATCHES_FOUND';
            interpretation = 'Shared normalized configuration signatures found';
        else
            overlapStatus = 'NO_MATCHES_ON_TESTED_KEYS';
            interpretation = 'No exact normalized signatures matched; independence not established';
        end

        if strcmp(topology,'MOSFET_Common_Source')
            interpretation = [interpretation ...
                '; provisional 7-key comparison, Cout_F excluded'];
        end

        pairRows(end+1,:) = {pairID,topology,nameA,nameB,mode, ...
            numel(uniqueA),numel(uniqueB),sharedConfigs, ...
            matchedRowPairs,overlapStatus, ...
            sprintf('Rows matched: A=%d, B=%d',matchedRowsA,matchedRowsB), ...
            interpretation}; %#ok<SAGROW>
    end
end

%% E. Export tables

FileAudit = cell2table(fileAudit,'VariableNames',{ ...
    'FileName','Topology','ReadStatus','Rows','MatchMode', ...
    'CompleteKeyRows','SignatureStatus','FullPath'});

KeyAudit = cell2table(keyAudit,'VariableNames',{ ...
    'FileName','Topology','CanonicalKey','CandidateAliases', ...
    'ActualColumns','MappingStatus'});

PairSummary = cell2table(pairRows,'VariableNames',{ ...
    'PairID','Topology','FileA','FileB','MatchMode', ...
    'UniqueConfigsA','UniqueConfigsB','SharedConfigurations', ...
    'MatchedRowPairs','OverlapStatus','MatchedRowsDetail', ...
    'Interpretation'});

if isempty(matchRows)
    RowMatches = cell2table(cell(0,8),'VariableNames',{ ...
        'PairID','Topology','FileA','RowA','FileB','RowB', ...
        'ConfigurationSignature','MatchMode'});
else
    RowMatches = cell2table(matchRows,'VariableNames',{ ...
        'PairID','Topology','FileA','RowA','FileB','RowB', ...
        'ConfigurationSignature','MatchMode'});
end

writetable(FileAudit,fullfile(outDir,'Phase6F2_FileAudit.csv'));
writetable(KeyAudit,fullfile(outDir,'Phase6F2_KeyMapping.csv'));
writetable(PairSummary,fullfile(outDir,'Phase6F2_PairSummary.csv'));
writetable(RowMatches,fullfile(outDir,'Phase6F2_RowMatches.csv'));

%% F. Summary

fid = fopen(fullfile(outDir,'Phase6F2_RunSummary.txt'),'w');

if fid < 0
    error('Unable to create summary file.');
end

fprintf(fid,'PHASE 6F.2 - CROSS-DATASET CONFIGURATION OVERLAP\n');
fprintf(fid,'Timestamp: %s\n',stamp);
fprintf(fid,'Read-only: YES\n');
fprintf(fid,'Registered files: %d\n',N);
fprintf(fid,'Readable files: %d\n',sum(strcmp({D.status},'READABLE')));
fprintf(fid,'Pair comparisons recorded: %d\n',height(PairSummary));
fprintf(fid,'Pair comparisons with matches: %d\n', ...
    sum(strcmp(PairSummary.OverlapStatus,'MATCHES_FOUND')));
fprintf(fid,'Pairs not comparable: %d\n', ...
    sum(strcmp(PairSummary.OverlapStatus,'NOT_COMPARABLE')));
fprintf(fid,'Row-level matching records: %d\n',height(RowMatches));

fprintf(fid,'\nMETHOD\n');
fprintf(fid,'BJT signatures use nine mapped parameters.\n');
fprintf(fid,'MOSFET signatures provisionally use seven mapped parameters.\n');
fprintf(fid,'MOSFET Cout_F is excluded because its mapping remains unresolved.\n');
fprintf(fid,'Numeric serialization uses 10 significant digits; no physical tolerance is applied.\n');
fprintf(fid,'Cross-file units and physical equivalence are not verified by this script.\n');

fprintf(fid,'\nINTERPRETATION LIMITS\n');
fprintf(fid,'A match is evidence of a shared normalized signature on the tested keys.\n');
fprintf(fid,'A non-match does not prove dataset independence.\n');
fprintf(fid,'Missing keys or ambiguous mappings prevent a valid pair comparison.\n');
fprintf(fid,'Prior BJT v3/v4 evidence: 500 shared configurations and 20 status discrepancies.\n');
fprintf(fid,'Prior MOSFET pilot/validation zero-match finding remains unresolved.\n');
fprintf(fid,'No training, splitting, or source modification occurred.\n');

fclose(fid);

fprintf('\nPHASE 6F.2 COMPLETE\n');
fprintf('Output folder:\n%s\n',outDir);
fprintf('Pair comparisons: %d\n',height(PairSummary));
fprintf('Row matches: %d\n',height(RowMatches));

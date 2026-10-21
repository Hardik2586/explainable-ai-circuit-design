clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root, 'data');
resultsRoot = fullfile(root, 'results');

assert(isfolder(dataRoot), 'Data directory not found.');

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot, ...
    ['Phase6E2_CandidateLineageAudit_' stamp]);

if ~isfolder(resultsRoot), mkdir(resultsRoot); end
mkdir(outDir);

fprintf('\nPHASE 6E.2: CANDIDATE AND LINEAGE AUDIT\n');
fprintf('Data root: %s\n', dataRoot);
fprintf('Output: %s\n\n', outDir);

%% Discover data files only
files = dir(fullfile(dataRoot, '**', '*.csv'));

inventory = table();
pairReview = table();
keyColumnsUsed = strings(0,1);

% These are circuit configuration parameters, not response variables.
bjtKeys = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
mosKeys = {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','CIN_F','VDD_V'};

for i = 1:numel(files)
    path = fullfile(files(i).folder, files(i).name);
    rel = erase(path, [root '\']);
    low = lower(strrep(rel,'/','\'));
    name = lower(files(i).name);

    % Exclude governance outputs if any were saved under data.
    if contains(low,'phase6e') || contains(low,'phase6d') || ...
       contains(low,'phase6c') || contains(low,'registry')
        continue;
    end

    topology = "Unknown";
    if contains(low,'common_source') || contains(name,'cs_dataset') || ...
       contains(name,'phase4h_freshcircuitdataset') || ...
       contains(name,'phase5a_dc_candidates')
        topology = "MOSFET_Common_Source";
    elseif contains(name,'ce_amplifier') || contains(low,'common_emitter')
        topology = "BJT_Common_Emitter";
    end

    % Keep test/evaluation data protected regardless of other rules.
    protected = contains(low,'ce_amplifier_dataset_v2_test100') || ...
                contains(low,'phase4h_independentvalidation') || ...
                contains(low,'phase4h_freshcircuitdataset') || ...
                contains(low,'independentvalidation') || ...
                contains(low,'holdout');

    % Classify from both the path and filename.
    derived = false;
    derivedReason = "";

    derivedTokens = ["diagnostic","metric","label","bandwidth", ...
        "analysis","prediction","derived","operatingpoint", ...
        "operating_point","report","summary","ranking", ...
        "ranked","optimization","verification","progress", ...
        "failure","robustness","comparison","correlation", ...
        "sensitivity","shap","audit","evaluation"];

    searchText = lower(string(rel));

    for k = 1:numel(derivedTokens)
        if contains(searchText, derivedTokens(k))
            derived = true;
            derivedReason = "Derived/report/analysis path or filename token: " ...
                + derivedTokens(k);
            break;
        end
    end

    % Read table without changing the source file.
    readStatus = "READABLE";
    nRows = NaN;
    nCols = NaN;
    missingCells = NaN;
    columnsText = "";
    cfgKeys = strings(0,1);
    keyList = {};

    try
        T = readtable(path, 'VariableNamingRule','preserve');
        nRows = height(T);
        nCols = width(T);
        cols = string(T.Properties.VariableNames);
        columnsText = strjoin(cols, ';');

        % Count missing values in common MATLAB data types.
        missTotal = 0;
        for c = 1:width(T)
            x = T{:,c};
            if isnumeric(x)
                missTotal = missTotal + sum(isnan(x));
            elseif isstring(x)
                missTotal = missTotal + sum(ismissing(x));
            elseif iscategorical(x)
                missTotal = missTotal + sum(isundefined(x));
            elseif isdatetime(x) || isduration(x)
                missTotal = missTotal + sum(ismissing(x));
            end
        end
        missingCells = missTotal;

        % Configuration keys only for known circuit families.
        if topology == "BJT_Common_Emitter"
            keyList = bjtKeys;
        elseif topology == "MOSFET_Common_Source"
            keyList = mosKeys;
        end

        % Require all key columns to be present.
        present = ismember(string(keyList), cols);

        if ~isempty(keyList) && all(present) && height(T) > 0
            keyMatrix = strings(height(T), numel(keyList));

            for k = 1:numel(keyList)
                x = T.(keyList{k});
                if isnumeric(x)
                    % Numeric rounding avoids tiny text-format differences.
                    keyMatrix(:,k) = compose('%.10g', double(x));
                else
                    keyMatrix(:,k) = string(x);
                end
            end

            cfgKeys = join(keyMatrix, "|", 2);
        end

    catch ME
        readStatus = "READ_ERROR";
        derivedReason = string(ME.message);
    end

    if protected
        decision = "PROTECTED_EVALUATION";
        reason = "Protected evaluation/test artifact; never use as training source.";
    elseif derived
        decision = "DERIVED_OR_REVIEW";
        reason = derivedReason;
    elseif topology == "Unknown"
        decision = "TOPOLOGY_REVIEW";
        reason = "Topology not established; manual review required.";
    elseif isempty(cfgKeys)
        decision = "SOURCE_CANDIDATE_REVIEW";
        reason = "Circuit table found, but complete configuration key is unavailable.";
    else
        decision = "SOURCE_CANDIDATE_REVIEW";
        reason = "Candidate only. Configuration lineage and provenance require approval.";
    end

    row = table(string(rel), topology, string(readStatus), ...
        nRows, nCols, missingCells, decision, string(reason), ...
        columnsText, ...
        'VariableNames', {'RelativePath','Topology','ReadStatus', ...
        'Rows','Columns','MissingCells','Decision','Reason','ColumnNames'});

    inventory = [inventory; row]; %#ok<AGROW>

    % Keep readable tables and their configuration keys for pairwise audit.
    if readStatus == "READABLE" && ~isempty(cfgKeys)
        if ~exist('keyData','var') || isempty(keyData)
            keyData = struct( ...
               'path', {}, ...
               'topology', {}, ...
               'keys', {});
        end

        kIndex = numel(keyData) + 1;

        keyData(kIndex).path = string(rel);
        keyData(kIndex).topology = string(topology);
        keyData(kIndex).keys = string(cfgKeys(:));
     end
end

%% Pairwise configuration overlap
if exist('keyData','var')
    idx = 1:numel(keyData);
    for a = 1:numel(idx)
        A = keyData(idx(a));

        for b = a+1:numel(idx)
            B = keyData(idx(b));

            if ~strcmp(string(A.topology), string(B.topology)) || ...
                   strcmp(string(A.topology), "Unknown")
               continue;
            end

            shared = intersect(A.keys, B.keys);
            nShared = numel(shared);

            if nShared > 0
                note = "Configuration overlap found; review lineage before splitting.";
                if contains(lower(A.path),'test100') || ...
                   contains(lower(B.path),'test100') || ...
                   contains(lower(A.path),'phase4h') || ...
                   contains(lower(B.path),'phase4h')
                    note = "Protected evaluation file overlaps another file; do not use the protected file for training.";
                end

                pr = table(A.path, B.path, A.topology, ...
                    numel(A.keys), numel(B.keys), nShared, ...
                    nShared/max(1,min(numel(A.keys),numel(B.keys))), ...
                    note, ...
                    'VariableNames', {'FileA','FileB','Topology', ...
                    'RowsA','RowsB','SharedConfigurations', ...
                    'OverlapFractionOfSmallerFile','ReviewAction'});

                pairReview = [pairReview; pr]; %#ok<AGROW>
            end
        end
    end
end

%% Export
writetable(inventory, fullfile(outDir, ...
    'Phase6E2_DataInventory.csv'));

writetable(pairReview, fullfile(outDir, ...
    'Phase6E2_ConfigurationOverlapPairs.csv'));

if isempty(inventory)
    counts = table();
else
    groups = unique(inventory.Decision);
    n = zeros(numel(groups),1);
    for k = 1:numel(groups)
        n(k) = sum(inventory.Decision == groups(k));
    end
    counts = table(groups,n,'VariableNames',{'Decision','FileCount'});
end

writetable(counts, fullfile(outDir, ...
    'Phase6E2_DecisionSummary.csv'));

fid = fopen(fullfile(outDir,'Phase6E2_RunSummary.txt'),'w');
if fid >= 0
    fprintf(fid,'PHASE 6E.2 CANDIDATE AND LINEAGE AUDIT\n');
    fprintf(fid,'Files inventoried: %d\n',height(inventory));
    fprintf(fid,'Overlap pairs flagged: %d\n',height(pairReview));
    fprintf(fid,'No source files modified.\n');
    fprintf(fid,'No splits approved or applied.\n');
    fprintf(fid,'No model trained.\n');
    fclose(fid);
end

fprintf('\nPHASE 6E.2 COMPLETE\n');
fprintf('Files inventoried: %d\n',height(inventory));
fprintf('Configuration overlap pairs: %d\n',height(pairReview));
disp(counts);
fprintf('Output folder:\n%s\n',outDir);

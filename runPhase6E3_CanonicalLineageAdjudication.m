clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root, 'data');
resultsRoot = fullfile(root, 'results');

assert(isfolder(dataRoot), 'Data folder not found: %s', dataRoot);
if ~isfolder(resultsRoot), mkdir(resultsRoot); end

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot, ...
    ['Phase6E3_CanonicalLineage_' stamp]);
mkdir(outDir);

fprintf('\nPHASE 6E.3: CANONICAL LINEAGE ADJUDICATION\n');
fprintf('Data root: %s\nOutput: %s\n\n', dataRoot, outDir);

%% Discover files only under data/
files = dir(fullfile(dataRoot, '**', '*.csv'));

% Dataset roles are inferred conservatively.
% Files outside data/ are not considered source candidates here.

fileRecords = struct('path',{},'topology',{},'role',{}, ...
    'status',{},'rows',{},'cols',{},'keys',{}, ...
    'keyNames',{},'table',{},'reason',{});

inventory = table();
pairRows = table();
valueRows = table();

% Normalize names so "R1 (Ohm)", "R1_Ohm" and "r1" can be compared.
normalizeName = @(s) lower(regexprep(char(s),'[^a-zA-Z0-9]',''));

% Known circuit parameter aliases.
% These are aliases only; missing keys are NOT fabricated.
bjtAliases = {
    {'r1','r1ohm'}
    {'r2','r2ohm'}
    {'rc','rcohm'}
    {'re','reohm'}
    {'rl','rlohm'}
    {'cin','cinf','cinin'}
    {'cout','coutf'}
    {'ce','cef','ceuf'}
    {'vcc','vccv'}
};

mosAliases = {
    {'rd','rdohm'}
    {'rs','rsohm'}
    {'rg','rgohm'}
    {'rgu','rguohm'}
    {'rgl','rglohm'}
    {'vdd','vddv'}
    {'vgs','vgsv'}
    {'cin','cinf'}
    {'cout','coutf'}
};

% Response/output terms excluded from configuration-key discovery.
responseTokens = ["gain","vout","vin","current","power","freq", ...
    "frequency","phase","bandwidth","status","region","label", ...
    "metric","prediction","target","error","residual","score", ...
    "peak","diagnostic","pass","fail","valid","id","index"];

%% Read and classify candidate files
for i = 1:numel(files)
    path = fullfile(files(i).folder, files(i).name);
    rel = string(erase(path,[root '\']));
    low = lower(strrep(char(rel),'/','\'));
    nm = lower(files(i).name);

    topology = "Unknown";
    if contains(low,'common_source') || contains(nm,'cs_dataset') || ...
       contains(nm,'phase4h_freshcircuitdataset') || ...
       contains(nm,'phase5a_dc_candidates')
        topology = "MOSFET_Common_Source";
    elseif contains(nm,'ce_amplifier') || contains(low,'common_emitter')
        topology = "BJT_Common_Emitter";
    end

    protected = contains(low,'ce_amplifier_dataset_v2_test100') || ...
        contains(low,'phase4h_independentvalidation') || ...
        contains(low,'phase4h_freshcircuitdataset') || ...
        contains(low,'holdout') || contains(low,'independentvalidation');

    role = "SOURCE_CANDIDATE_REVIEW";
    reason = "Candidate only; provenance not established.";

    if protected
        role = "PROTECTED_EVALUATION";
        reason = "Protected evaluation artifact; do not use as training data.";
    elseif contains(low,'diagnostic') || contains(low,'analysis') || ...
           contains(low,'operatingpoint') || contains(low,'operating_point') || ...
           contains(low,'metric') || contains(low,'label') || ...
           contains(low,'report') || contains(low,'prediction') || ...
           contains(low,'derived')
        role = "DERIVED_OR_REVIEW";
        reason = "Likely derived/analysis table based on path or filename.";
    elseif topology == "Unknown"
        role = "TOPOLOGY_REVIEW";
        reason = "Topology not established.";
    end

    rec = struct('path',rel,'topology',topology,'role',role, ...
        'status',"READ_ERROR",'rows',NaN,'cols',NaN, ...
        'keys',strings(0,1),'keyNames',strings(0,1), ...
        'table',table(),'reason',reason);

    try
        T = readtable(path,'VariableNamingRule','preserve');
        rec.status = "READABLE";
        rec.rows = height(T);
        rec.cols = width(T);
        rec.table = T;

        originalNames = string(T.Properties.VariableNames);
        normalizedNames = strings(size(originalNames));
        for c = 1:numel(originalNames)
            normalizedNames(c) = string(normalizeName(originalNames(c)));
        end

        % Determine key columns only from known parameter aliases.
        aliases = {};
        if topology == "BJT_Common_Emitter"
            aliases = bjtAliases;
        elseif topology == "MOSFET_Common_Source"
            aliases = mosAliases;
        end

        selectedColumns = [];
        selectedCanonicalNames = strings(0,1);

        for a = 1:numel(aliases)
            aliasGroup = string(aliases{a});
            hit = find(ismember(normalizedNames,aliasGroup),1);

            if ~isempty(hit)
                selectedColumns(end+1) = hit; %#ok<AGROW>
                selectedCanonicalNames(end+1,1) = aliasGroup(1); %#ok<AGROW>
            end
        end

        % Require at least 3 known parameter columns before generating keys.
        % Partial keys are useful for diagnostics but are not strong proof.
        if numel(selectedColumns) >= 3 && height(T) > 0
            keyMatrix = strings(height(T),numel(selectedColumns));

            for k = 1:numel(selectedColumns)
                x = T{:,selectedColumns(k)};

                if isnumeric(x)
                    keyMatrix(:,k) = compose('%.10g',double(x));
                elseif islogical(x)
                    keyMatrix(:,k) = string(double(x));
                else
                    keyMatrix(:,k) = strtrim(string(x));
                end
            end

            rec.keys = join(keyMatrix,"|",2);
            rec.keyNames = selectedCanonicalNames;
        else
            rec.reason = rec.reason + ...
                " Insufficient recognized parameter columns for strong key comparison.";
        end

    catch ME
        rec.reason = "Read error: " + string(ME.message);
    end

    fileRecords(end+1) = rec; %#ok<SAGROW>

    inv = table(rel,topology,role,rec.status,rec.rows,rec.cols, ...
        strjoin(rec.keyNames,';'),rec.reason, ...
        'VariableNames',{'RelativePath','Topology','Role','ReadStatus', ...
        'Rows','Columns','RecognizedKeyColumns','ReviewReason'});

    inventory = [inventory; inv]; %#ok<AGROW>
end

%% Pairwise configuration comparison
for a = 1:numel(fileRecords)
    A = fileRecords(a);

    if A.status ~= "READABLE" || isempty(A.keys) || A.topology == "Unknown"
        continue;
    end

    for b = a+1:numel(fileRecords)
        B = fileRecords(b);

        if B.status ~= "READABLE" || isempty(B.keys)
            continue;
        end

        if ~strcmp(char(A.topology),char(B.topology)) || ...
                A.topology == "Unknown"
            continue;
        end

        % Only compare keys when both files use exactly the same
        % recognized canonical key columns in the same order.
        if ~isequal(A.keyNames,B.keyNames)
            continue;
        end

        keysA = A.keys;
        keysB = B.keys;

        [shared,ia,ib] = intersect(keysA,keysB,'stable');
        nShared = numel(shared);

        if nShared == 0
            continue;
        end

        overlapSmaller = nShared/max(1,min(numel(keysA),numel(keysB)));

        pairDecision = "CONFIGURATION_OVERLAP_REVIEW";
        if A.role == "PROTECTED_EVALUATION" || ...
                B.role == "PROTECTED_EVALUATION"
            pairDecision = "PROTECTED_DATA_OVERLAP_REVIEW";
        end

        pr = table(A.path,B.path,A.topology, ...
            numel(keysA),numel(keysB),nShared,overlapSmaller, ...
            strjoin(A.keyNames,';'),pairDecision, ...
            'VariableNames',{'FileA','FileB','Topology','RowsA','RowsB', ...
            'SharedConfigurations','OverlapFractionOfSmallerFile', ...
            'ComparedKeyColumns','Decision'});

        pairRows = [pairRows; pr]; %#ok<AGROW>

        %% Compare common non-key columns for shared configurations.
        TA = A.table;
        TB = B.table;

        namesA = string(TA.Properties.VariableNames);
        namesB = string(TB.Properties.VariableNames);

        normA = strings(size(namesA));
        normB = strings(size(namesB));
        for c = 1:numel(namesA), normA(c) = string(normalizeName(namesA(c))); end
        for c = 1:numel(namesB), normB(c) = string(normalizeName(namesB(c))); end

        commonNorm = intersect(normA,normB,'stable');
        keyNorm = A.keyNames;

        for c = 1:numel(commonNorm)
            cn = commonNorm(c);

            if any(keyNorm == cn)
                continue;
            end

            ca = find(normA == cn,1);
            cb = find(normB == cn,1);

            % Skip obvious identifier columns; they need not be equal
            % across separately exported tables.
            if contains(cn,"circuitid") || cn == "id" || cn == "index"
                continue;
            end

            va = TA{ia,ca};
            vb = TB{ib,cb};

            compareStatus = "NOT_COMPARABLE";
            mismatchCount = NaN;
            comparedCount = 0;

            try
                if isnumeric(va) && isnumeric(vb)
                    va = double(va(:));
                    vb = double(vb(:));

                    good = isfinite(va) & isfinite(vb);
                    comparedCount = sum(good);

                    if comparedCount > 0
                        tol = 1e-8 + 1e-6 .* max(abs(va(good)),abs(vb(good)));
                        mismatchCount = sum(abs(va(good)-vb(good)) > tol);

                        if mismatchCount == 0
                            compareStatus = "MATCH_WITHIN_TOLERANCE";
                        else
                            compareStatus = "NUMERIC_OUTPUT_MISMATCH";
                        end
                    else
                        compareStatus = "NO_COMPARABLE_NUMERIC_VALUES";
                    end

                else
                    sa = strtrim(string(va(:)));
                    sb = strtrim(string(vb(:)));
                    good = ~ismissing(sa) & ~ismissing(sb);
                    comparedCount = sum(good);

                    if comparedCount > 0
                        mismatchCount = sum(sa(good) ~= sb(good));

                        if mismatchCount == 0
                            compareStatus = "MATCH";
                        else
                            compareStatus = "VALUE_MISMATCH";
                        end
                    else
                        compareStatus = "NO_COMPARABLE_VALUES";
                    end
                end
            catch
                compareStatus = "TYPE_OR_ALIGNMENT_REVIEW";
            end

            vr = table(A.path,B.path,A.topology,cn,nShared, ...
                string(compareStatus),double(comparedCount), ...
                double(mismatchCount), ...
                'VariableNames',{'FileA','FileB','Topology', ...
                'SharedColumn','SharedConfigurations','ComparisonStatus', ...
                'ComparedValues','MismatchCount'});

            valueRows = [valueRows; vr]; %#ok<AGROW>
        end
    end
end

%% Export reports
writetable(inventory,fullfile(outDir, ...
    'Phase6E3_FileInventory.csv'));

writetable(pairRows,fullfile(outDir, ...
    'Phase6E3_ConfigurationOverlap.csv'));

writetable(valueRows,fullfile(outDir, ...
    'Phase6E3_SharedOutputComparison.csv'));

%% Summary
if isempty(pairRows)
    overlapSummary = table();
else
    [G,topos] = findgroups(pairRows.Topology);
    nPairs = splitapply(@numel,pairRows.SharedConfigurations,G);
    nWithFullSmallerOverlap = splitapply( ...
        @(x) sum(x >= 0.999999), ...
        pairRows.OverlapFractionOfSmallerFile,G);

    overlapSummary = table(topos,nPairs,nWithFullSmallerOverlap, ...
        'VariableNames',{'Topology','OverlapPairCount', ...
        'PairsCoveringSmallerFile'});
end

writetable(overlapSummary,fullfile(outDir, ...
    'Phase6E3_OverlapSummary.csv'));

fid = fopen(fullfile(outDir,'Phase6E3_RunSummary.txt'),'w');
if fid >= 0
    fprintf(fid,'PHASE 6E.3 CANONICAL LINEAGE ADJUDICATION\n');
    fprintf(fid,'Files inventoried: %d\n',height(inventory));
    fprintf(fid,'Configuration overlap pairs: %d\n',height(pairRows));
    fprintf(fid,'Shared output comparisons: %d\n',height(valueRows));
    fprintf(fid,'No source files modified.\n');
    fprintf(fid,'No canonical dataset automatically approved.\n');
    fprintf(fid,'No train/test split applied.\n');
    fprintf(fid,'No model trained.\n');
    fclose(fid);
end

fprintf('\nPHASE 6E.3 COMPLETE\n');
fprintf('Files inventoried: %d\n',height(inventory));
fprintf('Configuration overlap pairs: %d\n',height(pairRows));
fprintf('Shared output comparisons: %d\n',height(valueRows));
disp(overlapSummary);
fprintf('Output folder:\n%s\n',outDir);

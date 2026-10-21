
%% PHASE 6E.4: DISCREPANCY INVESTIGATION
% Universal Circuit-XAI
% Read-only. No training. No split approval. No source modifications.

clear; clc;

root = 'C:\Internship Project';
dataRoot = fullfile(root,'data');
resultsRoot = fullfile(root,'results');

assert(isfolder(dataRoot),'Data folder not found.');
if ~isfolder(resultsRoot), mkdir(resultsRoot); end

stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outDir = fullfile(resultsRoot,['Phase6E4_DiscrepancyInvestigation_' stamp]);
mkdir(outDir);

fprintf('\nPHASE 6E.4: DISCREPANCY INVESTIGATION\n');
fprintf('Output: %s\n\n',outDir);

%% Find the required files by filename and path
allFiles = dir(fullfile(dataRoot,'**','*.csv'));

paths = strings(numel(allFiles),1);
for i = 1:numel(allFiles)
    paths(i) = string(fullfile(allFiles(i).folder,allFiles(i).name));
end

bjtV3 = findFile(paths,'CE_Amplifier_Dataset_v3_500.csv','processed');
bjtV4 = findFile(paths,'CE_Amplifier_Dataset_v4_500_1GHz.csv','processed');

mosPilot = findFile(paths,'CS_Pilot_20261013_015305.csv','');
mosValidation = findFile(paths,'CS_Dataset_v2_100.csv','external_model_validation');

% Additional small external-model pilot datasets, if present.
mosPilot3 = findFile(paths,'CS_Dataset_v2_100.csv','external_model_pilot');
mosValidation100 = mosValidation;

%% Results accumulators
pairSummary = table();
mismatchRows = table();
keyAudit = table();

%% BJT v3 vs v4
if bjtV3 ~= "" && bjtV4 ~= ""
    fprintf('Comparing BJT v3 vs v4...\n');
    [S,M,K] = comparePair(bjtV3,bjtV4,'BJT_Common_Emitter', ...
        {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'}, ...
        {'ACStatus','SimulationStatus'});
    pairSummary = [pairSummary; S];
    mismatchRows = [mismatchRows; M];
    keyAudit = [keyAudit; K];
else
    warning('Could not uniquely locate both BJT v3/v4 files.');
end

%% MOSFET pilot vs external-model validation
if mosPilot ~= "" && mosValidation ~= ""
    fprintf('Comparing MOSFET 20-row pilot vs external validation...\n');
    [S,M,K] = comparePair(mosPilot,mosValidation, ...
        'MOSFET_Common_Source', ...
        {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V', ...
         'VGS_V','Cin_F','Cout_F'}, ...
        {'AmplifierCandidate','BiasRegion'});
    pairSummary = [pairSummary; S];
    mismatchRows = [mismatchRows; M];
    keyAudit = [keyAudit; K];
else
    warning('Could not uniquely locate the MOSFET 20-row pilot and validation files.');
end

%% Small external-model pilot vs validation
if mosPilot3 ~= "" && mosValidation100 ~= ""
    fprintf('Comparing external-model pilot vs validation...\n');
    [S,M,K] = comparePair(mosPilot3,mosValidation100, ...
        'MOSFET_Common_Source', ...
        {'RGU_Ohm','RGL_Ohm','RD_Ohm','RS_Ohm','VDD_V', ...
         'VGS_V','Cin_F','Cout_F'}, ...
        {'AmplifierCandidate','BiasRegion'});
    pairSummary = [pairSummary; S];
    mismatchRows = [mismatchRows; M];
    keyAudit = [keyAudit; K];
end

%% Export reports
writetable(pairSummary,fullfile(outDir,'Phase6E4_PairSummary.csv'));
writetable(mismatchRows,fullfile(outDir,'Phase6E4_ValueDiscrepancies.csv'));
writetable(keyAudit,fullfile(outDir,'Phase6E4_KeyAudit.csv'));

fid = fopen(fullfile(outDir,'Phase6E4_RunSummary.txt'),'w');
if fid >= 0
    fprintf(fid,'PHASE 6E.4 DISCREPANCY INVESTIGATION\n');
    fprintf(fid,'Pair comparisons completed: %d\n',height(pairSummary));
    fprintf(fid,'Value discrepancy records: %d\n',height(mismatchRows));
    fprintf(fid,'Configuration key audit rows: %d\n',height(keyAudit));
    fprintf(fid,'No source files modified.\n');
    fprintf(fid,'No training performed.\n');
    fprintf(fid,'No train/test split approved or applied.\n');
    fclose(fid);
end

fprintf('\nPHASE 6E.4 COMPLETE\n');
fprintf('Pair comparisons: %d\n',height(pairSummary));
fprintf('Discrepancy records: %d\n',height(mismatchRows));
fprintf('Key audit records: %d\n',height(keyAudit));
disp(pairSummary);
fprintf('Output folder:\n%s\n',outDir);

%% ================= LOCAL FUNCTIONS =================

function pathOut = findFile(paths,fileName,pathToken)
    pathOut = "";
    hit = find(contains(lower(paths),lower(fileName)) & ...
        contains(lower(paths),lower(pathToken)));

    if strlength(pathToken) == 0
        hit = find(contains(lower(paths),lower(fileName)));
    end

    if numel(hit) == 1
        pathOut = paths(hit);
    elseif numel(hit) > 1
        % Prefer exact filename matches, then require a unique match.
        exact = hit(arrayfun(@(j) ...
            strcmpi(getFileName(paths(j)),fileName),hit));
        if numel(exact) == 1
            pathOut = paths(exact);
        else
            warning('Ambiguous file match for %s (%d matches).',fileName,numel(hit));
        end
    end
end

function name = getFileName(path)
    [~,n,e] = fileparts(char(path));
    name = [n e];
end

function [S,M,K] = comparePair(pathA,pathB,topology,keyAliases,targetNames)
    S = table();
    M = table();
    K = table();

    A = readtable(char(pathA),'VariableNamingRule','preserve');
    B = readtable(char(pathB),'VariableNamingRule','preserve');

    namesA = string(A.Properties.VariableNames);
    namesB = string(B.Properties.VariableNames);

    normA = normalizeNames(namesA);
    normB = normalizeNames(namesB);

    keyColsA = zeros(1,numel(keyAliases));
    keyColsB = zeros(1,numel(keyAliases));
    selectedAliases = strings(0,1);

    % Map each known alias to actual columns.
    for k = 1:numel(keyAliases)
        alias = string(keyAliases{k});
        ca = find(normA == normalizeNames(alias),1);
        cb = find(normB == normalizeNames(alias),1);

        if ~isempty(ca) && ~isempty(cb)
            keyColsA(k) = ca;
            keyColsB(k) = cb;
            selectedAliases(end+1,1) = alias; %#ok<AGROW>
        end
    end

    keyColsA = keyColsA(keyColsA > 0);
    keyColsB = keyColsB(keyColsB > 0);

    if numel(keyColsA) < 3 || numel(keyColsA) ~= numel(keyColsB)
        K = table(string(pathA),string(pathB),string(topology), ...
            numel(keyColsA),string(strjoin(cellstr(selectedAliases),';')), ...
            "INSUFFICIENT_COMMON_KEYS", ...
            'VariableNames',{'FileA','FileB','Topology','KeyCount', ...
            'KeyColumns','KeyStatus'});

        S = table(string(pathA),string(pathB),string(topology), ...
            height(A),height(B),0,0,0, ...
            "NOT_COMPARED_INSUFFICIENT_KEYS", ...
            'VariableNames',{'FileA','FileB','Topology','RowsA','RowsB', ...
            'SharedConfigurations','ComparedFields','MismatchCount','Status'});
        return;
    end

    keyMatrixA = makeKeys(A,keyColsA);
    keyMatrixB = makeKeys(B,keyColsB);

    [shared,ia,ib] = intersect(keyMatrixA,keyMatrixB,'stable');
    nShared = numel(shared);

    K = table(string(pathA),string(pathB),string(topology), ...
        numel(keyColsA),string(strjoin(cellstr(selectedAliases),';')), ...
        nShared,"KEYS_MATCHED", ...
        'VariableNames',{'FileA','FileB','Topology','KeyCount', ...
        'KeyColumns','SharedConfigurations','KeyStatus'});

    commonNorm = intersect(normA,normB,'stable');
    mismatchCount = 0;
    comparedFields = 0;

    for q = 1:numel(commonNorm)
        field = commonNorm(q);

        if any(normalizeNames(selectedAliases) == field)
            continue;
        end

        % Only inspect explicitly requested fields for this investigation.
        if ~any(normalizeNames(string(targetNames)) == field)
            continue;
        end

        ca = find(normA == field,1);
        cb = find(normB == field,1);

        va = A{ia,ca};
        vb = B{ib,cb};

        comparedFields = comparedFields + 1;

        for r = 1:nShared
            [different, valueA, valueB, status] = compareValues(va(r,:),vb(r,:));

            if different
                mismatchCount = mismatchCount + 1;

                mr = table(string(pathA),string(pathB),string(topology), ...
                    shared(r),field,string(valueA),string(valueB),string(status), ...
                    'VariableNames',{'FileA','FileB','Topology', ...
                    'ConfigurationKey','Field','ValueA','ValueB','ComparisonStatus'});

                M = [M; mr]; %#ok<AGROW>
            end
        end
    end

    if nShared == 0
        status = "NO_SHARED_CONFIGURATIONS";
    elseif comparedFields == 0
        status = "NO_REQUESTED_SHARED_FIELDS";
    elseif mismatchCount == 0
        status = "NO_MISMATCHES_IN_REQUESTED_FIELDS";
    else
        status = "MISMATCHES_FOUND";
    end

    S = table(string(pathA),string(pathB),string(topology), ...
        height(A),height(B),nShared,comparedFields,mismatchCount,string(status), ...
        'VariableNames',{'FileA','FileB','Topology','RowsA','RowsB', ...
        'SharedConfigurations','ComparedFields','MismatchCount','Status'});
end

function n = normalizeNames(names)
    n = strings(size(names));
    for i = 1:numel(names)
        n(i) = lower(regexprep(char(names(i)),'[^a-zA-Z0-9]',''));
    end
end

function keys = makeKeys(T,cols)
    K = strings(height(T),numel(cols));
    for c = 1:numel(cols)
        x = T{:,cols(c)};
        if isnumeric(x)
            K(:,c) = compose('%.10g',double(x));
        elseif islogical(x)
            K(:,c) = string(double(x));
        else
            K(:,c) = strtrim(string(x));
        end
    end
    keys = join(K,"|",2);
end

function [different,a,b,status] = compareValues(a0,b0)
    different = false;
    status = "MATCH";

    if isnumeric(a0) && isnumeric(b0)
        a = double(a0);
        b = double(b0);

        if isnan(a) && isnan(b)
            status = "BOTH_MISSING";
        elseif ~isfinite(a) || ~isfinite(b)
            different = true;
            status = "MISSINGNESS_OR_NONFINITE_DIFFERENCE";
        else
            tol = 1e-8 + 1e-6 * max(abs(a),abs(b));
            different = abs(a-b) > tol;
            if different, status = "NUMERIC_MISMATCH"; end
        end
        a = string(a);
        b = string(b);
    else
        a = strtrim(string(a0));
        b = strtrim(string(b0));

        if ismissing(a) && ismissing(b)
            status = "BOTH_MISSING";
        elseif ismissing(a) || ismissing(b)
            different = true;
            status = "MISSINGNESS_DIFFERENCE";
        else
            different = a ~= b;
            if different, status = "CATEGORICAL_MISMATCH"; end
        end
    end
end

clear; clc;

root = 'C:\Internship Project';

pilotFile = fullfile(root,'data','universal','Common_Source', ...
    'pilot','CS_Pilot_20261013_015305.csv');

validationFile = fullfile(root,'data','universal','Common_Source', ...
    'external_model_validation','20261020_000113', ...
    'CS_Dataset_v2_100.csv');

bjtV3File = fullfile(root,'data','processed', ...
    'CE_Amplifier_Dataset_v3_500.csv');

bjtV4File = fullfile(root,'data','processed', ...
    'CE_Amplifier_Dataset_v4_500_1GHz.csv');

files = {pilotFile, validationFile, bjtV3File, bjtV4File};

for k = 1:numel(files)
    if ~isfile(files{k})
        error('Missing required source file:\n%s',files{k});
    end
end

stamp = datestr(now,'yyyymmdd_HHMMSS');
outDir = fullfile(root,'results', ...
    ['Phase6E5_SchemaAndStatusAudit_' stamp]);

mkdir(outDir);

%% A. Read all source files without changing them

P = readtable(pilotFile,'VariableNamingRule','preserve');
V = readtable(validationFile,'VariableNamingRule','preserve');
B3 = readtable(bjtV3File,'VariableNamingRule','preserve');
B4 = readtable(bjtV4File,'VariableNamingRule','preserve');

%% B. Export schema inventories

writetable(schemaInventory(P,'MOSFET_Pilot'), ...
    fullfile(outDir,'MOSFET_Pilot_Schema.csv'));

writetable(schemaInventory(V,'MOSFET_Validation'), ...
    fullfile(outDir,'MOSFET_Validation_Schema.csv'));

writetable(schemaInventory(B3,'BJT_v3'), ...
    fullfile(outDir,'BJT_v3_Schema.csv'));

writetable(schemaInventory(B4,'BJT_v4'), ...
    fullfile(outDir,'BJT_v4_Schema.csv'));

%% C. Export numeric range summaries

writetable(numericSummary(P,'MOSFET_Pilot'), ...
    fullfile(outDir,'MOSFET_Pilot_NumericSummary.csv'));

writetable(numericSummary(V,'MOSFET_Validation'), ...
    fullfile(outDir,'MOSFET_Validation_NumericSummary.csv'));

%% D. Compare MOSFET column names conservatively

pn = string(P.Properties.VariableNames);
vn = string(V.Properties.VariableNames);

aliasRows = cell(0,5);

for i = 1:numel(pn)
    np = normalizeName(pn(i));

    for j = 1:numel(vn)
        nv = normalizeName(vn(j));

        if np == nv
            kind = "NORMALIZED_NAME_MATCH";
        elseif strlength(np) >= 3 && strlength(nv) >= 3 && ...
                (contains(np,nv) || contains(nv,np))
            kind = "PARTIAL_NAME_REVIEW";
        else
            continue;
        end

        aliasRows(end+1,:) = {char(pn(i)),char(vn(j)), ...
            char(np),char(nv),char(kind)}; %#ok<SAGROW>
    end
end

if isempty(aliasRows)
    AliasCandidates = table();
else
    AliasCandidates = cell2table(aliasRows,'VariableNames', ...
        {'PilotColumn','ValidationColumn', ...
         'PilotNormalizedName','ValidationNormalizedName', ...
         'CandidateType'});
end

writetable(AliasCandidates, ...
    fullfile(outDir,'MOSFET_AliasCandidates.csv'));

%% E. Compare known MOSFET configuration fields

keys = ["RGU_Ohm","RGL_Ohm","RD_Ohm","RS_Ohm", ...
        "VDD_V","VGS_V","Cin_F","Cout_F"];

keyRows = cell(0,9);

for i = 1:numel(keys)
    pcol = findName(pn,keys(i));
    vcol = findName(vn,keys(i));

    if pcol ~= "" && vcol ~= ""
        a = numericColumn(P,char(pcol));
        b = numericColumn(V,char(vcol));

        keyRows(end+1,:) = {char(keys(i)),char(pcol),char(vcol), ...
            sum(isfinite(a)),sum(isfinite(b)), ...
            minFinite(a),maxFinite(a), ...
            minFinite(b),maxFinite(b)}; %#ok<SAGROW>
    else
        keyRows(end+1,:) = {char(keys(i)),char(pcol),char(vcol), ...
            NaN,NaN,NaN,NaN,NaN,NaN}; %#ok<SAGROW>
    end
end

MOSFETKeyAudit = cell2table(keyRows,'VariableNames', ...
    {'ExpectedKey','PilotColumn','ValidationColumn', ...
     'PilotFiniteN','ValidationFiniteN', ...
     'PilotMin','PilotMax','ValidationMin','ValidationMax'});

writetable(MOSFETKeyAudit, ...
    fullfile(outDir,'MOSFET_KeyAudit.csv'));

%% F. BJT v3 versus v4 status audit

bjtKeys = ["R1","R2","RC","RE","RL", ...
           "Cin","Cout","Ce","VCC"];

b3names = string(B3.Properties.VariableNames);
b4names = string(B4.Properties.VariableNames);

k3 = strings(1,numel(bjtKeys));
k4 = strings(1,numel(bjtKeys));

for i = 1:numel(bjtKeys)
    k3(i) = findName(b3names,bjtKeys(i));
    k4(i) = findName(b4names,bjtKeys(i));
end

if any(k3 == "") || any(k4 == "")
    error(['Expected BJT configuration keys are missing. ' ...
           'Inspect the exported schema files before proceeding.']);
end

sig3 = makeSignatures(B3,k3);
sig4 = makeSignatures(B4,k4);

[shared,idx3,idx4] = intersect(sig3,sig4,'stable');


statusFields = ["AC_Status","Simulation_Status"];
statusRows = cell(0,15);
affected = zeros(0,2);

for i = 1:numel(shared)
    for j = 1:numel(statusFields)

        c3 = findName(b3names,statusFields(j));
        c4 = findName(b4names,statusFields(j));

        if c3 == "" || c4 == ""
            continue;
        end

        % MATLAB-compatible indexing using temporary variables
        col3 = B3.(char(c3));
        col4 = B4.(char(c4));

        a = string(col3(idx3(i)));
        b = string(col4(idx4(i)));

        if ismissing(a), a = "<MISSING>"; end
        if ismissing(b), b = "<MISSING>"; end

        if strcmpi(strtrim(a),strtrim(b))
            continue;
        end

        keyValues = cell(1,numel(bjtKeys));

        for q = 1:numel(bjtKeys)
            keyColumn = numericColumn(B3,char(k3(q)));
            keyValues{q} = keyColumn(idx3(i));
        end

        statusRows(end+1,:) = ...
            [{i,char(statusFields(j)),char(a),char(b), ...
              idx3(i),idx4(i)},keyValues]; %#ok<SAGROW>

        affected(end+1,:) = [idx3(i),idx4(i)]; %#ok<SAGROW>
    end
end


statusHeaders = [{'MatchedPair','Field','V3Value','V4Value', ...
                  'V3Row','V4Row'},cellstr(bjtKeys)];

if isempty(statusRows)
    BJTStatusDifferences = cell2table(cell(0,15), ...
        'VariableNames',statusHeaders);
else
    BJTStatusDifferences = cell2table(statusRows, ...
        'VariableNames',statusHeaders);
end

writetable(BJTStatusDifferences, ...
    fullfile(outDir,'BJT_StatusDifferences.csv'));

%% G. Export complete original rows for affected BJT configurations

if ~isempty(affected)
    affected = unique(affected,'rows','stable');

    R3 = B3(affected(:,1),:);
    R4 = B4(affected(:,2),:);

    R3.Properties.VariableNames = cellstr( ...
        "V3_" + string(R3.Properties.VariableNames));
    R4.Properties.VariableNames = cellstr( ...
        "V4_" + string(R4.Properties.VariableNames));

    RowPairs = table(affected(:,1),affected(:,2), ...
        'VariableNames',{'V3_SourceRow','V4_SourceRow'});

    FullRows = [RowPairs R3 R4];
else
    FullRows = table();
end

writetable(FullRows, ...
    fullfile(outDir,'BJT_FullDiscrepancyRows.csv'));

%% H. Run summary

fid = fopen(fullfile(outDir,'RunSummary.txt'),'w');

fprintf(fid,'PHASE 6E.5 AUDIT\n');
fprintf(fid,'Timestamp: %s\n',stamp);
fprintf(fid,'Read-only: YES\n\n');

fprintf(fid,'MOSFET pilot rows: %d\n',height(P));
fprintf(fid,'MOSFET validation rows: %d\n',height(V));
fprintf(fid,'MOSFET pilot columns: %d\n',width(P));
fprintf(fid,'MOSFET validation columns: %d\n\n',width(V));

fprintf(fid,'MOSFET alias candidate rows: %d\n',height(AliasCandidates));
fprintf(fid,'BJT v3 rows: %d\n',height(B3));
fprintf(fid,'BJT v4 rows: %d\n',height(B4));
fprintf(fid,'BJT shared configuration signatures: %d\n',numel(shared));
fprintf(fid,'BJT status discrepancy records: %d\n',height(BJTStatusDifferences));

fprintf(fid,'\nNo source files modified.\n');
fprintf(fid,'No training performed.\n');
fprintf(fid,'No train/test split approved.\n');
fprintf(fid,'No independence inferred from zero overlap.\n');

fclose(fid);

fprintf('\nPhase 6E.5 completed.\nOutput folder:\n%s\n',outDir);

%% Local functions


function T = schemaInventory(A,label)

    names = string(A.Properties.VariableNames);
    rows = cell(numel(names),6);

    for n = 1:numel(names)

        x = A.(char(names(n)));

        if isnumeric(x) || islogical(x)

            missingCount = sum(~isfinite(double(x(:))));

            exampleValues = string(x(1:min(3,numel(x))));
            exampleValues(ismissing(exampleValues)) = "<MISSING>";
            examples = strjoin(exampleValues(:)," | ");

        else

            sx = string(x(:));

            missingCount = sum(ismissing(sx) | ...
                strlength(strtrim(sx)) == 0);

            exampleValues = sx(1:min(3,numel(sx)));
            exampleValues(ismissing(exampleValues)) = "<MISSING>";
            examples = strjoin(exampleValues(:)," | ");

        end

        % Safe conversion even when examples contain missing values
        if ismissing(examples)
            examples = "<MISSING>";
        end

        rows(n,:) = {char(string(label)), ...
            char(names(n)), ...
            class(x), ...
            height(A), ...
            missingCount, ...
            char(examples)};

    end

    T = cell2table(rows,'VariableNames', ...
        {'Dataset','ColumnName','MATLABType','RowCount', ...
         'MissingCount','FirstThreeExamples'});

end


function T = numericSummary(A,label)
    names = string(A.Properties.VariableNames);
    rows = cell(0,8);

    for n = 1:numel(names)
        x = numericColumn(A,char(names(n)));
        x = x(isfinite(x));

        if isempty(x), continue; end

        rows(end+1,:) = {label,char(names(n)),numel(x), ...
            min(x),max(x),mean(x),median(x),std(x)}; %#ok<AGROW>
    end

    T = cell2table(rows,'VariableNames', ...
        {'Dataset','ColumnName','FiniteN','Min','Max', ...
         'Mean','Median','Std'});
end

function s = normalizeName(x)
    s = lower(regexprep(string(x),'[^a-zA-Z0-9]',''));
end

function n = findName(names,target)
    ix = find(strcmpi(names,target),1);
    if isempty(ix)
        n = "";
    else
        n = names(ix);
    end
end

function x = numericColumn(T,name)
    v = T.(name);

    if isnumeric(v) || islogical(v)
        x = double(v(:));
    else
        x = str2double(string(v(:)));
    end
end

function y = minFinite(x)
    x = x(isfinite(x));
    if isempty(x), y = NaN; else, y = min(x); end
end

function y = maxFinite(x)
    x = x(isfinite(x));
    if isempty(x), y = NaN; else, y = max(x); end
end

function sig = makeSignatures(T,keyNames)
    parts = strings(height(T),numel(keyNames));

    for j = 1:numel(keyNames)
        x = numericColumn(T,char(keyNames(j)));

        for i = 1:height(T)
            if isfinite(x(i))
                parts(i,j) = string(sprintf('%.12g',x(i)));
            else
                parts(i,j) = "<MISSING>";
            end
        end
    end

    sig = join(parts,"|",2);
end

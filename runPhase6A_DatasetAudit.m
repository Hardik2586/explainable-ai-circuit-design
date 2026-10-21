
%% PHASE 6A: DATASET AUDIT
% Inventory existing CSV datasets before AI model training.
% Does not modify or overwrite previous results.

clear; clc;

projectRoot = 'C:\Internship Project';
resultsRoot = fullfile(projectRoot, 'results');

timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

outputFolder = fullfile(resultsRoot, ...
    ['Phase6A_DatasetAudit_' timestamp]);

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

fprintf('\n===== PHASE 6A: DATASET AUDIT =====\n');
fprintf('Searching: %s\n', resultsRoot);

files = dir(fullfile(resultsRoot, '**', '*.csv'));

if isempty(files)
    error('No CSV files found under the results directory.');
end

% Inventory table
FilePath = strings(0,1);
FileName = strings(0,1);
Rows = zeros(0,1);
Columns = zeros(0,1);
ReadStatus = strings(0,1);
ColumnList = strings(0,1);
CandidateCount = nan(0,1);

for k = 1:numel(files)

    path = fullfile(files(k).folder, files(k).name);

    try
        opts = detectImportOptions(path);
        opts.VariableNamingRule = 'preserve';
        T = readtable(path, opts);

        names = string(T.Properties.VariableNames);

        FilePath(end+1,1) = string(path);
        FileName(end+1,1) = string(files(k).name);
        Rows(end+1,1) = height(T);
        Columns(end+1,1) = width(T);
        ReadStatus(end+1,1) = "OK";
        ColumnList(end+1,1) = strjoin(names, " | ");

        % Count unique candidate IDs when available.
        if any(names == "CandidateID")
            ids = unique(T.CandidateID);
            CandidateCount(end+1,1) = numel(ids);
        else
            CandidateCount(end+1,1) = NaN;
        end

        fprintf('\n[%d/%d] %s\n', k, numel(files), ...
            files(k).name);
        fprintf('Rows: %d | Columns: %d\n', ...
            height(T), width(T));
        fprintf('Variables: %s\n', strjoin(names, ', '));

    catch ME
        FilePath(end+1,1) = string(path);
        FileName(end+1,1) = string(files(k).name);
        Rows(end+1,1) = NaN;
        Columns(end+1,1) = NaN;
        ReadStatus(end+1,1) = "READ_ERROR";
        ColumnList(end+1,1) = string(ME.message);
        CandidateCount(end+1,1) = NaN;


        fprintf('\nCould not read %s\n%s\n', ...
            files(k).name, ME.message);
    end
end

Inventory = table(FileName, FilePath, Rows, Columns, ...
    CandidateCount, ReadStatus, ColumnList);

inventoryPath = fullfile(outputFolder, ...
    'Phase6A_CSV_Inventory.csv');

writetable(Inventory, inventoryPath);

%% Identify likely circuit datasets
allNames = lower(ColumnList);

hasResistance = contains(allNames, 'rd_ohm') | ...
    contains(allNames, 'rg_ohm') | ...
    contains(allNames, 'rs_ohm');

hasGain = contains(allNames, 'gain');
hasCandidate = contains(allNames, 'candidateid');

LikelyCircuitData = Inventory( ...
    ReadStatus == "OK" & hasResistance & hasGain, :);

writetable(LikelyCircuitData, fullfile(outputFolder, ...
    'Phase6A_LikelyCircuitDatasets.csv'));

fprintf('\n===== AUDIT SUMMARY =====\n');
fprintf('CSV files found: %d\n', numel(files));
fprintf('Successfully read: %d\n', sum(ReadStatus == "OK"));
fprintf('Read errors: %d\n', sum(ReadStatus ~= "OK"));
fprintf('Likely circuit datasets: %d\n', ...
    height(LikelyCircuitData));

fprintf('\n===== LIKELY CIRCUIT DATASETS =====\n');

if isempty(LikelyCircuitData)
    fprintf(['No dataset matched the initial column-name filter. ' ...
        'Review the full inventory.\n']);
else
    disp(LikelyCircuitData(:, ...
        {'FileName','Rows','Columns','CandidateCount'}));
end

fprintf('\nInventory saved to:\n%s\n', inventoryPath);
fprintf('Audit folder:\n%s\n', outputFolder);

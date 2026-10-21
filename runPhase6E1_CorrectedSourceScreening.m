clear; clc;

%% Configuration
projectRoot = 'C:\Internship Project';
resultsRoot = fullfile(projectRoot, 'results');

if ~isfolder(projectRoot)
    error('Project root not found: %s', projectRoot);
end

if ~isfolder(resultsRoot)
    mkdir(resultsRoot);
end

timestamp = char(datetime('now', ...
    'Format', 'yyyyMMdd_HHmmss'));

outputDir = fullfile(resultsRoot, ...
    ['Phase6E1_CorrectedSourceScreening_' timestamp]);

mkdir(outputDir);

fprintf('\n====================================================\n');
fprintf(' PHASE 6E.1: CORRECTED SOURCE DATASET SCREENING\n');
fprintf('====================================================\n');
fprintf('Project root: %s\n', projectRoot);
fprintf('Output folder: %s\n\n', outputDir);

%% Find CSV files
allFiles = dir(fullfile(projectRoot, '**', '*.csv'));

% Exclude files inside this run's output folder.
keep = true(numel(allFiles), 1);

for i = 1:numel(allFiles)
    fullName = fullfile(allFiles(i).folder, allFiles(i).name);

    if startsWith(lower(fullName), lower(outputDir))
        keep(i) = false;
    end
end

allFiles = allFiles(keep);

nFiles = numel(allFiles);

fprintf('CSV files discovered: %d\n', nFiles);

%% Output accumulators
inventory = table();
schemaInventory = table();
candidateShortlist = table();
lineageReview = table();

readableCount = 0;
readErrorCount = 0;

%% Filename and path classification tokens
protectedTokens = {
    'test100'
    'test_set'
    'holdout'
    'phase4h'
    'independentvalidation'
    'independent_validation'
    'protected_eval'
    'protected_evaluation'
    'evaluation_set'
};

derivedTokens = {
    'diagnostic'
    'diagnostics'
    'metric'
    'metrics'
    'label'
    'labels'
    'bandwidth'
    'analysis'
    'prediction'
    'predictions'
    'derived'
    'operatingpoint'
    'operating_point'
    'report'
    'summary'
    'registry'
    'shortlist'
    'schema_inventory'
    'screeningsummary'
    'screening_summary'
    'governance'
    'audit'
    'crossdataset'
    'lineage'
    'failureanalysis'
    'failure_analysis'
    'robustness'
    'validation'
};

%% Scan files
for i = 1:nFiles

    fileName = allFiles(i).name;
    folderName = allFiles(i).folder;
    fullPath = fullfile(folderName, fileName);

    relativePath = strrep(fullPath, [projectRoot '\'], '');
    lowerName = lower(fileName);
    lowerPath = lower(relativePath);

    fprintf('[%d/%d] %s\n', i, nFiles, relativePath);

    topology = 'Unknown';

    if contains(lowerPath, 'common_source') || ...
            contains(lowerName, 'cs_') || ...
            contains(lowerName, 'mosfet')
        topology = 'MOSFET_Common_Source';

    elseif contains(lowerPath, 'common_emitter') || ...
            contains(lowerName, 'ce_amplifier') || ...
            contains(lowerName, 'bjt')
        topology = 'BJT_Common_Emitter';
    end

    % Default values in case the file cannot be read.
    status = 'READ_ERROR';
    nRows = NaN;
    nCols = NaN;
    missingCells = NaN;
    missingFraction = NaN;
    classification = 'UNRESOLVED_REVIEW';
    reason = 'File could not be read; manual review required.';
    candidateTarget = '';
    columnNamesText = '';
    missingByColumnText = '';

    try
        opts = detectImportOptions(fullPath);
        T = readtable(fullPath, opts);

        nRows = height(T);
        nCols = width(T);
        status = 'READABLE';
        readableCount = readableCount + 1;

        if nRows == 0 || nCols == 0
            missingCells = NaN;
            missingFraction = NaN;
        else
            missingPerColumn = zeros(1, nCols);

            for c = 1:nCols
                v = T{:, c};

                if iscell(v)
                    miss = cellfun(@(x) ...
                        isempty(x) || ...
                        (isstring(x) && ismissing(x)) || ...
                        (ischar(x) && isempty(strtrim(x))), v);

                elseif isstring(v)
                    miss = ismissing(v);

                elseif isnumeric(v)
                    miss = isnan(v);

                elseif iscategorical(v)
                    miss = isundefined(v);

                elseif isdatetime(v) || isduration(v)
                    miss = ismissing(v);

                else
                    miss = false(height(T), 1);
                end

                missingPerColumn(c) = sum(miss);
            end

            missingCells = sum(missingPerColumn);
            totalCells = nRows * nCols;
            missingFraction = missingCells / totalCells;

            columnNames = T.Properties.VariableNames;
            columnNamesText = strjoin(columnNames, ';');

            missingDescriptions = strings(1, nCols);

            for c = 1:nCols
                missingDescriptions(c) = sprintf('%s=%d', ...
                    columnNames{c}, missingPerColumn(c));

                schemaRow = table( ...
                    string(relativePath), ...
                    string(topology), ...
                    string(columnNames{c}), ...
                    double(c), ...
                    double(missingPerColumn(c)), ...
                    double(nRows), ...
                    'VariableNames', { ...
                    'RelativePath', 'Topology', 'ColumnName', ...
                    'ColumnIndex', 'MissingCount', 'RowCount'});

                schemaInventory = [schemaInventory; schemaRow]; %#ok<AGROW>
            end

            missingByColumnText = strjoin(missingDescriptions, ';');
        end

        %% Corrected classification
        % Priority 1: protect known evaluation/test artifacts.
        isProtected = false;

        for k = 1:numel(protectedTokens)
            if contains(lowerPath, protectedTokens{k})
                isProtected = true;
                break;
            end
        end

        % Explicit protected BJT test set.
        if contains(lowerName, 'ce_amplifier_dataset_v2_test100')
            isProtected = true;
        end

        % Priority 2: derived tables are not source candidates.
        isDerived = false;
        matchedDerivedToken = '';

        for k = 1:numel(derivedTokens)
            if contains(lowerName, derivedTokens{k})
                isDerived = true;
                matchedDerivedToken = derivedTokens{k};
                break;
            end
        end

        % Phase 4H is a historical independent evaluation artifact.
        if contains(lowerPath, 'phase4h') || ...
                contains(lowerPath, 'independentvalidation')
            isProtected = true;
        end

        % Specific, known BJT candidate: review only, never auto-approve.
        isKnownBjtCandidate = ...
            strcmpi(fileName, 'CE_Amplifier_ML_Valid.csv');

        % Recognize the known source-candidate name explicitly.
        % Its name contains "valid", which is not itself proof of leakage
        % or proof that the file is an independent evaluation dataset.
        if isProtected
            classification = 'PROTECTED_EVALUATION';
            reason = 'Protected test/evaluation artifact; exclude from source selection and split assignment.';

        elseif isDerived
            classification = 'LIKELY_DERIVED_REVIEW';
            reason = ['Derived/report/analysis filename token: ' ...
                matchedDerivedToken '. Not a source candidate without lineage review.'];

        elseif isKnownBjtCandidate
            classification = 'SOURCE_CANDIDATE_REVIEW';
            reason = ['Known BJT candidate for manual review. ' ...
                'Not canonically approved; confirm generation provenance and target definition.'];
            candidateTarget = 'Gain_dB';

        elseif nRows < 50
            classification = 'INSUFFICIENT_ROWS_REVIEW';
            reason = 'Fewer than 50 rows; likely pilot or incomplete dataset.';

        elseif missingFraction > 0.20
            classification = 'MISSING_DATA_REVIEW';
            reason = 'More than 20 percent of table cells are missing; investigate column-level missingness.';

        elseif strcmp(topology, 'Unknown')
            classification = 'TOPOLOGY_REVIEW';
            reason = 'Topology is unknown; identify circuit family before considering canonical use.';

        else
            % Do not label a file as a source solely because it is complete.
            classification = 'SOURCE_CANDIDATE_REVIEW';
            reason = ['Heuristic candidate only. Review circuit configuration ' ...
                'keys, data-generation method, targets, and overlap before approval.'];
        end

    catch ME
        readErrorCount = readErrorCount + 1;
        reason = ['Read failure: ' ME.message];
    end

    %% Inventory row
    invRow = table( ...
        string(relativePath), ...
        string(topology), ...
        string(status), ...
        double(nRows), ...
        double(nCols), ...
        double(missingCells), ...
        double(missingFraction), ...
        string(classification), ...
        string(reason), ...
        string(candidateTarget), ...
        string(columnNamesText), ...
        string(missingByColumnText), ...
        'VariableNames', { ...
        'RelativePath', 'Topology', 'ReadStatus', 'Rows', 'Columns', ...
        'MissingCells', 'MissingFraction', 'Classification', ...
        'ClassificationReason', 'PotentialTarget', 'ColumnNames', ...
        'MissingByColumn'});

    inventory = [inventory; invRow]; %#ok<AGROW>

    %% Candidate shortlist
    if strcmp(classification, 'SOURCE_CANDIDATE_REVIEW')
        candidateShortlist = [candidateShortlist; invRow]; %#ok<AGROW>
    end

    %% Lineage/overlap review for data tables
    if strcmp(status, 'READABLE') && nRows > 0 && nCols > 0
        if contains(lowerName, 'ce_amplifier') || ...
                contains(lowerName, 'common_source') || ...
                contains(lowerName, 'cs_dataset') || ...
                contains(lowerName, 'phase5a') || ...
                contains(lowerName, 'phase4h')

            reviewReason = ['Manual lineage review required. Compare configuration ' ...
                'keys, source parameters, generation scripts, and target columns. ' ...
                'No split or approval is performed by this script.'];

            lr = table( ...
                string(relativePath), ...
                string(topology), ...
                double(nRows), ...
                double(nCols), ...
                string(classification), ...
                string(reviewReason), ...
                'VariableNames', { ...
                'RelativePath', 'Topology', 'Rows', 'Columns', ...
                'Classification', 'RequiredReview'});

            lineageReview = [lineageReview; lr]; %#ok<AGROW>
        end
    end
end

%% Export reports
writetable(inventory, fullfile(outputDir, ...
    'Phase6E1_FullDatasetInventory.csv'));

writetable(schemaInventory, fullfile(outputDir, ...
    'Phase6E1_ColumnMissingnessInventory.csv'));

writetable(candidateShortlist, fullfile(outputDir, ...
    'Phase6E1_CorrectedCandidateShortlist.csv'));

writetable(lineageReview, fullfile(outputDir, ...
    'Phase6E1_LineageReview.csv'));

%% Classification counts
if isempty(inventory)
    summary = table();
else
    classNames = unique(inventory.Classification);
    counts = zeros(numel(classNames), 1);

    for k = 1:numel(classNames)
        counts(k) = sum(inventory.Classification == classNames(k));
    end

    summary = table(classNames, counts, ...
        'VariableNames', {'Classification', 'FileCount'});
end

writetable(summary, fullfile(outputDir, ...
    'Phase6E1_ClassificationSummary.csv'));

%% Known relationships from earlier governance phases
% These are review flags based on prior audit findings, not fresh proof
% that every overlapping row is a leakage event.
knownPair = {
    'data\final\CE_Amplifier_ML_Valid.csv', ...
    'data\final\CE_Amplifier_OperatingPoint_660.csv', ...
    'BJT; prior audit reported 660/660 configuration overlap';

    'CE_Amplifier_Dataset_v3_500.csv', ...
    'CE_Amplifier_Dataset_v4_500_1GHz.csv', ...
    'BJT; prior audit reported 500/500 configuration overlap';

    'CE_Amplifier_ML_Valid.csv', ...
    'CE_Amplifier_Dataset_v5_2000_1GHz.csv', ...
    'BJT; prior audit reported 660 shared configurations';

    'CE_Amplifier_OperatingPoint_660.csv', ...
    'CE_Amplifier_Dataset_v5_2000_1GHz.csv', ...
    'BJT; prior audit reported 660 shared configurations';

    'Phase5A_DC_Candidates.csv', ...
    'Phase5A/derived operating-region table', ...
    'MOSFET; earlier audit indicated 205 configurations are a subset of 1215'
};

if ~isempty(knownPair)
    knownPairTable = cell2table(knownPair, ...
        'VariableNames', {'FileA', 'FileB', 'PriorAuditNote'});

    knownPairTable.Action = repmat( ...
        "REVIEW_ONLY_NO_SPLIT_APPROVED", height(knownPairTable), 1);

    writetable(knownPairTable, fullfile(outputDir, ...
        'Phase6E1_KnownLineageRisks.csv'));
end

%% Write run summary
summaryFile = fullfile(outputDir, 'Phase6E1_RunSummary.txt');
fid = fopen(summaryFile, 'w');

if fid ~= -1
    fprintf(fid, 'PHASE 6E.1 CORRECTED SOURCE SCREENING\n');
    fprintf(fid, 'Timestamp: %s\n', timestamp);
    fprintf(fid, 'Project root: %s\n', projectRoot);
    fprintf(fid, 'Files discovered: %d\n', nFiles);
    fprintf(fid, 'Readable files: %d\n', readableCount);
    fprintf(fid, 'Read errors: %d\n', readErrorCount);
    fprintf(fid, 'Candidate rows for review: %d\n', ...
        height(candidateShortlist));
    fprintf(fid, 'Schema inventory rows: %d\n', ...
        height(schemaInventory));
    fprintf(fid, 'Lineage review rows: %d\n', ...
        height(lineageReview));
    fprintf(fid, '\nNo source files were modified.\n');
    fprintf(fid, 'No train/test split was applied or approved.\n');
    fprintf(fid, 'No model was trained.\n');
    fprintf(fid, 'All source candidate classifications require manual review.\n');
    fclose(fid);
end

%% Console summary
fprintf('\n====================================================\n');
fprintf(' PHASE 6E.1 COMPLETE\n');
fprintf('====================================================\n');
fprintf('Files discovered: %d\n', nFiles);
fprintf('Readable: %d\n', readableCount);
fprintf('Read errors: %d\n', readErrorCount);
fprintf('Candidate rows for review: %d\n', ...
    height(candidateShortlist));
fprintf('Column inventory rows: %d\n', ...
    height(schemaInventory));
fprintf('Lineage review rows: %d\n', ...
    height(lineageReview));

fprintf('\nClassification summary:\n');
disp(summary);

fprintf('Output folder:\n%s\n', outputDir);

fprintf('\nIMPORTANT:\n');
fprintf('- Candidate status is not approval.\n');
fprintf('- No data split or training was performed.\n');
fprintf('- Inspect the generated reports before Phase 6E.2.\n');

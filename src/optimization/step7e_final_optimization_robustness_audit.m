%% STEP 7E - FINAL OPTIMIZATION + ROBUSTNESS AUDIT
%
% Final integration audit for:
%   - DL optimization
%   - SPICE optimization verification
%   - XAI -> optimization analysis
%   - XAI -> physical interaction validation
%   - robustness SPICE simulations
%   - robustness statistical analysis
%
% IMPORTANT:
% No new SPICE simulations are performed.

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7E - FINAL OPTIMIZATION + ROBUSTNESS AUDIT\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

optDir = fullfile( ...
    projectRoot,'results','optimization');

spiceVerificationFile = fullfile( ...
    optDir, ...
    'spice_verification', ...
    'SPICE_Optimization_Verification.mat');

xaiOptimizationFile = fullfile( ...
    optDir, ...
    'XAI_Optimization_Analysis.mat');

physicalValidationFile = fullfile( ...
    optDir, ...
    'XAI_R1_R2_Physical_Validation.mat');

robustnessDir = fullfile( ...
    optDir, ...
    'robustness');

robustnessResultFile = fullfile( ...
    robustnessDir, ...
    'Robustness_SPICE_Results.mat');

robustnessAnalysisFile = fullfile( ...
    robustnessDir, ...
    'Robustness_Analysis_Results.mat');

robustnessCSV = fullfile( ...
    robustnessDir, ...
    'Robustness_Final_Analysis.csv');

%% ============================================================
% AUDIT INITIALIZATION
% ============================================================

checkName = {};
checkStatus = {};
checkDetails = {};

%% ============================================================
% CHECK 1 - DL OPTIMIZATION RESULTS
% ============================================================

optimizationFile = fullfile( ...
    optDir, ...
    'DL_fmincon_Optimization_Results.mat');

if isfile(optimizationFile)

    O = load(optimizationFile);

    if isfield(O,'optimizationResults')

        OR = O.optimizationResults;

        requiredCases = {'Low','Medium','High'};

        casesPresent = all(isfield(OR,requiredCases));

        if casesPresent

            checkName{end+1,1} = 'DL optimization results';
            checkStatus{end+1,1} = 'PASS';
            checkDetails{end+1,1} = ...
                'Low/Medium/High optimization results present.';

        else

            checkName{end+1,1} = 'DL optimization results';
            checkStatus{end+1,1} = 'FAIL';
            checkDetails{end+1,1} = ...
                'One or more optimization cases missing.';

        end

    else

        checkName{end+1,1} = 'DL optimization results';
        checkStatus{end+1,1} = 'FAIL';
        checkDetails{end+1,1} = ...
            'optimizationResults variable missing.';

    end

else

    checkName{end+1,1} = 'DL optimization results';
    checkStatus{end+1,1} = 'FAIL';
    checkDetails{end+1,1} = ...
        'Optimization result file missing.';

end

%% ============================================================
% CHECK 2 - SPICE OPTIMIZATION VERIFICATION
% ============================================================

if isfile(spiceVerificationFile)

    S = load(spiceVerificationFile);

    if isfield(S,'spiceResults')

        spiceResults = S.spiceResults;

        requiredCases = {'Low','Medium','High'};

        casesPresent = all( ...
            isfield(spiceResults,requiredCases));

        if casesPresent

            checkName{end+1,1} = ...
                'SPICE optimization verification';

            checkStatus{end+1,1} = 'PASS';

            checkDetails{end+1,1} = ...
                'Low/Medium/High SPICE verification results present.';

        else

            checkName{end+1,1} = ...
                'SPICE optimization verification';

            checkStatus{end+1,1} = 'FAIL';

            checkDetails{end+1,1} = ...
                'One or more SPICE verification cases missing.';

        end

    else

        checkName{end+1,1} = ...
            'SPICE optimization verification';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'spiceResults variable missing.';

    end

else

    checkName{end+1,1} = ...
        'SPICE optimization verification';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'SPICE optimization verification file missing.';

end

%% ============================================================
% CHECK 3 - XAI -> OPTIMIZATION
% ============================================================

if isfile(xaiOptimizationFile)

    X = load(xaiOptimizationFile);

    if ~isempty(fieldnames(X))

        checkName{end+1,1} = ...
            'XAI to optimization analysis';

        checkStatus{end+1,1} = 'PASS';

        checkDetails{end+1,1} = ...
            'XAI optimization analysis file present.';

    else

        checkName{end+1,1} = ...
            'XAI to optimization analysis';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'XAI optimization file is empty.';

    end

else

    checkName{end+1,1} = ...
        'XAI to optimization analysis';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'XAI optimization analysis file missing.';

end

%% ============================================================
% CHECK 4 - XAI -> PHYSICAL VALIDATION
% ============================================================

if isfile(physicalValidationFile)

    P = load(physicalValidationFile);

    if ~isempty(fieldnames(P))

        checkName{end+1,1} = ...
            'XAI physical interaction validation';

        checkStatus{end+1,1} = 'PASS';

        checkDetails{end+1,1} = ...
            'R1-R2 SPICE physical validation present.';

    else

        checkName{end+1,1} = ...
            'XAI physical interaction validation';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'Physical validation file is empty.';

    end

else

    checkName{end+1,1} = ...
        'XAI physical interaction validation';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Physical validation file missing.';

end

%% ============================================================
% CHECK 5 - ROBUSTNESS SPICE RESULTS
% ============================================================

if isfile(robustnessResultFile)

    R = load(robustnessResultFile);

    if isfield(R,'robustness')

        checkName{end+1,1} = ...
            'Robustness SPICE results';

        checkStatus{end+1,1} = 'PASS';

        checkDetails{end+1,1} = ...
            'Robustness simulation results present.';

    else

        checkName{end+1,1} = ...
            'Robustness SPICE results';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'robustness variable missing.';

    end

else

    checkName{end+1,1} = ...
        'Robustness SPICE results';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness SPICE result file missing.';

end

%% ============================================================
% CHECK 6 - ROBUSTNESS ANALYSIS
% ============================================================

if isfile(robustnessAnalysisFile)

    A = load(robustnessAnalysisFile);

    if isfield(A,'analysis') && isfield(A,'finalTable')

        checkName{end+1,1} = ...
            'Robustness statistical analysis';

        checkStatus{end+1,1} = 'PASS';

        checkDetails{end+1,1} = ...
            'Final robustness analysis present.';

    else

        checkName{end+1,1} = ...
            'Robustness statistical analysis';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'Required robustness analysis variables missing.';

    end

else

    checkName{end+1,1} = ...
        'Robustness statistical analysis';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness analysis file missing.';

end

%% ============================================================
% CHECK 7 - ROBUSTNESS CSV
% ============================================================

if isfile(robustnessCSV)

    T = readtable(robustnessCSV);

    if height(T) == 3

        checkName{end+1,1} = ...
            'Robustness final CSV';

        checkStatus{end+1,1} = 'PASS';

        checkDetails{end+1,1} = ...
            'Three circuit-level robustness records present.';

    else

        checkName{end+1,1} = ...
            'Robustness final CSV';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            sprintf('Expected 3 rows, found %d.',height(T));

    end

else

    checkName{end+1,1} = ...
        'Robustness final CSV';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Final robustness CSV missing.';

end

%% ============================================================
% CHECK 8 - EXACT 300 ROBUSTNESS RUNS
% ============================================================

if isfile(robustnessResultFile)

    R = load(robustnessResultFile);

    if isfield(R,'robustness')

        cases = {'Low','Medium','High'};

        totalRuns = 0;
        totalSuccess = 0;
        totalValid = 0;
        totalInvalid = 0;

        for k = 1:numel(cases)

            C = R.robustness.(cases{k});

            totalRuns = ...
                totalRuns + numel(C.success);

            totalSuccess = ...
                totalSuccess + sum(logical(C.success));

            totalValid = ...
                totalValid + sum(logical(C.valid));

            totalInvalid = ...
                totalInvalid + ...
                sum(logical(C.success) & ...
                ~logical(C.valid));

        end

        if totalRuns == 300 && ...
           totalSuccess == 300 && ...
           totalValid == 300 && ...
           totalInvalid == 0

            checkName{end+1,1} = ...
                '300-run robustness validation';

            checkStatus{end+1,1} = 'PASS';

            checkDetails{end+1,1} = ...
                '300/300 successful and physically valid.';

        else

            checkName{end+1,1} = ...
                '300-run robustness validation';

            checkStatus{end+1,1} = 'FAIL';

            checkDetails{end+1,1} = sprintf( ...
                'Runs=%d, success=%d, valid=%d, invalid=%d.', ...
                totalRuns, ...
                totalSuccess, ...
                totalValid, ...
                totalInvalid);

        end

    else

        checkName{end+1,1} = ...
            '300-run robustness validation';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'robustness variable missing.';

    end

else

    checkName{end+1,1} = ...
        '300-run robustness validation';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness result file missing.';

end

%% ============================================================
% CHECK 9 - ROBUSTNESS METRIC CONSISTENCY
% ============================================================

if isfile(robustnessAnalysisFile)

    A = load(robustnessAnalysisFile);

    if isfield(A,'finalTable')

        T = A.finalTable;

        requiredColumns = { ...
            'NominalGain_dB', ...
            'MeanGain_dB', ...
            'StdGain_dB', ...
            'MinGain_dB', ...
            'MaxGain_dB', ...
            'CoefficientVariation_percent', ...
            'ValidityPercent'};

        allColumnsPresent = all( ...
            ismember( ...
            requiredColumns, ...
            T.Properties.VariableNames));

        if allColumnsPresent

            calculatedCV = ...
                100*T.StdGain_dB ./ T.MeanGain_dB;

            cvError = max( ...
                abs(calculatedCV - ...
                T.CoefficientVariation_percent));

            rangesValid = ...
                all(T.MinGain_dB <= T.MeanGain_dB) && ...
                all(T.MeanGain_dB <= T.MaxGain_dB);

            if cvError < 1e-10 && rangesValid

                checkName{end+1,1} = ...
                    'Robustness metric consistency';

                checkStatus{end+1,1} = 'PASS';

                checkDetails{end+1,1} = ...
                    'CV and gain ranges internally consistent.';

            else

                checkName{end+1,1} = ...
                    'Robustness metric consistency';

                checkStatus{end+1,1} = 'FAIL';

                checkDetails{end+1,1} = ...
                    'One or more robustness metrics inconsistent.';

            end

        else

            checkName{end+1,1} = ...
                'Robustness metric consistency';

            checkStatus{end+1,1} = 'FAIL';

            checkDetails{end+1,1} = ...
                'Required robustness columns missing.';

        end

    else

        checkName{end+1,1} = ...
            'Robustness metric consistency';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'finalTable missing.';

    end

else

    checkName{end+1,1} = ...
        'Robustness metric consistency';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness analysis file missing.';

end

%% ============================================================
% CHECK 10 - ROBUSTNESS RANKING
% ============================================================

if isfile(robustnessAnalysisFile)

    A = load(robustnessAnalysisFile);

    if isfield(A,'finalTable')

        T = A.finalTable;

        [~,expectedRankOrder] = ...
            sort(T.StdGain_dB,'ascend');

        expectedRank = zeros(height(T),1);

        for k = 1:height(T)

            expectedRank(expectedRankOrder(k)) = k;

        end

        if isequal(expectedRank,T.RobustnessRank)

            checkName{end+1,1} = ...
                'Robustness ranking';

            checkStatus{end+1,1} = 'PASS';

            checkDetails{end+1,1} = ...
                'Ranking correctly follows gain standard deviation.';

        else

            checkName{end+1,1} = ...
                'Robustness ranking';

            checkStatus{end+1,1} = 'FAIL';

            checkDetails{end+1,1} = ...
                'Stored ranking does not match gain variability.';

        end

    else

        checkName{end+1,1} = ...
            'Robustness ranking';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'Robustness table unavailable.';

    end

else

    checkName{end+1,1} = ...
        'Robustness ranking';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness analysis unavailable.';

end

%% ============================================================
% CHECK 11 - BEST ROBUSTNESS
% ============================================================

if isfile(robustnessAnalysisFile)

    A = load(robustnessAnalysisFile);

    if isfield(A,'finalTable')

        T = A.finalTable;

        [~,bestIdx] = min(T.StdGain_dB);

        bestCircuit = string(T.Circuit(bestIdx));

        if bestCircuit == "Medium"

            checkName{end+1,1} = ...
                'Medium-gain robustness result';

            checkStatus{end+1,1} = 'PASS';

            checkDetails{end+1,1} = ...
                'Medium-gain circuit has lowest gain standard deviation.';

        else

            checkName{end+1,1} = ...
                'Medium-gain robustness result';

            checkStatus{end+1,1} = 'WARN';

            checkDetails{end+1,1} = sprintf( ...
                '%s has the lowest gain standard deviation.', ...
                bestCircuit);

        end

    else

        checkName{end+1,1} = ...
            'Medium-gain robustness result';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'Robustness table unavailable.';

    end

else

    checkName{end+1,1} = ...
        'Medium-gain robustness result';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness analysis unavailable.';

end

%% ============================================================
% CHECK 12 - PHYSICAL VALIDITY
% ============================================================

if isfile(robustnessAnalysisFile)

    A = load(robustnessAnalysisFile);

    if isfield(A,'finalTable')

        T = A.finalTable;

        if all(T.ValidityPercent == 100)

            checkName{end+1,1} = ...
                'Physical validity under tolerance';

            checkStatus{end+1,1} = 'PASS';

            checkDetails{end+1,1} = ...
                'All three optimized circuits retained 100%% validity.';

        else

            checkName{end+1,1} = ...
                'Physical validity under tolerance';

            checkStatus{end+1,1} = 'WARN';

            checkDetails{end+1,1} = ...
                'At least one circuit has less than 100%% validity.';

        end

    else

        checkName{end+1,1} = ...
            'Physical validity under tolerance';

        checkStatus{end+1,1} = 'FAIL';

        checkDetails{end+1,1} = ...
            'Robustness table unavailable.';

    end

else

    checkName{end+1,1} = ...
        'Physical validity under tolerance';

    checkStatus{end+1,1} = 'FAIL';

    checkDetails{end+1,1} = ...
        'Robustness analysis unavailable.';

end

%% ============================================================
% CHECK 13 - PREVIOUS FINAL PROJECT AUDIT
% ============================================================

finalResultsFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'final', ...
    'PROJECT_FINAL_RESULTS.mat');

if isfile(finalResultsFile)

    checkName{end+1,1} = ...
        'Previous final project audit';

    checkStatus{end+1,1} = 'PASS';

    checkDetails{end+1,1} = ...
        'PROJECT_FINAL_RESULTS.mat exists.';

else

    checkName{end+1,1} = ...
        'Previous final project audit';

    checkStatus{end+1,1} = 'WARN';

    checkDetails{end+1,1} = ...
        'Previous final project audit file not found.';

end

%% ============================================================
% BUILD AUDIT TABLE
% ============================================================

auditTable = table( ...
    string(checkName), ...
    string(checkStatus), ...
    string(checkDetails), ...
    'VariableNames', ...
    {'Check','Status','Details'});

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7E AUDIT RESULTS\n');
fprintf('============================================================\n');

disp(auditTable);

%% ============================================================
% SUMMARY
% ============================================================

nPass = sum(auditTable.Status == "PASS");
nFail = sum(auditTable.Status == "FAIL");
nWarn = sum(auditTable.Status == "WARN");

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FINAL AUDIT SUMMARY\n');
fprintf('============================================================\n');

fprintf('Total checks : %d\n',height(auditTable));
fprintf('PASS         : %d\n',nPass);
fprintf('WARN         : %d\n',nWarn);
fprintf('FAIL         : %d\n',nFail);

%% ============================================================
% SAVE AUDIT
% ============================================================

finalDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'final');

if ~isfolder(finalDir)

    mkdir(finalDir);

end

auditMAT = fullfile( ...
    finalDir, ...
    'STEP7E_Final_Optimization_Robustness_Audit.mat');

auditCSV = fullfile( ...
    finalDir, ...
    'STEP7E_Final_Optimization_Robustness_Audit.csv');

save( ...
    auditMAT, ...
    'auditTable', ...
    'nPass', ...
    'nWarn', ...
    'nFail');

writetable( ...
    auditTable, ...
    auditCSV);

fprintf('\nAudit saved to:\n%s\n',auditMAT);
fprintf('CSV saved to:\n%s\n',auditCSV);

%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 7E FINAL STATUS\n');
fprintf('============================================================\n');

if nFail == 0

    fprintf('[PASS] No audit failures detected.\n');

    if nWarn == 0

        fprintf('[PASS] No warnings detected.\n');
        fprintf('[PASS] Optimization + robustness pipeline fully validated.\n');

    else

        fprintf('[WARN] %d warning(s) require review.\n',nWarn);

    end

else

    fprintf('[FAIL] %d audit failure(s) detected.\n',nFail);
    fprintf('Review the audit table before finalizing the project.\n');

end

fprintf('\n');
fprintf('No new SPICE simulations were performed.\n');
fprintf('Step 7E only integrates and validates existing results.\n');
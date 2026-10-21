%% STEP 8B - GENERATE SPICE OPERATING-POINT DATASET
%
% Purpose:
%   Extract SPICE-derived DC operating-point quantities for the
%   existing 660 physically valid CE amplifier circuits.
%
% IMPORTANT:
%   - No new circuit parameters are generated.
%   - The canonical 660-row dataset is not modified.
%   - Existing runSpice.m is used as the SPICE engine.
%
% Output:
%   CE_Amplifier_OperatingPoint_660.csv
%   CE_Amplifier_OperatingPoint_660.mat
%
% Extracted quantities:
%   VB, VE, VC, IB, IC, IE, VCE, VCB
%
% VCB is calculated as:
%   VCB = VC - VB

clear;
clc;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8B - SPICE OPERATING-POINT DATASET GENERATION\n');
fprintf('============================================================\n');

%% ============================================================
% PATHS
% ============================================================

projectRoot = 'C:\Internship Project';

datasetFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

runSpiceFile = fullfile( ...
    projectRoot, ...
    'src', ...
    'spice', ...
    'runSpice.m');

outputDir = fullfile( ...
    projectRoot, ...
    'data', ...
    'processed');

outputCSV = fullfile( ...
    outputDir, ...
    'CE_Amplifier_OperatingPoint_660.csv');

outputMAT = fullfile( ...
    outputDir, ...
    'CE_Amplifier_OperatingPoint_660.mat');

%% ============================================================
% CHECK INPUTS
% ============================================================

if ~isfile(datasetFile)

    error( ...
        'Canonical dataset not found:\n%s', ...
        datasetFile);

end

if ~isfile(runSpiceFile)

    error( ...
        'runSpice.m not found:\n%s', ...
        runSpiceFile);

end

if ~isfolder(outputDir)

    mkdir(outputDir);

end

fprintf('[PASS] Canonical dataset found.\n');
fprintf('[PASS] runSpice.m found.\n');

%% ============================================================
% LOAD CANONICAL DATASET
% ============================================================

T = readtable(datasetFile);

featureNames = { ...
    'R1','R2','RC','RE','RL', ...
    'Cin','Cout','Ce','VCC'};

targetName = 'Gain_dB';

requiredColumns = [featureNames,{targetName}];

missingColumns = setdiff( ...
    requiredColumns, ...
    T.Properties.VariableNames);

if ~isempty(missingColumns)

    error( ...
        'Missing required columns: %s', ...
        strjoin(missingColumns,', '));

end

fprintf('[PASS] Dataset loaded.\n');
fprintf('Rows found: %d\n',height(T));

if height(T) ~= 660

    error( ...
        'Expected exactly 660 rows, found %d.', ...
        height(T));

end

fprintf('[PASS] Exactly 660 canonical circuits confirmed.\n');

%% ============================================================
% SPICE CONFIGURATION
% ============================================================

spiceOptions = struct();

spiceOptions.ngspice_exe = ...
    'C:\ngspice-47_64\bin\ngspice_con.exe';

% Keep the same model path used by runSpice.
% If your runSpice.m already has a default model path,
% leaving this field empty allows that default to be used.

spiceOptions.cleanup = true;

%% ============================================================
% VERIFY NGSPICE
% ============================================================

if ~isfile(spiceOptions.ngspice_exe)

    error( ...
        'ngspice executable not found:\n%s', ...
        spiceOptions.ngspice_exe);

end

fprintf('[PASS] ngspice executable found.\n');

%% ============================================================
% PREALLOCATE RESULTS
% ============================================================

N = height(T);

R1 = T.R1;
R2 = T.R2;
RC = T.RC;
RE = T.RE;
RL = T.RL;

Cin = T.Cin;
Cout = T.Cout;
Ce = T.Ce;

VCC = T.VCC;

Gain_dB = T.Gain_dB;

VB = NaN(N,1);
VE = NaN(N,1);
VC = NaN(N,1);

IB = NaN(N,1);
IC = NaN(N,1);
IE = NaN(N,1);

VCE = NaN(N,1);
VCB = NaN(N,1);

Success = false(N,1);
PhysicalValid = false(N,1);

ExitCode = NaN(N,1);

ErrorMessage = strings(N,1);

%% ============================================================
% TEMPORARY WORK ROOT
% ============================================================

workRoot = fullfile( ...
    tempdir, ...
    'CE_OperatingPoint_660');

if isfolder(workRoot)

    try
        rmdir(workRoot,'s');
    catch
        warning( ...
            'Could not completely remove previous work directory.');
    end

end

mkdir(workRoot);

fprintf('\n');
fprintf('Temporary SPICE directory:\n%s\n',workRoot);

%% ============================================================
% RUN SPICE
% ============================================================

fprintf('\n');
fprintf('Starting 660 SPICE operating-point extractions...\n');
fprintf('This may take several minutes.\n\n');

tic;

for i = 1:N

    %% --------------------------------------------------------
    % Parameter structure
    % --------------------------------------------------------

    params = struct();

    params.R1 = R1(i);
    params.R2 = R2(i);
    params.RC = RC(i);
    params.RE = RE(i);
    params.RL = RL(i);

    params.Cin = Cin(i);
    params.Cout = Cout(i);
    params.Ce = Ce(i);

    params.VCC = VCC(i);

    %% --------------------------------------------------------
    % Unique work directory
    % --------------------------------------------------------

    circuitWorkDir = fullfile( ...
        workRoot, ...
        sprintf('run_%04d',i));

    if ~isfolder(circuitWorkDir)

        mkdir(circuitWorkDir);

    end

    %% --------------------------------------------------------
    % Run ngspice
    % --------------------------------------------------------

    try

        result = runSpice( ...
            params, ...
            circuitWorkDir, ...
            spiceOptions);

        %% ----------------------------------------------------
        % Basic execution status
        % ----------------------------------------------------

        Success(i) = logical(result.success);

        if isfield(result,'exit_code')

            ExitCode(i) = result.exit_code;

        end

        if isfield(result,'error_msg')

            ErrorMessage(i) = string(result.error_msg);

        end

        %% ----------------------------------------------------
        % Extract operating point
        % ----------------------------------------------------

        if Success(i)

            VB(i) = result.VB;
            VE(i) = result.VE;
            VC(i) = result.VC;

            IB(i) = result.IB;
            IC(i) = result.IC;
            IE(i) = result.IE;

            VCE(i) = result.VCE;

            % Collector-base voltage:
            %
            % VCB = VC - VB
            %
            VCB(i) = VC(i) - VB(i);

        end

        %% ----------------------------------------------------
        % Physical validity
        % ----------------------------------------------------
        %
        % IMPORTANT:
        % This is intentionally based on the actual SPICE
        % operating point, not the approximate analytical model.
        %
        % We use:
        %   VBE = VB - VE
        %   VCB > 0
        %   VCE > 0.2 V
        %   IB > 0
        %   IC > 0
        %
        % This is consistent with the project's existing
        % practical operating-region screening.

        if Success(i)

            VBE_actual = VB(i) - VE(i);

            PhysicalValid(i) = ...
                isfinite(VB(i)) && ...
                isfinite(VE(i)) && ...
                isfinite(VC(i)) && ...
                isfinite(IB(i)) && ...
                isfinite(IC(i)) && ...
                isfinite(IE(i)) && ...
                isfinite(VCE(i)) && ...
                isfinite(VCB(i)) && ...
                (IB(i) > 0) && ...
                (IC(i) > 0) && ...
                (VBE_actual >= 0.55) && ...
                (VBE_actual <= 0.90) && ...
                (VCE(i) > 0.2) && ...
                (VCB(i) > 0);

        end

    catch ME

        Success(i) = false;

        ErrorMessage(i) = ...
            string(ME.message);

    end

    %% --------------------------------------------------------
    % Progress
    % --------------------------------------------------------

    if mod(i,25) == 0 || i == 1 || i == N

        elapsed = toc;

        fprintf( ...
            'Progress: %3d / %3d | Success: %3d | Valid: %3d | Elapsed: %.1f s\n', ...
            i, ...
            N, ...
            sum(Success(1:i)), ...
            sum(PhysicalValid(1:i)), ...
            elapsed);

    end

end

elapsedTime = toc;

%% ============================================================
% BUILD OUTPUT TABLE
% ============================================================

OperatingPointTable = table( ...
    R1, ...
    R2, ...
    RC, ...
    RE, ...
    RL, ...
    Cin, ...
    Cout, ...
    Ce, ...
    VCC, ...
    Gain_dB, ...
    VB, ...
    VE, ...
    VC, ...
    IB, ...
    IC, ...
    IE, ...
    VCE, ...
    VCB, ...
    Success, ...
    PhysicalValid, ...
    ExitCode, ...
    ErrorMessage);

%% ============================================================
% SUMMARY
% ============================================================

nSuccess = sum(Success);
nFailure = N - nSuccess;

nValid = sum(PhysicalValid);
nInvalid = nSuccess - nValid;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8B SUMMARY\n');
fprintf('============================================================\n');

fprintf('Expected circuits       : %d\n',N);
fprintf('Successful SPICE runs   : %d\n',nSuccess);
fprintf('Failed SPICE runs       : %d\n',nFailure);
fprintf('Physically valid        : %d\n',nValid);
fprintf('Physically invalid      : %d\n',nInvalid);
fprintf('Success rate            : %.2f %%\n', ...
    100*nSuccess/N);

if nSuccess > 0

    fprintf('Physical validity rate  : %.2f %% of successful runs\n', ...
        100*nValid/nSuccess);

end

fprintf('Runtime                 : %.2f minutes\n', ...
    elapsedTime/60);

%% ============================================================
% CHECK AGAINST EXPECTED 660
% ============================================================

if nSuccess == 660

    fprintf('\n[PASS] All 660 SPICE simulations succeeded.\n');

else

    fprintf('\n[WARN] %d SPICE simulations failed.\n', ...
        nFailure);

end

if nValid == 660

    fprintf('[PASS] All 660 operating points are physically valid.\n');

else

    fprintf('[WARN] %d operating points failed physical validity screening.\n', ...
        nInvalid);

end

%% ============================================================
% DISPLAY OPERATING-POINT RANGES
% ============================================================

validIdx = PhysicalValid;

if any(validIdx)

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' SPICE OPERATING-POINT RANGES\n');
    fprintf('============================================================\n');

    fprintf('\nVB:\n');
    fprintf('  Min = %.6f V\n',min(VB(validIdx)));
    fprintf('  Median = %.6f V\n',median(VB(validIdx)));
    fprintf('  Max = %.6f V\n',max(VB(validIdx)));

    fprintf('\nVE:\n');
    fprintf('  Min = %.6f V\n',min(VE(validIdx)));
    fprintf('  Median = %.6f V\n',median(VE(validIdx)));
    fprintf('  Max = %.6f V\n',max(VE(validIdx)));

    fprintf('\nVC:\n');
    fprintf('  Min = %.6f V\n',min(VC(validIdx)));
    fprintf('  Median = %.6f V\n',median(VC(validIdx)));
    fprintf('  Max = %.6f V\n',max(VC(validIdx)));

    fprintf('\nIC:\n');
    fprintf('  Min = %.6e A\n',min(IC(validIdx)));
    fprintf('  Median = %.6e A\n',median(IC(validIdx)));
    fprintf('  Max = %.6e A\n',max(IC(validIdx)));

    fprintf('\nVCE:\n');
    fprintf('  Min = %.6f V\n',min(VCE(validIdx)));
    fprintf('  Median = %.6f V\n',median(VCE(validIdx)));
    fprintf('  Max = %.6f V\n',max(VCE(validIdx)));

    fprintf('\nVCB:\n');
    fprintf('  Min = %.6f V\n',min(VCB(validIdx)));
    fprintf('  Median = %.6f V\n',median(VCB(validIdx)));
    fprintf('  Max = %.6f V\n',max(VCB(validIdx)));

end

%% ============================================================
% SAVE CSV
% ============================================================

writetable( ...
    OperatingPointTable, ...
    outputCSV);

fprintf('\nCSV saved to:\n%s\n',outputCSV);

%% ============================================================
% SAVE MAT
% ============================================================

save( ...
    outputMAT, ...
    'OperatingPointTable', ...
    'spiceOptions', ...
    'featureNames', ...
    'targetName', ...
    'N', ...
    'nSuccess', ...
    'nFailure', ...
    'nValid', ...
    'nInvalid', ...
    'elapsedTime');

fprintf('MAT saved to:\n%s\n',outputMAT);

%% ============================================================
% FINAL STATUS
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 8B FINAL STATUS\n');
fprintf('============================================================\n');

if nSuccess == 660 && nValid == 660

    fprintf('[PASS] Step 8B completed successfully.\n');
    fprintf('[PASS] 660/660 SPICE operating points extracted.\n');
    fprintf('[PASS] 660/660 operating points physically valid.\n');

else

    fprintf('[WARN] Step 8B completed with exceptions.\n');
    fprintf('Review the summary before proceeding.\n');

end

fprintf('\n');
fprintf('No changes were made to the canonical ML dataset.\n');
fprintf('This step only adds SPICE operating-point information.\n');
function optimizationResults = optimizeCEAmplifier()
% ============================================================
% STEP 3B
% CE AMPLIFIER OPTIMIZATION USING DL SURROGATE + FMINCON
%
% Objective:
%   Maximize predicted Gain_dB
%
% Since fmincon minimizes:
%   objective = -predicted Gain_dB
%
% Physical validation with SPICE is performed separately.
%
% ============================================================

clc;

fprintf('============================================================\n');
fprintf(' STEP 3B: CE AMPLIFIER DL-SURROGATE OPTIMIZATION\n');
fprintf('============================================================\n\n');


%% ------------------------------------------------------------
% Paths
% ------------------------------------------------------------

setupFile = ...
    'C:\Internship Project\results\optimization\Optimization_Setup.mat';

predictionSetupFile = ...
    'C:\Internship Project\results\optimization\DL_Optimization_Prediction_Setup.mat';

outputDir = ...
    'C:\Internship Project\results\optimization';


%% ------------------------------------------------------------
% Load setup
% ------------------------------------------------------------

fprintf('Loading optimization setup...\n');

S = load(setupFile);

optimizationSetup = S.optimizationSetup;

fprintf('Dataset size: %d x %d\n', ...
    size(optimizationSetup.X,1), ...
    size(optimizationSetup.X,2));


%% ------------------------------------------------------------
% Load DL prediction setup
% ------------------------------------------------------------

fprintf('Loading DL prediction setup...\n');

P = load(predictionSetupFile);

net   = P.net;
mu    = P.mu;
sigma = P.sigma;


%% ------------------------------------------------------------
% Verify network
% ------------------------------------------------------------

fprintf('Network class: %s\n', class(net));

if ~isa(net,'dlnetwork')
    error('Loaded network is not a dlnetwork.');
end


%% ------------------------------------------------------------
% Feature names
% ------------------------------------------------------------

featureNames = optimizationSetup.featureNames;

fprintf('\nFeatures:\n');

for k = 1:numel(featureNames)
    fprintf('  %d. %s\n',k,featureNames{k});
end


%% ------------------------------------------------------------
% Bounds
% ------------------------------------------------------------

LB = optimizationSetup.LB;
UB = optimizationSetup.UB;


%% ------------------------------------------------------------
% Prediction function
% ------------------------------------------------------------

predictGain = @(x) predictDLGain(x,net,mu,sigma);


%% ------------------------------------------------------------
% Objective function
% ------------------------------------------------------------

objective = @(x) -predictGain(x);


%% ------------------------------------------------------------
% fmincon options
% ------------------------------------------------------------

options = optimoptions('fmincon', ...
    'Algorithm','sqp', ...
    'Display','iter', ...
    'MaxIterations',200, ...
    'MaxFunctionEvaluations',5000, ...
    'OptimalityTolerance',1e-6, ...
    'StepTolerance',1e-8, ...
    'ConstraintTolerance',1e-6);


%% ------------------------------------------------------------
% Baseline circuits
% ------------------------------------------------------------

baselineNames = {'Low','Medium','High'};


%% ------------------------------------------------------------
% Results structure
% ------------------------------------------------------------

optimizationResults = struct();


%% ------------------------------------------------------------
% Optimize each baseline
% ------------------------------------------------------------

for k = 1:numel(baselineNames)

    name = baselineNames{k};

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' OPTIMIZING %s-GAIN BASELINE\n',upper(name));
    fprintf('============================================================\n');


    %% Baseline

    x0 = optimizationSetup.baseline.(name).x;

    baselineActual = optimizationSetup.baseline.(name).gainSPICE;


    baselinePredicted = predictGain(x0);


    fprintf('\nBaseline:\n');
    fprintf('  Actual SPICE Gain      : %.6f dB\n',baselineActual);
    fprintf('  DL predicted Gain      : %.6f dB\n',baselinePredicted);


    %% Check bounds

    if any(x0 < LB) || any(x0 > UB)

        warning('%s baseline is outside optimization bounds.',name);

    end


    %% Check analytical constraints

    [c0,ceq0] = circuitConstraints(x0);


    if any(c0 > 0) || any(abs(ceq0) > 1e-8)

        warning('%s baseline violates optimization constraints.',name);

    else

        fprintf('  Baseline constraints    : FEASIBLE\n');

    end


    %% Run fmincon

    fprintf('\nStarting fmincon...\n');

    [xOpt,fval,exitflag,output] = fmincon( ...
        objective, ...
        x0, ...
        [],[],[],[], ...
        LB, ...
        UB, ...
        @circuitConstraints, ...
        options);


    %% Predicted optimized gain

    predictedOptGain = predictGain(xOpt);


    %% Constraint check

    [cOpt,ceqOpt] = circuitConstraints(xOpt);

    feasibleOpt = ...
        all(cOpt <= 1e-8) && ...
        all(abs(ceqOpt) <= 1e-8);


    %% Improvement

    predictedImprovement = ...
        predictedOptGain - baselinePredicted;


    %% Store

    optimizationResults.(name).x0 = x0;

    optimizationResults.(name).xOpt = xOpt;

    optimizationResults.(name).baselineActualGain = ...
        baselineActual;

    optimizationResults.(name).baselinePredictedGain = ...
        baselinePredicted;

    optimizationResults.(name).predictedOptimizedGain = ...
        predictedOptGain;

    optimizationResults.(name).predictedImprovement = ...
        predictedImprovement;

    optimizationResults.(name).exitflag = ...
        exitflag;

    optimizationResults.(name).output = ...
        output;

    optimizationResults.(name).constraintValues = ...
        cOpt;

    optimizationResults.(name).feasible = ...
        feasibleOpt;


    %% Print result

    fprintf('\n------------------------------------------------------------\n');
    fprintf('%s OPTIMIZATION RESULT\n',upper(name));
    fprintf('------------------------------------------------------------\n');

    fprintf('Baseline DL prediction : %.6f dB\n', ...
        baselinePredicted);

    fprintf('Optimized DL prediction: %.6f dB\n', ...
        predictedOptGain);

    fprintf('Predicted improvement  : %.6f dB\n', ...
        predictedImprovement);

    fprintf('Exit flag              : %d\n', ...
        exitflag);

    fprintf('Constraints feasible   : %d\n', ...
        feasibleOpt);

    fprintf('\nOptimized parameters:\n');

    for j = 1:numel(featureNames)

        fprintf('  %-6s = %.10g\n', ...
            featureNames{j}, ...
            xOpt(j));

    end

end


%% ------------------------------------------------------------
% Save
% ------------------------------------------------------------

outputFile = ...
    fullfile(outputDir,'DL_fmincon_Optimization_Results.mat');

save(outputFile,'optimizationResults','-v7.3');


fprintf('\n');
fprintf('============================================================\n');
fprintf(' OPTIMIZATION COMPLETE\n');
fprintf('============================================================\n');

fprintf('\nSaved results:\n%s\n',outputFile);

end


%% ============================================================
% DL PREDICTION FUNCTION
% ============================================================

function y = predictDLGain(x,net,mu,sigma)

    x = double(x);

    % Ensure row vector
    if size(x,1) ~= 1
        x = x(:)';
    end

    % Log-transform first 8 physical parameters
    x(:,1:8) = log10(x(:,1:8));

    % Apply training normalization
    x = (x - mu) ./ sigma;

    % Network prediction
    y = predict(net,single(x));

    y = double(y);

    y = y(1);

end
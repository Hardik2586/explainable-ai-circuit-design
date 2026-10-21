clear; clc; close all;

projectRoot = 'C:\Internship Project';

modelFile = fullfile(projectRoot, 'models', 'Common_Source', ...
    '20261013_022802', 'CommonSourceModel.mat');

dataFile = fullfile(projectRoot, 'data', 'universal', ...
    'Common_Source', 'v2_100', '20261013_020826', ...
    'CS_Dataset_v2_100.csv');

assert(isfile(modelFile), 'Model not found: %s', modelFile);
assert(isfile(dataFile), 'Dataset not found: %s', dataFile);

S = load(modelFile);
T = readtable(dataFile, 'VariableNamingRule', 'preserve');

model = S.selectedModel;
features = S.featureColumns;
targetName = S.targetColumn;
modelName = string(S.modelInfo.SelectedModelName);

Xall = T{:, cellstr(features)};
Yall = T{:, targetName};

%% 1. Keep valid simulated observations
valid = all(isfinite(Xall), 2) & isfinite(Yall);

names = lower(regexprep(T.Properties.VariableNames, ...
    '[^a-zA-Z0-9]', ''));

flagIdx = find(strcmp(names, 'simulationvalid'), 1);
if ~isempty(flagIdx)
    flag = T{:, flagIdx};
    if islogical(flag) || isnumeric(flag)
        valid = valid & flag ~= 0;
    else
        valid = valid & strcmpi(string(flag), "true");
    end
end

X = Xall(valid, :);
Y = Yall(valid);

if size(X, 2) ~= 6
    error('Expected six input features; found %d.', size(X, 2));
end

%% 2. Prediction function
% The saved model may be boosted trees or standardized ridge regression.
predictFcn = @(Z) predictSavedModel(model, modelName, Z, S);

%% 3. Select two representative circuits
% Choose the lowest and highest model-predicted gains among valid rows.
allPredictions = predictFcn(X);

[~, lowIdx] = min(allPredictions);
[~, highIdx] = max(allPredictions);

explainIndices = unique([lowIdx, highIdx], 'stable');
nFeatures = size(X, 2);
nBackground = size(X, 1);

% Exact Shapley computation requires 2^M coalitions.
nCoalitions = 2^nFeatures;
coalitionValues = zeros(nCoalitions, 1);

% Shapley weights: |S|! (M-|S|-1)! / M!
factorialM = factorial(nFeatures);

%% 4. Explain each selected circuit
allExplanationRows = table();

for caseNumber = 1:numel(explainIndices)

    rowIdx = explainIndices(caseNumber);
    x = X(rowIdx, :);
    actualGain = Y(rowIdx);
    predictedGain = predictFcn(x);

    fprintf('\n========================================\n');
    fprintf('Circuit row: %d\n', rowIdx);
    fprintf('Observed ngspice gain: %.4f dB\n', actualGain);
    fprintf('Predicted model gain:  %.4f dB\n', predictedGain);

    % Coalition value v(S):
    % Keep features in S fixed to this circuit and average predictions
    % over the background rows for all other features.
    for mask = 0:(nCoalitions - 1)

        Xcoal = X;

        for j = 1:nFeatures
            if bitget(mask, j)
                Xcoal(:, j) = x(j);
            end
        end

        predictions = predictFcn(Xcoal);
        coalitionValues(mask + 1) = mean(predictions);
    end

    % Compute exact Shapley values by enumerating every subset.
    phi = zeros(1, nFeatures);

    for j = 1:nFeatures
        for mask = 0:(nCoalitions - 1)

            % Only subsets that do not contain feature j.
            if bitget(mask, j)
                continue;
            end

            subsetSize = sum(bitget(mask, 1:nFeatures));
            weight = factorial(subsetSize) * ...
                factorial(nFeatures - subsetSize - 1) / factorialM;

            largerMask = bitset(mask, j, 1);

            vWithout = coalitionValues(mask + 1);
            vWith = coalitionValues(largerMask + 1);

            phi(j) = phi(j) + weight * (vWith - vWithout);
        end
    end

    baseline = coalitionValues(1);
    reconstructedPrediction = baseline + sum(phi);

    fprintf('Background baseline:    %.4f dB\n', baseline);
    fprintf('Baseline + contributions: %.4f dB\n', ...
        reconstructedPrediction);
    fprintf('Reconstruction residual:  %.8f dB\n', ...
        predictedGain - reconstructedPrediction);

    % Save this circuit's local attribution table.
    caseLabel = repmat("CircuitRow_" + rowIdx, nFeatures, 1);

    caseTable = table( ...
        caseLabel, features(:), x(:), phi(:), ...
        'VariableNames', ...
        {'Circuit', 'Feature', 'FeatureValue', 'ShapleyContribution_dB'});

    caseTable = sortrows(caseTable, ...
        'ShapleyContribution_dB', 'descend');

    disp('Local feature contributions:');
    disp(caseTable);

    allExplanationRows = [allExplanationRows; caseTable];

    %% 5. Plot positive and negative contributions
    fig = figure('Name', ...
        sprintf('Local explanation - row %d', rowIdx));

    [~, order] = sort(phi);
    barh(phi(order));
    hold on;
    xline(0, '--k');

    labels = features(order);
    yticks(1:nFeatures);
    yticklabels(labels);
    xlabel('Shapley contribution to predicted gain (dB)');
    title(sprintf('Row %d | Predicted %.2f dB | Actual %.2f dB', ...
        rowIdx, predictedGain, actualGain));
    grid on;

    %% 6. Save plot and prediction summary
    outputRoot = fullfile(projectRoot, 'results', ...
        'XAI', 'Common_Source', 'Local_SHAP');

    if ~exist(outputRoot, 'dir')
        mkdir(outputRoot);
    end

    timestamp = char(datetime('now', ...
        'Format', 'yyyyMMdd_HHmmss'));

    runFolder = fullfile(outputRoot, timestamp);
    if ~exist(runFolder, 'dir')
        mkdir(runFolder);
    end

    exportgraphics(fig, fullfile(runFolder, ...
        sprintf('local_explanation_row_%d.png', rowIdx)), ...
        'Resolution', 150);

    summary = table(rowIdx, actualGain, predictedGain, baseline, ...
        predictedGain - reconstructedPrediction, ...
        'VariableNames', {'DatasetRow', 'ActualGain_dB', ...
        'PredictedGain_dB', 'Baseline_dB', 'ReconstructionResidual_dB'});

    writetable(summary, fullfile(runFolder, ...
        sprintf('prediction_summary_row_%d.csv', rowIdx)));

    writetable(caseTable, fullfile(runFolder, ...
        sprintf('local_contributions_row_%d.csv', rowIdx)));
end

%% 7. Save combined explanation table
writetable(allExplanationRows, ...
    fullfile(runFolder, 'all_local_contributions.csv'));

save(fullfile(runFolder, 'LocalShapleyResults.mat'), ...
    'allExplanationRows', 'features', 'targetName', 'modelName');

fprintf('\nLocal explanation analysis complete.\n');
fprintf('Results saved to:\n%s\n', runFolder);

%% Helper function
function y = predictSavedModel(model, modelName, X, S)
    if modelName == "RidgeLinear"
        X = (X - S.muX) ./ S.sigmaX;
    end
    y = predict(model, X);
end

%% prepare_dl_data.m
% Prepare CE amplifier dataset for Deep Learning
% Project: Explainable AI Framework for Electronic Circuit Understanding
% and Design Optimization

clear;
clc;
close all;

fprintf('=============================================\n');
fprintf('   CE AMPLIFIER - DL DATA PREPARATION\n');
fprintf('=============================================\n\n');


%% Project paths

scriptDir = fileparts(mfilename('fullpath'));

projectRoot = fileparts(fileparts(scriptDir));

dataFile = fullfile( ...
    projectRoot, ...
    'data', ...
    'final', ...
    'CE_Amplifier_ML_Valid.csv');

outputDir = fullfile( ...
    projectRoot, ...
    'results', ...
    'deep_learning');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fprintf('Project root:\n%s\n\n', projectRoot);
fprintf('Dataset:\n%s\n\n', dataFile);


%% Check dataset

if ~isfile(dataFile)
    error('Dataset not found:\n%s', dataFile);
end

fprintf('Dataset found successfully.\n\n');


%% Load dataset

data = readtable(dataFile);

fprintf('Dataset loaded successfully.\n');
fprintf('Number of rows    : %d\n', height(data));
fprintf('Number of columns : %d\n\n', width(data));


%% Display dataset variables

disp('Dataset variables:');
disp(data.Properties.VariableNames');


%% Define input features and target

featureNames = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};

targetName = 'Gain_dB';


%% Check required columns

requiredColumns = [featureNames, {targetName}];

for i = 1:numel(requiredColumns)

    if ~ismember(requiredColumns{i}, data.Properties.VariableNames)

        error('Required column "%s" was not found in the dataset.', ...
            requiredColumns{i});

    end

end

fprintf('All required columns are present.\n\n');


%% Extract input and target data

X_raw = data{:, featureNames};
Y = data{:, targetName};

fprintf('Input matrix size : %d x %d\n', ...
    size(X_raw,1), size(X_raw,2));

fprintf('Target size       : %d x %d\n\n', ...
    size(Y,1), size(Y,2));


%% Data quality check

if any(isnan(X_raw), 'all')
    error('Input dataset contains NaN values.');
end

if any(isinf(X_raw), 'all')
    error('Input dataset contains Inf values.');
end

if any(isnan(Y))
    error('Target contains NaN values.');
end

if any(isinf(Y))
    error('Target contains Inf values.');
end

fprintf('No NaN or Inf values detected.\n\n');


%% Train/test split

rng(42, 'twister');

N = size(X_raw, 1);

cv = cvpartition(N, 'HoldOut', 0.20);

trainIdx = training(cv);
testIdx  = test(cv);

X_train_raw = X_raw(trainIdx, :);
X_test_raw  = X_raw(testIdx, :);

Y_train = Y(trainIdx);
Y_test  = Y(testIdx);

fprintf('Train samples : %d\n', sum(trainIdx));
fprintf('Test samples  : %d\n\n', sum(testIdx));


%% Log-transform circuit component values

X_train = X_train_raw;
X_test  = X_test_raw;

componentIdx = 1:8;

X_train(:, componentIdx) = ...
    log10(X_train(:, componentIdx));

X_test(:, componentIdx) = ...
    log10(X_test(:, componentIdx));

fprintf('Log10 transformation applied to first 8 features.\n');
fprintf('VCC remains in linear scale.\n\n');


%% Calculate normalization parameters from training data

muX = mean(X_train, 1);

sigmaX = std(X_train, 0, 1);

sigmaX(sigmaX == 0) = 1;


%% Normalize inputs

X_train_norm = ...
    (X_train - muX) ./ sigmaX;

X_test_norm = ...
    (X_test - muX) ./ sigmaX;

fprintf('Input normalization completed.\n\n');


%% Verify processed data

fprintf('Checking processed data...\n');

if any(~isfinite(X_train_norm), 'all')
    error('Training input contains invalid values after preprocessing.');
end

if any(~isfinite(X_test_norm), 'all')
    error('Test input contains invalid values after preprocessing.');
end

if any(~isfinite(Y_train))
    error('Training target contains invalid values.');
end

if any(~isfinite(Y_test))
    error('Test target contains invalid values.');
end

fprintf('All processed values are finite.\n\n');


%% Check training normalization

trainMean = mean(X_train_norm, 1);
trainStd  = std(X_train_norm, 0, 1);

fprintf('Training normalized feature means:\n');
disp(trainMean);

fprintf('Training normalized feature standard deviations:\n');
disp(trainStd);


%% Save prepared dataset

saveFile = fullfile(outputDir, 'DL_Dataset.mat');

save(saveFile, ...
    'X_train_norm', ...
    'X_test_norm', ...
    'Y_train', ...
    'Y_test', ...
    'X_train_raw', ...
    'X_test_raw', ...
    'muX', ...
    'sigmaX', ...
    'featureNames', ...
    'targetName', ...
    'trainIdx', ...
    'testIdx', ...
    'componentIdx');

fprintf('=============================================\n');
fprintf('DL dataset preparation completed.\n');
fprintf('Saved to:\n%s\n', saveFile);
fprintf('=============================================\n');
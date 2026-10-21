%% prepare_ml_dataset.m
% Prepare valid CE amplifier simulations for ML/XAI

clear;
clc;

%% Project paths
project_dir = fileparts(fileparts(mfilename('fullpath')));

data_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_Dataset_v5_2000_1GHz.csv');

%% Load dataset
fprintf('Loading dataset...\n');

Dataset = readtable(data_file);

fprintf('Total simulations: %d\n', height(Dataset));

%% Select physically valid simulations
Valid = Dataset( ...
    Dataset.Simulation_Status == "Valid", :);

fprintf('Valid simulations: %d\n', height(Valid));

%% ML input parameters
Features = { ...
    'R1', ...
    'R2', ...
    'RC', ...
    'RE', ...
    'RL', ...
    'Cin', ...
    'Cout', ...
    'Ce', ...
    'VCC'};

%% ML target
Target = 'Gain_dB';

%% Check missing values
fprintf('\nChecking missing values...\n');

MLTable = Valid(:, [Features, {Target}]);

missing_count = sum(ismissing(MLTable));

disp(table( ...
    MLTable.Properties.VariableNames', ...
    missing_count', ...
    'VariableNames', {'Variable','MissingCount'}));

%% Remove rows with missing target/input values
MLTable = rmmissing(MLTable);

fprintf('\nRows after removing missing values: %d\n', ...
    height(MLTable));

%% Save clean ML dataset
output_file = fullfile( ...
    project_dir, ...
    'output', ...
    'CE_Amplifier_ML_Valid.csv');

writetable(MLTable, output_file);

fprintf('\nClean ML dataset saved:\n%s\n', output_file);

%% Display first few rows
fprintf('\nFirst five ML samples:\n');
disp(MLTable(1:min(5,height(MLTable)), :));

%% Basic statistics
fprintf('\nTarget statistics:\n');

fprintf('Gain minimum : %.4f dB\n', min(MLTable.Gain_dB));
fprintf('Gain maximum : %.4f dB\n', max(MLTable.Gain_dB));
fprintf('Gain mean    : %.4f dB\n', mean(MLTable.Gain_dB));
fprintf('Gain median  : %.4f dB\n', median(MLTable.Gain_dB));
fprintf('Gain std     : %.4f dB\n', std(MLTable.Gain_dB));
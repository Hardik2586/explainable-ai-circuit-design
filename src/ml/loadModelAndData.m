function [model, X, Y, Features, LogFeatures] = loadModelAndData(root_dir)
    % LOADMODELANDDATA  Load canonical dataset and ML model with log-transformed features.
    %
    %   [model, X, Y, Features, LogFeatures] = loadModelAndData(root_dir)
    %
    %   Returns the trained fitrensemble model, the log-transformed feature
    %   matrix X (660x9), target vector Y (660x1), and feature name lists.
    %
    %   Feature transformation:
    %     X(:,1:8) = log10(R1, R2, RC, RE, RL, Cin, Cout, Ce)
    %     X(:,9)   = VCC (linear, no transformation)

    Features    = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
    LogFeatures = {'R1','R2','RC','RE','RL','Cin','Cout','Ce'};

    % Load dataset
    dataset_path = fullfile(root_dir, 'data', 'final', 'CE_Amplifier_ML_Valid.csv');
    assert(isfile(dataset_path), 'Dataset not found: %s', dataset_path);
    T = readtable(dataset_path);

    % Construct feature matrix
    X = zeros(height(T), 9);
    for k = 1:numel(LogFeatures)
        X(:,k) = log10(T.(LogFeatures{k}));
    end
    X(:,9) = T.VCC;
    Y = T.Gain_dB;

    % Load model - try new location first, fall back to legacy
    model_path = fullfile(root_dir, 'models', 'ml', 'Gain_Boosted_Model.mat');
    if ~isfile(model_path)
        model_path = fullfile(root_dir, 'ml', 'models', 'Gain_Boosted_Model.mat');
    end
    assert(isfile(model_path), 'ML model not found');
    M = load(model_path);
    assert(isfield(M, 'model'), 'MAT file does not contain variable "model"');
    model = M.model;
end

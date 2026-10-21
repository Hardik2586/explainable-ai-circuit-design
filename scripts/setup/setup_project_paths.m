function root_dir = setup_project_paths()
    % SETUP_PROJECT_PATHS  Configure MATLAB path for CE Amplifier XAI project.
    %   root_dir = setup_project_paths()

    script_path = mfilename('fullpath');
    setup_dir   = fileparts(script_path);
    scripts_dir = fileparts(setup_dir);
    root_dir    = fileparts(scripts_dir);

    % Core source modules
    addpath(fullfile(root_dir, 'src', 'spice'));
    addpath(fullfile(root_dir, 'src', 'data'));
    addpath(fullfile(root_dir, 'src', 'ml'));
    addpath(fullfile(root_dir, 'src', 'explainability'));
    addpath(fullfile(root_dir, 'src', 'sensitivity'));
    addpath(fullfile(root_dir, 'src', 'interaction'));
    addpath(fullfile(root_dir, 'src', 'validation'));
    addpath(fullfile(root_dir, 'src', 'optimization'));

    % Legacy and utility directories
    addpath(fullfile(root_dir, 'spice', 'parsers'));
    addpath(fullfile(root_dir, 'spice', 'runners'));
    addpath(fullfile(root_dir, 'spice', 'templates'));
    addpath(fullfile(root_dir, 'scripts', 'setup'));
    addpath(fullfile(root_dir, 'scripts', 'utilities'));
    addpath(fullfile(root_dir, 'scripts', 'pipeline'));

    % Data paths
    addpath(fullfile(root_dir, 'data', 'final'));

    % Model paths
    addpath(fullfile(root_dir, 'ml', 'models'));
    addpath(fullfile(root_dir, 'ml', 'training'));
    addpath(fullfile(root_dir, 'ml', 'evaluation'));

    % XAI paths
    addpath(fullfile(root_dir, 'xai', 'global_shap'));
    addpath(fullfile(root_dir, 'xai', 'local_shap'));
    addpath(fullfile(root_dir, 'xai', 'dependence'));
    addpath(fullfile(root_dir, 'xai', 'interaction'));
    addpath(fullfile(root_dir, 'xai', 'validation'));

    % Test paths
    addpath(fullfile(root_dir, 'tests', 'dataset'));
    addpath(fullfile(root_dir, 'tests', 'ml'));
    addpath(fullfile(root_dir, 'tests', 'shap'));
    addpath(fullfile(root_dir, 'tests', 'spice'));

    % Numbered pipeline scripts
    addpath(fullfile(root_dir, 'scripts'));
end

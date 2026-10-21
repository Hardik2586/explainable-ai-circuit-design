%% run_full_pipeline.m
% Root Master Research Pipeline Entrypoint
addpath(fullfile(fileparts(mfilename('fullpath')), 'scripts', 'setup'));
run_full_pipeline_script = fullfile(fileparts(mfilename('fullpath')), 'scripts', 'pipeline', 'run_full_pipeline.m');
run(run_full_pipeline_script);

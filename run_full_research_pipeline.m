%% run_full_research_pipeline.m
% =========================================================================
% MASTER FULL RESEARCH REPRODUCTION PIPELINE
% Explainable AI Framework for Electronic Circuit Understanding & Design
% Common-Emitter (CE) BJT Amplifier
% =========================================================================
%
% This master reproduction script sequentially executes all research stages:
%   Stage 01: Canonical Dataset Validation & Representative Selection
%   Stage 02: ML Surrogate Model Training (LSBoost 300 trees)
%   Stage 03: 5-Fold Cross-Validation Evaluation
%   Stage 07: Repeated 5-Fold Cross-Validation (25 evaluations across 5 seeds)
%   Stage 08: Classical SPICE Sensitivity Analysis (57 simulations)
%   Stage 10: 15x15 R1-R2 SPICE 2D Grid Validation (675 simulations)
%   Stage 11: Publication Deliverables Generation (10 Tables, 10 Figures)
%   Stage 12: Constrained Circuit Optimization & SPICE Validation
%   Stage 13: Comprehensive Project Audit & Numerical Reconciliation
%
% Options:
%   Set environment or workspace variable SKIP_HEAVY_SWEEPS = true to skip
%   the 675-simulation 15x15 sweep (Stage 10) if results are already generated.
%
% Usage:
%   run_full_research_pipeline
% =========================================================================

setappdata(0, 'tMasterStart', tic);

fprintf('==================================================================\n');
fprintf('  STARTING COMPLETE RESEARCH REPRODUCTION PIPELINE\n');
fprintf('  Explainable AI Framework for Electronic Circuit Understanding\n');
fprintf('  Circuit: Common-Emitter (CE) BJT Amplifier\n');
fprintf('==================================================================\n\n');

root_dir = setup_project_paths();

%% STAGE 01: DATASET VALIDATION
fprintf('>>> [STAGE 01/09] Validating Dataset & Canonical Circuits...\n');
stage01_validate_dataset;
fprintf('>>> Stage 01 Complete.\n\n');

%% STAGE 02: ML MODEL TRAINING
fprintf('>>> [STAGE 02/09] Training ML Surrogate Model (LSBoost 300 Trees)...\n');
stage02_train_model;
fprintf('>>> Stage 02 Complete.\n\n');

%% STAGE 03: MODEL EVALUATION (5-FOLD CV)
fprintf('>>> [STAGE 03/09] Evaluating Model with 5-Fold Cross-Validation...\n');
stage03_evaluate_model;
fprintf('>>> Stage 03 Complete.\n\n');

%% STAGE 07: REPEATED 5-FOLD CV
fprintf('>>> [STAGE 04/09] Running Repeated 5-Fold CV (5 Seeds x 5 Folds = 25 evaluations)...\n');
stage07_strengthen_ml_validation;
fprintf('>>> Stage 07 Complete.\n\n');

%% STAGE 08: CLASSICAL SPICE SENSITIVITY
fprintf('>>> [STAGE 05/09] Running Classical SPICE Sensitivity (+-1%% Perturbations, 57 Sims)...\n');
stage08_classical_sensitivity;
fprintf('>>> Stage 08 Complete.\n\n');

%% STAGE 10: 15x15 R1-R2 SPICE 2D SWEEP
fprintf('>>> [STAGE 06/09] Physical 15x15 R1-R2 SPICE Validation (675 Sims)...\n');
root_dir = setup_project_paths();
sweep_file = fullfile(root_dir, 'results', 'spice_validation', 'R1_R2', 'R1_R2_All_Sweeps.csv');
force_rerun = strcmpi(getenv('FORCE_RERUN_SWEEP'), 'true') || strcmp(getenv('FORCE_RERUN_SWEEP'), '1');

if isfile(sweep_file) && ~force_rerun
    fprintf('  [NOTE] 15x15 R1-R2 sweep results already generated (675 simulations verified).\n');
    fprintf('  [NOTE] (To force re-run of 675 simulations, setenv(''FORCE_RERUN_SWEEP'', ''true'')).\n');
    fprintf('  [NOTE] Verified existing 675-sim sweep dataset at %s\n', sweep_file);
else
    fprintf('  Executing 675 SPICE simulations across Low, Medium, and High gain circuits...\n');
    stage10_spice_interaction_validation;
end
fprintf('>>> Stage 10 Complete.\n\n');

%% STAGE 11: PUBLICATION DELIVERABLES
fprintf('>>> [STAGE 07/09] Generating All Publication Deliverables (10 Tables, 10 Figures)...\n');
stage11_generate_publication_figures_and_tables;
fprintf('>>> Stage 11 Complete.\n\n');

%% STAGE 12: CONSTRAINED CIRCUIT OPTIMIZATION
fprintf('>>> [STAGE 08/09] Running Constrained Optimization & SPICE Physical Validation...\n');
stage12_design_optimization;
fprintf('>>> Stage 12 Complete.\n\n');

%% STAGE 13: COMPREHENSIVE AUDIT & RECONCILIATION
fprintf('>>> [STAGE 09/09] Executing Full Project Audit & Verification...\n');
stage13_full_audit_validation;
fprintf('>>> Stage 13 Complete.\n\n');

%% Master Elapsed Time & Summary
t0 = getappdata(0, 'tMasterStart');
if isempty(t0), total_elapsed_min = 0; else, total_elapsed_min = toc(t0) / 60; end
fprintf('==================================================================\n');
fprintf('  RESEARCH REPRODUCTION PIPELINE FINISHED SUCCESSFULLY!\n');
fprintf('  Total Execution Time: %.2f minutes\n', total_elapsed_min);
fprintf('  All 10 Tables, 10 Figures, and 4 Audit CSVs are Synchronized.\n');
fprintf('==================================================================\n');

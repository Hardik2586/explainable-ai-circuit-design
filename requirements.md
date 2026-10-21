# System Requirements & Dependencies

## 1. Software Environment
- **MATLAB:** R2021a or newer (R2023b+ recommended)
- **Operating System:** Windows 10 / Windows 11 (64-bit)
- **SPICE Simulator:** ngspice version 47 or compatible CLI binary
  - Default Binary Location: `C:\ngspice-47_64\bin\ngspice_con.exe`

## 2. MATLAB Toolboxes Required
- **Statistics and Machine Learning Toolbox** (Required for `fitrensemble`, `TreeBagger`, `cvpartition`, `shapley`, `kfoldLoss`, `kfoldPredict`)
- **Optimization Toolbox** (Required for future circuit optimization routines)
- **Global Optimization Toolbox** (Optional / Recommended for multi-objective optimization sweeps)

## 3. Circuit Models & Libraries
- **BJT Transistor Model:** 2N3904 NPN Bipolar Junction Transistor SPICE model library located at `spice/models/2N3904.lib`.

## 4. Execution & Setup Instructions
1. Open MATLAB and set current working directory to `C:\Internship Project`.
2. Run `setup_project_paths` to add all subdirectories to the active MATLAB path:
   ```matlab
   setup_project_paths;
   ```
3. Run sanity tests to verify environment readiness:
   ```matlab
   test_dataset;
   test_ml_model;
   test_shap;
   test_spice_baseline;
   ```
4. Run master pipeline:
   ```matlab
   run_full_pipeline;
   ```

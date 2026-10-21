# Explainable AI Framework for Electronic Circuit Understanding and Design Optimization

An end-to-end scientific research framework combining **SPICE circuit simulation**, **Machine Learning regression**, **Shapley explainability (SHAP)**, **operating-point physics**, and **constrained design optimization** applied to a Common-Emitter (CE) BJT amplifier.

---

## 1. Project Directory Structure

```
C:\Internship Project\
├── data/
│   ├── final/                 # Canonical 660-row validated dataset (CE_Amplifier_ML_Valid.csv)
│   └── raw/                   # Original 2,000-sample LHS dataset
├── src/
│   ├── spice/                 # Centralized SPICE execution layer (runSpice, runSpiceSensitivity, runSpiceSweep2D)
│   └── ml/                    # Data/model loading helper (loadModelAndData.m)
├── ml/
│   ├── models/                # Trained gradient boosted models (Gain_Boosted_Model.mat)
│   └── training/              # Model training scripts
├── xai/
│   ├── global_shap/           # Global SHAP importance results
│   ├── local_shap/            # Local SHAP analysis for representative circuits
│   ├── dependence/            # SHAP feature dependence analysis
│   └── interaction/           # Second-order SHAP interaction analysis
├── scripts/                   # Numbered, reproducible execution pipeline (stage01 to stage12)
├── results/
│   ├── tables/publication/    # Publication Tables 1 through 10
│   ├── figures/publication/   # Publication Figures 1 through 10
│   ├── spice_validation/R1_R2/# 675-simulation physical validation sweep results
│   ├── sensitivity/           # Classical SPICE sensitivity outputs
│   └── optimization/          # Optimized candidate circuit netlists and tables
├── tests/
│   └── spice/                 # Unit tests for SPICE execution layer (test_runSpice.m)
├── FINAL_PROJECT_STATUS.md    # Definitive scientific findings and numerical metrics
├── PROJECT_STATUS.md          # Stage completion checklist
└── requirements.md            # Software, toolbox, and ngspice dependencies
```

---

## 2. Research Workflow & Reproducibility

### Fast Smoke Validation (< 15 seconds)
To rapidly verify paths, toolboxes, dataset schema, model prediction, SHAP files, and an end-to-end SPICE simulation:
```matlab
cd('C:\Internship Project');
run_quick_validation;
```

### Full Research Pipeline Reproduction
To run the entire research reproduction sequentially from Stage 1 through Stage 13:
```matlab
cd('C:\Internship Project');
run_full_research_pipeline;
```

### Individual Pipeline Stages
You can also execute individual stages in MATLAB R2025b:

```matlab
% Set up project search paths
cd('C:\Internship Project');
setup_project_paths;

% Stage 01: Validate dataset schema, ranges, and representative circuits
run('scripts/stage01_validate_dataset.m');

% Stage 02: Train gradient boosted surrogate ensemble (LSBoost, 300 trees)
run('scripts/stage02_train_model.m');

% Stage 03: 5-Fold cross-validation
run('scripts/stage03_evaluate_model.m');

% Stage 07: Repeated 5-fold cross-validation (25 evaluations, mean +/- std)
run('scripts/stage07_strengthen_ml_validation.m');

% Stage 08: Classical SPICE sensitivity analysis & comparison with SHAP
run('scripts/stage08_classical_sensitivity.m');

% Stage 10: 15x15 R1-R2 SPICE physical validation sweep (675 simulations)
run('scripts/stage10_spice_interaction_validation.m');

% Stage 11: Compile publication figures (1-10) and tables (1-10)
run('scripts/stage11_generate_publication_figures_and_tables.m');

% Stage 12: Constrained circuit optimization & independent SPICE validation
run('scripts/stage12_design_optimization.m');

% Stage 13: Comprehensive project audit & numerical reconciliation
run('scripts/stage13_full_audit_validation.m');

% Master Final Validation Suite (12 Stages PASS/FAIL/WARNING Verification)
stage99_final_validation;
```

---

## 3. Auditing & Technical Reports
- **Project Completion Status:** [`PROJECT_COMPLETION_STATUS.md`](PROJECT_COMPLETION_STATUS.md)
- **Master Final Results Report:** [`results/final/FINAL_RESULTS.md`](results/final/FINAL_RESULTS.md)
- **Final Project Audit Report:** [`results/final/PROJECT_AUDIT.md`](results/final/PROJECT_AUDIT.md)
- **Dataset Validation Report:** [`results/final/Dataset_Validation_Report.md`](results/final/Dataset_Validation_Report.md)
- **Comprehensive Research Audit:** [`FINAL_RESEARCH_AUDIT.md`](FINAL_RESEARCH_AUDIT.md)
- **Data Leakage & Cross-Validation Audit:** [`results/audit/DATA_LEAKAGE_AUDIT.md`](results/audit/DATA_LEAKAGE_AUDIT.md)
- **Final Results Folder:** [`results/final/`](results/final/) containing all 13 publication figures, model evaluations, SHAP attributions, sensitivity data, 2D SPICE sweeps, and optimization tables.

---

## 3. Key Scientific Findings

1. **Surrogate Model Generalization:**
   * Full apparent training fit: $R^2 = 0.9597$, $\text{RMSE} = 1.4431\text{ dB}$.
   * Repeated 5-fold cross-validation ($N=25$ folds): $R^2 = 0.7998 \pm 0.0288$, $\text{RMSE} = 3.1912 \pm 0.2504\text{ dB}$, $\text{MAE} = 2.5103 \pm 0.1834\text{ dB}$.
2. **Global Parameter Attribution vs. Physical Sensitivity:**
   * Global SHAP importance ranks $R_E$ (3.87 dB) and $R_1$ (3.74 dB) as the dominant drivers of gain, followed by $R_C$ (2.81 dB), $R_2$ (2.67 dB), and $V_{CC}$ (2.38 dB).
   * Physical sensitivity correlation: Spearman $\rho = 0.7333$, Pearson $r = 0.7918$.
   * Small-signal sensitivity signs match physical theory: negative for $R_E$ and $R_1$; positive for $R_C, R_2, V_{CC}, R_L$.
3. **Physical Validation of $R_1$-$R_2$ Interaction:**
   * Re-ran $15 \times 15$ grid sweep across 3 circuits: **675 / 675 (100.0%) simulations executed successfully**.
   * Operating modes identified: 587 Active Linear, 87 Saturation ($V_{CE} < 0.2\text{ V}$), 1 Cutoff ($I_C < 10^{-7}\text{ A}$).
   * SPICE operating-point analysis confirms the interaction arises from the non-linear base voltage divider equation $V_B \approx V_{CC} \frac{R_2}{R_1 + R_2}$, which directly modulates quiescent collector current and transconductance $g_m$.
4. **Constrained Optimization & SPICE Verification:**
   * **Low Gain:** Baseline $9.41\text{ dB} \rightarrow$ Validated **$37.49\text{ dB}$ ($+28.07\text{ dB}$, $25.33\times$ gain increase)**.
   * **Medium Gain:** Baseline $35.22\text{ dB} \rightarrow$ Validated **$41.25\text{ dB}$ ($+6.03\text{ dB}$, $2.00\times$ gain increase)**.
   * **High Gain:** Stabilized DC operating headroom to $V_{CE} = 10.48\text{ V}$ at **$40.68\text{ dB}$** with verified active linear operation.

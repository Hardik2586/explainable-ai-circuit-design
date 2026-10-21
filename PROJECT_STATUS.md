# Project Status: Explainable AI Framework for Electronic Circuit Understanding and Design Optimization

**Circuit Under Investigation:** Common-Emitter (CE) BJT Amplifier  
**Primary Objective:** Utilize SPICE simulation, Machine Learning (ML), and Explainable AI (SHAP) to quantify parameter importance, uncover physical circuit interactions, and optimize amplifier performance.  
**Project Root:** `C:\Internship Project`  
**Status Date:** September 28, 2026  

---

## A. COMPLETED PRIOR RESEARCH STAGES

- [x] **CE Amplifier Dataset Generation:** Generated 2,000 raw Latin Hypercube Sampler (LHS) circuit configurations simulating AC sweep ($10\text{ Hz}$ to $1\text{ GHz}$) and DC bias point analysis in ngspice 47.
- [x] **Dataset Validation:** Filtered for DC operating point stability and AC convergence, isolating **660 physically valid circuit samples** across 9 key input parameters ($R_1, R_2, R_C, R_E, R_L, C_{in}, C_{out}, C_e, V_{CC}$) targeting gain ($A_v\text{ in dB}$).
- [x] **ML Regression Modeling:** Trained a Gradient Boosting Ensemble (`fitrensemble` with `LSBoost`, 300 decision trees) on log-transformed component features.
  - **Full-Dataset Fit:** $R^2 = 0.9597$, $\text{RMSE} = 1.4431\text{ dB}$, $\text{MAE} = 0.8086\text{ dB}$.
  - **Held-Out Test Set (80/20):** $R^2 = 0.7867$, $\text{RMSE} = 3.0746\text{ dB}$, $\text{MAE} = 2.5465\text{ dB}$.
- [x] **Global SHAP Analysis:** Ranked global parameter importance using MATLAB built-in `shapley` explainer ($R_E, R_1, R_C, R_2, V_{CC}, R_L, C_{in}, C_e, C_{out}$).
- [x] **Local SHAP Analysis:** Evaluated local feature attribution for three canonical operating regimes:
  - Low Gain (Row 450, Actual: $9.4122\text{ dB}$)
  - Medium Gain (Row 253, Actual: $35.2217\text{ dB}$)
  - High Gain (Row 259, Actual: $51.4451\text{ dB}$)
- [x] **SHAP Dependence Analysis:** Computed feature dependence curves and Spearman rank correlations against target gain.
- [x] **SHAP Interaction Analysis:** Uncovered second-order feature interaction effects, identifying $R_1 \leftrightarrow R_2$ ($0.61441\text{ dB}$) as the dominant interaction.

---

## B. COMPLETED RESEARCH & REPRODUCIBILITY STAGES (ALL VERIFIED)

- [x] **Canonical Representative Circuits:** Deterministically established and documented Low (Row 450), Medium (Row 253), and High (Row 259) circuits in [`results/tables/Representative_Circuits.csv`](file:///C:/Internship%20Project/results/tables/Representative_Circuits.csv).
- [x] **SPICE Execution Layer:** Centralized into `src/spice/runSpice.m`, `runSpiceSensitivity.m`, `runSpiceSweep2D.m` with whitespace-safe execution and automatic DC operating point extraction ($V_B, V_E, V_C, I_B, I_C, I_E, V_{CE}$). Passes 100% of validation tests.
- [x] **$R_1$-$R_2$ SPICE Interaction Validation:** Successfully re-executed the $15 \times 15$ grid sweep across all 3 representative circuits:
  - **675 attempted / 675 executed (100.0% SPICE execution success rate)**.
  - Identified physical operating modes: **587 Active Linear**, **87 Saturation ($V_{CE} < 0.2\text{ V}$)**, **1 Cutoff ($I_C < 10^{-7}\text{ A}$)**.
  - Zero software failures.
- [x] **ML Surface vs. SPICE Surface Comparison:** Computed point-by-point error surfaces and statistical metrics:
  - Overall 675-point correlation: Pearson $r = 0.9147$, Spearman $\rho = 0.8738$.
  - Saved surfaces and contours to `results/figures/spice_validation/`.
- [x] **Physical Interpretation of $R_1$-$R_2$ Interaction:** Operating-point physics analysis confirmed base divider mechanism $V_B \approx V_{CC} \frac{R_2}{R_1 + R_2}$, proving that extreme resistor ratios pull the BJT into saturation or cutoff.
- [x] **SHAP vs. Classical Sensitivity:** Performed 57 SPICE sensitivity simulations ($\pm 1\%$ perturbations on all 9 parameters). Established statistical rank agreement:
  - Spearman $\rho = 0.7333$, Pearson $r = 0.7918$.
  - Confirmed all small-signal sensitivity signs match physical theory.
- [x] **Strengthened ML Validation:** Repeated 5-fold cross-validation (25 evaluations total) reporting:
  - $R^2 = 0.7998 \pm 0.0288$
  - $\text{RMSE} = 3.1912 \pm 0.2504\text{ dB}$
  - $\text{MAE} = 2.5103 \pm 0.1834\text{ dB}$
  - Generated 4-panel publication validation figure.
- [x] **Constrained Circuit Optimization:** Formulated optimization in MATLAB using Nelder-Mead simplex search with physical penalty functions constraining active linear operation ($V_B \ge 0.70\text{ V}, V_{CE} \ge 1.20\text{ V}, 0.2\text{ mA} \le I_C \le 8.0\text{ mA}$).
- [x] **SPICE Validation of Optimized Designs:** Independently simulated all candidate designs in ngspice:
  - Optimized Low Gain: **$37.49\text{ dB}$ ($+28.07\text{ dB}$, $25.33\times$ gain increase)**
  - Optimized Medium Gain: **$41.25\text{ dB}$ ($+6.03\text{ dB}$, $2.00\times$ gain increase)**
  - Optimized High Gain: Stabilized DC headroom to $V_{CE} = 10.48\text{ V}$ at **$40.68\text{ dB}$** with verified active linear operation.
- [x] **Publication Deliverables:**
  - 10 Canonical Tables compiled in [`results/tables/publication/`](file:///C:/Internship%20Project/results/tables/publication/).
  - 10 Publication Figures generated in [`results/figures/publication/`](file:///C:/Internship%20Project/results/figures/publication/).
- [x] **Comprehensive Scientific Audit (Stage 13):**
  - Generated 4 audited verification CSVs: `Model_Validation_Audit.csv`, `SHAP_Audit.csv`, `SHAP_Interaction_Audit.csv`, `SPICE_Execution_Audit.csv`.
  - Authored comprehensive audit reports: `FINAL_RESEARCH_AUDIT.md`, `PROJECT_AUDIT.md`, `DATA_LEAKAGE_AUDIT.md`, `FILE_CLEANUP_REPORT.md`.
  - Created turnkey pipeline wrappers: `run_quick_validation.m` (<15s) and `run_full_research_pipeline.m`.
- [x] **Final Deliverables Package (`results/final/`):**
  - Generated all final verification CSVs, MAT files, reports, and publication figures (`01_Dataset_Distribution.png` to `13_Optimization_Validation.png`).
  - Authored comprehensive master report: [`results/final/FINAL_RESULTS.md`](results/final/FINAL_RESULTS.md) with 18 structured sections.
  - Authored [`results/final/PROJECT_AUDIT.md`](results/final/PROJECT_AUDIT.md) and [`results/final/Dataset_Validation_Report.md`](results/final/Dataset_Validation_Report.md).
  - Authored master root deliverable: [`PROJECT_COMPLETION_STATUS.md`](PROJECT_COMPLETION_STATUS.md).
  - Automated 13-stage verification suite: [`scripts/stage99_final_validation.m`](scripts/stage99_final_validation.m) (100% PASS).

---

## C. INCOMPLETE

*(None. All requested research phases, physical simulations, audit verifications, and documentation deliverables are 100% completed.)*

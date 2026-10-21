# FILE CLEANUP & REPOSITORY ORGANIZATION REPORT
**Explainable AI Framework for Electronic Circuit Understanding and Design Optimization**  
**Circuit:** Common-Emitter (CE) BJT Amplifier  
**Date:** September 28, 2026  
**Auditor:** Antigravity Automated Scientific Integrity Suite  

---

## 1. Summary of Actions Taken

In accordance with scientific reproducibility standards and safe refactoring rules:
1. **Zero Data Destruction:** No historical data or experimental logs were deleted.
2. **Obsolete Scripts Archived:** Numbered scripts with unstandardized naming (`01_validate_dataset.m`, `02_train_model.m`, `03_evaluate_model.m`, `10_spice_interaction_validation.m`) were safely relocated to `archive/obsolete/` and replaced by standardized `stage01_` through `stage13_` scripts.
3. **Historical Failure Isolation:** The 675 failed zero-byte simulations resulting from the Windows path space bug in ngspice (`C:\Internship Project\...`) are isolated in `archive/failed_experiments/R1_R2_SPICE_validation_failed/` for historical provenance.
4. **Successful Reproduction Storage:** All 675 fully simulated, validated SPICE sweep outputs are stored in `results/spice_validation/R1_R2/`.

---

## 2. Inventory of Archived Files

| Original File Path | Relocated / Archived Destination | Reason for Relocation |
| :--- | :--- | :--- |
| `scripts/01_validate_dataset.m` | `archive/obsolete/01_validate_dataset.m` | Replaced by standardized `scripts/stage01_validate_dataset.m` |
| `scripts/02_train_model.m` | `archive/obsolete/02_train_model.m` | Replaced by standardized `scripts/stage02_train_model.m` |
| `scripts/03_evaluate_model.m` | `archive/obsolete/03_evaluate_model.m` | Replaced by standardized `scripts/stage03_evaluate_model.m` |
| `scripts/10_spice_interaction_validation.m` | `archive/obsolete/10_spice_interaction_validation.m` | Replaced by standardized `scripts/stage10_spice_interaction_validation.m` |
| `archive/failed_experiments/...` | `archive/failed_experiments/` | Historical record of path-bug simulation failure |
| Temporary `.asv` autosave files | Cleaned from active source directories | Redundant MATLAB editor autosaves |

---

## 3. Clean Repository Architecture

The current active workspace is organized according to the following canonical layout:

```
C:\Internship Project\
│
├── setup_project_paths.m             # Centralized path initialization
├── run_quick_validation.m            # Fast (<15s) smoke test suite
├── run_full_pipeline.m               # Core pipeline sanity suite
├── run_full_research_pipeline.m      # Complete sequential research reproduction
│
├── FINAL_RESEARCH_AUDIT.md           # Master scientific research audit report
├── FINAL_PROJECT_STATUS.md           # Research status and deliverables summary
├── README.md                         # Project documentation and reproduction guide
│
├── data/
│   └── final/
│       └── CE_Amplifier_ML_Valid.csv # Canonical 660-row validated dataset
│
├── models/
│   └── ml/
│       └── Gain_Boosted_Model.mat    # Canonical LSBoost 300-tree surrogate model
│
├── src/
│   └── spice/
│       ├── runSpice.m                # Centralized, robust SPICE execution engine
│       ├── runSpiceSensitivity.m     # Normalized SPICE local sensitivity runner
│       └── runSpiceSweep2D.m         # 2D factorial SPICE grid sweep runner
│
├── scripts/
│   ├── stage01_validate_dataset.m
│   ├── stage02_train_model.m
│   ├── stage03_evaluate_model.m
│   ├── stage07_strengthen_ml_validation.m
│   ├── stage08_classical_sensitivity.m
│   ├── stage10_spice_interaction_validation.m
│   ├── stage11_generate_publication_figures_and_tables.m
│   ├── stage12_design_optimization.m
│   └── stage13_full_audit_validation.m
│
├── xai/
│   ├── global_shap/                  # Global SHAP feature importances
│   ├── local_shap/                   # Local SHAP attributions on canonical circuits
│   ├── dependence/                   # SHAP dependence plots and rankings
│   ├── interaction/                  # 6x6 SHAP interaction analysis matrix
│   └── validation/                   # Explainability validation analysis
│
├── results/
│   ├── audit/                        # Audit reports and 4 verification CSVs
│   │   ├── Model_Validation_Audit.csv
│   │   ├── SHAP_Audit.csv
│   │   ├── SHAP_Interaction_Audit.csv
│   │   ├── SPICE_Execution_Audit.csv
│   │   ├── PROJECT_AUDIT.md
│   │   ├── DATA_LEAKAGE_AUDIT.md
│   │   └── FILE_CLEANUP_REPORT.md
│   ├── tables/
│   │   └── publication/              # Publication Tables: Table01_ to Table10_
│   ├── figures/
│   │   └── publication/              # Publication Figures: Fig01_ to Fig10_
│   ├── spice_validation/
│   │   └── R1_R2/                    # 675 verified SPICE simulations
│   ├── optimization/                 # Optimized netlists and candidate tables
│   ├── sensitivity/                  # Classical sensitivity outputs
│   └── ml/                           # Cross-validation result files
│
├── tests/
│   ├── spice/                        # Unit tests for SPICE execution
│   └── ml/                           # Unit tests for surrogate model and SHAP
│
└── archive/
    ├── obsolete/                     # Deprecated and superseded scripts
    └── failed_experiments/           # Historical log of path-bug simulations
```

---

## 4. Verification of Cleanliness
- No orphan scripts remain in `scripts/`.
- All scripts in `scripts/` conform to the strict prefix `stageXX_...`.
- All pipeline entrypoints run cleanly without missing dependencies.
- No files are located in temporary or unversioned directories outside the workspace.

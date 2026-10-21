PHASE 6C.1 CROSS-DATASET GOVERNANCE AUDIT
Project root: C:\Internship Project
Output folder: C:\Internship Project\results\Phase6C1_CrossDatasetGovernance_20261020_233831

CSV scanned: 274
Readable: 274
Read errors: 0
Exact duplicate file rows: 54
Cross-dataset configuration overlap rows: 1160
Overlap file-pair summaries: 2

SAFETY / INTERPRETATION NOTES
1. This audit is read-only and does not train models or alter source files.
2. Configuration overlap is a review flag, not proof of train/test leakage.
3. Roles and dataset classes are heuristic and require provenance review.
4. Existing test and holdout files are protected from split generation.
5. No proposed train/validation/test split is approved by this script.
6. BJT and MOSFET are audited separately; their keys are never cross-compared.

FILES TO REVIEW FIRST
- Phase6C1_CanonicalDatasetReview.csv
- Phase6C1_OverlapPairSummary.csv
- Phase6C1_CrossDatasetConfigurationOverlap.csv
- Phase6C1_ReadErrorDiagnostics.csv
- Phase6C1_ProposedSplitReview.csv

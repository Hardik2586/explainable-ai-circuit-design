# PROJECT AUDIT REPORT
**Explainable AI Framework for Electronic Circuit Understanding and Design Optimization**  
**Circuit:** Common-Emitter (CE) BJT Amplifier (2N3904)  
**Date of Audit:** September 28, 2026  
**Auditor:** Automated Scientific Integrity Suite & Antigravity Lead Engineer  

---

## 1. Executive Summary & Verification Matrix

This audit report documents the comprehensive validation and reproducibility verification of the MATLAB R2025b and ngspice 47 research codebase. All claimed numerical values, ML surrogate metrics, SHAP feature attributions, classical sensitivity coefficients, SPICE grid simulations, and optimization benchmarks have been audited against raw execution data.

### Verification Summary Table

| Audit Category | Checked Items | Observed Result | Status |
| :--- | :--- | :--- | :--- |
| **Dataset Integrity** | 660 rows, 10 columns, zero NaNs, parameter bounds | Exactly matched; 0 missing values | **PASS** |
| **Representative Circuits** | Row 450 (Low), Row 253 (Medium), Row 259 (High) | Canonicalized across all stages | **PASS** |
| **Model Reproducibility** | Full apparent $R^2=0.9597$, Held-out $R^2=0.7867$, CV $R^2=0.7998$ | 12/12 metrics matched within $\Delta < 10^{-4}$ | **PASS** |
| **SHAP Attribution** | Global (9 features), Local (3 circuits), Predictor mapping | Dimensions & log-transforms verified | **PASS** |
| **SHAP Interaction** | $6 \times 6$ matrix, symmetry, $R_1 \leftrightarrow R_2 = 0.61441\text{ dB}$ | Rank 1 interaction confirmed | **PASS** |
| **SPICE Execution Layer** | Centralized `runSpice.m`, relative path handling in ngspice | 0 software aborts, 100% execution success | **PASS** |
| **15x15 R1-R2 Grid** | 675 simulations across 3 circuits, operating point tracking | 587 active linear, 87 saturation, 1 cutoff | **PASS** |
| **Classical Sensitivity** | 57 SPICE simulations ($\pm 1\%$), rank correlation with SHAP | Spearman $\rho = 0.7333$, Pearson $r = 0.7918$ | **PASS** |
| **Circuit Optimization** | Constrained search with physics penalties ($V_{CE} \ge 1.2\text{ V}$) | All candidates SPICE-verified in active mode | **PASS** |
| **Publication Deliverables**| Tables 1–10 (`.csv`) and Figures 1–10 (`.png`) | All 20 publication artifacts verified | **PASS** |

---

## 2. Dataset Schema & Integrity Audit

The canonical dataset is located at `data/final/CE_Amplifier_ML_Valid.csv`.
- **Total Samples:** 660
- **Total Columns:** 10 (9 features + 1 target)
- **Features:** $R_1, R_2, R_C, R_E, R_L, C_{in}, C_{out}, C_e, V_{CC}$
- **Target:** Midband AC Gain ($A_v$ in dB)
- **Missing / Infinite Values:** 0
- **Duplicate Rows:** 0
- **Gain Distribution:**
  - Minimum Gain: $9.4122\text{ dB}$ (Row 450)
  - Median Gain: $35.1895\text{ dB}$ (Rank 331, canonical representative Row 253 = $35.2217\text{ dB}$)
  - Maximum Gain: $51.4451\text{ dB}$ (Row 259)
  - Mean $\pm$ Standard Deviation: $34.6425 \pm 7.1934\text{ dB}$

### Parameter Range Audit
- $R_1$: $[10.19\text{ k}\Omega, 997.86\text{ k}\Omega]$
- $R_2$: $[10.02\text{ k}\Omega, 993.22\text{ k}\Omega]$
- $R_C$: $[500.45\,\Omega, 9.76\text{ k}\Omega]$
- $R_E$: $[101.26\,\Omega, 4.99\text{ k}\Omega]$
- $R_L$: $[1.01\text{ k}\Omega, 99.55\text{ k}\Omega]$
- $C_{in}$: $[10.33\text{ nF}, 99.19\,\mu\text{F}]$
- $C_{out}$: $[10.22\text{ nF}, 96.02\,\mu\text{F}]$
- $C_e$: $[10.09\text{ nF}, 991.33\,\mu\text{F}]$
- $V_{CC}$: $[5.00\text{ V}, 14.99\text{ V}]$

---

## 3. ML Surrogate Model Architecture & Reproducibility

### Implementation Details
- **Function:** MATLAB built-in `fitrensemble`
- **Method:** `LSBoost` (Least-Squares Boosting)
- **Base Learners:** Regression Decision Trees (`templateTree`)
  - Maximum Number of Splits: 20
  - Minimum Leaf Size: 8
- **Number of Learning Cycles:** 300
- **Learning Rate ($\eta$):** 0.03
- **Feature Preprocessing:**
  - Logarithmic transformation: $x_k = \log_{10}(X_k)$ for $k \in \{R_1, R_2, R_C, R_E, R_L, C_{in}, C_{out}, C_e\}$
  - Linear scaling: $x_9 = V_{CC}$

### Performance Reconciliation Table

| Evaluation Protocol | Metric | Reported Value | Reproduced Value | Absolute Difference | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Full Apparent Fit** | $R^2$ | 0.95969 | 0.95969 | $3.14 \times 10^{-6}$ | **PASS** |
| Full Apparent Fit | RMSE | 1.4431 dB | 1.4431 dB | $5.82 \times 10^{-6}$ | **PASS** |
| Full Apparent Fit | MAE | 0.8086 dB | 0.80863 dB | $2.58 \times 10^{-5}$ | **PASS** |
| **Held-Out Test (80/20)** | $R^2$ | 0.7867 | 0.78673 | $2.78 \times 10^{-5}$ | **PASS** |
| Held-Out Test (80/20) | RMSE | 3.0746 dB | 3.0746 dB | $1.14 \times 10^{-5}$ | **PASS** |
| Held-Out Test (80/20) | MAE | 2.5465 dB | 2.5465 dB | $7.23 \times 10^{-6}$ | **PASS** |
| **Repeated 5-Fold CV** | $R^2$ Mean | 0.7998 | 0.79980 | $4.17 \times 10^{-7}$ | **PASS** |
| Repeated 5-Fold CV | $R^2$ Std | 0.0288 | 0.02879 | $1.34 \times 10^{-5}$ | **PASS** |
| Repeated 5-Fold CV | RMSE Mean | 3.1912 dB | 3.1912 dB | $6.67 \times 10^{-6}$ | **PASS** |
| Repeated 5-Fold CV | RMSE Std | 0.2504 dB | 0.25036 dB | $3.91 \times 10^{-5}$ | **PASS** |
| Repeated 5-Fold CV | MAE Mean | 2.5103 dB | 2.5103 dB | $1.43 \times 10^{-5}$ | **PASS** |
| Repeated 5-Fold CV | MAE Std | 0.1834 dB | 0.18342 dB | $2.40 \times 10^{-5}$ | **PASS** |

> [!IMPORTANT]
> The apparent fit metric ($R^2 = 0.9597$, $\text{RMSE} = 1.44\text{ dB}$) represents training memory on the entire dataset and is NOT a measure of generalization. The scientifically valid generalization estimate is provided by the repeated 5-fold cross-validation: $R^2 = 0.7998 \pm 0.0288$, $\text{RMSE} = 3.19 \pm 0.25\text{ dB}$.

---

## 4. SHAP Feature Attribution Audit

Feature importances were computed using MATLAB built-in `shapley` object.

### Global Attribution Hierarchy
1. $R_E$ ($3.8690\text{ dB}$): Primary emitter degeneration resistor controlling negative feedback and stage transconductance.
2. $R_1$ ($3.7356\text{ dB}$): Upper base divider resistor setting quiescent base potential $V_B$.
3. $R_C$ ($2.8104\text{ dB}$): Collector load resistor establishing AC gain slope and DC collector voltage $V_C$.
4. $R_2$ ($2.6713\text{ dB}$): Lower base divider resistor co-determining base bias.
5. $V_{CC}$ ($2.3819\text{ dB}$): DC power supply voltage defining amplifier headroom.
6. $R_L$ ($1.5502\text{ dB}$): External load resistance shunting $R_C$ in AC small-signal mode.
7. $C_{in}$ ($0.1101\text{ dB}$): AC input coupling capacitor (negligible midband impact).
8. $C_e$ ($0.0756\text{ dB}$): Emitter bypass capacitor (sets low-frequency pole, flat at midband).
9. $C_{out}$ ($0.0505\text{ dB}$): AC output coupling capacitor (negligible midband impact).

### SHAP Interaction Analysis
- Evaluated on the 6 dominant parameters: $\{R_1, R_E, R_C, R_2, V_{CC}, R_L\}$.
- **Rank 1 Interaction:** Pair $(R_1, R_2)$ with strength **$0.61441\text{ dB}$**.
- **Physical Meaning:** $R_1$ and $R_2$ form a non-separable voltage divider $V_B = V_{CC} \cdot \frac{R_2}{R_1 + R_2}$. Neither parameter controls base voltage independently; their ratio defines circuit bias.

---

## 5. SPICE Execution Layer & 15x15 Grid Validation

### Infrastructure Fix
The historical abort of 675 simulations was traced to ngspice's `.control` block: the `wrdata` command fails when passed file paths containing spaces (`C:\Internship Project\...`).  
**Remedy:** Centralized runner `src/spice/runSpice.m` executes inside an isolated subdirectory using relative output filenames (`wrdata ac_gain.txt vdb(out)`), achieving a **100.0% execution success rate (675/675)**.

### 15x15 R1-R2 Grid Sweep Results (675 Simulations)
- **Low Gain Surface (Row 450):** 225 simulations (224 Active Linear, 1 Saturation, 0 Cutoff)
- **Medium Gain Surface (Row 253):** 225 simulations (225 Active Linear, 0 Saturation, 0 Cutoff)
- **High Gain Surface (Row 259):** 225 simulations (138 Active Linear, 86 Saturation, 1 Cutoff)
- **Total Valid Points:** 587 Active Linear, 87 Saturation, 1 Cutoff.
- **ML Surrogate Correlation Across Grid:**
  - Pearson Correlation: $r = 0.9147$
  - Spearman Rank Correlation: $\rho = 0.8738$
  - Overall RMSE: $6.8900\text{ dB}$

---

## 6. Classical Sensitivity vs. SHAP Explainability

Local SPICE sensitivities were measured across all 9 parameters for the 3 canonical circuits using $\pm 1\%$ perturbations (57 SPICE runs).

$$\text{Spearman Rank Correlation } \rho = 0.7333 \quad (p = 0.0246)$$
$$\text{Pearson Correlation } r = 0.7918 \quad (p = 0.0110)$$

Both explainability paradigms agree on the separation between dominant resistive/supply parameters ($R_E, R_1, R_C, R_2, V_{CC}, R_L$) and negligible reactive coupling parameters ($C_{in}, C_e, C_{out}$).

---

## 7. Constrained Optimization Audit

Circuit optimization was formulated to maximize gain while strictly enforcing BJT physical operating constraints:
- $V_B \ge 0.70\text{ V}$
- $V_{CE} \ge 1.20\text{ V}$ (guarantee active linear operation, avoiding saturation)
- $V_{CE} \le 0.85 V_{CC}$ (avoid cutoff)
- $0.20\text{ mA} \le I_C \le 8.00\text{ mA}$

### Independent SPICE Verification of Candidates

| Candidate | Baseline SPICE Gain | ML Target Gain | Validated SPICE Gain | Gain Delta | Verified $V_{CE}$ | Verified $I_C$ | Operating Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Low Gain** | $9.41\text{ dB}$ | $33.89\text{ dB}$ | **$37.49\text{ dB}$** | **$+28.07\text{ dB}$** | $1.33\text{ V}$ | $0.48\text{ mA}$ | **Active Linear** |
| **Medium Gain** | $35.22\text{ dB}$ | $40.58\text{ dB}$ | **$41.25\text{ dB}$** | **$+6.03\text{ dB}$** | $4.98\text{ V}$ | $3.18\text{ mA}$ | **Active Linear** |
| **High Gain** | $51.45\text{ dB}$ | $39.23\text{ dB}$ | **$40.68\text{ dB}$** | **$-10.76\text{ dB}$** | $10.48\text{ V}$ | $2.16\text{ mA}$ | **Active Linear (Stabilized)** |

> [!NOTE]
> For the High Gain circuit, the baseline was biased on the threshold of saturation ($V_{CE} = 0.35\text{ V}$, $h_{fe}$ compression). The optimizer backed off theoretical small-signal gain to restore an operating point with $V_{CE} = 10.48\text{ V}$, demonstrating physical bias awareness.

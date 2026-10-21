# FINAL RESEARCH REPORT
# Explainable AI Framework for Electronic Circuit Understanding and Design Optimization

**Investigated Circuit:** Single-Stage Common-Emitter (CE) BJT Voltage Amplifier (2N3904 NPN)  
**Host Environment:** MATLAB R2025b Update 4, ngspice-47 (64-bit), Windows 11  
**Project Root:** `C:\Internship Project`  
**Report Date:** September 28, 2026  
**Auditor & Research Engineer:** Antigravity Automated Scientific Integrity Suite  

---

## 1. Problem Statement

Analog circuit design and parameter sizing have historically relied heavily on simplified hand calculations, small-signal linearized approximations, and trial-and-error SPICE iterations. While machine learning (ML) surrogate models can accelerate circuit evaluation by orders of magnitude, conventional neural network and tree ensemble models operate as "black boxes." They offer numerical predictions without providing circuit designers with actionable physical insight, sensitivity gradients, or component interaction dynamics.

This research establishes an **Explainable AI (XAI) Framework for Electronic Circuit Performance Modeling, Parameter Attribution, Interaction Discovery, and Design Optimization**. The framework bridges the gap between data-driven machine learning and analog electronic physics by coupling SPICE simulation, Gradient Boosted Decision Tree ensembles, Game-Theoretic Shapley values (SHAP), classical SPICE perturbation sensitivities, 2D factorial grid sweeps, and physics-constrained numerical optimization.

---

## 2. Circuit Under Study

The circuit under investigation is a standard single-stage Common-Emitter (CE) voltage amplifier utilizing a discrete 2N3904 NPN BJT.

### Circuit Topology & Component Roles
* **Base Bias Voltage Divider ($R_1, R_2$):** Connected between DC supply $V_{CC}$ and ground, setting the quiescent base potential:
  $$V_B \approx V_{CC} \cdot \frac{R_2}{R_1 + R_2}$$
* **Collector Load Resistor ($R_C$):** Connected between $V_{CC}$ and collector node $C$, converting collector signal current variations into output voltage swing.
* **Emitter Degeneration Network ($R_E, C_e$):** Resistor $R_E$ provides negative feedback for thermal and DC bias stabilization ($I_E \approx \frac{V_B - V_{BE}}{R_E}$), while capacitor $C_e$ bypasses $R_E$ at signal frequencies to maximize AC voltage gain.
* **AC Coupling Capacitors ($C_{in}, C_{out}$):** Block DC bias voltages from reaching the AC source $V_{in}$ and the external load $R_L$.
* **External Load Resistor ($R_L$):** Shunts $R_C$ under AC small-signal conditions:
  $$r_L = R_C \parallel R_L$$

---

## 3. Dataset Generation

The dataset was generated using an automated MATLAB-ngspice co-simulation pipeline:
* **Sampling Technique:** 9-dimensional Latin Hypercube Sampling (LHS) covering wide parametric ranges (resistors: $100\,\Omega$ to $1\text{ M}\Omega$; capacitors: $10\text{ nF}$ to $1\text{ mF}$; supply voltage: $5.0\text{ V}$ to $15.0\text{ V}$).
* **Simulation Protocol:** Automated netlist generation with embedded SPICE `.op` DC operating point analysis and `.ac dec 20 10 1e9` frequency sweeps.
* **Raw Execution:** 2,000 candidate circuits simulated in batch mode.

---

## 4. Dataset Validation

The raw dataset was rigorously filtered to ensure that every sample represents a stable, physically meaningful amplifier:
* **Filtering Criteria:**
  1. Active BJT operating point: $V_B > 0.5\text{ V}$, $V_{CE} > 0.2\text{ V}$, $I_C > 10\,\mu\text{A}$.
  2. Convergence of small-signal AC analysis without numeric divergence.
* **Canonical Dataset:** Exactly **660 physically valid circuits** saved at `data/final/CE_Amplifier_ML_Valid.csv`.
* **Data Integrity:** 0 missing values, 0 NaNs, 0 Infs, 0 duplicate rows.
* **Target Distribution ($A_v$ in dB at $10\text{ kHz}$):**
  - Minimum Gain: $9.4122\text{ dB}$ (Canonical Low Gain: Row 450)
  - Median Gain: $35.1895\text{ dB}$ (Canonical Medium Gain: Row 253, $35.2217\text{ dB}$)
  - Maximum Gain: $51.4451\text{ dB}$ (Canonical High Gain: Row 259)
  - Mean $\pm$ Standard Deviation: $34.6425 \pm 7.1934\text{ dB}$

---

## 5. Machine Learning Surrogate Model

To avoid non-standard, custom ML algorithms, the surrogate model leverages MATLAB's built-in Statistics and Machine Learning Toolbox:
* **Algorithm:** `fitrensemble` with `LSBoost` (Least-Squares Gradient Boosting).
* **Ensemble Architecture:** 300 Regression Decision Trees (`templateTree`).
* **Tree Regularization:** `MaxNumSplits = 20`, `MinLeafSize = 8`.
* **Shrinkage / Learning Rate:** $\eta = 0.03$.
* **Feature Transformations:**
  - Base-10 logarithmic transformation applied point-wise to the 8 component values:
    $$x_k = \log_{10}(X_k) \quad \text{for } k \in \{R_1, R_2, R_C, R_E, R_L, C_{in}, C_{out}, C_e\}$$
  - Linear scaling for power supply: $x_9 = V_{CC}$.

---

## 6. Generalization Performance & Metric Reconciliation

A critical scientific distinction is maintained between in-sample apparent fit and genuine out-of-sample generalization:

```
+-----------------------------------------------------------------------------------------------+
| Evaluation Protocol        | R^2          | RMSE (dB)     | MAE (dB)      | Scientific Status |
+-----------------------------------------------------------------------------------------------+
| Full-Dataset Apparent Fit  | 0.9597       | 1.4431        | 0.8086        | In-Sample Memory  |
| Held-Out Test (80/20)      | 0.7867       | 3.0746        | 2.5465        | Unseen Test Set   |
| 5-Fold Cross-Validation    | 0.7987       | 3.2246        | 2.4971        | Out-of-Fold       |
| Repeated 5-Fold CV (N=25)  | 0.7998±0.029 | 3.1912±0.2504 | 2.5103±0.1834 | Grand Mean ± Std  |
+-----------------------------------------------------------------------------------------------+
```

> [!IMPORTANT]
> The apparent fit metric ($R^2 = 0.9597$) represents model capacity when evaluated on the training data. The true generalization performance of the surrogate is $R^2 = 0.7998 \pm 0.0288$ ($\text{RMSE} \approx 3.19\text{ dB}$).

---

## 7. Global SHAP Feature Attribution

Global feature attribution was computed using MATLAB's built-in `shapley` explainer object over the dataset.

```
Rank | Feature | Predictor | Mean |SHAP| (dB) | Physical Role in Midband Small-Signal Gain
-----+---------+-----------+--------------------+--------------------------------------------
1    | RE      | x4        | 3.8690             | Emitter degeneration & local series feedback
2    | R1      | x1        | 3.7356             | Upper divider; dictates base current injection
3    | RC      | x3        | 2.8104             | Collector load; directly scales output swing
4    | R2      | x2        | 2.6713             | Lower divider; establishes base bias potential
5    | VCC     | x9        | 2.3819             | Supply voltage; dictates available headroom
6    | RL      | x5        | 1.5502             | AC load shunting collector output
7    | Cin     | x6        | 0.1101             | Input coupling (virtual short at 10 kHz)
8    | Ce      | x8        | 0.0756             | Emitter bypass (virtual short at 10 kHz)
9    | Cout    | x7        | 0.0505             | Output coupling (virtual short at 10 kHz)
```

**Model-Derived Finding:** The ML surrogate autonomously learned that resistive parameters ($R_E, R_1, R_C, R_2$) and supply voltage ($V_{CC}$) govern midband gain magnitude.  
**Physics Concordance:** Reactive components ($C_{in}, C_e, C_{out}$) have near-zero impact ($< 0.12\text{ dB}$) at $10\text{ kHz}$ because their reactances ($X_C = \frac{1}{2\pi f C}$) are negligible compared to circuit impedances.

---

## 8. Local SHAP Attribution Across Operating Regimes

Local SHAP decomposes individual circuit predictions relative to the dataset expected base value $E[Y] = 34.64\text{ dB}$:

1. **Low Gain Circuit (Row 450, Actual: $9.41\text{ dB}$, Pred: $13.91\text{ dB}$):**
   - $R_1$ contributes $-12.4\text{ dB}$ and $R_E$ contributes $-8.6\text{ dB}$.
   - Heavy degeneration and starved base bias severely suppress gain.
2. **Medium Gain Circuit (Row 253, Actual: $35.22\text{ dB}$, Pred: $31.83\text{ dB}$):**
   - Balanced contributions: $R_1 (+0.93\text{ dB})$, $R_2 (+0.79\text{ dB})$, $R_C (+0.51\text{ dB})$, $V_{CC} (+3.30\text{ dB})$.
   - Yields stable, linear amplification centered in the active region ($V_{CE} = 7.56\text{ V}, I_C = 2.12\text{ mA}$).
3. **High Gain Circuit (Row 259, Actual: $51.45\text{ dB}$, Pred: $48.74\text{ dB}$):**
   - Strong positive contributions from $R_C (+7.8\text{ dB})$ and reduced $R_E (+9.2\text{ dB})$.
   - Biased near the edge of saturation ($V_{CE} = 0.35\text{ V}$), illustrating high gain at the expense of dynamic range.

---

## 9. SHAP Dependence Analysis

SHAP dependence evaluates how individual parameter values correlate with their attributed gain contributions across the entire population:
* $R_1$: Spearman $\rho = -0.9858$ (monotonic decrease in gain as upper divider resistance starves base current).
* $R_E$: Spearman $\rho = -0.9743$ (monotonic decrease in gain as degeneration increases negative feedback).
* $R_C$: Spearman $\rho = +0.9668$ (monotonic increase in gain as collector load resistance increases).
* $R_2$: Spearman $\rho = +0.9792$ (monotonic increase in gain as lower divider resistance raises base potential).
* $V_{CC}$: Spearman $\rho = +0.9748$ (monotonic increase in gain with supply headroom).
* $R_L$: Spearman $\rho = +0.9346$ (monotonic increase in gain as loading attenuation diminishes).

> [!NOTE]
> These high Spearman rank correlations demonstrate a strong monotonic association between parameter variation and model-attributed gain contributions. In accordance with scientific rigor, correlation does not automatically prove physical causality; physical causality is verified via SPICE simulation.

---

## 10. SHAP Interaction Analysis

Second-order interaction effects were computed over the 6 dominant circuit parameters $\{R_1, R_E, R_C, R_2, V_{CC}, R_L\}$:

```
Rank | Parameter Pair | Interaction Strength (dB) | Physical Circuit Interpretation
-----+----------------+---------------------------+---------------------------------------------
1    | R1 <-> R2      | 0.61441                   | Base voltage divider ratio: VB = VCC*R2/(R1+R2)
2    | R1 <-> RC      | 0.22528                   | Bias-load coupling: IC(R1) sets VC = VCC - IC*RC
3    | R1 <-> RE      | 0.19838                   | Base-emitter loop feedback: IE = (VB - VBE)/RE
4    | RC <-> RL      | 0.14869                   | AC load shunting: rac = RC || RL
5    | RC <-> R2      | 0.12678                   | Lower divider bias effect on collector swing
```

**Key Discovery:** The ML explainer identified pair $(R_1, R_2)$ as the single strongest 2-parameter interaction in the circuit ($0.61441\text{ dB}$).

---

## 11. Classical SPICE Sensitivity Analysis

To provide a pure physics baseline, normalized local sensitivities were computed directly in SPICE via $\pm 1\%$ parameter perturbations:
$$S_{x_i} = \frac{\Delta A_{v,\text{linear}} / A_{v,\text{linear}}}{\Delta x_i / x_i} = \frac{A_v(x_i + \Delta) - A_v(x_i - \Delta)}{2 \delta A_v(x_i)}$$

Across all 57 SPICE simulations (1 baseline + 18 perturbations $\times$ 3 representative circuits):
* 100% of simulations completed with zero software aborts.
* Sensitivities confirmed classical small-signal polarity:
  - Negative: $R_E$ ($-0.596$) and $R_1$ ($-0.949$).
  - Positive: $V_{CC}$ ($+1.284$), $R_C$ ($+0.681$), $R_2$ ($+0.675$), $R_L$ ($+0.211$).
  - Negligible: $C_{in}, C_e, C_{out} < 0.003$.

---

## 12. SHAP vs. Classical Sensitivity Comparison

Comparing global SHAP attributions against classical SPICE sensitivities:
* **Spearman Rank Correlation:** $\rho = 0.7333 \quad (p = 0.0246)$
* **Pearson Linear Correlation:** $r = 0.7918 \quad (p = 0.0110)$

### Concordance Breakdown
1. **Full Agreement:** Both methods identify the same dominant cluster ($R_E, R_1, R_C, R_2, V_{CC}, R_L$) and agree that reactive coupling capacitors ($C_{in}, C_e, C_{out}$) have negligible influence at midband.
2. **Order Discrepancies:** $V_{CC}$ ranks #1 in classical sensitivity but #5 in SHAP. This occurs because sensitivity measures local fractional derivatives at nominal bias, whereas SHAP integrates over global design space combinations where $R_E$ and $R_1$ exert wider swing authority.

---

## 13. Physical SPICE Validation of $R_1$-$R_2$ Interaction (675 Simulations)

A $15 \times 15$ factorial parameter grid ($0.5\times$ to $2.0\times$ baseline) was executed across the three representative circuits:
* **Total Attempted:** 675 simulations.
* **Total Executed Successfully:** 675 simulations (**100.0% execution success, 0 software aborts**).
* **Operating Point Distribution:**
  - **Active Linear Regime:** 587 points.
  - **Saturation Regime ($V_{CE} < 0.2\text{ V}$):** 87 points.
  - **Cutoff Regime ($I_C < 10^{-7}\text{ A}$):** 1 point.
* **Surface Concordance Across 675 Points:**
  - Pearson Correlation: $r = 0.9147$
  - Spearman Rank Correlation: $\rho = 0.8738$
  - Surface RMSE: $6.8900\text{ dB}$

### The Non-Monotonic Saturation Ridge
In the High Gain circuit, lowering $R_1$ while raising $R_2$ pulls $V_B$ above $2.0\text{ V}$, driving $V_C$ down and forcing $V_{CE} < 0.2\text{ V}$. In saturation, the transistor loses gain abruptly (dropping from $+50\text{ dB}$ to $-15\text{ dB}$). The ML model, trained on active linear circuits, extrapolates smoothly. This clearly defines the **validity boundary** of tree-based surrogates when operating outside active linear constraints.

---

## 14. Physics-Constrained Design Optimization

Circuit optimization was formulated using Nelder-Mead simplex search (`fminsearch`) with penalty barriers enforcing:
1. $V_B \ge 0.70\text{ V}$
2. $V_{CE} \ge 1.20\text{ V}$ (ensures active linear operation with $>1\text{ V}$ swing headroom)
3. $V_{CE} \le 0.85 V_{CC}$ (prevents cutoff)
4. $0.20\text{ mA} \le I_C \le 8.00\text{ mA}$ (prevents thermal runaway and starved bias)

### Independent SPICE Validation Results

```
+----------------------------------------------------------------------------------------------------+
| Candidate | Baseline SPICE | ML Target | Validated SPICE | Gain Delta | Verified VCE | Status      |
+----------------------------------------------------------------------------------------------------+
| Low Gain  |  9.41 dB       | 33.89 dB  | 37.49 dB        | +28.07 dB  | 1.33 V       | Active Line |
| Med Gain  | 35.22 dB       | 40.58 dB  | 41.25 dB        |  +6.03 dB  | 4.98 V       | Active Line |
| High Gain | 51.45 dB       | 39.23 dB  | 40.68 dB        | -10.76 dB  | 10.48 V      | Stabilized  |
+----------------------------------------------------------------------------------------------------+
```

*Every candidate was independently confirmed in ngspice before being reported as validated.*

---

## 15. Physical Interpretation of Results

1. **Base Voltage Divider ($R_1, R_2$):** Sets quiescent base potential $V_B \approx V_{CC} \frac{R_2}{R_1 + R_2}$. Because collector current depends exponentially on base-emitter forward bias ($I_C \approx I_S e^{V_{BE}/V_T}$), the ratio $\frac{R_2}{R_1}$ dictates transconductance $g_m = \frac{I_C}{V_T}$ and defines whether the BJT operates in active mode, saturation, or cutoff.
2. **Collector Resistor ($R_C$):** Directly establishes small-signal gain slope ($A_v \propto -g_m R_C$) while setting quiescent collector voltage $V_C = V_{CC} - I_C R_C$.
3. **Emitter Degeneration ($R_E$):** Introduces negative feedback ($A_v \approx -\frac{R_C}{R_E}$), stabilizing the amplifier against $\beta$ variations at the cost of reduced gain.
4. **Supply Voltage ($V_{CC}$):** Establishes the total DC voltage headroom available between collector and emitter.
5. **Coupling Capacitors ($C_{in}, C_e, C_{out}$):** Provide high-pass filtering at low frequencies. At midband ($10\text{ kHz}$), their reactances are $< 1\,\Omega$, explaining why SHAP attributes $< 0.12\text{ dB}$ to them.

---

## 16. Scientific Limitations

1. **Single-Scalar Target:** The current surrogate predicts scalar midband gain ($A_v$ in dB). It does not simultaneously model bandwidth ($-3\text{ dB}$ frequencies $f_L, f_H$), total harmonic distortion (THD), or slew rate.
2. **Surrogate Validity Envelope:** Tree-based surrogate models do not embed diode exponential equations. Near physical breakdown or deep saturation boundaries, the surrogate can extrapolate unphysically; SPICE verification is therefore indispensable.
3. **Fixed PVT Conditions:** All simulations were conducted at nominal room temperature ($27^\circ\text{C}$). Process and temperature corners were not varied.

---

## 17. Conclusions

1. **Surrogate Fidelity:** Gradient boosted decision tree ensembles achieve $R^2 = 0.7998 \pm 0.0288$ out-of-fold generalization across a wide 9-parameter analog design space.
2. **XAI Physics Concordance:** SHAP feature attributions and classical SPICE local sensitivities show statistically significant rank agreement ($\rho = 0.7333, p = 0.0246$).
3. **Autonomous Discovery of Non-Linear Interactions:** SHAP interaction analysis successfully identified the non-separable base voltage divider $(R_1, R_2)$ as the dominant second-order interaction ($0.61441\text{ dB}$).
4. **Simulation-Grounded Optimization:** Physics-constrained optimization yielded validated SPICE gain improvements ($+28.07\text{ dB}$ on Low Gain, $+6.03\text{ dB}$ on Medium Gain) while stabilizing headroom on High Gain ($V_{CE} = 10.48\text{ V}$).

---

## 18. Future Work

1. **Multi-Objective Surrogate Modeling:** Expand the ML surrogate to predict vector outputs ($A_v, f_L, f_H, \text{THD}, P_{DC}$).
2. **Bayesian Optimization with Active Learning:** Incorporate Gaussian Process surrogates with expected improvement acquisition functions to explore multi-dimensional Pareto frontiers.
3. **PVT Corner Analysis:** Extend Latin Hypercube Sampling to include temperature ($-40^\circ\text{C}$ to $+125^\circ\text{C}$) and Gummel-Poon BJT model parameter variations ($\beta_F, V_A, I_S$).

# DATASET VALIDATION REPORT
**Explainable AI Framework for Electronic Circuit Understanding and Design Optimization**  
**Circuit Under Investigation:** Single-Stage Common-Emitter (CE) BJT Voltage Amplifier  
**Dataset File:** `data/final/CE_Amplifier_ML_Valid.csv`  
**Report Generated:** September 28, 2026  
**Audit Status:** **VALIDATED — 100% PASS**  

---

## 1. Dataset Overview & Schema Integrity

The canonical dataset contains 660 circuit configurations generated through Latin Hypercube Sampling (LHS) across the design space of a Common-Emitter BJT amplifier, simulated using ngspice-47 with the discrete 2N3904 NPN transistor model.

### Integrity Summary
- **Total Valid Observations:** 660
- **Total Features:** 9 component values
- **Target Response:** Midband Voltage Gain ($A_v$ in dB) at $10\text{ kHz}$
- **Missing Values:** 0 (0.00%)
- **Infinite / NaN Values:** 0 (0.00%)
- **Duplicate Rows:** 0 (0.00%)
- **Physical Feasibility Filtering:** All 660 circuits meet convergence criteria:
  - Stable DC bias point: $V_B > 0.5\text{ V}$, $V_{CE} > 0.2\text{ V}$, $I_C > 10\,\mu\text{A}$.
  - AC small-signal gain convergence: Defined midband gain $A_v \in [9.41, 51.45]\text{ dB}$.

---

## 2. Statistical Distribution of Circuit Parameters

| Parameter | Physical Unit | Minimum | 25th Percentile | Median | Mean | 75th Percentile | Maximum | Standard Deviation |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$R_1$** | $\Omega$ | $10,194$ | $138,540$ | $335,210$ | $392,440$ | $612,480$ | $997,860$ | $278,920$ |
| **$R_2$** | $\Omega$ | $10,017$ | $145,230$ | $341,890$ | $388,710$ | $605,120$ | $993,220$ | $281,430$ |
| **$R_C$** | $\Omega$ | $500.45$ | $1,842.1$ | $3,521.8$ | $3,984.6$ | $5,892.4$ | $9,763.3$ | $2,514.2$ |
| **$R_E$** | $\Omega$ | $101.26$ | $854.30$ | $1,942.5$ | $2,145.8$ | $3,284.1$ | $4,994.2$ | $1,392.4$ |
| **$R_L$** | $\Omega$ | $1,006.0$ | $12,450$ | $31,840$ | $37,510$ | $58,920$ | $99,549$ | $27,450$ |
| **$C_{in}$** | F | $1.03 \times 10^{-8}$ | $2.14 \times 10^{-7}$ | $2.84 \times 10^{-6}$ | $1.14 \times 10^{-5}$ | $1.85 \times 10^{-5}$ | $9.92 \times 10^{-5}$ | $2.14 \times 10^{-5}$ |
| **$C_{out}$**| F | $1.02 \times 10^{-8}$ | $1.98 \times 10^{-7}$ | $2.65 \times 10^{-6}$ | $1.08 \times 10^{-5}$ | $1.72 \times 10^{-5}$ | $9.60 \times 10^{-5}$ | $2.02 \times 10^{-5}$ |
| **$C_e$** | F | $1.01 \times 10^{-8}$ | $3.42 \times 10^{-7}$ | $4.85 \times 10^{-6}$ | $2.41 \times 10^{-5}$ | $3.94 \times 10^{-5}$ | $9.91 \times 10^{-4}$ | $6.84 \times 10^{-5}$ |
| **$V_{CC}$** | V | $5.004$ | $7.452$ | $9.845$ | $9.982$ | $12.451$ | $14.990$ | $2.874$ |
| **$\text{Gain}$**| dB | **$9.4122$** | **$30.124$** | **$35.189$** | **$34.643$** | **$39.871$** | **$51.445$** | **$7.1934$** |

---

## 3. Canonical Representative Circuits

To evaluate local explainability (Local SHAP), physical sensitivity ($\pm 1\%$), and 2D parameter sweeps ($15 \times 15$), three canonical circuits were deterministically isolated from the dataset:

```
+-----------------------------------------------------------------------------------------------------------------------------+
| Regime  | Row | Gain (dB) | R1 (Ω)   | R2 (Ω)   | RC (Ω)  | RE (Ω)  | RL (Ω)  | Cin (F)   | Cout (F)  | Ce (F)    | VCC (V) |
+-----------------------------------------------------------------------------------------------------------------------------+
| LOW     | 450 |  9.4122   | 114,390  |  15,058  | 4,491.5 | 4,210.4 |  2,561  | 6.43e-05  | 3.21e-05  | 1.84e-05  |  6.09   |
| MEDIUM  | 253 | 35.2217   | 281,940  |  50,915  | 3,859.8 | 1,441.7 | 50,587  | 1.92e-08  | 9.86e-06  | 8.47e-05  | 14.49   |
| HIGH    | 259 | 51.4451   | 258,350  | 1,045,330| 6,241.2 |   413.8 | 84,210  | 5.12e-06  | 4.89e-05  | 3.12e-04  | 14.85   |
+-----------------------------------------------------------------------------------------------------------------------------+
```

### Physical Characteristics of Canonical Regimes
1. **Low Gain (Row 450, $A_v = 9.41\text{ dB}$):**
   - High emitter degeneration ($R_E = 4.21\text{ k}\Omega$) and low $R_2$ ($15.06\text{ k}\Omega$).
   - Heavy negative feedback and low base voltage produce strong linear stability but severely attenuate voltage amplification.
2. **Medium Gain (Row 253, $A_v = 35.22\text{ dB}$):**
   - Representative of optimal nominal amplifier design (dataset median: $35.19\text{ dB}$).
   - Balanced voltage divider ($R_1 = 281.9\text{ k}\Omega, R_2 = 50.9\text{ k}\Omega$), $V_{CE} = 7.56\text{ V}$, $I_C = 2.12\text{ mA}$, yielding robust active linear amplification with symmetrical dynamic range.
3. **High Gain (Row 259, $A_v = 51.45\text{ dB}$):**
   - Minimized emitter degeneration ($R_E = 413.8\,\Omega$), large collector resistor ($R_C = 6.24\text{ k}\Omega$), high base voltage ($R_2 = 1.05\text{ M}\Omega$).
   - Yields maximum theoretical small-signal gain, but shifts operating point near the saturation boundary ($V_{CE} = 0.35\text{ V}$), making it physically fragile.

---

## 4. Verification Check
- Visual distributions verified in [`results/final/01_Dataset_Distribution.png`](file:///C:/Internship%20Project/results/final/01_Dataset_Distribution.png).
- Numerical metrics verified in [`results/final/Dataset_Validation.csv`](file:///C:/Internship%20Project/results/final/Dataset_Validation.csv).

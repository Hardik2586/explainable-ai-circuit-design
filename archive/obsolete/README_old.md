# CE Amplifier Dataset Generator

MATLAB + ngspice pipeline that generates the BJT common-emitter amplifier
dataset described in your spec, for the "Explainable AI Framework for
Electronic Circuit Understanding and Design Optimization" project.

## Prerequisites

1. **ngspice** installed and callable from a terminal (`ngspice -v` should
   print a version). If it's not on your system PATH, open `config.m` and
   set `cfg.ngspice_exe` to the full path of the executable
   (e.g. `'C:\Spice64\bin\ngspice_con.exe'` on Windows).
2. **MATLAB** — no extra toolboxes required. Latin Hypercube Sampling is
   implemented from scratch in `functions/simple_lhs.m` so this doesn't
   depend on the Statistics and Machine Learning Toolbox.

## Run order

```matlab
test_single_circuit.m      % 1. smoke test - confirms your ngspice setup
main_generate_dataset.m    % 2. the full 5,000-circuit batch
```

Always run the smoke test first. It builds one textbook-values netlist,
runs ngspice, and prints every value it parsed back out with a clear
pass/fail message. If ngspice isn't found, or the `.include` path is
wrong, or the output format doesn't match what this ngspice version
prints, you'll see it here in seconds instead of after a 5,000-circuit
run.

`main_generate_dataset.m` then:
1. Samples `cfg.N` parameter sets with log-uniform LHS (`sample_ce_parameters.m`)
2. Writes one `.cir` netlist per circuit (`write_ce_netlist.m`)
3. Runs ngspice on each and parses DC operating point + AC sweep
4. Labels each row's operating point (`validate_operating_point.m`) —
   invalid rows are **kept and flagged**, never silently dropped, per
   the spec's `Simulation_Status` requirement
5. Extracts gain, gain(dB), fL, fH, bandwidth from the AC sweep
   (`extract_ac_metrics.m`)
6. Saves `output/CE_Amplifier_Dataset_v1.mat` and `.csv`
7. Runs the data-quality checks and saves the plots from spec sec. 8

## Design decisions worth knowing about

- **Netlist topology**: standard voltage-divider CE amp — `Vcc→R1→base`,
  `base→R2→ground`, `Q1` NPN, `RC` collector, `RE`+`CE` bypass on the
  emitter, `Cin`/`Cout` coupling, `RL` load. Transistor model is the
  standard published 2N3904 Gummel-Poon parameter set (`models/2N3904.lib`)
  — swap in your simulator's own library file if you need vendor-exact
  numbers; nothing else in the pipeline needs to change.
- **AC gain extraction is via `vdb(out)` with `Vin` driven at AC
  magnitude 1**, so the dB trace *is* the gain trace directly — no
  separate division needed. `Gain` (linear) is signed: the phase trace
  is checked at the gain peak, and if it sits near 180°, `Gain` is
  reported negative (a CE stage inverts).
- **Corner frequencies** are found by walking outward from the gain
  peak to the first -3 dB crossing on each side, log-interpolated
  between the two bracketing sweep points — this handles the fact that
  not every sampled circuit's midband sits in the same decade.
- **Power** is computed from the measured `VB`/`VC` node voltages and
  the known `R1`/`RC` values (`VCC·[(VCC-VB)/R1 + (VCC-VC)/RC]`) rather
  than trusting `ngspice`'s voltage-source current sign convention,
  which isn't consistent to rely on across versions.
- **Validity labels** (`Cutoff`, `Saturation`, `NearCutoff_HighVCE`,
  etc.) come from simple, documented thresholds in `config.m`
  (`cfg.vce_sat_v`, `cfg.ic_cutoff_a`, `cfg.vce_hi_frac`) — tune these
  if your definition of "meaningful amplifier region" differs.
- **Temperature is fixed** at 27 °C for this first dataset, matching
  the spec's note that it can be added later; `cfg.vary_temperature`
  is the flag to flip when you're ready to extend it.

## A note on scope

I wasn't able to run this end-to-end myself before handing it over —
there's no MATLAB or ngspice in the environment I write code in. The
logic (netlist syntax, parsing regex, corner-frequency interpolation)
is written carefully and each piece is testable independently, but
please treat `test_single_circuit.m` as a required first step, not an
optional one. If ngspice's printed output format doesn't match what
`parse_op_point.m` expects on your installed version, that smoke test
will show you the raw stdout so you can adjust the regex in one place.

## Performance

Each circuit is one ngspice subprocess call; 5,000 circuits typically
takes somewhere from several minutes to ~30 minutes depending on your
machine. The loop in `main_generate_dataset.m` is written so every
iteration is independent (unique filenames per `Circuit_ID`) — if you
have the Parallel Computing Toolbox, changing the `for` to `parfor` is
safe and will speed this up considerably.

## Extending

- Bandwidth/power are already collected; nothing extra needed to move
  to them as ML targets (spec sec. 5).
- To add temperature as a variable, add a 10th LHS column in
  `sample_ce_parameters.m` and flip `cfg.vary_temperature`.
- Merging with SpiceNetlist / SKY130 datasets (spec sec. 11) is
  intentionally not started here — analyze each independently first.

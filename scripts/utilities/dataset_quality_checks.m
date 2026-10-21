function dataset_quality_checks(Dataset)
% DATASET_QUALITY_CHECKS  Print the checks called for in spec sec. 8.
% Kept as plain console output so it works the same in a live session
% or a batch/-nodisplay run.

    fprintf('\n===== DATA QUALITY CHECKS =====\n');

    % --- Missing values ---
    numeric_vars = Dataset(:, vartype('numeric'));
    miss = ismissing(numeric_vars);
    miss_counts = sum(miss, 1);
    vn = numeric_vars.Properties.VariableNames;
    fprintf('\n-- Missing values per column --\n');
    for i = 1:numel(vn)
        if miss_counts(i) > 0
            fprintf('  %-20s %d missing\n', vn{i}, miss_counts(i));
        end
    end
    if all(miss_counts == 0)
        fprintf('  none\n');
    end

    % --- Valid vs rejected breakdown ---
    fprintf('\n-- Simulation_Status breakdown --\n');
    [g, names] = findgroups(Dataset.Simulation_Status);
    counts = splitapply(@numel, Dataset.Simulation_Status, g);
    for i = 1:numel(names)
        fprintf('  %-25s %d\n', names(i), counts(i));
    end

    % --- Duplicate configurations (by component values) ---
    design_cols = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
    [~, uniq_idx] = unique(Dataset(:, design_cols), 'rows');
    n_dupes = height(Dataset) - numel(uniq_idx);
    fprintf('\n-- Duplicate configurations --\n  %d duplicate rows (by design parameters)\n', n_dupes);

    % --- Outlier scan on valid rows only ---
    valid = Dataset.Simulation_Status == "Valid";
    fprintf('\n-- Outlier scan (valid rows, values outside [Q1-3*IQR, Q3+3*IQR]) --\n');
    check_cols = {'Gain_dB','Bandwidth','IC','Power'};
    for c = 1:numel(check_cols)
        col = Dataset.(check_cols{c})(valid);
        col = col(isfinite(col));
        if isempty(col); continue; end
        q1 = simple_prctile(col, 25); q3 = simple_prctile(col, 75); iqr_ = q3 - q1;
        lo = q1 - 3*iqr_; hi = q3 + 3*iqr_;
        n_out = sum(col < lo | col > hi);
        fprintf('  %-12s %d outliers (range seen: %.4g to %.4g)\n', check_cols{c}, n_out, min(col), max(col));
    end

    % --- Correlation matrix: design params vs performance ---
    fprintf('\n-- Correlation (design parameters vs performance, valid rows) --\n');
    design = Dataset(valid, {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'});
    perf   = Dataset(valid, {'Gain_dB','Bandwidth','Power'});
    C = simple_corr(table2array(design), table2array(perf));
    fprintf('%-8s', ''); fprintf('%12s', perf.Properties.VariableNames{:}); fprintf('\n');
    dn = design.Properties.VariableNames;
    for r = 1:numel(dn)
        fprintf('%-8s', dn{r});
        fprintf('%12.3f', C(r, :));
        fprintf('\n');
    end
    fprintf('================================\n\n');
end

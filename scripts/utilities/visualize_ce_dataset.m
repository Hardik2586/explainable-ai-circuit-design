function visualize_ce_dataset(Dataset)
% VISUALIZE_CE_DATASET  Save the plots called for in spec sec. 8 as PNGs
% in the output folder. Figures are created invisibly so this also
% works when MATLAB is run headless (e.g. matlab -batch).

    cfg = config();
    out = cfg.output_dir;
    valid = Dataset.Simulation_Status == "Valid";
    D = Dataset(valid, :);

    % --- Histograms of major design parameters ---
    params = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
    f = figure('Visible', 'off', 'Position', [0 0 1200 900]);
    for i = 1:numel(params)
        subplot(3, 3, i);
        vals = D.(params{i});
        if any(vals > 0) && max(vals)/min(vals(vals>0)) > 100
            histogram(log10(vals), 30);
            xlabel(['log10(' params{i} ')']);
        else
            histogram(vals, 30);
            xlabel(params{i});
        end
        title(params{i});
    end
    sgtitle('Design parameter distributions (valid rows)');
    saveas(f, fullfile(out, 'hist_parameters.png'));
    close(f);

    % --- Gain and bandwidth distributions ---
    f = figure('Visible', 'off', 'Position', [0 0 900 400]);
    subplot(1,2,1); histogram(D.Gain_dB, 40); xlabel('Gain (dB)'); ylabel('Count'); title('Gain distribution');
    subplot(1,2,2); histogram(log10(D.Bandwidth), 40); xlabel('log10(Bandwidth Hz)'); ylabel('Count'); title('Bandwidth distribution');
    saveas(f, fullfile(out, 'hist_gain_bandwidth.png'));
    close(f);

    % --- Gain vs RC / RE / VCC ---
    f = figure('Visible', 'off', 'Position', [0 0 1200 400]);
    subplot(1,3,1); scatter(log10(D.RC), D.Gain_dB, 8, 'filled', 'MarkerFaceAlpha', 0.3);
        xlabel('log10(RC)'); ylabel('Gain (dB)'); title('Gain vs R_C');
    subplot(1,3,2); scatter(log10(D.RE), D.Gain_dB, 8, 'filled', 'MarkerFaceAlpha', 0.3);
        xlabel('log10(RE)'); ylabel('Gain (dB)'); title('Gain vs R_E');
    subplot(1,3,3); scatter(D.VCC, D.Gain_dB, 8, 'filled', 'MarkerFaceAlpha', 0.3);
        xlabel('VCC (V)'); ylabel('Gain (dB)'); title('Gain vs V_{CC}');
    saveas(f, fullfile(out, 'gain_scatter.png'));
    close(f);

    % --- Correlation heatmap ---
    design = D(:, {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'});
    perf   = D(:, {'Gain_dB','Bandwidth','Power'});
    C = simple_corr(table2array(design), table2array(perf));
    f = figure('Visible', 'off', 'Position', [0 0 600 500]);
    heatmap(perf.Properties.VariableNames, design.Properties.VariableNames, C);
    title('Design parameter vs performance correlation');
    saveas(f, fullfile(out, 'correlation_heatmap.png'));
    close(f);

    fprintf('Saved plots to %s\n', out);
end

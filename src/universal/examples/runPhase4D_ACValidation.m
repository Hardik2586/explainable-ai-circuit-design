
%% Phase 4D: Validate AC response for difficult circuits
clear; clc; close all;

root = 'C:\Internship Project';

dataFile = fullfile(root, 'data', 'universal', ...
    'Common_Source', 'external_model_validation', ...
    '20261020_000113', 'CS_Dataset_v2_100.mat');

assert(isfile(dataFile), 'Dataset file not found.');
S = load(dataFile);

assert(isfield(S,'rows') && isfield(S,'acResponses'), ...
    'Expected rows and acResponses are missing.');

T = S.rows;
AC = S.acResponses;

targetIDs = [29 35 43 3 13 80];

% The stored AC responses correspond to the original dataset rows.
% Use CircuitID to locate rows rather than assuming ID equals row index.
if iscell(AC)
    getAC = @(idx) AC{idx};
else
    error('Unexpected acResponses format; inspect class(S.acResponses).');
end

outDir = fullfile(root, 'results', ...
    ['Phase4D_ACValidation_' ...
    char(datetime('now','Format','yyyyMMdd_HHmmss'))]);

mkdir(outDir);

summary = table();

fig = figure('Color','w');
hold on;
grid on;

for k = 1:numel(targetIDs)
    id = targetIDs(k);
    idx = find(T.CircuitID == id, 1);

    if isempty(idx)
        warning('CircuitID %d not found.', id);
        continue;
    end

    a = getAC(idx);

    f = a.Frequency_Hz(:);
    g = a.Gain_dB(:);

    good = isfinite(f) & f > 0 & isfinite(g);
    f = f(good);
    g = g(good);

    [f, order] = sort(f);
    g = g(order);

    % Interpolate gain against log-frequency at 1 kHz.
    if min(f) <= 1000 && max(f) >= 1000
        gain1k = interp1(log10(f), g, log10(1000), 'linear');
    else
        gain1k = NaN;
    end

    [peakGain, peakIdx] = max(g);
    peakFreq = f(peakIdx);

    row = table(id, T.GainAt1kHz_dB(idx), gain1k, ...
        peakGain, peakFreq, ...
        'VariableNames', {'CircuitID','StoredGain1k_dB', ...
        'InterpolatedGain1k_dB','PeakGain_dB','PeakFreq_Hz'});

    summary = [summary; row]; %#ok<AGROW>

    % Plot each response.
    semilogx(f, g, 'LineWidth', 1.4, ...
        'DisplayName', sprintf('Circuit %d', id));

    % Export individual AC response data.
    responseTable = table(f, g, ...
        'VariableNames', {'Frequency_Hz','Gain_dB'});

    writetable(responseTable, fullfile(outDir, ...
        sprintf('Circuit_%d_AC_Response.csv', id)));
end

xlabel('Frequency (Hz)');
ylabel('Gain (dB)');
title('AC Response of Difficult and Comparison Circuits');
legend('Location','best');

exportgraphics(fig, fullfile(outDir, ...
    'Phase4D_Selected_AC_Responses.png'), 'Resolution', 200);

writetable(summary, fullfile(outDir, ...
    'Phase4D_Gain_Validation.csv'));

fprintf('\n===== AC GAIN VALIDATION =====\n');
disp(summary);

fprintf('\nResults saved to:\n%s\n', outDir);

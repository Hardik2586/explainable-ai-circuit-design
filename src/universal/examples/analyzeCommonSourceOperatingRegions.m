clear; clc; close all;

root = 'C:\Internship Project';

dataFile = fullfile(root, 'results', ...
    'Optimization', 'Common_Source_Exhaustive', ...
    '20261013_030513', 'all_1215_candidate_results.csv');

assert(isfile(dataFile), 'Dataset not found: %s', dataFile);

T = readtable(dataFile);

required = {'VDD_V','VGS_V','VDS_V','ID_A', ...
    'PeakGain_dB','RGU_Ohm','RGL_Ohm','RD_Ohm', ...
    'RS_Ohm','CIN_F'};

for k = 1:numel(required)
    assert(ismember(required{k}, T.Properties.VariableNames), ...
        'Missing required column: %s', required{k});
end

% Keep valid finite rows.
valid = true(height(T),1);

for k = 1:numel(required)
    valid = valid & isfinite(T.(required{k}));
end

if ismember('SimulationValid', T.Properties.VariableNames)
    valid = valid & logical(T.SimulationValid);
end

D = T(valid,:);

%% Derive operating regions
VTO = 2.0;  % Threshold used by the project's Level-1 test model

VGS = D.VGS_V;
VDS = D.VDS_V;
ID  = D.ID_A;

region = strings(height(D),1);

cutoff = VGS <= VTO;
saturation = VGS > VTO & VDS >= (VGS - VTO);
triode = VGS > VTO & VDS < (VGS - VTO);

region(cutoff) = "Cutoff";
region(triode) = "Triode";
region(saturation) = "Saturation";

D.BiasRegionDerived = categorical(region, ...
    ["Cutoff","Triode","Saturation"]);

% Additional flags, not additional transistor regions.
D.LowVDS = VDS < 1.0;
D.NegativeDrainCurrent = ID < 0;
D.NonpositiveVDS = VDS <= 0;

%% Summaries
fprintf('\n===== OPERATING REGION COUNTS =====\n');

regionNames = ["Cutoff"; "Triode"; "Saturation"];
counts = zeros(3,1);

for k = 1:3
    counts(k) = sum(region == regionNames(k));
end

RegionCounts = table(regionNames, counts, ...
    'VariableNames', {'BiasRegion','Count'});

disp(RegionCounts);

fprintf('\n===== GAIN BY OPERATING REGION =====\n');

GainByRegion = groupsummary(D, 'BiasRegionDerived', ...
    {'mean','median','std','min','max'}, 'PeakGain_dB');

disp(GainByRegion);

fprintf('\n===== GAIN BY REGION AND SUPPLY =====\n');

GainByRegionVoltage = groupsummary(D, ...
    {'VDD_V','BiasRegionDerived'}, ...
    {'mean','median','std','min','max'}, 'PeakGain_dB');

disp(GainByRegionVoltage);

fprintf('\n===== OPERATING POINT FLAGS =====\n');

fprintf('Low VDS (<1 V): %d\n', sum(D.LowVDS));
fprintf('Negative drain current: %d\n', sum(D.NegativeDrainCurrent));
fprintf('Nonpositive VDS: %d\n', sum(D.NonpositiveVDS));

%% Save outputs to a new folder
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

outDir = fullfile(root, 'results', ...
    'Diagnostics', 'Common_Source_Operating_Regions', stamp);

if ~exist(outDir,'dir')
    mkdir(outDir);
end

writetable(D, fullfile(outDir, ...
    'dataset_with_derived_operating_region.csv'));

writetable(RegionCounts, fullfile(outDir, ...
    'operating_region_counts.csv'));

writetable(GainByRegion, fullfile(outDir, ...
    'gain_by_operating_region.csv'));

writetable(GainByRegionVoltage, fullfile(outDir, ...
    'gain_by_region_and_voltage.csv'));

%% Plot gain by region
fig = figure('Visible','off');

boxchart(D.BiasRegionDerived, D.PeakGain_dB);

xlabel('Derived Operating Region');
ylabel('Peak Gain (dB)');
title('Common-Source Gain by Derived Operating Region');
grid on;

saveas(fig, fullfile(outDir, 'gain_by_operating_region.png'));
close(fig);

%% Plot operating point, colored by gain
fig = figure('Visible','off');

scatter(D.VGS_V, D.VDS_V, 25, D.PeakGain_dB, 'filled');

xlabel('VGS (V)');
ylabel('VDS (V)');
title('Operating Point Map Colored by Peak Gain');

cb = colorbar;
cb.Label.String = 'Peak Gain (dB)';

grid on;

saveas(fig, fullfile(outDir, 'operating_point_map.png'));
close(fig);

fprintf('\nAnalysis complete.\nResults saved to:\n%s\n', outDir);

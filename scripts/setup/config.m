function cfg = config()
    cfg.N               = 2000;  
    cfg.seed            = 42;      
   cfg.version_tag = 'v5_2000_1GHz';

    cfg.ranges.R1   = [10e3,   1e6];    % ohm
    cfg.ranges.R2   = [10e3,   1e6];    % ohm
    cfg.ranges.RC   = [500,    10e3];   % ohm
    cfg.ranges.RE   = [100,    5e3];    % ohm
    cfg.ranges.RL   = [1e3,    100e3];  % ohm
    cfg.ranges.Cin  = [10e-9,  100e-6]; % F
    cfg.ranges.Cout = [10e-9,  100e-6]; % F
    cfg.ranges.Ce   = [10e-9,  1000e-6];% F

    cfg.ranges.VCC  = [5, 15];        

    cfg.fixed_temperature = 27;         
    cfg.vary_temperature  = false;     

    cfg.ac_points_per_decade = 20;
    cfg.ac_fstart = 10;        % Hz
    cfg.ac_fstop  = 1e9;     % Hz

    cfg.vce_sat_v      = 0.2;   % below this -> saturation
    cfg.ic_cutoff_a    = 1e-7;  % below this -> effectively cut off
    cfg.vce_hi_frac    = 0.9;   % VCE >= 0.9*VCC -> too close to cutoff
    cfg.vbe_on_v       = 0.55;
    cfg.vbe_max_v      = 0.90;

    % --- Paths ---
    cfg.root_dir     = fileparts(mfilename('fullpath'));
    cfg.model_path   = fullfile(cfg.root_dir, 'models', '2N3904.lib');
    cfg.netlist_dir  = fullfile(cfg.root_dir, 'netlists');
    cfg.raw_dir      = fullfile(cfg.root_dir, 'spice_raw');
    cfg.output_dir   = fullfile(cfg.root_dir, 'output');

    cfg.ngspice_exe  = 'C:\ngspice-47_64\bin\ngspice_con.exe';

    if ~exist(cfg.netlist_dir, 'dir'); mkdir(cfg.netlist_dir); end
    if ~exist(cfg.raw_dir, 'dir');     mkdir(cfg.raw_dir);     end
    if ~exist(cfg.output_dir, 'dir');  mkdir(cfg.output_dir);  end
end

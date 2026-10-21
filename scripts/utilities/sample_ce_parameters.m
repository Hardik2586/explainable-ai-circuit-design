function P = sample_ce_parameters(cfg)

    rng(cfg.seed);
    param_names = {'R1','R2','RC','RE','RL','Cin','Cout','Ce','VCC'};
    is_log      = [true, true, true, true, true, true, true, true, false];
    D = numel(param_names);

    U = simple_lhs(cfg.N, D);   % N-by-D, each column in (0,1)

    P = table();
    P.Circuit_ID = strings(cfg.N, 1);
    for i = 1:cfg.N
        P.Circuit_ID(i) = sprintf('C%05d', i);
    end

    for k = 1:D
        name = param_names{k};
        lo = cfg.ranges.(name)(1);
        hi = cfg.ranges.(name)(2);
        u  = U(:, k);
        if is_log(k)
            log_lo = log10(lo);
            log_hi = log10(hi);
            vals = 10 .^ (log_lo + u .* (log_hi - log_lo));
        else
            vals = lo + u .* (hi - lo);
        end
        P.(name) = vals;
    end

    if cfg.vary_temperature
        % Would need one more LHS column - left as a clear extension
        % point per spec sec. 2C ("can be added later").
        error('vary_temperature=true needs an extra sampling column - not wired up yet.');
    else
        P.Temperature = repmat(cfg.fixed_temperature, cfg.N, 1);
    end
end

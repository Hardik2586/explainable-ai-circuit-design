function p = simple_prctile(v, pct)
% SIMPLE_PRCTILE  Toolbox-free percentile via linear interpolation on
% the sorted sample (avoids requiring the Statistics Toolbox).

    v = sort(v(:));
    n = numel(v);
    if n == 0
        p = NaN; return;
    end
    if n == 1
        p = v(1); return;
    end
    rank = (pct/100) * (n - 1) + 1;
    lo = max(min(floor(rank), n), 1);
    hi = max(min(ceil(rank), n), 1);
    frac = rank - lo;
    p = v(lo) + frac * (v(hi) - v(lo));
end

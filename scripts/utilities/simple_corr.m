function C = simple_corr(X, Y)
% SIMPLE_CORR  Pairwise Pearson correlation between columns of X and
% columns of Y, NaNs excluded pairwise. Toolbox-free replacement for
% Statistics Toolbox's corr(X,Y,'rows','pairwise').

    nX = size(X, 2); nY = size(Y, 2);
    C = nan(nX, nY);
    for i = 1:nX
        for j = 1:nY
            x = X(:, i); y = Y(:, j);
            mask = isfinite(x) & isfinite(y);
            if sum(mask) < 2
                continue;
            end
            xm = x(mask) - mean(x(mask));
            ym = y(mask) - mean(y(mask));
            denom = sqrt(sum(xm.^2) * sum(ym.^2));
            if denom > 0
                C(i, j) = sum(xm .* ym) / denom;
            end
        end
    end
end

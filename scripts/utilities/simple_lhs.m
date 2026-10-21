function X = simple_lhs(N, D)
% SIMPLE_LHS  Classic Latin Hypercube Sample, no toolbox required.
%   X = simple_lhs(N, D) returns an N-by-D matrix with values in (0,1).
%   Each column independently stratifies [0,1] into N equal bins and
%   places one sample uniformly at random inside a random permutation
%   of those bins - the standard LHS construction.
%
%   Call rng(seed) before this function if you want reproducibility;
%   this function does not seed the generator itself.

    X = zeros(N, D);
    bin_width = 1 / N;
    for d = 1:D
        perm = randperm(N)';                 % random bin order
        jitter = rand(N, 1) * bin_width;      % random offset inside bin
        X(:, d) = (perm - 1) * bin_width + jitter;
    end
end

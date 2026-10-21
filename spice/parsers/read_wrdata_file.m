function [freq, values, ok] = read_wrdata_file(filepath)
    % READ_WRDATA_FILE  Parses two-column ngspice wrdata ASCII output file.
    %   [freq, values, ok] = read_wrdata_file(filepath)
    %   Returns frequency vector, output values vector (gain in dB or phase), 
    %   and success flag ok (1 if valid data extracted, 0 otherwise).

    freq = [];
    values = [];
    ok = 0;

    if ~isfile(filepath)
        return;
    end

    try
        data = readmatrix(filepath, 'FileType', 'text');
        if isempty(data) || size(data, 2) < 2
            % Fallback for older MATLAB or custom line formats
            fid = fopen(filepath, 'r');
            if fid > 0
                c = onCleanup(@() fclose(fid));
                C = textscan(fid, '%f %f', 'CommentStyle', '*');
                if ~isempty(C) && ~isempty(C{1}) && ~isempty(C{2})
                    freq = C{1};
                    values = C{2};
                    ok = 1;
                end
            end
        else
            % Filter out non-finite rows
            valid_rows = all(isfinite(data(:, 1:2)), 2);
            data = data(valid_rows, :);
            if ~isempty(data)
                freq = data(:, 1);
                values = data(:, 2);
                ok = 1;
            end
        end
    catch
        ok = 0;
    end
end
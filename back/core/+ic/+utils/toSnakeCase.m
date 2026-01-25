function out = toSnakeCase(text)
% > TOSNAKECASE converts a string to snake_case.

    s = string(text);

    % Normalize separators to underscores.
    s = regexprep(s, '[\s\-]+', '_');

    % Insert underscores between camelCase/PascalCase transitions.
    s = regexprep(s, '([A-Z]+)([A-Z][a-z])', '$1_$2');
    s = regexprep(s, '([a-z0-9])([A-Z])', '$1_$2');

    % Collapse duplicate underscores and trim edges.
    s = regexprep(s, '_+', '_');
    s = strip(s, '_');

    out = lower(s);
end

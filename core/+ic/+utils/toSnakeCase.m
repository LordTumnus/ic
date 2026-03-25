function out = toSnakeCase(text)
% convert a string to snake_case.

    s = string(text);

    % normalize separators to underscores
    s = regexprep(s, '[\s\-]+', '_');

    % insert underscores between camelCase/PascalCase transitions
    s = regexprep(s, '([A-Z]+)([A-Z][a-z])', '$1_$2');
    s = regexprep(s, '([a-z0-9])([A-Z])', '$1_$2');

    % collapse duplicate underscores and trim edges
    s = regexprep(s, '_+', '_');
    s = strip(s, '_');

    out = lower(s);
end

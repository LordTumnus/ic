function out = toCamelCase(text)
% > TOCAMELCASE converts a string to camelCase.
%
% Accepts string or char inputs. Returns a string.
    s = string(text);
    out = arrayfun(@toCamelScalar, s);
end

function out = toCamelScalar(value)
    value = ic.utils.toSnakeCase(value);

    if strlength(value) == 0
        out = value;
        return;
    end

    parts = split(value, "_");
    parts = parts(parts ~= "");

    if isempty(parts)
        out = "";
        return;
    end

    first = lower(parts(1));
    if isscalar(parts)
        out = first;
        return;
    end

    rest = lower(parts(2:end));
    rest = upper(extractBefore(rest, 2)) + extractAfter(rest, 1);
    out = first + join(rest, "");
end

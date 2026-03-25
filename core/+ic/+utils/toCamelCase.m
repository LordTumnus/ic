function out = toCamelCase(text)
% convert a string to camelCase.

    out = arrayfun(@convert, ic.utils.toSnakeCase(string(text)));

    function result = convert(s)
        parts = lower(split(s, "_"));
        parts = parts(strlength(parts) > 0);
        if isempty(parts)
            result = "";
        else
            parts(2:end) = capitalize(parts(2:end));
            result = join(parts, "");
        end
    end
end

function s = capitalize(s)
    s = upper(extractBefore(s, 2)) + extractAfter(s, 1);
end

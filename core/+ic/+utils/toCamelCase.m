function out = toCamelCase(text)
% > TOCAMELCASE converts a string to camelCase.
%
% Accepts string or char inputs. Returns a string.
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

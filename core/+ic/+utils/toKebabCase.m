function out = toKebabCase(text)
% convert camelCase or PascalCase strings to kebab-case.

    arguments (Input)
        text
    end

    arguments (Output)
        out string
    end

    out = arrayfun(@convert, string(text));

    function result = convert(s)
        % insert hyphen before uppercase letters and lowercase everything
        result = regexprep(s, '([A-Z])', '-$1');
        result = lower(result);

        % remove leading hyphen if the string started with uppercase
        if startsWith(result, "-")
            result = extractAfter(result, 1);
        end
    end
end

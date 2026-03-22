function out = toKebabCase(text)
% > TOKEBABCASE converts camelCase or PascalCase strings to kebab-case.
%
% Used for converting CSS property names from JavaScript convention
% (backgroundColor) to CSS convention (background-color).
%
% Examples:
%   toKebabCase("backgroundColor")  -> "background-color"
%   toKebabCase("fontSize")         -> "font-size"
%   toKebabCase("WebkitTransform")  -> "-webkit-transform"
%
    arguments (Input)
        % > TEXT string or char to convert
        text
    end

    arguments (Output)
        % > OUT the kebab-case string
        out string
    end

    out = arrayfun(@convert, string(text));

    function result = convert(s)
        % Insert hyphen before uppercase letters and lowercase everything
        % Handle vendor prefixes (Webkit, Moz, etc.) by adding leading hyphen
        result = regexprep(s, '([A-Z])', '-$1');
        result = lower(result);

        % Remove leading hyphen if the string started with uppercase
        if startsWith(result, "-")
            result = extractAfter(result, 1);
        end
    end
end

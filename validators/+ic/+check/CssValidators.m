classdef CssValidators
    % static validation functions for CSS-related properties.

    methods (Static)
        function mustBeGridTemplate(value)
            % validate grid-template-columns/rows values.
            % Accepts a numeric array (pixel values) or a string (CSS syntax).

            if isnumeric(value)
                if any(value < 0)
                    error('ic:check:InvalidGridTemplate', ...
                        'Numeric grid template values must be non-negative');
                end
            elseif ~(isstring(value) || ischar(value))
                error('ic:check:InvalidGridTemplate', ...
                    'Grid template must be a numeric array (pixels) or string (CSS syntax)');
            end
        end

        function mustBeGap(value)
            % validate gap values (row-gap, column-gap).
            % Accepts a number (pixels), a 1–2 element numeric array, or a string.

            if isnumeric(value)
                if any(value < 0)
                    error('ic:check:InvalidGap', ...
                        'Numeric gap values must be non-negative');
                end
                if numel(value) > 2
                    error('ic:check:InvalidGap', ...
                        'Numeric gap array must have 1-2 values (row-gap, column-gap)');
                end
            elseif ~(isstring(value) || ischar(value))
                error('ic:check:InvalidGap', ...
                    'Gap must be a number/array (pixels) or string (CSS value)');
            end
        end

        function mustBeSpacing(value)
            % validate spacing values (padding, margin).
            % Accepts a number (pixels), a 1–4 element numeric array (CSS shorthand), or a string.

            if isnumeric(value)
                if any(value < 0)
                    error('ic:check:InvalidSpacing', ...
                        'Numeric spacing values must be non-negative');
                end
                if numel(value) > 4
                    error('ic:check:InvalidSpacing', ...
                        'Numeric spacing array must have 1-4 values (CSS shorthand)');
                end
            elseif ~(isstring(value) || ischar(value))
                error('ic:check:InvalidSpacing', ...
                    'Spacing must be a number/array (pixels) or string (CSS value)');
            end
        end

        function mustBeSize(value)
            % validate size values (width, height, icon size).
            % Accepts a non-negative scalar (pixels) or a string (CSS value).

            if isnumeric(value)
                if ~isscalar(value) || value < 0
                    error('ic:check:InvalidSize', ...
                        'Numeric size must be a non-negative scalar');
                end
            elseif ~(isstring(value) || ischar(value))
                error('ic:check:InvalidSize', ...
                    'Size must be a number (pixels) or string (CSS value)');
            end
        end
    end
end

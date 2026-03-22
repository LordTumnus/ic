classdef CssValidators
    % > CSSVALIDATORS Static validation functions for CSS-related properties.
    %
    % Provides reusable validators for properties that accept flexible CSS
    % values.


    methods (Static)
        function mustBeGridTemplate(value)
            % > MUSTBEGRIDTEMPLATE Validates grid-template-columns/rows values.
            %
            % Accepts:
            %   - Numeric array: interpreted as pixel values
            %     [100, 200, 100] → "100px 200px 100px"
            %   - String: passed as-is to CSS
            %     "1fr 2fr", "repeat(3, 1fr)", "minmax(100px, 1fr)"
            %
            % Throws error if value is neither numeric nor string.

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
            % > MUSTBEGAP Validates gap values (row-gap, column-gap).
            %
            % Accepts:
            %   - Number: single value in pixels (same for rows and columns)
            %     10 → "10px"
            %   - Numeric array: 1-2 values
            %     [10, 20] → "10px 20px" (row-gap, column-gap)
            %   - String: passed as-is to CSS
            %     "1rem", "10px 20px"
            %
            % Throws error if value is invalid.

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
            % > MUSTBESPACING Validates spacing values (padding, margin).
            %
            % Accepts:
            %   - Number: single value in pixels
            %     10 → "10px"
            %   - Numeric array: CSS shorthand (1-4 values)
            %     [10, 20] → "10px 20px" (vertical, horizontal)
            %     [10, 20, 30, 40] → "10px 20px 30px 40px" (top, right, bottom, left)
            %   - String: passed as-is to CSS
            %     "1rem", "10px 20px", "5%"
            %
            % Throws error if value is invalid.

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
            % > MUSTBESIZE Validates size values (width, height, icon size).
            %
            % Accepts:
            %   - Number: single value in pixels
            %     16 → "16px"
            %   - String: passed as-is to CSS
            %     "1.5rem", "24px", "100%"
            %
            % Throws error if value is invalid.

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

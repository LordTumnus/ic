classdef GridContainer < ic.core.ComponentContainer
    % > GRIDCONTAINER CSS Grid-based layout container for arranging child components.
    %
    % The GridContainer provides a two-dimensional grid layout model for organizing
    % child components with configurable columns, rows, alignment, spacing, and
    % auto-placement behavior.
    %
    % Flexible property types:
    %   Columns/Rows: double array (pixels) or string (CSS syntax)
    %     - [100, 200, 100] → "100px 200px 100px"
    %     - "1fr 2fr" → passed as-is
    %     - "repeat(3, minmax(100px, 1fr))" → passed as-is
    %
    %   Gap: double or [row, col] array (pixels) or string (CSS value)
    %     - 10 → "10px"
    %     - [10, 20] → "10px 20px" (row-gap, column-gap)
    %
    %   Padding: double or array (1-4 values, pixels) or string (CSS value)
    %     - 10 → "10px"
    %     - [10, 20] → "10px 20px" (vertical, horizontal)
    %     - [10, 20, 30, 40] → "10px 20px 30px 40px" (top, right, bottom, left)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > COLUMNS grid-template-columns: defines column track sizes
        % Accepts: double array (pixels) or string (CSS syntax)
        % Examples: [100, 200], "1fr 2fr", "repeat(3, 1fr)", "minmax(100px, 1fr) auto"
        Columns {ic.check.CssValidators.mustBeGridTemplate} = "1fr"
        % > ROWS grid-template-rows: defines row track sizes
        % Accepts: double array (pixels) or string (CSS syntax)
        % Examples: [50, 100], "auto", "1fr 2fr", "repeat(2, minmax(50px, auto))"
        Rows {ic.check.CssValidators.mustBeGridTemplate} = "auto"
        % > GAP spacing between grid items
        % Accepts: double, [row, col] array (pixels), or string (CSS value)
        % Examples: 8, [10, 20], "1rem", "10px 20px"
        Gap {ic.check.CssValidators.mustBeGap} = 8
        % > ALIGNITEMS align-items: vertical alignment of items within their cells
        AlignItems string {mustBeMember(AlignItems, ...
            ["start", "center", "end", "stretch", "baseline"])} = "stretch"
        % > JUSTIFYITEMS justify-items: horizontal alignment of items within their cells
        JustifyItems string {mustBeMember(JustifyItems, ...
            ["start", "center", "end", "stretch"])} = "stretch"
        % > AUTOFLOW grid-auto-flow: controls auto-placement algorithm
        AutoFlow string {mustBeMember(AutoFlow, ...
            ["row", "column", "dense", "row-dense", "column-dense"])} = "row"
        % > PADDING internal padding
        % Accepts: double, array (1-4 values in pixels), or string (CSS value)
        % Examples: 16, [10, 20], [10, 20, 30, 40], "1rem", "10px 20px"
        Padding {ic.check.CssValidators.mustBeSpacing} = 0
    end

    methods
        function this = GridContainer(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(id);
        end
    end
end

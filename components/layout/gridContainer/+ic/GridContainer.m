classdef GridContainer < ic.core.ComponentContainer
    % > GRIDCONTAINER CSS Grid-based layout container for arranging child components.
    %
    % The GridContainer provides a two-dimensional grid layout model
    % for organizing child components with configurable columns, rows,
    %  alignment, spacing, and auto-placement behavior.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > COLUMNS grid-template-columns: defines column track sizes
        Columns {ic.check.CssValidators.mustBeGridTemplate} = "1fr"

        % > ROWS grid-template-rows: defines row track sizes
        Rows {ic.check.CssValidators.mustBeGridTemplate} = "auto"

        % > GAP spacing between grid items
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
        Padding {ic.check.CssValidators.mustBeSpacing} = 0
    end

    methods
        function this = GridContainer(props)
            arguments
                props.?ic.GridContainer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end

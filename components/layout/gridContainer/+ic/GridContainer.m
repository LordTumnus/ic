classdef GridContainer < ic.core.ComponentContainer
    % css grid layout container for arranging child components in a two-dimensional grid

    properties (SetObservable, AbortSet, Description = "Reactive")
        % column track sizes as a CSS [grid-template-columns](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/grid-template-columns) string
        Columns {ic.check.CssValidators.mustBeGridTemplate} = "1fr"

        % row track sizes as a CSS [grid-template-rows](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/grid-template-rows) string

        Rows {ic.check.CssValidators.mustBeGridTemplate} = "auto"

        % spacing between grid cells, in pixels or as a CSS string
        Gap {ic.check.CssValidators.mustBeGap} = 8

        % vertical alignment of items within their grid cells
        AlignItems string {mustBeMember(AlignItems, ...
            ["start", "center", "end", "stretch", "baseline"])} = "stretch"

        % horizontal alignment of items within their grid cells
        JustifyItems string {mustBeMember(JustifyItems, ...
            ["start", "center", "end", "stretch"])} = "stretch"

        % auto-placement algorithm used when items are not explicitly positioned
        AutoFlow string {mustBeMember(AutoFlow, ...
            ["row", "column", "dense", "row-dense", "column-dense"])} = "row"

        % internal padding, in pixels or as a CSS string
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

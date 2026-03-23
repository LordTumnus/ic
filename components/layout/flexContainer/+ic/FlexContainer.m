classdef FlexContainer < ic.core.ComponentContainer
    % flexbox layout container for arranging child components in a single axis

    properties (SetObservable, AbortSet, Description = "Reactive")
        % main axis direction for laying out children
        Direction string {mustBeMember(Direction, ...
            ["row", "column", "row-reverse", "column-reverse"])} = "row"

        % whether children wrap to new lines when they overflow the main axis
        Wrap string {mustBeMember(Wrap, ...
            ["nowrap", "wrap", "wrap-reverse"])} = "nowrap"

        % alignment of children along the main axis
        JustifyContent string {mustBeMember(JustifyContent, ...
            ["start", "center", "end", "space-between", "space-around", "space-evenly"])} = "start"

        % alignment of children along the cross axis
        AlignItems string {mustBeMember(AlignItems, ...
            ["start", "center", "end", "stretch", "baseline"])} = "stretch"

        % spacing between child elements, in pixels or as a CSS string
        Gap {ic.check.CssValidators.mustBeGap} = 8

        % internal padding, in pixels or as a CSS string
        Padding {ic.check.CssValidators.mustBeSpacing} = 0
    end

    methods
        function this = FlexContainer(props)
            arguments
                props.?ic.FlexContainer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end

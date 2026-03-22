classdef FlexContainer < ic.core.ComponentContainer
    % > FLEXCONTAINER Flexbox-based layout container for arranging child components.
    %
    % The FlexContainer provides a flexible box layout model for organizing
    % child components horizontally or vertically with configurable alignment,
    % spacing, and wrapping behavior.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > DIRECTION flex-direction: controls the main axis
        Direction string {mustBeMember(Direction, ...
            ["row", "column", "row-reverse", "column-reverse"])} = "row"

        % > WRAP flex-wrap: controls whether items wrap to new lines
        Wrap string {mustBeMember(Wrap, ...
            ["nowrap", "wrap", "wrap-reverse"])} = "nowrap"

        % > JUSTIFYCONTENT justify-content: alignment along the main axis
        JustifyContent string {mustBeMember(JustifyContent, ...
            ["start", "center", "end", "space-between", "space-around", "space-evenly"])} = "start"

        % > ALIGNITEMS align-items: alignment along the cross axis
        AlignItems string {mustBeMember(AlignItems, ...
            ["start", "center", "end", "stretch", "baseline"])} = "stretch"

        % > GAP spacing between child elements
        Gap {ic.check.CssValidators.mustBeGap} = 8

        % > PADDING internal padding
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

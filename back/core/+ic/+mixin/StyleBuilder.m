% > STYLEBUILDER fluent builder for applying CSS styles to components.
%
% Accessed via the `css` property on Stylable components:
%   component.css.fillWidth().flexGrow(1).margin(8)
%
% All methods return the builder for chaining.
classdef StyleBuilder < handle

    properties (SetAccess = immutable, GetAccess = private)
        % > COMPONENT reference to the Stylable component
        Component
    end

    methods
        function this = StyleBuilder(component)
            arguments
                component (1,1) ic.mixin.Stylable
            end
            this.Component = component;
        end
    end

    methods
        function this = fillWidth(this)
            % > FILLWIDTH sets the component to fill available width (100%)
            this.Component.style("> *", "width", "100%");
        end

        function this = fillHeight(this)
            % > FILLHEIGHT sets the component to fill available height (100%)
            this.Component.style("> *", "height", "100%");
        end

        function this = fill(this)
            % > FILL sets the component to fill both width and height (100%)
            this.Component.style("> *", "width", "100%", "height", "100%");
        end

        function this = width(this, value)
            % > WIDTH sets the component width
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "width", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = height(this, value)
            % > HEIGHT sets the component height
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "height", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = minWidth(this, value)
            % > MINWIDTH sets the component minimum width
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "minWidth", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = minHeight(this, value)
            % > MINHEIGHT sets the component minimum height
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "minHeight", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = maxWidth(this, value)
            % > MAXWIDTH sets the component maximum width
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "maxWidth", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = maxHeight(this, value)
            % > MAXHEIGHT sets the component maximum height
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "maxHeight", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = flex(this, grow, shrink, basis)
            % > FLEX sets the flex shorthand property (grow, shrink, basis)
            arguments
                this (1,1) ic.mixin.StyleBuilder
                grow (1,1) double {mustBeNonnegative} = 1
                shrink (1,1) double {mustBeNonnegative} = 1
                basis = "auto"
            end
            basisValue = ic.mixin.StyleBuilder.toCssValue(basis);
            this.Component.style("> *", "flex", sprintf("%g %g %s", grow, shrink, basisValue));
        end

        function this = flexGrow(this, value)
            % > FLEXGROW sets flex-grow (how much the item grows relative to siblings)
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeNonnegative} = 1
            end
            this.Component.style("> *", "flexGrow", string(value));
        end

        function this = flexShrink(this, value)
            % > FLEXSHRINK sets flex-shrink (how much the item shrinks relative to siblings)
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeNonnegative} = 1
            end
            this.Component.style("> *", "flexShrink", string(value));
        end

        function this = flexBasis(this, value)
            % > FLEXBASIS sets the initial main size before growing/shrinking
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value = "auto"
            end
            this.Component.style("> *", "flexBasis", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = alignSelf(this, value)
            % > ALIGNSELF overrides parent's align-items for this component
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["auto", "start", "center", "end", "stretch", "baseline"])} = "auto"
            end
            this.Component.style("> *", "alignSelf", value);
        end

        function this = margin(this, value)
            % > MARGIN sets the component margin
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSpacing}
            end
            this.Component.style("> *", "margin", ic.mixin.StyleBuilder.toSpacingValue(value));
        end

        function this = padding(this, value)
            % > PADDING sets the component padding
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSpacing}
            end
            this.Component.style("> *", "padding", ic.mixin.StyleBuilder.toSpacingValue(value));
        end

        function this = hide(this)
            % > HIDE hides the component (display: none)
            this.Component.style("> *", "display", "none");
        end

        function this = show(this, displayType)
            % > SHOW shows the component with specified display type
            arguments
                this (1,1) ic.mixin.StyleBuilder
                displayType (1,1) string = "block"
            end
            this.Component.style("> *", "display", displayType);
        end

        function this = invisible(this)
            % > INVISIBLE makes the component invisible but keeps its space
            this.Component.style("> *", "visibility", "hidden");
        end

        function this = visible(this)
            % > VISIBLE makes the component visible
            this.Component.style("> *", "visibility", "visible");
        end

        function this = opacity(this, value)
            % > OPACITY sets the component opacity (0 to 1)
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeInRange(value, 0, 1)}
            end
            this.Component.style("> *", "opacity", string(value));
        end

        function this = position(this, type)
            % > POSITION sets the positioning type
            arguments
                this (1,1) ic.mixin.StyleBuilder
                type (1,1) string {mustBeMember(type, ...
                    ["static", "relative", "absolute", "fixed", "sticky"])}
            end
            this.Component.style("> *", "position", type);
        end

        function this = zIndex(this, value)
            % > ZINDEX sets the z-index (stacking order)
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeInteger}
            end
            this.Component.style("> *", "zIndex", string(value));
        end

        function this = overflow(this, value)
            % > OVERFLOW sets overflow behavior for both axes
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.Component.style("> *", "overflow", value);
        end

        function this = overflowX(this, value)
            % > OVERFLOWX sets horizontal overflow behavior
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.Component.style("> *", "overflowX", value);
        end

        function this = overflowY(this, value)
            % > OVERFLOWY sets vertical overflow behavior
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.Component.style("> *", "overflowY", value);
        end
    end

    methods (Static, Access = private)
        function css = toCssValue(value)
            if isnumeric(value)
                css = sprintf("%gpx", value);
            else
                css = string(value);
            end
        end

        function css = toSpacingValue(value)
            if isnumeric(value)
                css = strjoin(arrayfun(@(v) sprintf("%gpx", v), value, ...
                    'UniformOutput', false), " ");
            else
                css = string(value);
            end
        end
    end
end

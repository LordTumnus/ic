classdef StyleBuilder < handle
    % fluent builder for applying common CSS styles to components.
    %

    properties (SetAccess = immutable, GetAccess = private)
        % the #ic.mixin.Stylable component this builder operates on
        Component
    end

    methods
        function this = StyleBuilder(component)
            arguments
                % target component
                component (1,1) ic.mixin.Stylable
            end
            this.Component = component;
        end
    end

    methods
        function this = fillWidth(this)
            % sets width to 100%.
            this.Component.style("> *", "width", "100%");
        end

        function this = fillHeight(this)
            % sets height to 100%.
            this.Component.style("> *", "height", "100%");
        end

        function this = fill(this)
            % sets both width and height to 100%.
            this.Component.style("> *", "width", "100%", "height", "100%");
        end

        function this = width(this, value)
            % sets the component width, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                % size value (numeric → px, string → verbatim CSS)
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "width", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = height(this, value)
            % sets the component height, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                % size value (numeric → px, string → verbatim CSS)
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "height", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = minWidth(this, value)
            % sets the minimum width, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "minWidth", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = minHeight(this, value)
            % sets the minimum height, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "minHeight", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = maxWidth(this, value)
            % sets the maximum width, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "maxWidth", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = maxHeight(this, value)
            % sets the maximum height, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.Component.style("> *", "maxHeight", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = flex(this, grow, shrink, basis)
            % sets the flex shorthand (grow, shrink, basis).
            arguments
                this (1,1) ic.mixin.StyleBuilder
                % flex grow factor
                grow (1,1) double {mustBeNonnegative} = 1
                % flex shrink factor
                shrink (1,1) double {mustBeNonnegative} = 1
                % initial main size before growing/shrinking
                basis = "auto"
            end
            basisValue = ic.mixin.StyleBuilder.toCssValue(basis);
            this.Component.style("> *", "flex", sprintf("%g %g %s", grow, shrink, basisValue));
        end

        function this = flexGrow(this, value)
            % sets how much the item grows relative to siblings.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeNonnegative} = 1
            end
            this.Component.style("> *", "flexGrow", string(value));
        end

        function this = flexShrink(this, value)
            % sets how much the item shrinks relative to siblings.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeNonnegative} = 1
            end
            this.Component.style("> *", "flexShrink", string(value));
        end

        function this = flexBasis(this, value)
            % sets the initial main size before growing/shrinking.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value = "auto"
            end
            this.Component.style("> *", "flexBasis", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = alignSelf(this, value)
            % overrides the parent's align-items for this component.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["auto", "start", "center", "end", "stretch", "baseline"])} = "auto"
            end
            this.Component.style("> *", "alignSelf", value);
        end

        function this = margin(this, value)
            % sets the component margin, in pixels or as a CSS spacing string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSpacing}
            end
            this.Component.style("> *", "margin", ic.mixin.StyleBuilder.toSpacingValue(value));
        end

        function this = padding(this, value)
            % sets the component padding, in pixels or as a CSS spacing string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSpacing}
            end
            this.Component.style("> *", "padding", ic.mixin.StyleBuilder.toSpacingValue(value));
        end

        function this = hide(this)
            % hides the component (display: none).
            this.Component.style("> *", "display", "none");
        end

        function this = show(this, displayType)
            % shows the component with the specified display type.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                displayType (1,1) string = "block"
            end
            this.Component.style("> *", "display", displayType);
        end

        function this = invisible(this)
            % makes the component invisible but preserves its layout space.
            this.Component.style("> *", "visibility", "hidden");
        end

        function this = visible(this)
            % makes the component visible.
            this.Component.style("> *", "visibility", "visible");
        end

        function this = opacity(this, value)
            % sets the component opacity (0 = transparent, 1 = opaque).
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeInRange(value, 0, 1)}
            end
            this.Component.style("> *", "opacity", string(value));
        end

        function this = position(this, type)
            % sets the CSS positioning type.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                type (1,1) string {mustBeMember(type, ...
                    ["static", "relative", "absolute", "fixed", "sticky"])}
            end
            this.Component.style("> *", "position", type);
        end

        function this = zIndex(this, value)
            % sets the z-index (stacking order).
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeInteger}
            end
            this.Component.style("> *", "zIndex", string(value));
        end

        function this = overflow(this, value)
            % sets overflow behavior for both axes.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.Component.style("> *", "overflow", value);
        end

        function this = overflowX(this, value)
            % sets horizontal overflow behavior.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.Component.style("> *", "overflowX", value);
        end

        function this = overflowY(this, value)
            % sets vertical overflow behavior.
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

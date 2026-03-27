classdef StyleBuilder < handle
    % fluent builder for applying CSS styles and keyframes to components.
    % All style operations (set, get, clear) and keyframe definitions are
    % accessed through this class via the #ic.mixin.Stylable.css property.

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

    methods (Access = public)
        function this = style(this, selector, varargin)
            % applies CSS styles to elements matching the CSS selector.
            % Styles are merged with any existing styles for the selector, and properties set to "" are removed. The complete style object for the selector is published to the view on each update, so it's recommended to batch multiple style changes together by passing an object or using the fluent helpers.
            % The selector should target children or descendants of the component wrapper, not the wrapper itself. For example, to set styles on all direct children, use "> *". See the [CSS selector](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Selectors) reference for more details and examples
            % {returns} the builder itself, for chaining {/returns}
            % {example}
            %   comp.css.style("> *", "width", "100%")
            %   comp.css.style(".label", "color", "red")
            %   comp.css.style("> *", struct("flex", "1", "margin", "5px"))
            % {/example}

            arguments (Input)
                this (1,1) ic.mixin.StyleBuilder
                % CSS selector scoped to the component wrapper
                selector (1,1) string
            end

            arguments (Input, Repeating)
                varargin
            end

            % parse input into a struct of new styles
            if isscalar(varargin) && isstruct(varargin{1})
                newStyles = varargin{1};
            else
                if mod(numel(varargin), 2) ~= 0
                    error("ic:mixin:StyleBuilder:InvalidStyleArgs", ...
                          "Style properties must be specified as name-value pairs.");
                end
                varargin(1:2:end) = ...
                  cellfun(@string, varargin(1:2:end), 'UniformOutput', false);
                newStyles = struct(varargin{:});
            end

            % merge with existing styles for this selector
            if this.Component.Styles.isKey(selector)
                existingStyles = this.Component.Styles(selector);
            else
                existingStyles = struct();
            end

            % apply new styles (merge), removing properties set to ""
            fields = fieldnames(newStyles);
            for jj = 1:numel(fields)
                fname = fields{jj};
                fvalue = newStyles.(fname);
                if isstring(fvalue) && fvalue == ""
                    % remove property
                    if isfield(existingStyles, fname)
                        existingStyles = rmfield(existingStyles, fname);
                    end
                else
                    existingStyles.(fname) = fvalue;
                end
            end

            % store merged styles
            this.Component.Styles(selector) = existingStyles;

            % convert property names to kebab-case for CSS
            mergedFields = fieldnames(existingStyles);
            kebabKeys = cell(1, numel(mergedFields));
            values = cell(1, numel(mergedFields));
            for kk = 1:numel(mergedFields)
                kebabKeys{kk} = char(ic.utils.toKebabCase(mergedFields{kk}));
                values{kk} = existingStyles.(mergedFields{kk});
            end
            cssStyles = containers.Map(kebabKeys, values);

            % publish the complete styles for this selector
            this.Component.publish("@style", struct( ...
                "selector", selector, ...
                "styles", cssStyles));
        end

        function styles = getStyle(this, selector)
            % returns the current styles for a selector.
            % {returns} the style struct, or an empty struct if none set {/returns}
            arguments (Input)
                this (1,1) ic.mixin.StyleBuilder
                % CSS selector to query
                selector (1,1) string
            end

            arguments (Output)
                styles (1,1) struct
            end

            if this.Component.Styles.isKey(selector)
                styles = this.Component.Styles(selector);
            else
                styles = struct();
            end
        end

        function this = clearStyle(this, selector)
            % removes all styles for a specific selector.
            arguments (Input)
                this (1,1) ic.mixin.StyleBuilder
                % CSS selector whose styles should be cleared
                selector (1,1) string
            end

            if this.Component.Styles.isKey(selector)
                this.Component.Styles(selector) = [];
            end

            this.Component.publish("@clearStyle", struct("selector", selector));
        end

        function this = clearStyles(this)
            % removes all dynamic styles for the component
            this.Component.Styles = dictionary(string.empty(), struct.empty());
            this.Component.publish("@clearStyles", struct());
        end

        function result = getAllStyles(this)
            % returns all dynamic styles as an object mapping selectors to their style structs.
            % {returns} a containers.Map mapping selectors to style structs {/returns}
            result = containers.Map('KeyType', 'char', 'ValueType', 'any');
            selectors = keys(this.Component.Styles);
            for ii = 1:numel(selectors)
                result(char(selectors(ii))) = this.Component.Styles(selectors(ii));
            end
        end

        function this = keyframes(this, name, varargin)
            % defines a CSS @keyframes animation. The keyframe is not scoped, (global), so in theory any component can reuse it
            %
            % Frames can be specified as a struct-of-structs or as alternating
            % stop-name / properties-struct pairs:
            % {example}
            %   comp.css.keyframes("fadeIn", struct( ...
            %       "from", struct("opacity", "0"), ...
            %       "to",   struct("opacity", "1")))
            %   comp.css.keyframes("slide", ...
            %       "0%",   struct("transform", "translateX(0)"), ...
            %       "100%", struct("transform", "translateX(100px)"))
            %   comp.css.style("> *", "animationName", "fadeIn", "animationDuration", "1s")
            % {/example}

            arguments (Input)
                this (1,1) ic.mixin.StyleBuilder
                % keyframe animation name
                name (1,1) string
            end
            arguments (Input, Repeating)
                % alternating stop name (e.g. "from", "to", "0%", "50%") and properties struct pairs, or a single struct-of-structs with stop names as fields
                varargin
            end

            % parse frames
            if isscalar(varargin) && isstruct(varargin{1})
                framesStruct = varargin{1};
            else
                if mod(numel(varargin), 2) ~= 0
                    error("ic:mixin:StyleBuilder:InvalidKeyframeArgs", ...
                          "Keyframe stops must be specified as name-value pairs.");
                end
                args = cell(1, numel(varargin));
                for ii = 1:2:numel(varargin)
                    key = string(varargin{ii});
                    % normalize percentage keys: "0%" → "p0" (struct fields can't start with digits)
                    key = regexprep(key, '^(\d+)%$', 'p$1');
                    args{ii} = char(key);
                    args{ii+1} = varargin{ii+1};
                end
                framesStruct = struct(args{:});
            end

            % convert each frame's property names to kebab-case
            stops = fieldnames(framesStruct);
            frames = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for ii = 1:numel(stops)
                stopName = stops{ii};
                props = framesStruct.(stopName);
                propFields = fieldnames(props);
                converted = containers.Map('KeyType', 'char', 'ValueType', 'any');
                for jj = 1:numel(propFields)
                    kebab = char(ic.utils.toKebabCase(propFields{jj}));
                    converted(kebab) = props.(propFields{jj});
                end
                frames(stopName) = converted;
            end

            this.Component.publish("@keyframes", struct( ...
                "name", name, ...
                "frames", frames));
        end

        function this = removeKeyframes(this, name)
            % removes a previously defined @keyframes animation.
            arguments (Input)
                this (1,1) ic.mixin.StyleBuilder
                % keyframe animation name (unscoped, as originally passed to keyframes())
                name (1,1) string
            end
            this.Component.publish("@removeKeyframes", struct("name", name));
        end
    end

    methods
        function this = fillWidth(this)
            % sets width to 100%.
            this.style("> *", "width", "100%");
        end

        function this = fillHeight(this)
            % sets height to 100%.
            this.style("> *", "height", "100%");
        end

        function this = fill(this)
            % sets both width and height to 100%.
            this.style("> *", "width", "100%", "height", "100%");
        end

        function this = width(this, value)
            % sets the component width, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                % size value (numeric → px, string → verbatim CSS)
                value {ic.check.CssValidators.mustBeSize}
            end
            this.style("> *", "width", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = height(this, value)
            % sets the component height, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                % size value (numeric → px, string → verbatim CSS)
                value {ic.check.CssValidators.mustBeSize}
            end
            this.style("> *", "height", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = minWidth(this, value)
            % sets the minimum width, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.style("> *", "minWidth", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = minHeight(this, value)
            % sets the minimum height, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.style("> *", "minHeight", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = maxWidth(this, value)
            % sets the maximum width, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.style("> *", "maxWidth", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = maxHeight(this, value)
            % sets the maximum height, in pixels or as a CSS size string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSize}
            end
            this.style("> *", "maxHeight", ic.mixin.StyleBuilder.toCssValue(value));
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
            this.style("> *", "flex", sprintf("%g %g %s", grow, shrink, basisValue));
        end

        function this = flexGrow(this, value)
            % sets how much the item grows relative to siblings.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeNonnegative} = 1
            end
            this.style("> *", "flexGrow", string(value));
        end

        function this = flexShrink(this, value)
            % sets how much the item shrinks relative to siblings.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeNonnegative} = 1
            end
            this.style("> *", "flexShrink", string(value));
        end

        function this = flexBasis(this, value)
            % sets the initial main size before growing/shrinking.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value = "auto"
            end
            this.style("> *", "flexBasis", ic.mixin.StyleBuilder.toCssValue(value));
        end

        function this = alignSelf(this, value)
            % overrides the parent's align-items for this component.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["auto", "start", "center", "end", "stretch", "baseline"])} = "auto"
            end
            this.style("> *", "alignSelf", value);
        end

        function this = margin(this, value)
            % sets the component margin, in pixels or as a CSS spacing string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSpacing}
            end
            this.style("> *", "margin", ic.mixin.StyleBuilder.toSpacingValue(value));
        end

        function this = padding(this, value)
            % sets the component padding, in pixels or as a CSS spacing string.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value {ic.check.CssValidators.mustBeSpacing}
            end
            this.style("> *", "padding", ic.mixin.StyleBuilder.toSpacingValue(value));
        end

        function this = hide(this)
            % hides the component (display: none).
            this.style("> *", "display", "none");
        end

        function this = show(this, displayType)
            % shows the component with the specified display type.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                displayType (1,1) string = "block"
            end
            this.style("> *", "display", displayType);
        end

        function this = invisible(this)
            % makes the component invisible but preserves its layout space.
            this.style("> *", "visibility", "hidden");
        end

        function this = visible(this)
            % makes the component visible.
            this.style("> *", "visibility", "visible");
        end

        function this = opacity(this, value)
            % sets the component opacity (0 = transparent, 1 = opaque).
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeInRange(value, 0, 1)}
            end
            this.style("> *", "opacity", string(value));
        end

        function this = position(this, type)
            % sets the CSS positioning type.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                type (1,1) string {mustBeMember(type, ...
                    ["static", "relative", "absolute", "fixed", "sticky"])}
            end
            this.style("> *", "position", type);
        end

        function this = zIndex(this, value)
            % sets the z-index (stacking order).
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) double {mustBeInteger}
            end
            this.style("> *", "zIndex", string(value));
        end

        function this = overflow(this, value)
            % sets overflow behavior for both axes.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.style("> *", "overflow", value);
        end

        function this = overflowX(this, value)
            % sets horizontal overflow behavior.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.style("> *", "overflowX", value);
        end

        function this = overflowY(this, value)
            % sets vertical overflow behavior.
            arguments
                this (1,1) ic.mixin.StyleBuilder
                value (1,1) string {mustBeMember(value, ...
                    ["visible", "hidden", "scroll", "auto", "clip"])}
            end
            this.style("> *", "overflowY", value);
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

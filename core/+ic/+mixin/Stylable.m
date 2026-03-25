classdef (Abstract) Stylable < handle
    % dynamic CSS styling capabilities for components.
    % Styles are scoped to the component wrapper DOM element (tagged with its #ic.core.ComponentBase.ID). Internally, it uses constructable stylesheets ([CSSStyleSheet](https://developer.mozilla.org/en-US/docs/Web/API/CSSStyleSheet)) for performant rule injection.
    % Note that styles shouldn't be applied to the wrapper element itself. Instead, children or descendants should be targeted via selectors

    properties (SetAccess = private, Hidden)
        % dynamic CSS styles per selector
        Styles = dictionary(string.empty(), struct.empty());
    end

    properties (Dependent, SetAccess = private)
        % util #ic.mixin.StyleBuilder class that simplifies common style update patterns with a fluent syntax
        css
    end

    properties (Access = private, Hidden)
        % cached #ic.mixin.StyleBuilder instance
        StyleBuilder
    end

    methods (Abstract, Access = public)
        publish(this, name, data)
    end

    methods
        function builder = get.css(this)
            % returns a style builder object that allows chaining style updates in a fluent syntax.
            % {returns} a #ic.mixin.StyleBuilder bound to this component {/returns}
            if isempty(this.StyleBuilder)
                this.StyleBuilder = ic.mixin.StyleBuilder(this);
            end
            builder = this.StyleBuilder;
        end
    end

    methods (Access = public)
        function this = style(this, selector, varargin)
            % applies CSS styles to elements matching the CSS selector.
            % Styles are merged with any existing styles for the selector, and properties set to "" are removed. The complete style object for the selector is published to the view on each update, so it's recommended to batch multiple style changes together by passing an object or using the css builder.
            % The selector should target children or descendants of the component wrapper, not the wrapper itself. For example, to set styles on all direct children, use "> *". See the [CSS selector](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Selectors) reference for more details and examples
            % {returns} the component itself, for chaining {/returns}
            % {example}
            %   comp.style("> *", "width", "100%")
            %   comp.style(".label", "color", "red")
            %   comp.style("> *", struct("flex", "1", "margin", "5px"))
            % {/example}

            arguments (Input)
                this (1,1) ic.mixin.Stylable
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
                    error("ic:mixin:Stylable:InvalidStyleArgs", ...
                          "Style properties must be specified as name-value pairs.");
                end
                varargin(1:2:end) = ...
                  cellfun(@string, varargin(1:2:end), 'UniformOutput', false);
                newStyles = struct(varargin{:});
            end

            % merge with existing styles for this selector
            if this.Styles.isKey(selector)
                existingStyles = this.Styles(selector);
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
            this.Styles(selector) = existingStyles;

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
            this.publish("@style", struct( ...
                "selector", selector, ...
                "styles", cssStyles));
        end

        function styles = getStyle(this, selector)
            % returns the current styles for a selector.
            % {returns} the style struct, or an empty struct if none set {/returns}
            arguments (Input)
                this (1,1) ic.mixin.Stylable
                % CSS selector to query
                selector (1,1) string
            end

            arguments (Output)
                styles (1,1) struct
            end

            if this.Styles.isKey(selector)
                styles = this.Styles(selector);
            else
                styles = struct();
            end
        end

        function clearStyle(this, selector)
            % removes all styles for a specific selector.
            arguments (Input)
                this (1,1) ic.mixin.Stylable
                % CSS selector whose styles should be cleared
                selector (1,1) string
            end

            if this.Styles.isKey(selector)
                this.Styles(selector) = [];
            end

            this.publish("@clearStyle", struct("selector", selector));
        end

        function clearStyles(this)
            % removes all dynamic styles for the component
            arguments (Input)
                this (1,1) ic.mixin.Stylable
            end

            this.Styles = dictionary(string.empty(), struct.empty());
            this.publish("@clearStyles", struct());
        end

        function result = getAllStyles(this)
            % returns all dynamic styles as an object mapping selectors to their style structs.
            % {returns} a containers.Map mapping selectors to style structs {/returns}
            result = containers.Map('KeyType', 'char', 'ValueType', 'any');
            selectors = keys(this.Styles);
            for ii = 1:numel(selectors)
                result(char(selectors(ii))) = this.Styles(selectors(ii));
            end
        end
    end
end

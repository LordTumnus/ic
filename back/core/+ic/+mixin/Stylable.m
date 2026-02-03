% > STYLABLE mixin providing dynamic CSS styling capabilities for components.
%
% This mixin adds the ability to dynamically apply CSS styles to components.
% Use the `css` property for convenient fluent styling:
%
%   component.css.fillWidth().flexGrow(1).margin(8)
%
% Or use the `style` method directly for custom selectors:
%
%   component.style("> *", "color", "red")
classdef (Abstract) Stylable < handle

    properties (SetAccess = private, Hidden)
        % > STYLES stores dynamic CSS styles per selector (selector → struct of properties)
        Styles = dictionary(string.empty(), struct.empty());
    end

    properties (Dependent, SetAccess = private)
        % > CSS fluent style builder for convenient chaining
        css
    end

    properties (Access = private, Hidden)
        % > STYLEBUILDER_ cached StyleBuilder instance
        StyleBuilder
    end

    methods (Abstract, Access = public)
        % > PUBLISH sends an event to the view (must be implemented by host class)
        publish(this, name, data)
    end

    methods
        function builder = get.css(this)
            % > CSS returns a StyleBuilder for fluent styling
            if isempty(this.StyleBuilder)
                this.StyleBuilder = ic.mixin.StyleBuilder(this);
            end
            builder = this.StyleBuilder;
        end
    end

    methods (Access = public)
        function style(this, selector, varargin)
            % > STYLE applies CSS styles to elements matching the selector.
            % Styles are merged with existing styles for that selector.
            % To remove a property, set its value to "".
            %
            % The selector is scoped to the component wrapper (#componentId).
            % Since the wrapper uses `display: contents`, use "> *" to
            % target the actual component root element for layout styles.
            %
            % Examples:
            %   comp.style("> *", "width", "100%")        % targets component root
            %   comp.style(".label", "color", "red")      % targets .label inside
            %   comp.style("> *", struct("flex", "1"))    % using struct

            arguments (Input)
                this (1,1) ic.mixin.Stylable
                selector (1,1) string
            end

            arguments (Input, Repeating)
                varargin
            end

            % Parse input into a struct of new styles
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

            % Merge with existing styles for this selector
            if this.Styles.isKey(selector)
                existingStyles = this.Styles(selector);
            else
                existingStyles = struct();
            end

            % Apply new styles (merge), removing properties set to ""
            fields = fieldnames(newStyles);
            for jj = 1:numel(fields)
                fname = fields{jj};
                fvalue = newStyles.(fname);
                if isstring(fvalue) && fvalue == ""
                    % Remove property
                    if isfield(existingStyles, fname)
                        existingStyles = rmfield(existingStyles, fname);
                    end
                else
                    existingStyles.(fname) = fvalue;
                end
            end

            % Store merged styles
            this.Styles(selector) = existingStyles;

            % Convert property names to kebab-case for CSS
            mergedFields = fieldnames(existingStyles);
            kebabKeys = cell(1, numel(mergedFields));
            values = cell(1, numel(mergedFields));
            for kk = 1:numel(mergedFields)
                kebabKeys{kk} = char(ic.utils.toKebabCase(mergedFields{kk}));
                values{kk} = existingStyles.(mergedFields{kk});
            end
            cssStyles = containers.Map(kebabKeys, values);

            % Publish the complete styles for this selector
            this.publish("@style", struct( ...
                "selector", selector, ...
                "styles", cssStyles));
        end

        function styles = getStyle(this, selector)
            % > GETSTYLE returns the current styles for a selector.
            % Returns an empty struct if no styles are set for the selector.
            arguments (Input)
                this (1,1) ic.mixin.Stylable
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
            % > CLEARSTYLE removes all styles for a specific selector.
            arguments (Input)
                this (1,1) ic.mixin.Stylable
                selector (1,1) string
            end

            if this.Styles.isKey(selector)
                this.Styles(selector) = [];
            end

            this.publish("@clearStyle", struct("selector", selector));
        end

        function clearStyles(this)
            % > CLEARSTYLES removes all dynamic styles for the component.
            arguments (Input)
                this (1,1) ic.mixin.Stylable
            end

            this.Styles = dictionary(string.empty(), struct.empty());
            this.publish("@clearStyles", struct());
        end
    end
end

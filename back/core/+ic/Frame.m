% > FRAME is the root component that holds other interactive components and bridges them to the HTML view
classdef Frame < ic.core.ComponentBase & ic.core.Container

    properties (SetAccess = private)
        % > VIEW the view bridge that handles HTML communication
        View ic.core.View
        % > REGISTRY map of component IDs to components for O(1) event dispatch
        Registry = dictionary(string.empty(), ic.core.ComponentBase.empty())
        % > GLOBALSTYLES nested dictionary: componentType → (selector → styles struct)
        GlobalStyles = dictionary(string.empty(), dictionary.empty())
    end

    properties (SetAccess = private, SetObservable, Description = "Reactive")
        % > THEME CSS custom property values (syncs to frontend automatically via jsonencode)
        Theme ic.style.Theme
    end

    properties (SetObservable, Description = "Reactive")
        % > COLORSCHEME active color scheme
        ColorScheme (1,1) string {mustBeMember(ColorScheme, ["light", "dark"])} = "light"
    end

    properties (Dependent)
        Position (1,4) double
        Visible (1,1) matlab.lang.OnOffSwitchState
        Units (1,1) string
        Layout matlab.ui.layout.GridLayoutOptions
        UIParent (1,1) matlab.ui.container.Container
    end

    properties (Dependent, Hidden)
        Parent (1,1) matlab.ui.container.Container
    end


    methods
        function this = Frame(args)
            % > FRAME creates a frame component that can hold other interactive components
            arguments (Input)
                % > ARGS optional name-value pairs of properties of the frame
                args.?matlab.ui.componentcontainer.ComponentContainer
            end
            arguments (Output)
                % > THIS the frame
                this (1,1) ic.Frame
            end

            % call superclass constructor with frame ID
            this@ic.core.ComponentBase("ic-frame");

            % initialize the theme
            this.Theme = ic.style.Theme();

            % initialize the view
            args = namedargs2cell(args);
            this.View = ic.core.View(this, args{:});

            addlistener(this.View, "ObjectBeingDestroyed", ...
                @(~,~) this.delete());
        end

        function delete(this)
            % DELETE cleans up the Frame and its View
            if isvalid(this.View)
                this.View.delete();
            end
            delete@ic.core.Container(this);
        end

        function position = get.Position(this)
            position = this.View.Position;
        end

        function visible = get.Visible(this)
            visible = this.View.Visible;
        end

        function units = get.Units(this)
            units = string(this.View.Units);
        end

        function layout = get.Layout(this)
            layout = this.View.Layout;
        end

        function parent = get.Parent(this)
            warning("Frame objects will not appear as Children of their uicontainer. To remove this warning, use UIParent instead");
            parent = this.View.Parent;
        end

        function uiparent = get.UIParent(this)
            uiparent = this.View.Parent;
        end


        function set.Position(this, position)
            this.View.Position = position;
        end

        function set.Visible(this, visible)
            this.View.Visible = visible;
        end

        function set.Units(this, units)
            this.View.Units = units;
        end

        function set.Layout(this, layout)
            this.View.Layout = layout;
        end

        function set.Parent(this, parent)
            warning("Frame objects will not appear as Children of their uicontainer. To remove this warning, use UIParent instead");
            this.View.Parent = parent;
        end

        function set.UIParent(this, uiparent)
            this.View.Parent = uiparent;
        end

    end

    methods (Access = public)
        function tf = isAttached(~)
            % > ISATTACHED Frame is always attached (it's the root)
            tf = true;
        end

        function theme(this, name, value)
            % > THEME sets CSS custom property values.
            % theme("name", "value") - sets value for the ACTIVE color scheme
            % theme("name", ["light", "dark"]) - sets both light and dark values

            arguments (Input)
                this (1,1) ic.Frame
            end

            arguments (Input, Repeating)
                name (1,1) string
                value string
            end

            currentTheme = this.Theme;

            for ii = 1:numel(name)
                propName = ic.utils.toPascalCase(name{ii});

                if ~isprop(currentTheme, propName)
                    error("ic:Frame:InvalidThemeProperty", ...
                          "Unknown theme property: %s", name{ii});
                end

                val = value{ii};
                if isscalar(val)
                    % Single value: apply to active scheme only
                    currentValues = currentTheme.(propName);
                    if this.ColorScheme == "light"
                        currentTheme.(propName) = [val, currentValues(2)];
                    else
                        currentTheme.(propName) = [currentValues(1), val];
                    end
                else
                    % Array [light, dark]: set both values
                    currentTheme.(propName) = val;
                end
            end

            % Assign back to trigger reactive sync (Theme.jsonencode serializes to CSS)
            this.Theme = currentTheme;
        end

        function globalStyle(this, componentType, selector, varargin)
            % > GLOBALSTYLE applies CSS styles to all components of a type.

            arguments (Input)
                this (1,1) ic.Frame
                componentType (1,1) string
                selector (1,1) string
            end

            arguments (Input, Repeating)
                varargin
            end

            % Parse styles (same logic as ComponentBase.style)
            if isscalar(varargin) && isstruct(varargin{1})
                newStyles = varargin{1};
            else
                if mod(numel(varargin), 2) ~= 0
                    error("ic:Frame:InvalidStyleArgs", ...
                          "Style properties must be specified as name-value pairs.");
                end
                varargin(1:2:end) = ...
                    cellfun(@string, varargin(1:2:end), 'UniformOutput', false);
                newStyles = struct(varargin{:});
            end

            % Get or create selector dictionary for this component type
            if this.GlobalStyles.isKey(componentType)
                selectorDict = this.GlobalStyles(componentType);
            else
                selectorDict = dictionary(string.empty(), struct.empty());
            end

            % Merge with existing styles for this selector
            if selectorDict.isKey(selector)
                existingStyles = selectorDict(selector);
            else
                existingStyles = struct();
            end

            fields = fieldnames(newStyles);
            for jj = 1:numel(fields)
                fname = fields{jj};
                fvalue = newStyles.(fname);
                if isstring(fvalue) && fvalue == ""
                    if isfield(existingStyles, fname)
                        existingStyles = rmfield(existingStyles, fname);
                    end
                else
                    existingStyles.(fname) = fvalue;
                end
            end

            selectorDict(selector) = existingStyles;
            this.GlobalStyles(componentType) = selectorDict;

            % Convert to kebab-case for CSS
            cssStyles = struct();
            mergedFields = fieldnames(existingStyles);
            for kk = 1:numel(mergedFields)
                kebabName = ic.utils.toKebabCase(mergedFields{kk});
                cssStyles.(kebabName) = existingStyles.(mergedFields{kk});
            end

            this.publish("@globalStyle", struct( ...
                "type", componentType, ...
                "selector", selector, ...
                "styles", cssStyles));
        end

        function clearGlobalStyle(this, componentType, selector)
            % > CLEARGLOBALSTYLE removes styles for a specific selector on a component type.

            arguments (Input)
                this (1,1) ic.Frame
                componentType (1,1) string
                selector (1,1) string
            end

            if this.GlobalStyles.isKey(componentType)
                selectorDict = this.GlobalStyles(componentType);
                if selectorDict.isKey(selector)
                    selectorDict(selector) = [];
                    this.GlobalStyles(componentType) = selectorDict;
                end
            end

            this.publish("@clearGlobalStyle", struct( ...
                "type", componentType, ...
                "selector", selector));
        end

        function clearGlobalStyles(this, componentType)
            % > CLEARGLOBALSTYLES removes all styles for a component type.

            arguments (Input)
                this (1,1) ic.Frame
                componentType (1,1) string
            end

            if this.GlobalStyles.isKey(componentType)
                this.GlobalStyles(componentType) = [];
            end

            this.publish("@clearGlobalStyles", struct("type", componentType));
        end

        function clearAllGlobalStyles(this)
            % > CLEARALLGLOBALSTYLES removes all global styles.

            arguments (Input)
                this (1,1) ic.Frame
            end

            this.GlobalStyles = dictionary(string.empty(), dictionary.empty());
            this.publish("@clearAllGlobalStyles", struct());
        end
    end

    methods (Access = {?ic.core.Container, ?ic.core.Component}, Hidden)
        function frame = getFrame(this)
            % > GETFRAME returns self since Frame is the root
            frame = this;
        end
    end

    methods (Access = protected)
        function send(this, evt)
            % > SEND delegates to the View instead of parent
            this.View.send(evt);
        end

        function registerSubtree(this, component)
            % > REGISTERSUBTREE registers a component and its subtree (Frame is the registry)
            ic.core.Container.registerSubtreeWithFrame(component, this);
        end

        function deregisterSubtree(this, component)
            % > DEREGISTERSUBTREE deregisters a component and its subtree (Frame is the registry)
            ic.core.Container.deregisterSubtreeWithFrame(component, this);
        end

        function definition = getComponentDefinition(this)
            % > GETCOMPONENTDEFINITION returns the component definition struct for this frame
            definition = getComponentDefinition@ic.core.ComponentBase(this);
            definition.targets = num2cell(string.empty());
        end
    end

    methods (Access = {?ic.core.Container})
        function registerDescendant(this, component)
            % > REGISTERDESCENDANT adds a component to the registry for O(1) event dispatch
            this.Registry(component.ID) = component;
        end

        function deregisterDescendant(this, id)
            % > DEREGISTERDESCENDANT removes a component from the registry
            if this.Registry.isKey(id)
                this.Registry(id) = [];
            end
        end
    end

end

classdef Frame < ic.core.ComponentBase & ...
                 ic.core.Container & ...
                 ic.mixin.Stylable & ...
                 ic.mixin.Effectable & ...
                 ic.mixin.AllowsOverlay
    % root of the IC component tree. Every IC application starts with a single Frame.
    % The Frame owns the #ic.core.View bridge and the component registry. Components are added via #ic.core.Container.addChild, which serializes their definition and sends it over the frontend.
    % Frames also handle theming via their #ic.Frame.Theme and #ic.FrameColorScheme properties, and styling for all components of a given type via the #ic.Frame.globalStyle method

    properties (SetAccess = private)
        % bridge that wraps uihtml and handles MATLAB↔JS communication
        View ic.core.View

        % id to component dictionary for O(1) event dispatch from the frontend
        Registry = dictionary(string.empty(), ic.core.ComponentBase.empty())

        % dictionary mapping component type to style rules applied to all the children of that type
        GlobalStyles = configureDictionary("string", "dictionary")

        % collects frontend log entries
        Logger ic.core.Logger
    end

    properties (SetAccess = private, SetObservable, Description = "Reactive")
        % theme tokens synced to the frontend
        Theme ic.style.Theme = ic.style.Theme()
    end

    properties (SetObservable, Description = "Reactive")
        % active color scheme
        ColorScheme (1,1) string {mustBeMember(ColorScheme, ["light", "dark"])} = "light"

        % when true, the frontend forwards log entries to MATLAB and prints
        % them in the command window
        Debug (1,1) logical = false

        % minimum severity that the #ic.core.Logger accepts (used when #ic.Frame.Debug is true)
        LogLevel (1,1) string {mustBeMember(LogLevel, ["debug", "info", "warn", "error"])} = "debug"
    end

    properties (Dependent)
        % position of the underlying uihtml container, in current Units
        Position (1,4) double

        % whether the frame is visible
        Visible (1,1) matlab.lang.OnOffSwitchState

        % coordinate units for Position
        Units (1,1) string

        % grid layout options when placed inside a uigridlayout
        Layout matlab.ui.layout.GridLayoutOptions

        % parent uicontainer or uifigure
        UIParent (1,1) matlab.ui.container.Container
    end

    properties (Dependent, Hidden)
        % do not use. Frame objects do not appear as Children of their uicontainer, so using Parent is misleading.
        Parent (1,1) matlab.ui.container.Container
    end


    methods
        function this = Frame(args)
            % create a frame and its backing #ic.core.View.
            arguments (Input)
                % name-value pairs forwarded to the underlying uihtml container
                args.?matlab.ui.componentcontainer.ComponentContainer
            end
            arguments (Output)
                this (1,1) ic.Frame
            end

            % fixed ID
            this@ic.core.ComponentBase("ic-frame");

            % create the view bridge (uihtml inside a uigridlayout)
            args = namedargs2cell(args);
            this.View = ic.core.View(this, args{:});

            addlistener(this.View, "ObjectBeingDestroyed", ...
                @(~,~) this.delete());

            % initialize logger and keep it in sync with LogLevel
            this.Logger = ic.core.Logger();

            addlistener(this, "LogLevel", "PostSet", ...
                @(~,~) this.Logger.setLogLevel(this.LogLevel));

            % listen for frontend log entries
            this.subscribe("@log", @(~, ~, data) this.onLog(data));
        end

        function delete(this)
            % destroy the frame and its view, cascading deletion to all children.
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
            % {returns} true {/returns}
            tf = true;
        end

        function theme(this, name, value)
            % set one or more #ic.style.Theme properties by name.
            % - if a scalar value is applied, it will impact the active #ic.Frame.ColorScheme only
            % - if a two-element array is set, it sets both [light, dark]
            %
            % {example}
            %   f.theme("primary", "#ff6600")
            %   f.theme("primary-foreground", ["#000", "#fff"])
            %   f.theme("Muted", "#eee", "border", "#ccc")
            % {/example}

            arguments (Input)
                this (1,1) ic.Frame
            end

            arguments (Input, Repeating)
                % theme property name. Supports any casing (snake_case, kebab-case, camelCase, PascalCase)
                name (1,1) string
                % color value, or [light, dark] pair
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
                    % single value → apply to active scheme only
                    currentValues = currentTheme.(propName);
                    if this.ColorScheme == "light"
                        currentTheme.(propName) = [val, currentValues(2)];
                    else
                        currentTheme.(propName) = [currentValues(1), val];
                    end
                else
                    % [light, dark] → set both values
                    currentTheme.(propName) = val;
                end
            end

            % assign back to trigger reactive sync (Theme.jsonencode → CSS)
            this.Theme = currentTheme;
        end

        function globalStyle(this, componentType, selector, varargin)
            % apply CSS styles to every instance of a component type. Setting a property to "" removes it.
            %
            % {example}
            %   f.globalStyle("ic.Button", ".ic-btn", "backgroundColor", "#000")
            %   f.globalStyle("ic.Button", ".ic-btn__label", struct("color", "red"))
            % {/example}

            arguments (Input)
                this (1,1) ic.Frame
                % fully qualified class name
                componentType (1,1) string
                % CSS selector scoped to the component wrapper
                selector (1,1) string
            end

            arguments (Input, Repeating)
                varargin
            end

            % parse styles into a struct
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

            % get or create the selector dictionary for this type
            if this.GlobalStyles.isKey(componentType)
                selectorDict = this.GlobalStyles(componentType);
            else
                selectorDict = dictionary(string.empty(), struct.empty());
            end

            % merge with existing styles for this selector
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

            % convert to kebab-case for CSS and publish
            mergedFields = fieldnames(existingStyles);
            kebabKeys = cell(1, numel(mergedFields));
            values = cell(1, numel(mergedFields));
            for kk = 1:numel(mergedFields)
                kebabKeys{kk} = char(ic.utils.toKebabCase(mergedFields{kk}));
                values{kk} = existingStyles.(mergedFields{kk});
            end
            cssStyles = containers.Map(kebabKeys, values);

            this.publish("@globalStyle", struct( ...
                "type", componentType, ...
                "selector", selector, ...
                "styles", cssStyles));
        end

        function clearGlobalStyle(this, componentType, selector)
            % remove styles for a specific selector on a component type.
            arguments (Input)
                this (1,1) ic.Frame
                % fully qualified class name
                componentType (1,1) string
                % CSS selector to clear
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
            % remove all styles for every selector on a component type.
            arguments (Input)
                this (1,1) ic.Frame
                % fully qualified class name
                componentType (1,1) string
            end

            if this.GlobalStyles.isKey(componentType)
                this.GlobalStyles(componentType) = [];
            end

            this.publish("@clearGlobalStyles", struct("type", componentType));
        end

        function clearAllGlobalStyles(this)
            % remove every global style rule across all component types.
            arguments (Input)
                this (1,1) ic.Frame
            end

            this.GlobalStyles = configureDictionary("string", "dictionary");
            this.publish("@clearAllGlobalStyles", struct());
        end

        function logger = logs(this)
            % return the logger instance for log inspection.
            % {returns} the #ic.core.Logger that collects frontend log entries {/returns}
            logger = this.Logger;
        end
    end

    methods (Access = private)
        function onLog(this, data)
            % handle incoming log events from the frontend.
            added = this.Logger.add(data);

            % print to command window when Debug is enabled
            if this.Debug && added
                this.Logger.show(1);
            end
        end
    end

    methods (Access = {?ic.core.Container, ?ic.core.Component, ?ic.mixin.Registrable}, Hidden)
        function frame = getFrame(this)
            % return the same frame
            frame = this;
        end
    end

    methods (Access = protected)
        function send(this, evt)
            % forward events to the #ic.core.View for transmission via uihtml.
            this.View.send(evt);
        end

        function registerSubtree(this, component)
            % add a component and its descendants to the registry.
            ic.mixin.Registrable.registerSubtreeWithFrame(component, this);
        end

        function deregisterSubtree(this, component)
            % remove a component and its descendants from the registry.
            ic.mixin.Registrable.deregisterSubtreeWithFrame(component, this);
        end
    end

    methods (Access = protected)
        function sendReactiveProperty(this, propertyName)
            % publish the current value of a reactive property to the frontend.
            if ~this.isAttached()
                return;
            end
            this.publish("@prop/" + propertyName, this.(propertyName));
        end
    end

    methods (Access = {?ic.core.Container, ?ic.mixin.Registrable})
        function registerDescendant(this, component)
            % add a component to the id→component registry for O(1) event routing.
            this.Registry(component.ID) = component;
        end

        function deregisterDescendant(this, id)
            % remove a component from the registry.
            if this.Registry.isKey(id)
                this.Registry(id) = [];
            end
        end
    end

end

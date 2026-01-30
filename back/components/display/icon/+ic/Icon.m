classdef Icon < ic.core.Component
    % ICON Displays an SVG icon from the built-in set or a custom path.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % Name of the icon from the IconName enum
        Name ic.IconName = ic.IconName.Info
        % Size in pixels (width = height)
        Size double = 24
        % Color of the icon (CSS color string or empty for currentColor)
        Color string = ""
        % Stroke width for line icons
        StrokeWidth double = 2
    end

    properties (SetObservable, AbortSet)
        % Path to a custom SVG file (overrides Name when set)
        CustomPath string = ""
    end

    properties (SetAccess = private, SetObservable, AbortSet, Description = "Reactive")
        % Base64-encoded SVG content (auto-populated from CustomPath)
        CustomSvg string = ""
    end

    methods
        function this = Icon(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);

            addlistener(this, 'CustomPath', 'PostSet', @(~,~) this.loadCustomIcon());
        end
    end

    methods (Access = private)
        function loadCustomIcon(this)
            if this.CustomPath == ""
                this.CustomSvg = "";
                return;
            end

            if ~isfile(this.CustomPath)
                warning('ic:Icon:FileNotFound', 'Icon file not found: %s', this.CustomPath);
                this.CustomSvg = "";
                return;
            end

            try
                content = fileread(this.CustomPath);
                this.CustomSvg = matlab.net.base64encode(uint8(content));
            catch ex
                warning('ic:Icon:ReadError', 'Failed to read icon file: %s', ex.message);
                this.CustomSvg = "";
            end
        end
    end
end

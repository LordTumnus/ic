classdef Icon < ic.core.Component
    % > ICON Displays an SVG icon.
    %
    % Create icons using static factory methods:
    %   icon = ic.Icon.fromName("chevron-down")
    %   icon = ic.Icon.fromFile("path/to/icon.svg")
    %   icon = ic.Icon.fromPath("M12 2L2 7l10 5 10-5-10-5z")
    %
    % Icon names are Lucide filenames without .svg extension.
    % Browse: https://lucide.dev/icons

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SIZE size of the icon (width = height)
        Size {ic.check.CssValidators.mustBeSize} = 16
        % > COLOR color of the icon (CSS color string or empty for currentColor)
        Color string = ""
        % > STROKEWIDTH stroke width for line icons
        StrokeWidth double = 2
    end

    properties (SetAccess = private, SetObservable, AbortSet, ...
            Description = "Reactive", Hidden)
        % > NAME Lucide icon name (kebab-case filename without .svg)
        Name string = "info"
        % > PATHDATA svg path data (d attribute)
        PathData string = ""
        % > CUSTOMSVG base64-encoded SVG content (from file)
        CustomSvg string = ""
    end

    methods (Static)
        function icon = fromName(name, id)
            % FROMNAME Create icon from Lucide icon name
            %   icon = ic.Icon.fromName("check")
            %   icon = ic.Icon.fromName("chevron-down")
            arguments
                name (1,1) string
                id string = "ic-" + matlab.lang.internal.uuid()
            end
            icon = ic.Icon(id);
            icon.Name = name;
        end

        function icon = fromFile(path, id)
            % FROMFILE Create icon from SVG file
            arguments
                path string
                id string = "ic-" + matlab.lang.internal.uuid()
            end
            if ~isfile(path)
                error('ic:Icon:FileNotFound', 'Icon file not found: %s', path);
            end
            icon = ic.Icon(id);
            content = fileread(path);
            icon.CustomSvg = matlab.net.base64encode(uint8(content));
        end

        function icon = fromPath(pathData, id)
            % FROMPATH Create icon from SVG path data (d attribute)
            arguments
                pathData string
                id string = "ic-" + matlab.lang.internal.uuid()
            end
            icon = ic.Icon(id);
            icon.PathData = pathData;
        end

        function names = list()
            % > LIST Return all available Lucide icon names.
            %   names = ic.Icon.list()           % all ~1900 icons
            %   names(contains(names, "arrow"))  % filter by keyword
            iconsDir = fullfile(ic.Icon.lucideDir());
            files = dir(fullfile(iconsDir, "*.svg"));
            names = string({files.name});
            names = erase(names, ".svg");
            names = sort(names);
        end

        function browse()
            % > BROWSE Open the Lucide icon gallery in the browser.
            %   ic.Icon.browse()
            web("https://lucide.dev/icons", "-browser");
        end
    end

    methods (Static, Access = private)
        function p = lucideDir()
            % Locate the lucide-static icons directory relative to this file
            thisDir = fileparts(mfilename("fullpath"));
            p = fullfile(thisDir, "..", "..", "..", "..", "..", ...
                "front", "node_modules", "lucide-static", "icons");
        end
    end

    methods
        function this = Icon(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end
    end
end

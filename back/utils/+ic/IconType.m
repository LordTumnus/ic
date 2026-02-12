classdef IconType
    % > ICONTYPE Serializable icon descriptor.
    %
    % Describes an icon source. Supports Lucide icons, SVG files, SVG path
    % data, and raster images.
    %
    %   icon = ic.IconType.lucide("apple")
    %   icon = ic.IconType.filePath("path/to/icon.svg")
    %   icon = ic.IconType.filePath("path/to/logo.png")
    %   icon = ic.IconType.svgPath("M12 2L2 7l10 5 10-5-10-5z")

    properties (SetAccess = immutable)
        % > TYPE icon source type: "lucide", "path", "file", or "raster"
        Type (1,1) string
        % > VALUE icon name, SVG path data, base64 SVG content, or data URI
        Value (1,1) string
    end

    methods
        function this = IconType(type, value)
            % > ICONTYPE Construct an icon descriptor.
            %   obj = ic.IconType(type, value)
            %
            % Prefer the static factory methods instead:
            %   ic.IconType.lucide("apple")
            %   ic.IconType.filePath("icon.svg")
            %   ic.IconType.svgPath("M12 2L2 7...")
            arguments
                type (1,1) string {mustBeMember(type, ...
                    ["lucide", "path", "file", "raster"])}
                value (1,1) string
            end
            this.Type = type;
            this.Value = value;
        end

        function json = jsonencode(this, varargin)
            % > JSONENCODE Serialize to {"type":"...","value":"..."}.
            if isempty(this)
                json = jsonencode([], varargin{:});
                return;
            end
            s = struct('type', char(this.Type), 'value', char(this.Value));
            json = jsonencode(s, varargin{:});
        end
    end

    methods (Static)
        function obj = lucide(name)
            % > LUCIDE Create icon from a Lucide icon name.
            %   icon = ic.IconType.lucide("apple")
            %   icon = ic.IconType.lucide("chevron-down")
            %
            % Browse: https://lucide.dev/icons
            arguments
                name (1,1) string
            end
            obj = ic.IconType("lucide", name);
        end

        function obj = svgPath(pathData)
            % > SVGPATH Create icon from SVG path data (d attribute).
            %   icon = ic.IconType.svgPath("M12 2L2 7l10 5 10-5-10-5z")
            arguments
                pathData (1,1) string
            end
            obj = ic.IconType("path", pathData);
        end

        function obj = filePath(path)
            % > FILEPATH Create icon from an image file.
            %   icon = ic.IconType.filePath("icon.svg")     % SVG
            %   icon = ic.IconType.filePath("logo.png")     % raster
            %
            % Supported formats: .svg, .png, .jpg, .jpeg, .gif, .bmp,
            % .webp, .ico
            arguments
                path (1,1) string
            end
            assert(isfile(path), "ic:IconType:FileNotFound", ...
                "Icon file not found: %s", path);

            [~, ~, ext] = fileparts(path);
            ext = lower(ext);

            if ext == ".svg"
                content = fileread(path);
                obj = ic.IconType("file", ...
                    matlab.net.base64encode(uint8(content)));
            else
                mimeMap = dictionary( ...
                    [".png", ".jpg", ".jpeg", ".gif", ...
                     ".bmp", ".webp", ".ico"], ...
                    ["image/png", "image/jpeg", "image/jpeg", ...
                     "image/gif", "image/bmp", "image/webp", ...
                     "image/x-icon"]);
                assert(isKey(mimeMap, ext), ...
                    "ic:IconType:UnsupportedFormat", ...
                    "Unsupported image format '%s'. Use .svg, " + ...
                    ".png, .jpg, .gif, .bmp, .webp, or .ico.", ext);

                fid = fopen(path, 'rb');
                data = fread(fid, Inf, '*uint8');
                fclose(fid);

                b64 = matlab.net.base64encode(data);
                dataUri = sprintf("data:%s;base64,%s", ...
                    mimeMap(ext), b64);
                obj = ic.IconType("raster", dataUri);
            end
        end
    end
end

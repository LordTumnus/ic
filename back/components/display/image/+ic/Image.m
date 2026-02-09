classdef Image < ic.core.Component
    % > IMAGE Displays a raster or vector image.
    %
    % Create images using static factory methods:
    %   img = ic.Image.fromFile("photo.png")
    %   img = ic.Image.fromUrl("https://example.com/photo.jpg")
    %   img = ic.Image.fromBase64(data, "image/png")
    %
    % Supported formats: PNG, JPG, GIF, WebP, SVG, BMP.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > WIDTH width of the image (CSS value: number=px, string=any unit)
        Width {ic.check.CssValidators.mustBeSize} = "auto"
        % > HEIGHT height of the image (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "auto"
        % > OBJECTFIT how the image fills its container
        ObjectFit string {mustBeMember(ObjectFit, ...
            ["contain", "cover", "fill", "none", "scale-down"])} = "contain"
        % > BORDERRADIUS corner rounding (CSS value: number=px, string=any unit)
        BorderRadius {ic.check.CssValidators.mustBeSize} = 2
        % > OPACITY image opacity (0 to 1)
        Opacity double {mustBeInRange(Opacity, 0, 1)} = 1
    end

    properties (SetAccess = private, SetObservable, AbortSet, ...
            Description = "Reactive", Hidden)
        % > SRC image source — URL or data URI (set via factory methods)
        Src string = ""
    end

    methods (Static)
        function img = fromFile(path, id)
            % FROMFILE Create image from a local file.
            %   img = ic.Image.fromFile("photo.png")
            %   img = ic.Image.fromFile("C:\data\scan.jpg")
            arguments
                path (1,1) string
                id string = "ic-" + matlab.lang.internal.uuid()
            end
            if ~isfile(path)
                error('ic:Image:FileNotFound', 'Image file not found: %s', path);
            end
            [~, ~, ext] = fileparts(path);
            mime = ic.Image.mimeFromExt(ext);
            % Read as binary (not text) to avoid line-ending corruption
            fid = fopen(path, 'rb');
            raw = fread(fid, '*uint8')';
            fclose(fid);
            b64 = matlab.net.base64encode(raw);
            img = ic.Image(id);
            img.Src = "data:" + mime + ";base64," + b64;
        end

        function img = fromUrl(url, id)
            % FROMURL Create image from a URL.
            %   img = ic.Image.fromUrl("https://example.com/photo.jpg")
            arguments
                url (1,1) string
                id string = "ic-" + matlab.lang.internal.uuid()
            end
            img = ic.Image(id);
            img.Src = url;
        end

        function img = fromBase64(data, mimeType, id)
            % FROMBASE64 Create image from base64-encoded data.
            %   img = ic.Image.fromBase64(b64str, "image/png")
            arguments
                data (1,1) string
                mimeType (1,1) string = "image/png"
                id string = "ic-" + matlab.lang.internal.uuid()
            end
            img = ic.Image(id);
            img.Src = "data:" + mimeType + ";base64," + data;
        end
    end

    methods (Static, Access = private)
        function mime = mimeFromExt(ext)
            % Map file extension to MIME type
            ext = lower(ext);
            map = dictionary( ...
                [".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".ico"], ...
                ["image/png", "image/jpeg", "image/jpeg", "image/gif", ...
                 "image/webp", "image/svg+xml", "image/bmp", "image/x-icon"]);
            if isKey(map, ext)
                mime = map(ext);
            else
                mime = "application/octet-stream";
            end
        end
    end

    events (Description = "Reactive")
        Clicked
        Loaded
        Error
    end

    methods (Access = private)
        function this = Image(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end
    end
end

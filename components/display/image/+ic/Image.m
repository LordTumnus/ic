classdef Image < ic.core.Component
    % > IMAGE Displays a raster or vector image.
    %
    %   img = ic.Image(Source="photo.png")
    %   img = ic.Image(Source="https://example.com/photo.jpg")
    %
    %
    % Supported formats: PNG, JPG, GIF, WebP, SVG, BMP.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SOURCE image source (file path or URL)
        Source ic.asset.Asset {ic.assets.mustBeImage} = ic.asset.Asset()
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

    events (Description = "Reactive")
        Clicked
        Loaded
        Error
    end

    methods
        function this = Image(props)
            arguments
                props.?ic.Image
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end

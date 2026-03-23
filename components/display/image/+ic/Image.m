classdef Image < ic.core.Component
    % displays a raster or vector image in any of the following formats:
    % PNG, JPG, GIF, WebP, SVG, BMP.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % image asset source
        Source ic.asset.Asset {ic.assets.mustBeImage} = ic.asset.Asset()

        % width of the image, in pixels or as a CSS string
        Width {ic.check.CssValidators.mustBeSize} = "auto"

        % height of the image, in pixels or as a CSS string
        Height {ic.check.CssValidators.mustBeSize} = "auto"

        % way in which the image fills its container. See the [Mozilla Developer documentation](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/object-fit) for details
        ObjectFit string {mustBeMember(ObjectFit, ...
            ["contain", "cover", "fill", "none", "scale-down"])} = "contain"

        % corner rounding radius, in pixels or as a CSS string
        BorderRadius {ic.check.CssValidators.mustBeSize} = 2

        % image opacity, between 0 (fully transparent) and 1 (fully opaque)
        Opacity double {mustBeInRange(Opacity, 0, 1)} = 1
    end

    events (Description = "Reactive")
        % triggered when the image is clicked
        % {payload}
        % source | struct or char: the image source that was clicked
        % {/payload}
        Clicked

        % triggered when the image finishes loading successfully
        % {payload}
        % source | struct or char: the image source that loaded
        % {/payload}
        Loaded

        % triggered when the image fails to load
        % {payload}
        % source | struct or char: the image source that failed
        % {/payload}
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

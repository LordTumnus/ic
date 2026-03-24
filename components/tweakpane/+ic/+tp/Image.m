classdef Image < ic.tp.Blade
    % read-only image display blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % image source
        Source (1,1) ic.asset.Asset

        % display height in pixels
        Height (1,1) double = 100

        % CSS object-fit mode controlling how the image fills the display area
        ObjectFit (1,1) string {mustBeMember(ObjectFit, ["contain","cover","fill"])} = "contain"
    end

    events (Description = "Reactive")
        % fires when the image is clicked
        Clicked
    end

    methods
        function this = Image(props)
            arguments
                props.?ic.tp.Image
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end

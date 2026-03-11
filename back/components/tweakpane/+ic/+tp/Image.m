classdef Image < ic.tp.Blade
    % > IMAGE Read-only image display blade for TweakPane.
    %
    % MATLAB pushes image data via ic.Asset (file path, URL, or base64).
    % The Svelte side renders it inline in the TweakPane panel.
    %
    % Example:
    %   tp.addImage(Label="Preview", Source="photo.png", Height=120);

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SOURCE image source (file path, URL, asset)
        Source (1,1) ic.asset.Asset
        % > HEIGHT display height in pixels
        Height (1,1) double = 100
        % > OBJECTFIT CSS object-fit mode
        ObjectFit (1,1) string {mustBeMember(ObjectFit, ["contain","cover","fill"])} = "contain"
    end

    events (Description = "Reactive")
        % > CLICKED fires when the image is clicked
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

classdef Button < ic.tp.Blade
    % > BUTTON Action button blade for TweakPane.

    events (Description = "Reactive")
        % > CLICKED fires when the button is clicked
        Clicked
    end

    methods
        function this = Button(props)
            arguments
                props.?ic.tp.Button
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end

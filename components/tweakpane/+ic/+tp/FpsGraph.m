classdef FpsGraph < ic.tp.Blade
    % auto-updating FPS graph blade for TweakPane.
    % Measures and plots the uihtml iframe frame rate.
    % uses [@tweakpane/plugin-essentials](https://github.com/tweakpane/plugin-essentials).

    methods
        function this = FpsGraph(props)
            arguments
                props.?ic.tp.FpsGraph
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end

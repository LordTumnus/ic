classdef FpsGraph < ic.tp.Blade
    % > FPSGRAPH Auto-updating FPS graph blade (plugin-essentials).

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

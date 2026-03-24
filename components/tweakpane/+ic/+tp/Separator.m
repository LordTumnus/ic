classdef Separator < ic.tp.Blade
    % visual divider blade for TweakPane

    methods
        function this = Separator(props)
            arguments
                props.?ic.tp.Separator
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end

classdef TabPage < ic.tp.ContainerBlade
    % > TABPAGE A single tab page within a TabGroup.

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % > PAGEINDEX index within the parent TabGroup (set by TabGroup)
        PageIndex (1,1) double = 0
    end

    methods
        function this = TabPage(props)
            arguments
                props.?ic.tp.TabPage
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.ContainerBlade(props);
        end
    end
end

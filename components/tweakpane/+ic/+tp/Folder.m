classdef Folder < ic.tp.ContainerBlade
    % collapsible folder container for TweakPane.
    % Can hold any blade type, including nested folders.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether the folder is open
        Expanded (1,1) logical = true
    end

    methods
        function this = Folder(props)
            arguments
                props.?ic.tp.Folder
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.ContainerBlade(props);
        end
    end
end

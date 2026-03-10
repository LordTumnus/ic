classdef Folder < ic.tp.ContainerBlade
    % > FOLDER Collapsible folder container for TweakPane.
    %
    % A folder can hold any blade type, including nested folders.
    %   folder = pane.addFolder("Advanced");
    %   folder.addSlider("Detail", Min=0, Max=10);

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > EXPANDED whether the folder is open
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

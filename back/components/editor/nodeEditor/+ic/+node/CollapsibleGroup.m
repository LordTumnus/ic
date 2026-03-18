classdef CollapsibleGroup < ic.node.Group
    % > COLLAPSIBLEGROUP Group with accent stripe, collapse toggle, and resize.
    %
    %   g = ic.node.CollapsibleGroup(Label="Pipeline", Width=500, Height=300)
    %   editor.addNode(g);
    %   g.addGroupChild(someNode);

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > COLLAPSED collapse to header-only (hide children)
        Collapsed (1,1) logical = false

        % > RESIZABLE allow user resize via drag handles
        Resizable (1,1) logical = true

        % > ACCENTCOLOR accent color for header stripe (CSS value, empty = theme default)
        AccentColor (1,1) string = ""
    end

    methods
        function this = CollapsibleGroup(props)
            % > COLLAPSIBLEGROUP Construct a collapsible group node.
            arguments
                props.?ic.node.CollapsibleGroup
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Group(props);
        end
    end
end

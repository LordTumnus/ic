classdef BasicGroup < ic.node.Group
    % > BASICGROUP Simple container group — label and background only.
    %   No accent stripe, no collapse, no resize handles.
    %
    %   g = ic.node.BasicGroup(Label="Section", BackgroundColor="#e0f0ff")
    %   editor.addNode(g);
    %   g.addGroupChild(someNode);

    methods
        function this = BasicGroup(props)
            % > BASICGROUP Construct a basic group node.
            arguments
                props.?ic.node.BasicGroup
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Group(props);
        end
    end
end

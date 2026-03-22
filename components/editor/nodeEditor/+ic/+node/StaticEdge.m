classdef StaticEdge < ic.node.Edge
    % > STATICEDGE Backward-compatible wrapper — creates Edge with Type="static".
    %   Thin wrapper around ic.node.Edge for API compatibility.
    %
    %   e = ic.node.StaticEdge()
    %   e = ic.node.StaticEdge(EndArrow="arrow", Animated=true)

    methods
        function this = StaticEdge(props)
            arguments
                props.?ic.node.Edge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            args = namedargs2cell(props);
            this@ic.node.Edge(args{:}, Type="static");
        end
    end
end

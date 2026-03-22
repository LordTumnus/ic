classdef FlowEdge < ic.node.Edge
    % > FLOWEDGE Backward-compatible wrapper — creates Edge with Type="flow".
    %   Thin wrapper around ic.node.Edge for API compatibility.
    %
    %   e = ic.node.FlowEdge()
    %   e = ic.node.FlowEdge(ParticleColor="#3b82f6", ParticleSize=4)

    methods
        function this = FlowEdge(props)
            arguments
                props.?ic.node.Edge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            args = namedargs2cell(props);
            this@ic.node.Edge(args{:}, Type="flow", Animated=true);
        end
    end
end

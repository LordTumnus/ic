classdef SignalEdge < ic.node.Edge
    % > SIGNALEDGE Backward-compatible wrapper — creates Edge with Type="signal".
    %   Thin wrapper around ic.node.Edge for API compatibility.
    %
    %   e = ic.node.SignalEdge()
    %   e = ic.node.SignalEdge(SignalColor="#22c55e", Amplitude=10)

    methods
        function this = SignalEdge(props)
            arguments
                props.?ic.node.Edge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            args = namedargs2cell(props);
            this@ic.node.Edge(args{:}, Type="signal");
        end
    end
end

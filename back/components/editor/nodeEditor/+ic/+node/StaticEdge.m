classdef StaticEdge < ic.node.Edge
    % > STATICEDGE Simple line edge with optional dash animation.
    %
    %   e = ic.node.StaticEdge()
    %   e = ic.node.StaticEdge(EndArrow="arrow", Animated=true)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ANIMATED dash animation on edge
        Animated (1,1) logical = false
    end

    methods
        function this = StaticEdge(props)
            % > STATICEDGE Construct a static edge.
            arguments
                props.?ic.node.StaticEdge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Edge(props);
        end

        function copyDisplayProps(this, source)
            this.Animated = source.Animated;
        end
    end
end

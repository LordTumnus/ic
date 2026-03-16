classdef StaticEdge < ic.node.Edge
    % > STATICEDGE Simple line edge with optional arrowheads.
    %
    %   e = ic.node.StaticEdge()
    %   e = ic.node.StaticEdge(EndArrow="arrow")
    %   e = ic.node.StaticEdge(StartArrow="diamond", EndArrow="arrow")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ANIMATED dash animation on edge
        Animated (1,1) logical = false

        % > STARTARROW arrowhead at source end: none | arrow | diamond | circle
        StartArrow (1,1) string {mustBeMember(StartArrow, ...
            ["none", "arrow", "diamond", "circle"])} = "none"

        % > ENDARROW arrowhead at target end: none | arrow | diamond | circle
        EndArrow (1,1) string {mustBeMember(EndArrow, ...
            ["none", "arrow", "diamond", "circle"])} = "none"
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
            this.StartArrow = source.StartArrow;
            this.EndArrow = source.EndArrow;
        end
    end
end

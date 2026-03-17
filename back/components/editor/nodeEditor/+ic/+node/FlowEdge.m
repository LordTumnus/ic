classdef FlowEdge < ic.node.Edge
    % > FLOWEDGE Animated particle edge — dots travel from source to target.
    %
    %   Particle count and speed are controlled by the source port's
    %   OutputRate and Speed properties. The edge controls only display:
    %   particle size and particle color. Stroke color and thickness
    %   come from the base Edge class.
    %
    %   e = ic.node.FlowEdge()
    %   e = ic.node.FlowEdge(ParticleColor="#3b82f6", ParticleSize=4)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > PARTICLESIZE circle radius in pixels
        ParticleSize (1,1) double {mustBePositive} = 3

        % > PARTICLECOLOR CSS color for particles (empty = --ic-primary)
        ParticleColor (1,1) string = ""
    end

    methods
        function this = FlowEdge(props)
            % > FLOWEDGE Construct a flow edge.
            arguments
                props.?ic.node.FlowEdge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Edge(props);
        end

        function copyDisplayProps(this, source)
            this.ParticleSize = source.ParticleSize;
            this.ParticleColor = source.ParticleColor;
        end
    end
end

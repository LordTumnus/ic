classdef Edge < ic.core.Component
    % > EDGE Connection between two node ports.
    %
    %   Edges are created via node.connect() — not directly by the user.
    %   SourceNode/TargetNode store Node IDs (strings), not handle references.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SOURCENODE source node ID
        SourceNode (1,1) string = ""

        % > SOURCEPORT source port name (used as Svelte Flow Handle ID)
        SourcePort (1,1) string = ""

        % > TARGETNODE target node ID
        TargetNode (1,1) string = ""

        % > TARGETPORT target port name (used as Svelte Flow Handle ID)
        TargetPort (1,1) string = ""

        % > LABEL edge label text
        Label (1,1) string = ""

        % > ANIMATED dash animation on edge
        Animated (1,1) logical = false
    end

    methods
        function this = Edge(props)
            % > EDGE Construct an edge.
            arguments
                props.?ic.node.Edge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end

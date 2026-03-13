classdef Node < ic.core.Component
    % > NODE Draggable node in a NodeEditor canvas.
    %
    %   n = ic.node.Node(Label="Filter", Position=[300 200], ...
    %       Inputs=ic.node.Port("in", Type="signal"), ...
    %       Outputs=ic.node.Port("out", Type="signal"));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL header text
        Label (1,1) string = ""

        % > POSITION canvas coordinates [x, y]
        Position (1,2) double = [0 0]

        % > INPUTS input port definitions (left side handles)
        Inputs (:,1) ic.node.Port = ic.node.Port.empty(0,1)

        % > OUTPUTS output port definitions (right side handles)
        Outputs (:,1) ic.node.Port = ic.node.Port.empty(0,1)

        % > DISABLED prevent interaction
        Disabled (1,1) logical = false

        % > COLOR accent color (empty = theme default)
        Color (1,1) string = ""

        % > ICON header icon
        Icon ic.asset.Asset = ic.asset.Asset.empty

        % > DATA arbitrary user payload
        Data (1,1) struct = struct()
    end

    methods
        function this = Node(props)
            % > NODE Construct a node.
            arguments
                props.?ic.node.Node
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function edge = connect(this, targetNode, sourcePort, targetPort, props)
            % > CONNECT Create an edge from this node to targetNode.
            %
            %   edge = n1.connect(n2)                      % auto-match ports
            %   edge = n1.connect(n2, "out", "in")         % explicit ports
            %   edge = n1.connect(n2, Label="data")        % auto + edge config
            %   edge = n1.connect(n2, "out", "in", Label="data")
            arguments
                this (1,1) ic.node.Node
                targetNode (1,1) ic.node.Node
                sourcePort (1,1) string = ""
                targetPort (1,1) string = ""
                props.Label (1,1) string = ""
                props.Animated (1,1) logical = false
            end

            % Validate both nodes are attached to a NodeEditor
            assert(~isempty(this.Parent), ...
                "ic:node:NotAttached", ...
                "Source node must be added to a NodeEditor before connecting.");
            assert(~isempty(targetNode.Parent), ...
                "ic:node:NotAttached", ...
                "Target node must be added to a NodeEditor before connecting.");
            assert(this.Parent == targetNode.Parent, ...
                "ic:node:DifferentEditors", ...
                "Both nodes must belong to the same NodeEditor.");

            % Auto-match ports
            if sourcePort == ""
                assert(~isempty(this.Outputs), ...
                    "ic:node:NoPorts", ...
                    "Source node has no output ports to auto-match.");
                sourcePort = this.Outputs(1).Name;
            end
            if targetPort == ""
                assert(~isempty(targetNode.Inputs), ...
                    "ic:node:NoPorts", ...
                    "Target node has no input ports to auto-match.");
                targetPort = targetNode.Inputs(1).Name;
            end

            % Create edge and add to editor
            edge = ic.node.Edge( ...
                SourceNode=this.ID, SourcePort=sourcePort, ...
                TargetNode=targetNode.ID, TargetPort=targetPort, ...
                Label=props.Label, Animated=props.Animated);

            this.Parent.addChild(edge, "edges");
        end

        function disconnect(this, targetNode, sourcePort)
            % > DISCONNECT Remove edges from this node to targetNode.
            %
            %   n1.disconnect(n2)           % all edges n1 → n2
            %   n1.disconnect(n2, "out")    % only from port "out"
            arguments
                this (1,1) ic.node.Node
                targetNode (1,1) ic.node.Node
                sourcePort (1,1) string = ""
            end

            assert(~isempty(this.Parent), ...
                "ic:node:NotAttached", ...
                "Node must be added to a NodeEditor before disconnecting.");

            edges = this.Parent.getChildrenInTarget("edges");
            for ii = numel(edges):-1:1
                e = edges(ii);
                if e.SourceNode == this.ID && e.TargetNode == targetNode.ID
                    if sourcePort == "" || e.SourcePort == sourcePort
                        this.Parent.removeChild(e);
                    end
                end
            end
        end

        function disconnectAll(this)
            % > DISCONNECTALL Remove all edges connected to this node.
            arguments
                this (1,1) ic.node.Node
            end

            assert(~isempty(this.Parent), ...
                "ic:node:NotAttached", ...
                "Node must be added to a NodeEditor before disconnecting.");

            edges = this.Parent.getChildrenInTarget("edges");
            for ii = numel(edges):-1:1
                e = edges(ii);
                if e.SourceNode == this.ID || e.TargetNode == this.ID
                    this.Parent.removeChild(e);
                end
            end
        end
    end
end

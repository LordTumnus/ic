classdef (Abstract) Node < ic.core.ComponentContainer
    % > NODE Abstract base for draggable nodes in a NodeEditor canvas.
    %   Each concrete subclass overrides defineDefaultPorts() to add its ports.
    %   Node is a ComponentContainer with targets ["inputs", "outputs"].
    %   Ports are Component children living in those target slots.
    %
    %   Traversal:
    %     node.Inputs / node.Outputs         → Port handle arrays
    %     node.Inputs(1).Edges               → edges connected to that port
    %     node.getConnectedNodes("portName") → nodes reachable from that port

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > POSITION canvas coordinates [x, y]
        Position (1,2) double = [0 0]

        % > DISABLED prevent interaction
        Disabled (1,1) logical = false

        % > LOCKED prevent drag and delete from UI
        Locked (1,1) logical = false

        % > DATA arbitrary user payload
        Data (1,1) struct = struct()
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.node.Node, ?ic.mixin.Reactive}, ...
            Hidden, Description = "Reactive")
        % > PARENTNODEID ID of the parent group node (empty = top-level)
        ParentNodeID (1,1) string = ""
    end

    properties (SetAccess = private)
        % > PARENTNODE handle reference to parent group (empty = top-level)
        ParentNode ic.node.Node
    end

    properties (Dependent, SetAccess = private)
        % > INPUTS array of Port children in the "inputs" target
        Inputs

        % > OUTPUTS array of Port children in the "outputs" target
        Outputs
    end

    methods (Abstract, Access = protected)
        % > DEFINEDEFAULTPORTS Each subclass adds its default ports.
        defineDefaultPorts(this)
    end

    methods
        function this = Node(props)
            % > NODE Construct a node (called by subclass constructors).
            %   No arguments block — abstract classes can't use props.?ClassName.
            this@ic.core.ComponentContainer(props);
            this.Targets = ["inputs", "outputs"];
            this.defineDefaultPorts();
        end

        % --- Dependent getters ---

        function ports = get.Inputs(this)
            ports = this.getChildrenInTarget("inputs");
        end

        function ports = get.Outputs(this)
            ports = this.getChildrenInTarget("outputs");
        end
    end

    methods (Access = public)
        function addPort(this, port, side)
            % > ADDPORT Add a port to the node.
            %
            %   node.addPort(ic.node.Port("signal"), "inputs")
            %   node.addPort(ic.node.Port("out"), "outputs")
            arguments
                this (1,1) ic.node.Node
                port (1,1) ic.node.Port
                side (1,1) string {mustBeMember(side, ["inputs", "outputs"])}
            end
            this.addChild(port, side);
        end

        function removePort(this, port)
            % > REMOVEPORT Remove a port and cascade-delete connected edges.
            arguments
                this (1,1) ic.node.Node
                port (1,1) ic.node.Port
            end

            % Cascade-delete edges connected to this port
            if ~isempty(this.Parent)
                portName = port.Name;
                portTarget = port.Target;
                edges = this.Parent.Edges;
                for ii = numel(edges):-1:1
                    e = edges(ii);
                    if (portTarget == "inputs" && e.TargetNode == this && e.TargetPortName == portName) || ...
                       (portTarget == "outputs" && e.SourceNode == this && e.SourcePortName == portName)
                        this.Parent.removeEdge(e);
                    end
                end
            end

            this.removeChild(port);
        end

        function port = findPort(this, name, side)
            % > FINDPORT Look up a port handle by name and side.
            %
            %   port = node.findPort("data", "inputs")
            %   port = node.findPort("out", "outputs")
            arguments
                this (1,1) ic.node.Node
                name (1,1) string
                side (1,1) string {mustBeMember(side, ["inputs", "outputs"])}
            end
            if side == "inputs"
                ports = this.Inputs;
            else
                ports = this.Outputs;
            end
            for ii = 1:numel(ports)
                if ports(ii).Name == name
                    port = ports(ii);
                    return
                end
            end
            error("ic:Node:PortNotFound", ...
                "Port '%s' not found in %s of node '%s'.", name, side, this.ID);
        end

        function edge = connect(this, targetNode, sourcePort, targetPort, props)
            % > CONNECT Create an edge from this node to targetNode.
            %
            %   edge = n1.connect(n2)                             % auto-match ports
            %   edge = n1.connect(n2, "out", "in")                % explicit ports
            %   edge = n1.connect(n2, Edge=ic.node.StaticEdge())  % custom edge
            arguments
                this (1,1) ic.node.Node
                targetNode (1,1) ic.node.Node
                sourcePort (1,1) string = ""
                targetPort (1,1) string = ""
                props.Edge (1,1) ic.node.Edge = ic.node.StaticEdge()
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
                outputs = this.Outputs;
                assert(~isempty(outputs), ...
                    "ic:node:NoPorts", ...
                    "Source node has no output ports to auto-match.");
                sourcePort = outputs(1).Name;
            end
            if targetPort == ""
                inputs = targetNode.Inputs;
                assert(~isempty(inputs), ...
                    "ic:node:NoPorts", ...
                    "Target node has no input ports to auto-match.");
                targetPort = inputs(1).Name;
            end

            % Configure edge endpoints and add to editor
            edge = props.Edge;
            edge.setEndpoints(this, sourcePort, targetNode, targetPort);
            this.Parent.addChild(edge, "edges");
        end

        function disconnect(this, targetNode, sourcePort)
            % > DISCONNECT Remove edges from this node to targetNode.
            %
            %   n1.disconnect(n2)           % all edges n1 -> n2
            %   n1.disconnect(n2, "out")    % only from port "out"
            arguments
                this (1,1) ic.node.Node
                targetNode (1,1) ic.node.Node
                sourcePort (1,1) string = ""
            end

            assert(~isempty(this.Parent), ...
                "ic:node:NotAttached", ...
                "Node must be added to a NodeEditor before disconnecting.");

            edges = this.Parent.Edges;
            for ii = numel(edges):-1:1
                e = edges(ii);
                if e.SourceNode == this && e.TargetNode == targetNode
                    if sourcePort == "" || e.SourcePortName == sourcePort
                        this.Parent.removeEdge(e);
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

            edges = this.Parent.Edges;
            for ii = numel(edges):-1:1
                e = edges(ii);
                if e.SourceNode == this || e.TargetNode == this
                    this.Parent.removeEdge(e);
                end
            end
        end

        function nodes = getConnectedNodes(this, portName)
            % > GETCONNECTEDNODES Get all nodes connected to this node.
            %   Returns unique nodes linked via edges. Optionally filter by port name.
            %
            %   allConnected = node.getConnectedNodes()
            %   fromOutput   = node.getConnectedNodes("data")
            arguments
                this (1,1) ic.node.Node
                portName (1,1) string = ""
            end

            if isempty(this.Parent)
                nodes = ic.node.Node.empty;
                return
            end

            edges = this.Parent.Edges;
            nodes = ic.node.Node.empty;
            for ii = 1:numel(edges)
                e = edges(ii);
                if e.SourceNode == this
                    if portName == "" || e.SourcePortName == portName
                        nodes(end+1) = e.TargetNode; %#ok<AGROW>
                    end
                elseif e.TargetNode == this
                    if portName == "" || e.TargetPortName == portName
                        nodes(end+1) = e.SourceNode; %#ok<AGROW>
                    end
                end
            end

            % Return unique nodes
            if ~isempty(nodes)
                [~, idx] = unique(arrayfun(@(n) n.ID, nodes));
                nodes = nodes(idx);
            end
        end

        function edges = getConnectedEdges(this, portName)
            % > GETCONNECTEDEDGES Get all edges connected to this node.
            %   Optionally filter by port name.
            %
            %   allEdges = node.getConnectedEdges()
            %   portEdges = node.getConnectedEdges("data")
            arguments
                this (1,1) ic.node.Node
                portName (1,1) string = ""
            end

            if isempty(this.Parent)
                edges = ic.node.Edge.empty;
                return
            end

            allEdges = this.Parent.Edges;
            edges = ic.node.Edge.empty;
            for ii = 1:numel(allEdges)
                e = allEdges(ii);
                if e.SourceNode == this
                    if portName == "" || e.SourcePortName == portName
                        edges(end+1) = e; %#ok<AGROW>
                    end
                elseif e.TargetNode == this
                    if portName == "" || e.TargetPortName == portName
                        edges(end+1) = e; %#ok<AGROW>
                    end
                end
            end
        end

        function validateChild(this, child, target)
            % > VALIDATECHILD only Port allowed as children
            assert(isa(child, "ic.node.Port"), ...
                "ic:Node:InvalidChild", ...
                "Only ic.node.Port can be added to a Node.");
            validateChild@ic.core.ComponentContainer(this, child, target);
        end

        function setParentNode(this, groupNode)
            % > SETPARENTNODE Set the parent group node (for subflow grouping).
            arguments
                this (1,1) ic.node.Node
                groupNode ic.node.Node = ic.node.Node.empty
            end
            if isempty(groupNode)
                this.ParentNode = ic.node.Node.empty;
                this.ParentNodeID = "";
            else
                this.ParentNode = groupNode;
                this.ParentNodeID = groupNode.ID;
            end
        end
    end
end

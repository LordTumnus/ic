classdef NodeEditor < ic.core.ComponentContainer & ic.mixin.Requestable
    % > NODEEDITOR Canvas for draggable nodes connected by edges.
    %
    %   editor = ic.NodeEditor(Height="500px");
    %   n1 = ic.node.Node(Label="Source", Position=[100 150], ...
    %       Outputs=ic.node.Port("out", Type="signal"));
    %   n2 = ic.node.Node(Label="Filter", Position=[400 150], ...
    %       Inputs=ic.node.Port("in", Type="signal"));
    %   editor.addNode(n1);
    %   editor.addNode(n2);
    %   e = n1.connect(n2);

    events (Description = "Reactive")
        % > NODEMOVED fires when user finishes dragging a node
        NodeMoved
    end

    events
        % > CONNECTED fires after a connection is created from the UI
        Connected

        % > DISCONNECTED fires after an edge is removed from the UI
        Disconnected

        % > NODEDELETED fires after node(s) are deleted from the UI
        NodeDeleted
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > HEIGHT container height (CSS value)
        Height (1,1) string = "100%"

        % > GRIDSIZE snap grid spacing (0 = no snap)
        GridSize (1,1) double = 20

        % > EDGEGEOMETRY default edge type: bezier | straight | smoothstep | step
        EdgeGeometry (1,1) string {mustBeMember(EdgeGeometry, ...
            ["bezier", "straight", "smoothstep", "step"])} = "bezier"
    end

    properties (Dependent, SetAccess = private)
        % > NODES array of Node children (read-only)
        Nodes

        % > EDGES array of Edge children (read-only)
        Edges
    end

    properties (Access = private)
        % Guard flag: prevents handleNodeDestroyed from duplicating
        % cleanup that removeNode already handles.
        IsRemovingNode (1,1) logical = false
    end

    methods
        function this = NodeEditor(props)
            % > NODEEDITOR Construct a node editor.
            arguments
                props.?ic.NodeEditor
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = ["nodes", "edges"];
            this.setupEventHandlers();
        end

        % --- Dependent getters ---

        function nodes = get.Nodes(this)
            nodes = this.getChildrenInTarget("nodes");
        end

        function edges = get.Edges(this)
            edges = this.getChildrenInTarget("edges");
        end
    end

    methods (Access = public)
        function addNode(this, node)
            % > ADDNODE Add a node to the canvas.
            arguments
                this (1,1) ic.NodeEditor
                node (1,1) ic.node.Node
            end
            this.addChild(node, "nodes");

            % Listen for direct delete(node) — cascade connected edges
            addlistener(node, 'ObjectBeingDestroyed', ...
                @(src, ~) this.handleNodeDestroyed(src));
        end

        function removeNode(this, node)
            % > REMOVENODE Remove a node and cascade-delete connected edges.
            arguments
                this (1,1) ic.NodeEditor
                node (1,1) ic.node.Node
            end

            this.IsRemovingNode = true;

            % Cascade-delete connected edges first
            edges = this.Edges;
            for ii = numel(edges):-1:1
                if edges(ii).SourceNode == node.ID || edges(ii).TargetNode == node.ID
                    this.removeChild(edges(ii));
                end
            end

            % Remove the node
            this.removeChild(node);

            this.IsRemovingNode = false;
        end

        function validateChild(this, child, target)
            % > VALIDATECHILD only Node and Edge allowed as children
            if target == "nodes"
                assert(isa(child, "ic.node.Node"), ...
                    "ic:NodeEditor:InvalidChild", ...
                    "Only ic.node.Node can be added to the 'nodes' target.");
            elseif target == "edges"
                assert(isa(child, "ic.node.Edge"), ...
                    "ic:NodeEditor:InvalidChild", ...
                    "Only ic.node.Edge can be added to the 'edges' target.");
            end
            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function setupEventHandlers(this)
            % Request handlers: frontend calls request('connect', data) etc.
            this.onRequest("Connect",     @(comp, data) comp.handleConnect(data));
            this.onRequest("Disconnect",  @(comp, data) comp.handleDisconnect(data));
            this.onRequest("DeleteNodes", @(comp, data) comp.handleDeleteNodes(data));
        end

        function result = handleConnect(this, data)
            % Frontend drew a connection — create an Edge child.
            srcNode = this.findNodeById(data.source);
            tgtNode = this.findNodeById(data.target);
            edge = srcNode.connect(tgtNode, string(data.sourcePort), string(data.targetPort));
            notify(this, 'Connected', ic.event.MEvent(struct( ...
                'Edge', edge, ...
                'SourceNode', srcNode, 'TargetNode', tgtNode)));
            result = edge.ID;
        end

        function result = handleDeleteNodes(this, data)
            % Frontend deleted node(s) — cascade-remove and destroy.
            ids = string(data.nodeIds);
            for ii = 1:numel(ids)
                node = this.findNodeById(ids(ii));
                this.removeNode(node);
                delete(node);
            end
            notify(this, 'NodeDeleted', ic.event.MEvent(struct('NodeIds', ids)));
            result = true;
        end

        function result = handleDisconnect(this, data)
            % Frontend deleted a standalone edge.
            edgeId = string(data.edgeId);
            edges = this.Edges;
            for ii = 1:numel(edges)
                if edges(ii).ID == edgeId
                    edge = edges(ii);
                    this.removeChild(edge);
                    delete(edge);
                    notify(this, 'Disconnected', ic.event.MEvent(struct('EdgeId', edgeId)));
                    result = true;
                    return
                end
            end
            result = false;
        end

        function node = findNodeById(this, id)
            nodes = this.Nodes;
            for ii = 1:numel(nodes)
                if nodes(ii).ID == string(id)
                    node = nodes(ii);
                    return
                end
            end
            error("ic:NodeEditor:NodeNotFound", ...
                "Node with ID '%s' not found.", id);
        end

        function handleNodeDestroyed(this, node)
            % Called via ObjectBeingDestroyed listener on each Node.
            % Two cases:
            %   1. removeNode called → IsRemovingNode=true → skip.
            %   2. User called delete(node) directly → cascade edges.
            if ~isvalid(this), return; end
            if this.IsRemovingNode, return; end

            % Cascade-delete connected edges
            edges = this.Edges;
            for ii = numel(edges):-1:1
                if edges(ii).SourceNode == node.ID || edges(ii).TargetNode == node.ID
                    this.removeChild(edges(ii));
                end
            end
        end
    end
end

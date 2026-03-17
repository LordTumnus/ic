classdef NodeEditor < ic.core.ComponentContainer & ic.mixin.Requestable
    % > NODEEDITOR Canvas for draggable nodes connected by edges.
    %
    %   editor = ic.NodeEditor(Height="500px");
    %   n1 = ic.node.Transform(Label="Source", Position=[100 150]);
    %   n2 = ic.node.Transform(Label="Sink", Position=[400 150]);
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

        % > SELECTIONCHANGED fires when user changes node/edge selection
        SelectionChanged
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > HEIGHT container height (CSS value)
        Height (1,1) string = "100%"

        % > GRIDSIZE snap grid spacing (0 = no snap)
        GridSize (1,1) double = 20

        % > EDGEGEOMETRY default edge type: bezier | straight | smoothstep | step
        EdgeGeometry (1,1) string {mustBeMember(EdgeGeometry, ...
            ["bezier", "straight", "smoothstep", "step"])} = "bezier"

        % > SHOWMINIMAP show/hide the minimap overlay
        ShowMiniMap (1,1) logical = false

        % > LAYOUT auto-layout direction: horizontal | vertical
        Layout (1,1) string {mustBeMember(Layout, ...
            ["horizontal", "vertical"])} = "horizontal"

        % > SNAPTOGRID snap nodes to grid when dragging
        SnapToGrid (1,1) logical = false

        % > GRIDVARIANT background grid pattern: dots | lines | cross
        GridVariant (1,1) string {mustBeMember(GridVariant, ...
            ["dots", "lines", "cross"])} = "dots"
    end

    properties (SetObservable, Description = "Reactive", ...
            SetAccess = {?ic.NodeEditor, ?ic.mixin.Reactive}, Hidden)
        % > SELECTEDNODEIDS IDs of currently selected nodes (Svelte bridge)
        SelectedNodeIds (1,:) string = string.empty

        % > SELECTEDEDGEIDS IDs of currently selected edges (Svelte bridge)
        SelectedEdgeIds (1,:) string = string.empty
    end

    properties (Dependent, SetAccess = private)
        % > NODES array of Node children (read-only)
        Nodes

        % > EDGES array of Edge children (read-only)
        Edges

        % > SELECTEDNODES currently selected Node children (read-only)
        SelectedNodes

        % > SELECTEDEDGES currently selected Edge children (read-only)
        SelectedEdges
    end

    properties (Access = private)
        % Guard flag: prevents handleNodeDestroyed from duplicating
        % cleanup that removeNode already handles.
        IsRemovingNode (1,1) logical = false

        % Guard flag: prevents handleEdgeDestroyed from duplicating
        % cleanup that removeChild already handles.
        IsRemovingEdge (1,1) logical = false
    end

    methods
        function this = NodeEditor(props)
            % > NODEEDITOR Construct a node editor.
            arguments
                props.?ic.NodeEditor
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = ["nodes", "edges", "toolbar"];
            this.setupEventHandlers();

            % Fire SelectionChanged when frontend writes selection IDs
            addlistener(this, 'SelectedNodeIds', 'PostSet', ...
                @(~, ~) this.fireSelectionChanged());
            addlistener(this, 'SelectedEdgeIds', 'PostSet', ...
                @(~, ~) this.fireSelectionChanged());
        end

        % --- Dependent getters ---

        function nodes = get.Nodes(this)
            nodes = this.getChildrenInTarget("nodes");
        end

        function edges = get.Edges(this)
            edges = this.getChildrenInTarget("edges");
        end

        function nodes = get.SelectedNodes(this)
            ids = this.SelectedNodeIds;
            if isempty(ids)
                nodes = ic.node.Node.empty;
                return
            end
            all = this.Nodes;
            mask = arrayfun(@(n) ismember(n.ID, ids), all);
            nodes = all(find(mask)); %#ok<FNDSB>
        end

        function edges = get.SelectedEdges(this)
            ids = this.SelectedEdgeIds;
            if isempty(ids)
                edges = ic.node.Edge.empty;
                return
            end
            all = this.Edges;
            mask = arrayfun(@(e) ismember(e.ID, ids), all);
            edges = all(find(mask)); %#ok<FNDSB>
        end
    end

    methods (Description = "Reactive")
        function out = fitView(this)
            % > FITVIEW Fit all nodes into the viewport.
            out = this.publish("fitView", []);
        end

        function out = zoomTo(this, level)
            % > ZOOMTO Zoom to a specific level (1 = 100%).
            arguments
                this
                level (1,1) double
            end
            out = this.publish("zoomTo", struct('level', level));
        end

        function out = selectAll(this)
            % > SELECTALL Select all nodes and edges.
            out = this.publish("selectAll", []);
        end

        function out = clearSelection(this)
            % > CLEARSELECTION Deselect all nodes and edges.
            out = this.publish("clearSelection", []);
        end

        function out = relayout(this, direction)
            % > RELAYOUT Auto-layout nodes using dagre algorithm.
            arguments
                this
                direction (1,1) string {mustBeMember(direction, ...
                    ["", "horizontal", "vertical"])} = ""
            end
            if direction ~= ""
                this.Layout = direction;
            end
            out = this.publish("relayout", []);
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
            % (must delete edges before removing node so port refs are still valid)
            edges = this.Edges;
            for ii = numel(edges):-1:1
                e = edges(ii);
                if e.SourceNode == node || e.TargetNode == node
                    this.removeEdge(e);
                end
            end

            % Remove the node (framework deregisters nested port children)
            this.removeChild(node);

            this.IsRemovingNode = false;
        end

        function removeEdge(this, edge)
            % > REMOVEEDGE Remove an edge and clean up port references.
            arguments
                this (1,1) ic.NodeEditor
                edge (1,1) ic.node.Edge
            end
            this.IsRemovingEdge = true;
            this.removeChild(edge);
            delete(edge);  % Edge destructor unregisters from ports
            this.IsRemovingEdge = false;
        end

        function removeNodes(this, nodes)
            % > REMOVENODES Remove multiple nodes and their connected edges.
            arguments
                this (1,1) ic.NodeEditor
                nodes (1,:) ic.node.Node
            end
            for ii = numel(nodes):-1:1
                this.removeNode(nodes(ii));
                delete(nodes(ii));
            end
        end

        function edges = connectAll(this, pairs)
            % > CONNECTALL Connect multiple node pairs at once.
            %   pairs is an N-by-2 cell array: {srcNode, tgtNode; ...}
            arguments
                this (1,1) ic.NodeEditor
                pairs (:,2) cell
            end
            edges = ic.node.Edge.empty(1, 0);
            for ii = 1:size(pairs, 1)
                edges(end+1) = pairs{ii,1}.connect(pairs{ii,2}); %#ok<AGROW>
            end
        end

        function node = findNodeById(this, id)
            % > FINDNODEBYID Look up a node by its ID string.
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

        function edge = findEdgeById(this, id)
            % > FINDEDGEBYID Look up an edge by its ID string.
            edges = this.Edges;
            for ii = 1:numel(edges)
                if edges(ii).ID == string(id)
                    edge = edges(ii);
                    return
                end
            end
            error("ic:NodeEditor:EdgeNotFound", ...
                "Edge with ID '%s' not found.", id);
        end

        function validateChild(this, child, target)
            % > VALIDATECHILD enforce type constraints per target
            if target == "nodes"
                assert(isa(child, "ic.node.Node"), ...
                    "ic:NodeEditor:InvalidChild", ...
                    "Only ic.node.Node subclasses can be added to 'nodes'.");
            elseif target == "edges"
                assert(isa(child, "ic.node.Edge"), ...
                    "ic:NodeEditor:InvalidChild", ...
                    "Only ic.node.Edge subclasses can be added to 'edges'.");

                % Listen for direct delete(edge) — remove from view
                addlistener(child, 'ObjectBeingDestroyed', ...
                    @(src, ~) this.handleEdgeDestroyed(src));
            elseif target == "toolbar"
                assert(isa(child, "ic.core.Component"), ...
                    "ic:NodeEditor:InvalidChild", ...
                    "Only ic.core.Component can be added to 'toolbar'.");
            end
            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function fireSelectionChanged(this)
            notify(this, 'SelectionChanged', ic.event.MEvent(struct( ...
                'SelectedNodes', this.SelectedNodes, ...
                'SelectedEdges', this.SelectedEdges)));
        end

        function setupEventHandlers(this)
            this.onRequest("Connect",         @(comp, data) comp.handleConnect(data));
            this.onRequest("Disconnect",      @(comp, data) comp.handleDisconnect(data));
            this.onRequest("DeleteNodes",     @(comp, data) comp.handleDeleteNodes(data));
            this.onRequest("DuplicateNodes",  @(comp, data) comp.handleDuplicateNodes(data));
        end

        function result = handleConnect(this, data)
            % Frontend drew a connection — edge type from source port.
            srcNode = this.findNodeById(data.source);
            tgtNode = this.findNodeById(data.target);
            srcPort = srcNode.findPort(string(data.sourcePort), "outputs");
            tgtPort = tgtNode.findPort(string(data.targetPort), "inputs");

            % Validate MaxConnections on both ports
            if numel(srcPort.Edges) >= srcPort.MaxConnections
                error("ic:NodeEditor:MaxConnections", ...
                    "Source port '%s' already has %d/%d connections.", ...
                    srcPort.Name, numel(srcPort.Edges), srcPort.MaxConnections);
            end
            if numel(tgtPort.Edges) >= tgtPort.MaxConnections
                error("ic:NodeEditor:MaxConnections", ...
                    "Target port '%s' already has %d/%d connections.", ...
                    tgtPort.Name, numel(tgtPort.Edges), tgtPort.MaxConnections);
            end

            typeMap = dictionary("static", "ic.node.StaticEdge", ...
                                 "flow",   "ic.node.FlowEdge", ...
                                 "signal", "ic.node.SignalEdge");
            edge = feval(typeMap(srcPort.Type));
            edge.setEndpoints(srcNode, string(data.sourcePort), ...
                              tgtNode, string(data.targetPort));
            this.addChild(edge, "edges");

            notify(this, 'Connected', ic.event.MEvent(struct( ...
                'Edge', edge, ...
                'SourceNode', srcNode, 'TargetNode', tgtNode)));
            result = edge.ID;
        end

        function result = handleDeleteNodes(this, data)
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
            edgeId = string(data.edgeId);
            edges = this.Edges;
            for ii = 1:numel(edges)
                if edges(ii).ID == edgeId
                    edge = edges(ii);
                    this.removeEdge(edge);
                    notify(this, 'Disconnected', ic.event.MEvent(struct('EdgeId', edgeId)));
                    result = true;
                    return
                end
            end
            result = false;
        end

        function result = handleDuplicateNodes(this, data)
            % Frontend sends node IDs; MATLAB clones from actual objects.
            %   data.nodeIds: string array of node IDs to duplicate
            %   data.offset:  [dx, dy] position offset
            fprintf("[NE-MATLAB] handleDuplicateNodes called\n");
            fprintf("[NE-MATLAB] data fields: %s\n", strjoin(string(fieldnames(data)), ", "));
            fprintf("[NE-MATLAB] data.nodeIds class=%s size=%s\n", class(data.nodeIds), mat2str(size(data.nodeIds)));
            disp(data.nodeIds);
            nodeIds = string(data.nodeIds);
            offset  = reshape(double(data.offset), 1, []);

            oldToNew = containers.Map('KeyType', 'char', 'ValueType', 'any');
            newNodeIds = {};

            % Clone each node
            for ii = 1:numel(nodeIds)
                orig = this.findNodeById(nodeIds(ii));
                if isempty(orig), continue; end

                % Instantiate same class (constructor sets defaults + ports)
                newNode = feval(class(orig));

                % Copy all reactive properties via metaclass introspection
                mc = metaclass(orig);
                for jj = 1:numel(mc.PropertyList)
                    mp = mc.PropertyList(jj);
                    if mp.Description ~= "Reactive", continue; end
                    if mp.Dependent,                  continue; end
                    if ~strcmp(mp.SetAccess, 'public'), continue; end
                    val = orig.(mp.Name);
                    if mp.Name == "Position"
                        val = val + offset;
                    end
                    newNode.(mp.Name) = val;
                end

                % Clone port configuration (reactive props on each port)
                ic.NodeEditor.clonePorts(orig.Outputs, newNode.Outputs);
                ic.NodeEditor.clonePorts(orig.Inputs,  newNode.Inputs);

                this.addNode(newNode);
                oldToNew(char(nodeIds(ii))) = newNode;
                newNodeIds{end+1} = newNode.ID; %#ok<AGROW>
            end

            % Recreate internal edges (both endpoints in the cloned set)
            edges = this.Edges;
            for ii = 1:numel(edges)
                e = edges(ii);
                srcKey = char(e.SourceNode.ID);
                tgtKey = char(e.TargetNode.ID);
                if oldToNew.isKey(srcKey) && oldToNew.isKey(tgtKey)
                    try
                        newSrc = oldToNew(srcKey);
                        newTgt = oldToNew(tgtKey);
                        newSrc.connect(newTgt, e.SourcePortName, e.TargetPortName);
                    catch
                        % Skip edges that can't be recreated
                    end
                end
            end

            result = struct('nodeIds', {newNodeIds});
        end

        function handleNodeDestroyed(this, node)
            if ~isvalid(this), return; end
            if this.IsRemovingNode, return; end

            % Cascade-delete connected edges (must happen before
            % the node/ports become invalid)
            edges = this.Edges;
            for ii = numel(edges):-1:1
                e = edges(ii);
                if e.SourceNode == node || e.TargetNode == node
                    this.removeEdge(e);
                end
            end
        end

        function handleEdgeDestroyed(this, edge)
            if ~isvalid(this), return; end
            if this.IsRemovingEdge, return; end

            % Remove edge from view (triggered by direct delete(edge))
            this.IsRemovingEdge = true;
            this.removeChild(edge);
            this.IsRemovingEdge = false;
        end
    end

    methods (Static, Access = private)
        function clonePorts(origPorts, newPorts)
            % Copy all reactive properties from original ports to new ports.
            for jj = 1:min(numel(origPorts), numel(newPorts))
                mc = metaclass(origPorts(jj));
                for kk = 1:numel(mc.PropertyList)
                    mp = mc.PropertyList(kk);
                    if mp.Description ~= "Reactive",  continue; end
                    if mp.Dependent,                   continue; end
                    if ~strcmp(mp.SetAccess, 'public'), continue; end
                    newPorts(jj).(mp.Name) = origPorts(jj).(mp.Name);
                end
            end
        end
    end
end

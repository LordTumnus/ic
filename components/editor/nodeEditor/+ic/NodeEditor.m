classdef NodeEditor < ic.core.ComponentContainer & ic.mixin.Requestable
    % {wip} {/wip}
    % canvas for draggable nodes connected by edges.

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

        % > DEFAULTGROUPTYPE class used when creating groups from UI actions
        DefaultGroupType (1,1) string {mustBeMember(DefaultGroupType, ...
            ["ic.node.CollapsibleGroup", "ic.node.BasicGroup"])} = "ic.node.CollapsibleGroup"

        % > PLAYING whether edge animations are running
        Playing (1,1) logical = true

        % > PLAYSPEED animation speed multiplier (0.5x, 1x, 2x, 5x, 10x)
        PlaySpeed (1,1) double {mustBePositive} = 1
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
            %   If the node is a Group, cascade-deletes all children first.
            arguments
                this (1,1) ic.NodeEditor
                node (1,1) ic.node.Node
            end

            this.IsRemovingNode = true;

            % If it's a Group, cascade-delete children first
            if isa(node, 'ic.node.Group')
                children = node.GroupChildren;
                for ii = numel(children):-1:1
                    this.removeNode(children(ii));
                    delete(children(ii));
                end
            end

            % Cascade-delete connected edges
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

        function group = groupNodes(this, nodes, props)
            % > GROUPNODES Create a group wrapping the given nodes.
            %   Automatically creates boundary ports for any edges that cross
            %   the group boundary, with correct types and signal/flow props
            %   copied from the connected output ports. Rewires crossing edges
            %   through the boundary ports.
            %
            %   All nodes must already be in this editor. Group nodes in the
            %   input array are silently filtered out.
            %
            %   g = editor.groupNodes([n1, n2], Label="Pipeline")
            %   g = editor.groupNodes([n1, n2, n3], ...
            %       Label="DSP", AccentColor="#3b82f6")
            arguments
                this (1,1) ic.NodeEditor
                nodes (1,:) ic.node.Node
                props.Label (1,1) string = "Group"
                props.Position (1,2) double = [NaN NaN]
                props.Width (1,1) double = NaN
                props.Height (1,1) double = NaN
                props.BackgroundColor (1,1) string = ""
                props.BackgroundOpacity (1,1) double = 0
                props.AccentColor (1,1) string = ""
                props.GroupType (1,1) string = ""
            end

            % Filter out groups
            keep = arrayfun(@(n) ~isa(n, 'ic.node.Group'), nodes);
            nodes = nodes(find(keep)); %#ok<FNDSB>
            assert(numel(nodes) >= 1, ...
                "ic:NodeEditor:TooFewNodes", ...
                "groupNodes requires at least 1 non-group node.");
            for ii = 1:numel(nodes)
                assert(~isempty(nodes(ii).Parent) && nodes(ii).Parent == this, ...
                    "ic:NodeEditor:NotAttached", ...
                    "All nodes must already be in this NodeEditor.");
            end
            selectedIds = arrayfun(@(n) n.ID, nodes);

            % Compute bounding box (auto-compute if not given)
            positions = cell2mat(arrayfun( ...
                @(n) n.Position, nodes, 'UniformOutput', false)');
            nodeW = 180; nodeH = 60;  % estimated node size
            pad = [40, 50, 40, 40];   % left, top, right, bottom
            if any(isnan(props.Position))
                props.Position = [min(positions(:,1)) - pad(1), ...
                                  min(positions(:,2)) - pad(2)];
            end
            if isnan(props.Width)
                props.Width = max(positions(:,1)) + nodeW + pad(3) ...
                    - props.Position(1);
            end
            if isnan(props.Height)
                props.Height = max(positions(:,2)) + nodeH + pad(4) ...
                    - props.Position(2);
            end

            % Create group
            groupType = props.GroupType;
            if groupType == ""
                groupType = this.DefaultGroupType;
            end
            groupArgs = {'Label', props.Label, ...
                'Position', props.Position, ...
                'Width', props.Width, 'Height', props.Height, ...
                'BackgroundColor', props.BackgroundColor, ...
                'BackgroundOpacity', props.BackgroundOpacity};
            if props.AccentColor ~= "" && groupType == "ic.node.CollapsibleGroup"
                groupArgs = [groupArgs, {'AccentColor', props.AccentColor}];
            end
            group = feval(groupType, groupArgs{:});
            this.addNode(group);

            % Analyze crossing edges
            edges = this.Edges;
            inboundIdx  = [];
            outboundIdx = [];
            for ii = 1:numel(edges)
                e = edges(ii);
                srcIn = ismember(e.SourceNodeID, selectedIds);
                tgtIn = ismember(e.TargetNodeID, selectedIds);
                if ~srcIn && tgtIn
                    inboundIdx(end+1) = ii; %#ok<AGROW>
                elseif srcIn && ~tgtIn
                    outboundIdx(end+1) = ii; %#ok<AGROW>
                end
            end

            % Rewire INBOUND edges (external → selected)
            for ii = 1:numel(inboundIdx)
                e = edges(inboundIdx(ii));
                srcPort = e.SourcePort;
                portType = srcPort.Type;
                bpName = ic.NodeEditor.uniquePortName( ...
                    group, e.TargetPortName + "_in", "inputs");
                bp = ic.node.Port(bpName, ...
                    Label=string(bpName), Type=portType);
                ic.NodeEditor.copyPortBehavior(srcPort, bp);
                group.addPort(bp, "inputs");

                extNode = e.SourceNode;
                extPort = e.SourcePortName;
                intNode = e.TargetNode;
                intPort = e.TargetPortName;
                this.removeEdge(e);

                extEdge = ic.node.Edge(Type=portType);
                extEdge.setEndpoints(extNode, extPort, group, bpName);
                this.addChild(extEdge, "edges");

                intEdge = ic.node.Edge(Type=portType);
                intEdge.setEndpoints(group, bpName + ":int", intNode, intPort);
                this.addChild(intEdge, "edges");
            end

            % Rewire OUTBOUND edges (selected → external)
            for ii = 1:numel(outboundIdx)
                e = edges(outboundIdx(ii));
                srcPort = e.SourcePort;
                portType = srcPort.Type;
                bpName = ic.NodeEditor.uniquePortName( ...
                    group, e.SourcePortName + "_out", "outputs");
                bp = ic.node.Port(bpName, ...
                    Label=string(bpName), Type=portType);
                ic.NodeEditor.copyPortBehavior(srcPort, bp);
                group.addPort(bp, "outputs");

                extNode = e.TargetNode;
                extPort = e.TargetPortName;
                intNode = e.SourceNode;
                intPort = e.SourcePortName;
                this.removeEdge(e);

                intEdge = ic.node.Edge(Type=portType);
                intEdge.setEndpoints(intNode, intPort, group, bpName + ":int");
                this.addChild(intEdge, "edges");

                extEdge = ic.node.Edge(Type=portType);
                extEdge.setEndpoints(group, bpName, extNode, extPort);
                this.addChild(extEdge, "edges");
            end

            % Parent all nodes into the group
            for ii = 1:numel(nodes)
                group.addGroupChild(nodes(ii));
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
            this.onRequest("UngroupNodes",    @(comp, data) comp.handleUngroupNodes(data));
            this.onRequest("GroupSelection",  @(comp, data) comp.handleGroupSelection(data));
            this.onRequest("UpdateNodeProp",  @(comp, data) comp.handleUpdateNodeProp(data));
            this.onRequest("UpdateEdgeProp",  @(comp, data) comp.handleUpdateEdgeProp(data));
        end

        function result = handleConnect(this, data)
            % Frontend drew a connection — edge type from source port.
            srcNode = this.findNodeById(data.source);
            tgtNode = this.findNodeById(data.target);

            % :int suffix reverses the port side (interior group handles)
            srcPortName = string(data.sourcePort);
            tgtPortName = string(data.targetPort);
            srcIsInt = endsWith(srcPortName, ":int");
            tgtIsInt = endsWith(tgtPortName, ":int");
            srcLookup = regexprep(srcPortName, ':int$', '');
            tgtLookup = regexprep(tgtPortName, ':int$', '');
            srcSide = "outputs"; if srcIsInt, srcSide = "inputs"; end
            tgtSide = "inputs";  if tgtIsInt, tgtSide = "outputs"; end
            srcPort = srcNode.findPort(srcLookup, srcSide);
            tgtPort = tgtNode.findPort(tgtLookup, tgtSide);

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

            edge = ic.node.Edge(Type=srcPort.Type);
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

        function result = handleUngroupNodes(this, data)
            % Ungroup: rewire boundary edges back to direct connections,
            % remove children from group, and delete the group.
            groupId = string(data.groupId);
            group = this.findNodeById(groupId);
            assert(isa(group, 'ic.node.Group'), ...
                "ic:NodeEditor:NotAGroup", ...
                "Node '%s' is not a Group.", groupId);

            % 1. Classify edges touching the group by boundary port
            %    Exterior edges: external ↔ group (port without :int)
            %    Interior edges: group ↔ child  (port with :int)
            edges = this.Edges;
            extEdges = struct('port', {}, 'edge', {}, 'otherNode', {}, 'otherPort', {}, 'dir', {});
            intEdges = struct('port', {}, 'edge', {}, 'otherNode', {}, 'otherPort', {}, 'dir', {});
            for ii = 1:numel(edges)
                e = edges(ii);
                if e.SourceNodeID == groupId
                    pn = e.SourcePortName;
                    if endsWith(pn, ":int")
                        % Interior outgoing: group:bp:int → child (input bp)
                        intEdges(end+1) = struct('port', extractBefore(pn, strlength(pn)-3), ...
                            'edge', e, 'otherNode', e.TargetNode, ...
                            'otherPort', e.TargetPortName, 'dir', "in"); %#ok<AGROW>
                    else
                        % Exterior outgoing: group:bp → external (output bp)
                        extEdges(end+1) = struct('port', pn, ...
                            'edge', e, 'otherNode', e.TargetNode, ...
                            'otherPort', e.TargetPortName, 'dir', "out"); %#ok<AGROW>
                    end
                elseif e.TargetNodeID == groupId
                    pn = e.TargetPortName;
                    if endsWith(pn, ":int")
                        % Interior incoming: child → group:bp:int (output bp)
                        intEdges(end+1) = struct('port', extractBefore(pn, strlength(pn)-3), ...
                            'edge', e, 'otherNode', e.SourceNode, ...
                            'otherPort', e.SourcePortName, 'dir', "out"); %#ok<AGROW>
                    else
                        % Exterior incoming: external → group:bp (input bp)
                        extEdges(end+1) = struct('port', pn, ...
                            'edge', e, 'otherNode', e.SourceNode, ...
                            'otherPort', e.SourcePortName, 'dir', "in"); %#ok<AGROW>
                    end
                end
            end

            % 2. Pair exterior↔interior edges by boundary port name
            %    and collect direct edges to create after cleanup
            rewires = {};
            for ii = 1:numel(extEdges)
                ext = extEdges(ii);
                for jj = 1:numel(intEdges)
                    int = intEdges(jj);
                    if int.port == ext.port
                        % Determine edge type from the exterior edge
                        edgeCls = class(ext.edge);
                        if ext.dir == "in"
                            % Inbound: external → child
                            rewires{end+1} = struct( ...
                                'srcNode', ext.otherNode, 'srcPort', ext.otherPort, ...
                                'tgtNode', int.otherNode, 'tgtPort', int.otherPort, ...
                                'edgeCls', edgeCls); %#ok<AGROW>
                        else
                            % Outbound: child → external
                            rewires{end+1} = struct( ...
                                'srcNode', int.otherNode, 'srcPort', int.otherPort, ...
                                'tgtNode', ext.otherNode, 'tgtPort', ext.otherPort, ...
                                'edgeCls', edgeCls); %#ok<AGROW>
                        end
                    end
                end
            end

            % 3. Delete all boundary edges
            allBoundaryEdges = [extEdges.edge, intEdges.edge];
            for ii = 1:numel(allBoundaryEdges)
                this.removeEdge(allBoundaryEdges(ii));
            end

            % 4. Remove children from the group (converts positions to absolute)
            children = group.GroupChildren;
            for ii = 1:numel(children)
                group.removeGroupChild(children(ii));
            end

            % 5. Create direct edges to replace the boundary tunnels
            for ii = 1:numel(rewires)
                r = rewires{ii};
                newEdge = feval(r.edgeCls);
                newEdge.setEndpoints(r.srcNode, r.srcPort, r.tgtNode, r.tgtPort);
                this.addChild(newEdge, "edges");
            end

            % 6. Delete the group node
            this.removeNode(group);

            result = true;
        end

        function result = handleGroupSelection(this, data)
            % Frontend sends node IDs → delegates to public groupNodes().
            nodeIds = string(data.nodeIds);
            nodes = ic.node.Node.empty;
            for ii = 1:numel(nodeIds)
                n = this.findNodeById(nodeIds(ii));
                if ~isa(n, 'ic.node.Group')
                    nodes(end+1) = n; %#ok<AGROW>
                end
            end
            if numel(nodes) < 2
                result = false;
                return
            end
            group = this.groupNodes(nodes);
            result = struct('groupId', group.ID);
        end

        function result = handleUpdateNodeProp(this, data)
            % > HANDLEUPDATENODEPROP Set a reactive property on a node.
            %   data.nodeId: node ID string
            %   data.prop:   camelCase property name
            %   data.value:  new value
            node = this.findNodeById(data.nodeId);
            prop = string(data.prop);
            % camelCase → PascalCase (capitalize first letter)
            propPascal = upper(extractBefore(prop, 2)) + extractAfter(prop, 1);
            node.(propPascal) = data.value;
            result = true;
        end

        function result = handleUpdateEdgeProp(this, data)
            % > HANDLEUPDATEEDGEPROP Set a reactive property on an edge.
            %   data.edgeId: edge ID string
            %   data.prop:   camelCase property name
            %   data.value:  new value
            edges = this.Edges;
            edge = [];
            for ii = 1:numel(edges)
                if edges(ii).ID == string(data.edgeId)
                    edge = edges(ii);
                    break
                end
            end
            if isempty(edge)
                error("ic:NodeEditor:EdgeNotFound", ...
                    "Edge with ID '%s' not found.", data.edgeId);
            end
            prop = string(data.prop);
            propPascal = upper(extractBefore(prop, 2)) + extractAfter(prop, 1);
            edge.(propPascal) = data.value;
            result = true;
        end

        function result = handleDuplicateNodes(this, data)
            % Frontend sends node IDs; MATLAB clones from actual objects.
            %   data.nodeIds: string array of node IDs to duplicate
            %   data.offset:  [dx, dy] position offset
            nodeIds = string(data.nodeIds);
            offset  = reshape(double(data.offset), 1, []);

            % Expand: include children of any selected groups
            expandedIds = nodeIds;
            for ii = 1:numel(nodeIds)
                try
                    orig = this.findNodeById(nodeIds(ii));
                catch
                    continue
                end
                if isa(orig, 'ic.node.Group')
                    children = orig.GroupChildren;
                    for jj = 1:numel(children)
                        cid = children(jj).ID;
                        if ~ismember(cid, expandedIds)
                            expandedIds(end+1) = cid; %#ok<AGROW>
                        end
                    end
                end
            end
            nodeIds = expandedIds;

            oldToNew = containers.Map('KeyType', 'char', 'ValueType', 'any');
            newNodeIds = {};

            % Clone each node (groups first, then children, order from nodeIds)
            for ii = 1:numel(nodeIds)
                try
                    orig = this.findNodeById(nodeIds(ii));
                catch
                    continue
                end

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
                    % Only apply offset to top-level nodes (not children)
                    if mp.Name == "Position" && isempty(orig.ParentNode)
                        val = val + offset;
                    end
                    newNode.(mp.Name) = val;
                end

                % Clone port configuration (reactive props on each port)
                ic.NodeEditor.clonePorts(orig.Outputs, newNode.Outputs);
                ic.NodeEditor.clonePorts(orig.Inputs,  newNode.Inputs);

                % Groups may have dynamically-added boundary ports that
                % the constructor doesn't create — replicate them.
                if isa(orig, 'ic.node.Group')
                    ic.NodeEditor.cloneDynamicPorts( ...
                        orig.Inputs,  newNode.Inputs,  newNode, "inputs");
                    ic.NodeEditor.cloneDynamicPorts( ...
                        orig.Outputs, newNode.Outputs, newNode, "outputs");
                end

                this.addNode(newNode);
                oldToNew(char(nodeIds(ii))) = newNode;
                newNodeIds{end+1} = newNode.ID; %#ok<AGROW>
            end

            % Re-establish parent-child relationships in cloned set.
            % Children already have relative positions from the original.
            % setParentNode converts absolute→relative by subtracting
            % the group position, so we pre-add it to cancel out.
            for ii = 1:numel(nodeIds)
                origKey = char(nodeIds(ii));
                if ~oldToNew.isKey(origKey), continue; end
                try
                    orig = this.findNodeById(nodeIds(ii));
                catch
                    continue
                end
                if ~isempty(orig.ParentNode) && ...
                        oldToNew.isKey(char(orig.ParentNode.ID))
                    newChild = oldToNew(origKey);
                    newGroup = oldToNew(char(orig.ParentNode.ID));
                    % Position is relative — add group pos so setParentNode
                    % subtracts it back, yielding the original relative pos.
                    newChild.Position = newChild.Position + newGroup.Position;
                    newChild.setParentNode(newGroup);
                end
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
                        isBoundary = contains(e.SourcePortName, ":int") ...
                            || contains(e.TargetPortName, ":int");
                        if isBoundary
                            % Boundary edges use :int port names that
                            % connect() can't resolve — use setEndpoints.
                            newEdge = feval(class(e));
                            newEdge.setEndpoints(newSrc, e.SourcePortName, ...
                                newTgt, e.TargetPortName);
                            this.addChild(newEdge, "edges");
                        else
                            newSrc.connect(newTgt, e.SourcePortName, e.TargetPortName);
                        end
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
        function name = uniquePortName(group, baseName, side)
            % Generate a port name that doesn't collide with existing ports.
            name = baseName;
            if side == "inputs"
                existing = group.Inputs;
            else
                existing = group.Outputs;
            end
            if isempty(existing)
                return
            end
            existingNames = arrayfun(@(p) p.Name, existing);
            suffix = 2;
            while ismember(name, existingNames)
                name = baseName + "_" + suffix;
                suffix = suffix + 1;
            end
        end

        function cls = edgeClassForType(~)
            % Return the edge class name. With unified Edge, always ic.node.Edge.
            % Kept for backward compatibility.
            cls = "ic.node.Edge";
        end

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

        function copyPortBehavior(srcPort, dstPort)
            % Copy signal/flow behavior props from source to destination port.
            % Called when creating group boundary ports so they inherit the
            % connected node's port behavior (speed, expression, etc.).
            if srcPort.Type == "flow" || srcPort.Type == "signal"
                dstPort.Speed = srcPort.Speed;
            end
            if srcPort.Type == "flow"
                dstPort.OutputRate = srcPort.OutputRate;
            end
            if srcPort.Type == "signal"
                dstPort.Expression = srcPort.Expression;
                dstPort.Frequency = srcPort.Frequency;
            end
        end

        function cloneDynamicPorts(origPorts, existingPorts, newNode, side)
            % Clone ports that exist on the original but not on the new node.
            % Groups have dynamic boundary ports added via addPort() that
            % the constructor doesn't create.
            nExisting = numel(existingPorts);
            for jj = (nExisting + 1):numel(origPorts)
                op = origPorts(jj);
                np = ic.node.Port(op.Name, Label=op.Label, Type=op.Type);
                newNode.addPort(np, side);
            end
        end
    end
end

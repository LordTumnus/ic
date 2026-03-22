classdef (Abstract) Group < ic.node.Node
    % > GROUP Abstract base for subflow containers.
    %   All child nodes stay in NodeEditor's flat "nodes" target.
    %   The parent-child relationship is expressed via ParentNode on
    %   the child, which maps to SvelteFlow's parentId.
    %
    %   Concrete subclasses: CollapsibleGroup, BasicGroup
    %
    %   % Connect through boundary ports:
    %   g.addPort("in", "input");
    %   g.connect(childNode, "in");           % group input → child
    %   childNode.connect(g, "data", "out");  % child → group output (auto)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL header text
        Label (1,1) string = "Group"

        % > WIDTH container width in pixels
        Width (1,1) double = 400

        % > HEIGHT container height in pixels
        Height (1,1) double = 300

        % > BACKGROUNDCOLOR body fill color (CSS value, empty = transparent)
        BackgroundColor (1,1) string = ""

        % > BACKGROUNDOPACITY body fill opacity (0–1)
        BackgroundOpacity (1,1) double {mustBeInRange(BackgroundOpacity,0,1)} = 0
    end

    properties (Dependent, SetAccess = private)
        % > GROUPCHILDREN nodes inside this group (read-only)
        GroupChildren
    end

    methods
        function nodes = get.GroupChildren(this)
            if isempty(this.Parent)
                nodes = ic.node.Node.empty;
                return
            end
            all = this.Parent.Nodes;
            mask = arrayfun(@(n) ...
                ~isempty(n.ParentNode) && isvalid(n.ParentNode) ...
                && n.ParentNode == this, all);
            nodes = all(find(mask)); %#ok<FNDSB>
        end

        function addGroupChild(this, node)
            % > ADDGROUPCHILD Parent a node into this group.
            %   Both group and node must already be added to the same editor.
            %   Position is automatically converted from absolute to relative.
            arguments
                this (1,1) ic.node.Group
                node (1,1) ic.node.Node
            end
            assert(~isempty(this.Parent) && ~isempty(node.Parent), ...
                "ic:Group:NotAttached", ...
                "Both group and node must be added to a NodeEditor.");
            assert(this.Parent == node.Parent, ...
                "ic:Group:DifferentEditors", ...
                "Group and node must belong to the same NodeEditor.");
            node.setParentNode(this);
        end

        function edge = connect(this, targetNode, sourcePort, targetPort, props)
            % > CONNECT Connect through a boundary port or between nodes.
            %   Automatically detects whether targetNode is inside or
            %   outside the group and uses the correct handle side.
            %
            %   External (standard):
            %     group.connect(externalNode, "out", "data")
            %       → group:out → externalNode:data
            %
            %   Internal (child is target):
            %     group.connect(childNode, "in")
            %       → group:in:int → childNode:firstInput
            %
            %   Internal (child is source — call from child side):
            %     childNode.connect(group, "data", "out")
            %       → childNode:data → group:out:int  (auto-detected by Node.connect)
            arguments
                this (1,1) ic.node.Group
                targetNode (1,1) ic.node.Node
                sourcePort (1,1) string = ""
                targetPort (1,1) string = ""
                props.Edge ic.node.Edge
            end

            % Detect if target is a child of this group
            isChild = ~isempty(targetNode.ParentNode) ...
                && isvalid(targetNode.ParentNode) ...
                && targetNode.ParentNode == this;

            if ~isChild
                % External connection — delegate to base class
                args = namedargs2cell(props);
                edge = connect@ic.node.Node(this, targetNode, ...
                    sourcePort, targetPort, args{:});
                return
            end

            % Internal connection — route through boundary port
            assert(~isempty(this.Parent), ...
                "ic:Group:NotAttached", ...
                "Group must be added to a NodeEditor.");

            % sourcePort here is the boundary port name on the group
            if sourcePort == ""
                % Try inputs first (more common: group input → child)
                if ~isempty(this.Inputs)
                    sourcePort = this.Inputs(1).Name;
                elseif ~isempty(this.Outputs)
                    sourcePort = this.Outputs(1).Name;
                else
                    error("ic:node:NoPorts", ...
                        "Group has no boundary ports.");
                end
            end

            % Determine direction from port side
            isInput = ~isempty(this.findPort(sourcePort, "inputs"));
            intHandle = sourcePort + ":int";

            if isInput
                % Group input interior is a source → child's input
                if targetPort == ""
                    inputs = targetNode.Inputs;
                    assert(~isempty(inputs), "ic:node:NoPorts", ...
                        "Target node has no input ports.");
                    targetPort = inputs(1).Name;
                end
                srcPortHandle = this.findPort(sourcePort, "inputs");
            else
                % Group output interior is a target → child is source
                if targetPort == ""
                    outputs = targetNode.Outputs;
                    assert(~isempty(outputs), "ic:node:NoPorts", ...
                        "Target node has no output ports.");
                    targetPort = outputs(1).Name;
                end
                srcPortHandle = this.findPort(sourcePort, "outputs");
            end

            % Create unified edge with type from source port
            edge = ic.node.Edge(Type=srcPortHandle.Type);

            % Forward display props
            if isfield(props, 'Edge')
                edge.copyDisplayProps(props.Edge);
            end

            % Wire endpoints based on direction
            if isInput
                edge.setEndpoints(this, intHandle, targetNode, targetPort);
            else
                edge.setEndpoints(targetNode, targetPort, this, intHandle);
            end
            this.Parent.addChild(edge, "edges");
        end

        function removeGroupChild(this, node)
            % > REMOVEGROUPCHILD Un-parent a node from this group.
            %   Node stays in the editor; position converted to absolute.
            arguments
                this (1,1) ic.node.Group %#ok<INUSA>
                node (1,1) ic.node.Node
            end
            node.setParentNode();
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(~)
            % Groups have no default ports. Users add boundary ports
            % via addPort() when they need edge tunneling.
        end
    end
end

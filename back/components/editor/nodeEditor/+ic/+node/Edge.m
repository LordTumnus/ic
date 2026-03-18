classdef (Abstract) Edge < ic.core.Component
    % > EDGE Connection between two node ports.
    %   Abstract base — subclass for specific edge visuals (StaticEdge, etc.).
    %   Stores handle references to source/target nodes AND ports.
    %
    %   Traversal:
    %     edge.SourceNode / edge.TargetNode   → Node handles
    %     edge.SourcePort / edge.TargetPort   → Port handles
    %
    %   Edges are created via node.connect() — not directly by the user.

    properties (SetAccess = private)
        % > SOURCENODE handle reference to source node
        SourceNode ic.node.Node

        % > TARGETNODE handle reference to target node
        TargetNode ic.node.Node

        % > SOURCEPORT handle reference to source port
        SourcePort ic.node.Port

        % > TARGETPORT handle reference to target port
        TargetPort ic.node.Port
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.node.Edge, ?ic.mixin.Reactive}, ...
            Hidden, Description = "Reactive")
        % > SOURCENODEID source node ID (for Svelte serialization)
        SourceNodeID (1,1) string = ""

        % > TARGETNODEID target node ID (for Svelte serialization)
        TargetNodeID (1,1) string = ""

        % > SOURCEPORTNAME source port name (for Svelte serialization)
        SourcePortName (1,1) string = ""

        % > TARGETPORTNAME target port name (for Svelte serialization)
        TargetPortName (1,1) string = ""
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL edge label text
        Label (1,1) string = ""

        % > GEOMETRY per-edge override: bezier | straight | smoothstep | step
        %   Empty string means use the editor's default EdgeGeometry.
        Geometry (1,1) string {mustBeMember(Geometry, ...
            ["", "bezier", "straight", "smoothstep", "step"])} = ""

        % > COLOR edge stroke color (empty = theme default)
        Color (1,1) string = ""

        % > THICKNESS edge stroke width in pixels
        Thickness (1,1) double {mustBePositive} = 1

        % > STARTARROW arrowhead at source end: none | arrow | diamond | circle
        StartArrow (1,1) string {mustBeMember(StartArrow, ...
            ["none", "arrow", "diamond", "circle"])} = "none"

        % > ENDARROW arrowhead at target end: none | arrow | diamond | circle
        EndArrow (1,1) string {mustBeMember(EndArrow, ...
            ["none", "arrow", "diamond", "circle"])} = "none"
    end

    properties (Access = private)
        EndpointsSet (1,1) logical = false
    end

    methods
        function this = Edge(props)
            % > EDGE Construct an edge (called by subclass constructors).
            %   No arguments block — abstract classes can't use props.?ClassName.
            this@ic.core.Component(props);
        end

        function setEndpoints(this, srcNode, srcPortName, tgtNode, tgtPortName)
            % > SETENDPOINTS One-shot setter for edge endpoints.
            %   Called by Node.connect() after edge construction.
            %   Looks up Port handles and registers this edge on both ports.
            arguments
                this (1,1) ic.node.Edge
                srcNode (1,1) ic.node.Node
                srcPortName (1,1) string
                tgtNode (1,1) ic.node.Node
                tgtPortName (1,1) string
            end
            assert(~this.EndpointsSet, ...
                "ic:Edge:EndpointsAlreadySet", ...
                "Edge endpoints can only be set once.");

            % Store node handles + serialization strings
            this.SourceNode = srcNode;
            this.TargetNode = tgtNode;
            this.SourceNodeID = srcNode.ID;
            this.TargetNodeID = tgtNode.ID;
            this.SourcePortName = srcPortName;
            this.TargetPortName = tgtPortName;

            % Look up and store port handles
            % :int suffix = group interior handle — direction is reversed
            % (an input port's interior acts as source, output's as target)
            srcIsInt = endsWith(srcPortName, ":int");
            tgtIsInt = endsWith(tgtPortName, ":int");
            srcLookup = regexprep(srcPortName, ':int$', '');
            tgtLookup = regexprep(tgtPortName, ':int$', '');
            srcSide = "outputs"; if srcIsInt, srcSide = "inputs"; end
            tgtSide = "inputs";  if tgtIsInt, tgtSide = "outputs"; end
            this.SourcePort = srcNode.findPort(srcLookup, srcSide);
            this.TargetPort = tgtNode.findPort(tgtLookup, tgtSide);

            % Register edge on both ports
            this.SourcePort.addEdge(this);
            this.TargetPort.addEdge(this);

            this.EndpointsSet = true;
        end

        function delete(this)
            % > DELETE Destructor — unregister from connected ports.
            if ~isempty(this.SourcePort) && isvalid(this.SourcePort)
                this.SourcePort.removeEdge(this);
            end
            if ~isempty(this.TargetPort) && isvalid(this.TargetPort)
                this.TargetPort.removeEdge(this);
            end
        end
    end

    methods (Abstract)
        % > COPYDISPLAYPROPS Copy display-only props from another edge of the same class.
        %   Used by Node.connect() to forward Edge= display props.
        copyDisplayProps(this, source)
    end
end

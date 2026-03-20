classdef Edge < ic.core.Component
    % > EDGE Connection between two node ports.
    %   Unified edge class with a Type property that controls rendering:
    %   "static" (simple line), "flow" (animated particles), "signal" (waveform).
    %
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
        % > TYPE rendering mode: static | flow | signal
        Type (1,1) string {mustBeMember(Type, ...
            ["static", "flow", "signal"])} = "static"

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

        % ── Shared animation ──

        % > ANIMATED enable animation (dash on static, waveform on signal)
        Animated (1,1) logical = false

        % ── Flow edge properties ──

        % > PARTICLESIZE circle radius in pixels (flow type)
        ParticleSize (1,1) double {mustBePositive} = 3

        % > PARTICLECOLOR CSS color for particles (empty = --ic-primary)
        ParticleColor (1,1) string = ""

        % ── Signal edge properties ──

        % > AMPLITUDE perpendicular displacement in pixels (signal type)
        Amplitude (1,1) double {mustBePositive} = 8

        % > SIGNALCOLOR waveform stroke color (empty = --ic-primary)
        SignalColor (1,1) string = ""

        % > SIGNALTHICKNESS waveform line width in pixels (signal type)
        SignalThickness (1,1) double {mustBePositive} = 2
    end

    properties (Access = private)
        EndpointsSet (1,1) logical = false
    end

    methods
        function this = Edge(props)
            % > EDGE Construct an edge.
            %   e = ic.node.Edge()
            %   e = ic.node.Edge(Type="flow", ParticleSize=4)
            arguments
                props.?ic.node.Edge
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
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

        function copyDisplayProps(this, source)
            % > COPYDISPLAYPROPS Copy display-only props from another edge.
            %   Used by Node.connect() to forward Edge= display props.
            arguments
                this (1,1) ic.node.Edge
                source (1,1) ic.node.Edge
            end
            this.Type = source.Type;
            this.Label = source.Label;
            this.Geometry = source.Geometry;
            this.Color = source.Color;
            this.Thickness = source.Thickness;
            this.StartArrow = source.StartArrow;
            this.EndArrow = source.EndArrow;
            this.Animated = source.Animated;
            this.ParticleSize = source.ParticleSize;
            this.ParticleColor = source.ParticleColor;
            this.Amplitude = source.Amplitude;
            this.SignalColor = source.SignalColor;
            this.SignalThickness = source.SignalThickness;
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
end

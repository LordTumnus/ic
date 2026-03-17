classdef Port < ic.core.Component
    % > PORT Connection point on a node.
    %   Port is a Component child of a Node (ComponentContainer).
    %   Ports live in the node's "inputs" or "outputs" target slot.
    %   Each port tracks its connected edges for graph traversal.
    %
    %   p = ic.node.Port("data")
    %   p = ic.node.Port("out", Type="flow", OutputRate=5, Speed=2)
    %   p = ic.node.Port("out", Type="signal", Expression="sin(2*pi*t)")
    %
    %   % Traversal: port → edges → other port
    %   p.Edges              % all edges connected to this port
    %   p.Edges(1).TargetPort  % the port on the other end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > NAME unique identifier within the node (e.g. "in", "out")
        Name (1,1) string = ""

        % > LABEL display text (empty → falls back to Name)
        Label (1,1) string = ""

        % > COLOR dot color (CSS value; empty → default)
        Color (1,1) string = ""

        % > MAXCONNECTIONS maximum simultaneous connections (Inf = unlimited)
        MaxConnections (1,1) double = Inf

        % > TYPE edge type created from this port: static | flow | signal
        %   Only meaningful on output ports. Input port type is ignored.
        Type (1,1) string {mustBeMember(Type, ...
            ["static","flow","signal"])} = "static"

        % > OUTPUTRATE particles per outgoing FlowEdge (flow behavior)
        OutputRate (1,1) double {mustBePositive} = 3

        % > SPEED animation speed multiplier (flow/signal behavior)
        Speed (1,1) double {mustBeNonnegative} = 1

        % > EXPRESSION waveform math expression f(t) for signal edges
        Expression (1,1) string = "sin(2*pi*t)"

        % > FREQUENCY number of waveform cycles visible (signal behavior)
        Frequency (1,1) double {mustBePositive} = 2
    end

    properties (SetAccess = {?ic.node.Edge})
        % > EDGES edges connected to this port (managed by Edge)
        Edges ic.node.Edge
    end

    properties (Dependent, SetAccess = private)
        % > CONNECTEDPORTS ports at the other end of each edge
        ConnectedPorts

        % > CONNECTEDNODES nodes at the other end of each edge
        ConnectedNodes

        % > ISCONNECTED true if any edges are connected
        IsConnected
    end

    methods
        function ports = get.ConnectedPorts(this)
            % > GET.CONNECTEDPORTS Ports at the opposite end of each edge.
            edges = this.Edges;
            if isempty(edges)
                ports = ic.node.Port.empty(1, 0);
                return
            end
            ports = arrayfun(@(e) this.otherPort(e), edges);
        end

        function nodes = get.ConnectedNodes(this)
            % > GET.CONNECTEDNODES Nodes at the opposite end of each edge.
            edges = this.Edges;
            if isempty(edges)
                nodes = ic.node.Node.empty;
                return
            end
            nodes = arrayfun(@(e) this.otherNode(e), edges);
        end

        function tf = get.IsConnected(this)
            % > GET.ISCONNECTED True if any edges are connected.
            tf = ~isempty(this.Edges);
        end

        function this = Port(name, props)
            % > PORT Construct a port with a required name.
            arguments
                name (1,1) string
                props.?ic.node.Port
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            props.Name = name;
            this@ic.core.Component(props);
            this.Edges = ic.node.Edge.empty(1, 0);
        end

        function addEdge(this, edge)
            % > ADDEDGE Register an edge on this port (called by Edge.setEndpoints).
            arguments
                this (1,1) ic.node.Port
                edge (1,1) ic.node.Edge
            end
            this.Edges(end+1) = edge;
        end

        function removeEdge(this, edge)
            % > REMOVEEDGE Unregister an edge from this port (called by Edge destructor).
            arguments
                this (1,1) ic.node.Port
                edge (1,1) ic.node.Edge
            end
            % Cannot use ~= on heterogeneous Edge arrays (ne is not sealed).
            % Compare by ID string instead.
            edgeId = edge.ID;
            keep = arrayfun(@(e) e.ID ~= edgeId, this.Edges);
            this.Edges = this.Edges(find(keep));
        end

        function delete(this)
            % > DELETE Destructor — cascade-delete connected edges.
            edges = this.Edges;
            for ii = numel(edges):-1:1
                if isvalid(edges(ii))
                    delete(edges(ii));
                end
            end
        end
    end

    methods (Access = private)
        function p = otherPort(this, edge)
            % > OTHERPORT Return the port on the opposite end of an edge.
            if edge.SourcePort == this
                p = edge.TargetPort;
            else
                p = edge.SourcePort;
            end
        end

        function n = otherNode(this, edge)
            % > OTHERNODE Return the node on the opposite end of an edge.
            if edge.SourcePort == this
                n = edge.TargetNode;
            else
                n = edge.SourceNode;
            end
        end
    end
end

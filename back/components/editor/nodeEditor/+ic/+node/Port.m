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

    methods
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
end

classdef Port < ic.core.Component
    % > PORT Connection point on a node.
    %   Port is a Component child of a Node (ComponentContainer).
    %   Ports live in the node's "inputs" or "outputs" target slot.
    %   Each port tracks its connected edges for graph traversal.
    %
    %   p = ic.node.Port("data")
    %   p = ic.node.Port("signal", Label="Audio", Color="#3b82f6")
    %   p = ic.node.Port("in", MaxConnections=1)
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
            mask = this.Edges ~= edge;
            this.Edges = this.Edges(mask);
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

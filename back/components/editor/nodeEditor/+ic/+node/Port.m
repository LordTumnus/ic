classdef Port
    % > PORT Connection point on a node.
    %   Immutable value class — defined at node creation, never changes.
    %
    %   p = ic.node.Port("in")
    %   p = ic.node.Port("out", Label="Signal", Color="#3b82f6")
    %   p = ic.node.Port("data", MaxConnections=1)

    properties (SetAccess = immutable)
        % > NAME unique identifier within the node (e.g. "in", "out")
        Name (1,1) string

        % > LABEL display text (empty → falls back to Name)
        Label (1,1) string = ""

        % > COLOR dot color (CSS value, e.g. "#3b82f6"; empty → default gray)
        Color (1,1) string = ""

        % > MAXCONNECTIONS maximum simultaneous connections (Inf = unlimited)
        MaxConnections (1,1) double = Inf
    end

    methods
        function this = Port(name, props)
            % > PORT Construct a port with a required name.
            arguments
                name (1,1) string
                props.Label (1,1) string = ""
                props.Color (1,1) string = ""
                props.MaxConnections (1,1) double = Inf
            end
            this.Name = name;
            this.Label = props.Label;
            this.Color = props.Color;
            this.MaxConnections = props.MaxConnections;
        end

        function json = jsonencode(this, varargin)
            % > JSONENCODE Encode port array as JSON.
            if isempty(this)
                json = "[]";
                return
            end
            arr = arrayfun(@(p) struct( ...
                'name', p.Name, ...
                'label', p.Label, ...
                'color', p.Color, ...
                'maxConnections', p.MaxConnections), this);
            json = jsonencode(arr, varargin{:});
        end
    end
end

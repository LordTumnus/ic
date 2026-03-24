classdef FlowchartConfig < ic.event.TransportData
    % configuration for Mermaid flowchart diagrams.
    % Pass an instance to #ic.Mermaid.Config to customize layout and appearance.

    properties
        % horizontal gap between nodes on the same level, in pixels
        NodeSpacing (1,1) double {mustBeNonnegative} = 50

        % vertical gap between nodes on different levels, in pixels
        RankSpacing (1,1) double {mustBeNonnegative} = 50

        % edge drawing style
        Curve string {mustBeMember(Curve, ["basis","linear","rounded","monotoneX"])} = "rounded"

        % space between label text and node border, in pixels
        Padding (1,1) double {mustBeNonnegative} = 15

        % padding around the entire diagram, in pixels
        DiagramPadding (1,1) double {mustBeNonnegative} = 20

        % maximum text width before wrapping inside nodes, in pixels
        WrappingWidth (1,1) double {mustBePositive} = 200
    end

    methods
        function this = FlowchartConfig(props)
            arguments
                props.?ic.mermaid.FlowchartConfig
            end
            fns = fieldnames(props);
            for i = 1:numel(fns)
                this.(fns{i}) = props.(fns{i});
            end
        end

        function s = toStruct(this)
            inner = struct();
            plist = properties(this);
            for i = 1:numel(plist)
                name = plist{i};
                inner.([lower(name(1)), name(2:end)]) = this.(name);
            end
            s = struct('flowchart', inner);
        end

        function json = jsonencode(this, varargin)
            json = jsonencode(this.toStruct(), varargin{:});
        end
    end
end

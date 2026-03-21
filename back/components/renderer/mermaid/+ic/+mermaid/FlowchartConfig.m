classdef FlowchartConfig < ic.event.TransportData
    % > FLOWCHARTCONFIG Mermaid flowchart diagram configuration.
    %
    %   m.Config = ic.mermaid.FlowchartConfig(NodeSpacing=100, Curve="linear")

    properties
        % > NODESPACING horizontal gap between nodes on the same level
        NodeSpacing (1,1) double {mustBeNonnegative} = 50

        % > RANKSPACING vertical gap between nodes on different levels
        RankSpacing (1,1) double {mustBeNonnegative} = 50

        % > CURVE edge drawing style
        Curve string {mustBeMember(Curve, ["basis","linear","rounded","monotoneX"])} = "rounded"

        % > PADDING space between label text and node border
        Padding (1,1) double {mustBeNonnegative} = 15

        % > DIAGRAMPADDING padding around the entire diagram
        DiagramPadding (1,1) double {mustBeNonnegative} = 20

        % > WRAPPINGWIDTH max text width before wrapping inside nodes
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

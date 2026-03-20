classdef IconBox < ic.node.Node
    % > ICONBOX Box with a Lucide icon and label — one input and one output.
    %
    %   n = ic.node.IconBox(Label="Settings", Icon="settings")
    %   n = ic.node.IconBox(Icon="database", Position=[200 200])

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display text (shown below the icon)
        Label (1,1) string = ""

        % > ICON Lucide icon name, file path, or URL (auto-detected via ic.Asset)
        Icon (1,1) ic.asset.Asset = ""

        % > BACKGROUNDCOLOR node fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR node stroke color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = IconBox(props)
            % > ICONBOX Construct an icon box node.
            arguments
                props.?ic.node.IconBox
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("in"), "inputs");
            this.addPort(ic.node.Port("out"), "outputs");
        end
    end
end

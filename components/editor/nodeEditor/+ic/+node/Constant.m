classdef Constant < ic.node.Node
    % > CONSTANT Inline numeric value node — compact pill with one signal output.
    %   The constant value is emitted as a flat signal (expression = the number).
    %
    %   n = ic.node.Constant(Value=42)
    %   n = ic.node.Constant(Value=3.14, BackgroundColor="#fef3c7")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE the numeric value displayed in the pill and emitted as signal
        Value (1,1) double = 0

        % > BACKGROUNDCOLOR pill fill color (empty = theme default)
        BackgroundColor (1,1) string = ""

        % > OUTLINECOLOR pill border color (empty = theme default)
        OutlineColor (1,1) string = ""
    end

    methods
        function this = Constant(props)
            % > CONSTANT Construct an inline value node.
            arguments
                props.?ic.node.Constant
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.Value(this, val)
            this.Value = val;
            this.syncSignalPort();
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("value"), "outputs");
            this.outputSignal("value", Expression=string(this.Value));
        end
    end

    methods (Access = private)
        function syncSignalPort(this)
            % > SYNCSIGNALPORT Propagate Value to the output port expression.
            try
                port = this.findPort("value", "outputs");
            catch
                return  % Port not yet created (during construction)
            end
            port.Expression = string(this.Value);
        end
    end
end

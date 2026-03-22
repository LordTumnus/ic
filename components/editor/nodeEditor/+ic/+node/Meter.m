classdef Meter < ic.node.Node
    % > METER Analog gauge dial sink node.
    %   Receives a signal from a connected edge and displays it as
    %   a needle on an analog gauge. The needle position maps the
    %   signal value to the Min–Max range.
    %
    %   m = ic.node.Meter(Position=[400 300])
    %   m = ic.node.Meter(Label="Voltage", Min=-1, Max=1, Unit="V")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the node
        Label (1,1) string = ""

        % > MIN minimum value on the gauge scale
        Min (1,1) double = 0

        % > MAX maximum value on the gauge scale
        Max (1,1) double = 100

        % > UNIT unit label displayed next to the value (e.g. "V", "dB")
        Unit (1,1) string = ""
    end

    methods
        function this = Meter(props)
            % > METER Construct a meter sink node.
            arguments
                props.?ic.node.Meter
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("signal", MaxConnections=1), "inputs");
        end
    end
end

classdef Clock < ic.node.Node
    % > CLOCK Circular clock face source node with animated hand.
    %   Emits ticks on a flow-type output port. The flow animation speed
    %   is linked to the Interval property so particles visually match
    %   the clock's tick rate.
    %
    %   clk = ic.node.Clock(Label="Timer", Interval=0.5, Animated=true)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the clock face
        Label (1,1) string = ""

        % > INTERVAL tick period (interpreted according to Unit)
        Interval (1,1) double {mustBePositive} = 1

        % > UNIT time unit for Interval: "s" (seconds), "ms", or "Hz"
        Unit (1,1) string {mustBeMember(Unit, ["s","ms","Hz"])} = "s"

        % > ANIMATED whether the clock hand rotates
        Animated (1,1) logical = true
    end

    methods
        function this = Clock(props)
            % > CLOCK Construct a clock source node.
            arguments
                props.?ic.node.Clock
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.Interval(this, val)
            this.Interval = val;
            this.syncFlowSpeed();
        end

        function set.Unit(this, val)
            this.Unit = val;
            this.syncFlowSpeed();
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("tick"), "outputs");
            this.outputFlow("tick", OutputRate=1, Speed=2/this.Interval);
        end
    end

    methods (Access = private)
        function syncFlowSpeed(this)
            % > SYNCFLOWSPEED Update tick port speed to match current Interval+Unit.
            %   Speed = 2/durationSec so particle traversal = hand revolution.
            try
                port = this.findPort("tick", "outputs");
            catch
                return  % Port not yet created (during construction)
            end
            iv = this.Interval;
            switch this.Unit
                case "ms", dur = iv / 1000;
                case "Hz", dur = max(iv, eps); dur = 1 / dur;
                otherwise, dur = iv;
            end
            port.Speed = 2 / dur;
        end
    end
end

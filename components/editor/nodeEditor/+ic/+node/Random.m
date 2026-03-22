classdef Random < ic.node.Node
    % > RANDOM 3D dice source node — outputs a ZOH noise signal.
    %   The edge renders as a zero-order-hold random waveform in [-1, 1].
    %   Uses a deterministic trig hash to simulate randomness via expr-eval.
    %
    %   rnd = ic.node.Random(Label="Noise")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the dice
        Label (1,1) string = ""

        % > PROFILE noise profile: "white", "binary", "sparse", or "smooth"
        Profile (1,1) string {mustBeMember(Profile, ["white","binary","sparse","smooth"])} = "white"
    end

    methods
        function this = Random(props)
            % > RANDOM Construct a random (dice) source node.
            arguments
                props.?ic.node.Random
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.Profile(this, val)
            this.Profile = val;
            try
                port = this.findPort("value", "outputs");
            catch
                return  % Port not yet created (during construction)
            end
            port.Expression = ic.node.Random.profileExpression(val);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("value"), "outputs");
            this.outputSignal("value", ...
                Expression=ic.node.Random.profileExpression(this.Profile), ...
                Frequency=6);
        end
    end

    methods (Static, Access = {?ic.node.Random, ?ic.core.Component})
        function expr = profileExpression(profile)
            % > PROFILEEXPRESSION Return the expr-eval expression for a noise profile.
            switch profile
                case "white"
                    % ZOH noise: floor() creates steps, trig hash → [-1,1]
                    expr = "sin(floor(t*8)*127.1)*cos(floor(t*8)*269.3)";
                case "binary"
                    % Binary noise: snaps to -1 or +1
                    expr = "sign(sin(floor(t*6)*127.1)*cos(floor(t*6)*269.3))";
                case "sparse"
                    % Sparse pulses: mostly zero with occasional spikes
                    expr = "((abs(sin(floor(t*4)*127.1)*cos(floor(t*4)*269.3))>0.7) * sign(sin(floor(t*4)*127.1))) * 1";
                case "smooth"
                    % Smooth random: sum of incommensurate sinusoids
                    expr = "sin(t*3.17)*0.5 + cos(t*7.31)*0.3 + sin(t*13.03)*0.2";
                otherwise
                    expr = "sin(floor(t*8)*127.1)*cos(floor(t*8)*269.3)";
            end
        end
    end
end

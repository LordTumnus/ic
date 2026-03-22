classdef Mux < ic.node.Node
    % > MUX Multiplexer node — combines N inputs into one output.
    %   Accepts any edge type on each input. Output is static.
    %   Rendered as a black tapered bar (Simulink style).
    %
    %   m = ic.node.Mux(InputNumber=4)
    %   m = ic.node.Mux(Label="Bus", InputNumber=3)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed beside the mux
        Label (1,1) string = ""

        % > INPUTNUMBER number of input ports
        InputNumber (1,1) double {mustBePositive, mustBeInteger} = 2
    end

    methods
        function this = Mux(props)
            % > MUX Construct a multiplexer node.
            arguments
                props.?ic.node.Mux
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.InputNumber(this, val)
            oldVal = this.InputNumber;
            this.InputNumber = val;
            this.syncInputPorts(oldVal, val);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            for ii = 1:this.InputNumber
                this.addPort(ic.node.Port("in" + ii, MaxConnections=1), "inputs");
            end
            this.addPort(ic.node.Port("out"), "outputs");
            this.outputStatic("out");
        end
    end

    methods (Access = private)
        function syncInputPorts(this, oldN, newN)
            % > SYNCINPUTPORTS Add or remove input ports to match InputNumber.
            try
                if newN > oldN
                    for ii = (oldN+1):newN
                        this.addPort(ic.node.Port("in" + ii, MaxConnections=1), "inputs");
                    end
                elseif newN < oldN
                    for ii = oldN:-1:(newN+1)
                        port = this.findPort("in" + ii, "inputs");
                        this.removePort(port);
                    end
                end
            catch
                return
            end
        end
    end
end

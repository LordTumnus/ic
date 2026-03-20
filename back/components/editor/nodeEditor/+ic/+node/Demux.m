classdef Demux < ic.node.Node
    % > DEMUX Demultiplexer node — splits one input into N outputs.
    %   Accepts any edge type on the single input. All outputs are static.
    %   Rendered as a black tapered bar (Simulink style), mirrored from Mux.
    %
    %   d = ic.node.Demux(OutputNumber=4)
    %   d = ic.node.Demux(Label="Split", OutputNumber=3)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed beside the demux
        Label (1,1) string = ""

        % > OUTPUTNUMBER number of output ports
        OutputNumber (1,1) double {mustBePositive, mustBeInteger} = 2
    end

    methods
        function this = Demux(props)
            % > DEMUX Construct a demultiplexer node.
            arguments
                props.?ic.node.Demux
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function set.OutputNumber(this, val)
            oldVal = this.OutputNumber;
            this.OutputNumber = val;
            this.syncOutputPorts(oldVal, val);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("in", MaxConnections=1), "inputs");
            for ii = 1:this.OutputNumber
                this.addPort(ic.node.Port("out" + ii), "outputs");
                this.outputStatic("out" + ii);
            end
        end
    end

    methods (Access = private)
        function syncOutputPorts(this, oldN, newN)
            % > SYNCOUTPUTPORTS Add or remove output ports to match OutputNumber.
            try
                if newN > oldN
                    for ii = (oldN+1):newN
                        this.addPort(ic.node.Port("out" + ii), "outputs");
                        this.outputStatic("out" + ii);
                    end
                elseif newN < oldN
                    for ii = oldN:-1:(newN+1)
                        port = this.findPort("out" + ii, "outputs");
                        this.removePort(port);
                    end
                end
            catch
                return
            end
        end
    end
end

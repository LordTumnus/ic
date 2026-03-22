classdef Display < ic.node.Node
    % > DISPLAY Multi-channel oscilloscope sink node.
    %   Receives signals from connected edges and renders them as waveforms.
    %   InputNumber controls how many input ports are available.
    %
    %   d = ic.node.Display(Position=[400 100])
    %   d = ic.node.Display(Label="Scope", InputNumber=3, PreviewTime=4)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the node
        Label (1,1) string = ""

        % > INPUTNUMBER number of input ports (dynamically adds/removes ports)
        InputNumber (1,1) double {mustBePositive, mustBeInteger} = 1

        % > PREVIEWTIME x-axis range in seconds for the waveform display
        PreviewTime (1,1) double {mustBePositive} = 2
    end

    methods
        function this = Display(props)
            % > DISPLAY Construct a display sink node.
            arguments
                props.?ic.node.Display
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
                return  % Port not yet created (during construction)
            end
        end
    end
end

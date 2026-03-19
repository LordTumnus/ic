classdef Logger < ic.node.Node
    % > LOGGER Scrolling terminal sink node.
    %   Displays log entries in a terminal-style console. The .log() method
    %   appends text that is reactively synced to the frontend display.
    %
    %   lg = ic.node.Logger(Position=[400 500])
    %   lg = ic.node.Logger(Label="Console", MaxLines=50)
    %   lg.log("System initialized")
    %   lg.log("Processing started at " + string(datetime))

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text displayed below the node
        Label (1,1) string = ""

        % > MAXLINES maximum number of log entries to keep
        MaxLines (1,1) double {mustBePositive, mustBeInteger} = 100
    end

    properties (SetObservable, AbortSet, Hidden, Description = "Reactive")
        % > LOGENTRIES log lines (auto-synced to frontend terminal display)
        LogEntries (1,:) string = string.empty
    end

    methods
        function this = Logger(props)
            % > LOGGER Construct a logger sink node.
            arguments
                props.?ic.node.Logger
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end

        function log(this, text)
            % > LOG Append a text entry to the terminal display.
            %
            %   logger.log("Hello world")
            %   logger.log("Value = " + string(42))
            arguments
                this (1,1) ic.node.Logger
                text (1,1) string
            end
            entries = this.LogEntries;
            entries(end+1) = text;
            if numel(entries) > this.MaxLines
                entries = entries(end - this.MaxLines + 1 : end);
            end
            this.LogEntries = entries;
        end

        function clearLog(this)
            % > CLEARLOG Clear all log entries.
            this.LogEntries = string.empty;
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(this)
            this.addPort(ic.node.Port("log"), "inputs");
        end
    end
end

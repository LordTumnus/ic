% > LOGGER stores and inspects frontend logs for a Frame
%
% The Logger receives log entries from the frontend (via Frame @log events)
% and provides methods to view, filter, and export logs.

classdef Logger < handle

    properties (Constant, Access = private)
        % Log level priority for filtering
        LevelPriority = dictionary(["debug", "info", "warn", "error"], [1, 2, 3, 4])
    end

    properties (SetAccess = private)
        % > BUFFER circular buffer of log entries
        Buffer = struct('level', {}, 'source', {}, 'message', {}, ...
                       'context', {}, 'timestamp', {})
        % > BUFFERSIZE maximum number of log entries to store
        BufferSize (1,1) double = 1000
        % > LOGLEVEL minimum log level to store/display
        LogLevel (1,1) string = "debug"
    end

    methods
        function this = Logger()
            % > LOGGER creates a new Logger instance
        end

        function setLogLevel(this, level)
            % > SETLOGLEVEL sets the minimum log level
            arguments
                this (1,1) ic.core.Logger
                level (1,1) string {mustBeMember(level, ["debug", "info", "warn", "error"])}
            end
            this.LogLevel = level;
        end
    end

    methods
        function added = add(this, data)
            % > ADD adds a log entry from the frontend
            %
            % Data should have: level, source, message, context, timestamp
            % Returns true if the entry was added (met log level threshold)

            % Check log level threshold
            logLevel = string(data.level);
            if this.LevelPriority(logLevel) < this.LevelPriority(this.LogLevel)
                added = false;
                return;
            end

            entry = struct(...
                'level', logLevel, ...
                'source', string(data.source), ...
                'message', string(data.message), ...
                'context', data.context, ...
                'timestamp', datetime(data.timestamp/1000, ...
                    'ConvertFrom', 'posixtime', 'TimeZone', 'local'));

            % Add to circular buffer
            if numel(this.Buffer) >= this.BufferSize
                this.Buffer(1) = [];
            end
            this.Buffer(end+1) = entry;
            added = true;
        end

        function logs = all(this)
            % > ALL returns all stored log entries as a table
            if isempty(this.Buffer)
                logs = table();
                return;
            end
            logs = struct2table(this.Buffer);
        end

        function logs = filter(this, options)
            % > FILTER returns logs matching the specified criteria
            %
            % Options:
            %   Level    - Minimum log level ("debug", "info", "warn", "error")
            %   Source   - Source module name (supports partial match)
            %   Since    - Datetime or duration for time-based filtering
            %   Contains - Text to search for in messages
            %   Limit    - Maximum number of entries to return

            arguments
                this (1,1) ic.core.Logger
                options.Level (1,1) string = "debug"
                options.Source (1,1) string = ""
                options.Since = NaT
                options.Contains (1,1) string = ""
                options.Limit (1,1) double = inf
            end

            if isempty(this.Buffer)
                logs = table();
                return;
            end

            logs = struct2table(this.Buffer);

            % Filter by level
            minPriority = this.LevelPriority(options.Level);
            priorities = arrayfun(@(lvl) this.LevelPriority(lvl), logs.level);
            logs = logs(priorities >= minPriority, :);

            % Filter by source
            if options.Source ~= ""
                mask = contains(logs.source, options.Source, 'IgnoreCase', true);
                logs = logs(mask, :);
            end

            % Filter by time
            if ~isnat(options.Since)
                if isduration(options.Since)
                    cutoff = datetime('now', 'TimeZone', 'local') - options.Since;
                else
                    cutoff = options.Since;
                end
                logs = logs(logs.timestamp >= cutoff, :);
            end

            % Filter by message content
            if options.Contains ~= ""
                mask = contains(logs.message, options.Contains, 'IgnoreCase', true);
                logs = logs(mask, :);
            end

            % Apply limit (most recent)
            if height(logs) > options.Limit
                logs = logs(end-options.Limit+1:end, :);
            end
        end

        function show(this, n)
            % > SHOW displays the most recent n log entries (default: 20)
            arguments
                this (1,1) ic.core.Logger
                n (1,1) double = 20
            end

            logs = this.filter('Limit', n);

            if isempty(logs) || height(logs) == 0
                fprintf("No logs to display.\n");
                return;
            end

            for ii = 1:height(logs)
                this.printEntry(table2struct(logs(ii,:)));
            end
        end

        function clear(this)
            % > CLEAR clears the log buffer
            this.Buffer = struct('level', {}, 'source', {}, 'message', {}, ...
                               'context', {}, 'timestamp', {});
        end

    end

    methods (Access = private)
        function printEntry(~, entry)
            % > PRINTENTRY formats and prints a log entry to command window

            % Format level with color hints
            switch entry.level
                case "debug"
                    levelStr = "[DEBUG]";
                case "info"
                    levelStr = "[INFO] ";
                case "warn"
                    levelStr = "[WARN] ";
                case "error"
                    levelStr = "[ERROR]";
            end

            timeStr = string(entry.timestamp, "HH:mm:ss.SSS");

            fprintf("%s %s [%s] %s\n", timeStr, levelStr, entry.source, entry.message);

            % Print context if present and non-empty
            if ~isempty(entry.context) && isstruct(entry.context)
                fields = fieldnames(entry.context);
                for ii = 1:numel(fields)
                    val = entry.context.(fields{ii});
                    if isstruct(val)
                        valStr = jsonencode(val);
                    else
                        valStr = string(val);
                    end
                    fprintf("              %s: %s\n", fields{ii}, valStr);
                end
            end
        end
    end

end

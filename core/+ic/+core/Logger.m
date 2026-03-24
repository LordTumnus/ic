classdef Logger < handle
   % circular log buffer for frontend log entries.
   % Owned by #ic.Frame and populated by @log events sent by the Svelte logger.
   % Logging is opt-in: entries are only collected when #ic.Frame.Debug is true. when  #ic.Frame.Debug is false, the Svelte logger discards entries immediately
   % Log levels in ascending priority: debug < info < warn < error.

   properties (Constant, Access = private)
      % priority weights for the four log levels; used for threshold comparison
      LevelPriority = dictionary(["debug", "info", "warn", "error"], [1, 2, 3, 4])
   end

   properties (SetAccess = private)
      % circular buffer of log entry structs
      Buffer = struct('level', {}, 'source', {}, 'message', {}, ...
                     'context', {}, 'timestamp', {})

      % maximum number of entries to retain. Oldest is dropped when this limit is hit
      BufferSize (1,1) double = 1000

      % minimum log level. Entries with a lower priority are discarded and not stored in the buffer
      LogLevel (1,1) string = "debug"
   end

   methods
      function setLogLevel(this, level)
         % set the minimum level. Entries below this level are ignored and not stored in the buffer.
         arguments
            this (1,1) ic.core.Logger
            % lowest logging level to store, inclusive
            level (1,1) string {mustBeMember(level, ["debug", "info", "warn", "error"])}
         end
         this.LogLevel = level;
      end
   end

   methods (Access = {?ic.Frame})
      function added = add(this, data)
         % add a log entry received from the Svelte frontend.
         % The entry is silently dropped if its level is below the set #ic.core.Logger.LogLevel.
         % {returns} a logical value of true if the entry was stored, or false if it was filtered out {/returns}
         arguments
            this (1,1) ic.core.Logger
            % the information coming from the frontend
            data struct
         end

         % check log level threshold
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

         % add to circular buffer, dropping the oldest entry when full
         if numel(this.Buffer) >= this.BufferSize
            this.Buffer(1) = [];
         end
         this.Buffer(end+1) = entry;
         added = true;
      end
   end

   methods (Access = public)
      function logs = all(this)
         % return all stored log entries as a MATLAB table.
         % {returns} table with columns: level, source, message, context, timestamp {/returns}
         if isempty(this.Buffer)
            logs = table();
            return;
         end
         logs = struct2table(this.Buffer);
      end

      function logs = filter(this, options)
         % return log entries matching the specified criteria (all criteria are ANDed).
         % {returns} table subset matching all specified filters {/returns}
         % {example}
         %   frame.Logger.filter(Level="warn");
         %   frame.Logger.filter(Source="Bridge", Since=minutes(5));
         %   frame.Logger.filter(Contains="failed", Limit=10);
         % {/example}
         arguments
            this (1,1) ic.core.Logger
            % minimum log level (inclusive)
            options.Level (1,1) string = "debug"
            % source module to match; case-insensitive partial match
            options.Source (1,1) string = ""
            % datetime or duration cutoff; entries older than this are excluded
            options.Since = NaT
            % text to search for in message field; case-insensitive
            options.Contains (1,1) string = ""
            % maximum number of entries to return (most recent N)
            options.Limit (1,1) double = inf
         end

         if isempty(this.Buffer)
            logs = table();
            return;
         end

         logs = struct2table(this.Buffer);

         % filter by level
         minPriority = this.LevelPriority(options.Level);
         priorities = arrayfun(@(lvl) this.LevelPriority(lvl), logs.level);
         logs = logs(priorities >= minPriority, :);

         % filter by source
         if options.Source ~= ""
            mask = contains(logs.source, options.Source, 'IgnoreCase', true);
            logs = logs(mask, :);
         end

         % filter by time
         if ~isnat(options.Since)
            if isduration(options.Since)
               cutoff = datetime('now', 'TimeZone', 'local') - options.Since;
            else
               cutoff = options.Since;
            end
            logs = logs(logs.timestamp >= cutoff, :);
         end

         % filter by message content
         if options.Contains ~= ""
            mask = contains(logs.message, options.Contains, 'IgnoreCase', true);
            logs = logs(mask, :);
         end

         % apply limit (most recent)
         if height(logs) > options.Limit
            logs = logs(end-options.Limit+1:end, :);
         end
      end

      function show(this, n)
         % print the n most recent log entries to the command window.
         % Each entry is formatted as: HH:mm:ss.SSS [LEVEL] [source] message. Structured context fields are printed indented below the message.
         arguments
            this (1,1) ic.core.Logger
            % number of most-recent entries to display
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
         % empty the log buffer
         this.Buffer = struct('level', {}, 'source', {}, 'message', {}, ...
                            'context', {}, 'timestamp', {});
      end

   end

   methods (Access = private)
      function printEntry(~, entry)
         % format and print a single log entry to the command window.
         % format: HH:mm:ss.SSS [LEVEL] [source] message
         % structured context fields are printed indented below the message.

         % format level with fixed-width label
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

         % print context if present and non-empty
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

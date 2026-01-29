classdef LoggerTest < matlab.unittest.TestCase
    % LOGGERTEST tests the ic.core.Logger class functionality
    %
    % Tests include:
    %   - Logger construction
    %   - Adding log entries
    %   - Log level filtering
    %   - Filtering and querying logs
    %   - Clearing logs

    properties
        Logger
    end

    methods (TestMethodSetup)
        function createLogger(testCase)
            testCase.Logger = ic.core.Logger();
        end
    end

    methods (Test)
        function testLoggerConstruction(testCase)
            % Test that Logger can be constructed
            testCase.verifyClass(testCase.Logger, 'ic.core.Logger');
        end

        function testEmptyBufferInitially(testCase)
            % Test that buffer is empty initially
            logs = testCase.Logger.all();
            testCase.verifyEmpty(logs);
        end

        function testAddLogEntry(testCase)
            % Test adding a log entry
            entry = struct(...
                'level', 'info', ...
                'source', 'Test', ...
                'message', 'Test message', ...
                'context', struct(), ...
                'timestamp', posixtime(datetime('now')) * 1000);

            added = testCase.Logger.add(entry);

            testCase.verifyTrue(added);
            logs = testCase.Logger.all();
            testCase.verifyEqual(height(logs), 1);
            testCase.verifyEqual(logs.level, "info");
            testCase.verifyEqual(logs.source, "Test");
            testCase.verifyEqual(logs.message, "Test message");
        end

        function testLogLevelFiltering(testCase)
            % Test that logs below minLevel are filtered
            testCase.Logger.setLogLevel("warn");

            debugEntry = struct('level', 'debug', 'source', 'Test', ...
                'message', 'Debug', 'context', struct(), ...
                'timestamp', posixtime(datetime('now')) * 1000);
            infoEntry = struct('level', 'info', 'source', 'Test', ...
                'message', 'Info', 'context', struct(), ...
                'timestamp', posixtime(datetime('now')) * 1000);
            warnEntry = struct('level', 'warn', 'source', 'Test', ...
                'message', 'Warn', 'context', struct(), ...
                'timestamp', posixtime(datetime('now')) * 1000);
            errorEntry = struct('level', 'error', 'source', 'Test', ...
                'message', 'Error', 'context', struct(), ...
                'timestamp', posixtime(datetime('now')) * 1000);

            addedDebug = testCase.Logger.add(debugEntry);
            addedInfo = testCase.Logger.add(infoEntry);
            addedWarn = testCase.Logger.add(warnEntry);
            addedError = testCase.Logger.add(errorEntry);

            testCase.verifyFalse(addedDebug);
            testCase.verifyFalse(addedInfo);
            testCase.verifyTrue(addedWarn);
            testCase.verifyTrue(addedError);

            logs = testCase.Logger.all();
            testCase.verifyEqual(height(logs), 2);
        end

        function testFilterByLevel(testCase)
            % Test filtering logs by level
            testCase.addTestLogs();

            warnAndAbove = testCase.Logger.filter('Level', 'warn');
            testCase.verifyEqual(height(warnAndAbove), 2);

            errorsOnly = testCase.Logger.filter('Level', 'error');
            testCase.verifyEqual(height(errorsOnly), 1);
        end

        function testFilterBySource(testCase)
            % Test filtering logs by source
            testCase.addTestLogs();

            bridgeLogs = testCase.Logger.filter('Source', 'Bridge');
            testCase.verifyEqual(height(bridgeLogs), 1);
            testCase.verifyEqual(bridgeLogs.source, "Bridge");
        end

        function testFilterByContains(testCase)
            % Test filtering logs by message content
            testCase.addTestLogs();

            messageLogs = testCase.Logger.filter('Contains', 'message');
            testCase.verifyGreaterThan(height(messageLogs), 0);
        end

        function testFilterByLimit(testCase)
            % Test limiting number of returned logs
            testCase.addTestLogs();

            limited = testCase.Logger.filter('Limit', 2);
            testCase.verifyEqual(height(limited), 2);
        end

        function testClearLogs(testCase)
            % Test clearing the log buffer
            testCase.addTestLogs();
            testCase.verifyGreaterThan(height(testCase.Logger.all()), 0);

            testCase.Logger.clear();
            testCase.verifyEmpty(testCase.Logger.all());
        end

        function testShowDoesNotError(testCase)
            % Test that show() works without errors
            testCase.addTestLogs();

            % Should not throw
            testCase.Logger.show(5);
        end

        function testShowWithEmptyBuffer(testCase)
            % Test that show() handles empty buffer
            % Should not throw
            testCase.Logger.show();
        end

        function testCircularBuffer(testCase)
            % Test that buffer doesn't exceed BufferSize
            % Add more logs than buffer size (1000)
            for ii = 1:1100
                entry = struct(...
                    'level', 'info', ...
                    'source', 'Test', ...
                    'message', sprintf('Message %d', ii), ...
                    'context', struct(), ...
                    'timestamp', posixtime(datetime('now')) * 1000);
                testCase.Logger.add(entry);
            end

            logs = testCase.Logger.all();
            testCase.verifyLessThanOrEqual(height(logs), 1000);
        end

        function testTimestampConversion(testCase)
            % Test that timestamps are converted to datetime
            entry = struct(...
                'level', 'info', ...
                'source', 'Test', ...
                'message', 'Timestamp test', ...
                'context', struct(), ...
                'timestamp', posixtime(datetime('now')) * 1000);

            testCase.Logger.add(entry);
            logs = testCase.Logger.all();

            testCase.verifyClass(logs.timestamp, 'datetime');
        end

        function testContextPreserved(testCase)
            % Test that context is preserved in log entries
            ctx = struct('componentId', 'btn1', 'eventName', 'click');
            entry = struct(...
                'level', 'warn', ...
                'source', 'Test', ...
                'message', 'With context', ...
                'context', ctx, ...
                'timestamp', posixtime(datetime('now')) * 1000);

            testCase.Logger.add(entry);
            logs = testCase.Logger.all();

            testCase.verifyEqual(string(logs.context.componentId), "btn1");
            testCase.verifyEqual(string(logs.context.eventName), "click");
        end
    end

    methods (Access = private)
        function addTestLogs(testCase)
            % Helper to add a variety of test logs
            entries = {
                struct('level', 'debug', 'source', 'Component', ...
                    'message', 'Debug message', 'context', struct(), ...
                    'timestamp', posixtime(datetime('now')) * 1000);
                struct('level', 'info', 'source', 'Registry', ...
                    'message', 'Info message', 'context', struct(), ...
                    'timestamp', posixtime(datetime('now')) * 1000);
                struct('level', 'warn', 'source', 'Bridge', ...
                    'message', 'Warning message', 'context', struct(), ...
                    'timestamp', posixtime(datetime('now')) * 1000);
                struct('level', 'error', 'source', 'Container', ...
                    'message', 'Error message', 'context', struct(), ...
                    'timestamp', posixtime(datetime('now')) * 1000);
            };

            for ii = 1:numel(entries)
                testCase.Logger.add(entries{ii});
            end
        end
    end

end

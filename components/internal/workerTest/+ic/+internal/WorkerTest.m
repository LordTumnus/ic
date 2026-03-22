classdef WorkerTest < ic.core.Component
    % WORKERTEST  Diagnostic component for testing Web Worker support in CEF.

    events (Description = "Reactive")
        TestComplete
    end

    methods
        function this = WorkerTest()
            this@ic.core.Component();
        end
    end
end

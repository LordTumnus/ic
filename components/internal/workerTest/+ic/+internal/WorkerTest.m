classdef WorkerTest < ic.core.Component
    % diagnostic component for testing Web Worker support in MATLAB's CEF sandbox. On mount, the Svelte side runs all 8 Worker creation methods (classic file, module file, blob URL, data URL, inline, etc.) and publishes the results back via TestComplete.
    %
    % {note} classic workers from file paths are the only method that works
    % reliably in Chromium 104. Module workers and blob/data URLs are blocked
    % by CSP {/note}

    events (Description = "Reactive")
        % fires when all worker tests finish running
        % {payload}
        % value | struct: struct with passed (double), total (double), and results (cell of structs with method, success, error, durationMs)
        % {/payload}
        TestComplete
    end

    methods
        function this = WorkerTest()
            this@ic.core.Component();
        end
    end
end

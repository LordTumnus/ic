classdef IntegrationTest < matlab.uitest.TestCase
% INTEGRATIONTEST True end-to-end tests for MATLAB <-> Svelte bridge
%
%   These tests verify actual round-trip communication between MATLAB
%   and Svelte. Each test:
%   1. Performs an action in MATLAB
%   2. Waits for Svelte to process it
%   3. Queries Svelte state to verify the action took effect
%
%   Requirements:
%   - Frontend must be built (npm run build in @front)
%   - Tests use getState() method to verify Svelte received updates
%
%   Test categories:
%   - Reactive Props: Verify MATLAB->Svelte property sync
%   - Reactive Methods: Verify MATLAB->Svelte->MATLAB round-trip
%   - Static Children: Verify static composition pattern

    properties
        Figure
        Frame
    end

    properties (Constant)
        % Timeout for waiting on Svelte responses (seconds)
        TIMEOUT = 2
    end

    methods (TestMethodSetup)
        function createFigure(testCase)
            testCase.Figure = uifigure('Visible', 'off');
            testCase.Frame = ic.Frame('Parent', testCase.Figure);
        end
    end

    methods (TestMethodTeardown)
        function clearFigure(testCase)
            if isvalid(testCase.Figure)
                delete(testCase.Figure);
            end
        end
    end

    methods (Test)
        function testComponentInsertionRoundTrip(testCase)
            % Verify component is created in Svelte after insertion

            comp = ic.test.TestComponent("test1");
            comp.Label = "Initial Label";
            comp.Counter = 42;

            comp.Parent = testCase.Frame;

            % Query Svelte state to verify component was created
            promise = comp.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved(), ...
                'getState should receive response from Svelte');

            result = promise.get();
            testCase.assertTrue(result.Success, ...
                'getState should succeed');
            testCase.verifyEqual(result.Data.label, 'Initial Label', ...
                'Svelte should have received initial label');
            testCase.verifyEqual(result.Data.counter, 42, ...
                'Svelte should have received initial counter');
        end

        function testMultipleComponentsInsertion(testCase)
            % Verify multiple components are created independently
            comp1 = ic.test.TestComponent("comp1");
            comp1.Label = "First";
            comp2 = ic.test.TestComponent("comp2");
            comp2.Label = "Second";

            comp1.Parent = testCase.Frame;
            comp2.Parent = testCase.Frame;

            % Query both components
            p1 = comp1.getState();
            p2 = comp2.getState();
            p1.wait(testCase.TIMEOUT);
            p2.wait(testCase.TIMEOUT);

            testCase.verifyEqual(p1.get().Data.label, 'First');
            testCase.verifyEqual(p2.get().Data.label, 'Second');
        end
    end

    methods (Test)
        function testPropertyUpdateReachesSvelte(testCase)
            % Verify property changes in MATLAB are received by Svelte

            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            % Change property after attachment
            comp.Label = "Updated from MATLAB";

            % Verify Svelte received the update
            promise = comp.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data.label,...
             'Updated from MATLAB', ...
             'Svelte should have received property update');
        end

        function testCounterPropertySync(testCase)
            % Verify numeric property syncs correctly
            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            comp.Counter = 999;

            promise = comp.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.verifyEqual(promise.get().Data.counter, 999);
        end

        function testEnabledPropertySync(testCase)
            % Verify boolean property syncs correctly
            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            comp.Enabled = false;

            promise = comp.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.verifyEqual(promise.get().Data.enabled, false);
        end

        function testMultiplePropertyUpdates(testCase)
            % Verify multiple rapid property updates are all received
            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            % Rapid-fire updates
            comp.Label = "Update 1";
            comp.Label = "Update 2";
            comp.Label = "Final Update";
            comp.Counter = 100;

            promise = comp.getState();
            promise.wait(testCase.TIMEOUT);

            % Svelte should have the final values
            testCase.verifyEqual(promise.get().Data.label, 'Final Update');
            testCase.verifyEqual(promise.get().Data.counter, 100);
        end
    end

    methods (Test)
        function testEchoMethodRoundTrip(testCase)
            % Verify Echo method round-trips value through Svelte

            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            promise = comp.echo("Hello from MATLAB");
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved(), ...
                'Echo should receive response');
            testCase.assertTrue(promise.get().Success);
            testCase.verifyEqual(promise.get().Data, 'Hello from MATLAB', ...
                'Echo should return the same value');
        end

        function testEchoWithComplexData(testCase)
            % Verify Echo handles complex data structures
            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            testData = struct('name', 'test', 'values', [1 2 3]);
            promise = comp.echo(testData);
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data.name, 'test');
        end

        function testIncrementCounterMethod(testCase)
            % Verify IncrementCounter modifies Svelte state and returns result

            comp = ic.test.TestComponent("test1");
            comp.Counter = 10;
            comp.Parent = testCase.Frame;

            promise = comp.incrementCounter();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data, 11, ...
                'Counter should be incremented to 11');

            % Verify state was actually updated in Svelte
            statePromise = comp.getState();
            statePromise.wait(testCase.TIMEOUT);
            testCase.verifyEqual(statePromise.get().Data.counter, 11);
        end

        function testMultipleIncrements(testCase)
            % Verify multiple method calls work correctly
            comp = ic.test.TestComponent("test1");
            comp.Counter = 0;
            comp.Parent = testCase.Frame;

            % Call increment 3 times
            p1 = comp.incrementCounter();
            p2 = comp.incrementCounter();
            p3 = comp.incrementCounter();
            p3.wait(testCase.TIMEOUT);

            testCase.verifyEqual(p1.get().Data, 1);
            testCase.verifyEqual(p2.get().Data, 2);
            testCase.verifyEqual(p3.get().Data, 3);
        end
    end

    methods (Test)
        function testStyleAppliedToComponent(testCase)
            % Verify style() applies CSS that can be queried from Svelte

            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            % Apply a background color style
            comp.css.style(".test-component", "backgroundColor", "rgb(255, 0, 0)");

            % Query computed styles from Svelte
            promise = comp.queryStyle();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            styles = promise.get().Data;
            testCase.verifyEqual(styles.backgroundColor, 'rgb(255, 0, 0)');
        end

        function testColorSchemeChangeUpdatesStyles(testCase)
            % Verify changing ColorScheme updates CSS variables in components

            comp = ic.test.TestComponent("test1");
            comp.Parent = testCase.Frame;

            % Style the component using a CSS variable
            comp.css.style(".test-component", "backgroundColor", "var(--ic-primary)");

            % Query initial style (light mode: primary = #18181b)
            promise1 = comp.queryStyle();
            promise1.wait(testCase.TIMEOUT);
            testCase.assertTrue(promise1.isResolved());
            lightBg = promise1.get().Data.backgroundColor;

            % Change to dark mode
            testCase.Frame.ColorScheme = "dark";

            % Query style again (dark mode: primary = #fafafa)
            promise2 = comp.queryStyle();
            promise2.wait(testCase.TIMEOUT);
            testCase.assertTrue(promise2.isResolved());
            darkBg = promise2.get().Data.backgroundColor;

            % Verify the background color changed
            testCase.verifyNotEqual(lightBg, darkBg, ...
                'Background color should change when switching color scheme');
        end
    end

    % Static Children - Insertion
    methods (Test)
        function testStaticContainerInsertion(testCase)
            % Verify container and static child are created in Svelte

            container = ic.test.TestStaticContainer("container1");
            container.Title = "My Container";
            container.Child.Label = "Static Child";
            container.Child.Counter = 42;

            container.Parent = testCase.Frame;

            % Query container state
            promise = container.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved(), ...
                'getState should receive response from Svelte');
            result = promise.get();
            testCase.assertTrue(result.Success, 'getState should succeed');
            testCase.verifyEqual(result.Data.title, 'My Container', ...
                'Svelte should have received container title');
        end

        function testStaticChildInitialProps(testCase)
            % Verify static child receives initial property values

            container = ic.test.TestStaticContainer("container2");
            container.Child.Label = "Initial Label";
            container.Child.Counter = 100;

            container.Parent = testCase.Frame;

            % Query child state directly
            promise = container.Child.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            result = promise.get();
            testCase.verifyEqual(result.Data.label, 'Initial Label', ...
                'Static child should have received initial label');
            testCase.verifyEqual(result.Data.counter, 100, ...
                'Static child should have received initial counter');
        end
    end

    % Static Children - Property Updates
    methods (Test)
        function testStaticChildPropertyUpdate(testCase)
            % Verify static child props update after attachment

            container = ic.test.TestStaticContainer("container3");
            container.Parent = testCase.Frame;

            % Update child property after attachment
            container.Child.Label = "Updated Label";

            promise = container.Child.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data.label, 'Updated Label', ...
                'Static child should receive property updates');
        end

        function testStaticChildCounterUpdate(testCase)
            % Verify static child counter prop updates

            container = ic.test.TestStaticContainer("container4");
            container.Parent = testCase.Frame;

            container.Child.Counter = 999;

            promise = container.Child.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data.counter, 999);
        end

        function testContainerTitleUpdate(testCase)
            % Verify container title prop updates

            container = ic.test.TestStaticContainer("container5");
            container.Parent = testCase.Frame;

            container.Title = "New Title";

            promise = container.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data.title, 'New Title');
        end
    end

    % Static Children - Parent-Child Linking
    methods (Test)
        function testChildCounterSyncsToParent(testCase)
            % Verify child counter changes sync to parent's childCounter
            % (via frontend-only $effect wiring)

            container = ic.test.TestStaticContainer("container6");
            container.Child.Counter = 50;
            container.Parent = testCase.Frame;

            % After attachment, the frontend $effect should sync
            % child.counter -> parent.childCounter
            promise = container.getState();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data.childCounter, 50, ...
                'Parent childCounter should mirror child counter');
        end

        function testChildCounterUpdateSyncsToParent(testCase)
            % Verify updating child counter syncs to parent

            container = ic.test.TestStaticContainer("container7");
            container.Parent = testCase.Frame;

            % Update child counter after attachment
            container.Child.Counter = 777;

            % Small delay to allow $effect to run
            pause(1);

            testCase.verifyEqual(container.ChildCounter, container.Child.Counter);

        end

        function testParentChildCounterSyncsToChild(testCase)
            % Verify parent childCounter changes sync to child's counter
            % (via frontend-only inverse $effect wiring)

            container = ic.test.TestStaticContainer("container8");
            container.Parent = testCase.Frame;

            % Update parent's childCounter
            container.ChildCounter = 123;

            % Wait for $effect to sync and propagate back to MATLAB
            pause(1);

            % Verify child counter matches parent's childCounter
            testCase.verifyEqual(container.Child.Counter, container.ChildCounter, ...
                'Child counter should mirror parent childCounter');
        end
    end

    % Static Children - Removal
    methods (Test)
        function testStaticContainerRemoval(testCase)
            % Verify removing container also removes static child

            container = ic.test.TestStaticContainer("container9");
            container.Parent = testCase.Frame;

            % Verify both are attached
            childPromise = container.Child.getState();
            childPromise.wait(testCase.TIMEOUT);
            testCase.assertTrue(childPromise.isResolved(), ...
                'Child should be queryable before removal');

            % Remove container
            container.Parent = [];

            % After removal, child should no longer be queryable
            childPromise2 = container.Child.getState();

            % We expect this to NOT resolve (child is gone)
            pause(0.3);
            testCase.assertFalse(childPromise2.isResolved(), ...
                'Child should not respond after container removal');
        end
    end

    % Static Children - Method Invocation
    methods (Test)
        function testStaticChildMethodInvocation(testCase)
            % Verify methods can be invoked on static children

            container = ic.test.TestStaticContainer("container10");
            container.Parent = testCase.Frame;

            % Call echo method on static child
            promise = container.Child.echo("Hello from static child");
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data, 'Hello from static child');
        end

        function testStaticChildIncrementCounter(testCase)
            % Verify incrementCounter method works on static child

            container = ic.test.TestStaticContainer("container11");
            container.Child.Counter = 10;
            container.Parent = testCase.Frame;

            promise = container.Child.incrementCounter();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved());
            testCase.verifyEqual(promise.get().Data, 11);
        end
    end

    % Logging Integration
    methods (Test)
        function testLogFlowFromSvelteToMatlab(testCase)
            % Verify logs from Svelte are captured in Frame.logs

            % Enable debug mode
            testCase.Frame.Debug = true;

            % Clear any existing logs
            testCase.Frame.logs.clear();

            % Create component and attach
            comp = ic.test.TestComponent("logtest");
            comp.Parent = testCase.Frame;

            % Trigger a log event from Svelte
            promise = comp.triggerLog();
            promise.wait(testCase.TIMEOUT);

            testCase.assertTrue(promise.isResolved(), ...
                'triggerLog should receive response from Svelte');

            % Verify the log was captured
            logs = testCase.Frame.logs.all();
            testCase.verifyGreaterThan(height(logs), 0, ...
                'Frame.logs should contain entries after triggerLog');

            % Find the TestComponent log entry
            testComponentLogs = logs(logs.source == "TestComponent", :);
            testCase.verifyGreaterThan(height(testComponentLogs), 0, ...
                'Should have log entry from TestComponent');
            testCase.verifyEqual(testComponentLogs.level(end), "error", ...
                'Log should be at error level');
        end
    end

end

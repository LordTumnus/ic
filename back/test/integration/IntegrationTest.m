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
            comp.style(".test-component", "backgroundColor", "rgb(255, 0, 0)");

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
            comp.style(".test-component", "backgroundColor", "var(--primary)");

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

end

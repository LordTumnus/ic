classdef TestComponent < ic.core.Component
% TESTCOMPONENT Integration test component with all reactive features
%
%   This component exposes reactive properties, events, and methods
%   for testing the full MATLAB <-> Svelte bridge integration.
%
%   Features tested:
%   - Reactive props: Label, Counter, Enabled (MATLAB <-> Svelte sync)
%   - Reactive events: Clicked, ValueChanged (Svelte -> MATLAB)
%   - Reactive methods: Echo, IncrementCounter (MATLAB -> Svelte with response)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % Label - Text label displayed in the component
        Label string = ""

        % Counter - Numeric counter value
        Counter double = 0

        % Enabled - Whether the component is enabled
        Enabled logical = true
    end

    events (Description = "Reactive")
        % Clicked - Fired when user clicks the component
        Clicked

        % ValueChanged - Fired when a value changes in the UI
        ValueChanged
    end

    methods
        function this = TestComponent(id)
            % TESTCOMPONENT Construct a new test component
            %
            %   comp = ic.test.TestComponent(id) creates a test component
            %   with the specified unique identifier.

            this@ic.core.Component(id);
        end
    end

    methods (Description = "Reactive")
        function out = echo(this, value)
            % ECHO Echo back the input value
            %
            %   response = comp.echo(value) sends the value to the Svelte
            %   component which echoes it back unchanged. Used to test
            %   MATLAB -> Svelte method invocation with response.

            out = this.publish("echo", value);
        end

        function out = incrementCounter(this)
            % INCREMENTCOUNTER Increment the counter in the UI
            %
            %   response = comp.incrementCounter() tells the Svelte component
            %   to increment its local counter and return the new value.
            %   Used to test methods that modify UI state.

            out = this.publish("incrementCounter", []);
        end

        function out = getState(this)
            % GETSTATE Get current state from Svelte component
            %
            %   response = comp.getState() queries the Svelte component for
            %   its current property values. Returns a struct with fields:
            %   - label: current label value
            %   - counter: current counter value
            %   - enabled: current enabled value
            %
            %   This enables true integration testing by verifying that
            %   property updates sent to Svelte were actually received.

            out = this.publish("getState", []);
        end

        function out = queryStyle(this)
            % QUERYSTYLE Query computed CSS styles from the Svelte component

            out = this.publish("queryStyle", {});
        end
    end
end

classdef TestStaticContainer < ic.core.ComponentContainer
% TESTSTATICCONTAINER Integration test container with a static TestComponent child
%
%   This component tests static composition pattern where children are
%   declared in the constructor and included in the parent's @insert payload.
%

    properties (SetObservable, AbortSet, Description = "Reactive")
        % Title - Container title displayed in the header
        Title string = "Static Container"

        % ChildCounter - Mirrors the child's Counter property
        % This enables testing frontend-only wiring in Svelte
        ChildCounter double = 0
    end

    properties (SetAccess = immutable)
        % Child - The static TestComponent child
        Child ic.test.TestComponent
    end

    methods
        function this = TestStaticContainer(id)
            % TESTSTATICCONTAINER Construct a static container with one child
            %
            %   container = ic.test.TestStaticContainer(id) creates a container
            %   with a pre-declared TestComponent child at id-child.

            this@ic.core.ComponentContainer(id);

            % Create the static child with suffix "-child"
            this.Child = ic.test.TestComponent(id + "-child");
            this.addStaticChild(this.Child);
        end
    end

    methods (Description = "Reactive")
        function out = getState(this)
            % GETSTATE Get current state from Svelte component
            %
            %   response = container.getState() queries the Svelte component
            %   for its current property values. Returns a struct with:
            %   - title: current title value
            %   - childCounter: current childCounter value

            out = this.publish("getState", []);
        end

        function out = getChildState(this)
            % GETCHILDSTATE Get current state from the static child
            %
            %   response = container.getChildState() queries the static child's
            %   Svelte component for its current property values.

            out = this.Child.getState();
        end
    end
end

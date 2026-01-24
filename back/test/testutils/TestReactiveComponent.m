classdef TestReactiveComponent < ic.core.Component
% TESTREACTIVECOMPONENT Test helper that exposes reactive features
%
%   Used by ComponentBaseTest to verify reactive property and event behavior

    properties (SetObservable, AbortSet, Description = "Reactive")
        Value double = 0
    end

    events (Description = "Reactive")
        ButtonClicked
    end

    methods
        function this = TestReactiveComponent(id)
            this@ic.core.Component(id);
        end

        function definition = getDefinitionForTest(this)
            % Expose protected method for testing
            definition = this.getComponentDefinition();
        end
    end

    methods (Description = "Reactive")
        function out = Ping(~, value)
            % Simple reactive method used for schema publishing tests
            out = publish("Ping", value);
        end
    end
end

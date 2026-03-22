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
        function this = TestReactiveComponent(props)
            arguments
                props.?TestReactiveComponent
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end

        function definition = getDefinitionForTest(this)
            % Expose protected method for testing
            definition = this.getComponentDefinition();
        end
    end

    methods (Description = "Reactive")
        function out = ping(this, value)
            % Simple reactive method used for schema publishing tests
            out = this.publish("ping", struct("value", value));
        end
    end
end

classdef Switch < ic.core.Component
    % switch slider that maintains on/off state

    properties (SetObservable, AbortSet, Description = "Reactive")
        % switch state
        Value matlab.lang.OnOffSwitchState = "off"

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % shape of the switch track and thumb
        Shape string {mustBeMember(Shape, ["square", "pill"])} = "square"

        % dimension of the switch relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether to display the on/off state label next to the switch
        ShowLabel logical = false

        % whether the switch is disabled and cannot be interacted with
        Disabled logical = false
    end

    events (Description = "Reactive")
        % triggered when the user toggles the switch
        ValueChanged
    end

    methods
        function this = Switch(props)
            arguments
                props.?ic.Switch
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the switch
            out = this.publish("focus", []);
        end
    end
end

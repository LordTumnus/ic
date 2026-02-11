classdef Switch < ic.core.Component
    % > SWITCH Slide switch that maintains on/off state.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE switch state (on or off)
        Value matlab.lang.OnOffSwitchState = "off"
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > SHAPE shape of the switch track and thumb
        Shape string {mustBeMember(Shape, ["square", "pill"])} = "square"
        % > SIZE size of the switch
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > SHOWLABEL whether to display the on/off state label
        ShowLabel logical = false
        % > DISABLED whether the switch is disabled
        Disabled logical = false
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
            % > FOCUS programmatically focus the switch
            out = this.publish("focus", []);
        end
    end
end

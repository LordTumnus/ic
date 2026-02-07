classdef ToggleButton < ic.core.Component
    % > TOGGLEBUTTON Latching button that maintains on/off state.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL text label of the button
        Label string = ""
        % > VALUE toggle state (true = pressed, false = released)
        Value logical = false
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > SIZE size of the button -> affects padding
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the button is disabled
        Disabled logical = false
    end

    methods
        function this = ToggleButton(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(id);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the button
            out = this.publish("focus", []);
        end
    end
end

classdef ToggleButton < ic.core.Component
    % latching button that maintains on/off state

    properties (SetObservable, AbortSet, Description = "Reactive")
        % text label of the button
        Label string = ""

        % toggle state
        Value logical = false

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"

        % dimension of the button relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the button is disabled and cannot be interacted with
        Disabled logical = false
    end

    events (Description = "Reactive")
        % triggered when the user toggles the button
        ValueChanged
    end

    methods
        function this = ToggleButton(props)
            arguments
                props.?ic.ToggleButton
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the button
            out = this.publish("focus", []);
        end
    end
end

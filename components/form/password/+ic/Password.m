classdef Password < ic.core.Component
    % masked text input with visibility toggle.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current text value of the password input
        Value string = ""

        % ghost text displayed when the #ic.Password.Value is empty
        Placeholder string = ""

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"

        % dimension of the input relative to the text font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the input is disabled and cannot be interacted with
        Disabled logical = false

        % whether the input is read-only
        Readonly logical = false

        % whether the input is in an invalid state. When true, the input will be styled with error colors and the #ic.Password.ErrorMessage will be displayed below the input.
        Invalid logical = false

        % error message displayed below the input when invalid
        ErrorMessage string = ""

        % helper text displayed below the input
        HelperText string = ""

        % whether to show the visibility toggle button that allows the user to switch between masked and unmasked input
        ShowToggle logical = true
    end

    events (Description = "Reactive")
        % triggered when the value changes
        % {payload}
        % value | char: current text content
        % {/payload}
        ValueChanged

        % fires when the Enter key is pressed
        % {payload}
        % value | char: current text content at the time of submission
        % {/payload}
        Submitted
    end

    methods
        function this = Password(props)
            arguments
                props.?ic.Password
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the input
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % programmatically blur (unfocus) the input
            out = this.publish("blur", []);
        end

        function out = selectAll(this)
            % select all text in the input
            out = this.publish("selectAll", []);
        end

        function out = clear(this)
            % clear the input value
            out = this.publish("clear", []);
        end
    end
end

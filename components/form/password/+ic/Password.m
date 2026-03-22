classdef Password < ic.core.Component
    % > PASSWORD Masked text input with visibility toggle.
    %
    %   Password input field with show/hide toggle, lock icon, and
    %   validation states. Suitable for authentication forms and
    %   sensitive data entry in engineering UIs.
    %
    %   Example:
    %       p = ic.Password();
    %       p.Placeholder = "Enter password...";
    %       addlistener(p, 'Submitted', @(~,e) authenticate(e.Data.value));
    %
    %   Events:
    %       ValueChanged - Fires on every keystroke with current value
    %       Submitted    - Fires when Enter is pressed

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current text value of the password input
        Value string = ""
        % > PLACEHOLDER placeholder text when input is empty
        Placeholder string = ""
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"
        % > SIZE size of the input
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the input is disabled
        Disabled logical = false
        % > READONLY whether the input is read-only
        Readonly logical = false
        % > INVALID whether the input is in an invalid state
        Invalid logical = false
        % > ERRORMESSAGE error message displayed below the input when invalid
        ErrorMessage string = ""
        % > HELPERTEXT helper text displayed below the input
        HelperText string = ""
        % > SHOWTOGGLE whether to show the visibility toggle button
        ShowToggle logical = true
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires on every keystroke with current value
        ValueChanged
        % > SUBMITTED fires when Enter key is pressed
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
            % > FOCUS programmatically focus the input
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % > BLUR programmatically blur (unfocus) the input
            out = this.publish("blur", []);
        end

        function out = selectAll(this)
            % > SELECTALL select all text in the input
            out = this.publish("selectAll", []);
        end

        function out = clear(this)
            % > CLEAR clear the input value
            out = this.publish("clear", []);
        end
    end
end

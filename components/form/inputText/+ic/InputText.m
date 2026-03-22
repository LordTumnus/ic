classdef InputText < ic.core.Component
    % > INPUTTEXT Single-line text input field.
    %
    %   Text input with optional prefix/suffix labels, validation states,
    %   and clearable functionality. Designed for engineering UIs where
    %   inputs often display units (Hz, dB, ms) or labels alongside values.
    %
    %   Example:
    %       t = ic.InputText();
    %       t.Value = "Hello";
    %       t.Placeholder = "Enter value...";
    %       t.Suffix = "Hz";
    %
    %   Events:
    %       ValueChanged - Fires on every keystroke with current value
    %       Submitted    - Fires when Enter is pressed

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current text value of the input
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
        % > PREFIX text or symbol displayed before the input (e.g. "$", "#")
        Prefix string = ""
        % > SUFFIX text or symbol displayed after the input (e.g. "Hz", "dB", "ms")
        Suffix string = ""
        % > CLEARABLE whether to show a clear button when input has value
        Clearable logical = false
        % > MAXLENGTH maximum number of characters allowed (0 = unlimited)
        MaxLength double {mustBeNonnegative, mustBeInteger} = 0
        % > SHOWCOUNTER whether to display character count (requires MaxLength > 0)
        ShowCounter logical = false
        % > TYPE HTML input type attribute
        Type string {mustBeMember(Type, ...
            ["text", "email", "url", "tel", "search"])} = "text"
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires on every keystroke with current value
        ValueChanged
        % > SUBMITTED fires when Enter key is pressed
        Submitted
    end

    methods
        function this = InputText(props)
            arguments
                props.?ic.InputText
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

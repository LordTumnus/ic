classdef TextArea < ic.core.Component
    % > TEXTAREA Multi-line text input field.
    %
    %   A resizable text area for multi-line text input. Supports validation
    %   states, character counting, and auto-resize to fit content.
    %   Submit with Ctrl+Enter (Cmd+Enter on Mac).
    %
    %   Example:
    %       t = ic.TextArea();
    %       t.Value = "Hello World";
    %       t.Placeholder = "Enter description...";
    %       t.Rows = 6;
    %       t.AutoResize = true;
    %
    %   Events:
    %       ValueChanged - Fires on every keystroke with current value
    %       Submitted    - Fires on Ctrl+Enter / Cmd+Enter

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current text value of the textarea
        Value string = ""
        % > PLACEHOLDER placeholder text when textarea is empty
        Placeholder string = ""
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"
        % > SIZE size of the textarea (affects font size and padding)
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the textarea is disabled
        Disabled logical = false
        % > READONLY whether the textarea is read-only
        Readonly logical = false
        % > INVALID whether the textarea is in an invalid state
        Invalid logical = false
        % > ERRORMESSAGE error message displayed below the textarea when invalid
        ErrorMessage string = ""
        % > HELPERTEXT helper text displayed below the textarea
        HelperText string = ""
        % > ROWS number of visible text rows
        Rows double {mustBePositive, mustBeInteger} = 4
        % > RESIZE resize behavior of the textarea
        Resize string {mustBeMember(Resize, ...
            ["vertical", "horizontal", "both", "none"])} = "vertical"
        % > AUTORESIZE whether the textarea auto-grows to fit content
        AutoResize logical = false
        % > MAXLENGTH maximum number of characters allowed (0 = unlimited)
        MaxLength double {mustBeNonnegative, mustBeInteger} = 0
        % > SHOWCOUNTER whether to display character count (requires MaxLength > 0)
        ShowCounter logical = false
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires on every keystroke with current value
        ValueChanged
        % > SUBMITTED fires on Ctrl+Enter / Cmd+Enter
        Submitted
    end

    methods
        function this = TextArea(props)
            arguments
                props.?ic.TextArea
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the textarea
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % > BLUR programmatically blur (unfocus) the textarea
            out = this.publish("blur", []);
        end

        function out = selectAll(this)
            % > SELECTALL select all text in the textarea
            out = this.publish("selectAll", []);
        end

        function out = clear(this)
            % > CLEAR clear the textarea value
            out = this.publish("clear", []);
        end
    end
end

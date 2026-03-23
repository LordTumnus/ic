classdef InputText < ic.core.Component
    % single-line text input field with optional prefix/suffix, validation, and character counter

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current text content
        Value string = ""

        % ghost text when displayed on an empty input
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

        % whether the input is in an invalid state. When true, the input box will be styled with error colors and the #ic.InputText.ErrorMessage will be displayed if set.
        Invalid logical = false

        % error message displayed below the input when invalid
        ErrorMessage string = ""

        % helper text displayed below the input
        HelperText string = ""

        % text or symbol displayed before the input
        Prefix string = ""

        % text or symbol displayed after the input
        Suffix string = ""

        % whether to show a clear button on the sinput box to remove the contents
        Clearable logical = false

        % maximum number of characters allowed (0 = unlimited)
        MaxLength double {mustBeNonnegative, mustBeInteger} = 0

        % whether to display character count (requires #ic.InputText.MaxLength to be defined different from 0)
        ShowCounter logical = false

        % HTML input type attribute
        Type string {mustBeMember(Type, ...
            ["text", "email", "url", "tel", "search"])} = "text"
    end

    events (Description = "Reactive")
        % triggered when the value changes on user input
        ValueChanged

        % fires when the Enter key is pressed
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
            % programmatically focus the input
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % programmatically blur (unfocus) the input
            out = this.publish("blur", []);
        end

        function out = selectAll(this)
            % select all text the in the input
            out = this.publish("selectAll", []);
        end

        function out = clear(this)
            % remove all text from the input
            out = this.publish("clear", []);
        end
    end
end

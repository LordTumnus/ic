classdef TextArea < ic.core.Component
    % multi-line text input field.
    % Supports validation states, character counting, and auto-resize to fit content

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current text value of the textarea
        Value string = ""

        % ghost placeholder text when textarea is empty
        Placeholder string = ""

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"

        % dimension of the textarea relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether the textarea is disabled and cannot be interacted with
        Readonly logical = false

        % whether the textarea is in an invalid state, which will trigger error styling and display the #ic.TextArea.ErrorMessage
        Invalid logical = false

        % error message displayed below the textarea when #ic.TextArea.Invalid is true
        ErrorMessage string = ""

        % additional text displayed below the textarea
        HelperText string = ""

        % number of visible text rows
        Rows double {mustBePositive, mustBeInteger} = 4

        % resize behavior of the textarea
        Resize string {mustBeMember(Resize, ...
            ["vertical", "horizontal", "both", "none"])} = "vertical"

        % whether the textarea auto-grows to fit content, increasing the number of rows as it needs
        AutoResize logical = false

        % maximum number of characters allowed (0 for unlimited)
        MaxLength double {mustBeNonnegative, mustBeInteger} = 0

        % whether to display the character count. It requires #ic.TextArea.MaxLength to be set to a positive integer to show the count of current/total characters.
        ShowCounter logical = false
    end

    events (Description = "Reactive")
        % triggered when the current value changes
        ValueChanged

        % fires on Ctrl+Enter / Cmd+Enter
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
            % programmatically focus the textarea
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % programmatically blur (unfocus) the textarea
            out = this.publish("blur", []);
        end

        function out = selectAll(this)
            % select all text in the textarea
            out = this.publish("selectAll", []);
        end

        function out = clear(this)
            % clear the textarea value
            out = this.publish("clear", []);
        end
    end
end

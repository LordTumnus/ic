classdef CodeEditor < ic.core.Component
    % code editor with syntax highlighting. Powered by [CodeMirror 6](https://codemirror.net/)
    % Supports Matlab, JavaScript, Markdown, CSS, Typst, LaTeX, and plain (no highlighting) text languages. The editor can be configured with features like line numbers, line wrapping, bracket matching, code folding, multiple selections, and more,

    properties (SetObservable, AbortSet, Description = "Reactive")
        % editor text content
        Value string = ""

        % syntax language for highlighting
        Language string {mustBeMember(Language, ["matlab", "javascript", "markdown", "css", "typst", "latex", "plain"])} = "matlab"

        % editor heigh, as a pixel value or a CSS string
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % display alternating line backgrounds. The amount of lines between stripes can be configured with #ic.CodeEditor.ZebraStripeStep
        ZebraStripes logical = false

        % whether to show line numbers in the gutter
        LineNumbers logical = true

        % enable wrapping long lines onto multiple visual lines
        LineWrapping logical = false

        % whether to highlight the line with the cursor
        HighlightActiveLine logical = true

        % whether the user is blocked from interacting with the editor
        ReadOnly logical = false

        % number of white spaces per tab stop
        TabSize double {mustBePositive, mustBeInteger} = 4

        % ghost text shown when the editor is empty
        Placeholder string = ""

        % editor font size in pixels (0 for default)
        FontSize double {mustBeNonnegative} = 0

        % whether to highlight the matching bracket of the one next to the cursor
        BracketMatching logical = true

        % display code folds in the gutter and enable fold commands
        CodeFolding logical = false

        % open the search panel. Can also be triggered by Ctrl+F / Cmd+F when the editor is focused
        ShowSearch logical = false

        % highlight other occurrences of selected text
        HighlightSelectionMatches logical = false

        % automatically close brackets and quotes after typing the opening character
        CloseBrackets logical = false

        % whether to allow multiple cursors for editing multiple selections at once
        AllowMultipleSelections logical = false

        % amount of lines between stripes
        ZebraStripeStep double {mustBePositive, mustBeInteger} = 2

        % line numbers locked from editing. Adding new lines above or below will adjust the line numbers accordingly, so the user will not be able to directly edit these lines
        UneditableLines double {mustBeNonnegative, mustBeInteger} = []

        % line numbers with a highlighted background
        HighlightedLines double {mustBeNonnegative, mustBeInteger} = []

        % column positions for vertical ruler lines
        Rulers double {mustBeNonnegative, mustBeInteger} = []

        % whether to show vertical indent guide lines on code blocks
        IndentGuides logical = false

        % allow scrolling beyond the last line
        ScrollPastEnd logical = false

        % display a custom status bar at the bottom of the editor showing the current cursor position and the editor language
        ShowStatusBar logical = true
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.CodeEditor, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % total number of lines in the document
        LineCount double = 0

        % current cursor line
        CursorLine double = 1

        % current cursor column
        CursorColumn double = 1

        % number of active selections
        SelectionCount double = 1
    end

    events (Description = "Reactive")
        % triggered when the document content changes
        ValueChanged

        % fires when the cursor or selection moves
        SelectionChanged

        % fires when the editor gains or loses focus
        FocusChanged
    end

    methods
        function this = CodeEditor(props)
            arguments
                props.?ic.CodeEditor
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % give keyboard focus to the editor
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % remove keyboard focus from the editor
            out = this.publish("blur", []);
        end

        function out = gotoLine(this, line)
            % move the cursor to the beginning of the specified line
            arguments
                this
                % line number to move the cursor to
                line (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("gotoLine", line);
        end

        function out = setSelection(this, fromLine, fromCol, toLine, toCol)
            % set the cursorselection range (square like - fromLine:fromCol to toLine:toCol)
            arguments
                this
                % starting line number of the selection
                fromLine (1,1) double {mustBePositive, mustBeInteger}
                % starting column number of the selection
                fromCol (1,1) double {mustBePositive, mustBeInteger}
                % ending line number of the selection
                toLine (1,1) double {mustBePositive, mustBeInteger}
                % ending column number of the selection
                toCol (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("setSelection", [fromLine, fromCol, toLine, toCol]);
        end

        function out = getSelection(this)
            % get the text in the current selection
            out = this.publish("getSelection", []);
        end

        function out = replaceSelection(this, text)
            % replace the contents of the current selection with text
            arguments
                this
                % replacement text for the current selection
                text (1,1) string
            end
            out = this.publish("replaceSelection", text);
        end

        function out = undo(this)
            % undo the last edit. Can be triggered by Ctrl+Z / Cmd+Z when the editor is focused
            out = this.publish("undo", []);
        end

        function out = redo(this)
            % redo the last undone edit. Can be triggered by Ctrl+Y / Cmd+Shift+Z when the editor is focused
            out = this.publish("redo", []);
        end

        function out = foldAll(this)
            % fold all collapsible blocks of code
            out = this.publish("foldAll", []);
        end

        function out = unfoldAll(this)
            % unfold all collapsed blocks of code
            out = this.publish("unfoldAll", []);
        end

        function out = scrollToLine(this, line)
            % scroll the viewport the specified line
            arguments
                this
                % line number to scroll to
                line (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("scrollToLine", line);
        end
    end
end

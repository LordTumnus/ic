classdef CodeEditor < ic.core.Component
    % > CODEEDITOR Source code editor with syntax highlighting.

    %   Powered by CodeMirror 6 with Lezer parsers. Supports MATLAB,
    %   JavaScript, Markdown, CSS, and plain text.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE editor text content
        Value string = ""
        % > LANGUAGE syntax language: "matlab", "javascript", "markdown", "css", "plain"
        Language string {mustBeMember(Language, ["matlab", "javascript", "markdown", "css", "plain"])} = "matlab"
        % > READONLY make the entire editor read-only
        ReadOnly logical = false
        % > HEIGHT editor height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"
        % > LINENUMBERS show line number gutter
        LineNumbers logical = true
        % > LINEWRAPPING soft-wrap long lines
        LineWrapping logical = false
        % > HIGHLIGHTACTIVELINE highlight the cursor line
        HighlightActiveLine logical = true
        % > TABSIZE spaces per tab stop
        TabSize double {mustBePositive, mustBeInteger} = 4
        % > PLACEHOLDER ghost text when the editor is empty
        Placeholder string = ""
        % > FONTSIZE override font size in pixels (0 = inherit from theme)
        FontSize double {mustBeNonnegative} = 0
        % > BRACKETMATCHING highlight matching brackets
        BracketMatching logical = true
        % > CODEFOLDING enable fold gutter and fold commands
        CodeFolding logical = false
        % > SHOWSEARCH open the search panel
        ShowSearch logical = false
        % > HIGHLIGHTSELECTIONMATCHES highlight other occurrences of selected text
        HighlightSelectionMatches logical = false
        % > CLOSEBRACKETS auto-close brackets and quotes
        CloseBrackets logical = false
        % > ALLOWMULTIPLESELECTIONS allow multiple cursors
        AllowMultipleSelections logical = false
        % > ZEBRASTRIPES alternating line backgrounds
        ZebraStripes logical = false
        % > ZEBRASTRIPESTEP lines between stripes
        ZebraStripeStep double {mustBePositive, mustBeInteger} = 2
        % > UNEDITABLELINES 1-based line numbers locked from editing
        UneditableLines double {mustBeNonnegative, mustBeInteger} = []
        % > HIGHLIGHTEDLINES 1-based line numbers to highlight with color
        HighlightedLines double {mustBeNonnegative, mustBeInteger} = []
        % > RULERS column positions for vertical ruler lines
        Rulers double {mustBeNonnegative, mustBeInteger} = []
        % > INDENTGUIDES show vertical indent guide lines
        IndentGuides logical = false
        % > SCROLLPASTEND allow scrolling beyond the last line
        ScrollPastEnd logical = false
        % > SHOWSTATUSBAR show bottom bar with cursor position and language
        ShowStatusBar logical = true
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.CodeEditor, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % > LINECOUNT total number of lines in the document (read-only)
        LineCount double = 0
        % > CURSORLINE current cursor line, 1-based (read-only)
        CursorLine double = 1
        % > CURSORCOLUMN current cursor column, 1-based (read-only)
        CursorColumn double = 1
        % > SELECTIONCOUNT number of active selections (read-only)
        SelectionCount double = 1
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the document content changes
        ValueChanged
        % > SELECTIONCHANGED fires when the cursor or selection moves
        SelectionChanged
        % > FOCUSCHANGED fires when the editor gains or loses focus
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
            % > FOCUS give keyboard focus to the editor
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % > BLUR remove keyboard focus from the editor
            out = this.publish("blur", []);
        end

        function out = gotoLine(this, line)
            % > GOTOLINE jump cursor to the specified line
            arguments
                this
                line (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("gotoLine", line);
        end

        function out = setSelection(this, fromLine, fromCol, toLine, toCol)
            % > SETSELECTION set the selection range (1-based line and column)
            arguments
                this
                fromLine (1,1) double {mustBePositive, mustBeInteger}
                fromCol  (1,1) double {mustBePositive, mustBeInteger}
                toLine   (1,1) double {mustBePositive, mustBeInteger}
                toCol    (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("setSelection", [fromLine, fromCol, toLine, toCol]);
        end

        function out = getSelection(this)
            % > GETSELECTION get the currently selected text
            out = this.publish("getSelection", []);
        end

        function out = replaceSelection(this, text)
            % > REPLACESELECTION replace the current selection with text
            arguments
                this
                text (1,1) string
            end
            out = this.publish("replaceSelection", text);
        end

        function out = undo(this)
            % > UNDO undo the last edit
            out = this.publish("undo", []);
        end

        function out = redo(this)
            % > REDO redo the last undone edit
            out = this.publish("redo", []);
        end

        function out = foldAll(this)
            % > FOLDALL fold all collapsible regions
            out = this.publish("foldAll", []);
        end

        function out = unfoldAll(this)
            % > UNFOLDALL unfold all collapsed regions
            out = this.publish("unfoldAll", []);
        end

        function out = scrollToLine(this, line)
            % > SCROLLTOLINE scroll the specified line into view
            arguments
                this
                line (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("scrollToLine", line);
        end
    end
end

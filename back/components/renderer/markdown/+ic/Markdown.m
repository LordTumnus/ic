classdef Markdown < ic.core.Component
    % > MARKDOWN Renders Markdown text as formatted HTML.
    %
    %   md = ic.Markdown(Value="# Hello World")
    %   md = ic.Markdown(Value="**bold** and _italic_", Height=400)
    %
    % Extensions are lazy-loaded on demand. Each toggle property controls
    % whether its plugin is active. Disabled plugins are never fetched,
    % keeping the base bundle small.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE markdown source text
        Value string = ""

        % > HEIGHT container height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % > LINEWRAPPING soft-wrap long lines vs horizontal scroll
        LineWrapping (1,1) logical = true

        % > SANITIZE strip raw HTML tags when true (safer)
        Sanitize (1,1) logical = true

        % ── Extension toggles ──────────────────────────────────────────

        % > CODEHIGHLIGHT syntax highlighting in fenced code blocks
        CodeHighlight (1,1) logical = true

        % > MATH KaTeX math rendering: $inline$ and $$block$$
        Math (1,1) logical = false

        % > TASKLISTS GitHub-style task lists: - [x] done
        TaskLists (1,1) logical = true

        % > FOOTNOTES footnote syntax: [^1]
        Footnotes (1,1) logical = true

        % > SUBSUPERSCRIPT subscript H~2~O and superscript x^2^
        SubSuperscript (1,1) logical = true

        % > EMOJI emoji shortcodes: :smile: → 😄
        Emoji (1,1) logical = true

        % > CONTAINERS admonition blocks: :::warning
        Containers (1,1) logical = true

        % > MARK highlighted text: ==marked==
        Mark (1,1) logical = true
    end

    methods
        function this = Markdown(props)
            arguments
                props.?ic.Markdown
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end

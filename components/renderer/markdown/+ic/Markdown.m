classdef Markdown < ic.core.Component & ic.mixin.Requestable
    % renders Markdown text as formatted HTML using [markdown-it v14](https://github.com/markdown-it/markdown-it).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % markdown source text
        Value string = ""

        % height of the container, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % whether to soft-wrap long lines (false = horizontal scroll)
        LineWrapping (1,1) logical = true

        % whether to strip raw HTML tags from the rendered output
        Sanitize (1,1) logical = true

        % syntax highlighting in fenced code blocks (uses [highlight.js v11](https://highlightjs.org/))
        CodeHighlight (1,1) logical = true

        % [KaTeX v0.16](https://katex.org/) math rendering: $inline$ and $$block$$
        Math (1,1) logical = false

        % GitHub-style task lists: - [x] done  (uses [markdown-it-task-lists](https://github.com/revin/markdown-it-task-lists) internally)
        TaskLists (1,1) logical = true

        % footnote syntax: [^1]  (uses [markdown-it-footnote](https://github.com/markdown-it/markdown-it-footnote) internally)
        Footnotes (1,1) logical = true

        % subscript H~2~O and superscript x^2^  (uses [markdown-it-sub](https://github.com/markdown-it/markdown-it-sub) and [markdown-it-sup](https://github.com/markdown-it/markdown-it-sup) internally)
        SubSuperscript (1,1) logical = true

        % emoji shortcodes: :smile: → 😄  (uses [markdown-it-emoji](https://github.com/markdown-it/markdown-it-emoji) internally)
        Emoji (1,1) logical = true

        % admonition blocks: :::warning  (uses [markdown-it-container](https://github.com/markdown-it/markdown-it-container) internally)
        Containers (1,1) logical = true

        % highlighted text: ==marked==  (uses [markdown-it-mark](https://github.com/markdown-it/markdown-it-mark) internally)
        Mark (1,1) logical = true

        % definition list syntax: Term\n: Definition  (uses [markdown-it-deflist](https://github.com/markdown-it/markdown-it-deflist) internally)
        DefinitionLists (1,1) logical = true

        % abbreviation tooltips: *[HTML]: Hyper Text Markup Language  (uses [markdown-it-abbr](https://github.com/markdown-it/markdown-it-abbr))
        Abbreviations (1,1) logical = true

        % underlined/inserted text: ++inserted++  (uses [markdown-it-ins](https://github.com/markdown-it/markdown-it-ins) internally)
        Insert (1,1) logical = true

        % auto-generate id anchors on headings  (uses [markdown-it-anchor](https://github.com/valeriangalliat/markdown-it-anchor) internally)
        HeadingAnchors (1,1) logical = true

        % custom classes/attributes: {.class #id attr=val}  (uses [markdown-it-attrs](https://github.com/arve0/markdown-it-attrs) internally)
        Attributes (1,1) logical = false

        % render a table of contents via [[toc]]  (uses [markdown-it-table-of-contents](https://www.npmjs.com/package/markdown-it-table-of-contents) internally)
        TableOfContents (1,1) logical = false

        % render ```mermaid code blocks as diagrams (uses [Mermaid.js v10](https://mermaid.js.org/) internally)
        Mermaid (1,1) logical = false
    end

    methods
        function this = Markdown(props)
            arguments
                props.?ic.Markdown
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.onRequest("FetchImage", @(comp, data) comp.handleFetchImage(data));
            this.onRequest("OpenLink", @(comp, data) comp.handleOpenLink(data));
        end
    end

    methods (Access = private)
        function result = handleOpenLink(~, data)
            url = string(data.url);
            web(url, '-browser');
            result = true;
        end

        function result = handleFetchImage(~, data)
            src = string(data.url);

            % read bytes, URL or local file
            if startsWith(src, "http://") || startsWith(src, "https://")
                opts = weboptions('ContentType', 'binary', 'Timeout', 10);
                bytes = webread(src, opts);
            else
                % local file path
                bytes = fileread(src, Encoding="bytes");
            end

            % detect MIME from extension
            [~, ~, ext] = fileparts(src);
            ext = lower(extractBefore(ext + "?", "?")); % strip query params
            mimeMap = dictionary( ...
                ".png",  "image/png", ...
                ".jpg",  "image/jpeg", ...
                ".jpeg", "image/jpeg", ...
                ".gif",  "image/gif", ...
                ".svg",  "image/svg+xml", ...
                ".webp", "image/webp", ...
                ".bmp",  "image/bmp", ...
                ".ico",  "image/x-icon", ...
                ".tif",  "image/tiff", ...
                ".tiff", "image/tiff");
            if mimeMap.isKey(ext)
                mime = mimeMap(ext);
            else
                mime = "image/png";
            end

            b64 = matlab.net.base64encode(bytes);
            result = struct('dataUri', "data:" + mime + ";base64," + b64);
        end
    end
end

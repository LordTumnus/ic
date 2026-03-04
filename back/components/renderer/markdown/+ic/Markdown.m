classdef Markdown < ic.core.Component & ic.mixin.Requestable
    % > MARKDOWN Renders Markdown text as formatted HTML.
    %
    %   md = ic.Markdown(Value="# Hello World")
    %   md = ic.Markdown(Value="**bold** and _italic_", Height=400)
    %
    % Extensions are lazy-loaded on demand. Each toggle property controls
    % whether its plugin is active. Disabled plugins are never fetched,
    % keeping the base bundle small.
    %
    % Images referenced by URL or local file path are fetched by MATLAB
    % and delivered as base64 data URIs (the embedded browser blocks
    % external resources and local file access).

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

        % > DEFINITIONLISTS definition list syntax: Term\n: Definition
        DefinitionLists (1,1) logical = true

        % > ABBREVIATIONS abbreviation tooltips: *[HTML]: Hyper Text Markup Language
        Abbreviations (1,1) logical = true

        % > INSERT underlined/inserted text: ++inserted++
        Insert (1,1) logical = true

        % > HEADINGANCHORS auto-generate id anchors on headings
        HeadingAnchors (1,1) logical = true

        % > ATTRIBUTES custom classes/attributes: {.class #id attr=val}
        Attributes (1,1) logical = false

        % > TABLEOFCONTENTS render a table of contents via [[toc]]
        TableOfContents (1,1) logical = false
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

            % Read bytes — URL or local file
            if startsWith(src, "http://") || startsWith(src, "https://")
                opts = weboptions('ContentType', 'binary', 'Timeout', 10);
                bytes = webread(src, opts);
            else
                % Local file path
                bytes = fileread(src, Encoding="bytes");
            end

            % Detect MIME from extension
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

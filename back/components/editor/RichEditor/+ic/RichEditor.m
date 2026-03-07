classdef RichEditor < ic.core.Component & ic.mixin.Requestable
    % > RICHEDITOR WYSIWYG rich-text editor powered by TipTap.
    %
    %   r = ic.RichEditor()
    %   r = ic.RichEditor(Value="<p>Hello <strong>world</strong></p>")
    %   r = ic.RichEditor(Placeholder="Start typing...", Height=400)
    %
    % Full-featured document editor with toolbar, bubble menu, slash
    % commands, table of contents, callout blocks, collapsible sections,
    % math rendering (KaTeX), and syntax-highlighted code blocks.
    %
    % Images referenced by URL are fetched by MATLAB and delivered as
    % base64 data URIs (the embedded browser blocks external resources).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE HTML content
        Value string = ""

        % > HEIGHT container height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % > READONLY non-editable mode
        ReadOnly (1,1) logical = false

        % > PLACEHOLDER ghost text when editor is empty
        Placeholder string = ""

        % > DISABLED fully disabled state
        Disabled (1,1) logical = false

        % > SHOWTOOLBAR show/hide the fixed top toolbar
        ShowToolbar (1,1) logical = true

        % > SHOWTOC show/hide the table of contents sidebar
        ShowToc (1,1) logical = true

        % > FOCUSMODE iA Writer-style focus mode (dim non-active blocks)
        FocusMode (1,1) logical = false

        % > MAXLENGTH character limit (Inf = unlimited)
        MaxLength (1,1) double {mustBePositive} = Inf
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.RichEditor, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % > WORDCOUNT total word count (read-only, frontend-updated)
        WordCount (1,1) double = 0

        % > CHARACTERCOUNT total character count (read-only, frontend-updated)
        CharacterCount (1,1) double = 0

        % > ISFOCUSED whether the editor has keyboard focus (read-only)
        IsFocused (1,1) logical = false
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when content changes (debounced ~300ms)
        ValueChanged

        % > FOCUSCHANGED fires when focus state changes
        FocusChanged

        % > SUBMITTED fires on Ctrl+Enter / Cmd+Enter
        Submitted
    end

    methods
        function this = RichEditor(props)
            arguments
                props.?ic.RichEditor
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.onRequest("FetchImage",  @(comp, data) comp.handleFetchImage(data));
            this.onRequest("OpenLink",    @(comp, data) comp.handleOpenLink(data));
            this.onRequest("BrowseImage", @(comp, ~)    comp.handleBrowseImage());
            this.onRequest("SavePdf",     @(comp, data) comp.handleSavePdf(data));
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

        function out = clear(this)
            % > CLEAR clear all editor content
            out = this.publish("clear", []);
        end

        function out = insertContent(this, html)
            % > INSERTCONTENT insert HTML at the current cursor position
            arguments
                this
                html (1,1) string
            end
            out = this.publish("insertContent", html);
        end

        function out = getMarkdown(this)
            % > GETMARKDOWN convert current content to Markdown
            out = this.publish("getMarkdown", []);
        end

        function out = exportPdf(this, filepath)
            % > EXPORTPDF export editor content as a PDF file
            %   exportPdf()          — opens a save dialog
            %   exportPdf(filepath)  — writes directly to the given path
            arguments
                this
                filepath (1,1) string = ""
            end
            out = this.publish("exportPdf", filepath);
        end
    end

    methods (Access = private)
        function result = handleOpenLink(~, data)
            url = string(data.url);
            web(url, '-browser');
            result = true;
        end

        function result = handleBrowseImage(~)
            [file, folder] = uigetfile( ...
                {'*.png;*.jpg;*.jpeg;*.gif;*.svg;*.webp;*.bmp;*.tif;*.tiff', ...
                 'Image Files'}, ...
                'Select Image');
            if isequal(file, 0)
                % User cancelled
                result = [];
                return
            end
            src = fullfile(folder, file);

            % Read the file and return as data URI
            bytes = fileread(src, Encoding="bytes");
            [~, ~, ext] = fileparts(src);
            ext = lower(ext);
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

        function result = handleSavePdf(~, data)
            filepath = string(data.filepath);

            % No filepath provided — open save dialog
            if filepath == ""
                [f, p] = uiputfile('*.pdf', 'Export as PDF');
                if isequal(f, 0)
                    result = struct('saved', false);
                    return
                end
                filepath = fullfile(p, f);
            end

            % Decode base64 and write to file
            bytes = matlab.net.base64decode(string(data.base64));
            fid = fopen(filepath, 'wb');
            if fid == -1
                error('ic:RichEditor:FileError', ...
                    'Cannot open file for writing: %s', filepath);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, bytes);

            result = struct('saved', true, 'filepath', filepath);
        end

        function result = handleFetchImage(~, data)
            src = string(data.url);

            % Read bytes - URL or local file
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

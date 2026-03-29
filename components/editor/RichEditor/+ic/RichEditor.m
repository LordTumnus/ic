classdef RichEditor < ic.core.Component & ic.mixin.Requestable
    % rich wysiwyg text editor powered by [TipTap](https://tiptap.dev/).
    % Use the toolbar or markdown syntax for formatting.
    % Type a slash (/) to see the list of available content blocks, including headings, lists, tables, callouts, and more.
    % Equations (inside $...$ or $$...$$) are rendered using [KaTeX](https://katex.org/).
    % Code blocks support syntax highlighting for many programming languages.
    % Links will be automatically detected and can be opened in the system web browser. Images can be inserted from the local file system or by pasting a URL, and will be fetched by MatLab and embedded as base64-encoded data URIs.


    properties (SetObservable, AbortSet, Description = "Reactive")
        % content of the editor as an HTML string
        Value string = ""

        % > container height, in pixels or as a CSS string
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % whether the user is blocked from editing the content
        ReadOnly (1,1) logical = false

        % ghost text displayed when editor is empty
        Placeholder string = ""

        % disable interaction and impede focus
        Disabled (1,1) logical = false

        % show/hide the fixed top toolbar with the most common formatting options
        ShowToolbar (1,1) logical = true

        % show/hide the table of contents on the sidebar
        ShowToc (1,1) logical = true

        % when enabled, the editor will dim all but the current line or block to help focus
        FocusMode (1,1) logical = false

        % content character limit (Inf = unlimited)
        MaxLength (1,1) double {mustBePositive} = Inf
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.RichEditor, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % total word count
        WordCount (1,1) double = 0

        % total character count
        CharacterCount (1,1) double = 0

        % whether the editor has keyboard focus
        IsFocused (1,1) logical = false
    end

    events (Description = "Reactive")
        % triggered when content change
        ValueChanged

        % fires when focus state changes
        FocusChanged

        % triggered when the user submits the editor content (Ctrl+Enter / Cmd+Enter)
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
            % give keyboard focus to the editor
            out = this.publish("focus", []);
        end

        function out = blur(this)
            % remove keyboard focus from the editor
            out = this.publish("blur", []);
        end

        function out = clear(this)
            % clear all editor content
            out = this.publish("clear", []);
        end

        function out = insertContent(this, html)
            % insert HTML at the current cursor position
            arguments
                this
                % HTML string to insert at the current cursor position
                html (1,1) string
            end
            out = this.publish("insertContent", html);
        end

        function out = getMarkdown(this)
            % convert current content to Markdown
            % {returns} an #ic.Promise that resolves to the Markdown string {/returns}
            out = this.publish("getMarkdown", []);
        end

        function out = exportPdf(this, filepath)
            % export the editor content as a PDF file. If a filepath is provided, the PDF will be saved to that location. If no filepath is provided, a save dialog will prompt the user to choose a location.
            arguments
                this
                filepath (1,1) string = ""
            end
            out = this.publish("exportPdf", filepath);
        end
    end

    methods (Access = private)
        function result = handleOpenLink(~, data)
            % open a link in the system web browser
            url = string(data.url);
            web(url, '-browser');
            result = true;
        end

        function result = handleBrowseImage(~)
            % open a file dialog to select an image and return as ic.Asset.
            [file, folder] = uigetfile( ...
                {'*.png;*.jpg;*.jpeg;*.gif;*.svg;*.webp;*.bmp;*.tif;*.tiff', ...
                 'Image Files'}, ...
                'Select Image');
            if isequal(file, 0)
                result = [];
                return
            end
            result = struct('asset', ic.Asset(fullfile(folder, file)));
        end

        function result = handleSavePdf(~, data)
            % save the provided base64-encoded PDF content to a file. Will open a save dialog if no filepath is provided.
            filepath = string(data.filepath);

            % open save dialog
            if filepath == ""
                [f, p] = uiputfile('*.pdf', 'Export as PDF');
                if isequal(f, 0)
                    result = struct('saved', false);
                    return
                end
                filepath = fullfile(p, f);
            end

            % decode base64 and write to file
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
            % resolve an image URL or local file path as an ic.Asset.
            result = struct('asset', ic.Asset(string(data.url)));
        end
    end
end

classdef Typst < ic.core.Component & ic.mixin.Requestable
    % > TYPST Renders Typst markup as formatted SVG pages.
    %
    %   t = ic.Typst(Value="= Hello Typst" + newline + "This is a #emph[test].")
    %   t = ic.Typst(Value="#lorem(500)", Height=600)
    %
    % Uses Typst's default page layout (A4). Control pagination with
    % #set page(...) rules in the markup, or via PageWidth/PageHeight
    % properties. All compilation happens client-side via WASM.
    %
    % Export to PDF:
    %   t.exportPdf("output.pdf")   % saves PDF to file

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE Typst source text
        Value string = ""

        % > HEIGHT container height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % > TOOLBARONHOVER show zoom/export toolbar on mouse hover
        ToolbarOnHover (1,1) logical = true

        % > PAGEWIDTH Typst page width (e.g. "210mm", "8.5in"); empty = Typst default
        PageWidth string = ""

        % > PAGEHEIGHT Typst page height (e.g. "297mm", "11in"); empty = Typst default
        PageHeight string = ""

        % > PAGEMARGIN Typst page margin (e.g. "1cm", "(x: 1cm, y: 2cm)")
        PageMargin string = ""

        % > FONTSIZE base font size (e.g. "11pt", "14pt")
        FontSize string = ""

        % > FONTFAMILY font family name (must be available in the WASM renderer)
        FontFamily string = ""

        % > PAGEGAP vertical gap between rendered pages in pixels
        PageGap (1,1) double {mustBeNonnegative} = 16

        % > PACKAGES Typst universe packages to load (future, no-op in v1)
        %   Example: ["@preview/cetz:0.3.4", "@preview/fletcher:0.5.0"]
        Packages (1,:) string = string.empty
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.Typst, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % > NUMPAGES total number of rendered pages (read-only, set by frontend)
        NumPages (1,1) double = 0
    end

    events (Description = "Reactive")
        % > COMPILED fires after successful compilation
        Compiled

        % > ERROR fires when compilation fails
        Error
    end

    methods
        function this = Typst(props)
            arguments
                props.?ic.Typst
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.onRequest("SavePdf", @(comp, data) comp.handleSavePdf(data));
            this.onRequest("OpenLink", @(~, data) ic.Typst.handleOpenLink(data));
            this.onRequest("ResolveImages", @(~, data) ic.Typst.handleResolveImages(data));
        end
    end

    methods (Description = "Reactive")
        function out = zoomIn(this)
            % > ZOOMIN increase zoom level by one step
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % > ZOOMOUT decrease zoom level by one step
            out = this.publish("zoomOut", []);
        end

        function out = resetView(this)
            % > RESETVIEW reset to initial zoom level
            out = this.publish("resetView", []);
        end

        function out = scrollToPage(this, pageNum)
            % > SCROLLTOPAGE scroll to a specific page number
            arguments
                this
                pageNum (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("scrollToPage", pageNum);
        end

        function out = exportPdf(this, filepath)
            % > EXPORTPDF compile to PDF and save to file
            %   t.exportPdf("output.pdf")
            %   t.exportPdf()              % opens save dialog
            arguments
                this
                filepath (1,1) string = ""
            end
            out = this.publish("exportPdf", filepath);
        end
    end

    methods (Access = private, Static)
        function result = handleOpenLink(data)
            url = string(data.url);
            web(url, '-browser');
            result = true;
        end

        function result = handleResolveImages(data)
            % Resolve image files requested by the Typst WASM compiler.
            % Inlines file I/O, hashing, and MIME (Asset helpers are private).
            paths = string(data.paths);
            outPaths = string.empty;
            outAssets = {};
            outErrors = {};

            for i = 1:numel(paths)
                p = paths(i);
                try
                    if startsWith(p, "http://") || startsWith(p, "https://")
                        [~, ~, ext] = fileparts(p);
                        ext = regexprep(ext, '\?.*$', '');
                        tmpFile = string(tempname) + ext;
                        websave(tmpFile, p);
                        c = onCleanup(@() delete(tmpFile));
                        fid = fopen(tmpFile, 'rb');
                        raw = fread(fid, Inf, '*uint8');
                        fclose(fid);
                    elseif isfile(p)
                        fid = fopen(p, 'rb');
                        raw = fread(fid, Inf, '*uint8');
                        fclose(fid);
                        [~, ~, ext] = fileparts(p);
                    else
                        resolved = fullfile(pwd, p);
                        if ~isfile(resolved), continue; end
                        fid = fopen(resolved, 'rb');
                        raw = fread(fid, Inf, '*uint8');
                        fclose(fid);
                        [~, ~, ext] = fileparts(resolved);
                    end

                    % Hash (pure-MATLAB fingerprint)
                    d = double(uint8(raw(:)));
                    n = numel(d);
                    s1 = mod(sum(d .* mod((1:n)', 65521)), 2^52);
                    s2 = mod(sum(d .* mod((1:n)' * 31, 65497)), 2^52);
                    hash = sprintf('%x%013x%013x', n, s1, s2);

                    % MIME from extension
                    mimeMap = dictionary( ...
                        [".svg",".png",".jpg",".jpeg",".gif",".bmp",".webp"], ...
                        ["image/svg+xml","image/png","image/jpeg","image/jpeg", ...
                         "image/gif","image/bmp","image/webp"]);
                    ext = lower(ext);
                    if isKey(mimeMap, ext)
                        mime = mimeMap(ext);
                    else
                        mime = "application/octet-stream";
                    end

                    outPaths(end+1) = p;                            %#ok<AGROW>
                    outAssets{end+1} = struct( ...                   %#ok<AGROW>
                        'hash', hash, ...
                        'mime', mime, ...
                        'data', matlab.net.base64encode(raw));
                catch ME
                    outErrors{end+1} = struct( ...          %#ok<AGROW>
                        'path', p, ...
                        'message', ME.message);
                    continue
                end
            end

            result = struct();
            result.paths = outPaths;
            result.assets = outAssets;
            result.errors = outErrors;
        end
    end

    methods (Access = private)
        function result = handleSavePdf(~, data)
            filepath = string(data.filepath);

            % No filepath provided — open save dialog
            if filepath == ""
                [f, p] = uiputfile('*.pdf', 'Export Typst as PDF');
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
                error('ic:Typst:FileError', ...
                    'Cannot open file for writing: %s', filepath);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, bytes);

            result = struct('saved', true, 'filepath', filepath);
        end
    end
end

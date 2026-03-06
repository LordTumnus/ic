classdef Latex < ic.core.Component & ic.mixin.Requestable
    % > LATEX Renders LaTeX markup as formatted PDF pages.
    %
    % Compilation happens client-side via SwiftLaTeX's PdfTeX WASM engine.
    % Packages are bundled locally (no internet required).
    %
    % BUNDLED PACKAGES
    %
    %   Math:
    %     amsmath, amssymb, amsfonts, amsthm, amstext, amscd, amsxtra,
    %     mathtools, bm, centernot, eucal, eufrak, euscript, xfrac
    %
    %   Document Structure:
    %     geometry, fancyhdr, enumitem, booktabs, float, setspace, parskip,
    %     longtable, multicol, tabularx, caption, subcaption, rotating,
    %     lscape, indentfirst, varioref, xr
    %
    %   Graphics & Color:
    %     tikz (+ pgf, shapes.geometric, positioning, arrows libraries),
    %     graphicx, xcolor, epstopdf-base
    %
    %   Code Listings:
    %     listings (+ lstlang1, lstlang2, lstlang3 language definitions)
    %
    %   References & Links:
    %     hyperref, nameref, url, backref, xr-hyper
    %
    %   Utilities:
    %     etoolbox, calc, ifthen, xparse, expl3, keyval, array,
    %     verbatim, shortvrb, showkeys, makeidx, xspace, theorem
    %
    %   Document Classes:
    %     article, report, book, letter, proc, slides
    %
    % NOTE: Packages not listed above are NOT available. If compilation
    % fails with "File 'xxx.sty' not found", the package is not bundled.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE LaTeX source text
        Value string = ""

        % > HEIGHT container height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % > TOOLBARONHOVER show zoom/export toolbar on mouse hover
        ToolbarOnHover (1,1) logical = true

        % > PAGEGAP vertical gap between rendered pages in pixels
        PageGap (1,1) double {mustBeNonnegative} = 16

        % > RENDERONCHANGE automatically render when Value changes (default true)
        RenderOnChange (1,1) logical = true
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.Latex, ?ic.mixin.Reactive}, ...
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
        function this = Latex(props)
            arguments
                props.?ic.Latex
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.onRequest("SavePdf", @(comp, data) comp.handleSavePdf(data));
            this.onRequest("OpenLink", @(~, data) ic.Latex.handleOpenLink(data));
            this.onRequest("ResolveImages", @(~, data) ic.Latex.handleResolveImages(data));
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
            % > EXPORTPDF save the compiled PDF to file
            %   l.exportPdf("output.pdf")
            %   l.exportPdf()              % opens save dialog
            arguments
                this
                filepath (1,1) string = ""
            end
            out = this.publish("exportPdf", filepath);
        end

        function out = render(this)
            % > RENDER trigger a render of the current Value
            out = this.publish("render", []);
        end
    end

    methods (Access = private, Static)
        function result = handleOpenLink(data)
            url = string(data.url);
            web(url, '-browser');
            result = true;
        end

        function result = handleResolveImages(data)
            % Resolve image files requested by the LaTeX WASM compiler.
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
                [f, p] = uiputfile('*.pdf', 'Export LaTeX as PDF');
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
                error('ic:Latex:FileError', ...
                    'Cannot open file for writing: %s', filepath);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, bytes);

            result = struct('saved', true, 'filepath', filepath);
        end
    end
end

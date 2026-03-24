classdef Latex < ic.core.Component & ic.mixin.Requestable
    % renders LaTeX markup as formatted PDF pages.
    % Compilation happens client-side via [SwiftLaTeX](https://www.swiftlatex.com/)'s PdfTeX WASM engine (no internet required). Images referenced in the source are resolved by MATLAB and embedded as a binary #ic.asset.Asset
    %
    % bundled packages:
    %   - math: amsmath, amssymb, mathtools, bm, xfrac, eucal, eufrak
    %   - structure: geometry, fancyhdr, enumitem, booktabs, multicol, tabularx, caption, subcaption, longtable, lscape
    %   - graphics: tikz (+pgf, shapes, positioning, arrows), graphicx, xcolor
    %   - listings: listings (+lstlang1/2/3)
    %   - refs: hyperref, nameref, url, backref
    %   - utils: etoolbox, calc, xparse, expl3, verbatim, makeidx
    %   - classes: article, report, book, letter, proc, slides
    %
    % packages not in this list are not available and compilation will fail with "File 'xxx.sty' not found"

    properties (SetObservable, AbortSet, Description = "Reactive")
        % source text that will be compiled as LaTeX
        Value string = ""

        % height of the container, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % whether to show the zoom/export toolbar on mouse hover
        ToolbarOnHover (1,1) logical = true

        % vertical gap between rendered pages, in pixels
        PageGap (1,1) double {mustBeNonnegative} = 16

        % whether to automatically re-render when Value changes
        RenderOnChange (1,1) logical = true
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.Latex, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % total number of rendered pages (set by the view after compilation)
        NumPages (1,1) double = 0
    end

    events (Description = "Reactive")
        % fires after successful compilation
        % {payload}
        % value | struct: compilation result — value.numPages (double) is the page count
        % {/payload}
        Compiled

        % fires when compilation fails
        % {payload}
        % value | struct: error details — value.message (char) is the error message
        % {/payload}
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
            % increase zoom level by one step
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % decrease zoom level by one step
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("zoomOut", []);
        end

        function out = resetView(this)
            % reset to initial zoom level
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("resetView", []);
        end

        function out = scrollToPage(this, pageNum)
            % scroll to a specific page number
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            arguments
                this
                % page number to scroll to
                pageNum (1,1) double {mustBePositive, mustBeInteger}
            end
            out = this.publish("scrollToPage", pageNum);
        end

        function out = exportPdf(this, filepath)
            % save the compiled PDF to a file, or open a save dialog if no path is given
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            % {example}
            %   l.exportPdf("output.pdf")  % save to path
            %   l.exportPdf()              % open save dialog
            % {/example}
            arguments
                this
                % destination file path; omit to open a save dialog
                filepath (1,1) string = ""
            end
            out = this.publish("exportPdf", filepath);
        end

        function out = render(this)
            % trigger a render of the current Value
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
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
            % resolve image files requested by the LaTeX WASM compiler.
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

                    % hash (pure-MATLAB fingerprint)
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

            % no filepath provided — open save dialog
            if filepath == ""
                [f, p] = uiputfile('*.pdf', 'Export LaTeX as PDF');
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
                error('ic:Latex:FileError', ...
                    'Cannot open file for writing: %s', filepath);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, bytes);

            result = struct('saved', true, 'filepath', filepath);
        end
    end
end

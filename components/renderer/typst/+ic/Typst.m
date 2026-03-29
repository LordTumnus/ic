classdef Typst < ic.core.Component & ic.mixin.Requestable
    % renders [Typst](https://typst.app/) markup as formatted SVG pages.
    % Compilation happens client-side via [typst.ts](https://github.com/Myriad-Dreamin/typst.ts) v0.7 WASM. [Typst Universe](https://typst.app/universe/) packages are downloaded by MATLAB on demand as they appear in the value. Images referenced in the source are resolved by MATLAB and embedded as binary #ic.Asset.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % Typst source text
        Value string = ""

        % height of the container, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % whether to show the zoom/export toolbar on mouse hover
        ToolbarOnHover (1,1) logical = true

        % Typst page width override (e.g. "210mm", "8.5in"); empty = Typst default
        PageWidth string = ""

        % Typst page height override (e.g. "297mm", "11in"); empty = Typst default
        PageHeight string = ""

        % Typst page margin override (e.g. "1cm", "(x: 1cm, y: 2cm)")
        PageMargin string = ""

        % base font size override (e.g. "11pt", "14pt")
        FontSize string = ""

        % font family name override (must be available in the WASM renderer)
        FontFamily string = ""

        % vertical gap between rendered pages, in pixels
        PageGap (1,1) double {mustBeNonnegative} = 16

        % [Typst Universe](https://typst.app/universe/) packages to pre-load, as version-pinned spec strings (e.g. "@preview/cetz:0.3.4").
        % {note} Packages referenced via #import in the source are detected automatically; use this property for transitive dependencies or pre-warming. {/note}
        Packages (1,:) string = string.empty

        % whether to automatically re-render when Value changes
        RenderOnChange (1,1) logical = true
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.Typst, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % total number of rendered pages (set by the view after compilation)
        NumPages (1,1) double = 0
    end

    properties (Access = private)
        PackageCache  % containers.Map: "ns/name/ver" → base64 tar.gz string
        PackageDeps   % containers.Map: "ns/name/ver" → cell of dep structs
    end

    events (Description = "Reactive")
        % fires after successful compilation
        % {payload}
        % value | struct: compilation result. value.numPages (double) is the page count
        % {/payload}
        Compiled

        % fires when compilation fails
        % {payload}
        % value | struct: error details. value.message (char) is the error message
        % {/payload}
        Error
    end

    methods
        function this = Typst(props)
            arguments
                props.?ic.Typst
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.PackageCache = containers.Map('KeyType', 'char', 'ValueType', 'char');
            this.PackageDeps = containers.Map('KeyType', 'char', 'ValueType', 'any');
            this.onRequest("SavePdf", @(comp, data) comp.handleSavePdf(data));
            this.onRequest("OpenLink", @(~, data) ic.Typst.handleOpenLink(data));
            this.onRequest("ResolveImages", @(~, data) ic.Typst.handleResolveImages(data));
            this.onRequest("ResolvePackages", @(comp, data) comp.handleResolvePackages(data));
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
            % compile to PDF and save to a file, or open a save dialog if no path is given
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            % {example}
            %   t.exportPdf("output.pdf")  % save to path
            %   t.exportPdf()              % open save dialog
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
        function deps = scanImportsFromTarGz(tarGzFile)
            % Extract a tar.gz and scan .typ files for #import "@ns/pkg:ver".
            % Returns a cell array of structs with namespace, name, version.
            tmpDir = string(tempname);
            mkdir(tmpDir);
            cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));
            untar(tarGzFile, tmpDir);

            typFiles = dir(fullfile(tmpDir, '**', '*.typ'));
            deps = {};
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

            for i = 1:numel(typFiles)
                content = fileread( ...
                    fullfile(typFiles(i).folder, typFiles(i).name));
                tokens = regexp(content, ...
                    '#import\s+"@([^/]+)/([^:]+):([^"]+)"', 'tokens');
                for j = 1:numel(tokens)
                    t = tokens{j};
                    key = char(string(t{1}) + "/" + ...
                        string(t{2}) + "/" + string(t{3}));
                    if ~seen.isKey(key)
                        seen(key) = true;
                        deps{end+1} = struct( ...             %#ok<AGROW>
                            'namespace', t{1}, ...
                            'name', t{2}, ...
                            'version', t{3});
                    end
                end
            end
        end

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
        function result = handleResolvePackages(this, data)
            % Resolve Typst universe packages including transitive deps.
            % Downloads tar.gz from the CDN, scans .typ files for #import
            % statements, and recursively resolves dependencies.
            specs = data.specs;
            if ~iscell(specs), specs = {specs}; end

            [outSpecs, outTarballs, outErrors] = ...
                this.resolvePackageTree(specs);

            result = struct();
            result.specs = outSpecs;
            result.tarballs = outTarballs;
            result.errors = outErrors;
        end

        function [outSpecs, outTarballs, outErrors] = ...
                resolvePackageTree(this, initialSpecs)
            % BFS resolution of packages and their transitive dependencies.
            MAX_DEPTH = 5;
            resolved = containers.Map('KeyType', 'char', 'ValueType', 'char');
            outErrors = {};

            queue = initialSpecs;
            for depth = 1:MAX_DEPTH
                if isempty(queue), break; end
                nextQueue = {};

                for i = 1:numel(queue)
                    s = queue{i};
                    ns  = string(s.namespace);
                    name = string(s.name);
                    ver  = string(s.version);
                    key  = char(ns + "/" + name + "/" + ver);

                    if resolved.isKey(key), continue; end

                    % MATLAB-side cache hit
                    if this.PackageCache.isKey(key)
                        resolved(key) = this.PackageCache(key);
                        % Queue known transitive deps
                        if this.PackageDeps.isKey(key)
                            deps = this.PackageDeps(key);
                            for j = 1:numel(deps)
                                dk = char(string(deps{j}.namespace) + "/" + ...
                                    string(deps{j}.name) + "/" + ...
                                    string(deps{j}.version));
                                if ~resolved.isKey(dk)
                                    nextQueue{end+1} = deps{j}; %#ok<AGROW>
                                end
                            end
                        end
                        continue
                    end

                    try
                        url = sprintf( ...
                            'https://packages.typst.org/%s/%s-%s.tar.gz', ...
                            ns, name, ver);
                        tmpFile = string(tempname) + ".tar.gz";
                        cleanupFile = onCleanup(@() delete(tmpFile));
                        websave(tmpFile, url);

                        fid = fopen(tmpFile, 'rb');
                        raw = fread(fid, Inf, '*uint8')';
                        fclose(fid);

                        b64 = matlab.net.base64encode(raw);
                        this.PackageCache(key) = b64;
                        resolved(key) = b64;

                        % Scan for transitive deps
                        deps = ic.Typst.scanImportsFromTarGz(tmpFile);
                        this.PackageDeps(key) = deps;
                        for j = 1:numel(deps)
                            dk = char(string(deps{j}.namespace) + "/" + ...
                                string(deps{j}.name) + "/" + ...
                                string(deps{j}.version));
                            if ~resolved.isKey(dk)
                                nextQueue{end+1} = deps{j}; %#ok<AGROW>
                            end
                        end
                    catch ME
                        outErrors{end+1} = struct( ...         %#ok<AGROW>
                            'spec', key, ...
                            'message', ME.message);
                    end
                end

                queue = nextQueue;
            end

            % Build parallel output arrays
            keys = resolved.keys();
            n = numel(keys);
            outSpecs = cell(n, 1);
            outTarballs = cell(n, 1);
            for i = 1:n
                parts = strsplit(keys{i}, '/');
                outSpecs{i} = struct( ...
                    'namespace', parts{1}, ...
                    'name', parts{2}, ...
                    'version', parts{3});
                outTarballs{i} = resolved(keys{i});
            end
        end

        function result = handleSavePdf(~, data)
            filepath = string(data.filepath);

            % No filepath provided: open save dialog
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

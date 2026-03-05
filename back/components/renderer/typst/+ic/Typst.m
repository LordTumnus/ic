classdef Typst < ic.core.Component & ic.mixin.Requestable
    % > TYPST Renders Typst markup as formatted SVG pages.
    %
    %   t = ic.Typst(Value="= Hello Typst" + newline + "This is a #emph[test].")
    %   t = ic.Typst(Value="#lorem(500)", Mode="document", Height=600)
    %
    % Two rendering modes:
    %   "auto"     — content-hugging, no page breaks (formulas, snippets)
    %   "document" — paginated A4 pages with gaps (full documents)
    %
    % All compilation happens client-side via WASM. No external
    % dependencies or network access required.
    %
    % Export to PDF:
    %   t.exportPdf("output.pdf")   % saves PDF to file
    %
    % Typst page/font settings can be configured via properties or
    % embedded directly in the markup using #set rules.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE Typst source text
        Value string = ""

        % > HEIGHT container height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % > MODE rendering mode: "auto" (content-hugging) or "document" (paginated)
        Mode (1,1) string {mustBeMember(Mode, ["auto", "document"])} = "auto"

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

        % > PAGEGAP vertical gap between rendered pages in pixels (document mode)
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
            % > SCROLLTOPAGE scroll to a specific page (document mode)
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

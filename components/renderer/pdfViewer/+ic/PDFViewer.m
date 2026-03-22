classdef PDFViewer < ic.core.Component
    % > PDFVIEWER Displays a PDF document with zoom and page navigation.
    %
    %   viewer = ic.PDFViewer(Value="report.pdf")
    %   viewer = ic.PDFViewer(Value="https://example.com/doc.pdf", ToolbarMode="hover")

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE PDF source (file path or URL)
        Value ic.asset.Asset {ic.assets.mustBePdf} = ic.asset.Asset()
        % > TOOLBARMODE controls display mode: "toolbar" (fixed top bar) or "hover" (floating on hover)
        ToolbarMode string {mustBeMember(ToolbarMode, ["toolbar", "hover"])} = "toolbar"
        % > SHOWZOOMCONTROLS show zoom in/out buttons and zoom percentage
        ShowZoomControls logical = true
        % > SHOWPAGECONTROLS show page navigation buttons and page indicator
        ShowPageControls logical = true
        % > SHOWFITBUTTON show fit-to-width button
        ShowFitButton logical = true
        % > SHOWROTATEBUTTON show rotate button
        ShowRotateButton logical = false
        % > PAGE current page number
        Page double {mustBePositive, mustBeInteger} = 1
        % > ZOOM zoom level in percent (100 = actual size)
        Zoom double {mustBePositive} = 100
        % > HEIGHT height of the viewer (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.PDFViewer, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % > NUMPAGES total number of pages in the document (read-only)
        NumPages double = 0
    end

    events (Description = "Reactive")
        % > PAGECHANGED fires when the user navigates to a different page
        PageChanged
        % > ZOOMCHANGED fires when the user changes the zoom level
        ZoomChanged
        % > LOADED fires when the PDF document has been loaded successfully
        Loaded
        % > ERROR fires when the PDF document fails to load
        Error
    end

    methods
        function this = PDFViewer(props)
            arguments
                props.?ic.PDFViewer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = nextPage(this)
            % > NEXTPAGE navigate to the next page
            out = this.publish("nextPage", []);
        end

        function out = previousPage(this)
            % > PREVIOUSPAGE navigate to the previous page
            out = this.publish("previousPage", []);
        end

        function out = zoomIn(this)
            % > ZOOMIN increase zoom level by 25%
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % > ZOOMOUT decrease zoom level by 25%
            out = this.publish("zoomOut", []);
        end

        function out = fitWidth(this)
            % > FITWIDTH fit the page width to the viewer width
            out = this.publish("fitWidth", []);
        end

        function out = fitPage(this)
            % > FITPAGE fit the entire page within the viewer
            out = this.publish("fitPage", []);
        end
    end
end

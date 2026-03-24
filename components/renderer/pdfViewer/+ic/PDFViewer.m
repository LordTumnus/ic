classdef PDFViewer < ic.core.Component
    % PDF viewer with zoom and page navigation controls, powered by [pdf.js v4](https://mozilla.github.io/pdf.js/).
    % Accepts a local file path or URL as #ic.PDFViewer.Value. The toolbar can be fixed or shown only on hover.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % PDF source as a file path or URL
        Value ic.asset.Asset {ic.assets.mustBePdf} = ic.asset.Asset()

        % toolbar display mode: "toolbar" (always visible) or "hover" (appears on mouse hover)
        ToolbarMode string {mustBeMember(ToolbarMode, ["toolbar", "hover"])} = "toolbar"

        % whether to show zoom in/out buttons and zoom percentage
        ShowZoomControls logical = true

        % whether to show page navigation buttons and page indicator
        ShowPageControls logical = true

        % whether to show the fit-to-width button
        ShowFitButton logical = true

        % whether to show the rotate button
        ShowRotateButton logical = false

        % current page number
        Page double {mustBePositive, mustBeInteger} = 1

        % zoom level as a percentage (100 = actual size)
        Zoom double {mustBePositive} = 100

        % height of the viewer, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize} = "100%"
    end

    properties (SetObservable, AbortSet, ...
            SetAccess = {?ic.PDFViewer, ?ic.mixin.Reactive}, ...
            Description = "Reactive")
        % total number of pages in the document (set by the view after loading)
        NumPages double = 0
    end

    events (Description = "Reactive")
        % fires when the user navigates to a different page
        % {payload}
        % value | double: the new page number
        % {/payload}
        PageChanged

        % fires when the user changes the zoom level
        % {payload}
        % value | double: the new zoom level as a percentage
        % {/payload}
        ZoomChanged

        % fires when the PDF document finishes loading
        % {payload}
        % numPages | double: total number of pages in the document
        % {/payload}
        Loaded

        % fires when the PDF document fails to load
        % {payload}
        % error | char: error message string
        % {/payload}
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
            % navigate to the next page
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("nextPage", []);
        end

        function out = previousPage(this)
            % navigate to the previous page
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("previousPage", []);
        end

        function out = zoomIn(this)
            % increase zoom level by 25%
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % decrease zoom level by 25%
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("zoomOut", []);
        end

        function out = fitWidth(this)
            % fit the page width to the viewer width
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("fitWidth", []);
        end

        function out = fitPage(this)
            % fit the entire page within the viewer
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("fitPage", []);
        end
    end
end

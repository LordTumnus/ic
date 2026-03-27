classdef Icon < ic.core.Component
    % Display an SVG icon read from an #ic.asset.Asset.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % icon asset source
        Source ic.asset.Asset {ic.assets.mustBeIcon} = ic.asset.Asset("info")

        % size of the icon, in pixels or CSS string. The size is applied to both the width and height of the icon
        Size {ic.check.CssValidators.mustBeSize} = 16

        % color of the icon, used for the stroke of line icons and the fill of solid icons. Can be any CSS color string. An empty string means to inherit the color from the parent container
        Color string = ""

        % stroke width for line icons, in pixels
        StrokeWidth double = 2
    end

    methods (Static)
        function names = list()
            % returns all available Lucide icon names.
            % {example}
            %   names = ic.Icon.list()           % all ~1900 icons
            %   names(contains(names, "arrow"))  % filter by keyword
            % {/example}
            iconsDir = fullfile(ic.Icon.lucideDir());
            files = dir(fullfile(iconsDir, "*.svg"));
            names = string({files.name});
            names = erase(names, ".svg");
            names = sort(names);
        end

        function browse()
            % opens the Lucide icon gallery in the browser.
            % {example}
            %   ic.Icon.browse()
            % {/example}
            web("https://lucide.dev/icons", "-browser");
        end

        function fig = gallery()
            % display all available Lucide icons in a paginated gallery.
            % {example}
            %   fig = ic.Icon.gallery()
            % {/example}

            fig = uifigure("Name", "Icon Gallery", ...
                "Position", [100 100 900 700], "Resize", "off");
            g = uigridlayout(fig, "ColumnWidth", {'1x'}, ...
                "RowHeight", {'1x'}, "Padding", [0 0 0 0]);
            f = ic.Frame("Parent", g);

            outer = ic.GridContainer( ...
                "Columns", "1fr", ...
                "Rows", "auto 1fr auto", ...
                "Gap", 0);
            outer.css.fill();
            f.addChild(outer);

            titleBar = ic.GridContainer( ...
                "Columns", "1fr", ...
                "Padding", [12 16 12 16]);
            titleBar.css.style(".ic-grid", ...
                "borderBottom", "1px solid var(--ic-border)");
            outer.addChild(titleBar);

            titleLbl = ic.Label( ...
                "Text", "Icon Gallery", ...
                "Variant", "heading", ...
                "Size", "lg");
            titleBar.addChild(titleLbl);

            iconGrid = ic.GridContainer( ...
                "Gap", 4, ...
                "Padding", 16, ...
                "AlignItems", "start", ...
                "JustifyItems", "center");
            iconGrid.css.fill();
            iconGrid.css.style(".ic-grid", ...
                "overflow", "hidden", ...
                "alignContent", "start");
            outer.addChild(iconGrid);

            footer = ic.GridContainer( ...
                "Columns", "auto 1fr auto", ...
                "Gap", 8, ...
                "Padding", [8 16 8 16], ...
                "AlignItems", "center", ...
                "JustifyItems", "center");
            footer.css.style(".ic-grid", ...
                "borderTop", "1px solid var(--ic-border)");
            outer.addChild(footer);

            prevBtn = ic.Button( ...
                "Label", "", ...
                "Fill", "ghost", ...
                "Size", "sm", ...
                "Icon", ic.Icon(Source="chevron-left"));

            footer.addChild(prevBtn);

            pageLbl = ic.Label( ...
                "Size", "sm", ...
                "Color", "muted", ...
                "Align", "center");
            footer.addChild(pageLbl);

            nextBtn = ic.Button( ...
                "Label", "", ...
                "Fill", "ghost", ...
                "Size", "sm", ...
                "Icon", ic.Icon(Source="chevron-right"));
            footer.addChild(nextBtn);

            % compute page size from figure dimensions
            figW = fig.Position(3);
            figH = fig.Position(4);
            gridPad = 16;
            tileW = 104;
            tileH = 58;
            barH = 44;

            cols = max(1, floor((figW - 2 * gridPad) / tileW));
            rows = max(1, floor((figH - 2 * barH - 2 * gridPad) / tileH));
            pageSize = cols * rows;

            iconGrid.Columns = sprintf("repeat(%d, 1fr)", cols);

            allNames = ic.Icon.list();
            totalPages = ceil(numel(allNames) / pageSize);
            currentPage = 1;

            loadPage(currentPage);

            % navigation callbacks
            addlistener(prevBtn, 'Clicked', @(~,~) navigate(-1));
            addlistener(nextBtn, 'Clicked', @(~,~) navigate(1));
            function navigate(direction)
                newPage = currentPage + direction;
                if newPage >= 1 && newPage <= totalPages
                    currentPage = newPage;
                    loadPage(currentPage);
                end
            end

            function loadPage(page)
                % load a page of icons into the grid

                kids = iconGrid.Children;
                if ~isempty(kids)
                    delete(kids);
                end
                startIdx = (page - 1) * pageSize + 1;
                endIdx = min(page * pageSize, numel(allNames));

                pageLbl.Text = sprintf("Page %d / %d  (%d icons)", ...
                    page, totalPages, numel(allNames));
                prevBtn.Disabled = (page == 1);
                nextBtn.Disabled = (page == totalPages);

                for i = startIdx:endIdx
                    % grid tile with icon and label
                    tile = ic.GridContainer( ...
                        "Columns", "1fr", ...
                        "Rows", "auto auto", ...
                        "Gap", 2, ...
                        "Padding", [8 4 8 4], ...
                        "JustifyItems", "center", ...
                        "AlignItems", "center");
                    tile.css.style(".ic-grid", ...
                        "borderRadius", "4px", ...
                        "cursor", "default");

                    icn = ic.Icon("Source", allNames(i), "Size", 22);
                    lbl = ic.Label( ...
                        "Text", allNames(i), ...
                        "Size", "xs", ...
                        "Color", "muted", ...
                        "Truncate", true, ...
                        "Align", "center");
                    lbl.css.fillWidth();

                    tile.addChild(icn);
                    tile.addChild(lbl);
                    iconGrid.addChild(tile);
                end
            end
        end
    end

    methods (Static, Access = private)
        function p = lucideDir()
            % locates the lucide-static icons directory relative to this file
            thisDir = fileparts(mfilename("fullpath"));
            p = fullfile(thisDir, "..", "..", "..", "..", ...
                "front", "node_modules", "lucide-static", "icons");
        end
    end

    methods
        function this = Icon(props)
            arguments
                props.?ic.Icon
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end

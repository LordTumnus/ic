classdef Icon < ic.core.Component
    % > ICON Displays an SVG icon.
    %
    %   icon = ic.Icon(Source="chevron-down")
    %   icon = ic.Icon(Source="path/to/icon.svg")
    %   icon = ic.Icon(Source="https://example.com/icon.svg")
    %
    % Browse: https://lucide.dev/icons

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SOURCE icon source (Lucide name, .svg file, or .svg URL)
        Source ic.asset.Asset {ic.assets.mustBeIcon} = ic.asset.Asset("info")
        % > SIZE size of the icon (width = height)
        Size {ic.check.CssValidators.mustBeSize} = 16
        % > COLOR color of the icon (CSS color string or empty for currentColor)
        Color string = ""
        % > STROKEWIDTH stroke width for line icons
        StrokeWidth double = 2
    end

    methods (Static)
        function names = list()
            % > LIST Return all available Lucide icon names.
            %   names = ic.Icon.list()           % all ~1900 icons
            %   names(contains(names, "arrow"))  % filter by keyword
            iconsDir = fullfile(ic.Icon.lucideDir());
            files = dir(fullfile(iconsDir, "*.svg"));
            names = string({files.name});
            names = erase(names, ".svg");
            names = sort(names);
        end

        function browse()
            % > BROWSE Open the Lucide icon gallery in the browser.
            %   ic.Icon.browse()
            web("https://lucide.dev/icons", "-browser");
        end

        function fig = gallery()
            % > GALLERY Display all available Lucide icons in a paginated gallery.
            %   fig = ic.Icon.gallery()
            %
            % Opens a uifigure with a responsive grid of Lucide icons.
            % Page size is computed to fill the grid exactly.

            fig = uifigure("Name", "Icon Gallery", ...
                "Position", [100 100 900 700], "Resize", "off");
            g = uigridlayout(fig, "ColumnWidth", {'1x'}, ...
                "RowHeight", {'1x'}, "Padding", [0 0 0 0]);

            % Create IC frame
            f = ic.Frame("Parent", g);

            % Outer layout: title | icons | footer
            outer = ic.GridContainer();
            outer.Columns = "1fr";
            outer.Rows = "auto 1fr auto";
            outer.Gap = 0;
            outer.css.fill();
            f.addChild(outer);

            % ── Title bar ──────────────────────────
            titleBar = ic.GridContainer();
            titleBar.Columns = "1fr";
            titleBar.Padding = [12 16 12 16];
            titleBar.style(".ic-grid", ...
                "borderBottom", "1px solid var(--ic-border)");
            outer.addChild(titleBar);

            titleLbl = ic.Label();
            titleLbl.Text = "Icon Gallery";
            titleLbl.Variant = "heading";
            titleLbl.Size = "lg";
            titleBar.addChild(titleLbl);

            % ── Icon grid ─────────────────────────
            iconGrid = ic.GridContainer();
            iconGrid.Gap = 4;
            iconGrid.Padding = 16;
            iconGrid.AlignItems = "start";
            iconGrid.JustifyItems = "center";
            iconGrid.css.fill();
            iconGrid.style(".ic-grid", ...
                "overflow", "hidden", ...
                "alignContent", "start");
            outer.addChild(iconGrid);

            % ── Footer bar ─────────────────────────
            footer = ic.GridContainer();
            footer.Columns = "auto 1fr auto";
            footer.Gap = 8;
            footer.Padding = [8 16 8 16];
            footer.AlignItems = "center";
            footer.JustifyItems = "center";
            footer.style(".ic-grid", ...
                "borderTop", "1px solid var(--ic-border)");
            outer.addChild(footer);

            prevBtn = ic.Button();
            prevBtn.Label = "";
            prevBtn.Fill = "ghost";
            prevBtn.Size = "sm";
            prevBtn.Icon = ic.Icon(Source="chevron-left");
            footer.addChild(prevBtn);

            pageLbl = ic.Label();
            pageLbl.Size = "sm";
            pageLbl.Color = "muted";
            pageLbl.Align = "center";
            footer.addChild(pageLbl);

            nextBtn = ic.Button();
            nextBtn.Label = "";
            nextBtn.Fill = "ghost";
            nextBtn.Size = "sm";
            nextBtn.Icon = ic.Icon(Source="chevron-right");
            footer.addChild(nextBtn);

            % ── Compute page size from figure dimensions ──
            figW = fig.Position(3);
            figH = fig.Position(4);
            gridPad = 16;
            tileW = 104;  % ~100px content + 4px gap
            tileH = 58;   % 22px icon + 2px gap + 14px label + 16px pad + 4px gap
            barH = 44;    % title / footer bar height estimate

            cols = max(1, floor((figW - 2 * gridPad) / tileW));
            rows = max(1, floor((figH - 2 * barH - 2 * gridPad) / tileH));
            pageSize = cols * rows;

            iconGrid.Columns = sprintf("repeat(%d, 1fr)", cols);

            % ── Pagination state ────────────────────
            allNames = ic.Icon.list();
            totalPages = ceil(numel(allNames) / pageSize);
            currentPage = 1;

            loadPage(currentPage);

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
                % Clear existing tiles
                kids = iconGrid.Children;
                if ~isempty(kids)
                    delete(kids);
                end

                % Page range
                startIdx = (page - 1) * pageSize + 1;
                endIdx = min(page * pageSize, numel(allNames));

                % Update footer
                pageLbl.Text = sprintf("Page %d / %d  (%d icons)", ...
                    page, totalPages, numel(allNames));
                prevBtn.Disabled = (page == 1);
                nextBtn.Disabled = (page == totalPages);

                % Add tiles for current page
                for i = startIdx:endIdx
                    tile = ic.GridContainer();
                    tile.Columns = "1fr";
                    tile.Rows = "auto auto";
                    tile.Gap = 2;
                    tile.Padding = [8 4 8 4];
                    tile.JustifyItems = "center";
                    tile.AlignItems = "center";
                    tile.style(".ic-grid", ...
                        "borderRadius", "4px", ...
                        "cursor", "default");

                    icn = ic.Icon(Source=allNames(i));
                    icn.Size = 22;
                    tile.addChild(icn);

                    lbl = ic.Label();
                    lbl.Text = allNames(i);
                    lbl.Size = "xs";
                    lbl.Color = "muted";
                    lbl.Truncate = true;
                    lbl.Align = "center";
                    lbl.css.fillWidth();
                    tile.addChild(lbl);

                    iconGrid.addChild(tile);
                end
            end
        end
    end

    methods (Static, Access = private)
        function p = lucideDir()
            % Locate the lucide-static icons directory relative to this file
            thisDir = fileparts(mfilename("fullpath"));
            p = fullfile(thisDir, "..", "..", "..", "..", "..", ...
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

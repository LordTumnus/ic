function MarketTracker()
% Crypto/stock ticker table with live price updates and trading terminal styling.

darkBg = [0.04 0.04 0.06];
fig = uifigure( ...
    "Name", "Market Tracker", ...
    "Position", [80 40 1500 900], ...
    "Color", darkBg);
gl = uigridlayout(fig, ...
    "RowHeight", {'1x'}, ...
    "ColumnWidth", {'1x'}, ...
    "Padding", [0 0 0 0], ...
    "BackgroundColor", darkBg);

frame = ic.Frame("Parent", gl);
frame.ColorScheme = "dark";
frame.Debug = true;
frame.css.style("", "backgroundColor", "#0a0a0f");

% +-----------------------------------------------+
% | Market Tracker     [Search...]  [Compact|Std] |
% +-----------------------------------------------+
% | #  | SYM | Name | Price | 24h% | Spark | ...  |
% |    |     |      |       |      |       |      |
% +-----------------------------------------------+

rootCol = ic.FlexContainer( ...
    "Direction", "column", ...
    "Gap", 0, ...
    "Padding", 0);
frame.addChild(rootCol);
rootCol.css.fill();

% header toolbar
headerRow = ic.FlexContainer( ...
    "Direction", "row", ...
    "Gap", 12, ...
    "Padding", [10 16], ...
    "AlignItems", "center");
rootCol.addChild(headerRow);

titleLabel = ic.Label( ...
    "Text", "Market Tracker", ...
    "Variant", "heading", ...
    "Size", "xl", ...
    "Weight", "bold");
headerRow.addChild(titleLabel);

spacer = ic.Label("Text", "");
headerRow.addChild(spacer);
spacer.css.style("> *", "flex", "1");

searchBar = ic.SearchBar( ...
    "Placeholder", "Filter tickers...", ...
    "Clearable", true, ...
    "Size", "sm");
headerRow.addChild(searchBar);
searchBar.css.style("> *", "flex", "1", "maxWidth", "300px");

sizeToggle = ic.SegmentedButton( ...
    "Items", ["Compact", "Standard", "Expanded"], ...
    "Value", "Standard", ...
    "Size", "sm");
headerRow.addChild(sizeToggle);

% table
tbl = ic.Table();
tbl.Striped = true;
tbl.Selectable = true;
tbl.ShowRowNumbers = true;
tbl.Size = "md";
rootCol.addChild(tbl);
tbl.css.fill();

% data
masterData = generateMarketData();

% column definitions
cols = [
    ic.table.ImageColumn("Logo", ...
        "Header", "", "Width", 36, "ObjectFit", "contain")

    ic.table.TextColumn("Symbol", ...
        "Pinned", "left", "Sortable", true, "Filterable", true, ...
        "Width", 85, "Transform", "uppercase")

    ic.table.TextColumn("Name", "Width", 140)

    ic.table.NumberColumn("Price", ...
        "Prefix", "$", "Decimals", 2, "ThousandsSeparator", true, ...
        "Sortable", true, "Width", 120)

    ic.table.NumberColumn("Change24h", ...
        "Header", "24h %", "Suffix", "%", "Decimals", 2, ...
        "Sortable", true, "Width", 95, ...
        "ColorRules", [ ...
            ic.table.ColorRule(">",  5,  "#22c55e")
            ic.table.ColorRule(">",  0,  "#4ade80")
            ic.table.ColorRule("<", -5,  "#ef4444")
            ic.table.ColorRule("<",  0,  "#f87171")])

    ic.table.SparklineColumn("Sparkline", ...
        "Header", "7d Trend", "Width", 130, ...
        "LineWidth", 1.5, "FillArea", true, "ShowEndDot", true, ...
        "Metric", "relative", ...
        "ColorRules", [ ...
            ic.table.ColorRule(">=", 0, "#4ade80")
            ic.table.ColorRule("<",  0, "#f87171")])

    ic.table.TextColumn("MarketCap", ...
        "Header", "Mkt Cap", "Width", 100, "Align", "right")

    ic.table.ProgressBarColumn("Volume", ...
        "Header", "Volume", "Min", 0, "Max", 100, ...
        "Variant", "primary", "Width", 110)

    ic.table.EnumColumn("Sector", ...
        "Filterable", true, "Width", 110, ...
        "Items",  ["Crypto", "Tech", "Finance", "Energy", "Healthcare"], ...
        "Colors", ["#f59e0b", "#3b82f6", "#10b981", "#eab308", "#ec4899"])

    ic.table.ProgressBarColumn("ATHRatio", ...
        "Header", "ATH %", "Min", 0, "Max", 100, ...
        "ShowLabel", true, "LabelFormat", "%d%%", ...
        "Variant", "success", "Width", 100, ...
        "ColorRules", [ ...
            ic.table.ColorRule(">=", 80, "#22c55e")
            ic.table.ColorRule(">=", 50, "#eab308")
            ic.table.ColorRule("<",  50, "#ef4444")])

    ic.table.BooleanColumn("Trending", "Header", "Hot", "Width", 60)

    ic.table.ColorColumn("BrandColor", "Header", "Brand", "Width", 70)
];

tbl.Columns = cols;
tbl.Data = masterData;

% ── styling — trading terminal theme ──────────────────────────────────

% header bar
headerRow.css.style("> *", ...
    "borderBottom", "1px solid #1e293b", ...
    "background", "#0c0d14");

titleLabel.css.style("> *", ...
    "color", "#e2e8f0", ...
    "textShadow", "0 0 20px rgba(59,130,246,0.3)");

% table header: dark + blue accent underline + monospace uppercase
tbl.css.style(".ic-tbl__header", ...
    "backgroundColor", "#0d0e14", ...
    "borderBottom", "2px solid #3b82f6");
tbl.css.style(".ic-tbl__hcell", ...
    "fontFamily", "'JetBrains Mono', 'Fira Code', 'Consolas', monospace", ...
    "fontSize", "10.5px", ...
    "textTransform", "uppercase", ...
    "letterSpacing", "0.6px", ...
    "color", "#e2e8f0");

% rows: monospace cells, white text, hover glow, selection accent
tbl.css.style(".ic-tbl__cell", ...
    "fontFamily", "'JetBrains Mono', 'Fira Code', 'Consolas', monospace", ...
    "fontSize", "12px", ...
    "color", "#e2e8f0");
tbl.css.style(".ic-tbl__row:hover", ...
    "backgroundColor", "rgba(59,130,246,0.06)");
tbl.css.style(".ic-tbl__row--selected", ...
    "backgroundColor", "rgba(59,130,246,0.12)", ...
    "boxShadow", "inset 3px 0 0 #3b82f6");
tbl.css.style(".ic-tbl__row--striped", ...
    "backgroundColor", "rgba(255,255,255,0.015)");

% pinned symbol column: subtle border
tbl.css.style(".ic-tbl__cell--pinned", "borderRight", "1px solid #1e293b");
tbl.css.style(".ic-tbl__hcell--sticking", "borderRight", "1px solid #1e293b");

% row number column
tbl.css.style(".ic-tbl__cell--rownum", "color", "#e2e8f0", "fontSize", "10px");

% price-flash keyframes: two identical pairs (a/b) so we can alternate
% names each tick to force the browser to re-trigger the animation
flashFrameUp = struct( ...
    "from", struct("boxShadow", "inset 0 0 12px rgba(34,197,94,0.5)"), ...
    "to",   struct("boxShadow", "inset 0 0 0 transparent"));
flashFrameDown = struct( ...
    "from", struct("boxShadow", "inset 0 0 12px rgba(239,68,68,0.5)"), ...
    "to",   struct("boxShadow", "inset 0 0 0 transparent"));
tbl.css.keyframes("flash-up-a",   flashFrameUp);
tbl.css.keyframes("flash-up-b",   flashFrameUp);
tbl.css.keyframes("flash-down-a", flashFrameDown);
tbl.css.keyframes("flash-down-b", flashFrameDown);

% track state for animation re-trigger
prevPrices = masterData.Price;
flashedSelectors = {};
flashTick = 0;

% ── event wiring ──────────────────────────────────────────────────────

% segmented button → table size
addlistener(sizeToggle, 'ValueChanged', @(~,e) onSizeChanged(e));

% search bar → filter rows
addlistener(searchBar, 'ValueChanged', @(~,e) onSearchChanged(e));

% row selection → toast
addlistener(tbl, 'SelectionChanged', @(~,e) onSelectionChanged(e));

% ── live price timer (2s tick) ────────────────────────────────────────

updateTimer = timer( ...
    "ExecutionMode", "fixedRate", ...
    "Period", 2, ...
    "TimerFcn", @(~,~) tickPrices());
start(updateTimer);

% clean up when figure closes
addlistener(fig, 'ObjectBeingDestroyed', @(~,~) cleanup());

% =====================================================================

function onSizeChanged(e)
    val = string(e.Data.value);
    switch val
        case "Compact",  tbl.Size = "sm";
        case "Standard", tbl.Size = "md";
        case "Expanded", tbl.Size = "lg";
    end
end

function onSearchChanged(e)
    applyFilter(e.Data.value);
end

function onSelectionChanged(e)
    sel = e.Data.selection;
    if ~strcmp(sel.type, "row") || isempty(sel.value)
        return;
    end
    rowIdx = sel.value(1);
    if rowIdx < 1 || rowIdx > height(tbl.Data), return; end
    row = tbl.Data(rowIdx, :);
    msg = sprintf("%s (%s)  —  $%s  |  %+.2f%%", ...
        row.Symbol, row.Name, formatPrice(row.Price), row.Change24h);
    t = ic.Toast("Value", msg, "Variant", "info", "Duration", 3, ...
        "Position", "bottom");
    frame.addChild(t);
end

function tickPrices()
    n = height(masterData);

    % snapshot prices before update
    oldPrices = masterData.Price;

    % small price perturbation ±0.5%
    pctChange = 0.005 * randn(n, 1);
    masterData.Price = masterData.Price .* (1 + pctChange);

    % shift 24h change slightly
    masterData.Change24h = masterData.Change24h + pctChange * 100 * 0.3;

    % roll sparkline: drop oldest, append new price
    for i = 1:n
        spark = masterData.Sparkline{i};
        masterData.Sparkline{i} = [spark(2:end), masterData.Price(i)];
    end

    % clear previous tick's flash selectors (required to re-trigger)
    for i = 1:numel(flashedSelectors)
        tbl.css.clearStyle(flashedSelectors{i});
    end

    applyFilter(searchBar.Value);

    % batch flash: collect row indices per direction, emit 2 calls via :is()
    direction = sign(masterData.Price - oldPrices);
    displayedSymbols = tbl.Data.Symbol;
    upRows = {};
    downRows = {};
    for i = 1:height(tbl.Data)
        mIdx = find(masterData.Symbol == displayedSymbols(i), 1);
        rowSel = sprintf(".ic-tbl__row[data-row-index='%d']", i - 1);
        if direction(mIdx) > 0
            upRows{end+1} = rowSel; %#ok<AGROW>
        elseif direction(mIdx) < 0
            downRows{end+1} = rowSel; %#ok<AGROW>
        end
    end

    % alternate a/b suffix so animation name always changes → forces re-trigger
    flashTick = flashTick + 1;
    if mod(flashTick, 2) == 0
        suffix = "-a";
    else
        suffix = "-b";
    end

    flashedSelectors = {};
    if ~isempty(upRows)
        sel = ":is(" + strjoin(string(upRows), ", ") + ") .ic-tbl__cell[data-field='Price']";
        tbl.css.style(sel, "animation", "flash-up" + suffix + " 0.6s ease-out");
        flashedSelectors{end+1} = sel;
    end
    if ~isempty(downRows)
        sel = ":is(" + strjoin(string(downRows), ", ") + ") .ic-tbl__cell[data-field='Price']";
        tbl.css.style(sel, "animation", "flash-down" + suffix + " 0.6s ease-out");
        flashedSelectors{end+1} = sel;
    end

    prevPrices = masterData.Price;
end

function applyFilter(tags)
    tags = string(tags);
    tags(tags == "" | ismissing(tags)) = [];

    if isempty(tags)
        tbl.Data = masterData;
        return;
    end

    mask = false(height(masterData), 1);
    for i = 1:numel(tags)
        mask = mask ...
            | contains(masterData.Symbol, tags(i), 'IgnoreCase', true) ...
            | contains(masterData.Name,   tags(i), 'IgnoreCase', true);
    end
    tbl.Data = masterData(mask, :);
end

function cleanup()
    stop(updateTimer);
    delete(updateTimer);
end

end % MarketTracker


function T = generateMarketData()

rng(42);

% 20 crypto + 30 stocks
Symbol = ["BTC","ETH","SOL","ADA","DOT","AVAX","LINK","MATIC","UNI","ATOM", ...
          "NEAR","FTM","ALGO","XRP","DOGE","SHIB","LTC","BCH","XLM","AAVE", ...
          "AAPL","MSFT","GOOGL","AMZN","NVDA","META","TSLA","JPM","V","JNJ", ...
          "WMT","PG","XOM","CVX","PFE","UNH","HD","BAC","DIS","NFLX", ...
          "CRM","AMD","INTC","CSCO","ORCL","ADBE","PYPL","SQ","COIN","ABNB"]';

Name = ["Bitcoin","Ethereum","Solana","Cardano","Polkadot","Avalanche","Chainlink","Polygon","Uniswap","Cosmos", ...
        "NEAR Protocol","Fantom","Algorand","Ripple","Dogecoin","Shiba Inu","Litecoin","Bitcoin Cash","Stellar","Aave", ...
        "Apple","Microsoft","Alphabet","Amazon","NVIDIA","Meta","Tesla","JPMorgan","Visa","Johnson & Johnson", ...
        "Walmart","Procter & Gamble","ExxonMobil","Chevron","Pfizer","UnitedHealth","Home Depot","Bank of America","Disney","Netflix", ...
        "Salesforce","AMD","Intel","Cisco","Oracle","Adobe","PayPal","Block","Coinbase","Airbnb"]';

Sector = [repmat("Crypto", 20, 1); ...
          repmat("Tech", 1, 1); repmat("Tech", 1, 1); repmat("Tech", 1, 1); ...
          repmat("Tech", 1, 1); repmat("Tech", 1, 1); repmat("Tech", 1, 1); ...
          repmat("Tech", 1, 1); ...
          "Finance"; "Finance"; ...
          "Healthcare"; ...
          "Tech"; "Healthcare"; ...
          "Energy"; "Energy"; ...
          "Healthcare"; "Healthcare"; ...
          "Tech"; "Finance"; ...
          "Tech"; "Tech"; ...
          "Tech"; "Tech"; "Tech"; "Tech"; "Tech"; "Tech"; ...
          "Finance"; "Finance"; ...
          "Finance"; "Tech"];

% realistic base prices
basePrices = [42150, 2530, 98, 0.45, 7.2, 34, 14.5, 0.85, 6.1, 9.8, ...
              4.2, 0.42, 0.18, 0.52, 0.08, 0.000012, 72, 235, 0.11, 92, ...
              178, 415, 141, 185, 880, 505, 245, 198, 280, 162, ...
              165, 158, 108, 155, 28, 525, 345, 35, 112, 625, ...
              265, 165, 32, 52, 125, 545, 62, 78, 225, 152]';

n = numel(Symbol);

% prices with ±5% random noise
Price = basePrices .* (1 + 0.05 * randn(n, 1));

% 24h change %
Change24h = 3 * randn(n, 1);

% 7-day sparklines (cell array of 7-point random walks)
Sparkline = cell(n, 1);
for i = 1:n
    steps = 1 + 0.02 * randn(1, 7);
    Sparkline{i} = Price(i) * cumprod(steps);
end

% market cap: compute raw then format as string
rawCap = Price .* (10.^(7 + 4*rand(n, 1)));
MarketCap = arrayfun(@formatMarketCap, rawCap);

% volume: raw then normalize 0-100
rawVol = 10.^(6 + 4*rand(n, 1));
Volume = 100 * rawVol / max(rawVol);

% ATH ratio: 40-100%
ATHRatio = 40 + randi(60, n, 1);

% trending flag
Trending = logical(randi([0 1], n, 1));

% brand colors
BrandColor = ["#F7931A","#627EEA","#9945FF","#0033AD","#E6007A","#E84142","#2A5ADA","#8247E5","#FF007A","#2E3148", ...
              "#00EC97","#1969FF","#000000","#0085C0","#C2A633","#FFA409","#345D9D","#4CC947","#0091FF","#B6509E", ...
              "#A2AAAD","#00A4EF","#4285F4","#FF9900","#76B900","#0668E1","#CC0000","#002D72","#1A1F71","#D51900", ...
              "#0071CE","#003DA5","#ED1B2F","#0060A9","#0093D0","#002855","#F96302","#012169","#0057B8","#E50914", ...
              "#00A1E0","#ED1C24","#0068B5","#049FD9","#C74634","#FF0000","#003087","#3E4348","#0052FF","#FF5A5F"]';

% logos — downloaded once to examples/assets/logos/, then served from disk
Logo = cell(n, 1);
logoFiles = downloadLogos(Symbol, BrandColor);
for i = 1:n
    if logoFiles(i) ~= ""
        Logo{i} = ic.asset.Asset(logoFiles(i));
    end
end

% build table, sort by market cap descending
T = table(Logo, Symbol, Name, Price, Change24h, Sparkline, MarketCap, Volume, Sector, ...
    ATHRatio, Trending, BrandColor);
[~, idx] = sort(rawCap, 'descend');
T = T(idx, :);

end


function str = formatMarketCap(val)
    if val >= 1e12
        str = sprintf("$%.1fT", val / 1e12);
    elseif val >= 1e9
        str = sprintf("$%.1fB", val / 1e9);
    elseif val >= 1e6
        str = sprintf("$%.0fM", val / 1e6);
    else
        str = sprintf("$%.0f", val);
    end
end


function str = formatPrice(val)
    if val >= 1000
        str = sprintf("%,.2f", val);
    elseif val >= 1
        str = sprintf("%.2f", val);
    elseif val >= 0.01
        str = sprintf("%.4f", val);
    else
        str = sprintf("%.6f", val);
    end
end


function files = downloadLogos(symbols, brandColors)
% Download ticker logos to examples/assets/logos/ (skips if already cached).
% Falls back to a colored-letter SVG for any symbol that can't be fetched.

assetsDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'assets', 'logos');
if ~isfolder(assetsDir), mkdir(assetsDir); end

cryptoBase = "https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/";
siBase = "https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/";

% map: symbol → {url, extension}
urlMap = containers.Map('KeyType','char','ValueType','any');
cryptoSyms = ["BTC","ETH","SOL","ADA","DOT","AVAX","LINK","MATIC","UNI","ATOM", ...
              "NEAR","FTM","ALGO","XRP","DOGE","SHIB","LTC","BCH","XLM","AAVE"];
for i = 1:numel(cryptoSyms)
    urlMap(cryptoSyms(i)) = {cryptoBase + lower(cryptoSyms(i)) + ".png", ".png"};
end

% stocks with known simple-icons slugs
stockMap = { ...
    "AAPL","apple"; "GOOGL","google"; "NVDA","nvidia"; "META","meta"; ...
    "TSLA","tesla"; "JPM","chase"; "V","visa"; "BAC","bankofamerica"; ...
    "NFLX","netflix"; "AMD","amd"; "INTC","intel"; "CSCO","cisco"; ...
    "PYPL","paypal"; "SQ","square"; "COIN","coinbase"; "ABNB","airbnb"};
for i = 1:size(stockMap,1)
    urlMap(stockMap{i,1}) = {siBase + stockMap{i,2} + ".svg", ".svg"};
end

n = numel(symbols);
files = strings(n, 1);
opts = weboptions('Timeout', 10);

for i = 1:n
    sym = char(symbols(i));
    dest = fullfile(assetsDir, string(sym) + ".svg");

    % use cached file if it exists and is non-empty
    if isfile(dest) && dir(dest).bytes > 0
        files(i) = dest;
        continue;
    end

    % try downloading from CDN
    downloaded = false;
    if urlMap.isKey(sym)
        info = urlMap(sym);
        url = info{1}; ext = info{2};
        destDl = fullfile(assetsDir, string(sym) + ext);
        try
            websave(destDl, url, opts);
            if dir(destDl).bytes > 0
                files(i) = destDl;
                downloaded = true;
            else
                delete(destDl);
            end
        catch
            if isfile(destDl), delete(destDl); end
        end
    end

    % fallback: generate white-letter SVG on transparent background
    if ~downloaded
        letter = sym(1);
        svg = sprintf(['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' ...
            '<text x="16" y="22.5" text-anchor="middle" font-family="system-ui,sans-serif" ' ...
            'font-weight="700" font-size="18" fill="white">%s</text></svg>'], ...
            letter);
        fid = fopen(dest, 'w'); fwrite(fid, svg); fclose(fid);
        files(i) = dest;
    end

    % recolor simple-icons SVGs (black paths → white)
    if downloaded && endsWith(files(i), ".svg")
        raw = fileread(files(i));
        if ~contains(raw, 'fill="white"')
            raw = strrep(raw, '<path', '<path fill="white"');
            fid = fopen(files(i), 'w'); fwrite(fid, raw); fclose(fid);
        end
    end
end

end

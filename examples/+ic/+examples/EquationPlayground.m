function EquationPlayground()
% interactive math explorer with 3D surface plot and live LaTeX preview

% build the figure with two frames: one for controls, one for status bar
fig = uifigure( ...
    "Name", "Equation Playground", ...
    "Position", [100 100 1400 850]);
gl = uigridlayout(fig, ...
    "RowHeight", {'1x', 'fit'}, ...
    "ColumnWidth", {'3x', '1x'}, ...
    "Padding", [0 0 5 0], ...
    "ColumnSpacing", 0, ...
    "RowSpacing", 0);

% native axes for 3D surface (left cell)
ax = uiaxes(gl);
ax.Layout.Row = 1; ax.Layout.Column = 1;
xlabel(ax, 'x'); ylabel(ax, 'y'); zlabel(ax, 'z');
ax.Box = 'on';
view(ax, -37.5, 30);

% right frame for tile layout controls
rightGl = uigridlayout(gl, ...
    "RowHeight", {'1x'}, ...
    "ColumnWidth", {'1x'}, ...
    "Padding", [0 0 0 0]);
rightGl.Layout.Row = 1;
rightGl.Layout.Column = 2;
rightFrame = ic.Frame("Parent", rightGl);
rightFrame.css.style(" *", "fontSize", "14px");
rightFrame.css.style(" .ic-tc__label", "fontSize", "16px");
rightFrame.css.style(" .ic-ac__label", "fontSize", "15px");

% bottom frame for status bar (spans both columns)
bottomGl = uigridlayout(gl, ...
    "RowHeight", {20}, ...
    "ColumnWidth", {'1x'}, ...
    "Padding", [0 0 0 0]);
bottomGl.Layout.Row = 2;
bottomGl.Layout.Column = [1 2];
bottomFrame = ic.Frame("Parent", bottomGl);

% state
currentExpr = "a * sin(x) .* cos(y)";
varNames = ["a", "b", "c"];
varValues = [1, 1, 1];
xRange = [-5, 5];
yRange = [-5, 5];
zRange = [-2, 2];
resolution = 50;
surfHandle = []; %#ok
colorbarHandle = [];
sliderHandles = {};
sliderRows = {};
sliderListeners = {};

% build ui sections
ctrl = buildControlPanel(rightFrame);
sb = buildStatusBar(bottomFrame);

% wire static callbacks
wireCallbacks(ctrl, sb);

% initialize
rebuildSliders(3);
updatePlot();
updateLatex();

% callbacks (nested to share workspace)

function wireCallbacks(c, ~)
    addlistener(c.editor, 'ValueChanged', @(~,evt) onExpressionChanged(evt.Data.value));
    addlistener(c.countInput, 'Submitted', @(~,evt) onCountSubmitted(evt.Data.value));
    addlistener(c.xMinSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("xMin", evt.Data.value));
    addlistener(c.xMaxSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("xMax", evt.Data.value));
    addlistener(c.yMinSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("yMin", evt.Data.value));
    addlistener(c.yMaxSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("yMax", evt.Data.value));
    addlistener(c.zMinSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("zMin", evt.Data.value));
    addlistener(c.zMaxSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("zMax", evt.Data.value));
    addlistener(c.resSlider, 'ValueChanging', @(~,evt) onDomainSliderChanged("res", evt.Data.value));
    addlistener(c.cmapSelect, 'ValueChanged', @(~,evt) onColormapChanged(evt.Data.value));
    addlistener(c.gridSwitch, 'ValueChanged', @(~,evt) onGridToggled(evt.Data.value));
    addlistener(c.colorbarSwitch, 'ValueChanged', @(~,evt) onColorbarToggled(evt.Data.value));

    % compile on ctrl+enter / cmd+enter
    c.editor.onKey("Ctrl+Enter", @(~,~) updatePlot(), "PreventDefault", true);
    c.editor.onKey("Meta+Enter", @(~,~) updatePlot(), "PreventDefault", true);
end

function onExpressionChanged(val)
    currentExpr = extractExpression(val);
    updatePlot();
    updateLatex();
end

function onCountSubmitted(val)
    raw = str2double(val);
    if isnan(raw) || raw < 1, raw = 1; end
    if raw > 6, raw = 6; end
    n = round(raw);
    ctrl.countInput.Value = string(n);
    rebuildSliders(n);
    updatePlot();
    updateLatex();
end

function onVarSliderChanged(idx, val)
    varValues(idx) = val;
    updatePlot();
end

function onDomainSliderChanged(which, val)
    switch which
        case "xMin", xRange(1) = val;
        case "xMax", xRange(2) = val;
        case "yMin", yRange(1) = val;
        case "yMax", yRange(2) = val;
        case "zMin", zRange(1) = val;
        case "zMax", zRange(2) = val;
        case "res",  resolution = round(val);
    end
    sb.resLabel.Text = sprintf("%d x %d", resolution, resolution);
    updatePlot();
end

function onColormapChanged(val)
    colormap(ax, char(val));
end

function onGridToggled(val)
    state = char(val);
    ax.XGrid = state; ax.YGrid = state; ax.ZGrid = state;
end

function onColorbarToggled(val)
    if val == "on"
        colorbarHandle = colorbar(ax);
    else
        if ~isempty(colorbarHandle) && isvalid(colorbarHandle)
            delete(colorbarHandle);
        end
        colorbarHandle = [];
    end
end

% core logic

function updatePlot()
    setStatus("Computing...", "muted");
    t0 = tic;
    try
        % build anonymous function
        args = join(["x", "y", varNames], ",");
        funcStr = "@(" + args + ") " + currentExpr;
        f = str2func(char(funcStr));

        % generate meshgrid
        xv = linspace(xRange(1), xRange(2), resolution);
        yv = linspace(yRange(1), yRange(2), resolution);
        [X, Y] = meshgrid(xv, yv);

        % evaluate
        argVals = num2cell(varValues);
        Z = f(X, Y, argVals{:});

        if ~isnumeric(Z) || ~isreal(Z)
            error('Expression must return real numeric values');
        end

        % handle scalar expansion
        if isscalar(Z)
            Z = Z * ones(size(X));
        end

        % plot
        cla(ax);
        surfHandle = surf(ax, X, Y, Z, ...
            'EdgeColor', 'none', ...
            'FaceLighting', 'gouraud');
        light(ax, 'Position', [1 0 1]);

        % re-apply display settings
        zlim(ax, zRange);
        colormap(ax, char(ctrl.cmapSelect.Value));
        onGridToggled();
        if ctrl.colorbarSwitch.Value && (isempty(colorbarHandle) || ~isvalid(colorbarHandle))
            colorbarHandle = colorbar(ax);
        end

        elapsed = toc(t0) * 1000;
        setStatus("Ready", "success");
        sb.timeLabel.Text = sprintf("%.1f ms", elapsed);
        sb.dimLabel.Text = sprintf("z = f(x, y, %s)", join(varNames, ", "));
    catch me
        setStatus("Error: " + me.message, "destructive");
    end
end

function updateEditor()
    args = join(["x", "y", varNames], ", ");
    line1 = "function z = myFunc(" + args + ")";
    line2 = "z = " + currentExpr;
    line3 = "end";
    ctrl.editor.Value = line1 + newline + line2 + newline + line3;
    ctrl.editor.UneditableLines = [1 3];
end

function updateLatex()
    latexExpr = matlabToLatex(currentExpr);
    doc = strjoin({
        '\documentclass[12pt]{article}'
        '\usepackage{amsmath, amssymb}'
        '\usepackage[paperwidth=4in, paperheight=1.5in, margin=0.2in]{geometry}'
        '\pagestyle{empty}'
        '\begin{document}'
        '{\LARGE'
        '\begin{equation*}'
        ['z = ' char(latexExpr)]
        '\end{equation*}'
        '}'
        '\end{document}'
    }, newline);
    ctrl.latex.Value = doc;
end

function rebuildSliders(n)
    % delete existing
    for k = 1:numel(sliderRows)
        if ~isempty(sliderListeners{k})
            cellfun(@delete, sliderListeners(k));
        end
        delete(sliderRows{k});
    end
    sliderHandles = {};
    sliderRows = {};
    sliderListeners = {};

    letters = 'abcdef';
    oldValues = varValues;

    for k = 1:n
        row = ic.FlexContainer("Direction", "row", "Gap", 8, "AlignItems", "center");
        ctrl.varSliderBox.addChild(row);

        lbl = ic.Label("Text", string(letters(k)), "Variant", "code", "Size", "sm", "Weight", "bold");
        row.addChild(lbl);
        lbl.css.style("> *", "width", "20px", "textAlign", "center", "flexShrink", "0");

        defaultVal = 1;
        if k <= numel(oldValues)
            defaultVal = oldValues(k);
        end

        s = ic.Slider( ...
            "Min", -1, "Max", 1, "Step", 0.01, ...
            "Value", defaultVal, ...
            "ShowValue", true, "Size", "sm");
        row.addChild(s);
        s.css.style("> *", "flex", "1", "minWidth", "0");

        sliderHandles{end+1} = s; %#ok<AGROW>
        sliderRows{end+1} = row; %#ok<AGROW>
        idx = k;
        lsnr = addlistener(s, 'ValueChanging', @(~,evt) onVarSliderChanged(idx, evt.Data.value));
        sliderListeners{end+1} = lsnr; %#ok<AGROW>
    end

    % update state
    varNames = string(arrayfun(@(i) letters(i), 1:n, 'UniformOutput', false));
    varValues = ones(1, n);
    for k = 1:min(n, numel(oldValues))
        varValues(k) = oldValues(k);
    end
    updateEditor();
end


function expr = extractExpression(editorValue)
    lines = splitlines(string(editorValue));
    if numel(lines) < 3
        expr = currentExpr;
        return
    end
    % grab everything between the function line and the end line
    middle = lines(2:end-1);
    joined = strip(strjoin(middle, newline));
    % strip leading "z = " if present
    if startsWith(joined, "z = ") || startsWith(joined, "z= ")
        joined = regexprep(joined, '^\s*z\s*=\s*', '');
    end
    expr = string(joined);
end

function setStatus(text, color)
    sb.statusLabel.Text = text;
    sb.statusLabel.Color = color;
end

end % EquationPlayground


% --- ui builders ---

function ctrl = buildControlPanel(frame)
tl = ic.TileLayout("Size", "sm", "DragEnabled", true);
frame.addChild(tl);
tl.css.fill();

% editor tab
[edPanel, ~] = tl.addTab("Editor", "Icon", "code");
ctrl.editor = ic.CodeEditor( ...
    "Language", "matlab", ...
    "Height", "100%", ...
    "LineNumbers", true, ...
    "BracketMatching", true, ...
    "HighlightActiveLine", false, ...
    "ShowStatusBar", false);
edPanel.addChild(ctrl.editor);

% initial editor content
initExpr = "a * sin(x) .* cos(y)";
ctrl.editor.Value = join([ ...
    "function z = myFunc(x, y, a, b, c)"
    "z = " + initExpr
    "end"
], newline);
ctrl.editor.UneditableLines = [1 3];

% parameters tab
[paramPanel, ~] = tl.addTab("Parameters", "Icon", "sliders-horizontal");
acc = ic.Accordion("Multiple", true, "Size", "sm");
paramPanel.addChild(acc);
acc.css.fill();

% variables panel
varPanel = acc.addPanel("Variables", "Icon", "variable", "Open", true);
countRow = ic.FlexContainer("Direction", "row", "Gap", 8, "AlignItems", "center", "Padding", [8 8 4 8]);
varPanel.addChild(countRow);

countRow.addChild(ic.Label("Text", "Count", "Variant", "caption", "Size", "sm"));
ctrl.countInput = ic.InputText("Value", "3", "Size", "sm");
countRow.addChild(ctrl.countInput);
ctrl.countInput.css.style("> *", "width", "60px");

ctrl.varSliderBox = ic.FlexContainer("Direction", "column", "Gap", 6, "Padding", [4 8 8 8]);
varPanel.addChild(ctrl.varSliderBox);

% domain panel
domPanel = acc.addPanel("Domain", "Icon", "grid-3x3", "Open", true);
domBox = ic.FlexContainer("Direction", "column", "Gap", 8, "Padding", [8 8]);
domPanel.addChild(domBox);

[ctrl.xMinSlider] = addLabeledSlider(domBox, "x min", -20, 0, 0.5, -5);
[ctrl.xMaxSlider] = addLabeledSlider(domBox, "x max", 0, 20, 0.5, 5);
[ctrl.yMinSlider] = addLabeledSlider(domBox, "y min", -20, 0, 0.5, -5);
[ctrl.yMaxSlider] = addLabeledSlider(domBox, "y max", 0, 20, 0.5, 5);
[ctrl.zMinSlider] = addLabeledSlider(domBox, "z min", -5, 0, 0.1, -2);
[ctrl.zMaxSlider] = addLabeledSlider(domBox, "z max", 0, 5, 0.1, 2);
[ctrl.resSlider] = addLabeledSlider(domBox, "res", 10, 200, 5, 50);

% display panel
dispPanel = acc.addPanel("Display", "Icon", "palette", "Open", true);
dispBox = ic.FlexContainer("Direction", "column", "Gap", 8, "Padding", [8 8]);
dispPanel.addChild(dispBox);

cmapRow = ic.FlexContainer("Direction", "row", "Gap", 8, "AlignItems", "center");
dispBox.addChild(cmapRow);
cmapRow.addChild(ic.Label("Text", "Colormap", "Variant", "caption", "Size", "sm"));
ctrl.cmapSelect = ic.Select( ...
    "Items", ["parula", "jet", "hot", "cool", "turbo", "hsv", "copper", "bone"], ...
    "Value", "parula", ...
    "Size", "sm");
cmapRow.addChild(ctrl.cmapSelect);
ctrl.cmapSelect.css.style("> *", "flex", "1");

ctrl.gridSwitch = addLabeledSwitch(dispBox, "Grid");
ctrl.colorbarSwitch = addLabeledSwitch(dispBox, "Colorbar");

% latex tab
[latexPanel, ~] = tl.addTab("LaTeX", "Icon", "sigma");
ctrl.latex = ic.Latex( ...
    "RenderOnChange", true, ...
    "Height", "100%", ...
    "ToolbarOnHover", false);
latexPanel.addChild(ctrl.latex);
end


function sb = buildStatusBar(frame)
container = ic.FlexContainer("Direction", "row", "Gap", 12, "Padding", [2 8], "AlignItems", "center");
frame.addChild(container);
container.css.fill();
container.css.style("> *", ...
    "borderTop", "1px solid var(--ic-border)", ...
    "background", "var(--ic-muted)", ...
    "minHeight", "24px");

sb.statusLabel = ic.Label("Text", "Ready", "Variant", "caption", "Size", "sm", "Color", "success");
container.addChild(sb.statusLabel);

spacer = ic.FlexContainer();
container.addChild(spacer);
spacer.css.style("> *", "flex", "1");

sb.timeLabel = ic.Label("Text", "0 ms", "Variant", "caption", "Size", "sm", "Color", "muted");
container.addChild(sb.timeLabel);

sb.dimLabel = ic.Label("Text", "z = f(x, y, a, b, c)", "Variant", "caption", "Size", "sm", "Color", "muted");
container.addChild(sb.dimLabel);

sb.resLabel = ic.Label("Text", "50 x 50", "Variant", "caption", "Size", "sm", "Color", "muted");
container.addChild(sb.resLabel);
end


% --- helpers ---

function s = addLabeledSlider(parent, labelText, minVal, maxVal, step, value)
row = ic.FlexContainer("Direction", "row", "Gap", 8, "AlignItems", "center");
parent.addChild(row);

lbl = ic.Label("Text", labelText, "Variant", "caption", "Size", "sm");
row.addChild(lbl);
lbl.css.style("> *", "width", "70px", "flexShrink", "0");

s = ic.Slider("Min", minVal, "Max", maxVal, "Step", step, "Value", value, "ShowValue", true, "Size", "sm");
row.addChild(s);
s.css.style("> *", "flex", "1", "minWidth", "0");
end

function sw = addLabeledSwitch(parent, labelText)
row = ic.FlexContainer("Direction", "row", "Gap", 8, "AlignItems", "center");
parent.addChild(row);
row.addChild(ic.Label("Text", labelText, "Variant", "caption", "Size", "sm"));
sw = ic.Switch("Size", "sm");
row.addChild(sw);
end

function latexStr = matlabToLatex(expr)
s = string(expr);

% element-wise operators
s = strrep(s, ".*", " \cdot ");
s = strrep(s, "./", " / ");
s = strrep(s, ".^", "^");

% power with braces: x^2 -> x^{2}, x^(expr) -> x^{expr}
s = regexprep(s, '\^(\w+)', '^{$1}');
s = regexprep(s, '\^\(([^)]+)\)', '^{$1}');

% sqrt
s = regexprep(s, 'sqrt\(([^)]+)\)', '\\sqrt{$1}');

% trig and math functions
funcs = ["sin","cos","tan","asin","acos","atan","sinh","cosh","tanh","exp","log","abs"];
for fn = funcs
    s = regexprep(s, '\b' + fn + '\b', '\' + fn);
end

% constants
s = regexprep(s, '\bpi\b', '\\pi');

% simple fractions: a/b (single tokens only)
s = regexprep(s, '(\w+)\s*/\s*(\w+)', '\\frac{$1}{$2}');

latexStr = s;
end

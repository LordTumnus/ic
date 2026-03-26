function LatexEditor()
% LaTeX live editor with split-pane editing, live preview, and figure capture

% build the figure and main frame where the app will live
fig = uifigure( ...
    "Name", "LaTeX Editor", ...
    "Position", [100 100 1200 750]);
gl = uigridlayout(fig, ...
    "RowHeight", {'1x'}, ...
    "ColumnWidth", {'1x'}, ...
    "Padding", [0 0 0 0]);
frame = ic.Frame("Parent", gl);

% root layout
% + -----------------------------------+
% | Toolbar                            |
% + -----------------------------------+
% | PNG |    Editor    |    Preview    |
% |     |              |               |
% |     |              |               |
% |     |              |               |
% + -----------------------------------+
root = ic.GridContainer( ...
    "Rows", "auto 1fr auto", ...
    "Columns", "1fr", ...
    "Gap", 0);
frame.addChild(root);
root.css.fill();

% toolbar container
% +-----------------------------------+
% | Capture | Export | Template | ... |
% +-----------------------------------+
tb = ic.FlexContainer( ...
    "Direction", "row", ...
    "Gap", 4, ...
    "Padding", [4 8], ...
    "AlignItems", "center");
root.addChild(tb);
tb.style("> *", ...
    "borderBottom", "1px solid var(--ic-border)", ...
    "background", "var(--ic-card)", ...
    "overflowX", "auto");

captureBtn = ic.Button("Label", "Capture Figures", "Variant", "secondary", "Fill", "outline", "Size", "sm");
captureBtn.Icon = ic.Icon("Source", "camera");
tb.addChild(captureBtn);

exportBtn = ic.Button("Label", "Export PDF", "Variant", "secondary", "Fill", "outline", "Size", "sm");
exportBtn.Icon = ic.Icon("Source", "download");
tb.addChild(exportBtn);

tb.addChild(ic.Label("Text", "|", "Color", "muted"));

templateSelect = ic.Select( ...
    "Items", ["Article", "Report", "Book", "Letter", "Blank"], ...
    "Placeholder", "Template...", ...
    "Size", "sm");
tb.addChild(templateSelect);
templateSelect.style("> *", "width", "140px");

tb.addChild(ic.Label("Text", "|", "Color", "muted"));

boldBtn      = ghostBtn("bold", tb);
italicBtn    = ghostBtn("italic", tb);
underlineBtn = ghostBtn("underline", tb);

tb.addChild(ic.Label("Text", "|", "Color", "muted"));

sectionBtn = ghostBtn("heading", tb);
listBtn    = ghostBtn("list", tb);
mathBtn    = ghostBtn("sigma", tb);
figBtn     = ghostBtn("image", tb);
tableBtn   = ghostBtn("table", tb);
snippetBtn = ghostBtn("braces", tb);

spacer = ic.FlexContainer();
tb.addChild(spacer);
spacer.style("> *", "flex", "1");

compileBtn = ic.Button("Label", "Compile", "Variant", "primary", "Size", "sm");
compileBtn.Icon = ic.Icon("Source", "play");
tb.addChild(compileBtn);

% main content area (thumbnail + split panel)
mainRow = ic.FlexContainer("Direction", "row", "Gap", 0);
root.addChild(mainRow);
mainRow.css.fill();


% thumbnail strip for captured figures
% +------------+
% |  Thumbnail |
% |  Thumbnail |
% |  Thumbnail |
% |  ...       |
% +------------+
thumbStrip = ic.FlexContainer( ...
    "Direction", "column", ...
    "Gap", 8, ...
    "Padding", [8 4], ...
    "AlignItems", "center");
thumbStrip.css.width("80px");
mainRow.addChild(thumbStrip);
thumbStrip.style("> *", ...
    "width", "160px", ...
    "borderRight", "1px solid var(--ic-border)", ...
    "overflowY", "auto", ...
    "flexShrink", "0");
thumbStrip.css.hide();

% split : editor + preview with resizable gutter
% +---------------------------+
% |           ||              |
% |  Editor   ||   Preview    |
% |           ||              |
% +---------------------------+
splitter = ic.Splitter("Direction", "horizontal", "GutterSize", 5);
mainRow.addChild(splitter);
splitter.style("> *", "flex", "1", "minWidth", "0");

leftPane = splitter.addPane("Size", 50, "MinSize", 20);
editor = ic.CodeEditor( ...
    "Language", "latex", ...
    "Height", "100%", ...
    "LineNumbers", true, ...
    "CodeFolding", true, ...
    "BracketMatching", true, ...
    "LineWrapping", true, ...
    "ShowStatusBar", false);
leftPane.addChild(editor);

rightPane = splitter.addPane("Size", 50, "MinSize", 20);
preview = ic.Latex( ...
    "RenderOnChange", false, ...
    "ToolbarOnHover", true, ...
    "Height", "100%");
rightPane.addChild(preview);

% status bar
% +-----------------------------------+
% | Compiled?            |  3 pages   |
% +-----------------------------------+
sb = ic.FlexContainer("Direction", "row", "Gap", 12, "Padding", [2 8], "AlignItems", "center");
root.addChild(sb);
sb.style("> *", ...
    "borderTop", "1px solid var(--ic-border)", ...
    "background", "var(--ic-muted)", ...
    "minHeight", "24px");

statusLabel    = ic.Label("Text", "Ready",     "Variant", "caption", "Size", "sm", "Color", "muted");
sb.addChild(statusLabel);
sbSpacer = ic.FlexContainer();
sb.addChild(sbSpacer);
sbSpacer.style("> *", "flex", "1");
pageCountLabel = ic.Label("Text", "0 pages",   "Variant", "caption", "Size", "sm", "Color", "muted");
sb.addChild(pageCountLabel);
cursorLabel    = ic.Label("Text", "Ln 1, Col 1", "Variant", "caption", "Size", "sm", "Color", "muted");
sb.addChild(cursorLabel);

% side drawer for snippet insertion
% +-----------------------------+
% | v | Environment             |
% | v | Math                    |
% | v | Structure               |
% +-----------------------------+

snippetDrawer = ic.Drawer("Title", "Insert Snippet", "Side", "right", "Size", "sm");
frame.addChild(snippetDrawer);

acc = ic.Accordion("Multiple", true, "Size", "sm");
snippetDrawer.addChild(acc, "body");

envPanel = acc.addPanel("Environments", "Open", true, "Icon", "braces");
addSnippetButtons(envPanel, {
    "equation",   "\\begin{equation}\n    \n\\end{equation}"
    "align",      "\\begin{align}\n    a &= b \\\\\n    c &= d\n\\end{align}"
    "figure",     "\\begin{figure}[htbp]\n    \\centering\n    % content here\n    \\caption{Caption}\n    \\label{fig:label}\n\\end{figure}"
    "table",      "\\begin{table}[htbp]\n    \\centering\n    \\begin{tabular}{lcc}\n        \\toprule\n        A & B & C \\\\\n        \\midrule\n        1 & 2 & 3 \\\\\n        \\bottomrule\n    \\end{tabular}\n    \\caption{Caption}\n    \\label{tab:label}\n\\end{table}"
    "itemize",    "\\begin{itemize}\n    \\item \n\\end{itemize}"
    "enumerate",  "\\begin{enumerate}\n    \\item \n\\end{enumerate}"
    "verbatim",   "\\begin{verbatim}\n\n\\end{verbatim}"
    "lstlisting", "\\begin{lstlisting}[language=Matlab]\n\n\\end{lstlisting}"
}, editor);

mathPanel = acc.addPanel("Math", "Icon", "sigma");
addSnippetButtons(mathPanel, {
    "fraction",  "\\frac{num}{den}"
    "sum",       "\\sum_{i=1}^{n} "
    "integral",  "\\int_{a}^{b} f(x) \\, dx"
    "matrix",    "\\begin{pmatrix}\n    a & b \\\\\n    c & d\n\\end{pmatrix}"
    "cases",     "\\begin{cases}\n    x & \\text{if } x > 0 \\\\\n    -x & \\text{otherwise}\n\\end{cases}"
}, editor);

structPanel = acc.addPanel("Structure", "Icon", "heading");
addSnippetButtons(structPanel, {
    "section",    "\\section{Title}"
    "subsection", "\\subsection{Title}"
    "paragraph",  "\\paragraph{Title}"
    "footnote",   "\\footnote{text}"
    "cite",       "\\cite{key}"
}, editor);

% event wiring
addlistener(compileBtn, 'Clicked', @(~,~) onCompile());
addlistener(exportBtn, 'Clicked', @(~,~) preview.exportPdf());
addlistener(templateSelect, 'ValueChanged', @(~,e) onTemplateChanged(e));
addlistener(editor, 'ValueChanged', @(~,~) onEditorChanged());
addlistener(editor, 'SelectionChanged', @(~,~) onCursorChanged());
addlistener(preview, 'Compiled', @(~,e) onCompiled(e));
addlistener(preview, 'Error', @(~,e) onCompileError(e));
addlistener(captureBtn, 'Clicked', @(~,~) onCaptureFigure());
addlistener(boldBtn, 'Clicked',      @(~,~) wrapSelection("\\textbf{%s}"));
addlistener(italicBtn, 'Clicked',    @(~,~) wrapSelection("\\textit{%s}"));
addlistener(underlineBtn, 'Clicked', @(~,~) wrapSelection("\\underline{%s}"));

addlistener(sectionBtn, 'Clicked', @(~,~) insertRaw(sprintf("\\section{Title}\n")));
addlistener(listBtn, 'Clicked',    @(~,~) insertRaw(sprintf("\\begin{itemize}\n    \\item \n\\end{itemize}\n")));
addlistener(mathBtn, 'Clicked',    @(~,~) insertRaw(sprintf("\\begin{equation}\n    \n\\end{equation}\n")));
addlistener(figBtn, 'Clicked',     @(~,~) insertRaw(sprintf("\\begin{figure}[htbp]\n    \\centering\n    \\includegraphics[width=0.8\\textwidth]{filename}\n    \\caption{Caption}\n    \\label{fig:label}\n\\end{figure}\n")));
addlistener(tableBtn, 'Clicked',   @(~,~) insertRaw(sprintf("\\begin{table}[htbp]\n    \\centering\n    \\begin{tabular}{lcc}\n        \\toprule\n        A & B & C \\\\\\\\\n        \\midrule\n        1 & 2 & 3 \\\\\\\\\n        \\bottomrule\n    \\end{tabular}\n    \\caption{Caption}\n\\end{table}\n")));
addlistener(snippetBtn, 'Clicked', @(~,~) snippetDrawer.open());

% state for figure capture (tracks which figures have already been captured to avoid duplicates)
capturedFigs = gobjects(0);

editor.Value = getTemplate("Article");
templateSelect.Value = "Article";
onCompile();

% callbacks
function onCompile()
    preview.Value = editor.Value;
    preview.render();
    statusLabel.Text = "Compiling...";
    statusLabel.Color = "muted";
end

function onTemplateChanged(evt)
    name = string(evt.Data.value);
    if name == "" || ismissing(name), return; end
    tex = getTemplate(name);
    if tex ~= ""
        editor.Value = tex;
        onCompile();
    end
end

function onEditorChanged()
    statusLabel.Text = "Editing...";
    statusLabel.Color = "muted";
end

function onCursorChanged()
    cursorLabel.Text = sprintf("Ln %d, Col %d", editor.CursorLine, editor.CursorColumn);
end

function onCompiled(evt)
    np = evt.Data.value.numPages;
    if np == 1
        pageCountLabel.Text = "1 page";
    else
        pageCountLabel.Text = sprintf("%d pages", np);
    end
    statusLabel.Text = "Compiled";
    statusLabel.Color = "success";
end

function onCompileError(evt)
    msg = string(evt.Data.value.message);
    statusLabel.Text = "Error";
    statusLabel.Color = "destructive";
    t = ic.Toast("Value", msg, "Variant", "destructive", "Duration", 5);
    frame.addChild(t);
end

function onCaptureFigure()
    figs = findall(0, 'Type', 'figure');
    figs(figs == fig) = [];

    % Filter out already-captured figures
    capturedFigs(~isvalid(capturedFigs)) = []; % prune deleted
    newFigs = figs(~ismember(figs, capturedFigs));

    if isempty(newFigs)
        t = ic.Toast("Value", "No new figures to capture.", "Variant", "warning");
        frame.addChild(t);
        return
    end

    for k = 1:numel(newFigs)
        capFig = newFigs(k);
        tmpFile = fullfile(tempdir, ...
            sprintf("capture_%s_%d.png", datestr(now, 'yyyymmdd_HHMMSS'), k)); %#ok<TNOW1,DATST>
        exportgraphics(capFig, tmpFile, 'Resolution', 150);

        thumb = ic.Image( ...
            "Source", tmpFile, ...
            "Width", 120, "Height", 100, ...
            "ObjectFit", "contain", "BorderRadius", 4);
        thumbStrip.addChild(thumb);
        thumb.style("> *", ...
            "border", "1px solid var(--ic-border)", ...
            "cursor", "pointer", ...
            "padding", "4px", ...
            "background", "var(--ic-card)");

        filePath = tmpFile;
        addlistener(thumb, 'Clicked', @(~,~) onThumbnailClicked(filePath));
    end

    capturedFigs = [capturedFigs; newFigs(:)];
    thumbStrip.css.show("flex");

    n = numel(newFigs);
    msg = sprintf("%d figure%s captured!", n, char('s' * (n > 1)));
    t = ic.Toast("Value", msg, "Variant", "success");
    frame.addChild(t);
end

function onThumbnailClicked(filepath)
    filepath = char(filepath);
    [~, name] = fileparts(filepath);
    caption = strrep(name, '_', '\_');
    label = strrep(name, '_', '-');
    snip = strjoin({
        '\begin{figure}[htbp]'
        '    \centering'
       ['    \includegraphics[width=0.8\textwidth]{' filepath '}']
       ['    \caption{' caption '}']
       ['    \label{fig:' label '}']
        '\end{figure}'
    }, newline);
    editor.replaceSelection(snip);
    editor.focus();
end

function wrapSelection(template)
    editor.getSelection().then(@(sel) doWrap(sel.Data));
    function doWrap(sel)
        sel = string(sel);
        if ismissing(sel), sel = ""; end
        editor.replaceSelection(sprintf(template, sel));
        editor.focus();
    end
end

function insertRaw(text)
    editor.replaceSelection(text);
    editor.focus();
end

end % LatexEditor


function btn = ghostBtn(iconName, parent)
    btn = ic.Button("Label", "", "Fill", "ghost", "Size", "sm", "Shape", "square");
    btn.Icon = ic.Icon("Source", iconName);
    parent.addChild(btn);
end

function addSnippetButtons(panel, snippetTable, ed)
    for k = 1:size(snippetTable, 1)
        lbl = snippetTable{k, 1};
        snip = sprintf(snippetTable{k, 2});
        b = ic.Button("Label", lbl, "Fill", "ghost", "Size", "sm");
        panel.addChild(b);
        b.css.fillWidth();
        addlistener(b, 'Clicked', @(~,~) doInsert(snip));
    end
    function doInsert(s)
        ed.replaceSelection(s);
        ed.focus();
    end
end

function tex = getTemplate(name)
    switch name
        case "Article"
            tex = strjoin({
                '\documentclass[12pt]{article}'
                '\usepackage{amsmath, amssymb}'
                '\usepackage{geometry}'
                '\geometry{a4paper, margin=1in}'
                '\usepackage{graphicx}'
                '\usepackage{hyperref}'
                '\usepackage{booktabs}'
                '\usepackage{xcolor}'
                ''
                '\title{My Article}'
                '\author{Author Name}'
                '\date{\today}'
                ''
                '\begin{document}'
                '\maketitle'
                ''
                '\section{Introduction}'
                'Write your introduction here. This is a live-editing'
                'environment powered by the IC framework.'
                ''
                '\section{Mathematics}'
                'The Euler identity:'
                '\begin{equation}'
                '    e^{i\pi} + 1 = 0'
                '\end{equation}'
                ''
                'And the Gaussian integral:'
                '\begin{equation}'
                '    \int_{-\infty}^{\infty} e^{-x^2} \, dx = \sqrt{\pi}'
                '\end{equation}'
                ''
                '\section{Tables}'
                '\begin{table}[htbp]'
                '    \centering'
                '    \begin{tabular}{lcc}'
                '        \toprule'
                '        Method & Accuracy & Speed \\'
                '        \midrule'
                '        Baseline  & 0.85 & 1.0x \\'
                '        Improved  & 0.92 & 0.8x \\'
                '        Proposed  & \textbf{0.96} & 1.2x \\'
                '        \bottomrule'
                '    \end{tabular}'
                '    \caption{Comparison of methods.}'
                '    \label{tab:comparison}'
                '\end{table}'
                ''
                '\section{Conclusion}'
                'Summarize your findings here.'
                ''
                '\end{document}'
            }, newline);

        case "Report"
            tex = strjoin({
                '\documentclass[12pt]{report}'
                '\usepackage{amsmath, amssymb}'
                '\usepackage{geometry}'
                '\geometry{a4paper, margin=1in}'
                '\usepackage{graphicx}'
                '\usepackage{hyperref}'
                '\usepackage{booktabs}'
                '\usepackage{fancyhdr}'
                ''
                '\title{Technical Report}'
                '\author{Author Name}'
                '\date{\today}'
                ''
                '\begin{document}'
                '\maketitle'
                '\tableofcontents'
                ''
                '\chapter{Introduction}'
                'Write your introduction here.'
                ''
                '\chapter{Background}'
                'Provide background information.'
                ''
                '\chapter{Methodology}'
                'Describe your approach.'
                ''
                '\chapter{Results}'
                'Present your findings.'
                ''
                '\chapter{Conclusion}'
                'Summarize and conclude.'
                ''
                '\end{document}'
            }, newline);

        case "Book"
            tex = strjoin({
                '\documentclass[12pt]{book}'
                '\usepackage{amsmath, amssymb}'
                '\usepackage{geometry}'
                '\geometry{a4paper, margin=1in}'
                '\usepackage{graphicx}'
                '\usepackage{hyperref}'
                ''
                '\title{My Book}'
                '\author{Author Name}'
                '\date{\today}'
                ''
                '\begin{document}'
                '\maketitle'
                '\tableofcontents'
                ''
                '\part{Getting Started}'
                ''
                '\chapter{Introduction}'
                'Welcome to this book.'
                ''
                '\section{Motivation}'
                'Explain the motivation here.'
                ''
                '\chapter{Background}'
                'Provide background information.'
                ''
                '\part{Main Content}'
                ''
                '\chapter{Methods}'
                'Describe your methods.'
                ''
                '\chapter{Conclusion}'
                'Summarize and conclude.'
                ''
                '\end{document}'
            }, newline);

        case "Letter"
            tex = strjoin({
                '\documentclass{letter}'
                '\usepackage{geometry}'
                '\geometry{a4paper, margin=1in}'
                ''
                '\signature{Your Name}'
                '\address{Your Address \\ City, State ZIP}'
                ''
                '\begin{document}'
                ''
                '\begin{letter}{Recipient Name \\ Address \\ City, State ZIP}'
                ''
                '\opening{Dear Sir or Madam,}'
                ''
                'I am writing to inform you about an exciting development.'
                'The IC framework now supports live LaTeX editing with'
                'real-time compilation and preview.'
                ''
                '\closing{Sincerely,}'
                ''
                '\end{letter}'
                ''
                '\end{document}'
            }, newline);

        case "Blank"
            tex = strjoin({
                '\documentclass[12pt]{article}'
                ''
                '\begin{document}'
                ''
                'Start writing here'
                ''
                '\end{document}'
            }, newline);

        otherwise
            tex = "";
    end
end

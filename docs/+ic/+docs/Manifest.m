classdef Manifest
% documentation ordering manifest for the IC framework.
% defines sections and the order in which classes/functions appear.
% entries starting with "+" are package expansions: all classes in that
% package are included alphabetically (e.g. "+ic.table" expands to
% ic.table.Column, ic.table.TextColumn, etc.)

    methods (Static)

        function sections = get()
        % return the ordered section list for the documentation.

            s = @ic.docs.Manifest.section;
            sub = @ic.docs.Manifest.sub;

            sections = [ ...
                s("Core", [ ...
                    "ic.Frame"
                    "ic.core.ComponentBase"
                    "ic.core.Component"
                    "ic.core.ComponentContainer"
                    "ic.core.Container"
                    "ic.core.View"
                    "ic.core.Logger"
                ]), ...
                s("Reactivity & Events", { ...
                    "ic.mixin.Reactive", ...
                    "ic.mixin.Publishable", ...
                    "ic.event.MEvent", ...
                    "ic.event.JsEvent", ...
                    "ic.event.TransportData", ...
                    sub("Transport data", "ic.utils.toTransport") ...
                }), ...
                s("Async", [ ...
                    "ic.async.Promise"
                    "ic.async.Resolution"
                ]), ...
                s("Mixins", { ...
                    "ic.mixin.Stylable", ...
                    sub("Styles", ["ic.mixin.StyleBuilder", "+ic.check"]), ...
                    "ic.mixin.Effectable", ...
                    sub("Effect utils", ["ic.effect.JsEffect", "ic.utils.bind"]), ...
                    "ic.mixin.Keyable", ...
                    sub("Key utils", "ic.key.KeyBinding"), ...
                    "ic.mixin.Requestable", ...
                    "ic.mixin.Registrable", ...
                    "ic.mixin.AllowsOverlay", ...
                    "ic.mixin.Overlay" ...
                }), ...
                s("Assets", { ...
                    "ic.Asset", ...
                    "ic.AssetRegistry", ...
                    sub("Asset validation", "+ic.assets") ...
                }), ...
                s("Theming", [ ...
                    "ic.style.Theme"
                ]), ...
                s("Utilities", [ ...
                    "ic.utils.toCamelCase"
                    "ic.utils.toKebabCase"
                    "ic.utils.toPascalCase"
                    "ic.utils.toSnakeCase"
                ]), ...
                s("Form Components", [ ...
                    "ic.Button"
                    "ic.SplitButton"
                    "ic.InputText"
                    "ic.Password"
                    "ic.TextArea"
                    "ic.Select"
                    "ic.MultiSelect"
                    "ic.TreeSelect"
                    "ic.SearchBar"
                    "ic.Checkbox"
                    "ic.Switch"
                    "ic.ToggleButton"
                    "ic.RadioButton"
                    "ic.SegmentedButton"
                    "ic.Slider"
                    "ic.RangeSlider"
                    "ic.Knob"
                    "ic.ColorPicker"
                ]), ...
                s("Display Components", [ ...
                    "ic.Label"
                    "ic.Icon"
                    "ic.Image"
                    "ic.ProgressBar"
                    "ic.CircularProgressBar"
                    "ic.Spinner"
                ]), ...
                s("Layout Components", [ ...
                    "ic.FlexContainer"
                    "ic.GridContainer"
                    "ic.Splitter"
                    "ic.SplitterPane"
                    "ic.TabContainer"
                    "ic.tab.Tab"
                    "ic.tab.TabPanel"
                    "ic.TileLayout"
                    "ic.Accordion"
                    "ic.accordion.AccordionPanel"
                ]), ...
                s("Overlay Components", [ ...
                    "ic.Dialog"
                    "ic.Drawer"
                    "ic.Popover"
                    "ic.popover.Panel"
                    "ic.Toast"
                ]), ...
                s("Menu", [ ...
                    "ic.mixin.HasContextMenu"
                    "ic.menu.Entry"
                    "ic.menu.Item"
                    "ic.menu.Folder"
                    "ic.menu.Separator"
                    "+ic.menu"
                ]), ...
                s("Utilities", [ ...
                    "ic.Panel", ...
                    "ic.HtmlElement", ...
                ]), ...
                s("Renderers", { ...
                    "ic.Markdown", ...
                    "ic.Latex", ...
                    "ic.Typst", ...
                    "ic.Mermaid", ...
                    sub("Mermaid Configs", "+ic.mermaid"), ...
                    "ic.PDFViewer", ...

                }), ...
                s("Editors", [ ...
                    "ic.CodeEditor" ...
                    "ic.RichEditor"
                ]), ...
                s("Tree", [ ...
                    "ic.TreeBase"
                    "ic.tree.Node"
                    "ic.Tree"
                    "ic.FilterTree"
                    "ic.VirtualTree"
                    "ic.VirtualFilterTree"
                    "ic.TreeTable"
                    "ic.VirtualTreeTable"
                ]), ...
                s("Table", {...
                    "ic.TableBase", ...
                    "ic.Table", ...
                    "ic.VirtualTable", ...
                    sub("Columns", {"ic.table.Column", ...
                    "ic.table.TextColumn", ...
                    "ic.table.NumberColumn", ...
                    "ic.table.BooleanColumn", ...
                    "ic.table.EnumColumn", ...
                    "+ic.table"}), ...
                }), ...
                s("Tweakpane", [ ...
                    "ic.TweakPane"
                    "ic.tp.Blade"
                    "ic.tp.ContainerBlade"
                    "ic.tp.Folder"
                    "ic.tp.TabGroup"
                    "ic.tp.TabPage"
                    "ic.tp.Separator"
                    "+ic.tp"
                ]), ...
            ];
        end

        function patterns = excluded()
        % return patterns of classes/packages to exclude from documentation.
        % exact names (e.g. "ic.NodeEditor") and package prefixes
        % (e.g. "+ic.node") are supported.
            patterns = [ ...
                "ic.NodeEditor"
                "+ic.node"
                "+ic.internal"
            ];
        end

        function s = section(title, items)
        % create a section struct.
        % items is a cell array — elements are either char/string (class
        % names) or subsection structs created by sub().
            if isstring(items) || ischar(items)
                items = cellstr(items);
            end
            s = struct('title', title, 'items', {items});
        end

        function ss = sub(title, items)
        % create a subsection struct (nested group within a section).
            ss = struct('title', title, 'items', {cellstr(items)});
        end

        function ordered = resolve(sections, allDocs)
        % expand +package entries and match against parsed docs.
        % returns a struct array of sections. Each section has title and
        % items (cell array). Items are either doc structs or subsection
        % structs {subsection: title, items: [doc structs]}.

            allNames = string({allDocs.fullName});
            placed = false(size(allNames)); % track which docs are placed

            % mark excluded items as already placed so they never appear
            excl = ic.docs.Manifest.excluded();
            for ee = 1:numel(excl)
                pat = excl(ee);
                if startsWith(pat, "+")
                    pkg = extractAfter(pat, 1) + ".";
                    placed = placed | startsWith(allNames, pkg);
                else
                    placed = placed | (allNames == pat);
                end
            end

            ordered = struct('title', {}, 'items', {});

            for ii = 1:numel(sections)
                sec = sections(ii);
                sectionItems = {};

                for jj = 1:numel(sec.items)
                    entry = sec.items{jj};

                    if isstruct(entry) && isfield(entry, 'title')
                        % subsection — resolve its items and wrap
                        subItems = [];
                        for kk = 1:numel(entry.items)
                            resolved = ic.docs.Manifest.resolveEntry( ...
                                string(entry.items{kk}), allNames, allDocs, placed);
                            for mm = 1:numel(resolved.indices)
                                placed(resolved.indices(mm)) = true;
                            end
                            subItems = [subItems, resolved.docs]; %#ok<AGROW>
                        end
                        if ~isempty(subItems)
                            sectionItems{end+1} = struct( ...
                                'subsection', entry.title, ...
                                'items', subItems); %#ok<AGROW>
                        end
                    else
                        % plain entry (string)
                        resolved = ic.docs.Manifest.resolveEntry( ...
                            string(entry), allNames, allDocs, placed);
                        for kk = 1:numel(resolved.indices)
                            placed(resolved.indices(kk)) = true;
                        end
                        for kk = 1:numel(resolved.docs)
                            sectionItems{end+1} = resolved.docs(kk); %#ok<AGROW>
                        end
                    end
                end

                if ~isempty(sectionItems)
                    ordered(end + 1) = struct( ...
                        'title', sec.title, ...
                        'items', {sectionItems}); %#ok<AGROW>
                end
            end

            % catch-all: items not placed in any section
            unplaced = find(~placed);
            if ~isempty(unplaced)
                visible = {};
                for kk = 1:numel(unplaced)
                    if ~allDocs(unplaced(kk)).hidden
                        visible{end+1} = allDocs(unplaced(kk)); %#ok<AGROW>
                    end
                end
                if ~isempty(visible)
                    ordered(end + 1) = struct( ...
                        'title', "Other", ...
                        'items', {visible});
                end
            end
        end

        function result = resolveEntry(entry, allNames, allDocs, placed)
        % resolve a single manifest entry (exact match or +package).
        % returns struct with docs (array) and indices (array).
            docs = [];
            indices = [];

            if startsWith(entry, "+")
                pkg = extractAfter(entry, 1) + ".";
                mask = startsWith(allNames, pkg) & ~placed;
                remaining = extractAfter(allNames(mask), strlength(pkg));
                shallow = ~contains(remaining, ".");
                shallowIdx = find(mask);
                shallowIdx = shallowIdx(shallow);
                [~, sortOrder] = sort(allNames(shallowIdx));
                expandedIdx = shallowIdx(sortOrder);

                for kk = 1:numel(expandedIdx)
                    idx = expandedIdx(kk);
                    if ~placed(idx)
                        docs = [docs, allDocs(idx)]; %#ok<AGROW>
                        indices = [indices, idx]; %#ok<AGROW>
                    end
                end
            else
                idx = find(allNames == entry, 1);
                if ~isempty(idx) && ~placed(idx)
                    docs = allDocs(idx);
                    indices = idx;
                end
            end

            result = struct('docs', docs, 'indices', indices);
        end

    end
end

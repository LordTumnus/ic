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
                s("Reactivity & Events", [ ...
                    "ic.mixin.Reactive"
                    "ic.mixin.Publishable"
                    "ic.event.MEvent"
                    "ic.event.JsEvent"
                    "ic.event.TransportData"
                ]), ...
                s("Async", [ ...
                    "ic.async.Promise"
                    "ic.async.Resolution"
                ]), ...
                s("Mixins", [ ...
                    "ic.mixin.Stylable"
                    "ic.mixin.StyleBuilder"
                    "ic.mixin.Effectable"
                    "ic.mixin.Keyable"
                    "ic.mixin.Requestable"
                    "ic.mixin.Registrable"
                    "ic.mixin.AllowsOverlay"
                    "ic.mixin.Overlay"
                ]), ...
                s("Effects & Key Bindings", [ ...
                    "ic.effect.JsEffect"
                    "ic.key.KeyBinding"
                ]), ...
                s("Theming & Assets", [ ...
                    "ic.style.Theme"
                    "ic.Asset"
                    "ic.AssetRegistry"
                ]), ...
                s("Utilities", [ ...
                    "ic.utils.bind"
                    "ic.utils.toCamelCase"
                    "ic.utils.toKebabCase"
                    "ic.utils.toPascalCase"
                    "ic.utils.toSnakeCase"
                    "ic.utils.toTransport"
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
                s("Panel", [ ...
                    "ic.Panel"
                ]), ...
                s("Renderers", [ ...
                    "ic.Markdown"
                    "ic.Latex"
                    "ic.Typst"
                    "ic.Mermaid"
                    "+ic.mermaid"
                    "ic.PDFViewer"
                    "ic.CodeEditor"
                ]), ...
                s("Rich Editor", [ ...
                    "ic.RichEditor"
                ]), ...
                s("Tree", [ ...
                    "ic.TreeBase"
                    "ic.tree.Node"
                    "ic.Tree"
                    "ic.FilterTree"
                    "ic.VirtualTree"
                    "ic.VirtualFilterTree"
                ]), ...
                s("Table", [ ...
                    "ic.TableBase"
                    "ic.Table"
                    "ic.VirtualTable"
                    "ic.TreeTable"
                    "ic.VirtualTreeTable"
                    "ic.table.Column"
                    "ic.table.TextColumn"
                    "ic.table.NumberColumn"
                    "ic.table.BooleanColumn"
                    "ic.table.EnumColumn"
                    "+ic.table"
                ]), ...
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
                s("Validators", [ ...
                    "+ic.assets"
                    "+ic.check"
                ]) ...
            ];
        end

        function s = section(title, items)
        % create a section struct.
            s = struct('title', title, 'items', {cellstr(items)});
        end

        function ordered = resolve(sections, allDocs)
        % expand +package entries and match against parsed docs.
        % returns a struct array of sections, each with title and items
        % (struct array of parsed docs in order).

            allNames = string({allDocs.fullName});
            placed = false(size(allNames)); % track which docs are placed

            ordered = struct('title', {}, 'items', {});

            for ii = 1:numel(sections)
                sec = sections(ii);
                sectionItems = [];

                for jj = 1:numel(sec.items)
                    entry = string(sec.items{jj});

                    if startsWith(entry, "+")
                        % package expansion — find all classes in this package
                        pkg = extractAfter(entry, 1) + ".";
                        mask = startsWith(allNames, pkg) & ~placed;
                        % exclude items that belong to a deeper sub-package
                        % e.g., "+ic.table" should match ic.table.Column
                        % but not ic.table.sub.Something
                        remaining = extractAfter(allNames(mask), strlength(pkg));
                        shallow = ~contains(remaining, ".");
                        shallowIdx = find(mask);
                        shallowIdx = shallowIdx(shallow);

                        % sort alphabetically
                        [~, sortOrder] = sort(allNames(shallowIdx));
                        expandedIdx = shallowIdx(sortOrder);

                        for kk = 1:numel(expandedIdx)
                            idx = expandedIdx(kk);
                            if ~placed(idx)
                                sectionItems = [sectionItems, allDocs(idx)]; %#ok<AGROW>
                                placed(idx) = true;
                            end
                        end
                    else
                        % exact match
                        idx = find(allNames == entry, 1);
                        if ~isempty(idx) && ~placed(idx)
                            sectionItems = [sectionItems, allDocs(idx)]; %#ok<AGROW>
                            placed(idx) = true;
                        end
                    end
                end

                if ~isempty(sectionItems)
                    ordered(end + 1) = struct( ...
                        'title', sec.title, ...
                        'items', sectionItems); %#ok<AGROW>
                end
            end

            % catch-all: items not placed in any section
            unplaced = find(~placed);
            if ~isempty(unplaced)
                % filter out hidden items
                visible = [];
                for kk = 1:numel(unplaced)
                    if ~allDocs(unplaced(kk)).hidden
                        visible = [visible, allDocs(unplaced(kk))]; %#ok<AGROW>
                    end
                end
                if ~isempty(visible)
                    ordered(end + 1) = struct( ...
                        'title', "Other", ...
                        'items', visible);
                end
            end
        end

    end
end

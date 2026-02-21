classdef FilterTree < ic.TreeBase
    % > FILTERTREE Tree with client-side tag-based filtering.
    %
    %   Displays a SearchBar above a Tree view. Typing filter tags
    %   narrows the visible tree using prefix-based operators:
    %     (none) = contains, | = OR, ~ = NOT, : = folder-only,
    %     @ = leaf-only, = = exact, / = ancestor path, ^ = starts-with
    %
    %   Example:
    %       ft = ic.FilterTree();
    %       root = ic.tree.Node("Root");
    %       src  = root.add("src");
    %       src.add("main.m");
    %       src.add("util.m");
    %       root.add("README.md");
    %       ft.Items = root;

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > PLACEHOLDER text shown in the search bar when empty
        Placeholder string = "Search..."
        % > CLEARABLE whether the search bar can be cleared via X button
        Clearable logical = true
        % > SELECTABLE whether tree items can be selected
        Selectable logical = true
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > HEIGHT height of the tree panel (number for px, or CSS string)
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400
        % > SHOWLINE whether to display tree connector lines
        ShowLine logical = true
        % > LAZYLOAD when true, child nodes rendered on demand
        LazyLoad logical = true
        % > CASESENSITIVE whether filtering is case-sensitive
        CaseSensitive logical = false
        % > AUTOEXPAND auto-expand ancestors of matching nodes during filter
        AutoExpand logical = true
    end

    properties (SetObservable, AbortSet, Description = "Reactive", ...
            Access = ?ic.mixin.Reactive, Hidden)
        % > SEARCHVALUE current filter tags (Svelte bridge — hidden from user)
        SearchValue string = string.empty
    end

    events (Description = "Reactive")
        % > SEARCHCHANGED fires when the filter tags change
        SearchChanged
    end

    methods
        function this = FilterTree(props)
            arguments
                props.?ic.FilterTree
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TreeBase(props);
        end

        function set.SearchValue(this, val)
            if isscalar(val) && val == ""
                val = string.empty;
            end
            this.SearchValue = val;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the search input
            out = this.publish("focus", []);
        end

        function out = clearSearch(this)
            % > CLEARSEARCH programmatically clear all filter tags
            this.SearchValue = string.empty;
            out = this.publish("clearSearch", []);
        end
    end
end

classdef FilterTree < ic.TreeBase & ic.mixin.HasContextMenu
    % tree with client-side tag-based filtering.
    % Displays a #ic.SearchBar above a #ic.Tree view. Typing filter tags narrows the visible tree using prefix-based operators: (none)=contains, |=OR, ~=NOT, :=folder-only, @=leaf-only, ==exact, /=ancestor path, ^=starts-with.
    % {/superclass}

    properties (SetObservable, AbortSet, Description = "Reactive")
        % ghost text shown in the search bar when empty
        Placeholder string = "Search..."

        % whether to display an "x" button to clear the search input when pressed
        Clearable logical = true

        % whether tree items can be selected
        Selectable logical = true

        % size of the control relative to its font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % height of the tree panel, in pixels or a CSS size string
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400

        % whether to display tree connector lines
        ShowLine logical = true

        % when true, child nodes rendered on demand
        LazyLoad logical = true

        % whether filtering is case-sensitive
        CaseSensitive logical = false

        % auto-expand ancestors of matching nodes during filter
        AutoExpand logical = true
    end

    properties (SetObservable, Description = "Reactive")
        % context menu entries for leaf nodes
        LeafContextMenu ic.menu.Entry = ic.menu.Entry.empty

        % context menu entries for folder nodes
        FolderContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % active filter tags as a string array. Each tag is an optional operator prefix followed by a search term. See #ic.FilterTree for supported operators.
        SearchValue string = string.empty
    end

    events (Description = "Reactive")
        % fires when the filter tags change
        % {payload}
        % value | cell[]: current filter tags
        % {/payload}
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
            % programmatically focus the search input
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("focus", []);
        end

        function out = clearSearch(this)
            % programmatically clear all filter tags
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            this.SearchValue = string.empty;
            out = this.publish("clearSearch", []);
        end
    end
end

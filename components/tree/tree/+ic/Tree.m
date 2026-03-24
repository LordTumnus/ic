classdef Tree < ic.TreeBase & ic.mixin.HasContextMenu
    % vertical tree view for displaying hierarchical data.
    % Renders items as an indented tree with expand/collapse. Optionally supports multi-selection with checkboxes. Items are #ic.tree.Node objects, and they are classified as folders if they have non-empty #ic.tree.Node.Children arrays; and leafs otherwise

    properties (SetObservable, AbortSet, Description = "Reactive")
        % size of the control, relative to its font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % whether checkboxes are shown for selection
        Selectable logical = true

        % height of the tree, in pixels or a CSS size string
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400

        % whether to display tree connector lines between nodes
        ShowLine logical = true

        % when true, child nodes are only rendered when their parent is expanded; when false, all nodes are pre-rendered in the DOM
        LazyLoad logical = true
    end

    properties (SetObservable, Description = "Reactive")
        % context menu entries for leaf nodes
        LeafContextMenu ic.menu.Entry = ic.menu.Entry.empty

        % context menu entries for folder nodes
        FolderContextMenu ic.menu.Entry = ic.menu.Entry.empty
    end

    methods
        function this = Tree(props)
            arguments
                props.?ic.Tree
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TreeBase(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the tree container
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("focus", []);
        end
    end
end

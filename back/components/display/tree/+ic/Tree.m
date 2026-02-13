classdef Tree < ic.tree.TreeBase
    % > TREE Vertical tree view for displaying hierarchical data.
    %
    %   Renders items as a vertical, indented tree with expand/collapse.
    %   Optionally supports multi-selection with checkboxes.
    %   Items are ic.tree.Node objects; selection is done via Node handles.
    %
    %   Example:
    %       t = ic.Tree();
    %       fruits = ic.tree.Node("Fruits", Icon=ic.IconType.lucide("apple"));
    %       apple  = fruits.add("Apple");
    %       citrus = fruits.add("Citrus");
    %       orange = citrus.add("Orange");
    %       lemon  = citrus.add("Lemon");
    %       t.Items = fruits;
    %
    %       % Selection (when Selectable is true):
    %       t.Selection = [apple, lemon];
    %
    %       % Expand / collapse:
    %       t.expandAll();
    %       t.collapseNode(citrus);

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > SELECTABLE whether checkboxes are shown for selection
        Selectable logical = true
        % > HEIGHT height of the tree (number for px, or CSS string like "100%")
        Height {ic.check.CssValidators.mustBeSize(Height)} = 400
        % > SHOWLINE whether to display tree connector lines between nodes
        ShowLine logical = true
    end

    methods
        function this = Tree(props)
            arguments
                props.?ic.Tree
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tree.TreeBase(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the tree container
            out = this.publish("focus", []);
        end
    end
end

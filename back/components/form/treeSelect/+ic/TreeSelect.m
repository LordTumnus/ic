classdef TreeSelect < ic.tree.TreeBase
    % > TREESELECT Hierarchical multi-value selector with cascading menus.
    %
    %   Displays selected items as closable tags inside the input field.
    %   Opens cascading sub-menus for hierarchical item selection.
    %   Items are ic.tree.Node objects; selection is done via Node handles.
    %
    %   Example:
    %       ts = ic.TreeSelect();
    %       fruits = ic.tree.Node("Fruits", Icon=ic.IconType.lucide("apple"));
    %       apple  = fruits.add("Apple");
    %       citrus = fruits.add("Citrus");
    %       orange = citrus.add("Orange");
    %       lemon  = citrus.add("Lemon");
    %       ts.Items = fruits;
    %       ts.Selection = [apple, lemon];
    %
    %       % Incremental operations:
    %       ts.addNode(citrus, "Grape");
    %       ts.removeNode(orange);
    %       ts.updateNode(apple, Label="Green Apple");

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > PLACEHOLDER text shown when no items are selected
        Placeholder string = "Select..."
        % > CLEARABLE whether all selections can be cleared via an X button
        Clearable logical = false
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"
        % > MAXPOPUPHEIGHT maximum height of the dropdown (number for px, or CSS string)
        MaxPopupHeight {ic.check.CssValidators.mustBeSize(MaxPopupHeight)} = 200
        % > MAXPANELWIDTH maximum width of each cascade panel (number for px, or CSS string)
        MaxPanelWidth {ic.check.CssValidators.mustBeSize(MaxPanelWidth)} = 240
        % > OPENONHOVER whether hovering a folder row auto-opens its sub-panel
        OpenOnHover logical = false
    end

    events (Description = "Reactive")
        % > OPENED fires when the dropdown opens
        Opened
        % > CLOSED fires when the dropdown closes
        Closed
    end

    methods
        function this = TreeSelect(props)
            arguments
                props.?ic.TreeSelect
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tree.TreeBase(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the input field
            out = this.publish("focus", []);
        end

        function out = open(this)
            % > OPEN programmatically open the dropdown
            out = this.publish("open", []);
        end

        function out = close(this)
            % > CLOSE programmatically close the dropdown
            out = this.publish("close", []);
        end
    end
end

classdef TreeSelect < ic.TreeBase
    % hierarchical multi-value selector with cascading menus.
    % Opens cascading sub-menus for hierarchical item selection; and displays selected items as closable tags inside the input field.
    % {properties}
    % #ic.TreeBase
    % {/properties}

    properties (SetObservable, AbortSet, Description = "Reactive")
        % text shown when no items are selected
        Placeholder string = "Select..."

        % whether an "x" icon appears on the input field, allowing the user to clear all selected items with one click
        Clearable logical = false

        % dimension of the component relative to the font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"

        % maximum height of the dropdown, in pixels or as a CSS string. Content that exceeds this height will cause the dropdown to scroll.
        MaxPopupHeight {ic.check.CssValidators.mustBeSize(MaxPopupHeight)} = 200

        % maximum width of each cascade panel, in pixels or as a CSS string. Panels that exceed this width will truncate content with an ellipsis.
        MaxPanelWidth {ic.check.CssValidators.mustBeSize(MaxPanelWidth)} = 240

        % whether hovering a folder row auto-opens its sub-panel
        OpenOnHover logical = false
    end

    events (Description = "Reactive")
        % fires when the dropdown opens
        Opened

        % fires when the dropdown closes
        Closed
    end

    methods
        function this = TreeSelect(props)
            arguments
                props.?ic.TreeSelect
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.TreeBase(props);
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the input field
            out = this.publish("focus", []);
        end

        function out = open(this)
            % programmatically open the dropdown
            out = this.publish("open", []);
        end

        function out = close(this)
            % programmatically close the dropdown
            out = this.publish("close", []);
        end
    end
end

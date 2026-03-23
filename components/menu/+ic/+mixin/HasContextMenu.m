classdef (Abstract) HasContextMenu < handle
    % mixin that adds a ContextMenuAction event to a component.
    % Any component inheriting this mixin gets the event bridged automatically by the IC framework. The event payload varies by consumer


    events (Description = "Reactive")
        % fires when the user clicks a context menu item.
        % {payload}
        % item | char: the Key of the selected #ic.menu.Item, or "key:value" for #ic.menu.ColorEntry / #ic.menu.TextEntry
        % {/payload}
        ContextMenuAction
    end
end

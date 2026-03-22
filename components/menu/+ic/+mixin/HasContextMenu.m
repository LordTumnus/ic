classdef (Abstract) HasContextMenu < handle
    % > HASCONTEXTMENU Mixin that adds a ContextMenuAction reactive event.
    %
    %   Any component inheriting this mixin gets the ContextMenuAction event
    %   bridged automatically by the IC framework (no manual subscribe/publish).
    %
    %   Usage:
    %       classdef MyComponent < ic.core.Component & ic.mixin.HasContextMenu
    %
    %   The event payload varies by consumer:
    %     Table:  struct with fields item, field, rowIndex
    %     Tree:   struct with fields item, nodeKey  (future)

    events (Description = "Reactive")
        % > CONTEXTMENUACTION fires when the user clicks a context menu item
        ContextMenuAction
    end
end

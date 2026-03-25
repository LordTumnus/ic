classdef DragDropTest < ic.core.Component
    % diagnostic component for testing drag-and-drop inside MATLAB's CEF sandbox.
    % Renders two side-by-side bins of colored cards that can be dragged within
    % and between bins. Uses [svelte-dnd-action](https://github.com/isaacHagoel/svelte-dnd-action)  to bypass the HTML5 DnD events block by MATLAB

    properties (SetObservable, AbortSet, Description = "Reactive")
        % items in the left bin; each element must have id, name, and color fields
        ListA (:,1) struct = struct( ...
            'id',    {1;   2;   3;   4}, ...
            'name',  {"Alpha"; "Bravo"; "Charlie"; "Delta"}, ...
            'color', {"#3b82f6"; "#ef4444"; "#22c55e"; "#f59e0b"})

        % items in the right bin; same struct schema as ListA
        ListB (:,1) struct = struct( ...
            'id',    {5;   6;   7;   8}, ...
            'name',  {"Echo"; "Foxtrot"; "Golf"; "Hotel"}, ...
            'color', {"#8b5cf6"; "#ec4899"; "#14b8a6"; "#f97316"})

        % whether dragging is disabled
        Disabled logical = false
    end

    events (Description = "Reactive")
        % fires when items are reordered within a bin or moved between bins
        % {payload}
        % value | struct: struct with fields listA and listB, each a cell array of structs with id, name, color
        % {/payload}
        OrderChanged
    end

    methods
        function this = DragDropTest(props)
            arguments
                props.?ic.internal.DragDropTest
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end
end

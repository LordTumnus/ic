classdef DragDropTest < ic.core.Component
    % DRAGDROPTEST  Diagnostic component for testing drag-and-drop in CEF.
    %
    %   Uses svelte-dnd-action (mouse-based, not HTML5 DnD) to verify
    %   drag-and-drop works inside MATLAB's Chromium 104 sandbox without
    %   requiring enableDragAndDropAll().
    %
    %   Example:
    %       t = ic.internal.DragDropTest();
    %       f = ic.Frame("Parent", uigridlayout(uifigure()));
    %       f.addChild(t);
    %       t.addlistener('OrderChanged', @(~,e) disp(e.Data));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LISTA items in the left bin (struct array with id, name, color)
        ListA (:,1) struct = struct( ...
            'id',    {1;   2;   3;   4}, ...
            'name',  {"Alpha"; "Bravo"; "Charlie"; "Delta"}, ...
            'color', {"#3b82f6"; "#ef4444"; "#22c55e"; "#f59e0b"})
        % > LISTB items in the right bin (struct array with id, name, color)
        ListB (:,1) struct = struct( ...
            'id',    {5;   6;   7;   8}, ...
            'name',  {"Echo"; "Foxtrot"; "Golf"; "Hotel"}, ...
            'color', {"#8b5cf6"; "#ec4899"; "#14b8a6"; "#f97316"})
        % > DISABLED whether dragging is disabled
        Disabled logical = false
    end

    events (Description = "Reactive")
        % > ORDERCHANGED fires when items are reordered or moved between lists
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

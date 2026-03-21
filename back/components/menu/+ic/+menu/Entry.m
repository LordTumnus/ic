classdef (Abstract) Entry < matlab.mixin.Heterogeneous & matlab.mixin.SetGetExactNames & ic.event.TransportData
    % > ENTRY Abstract base for context menu entries.
    %
    %   Enables heterogeneous arrays so Item, Separator, and Folder
    %   can be mixed:  [Item("a"), Separator(), Folder(Label="Sub")]
    %
    %   Subclasses: ic.menu.Item, ic.menu.Separator, ic.menu.Folder,
    %              ic.menu.ColorEntry, ic.menu.TextEntry

    methods (Abstract)
        s = toStruct(this)
    end

    methods (Sealed)
        function json = jsonencode(this, varargin)
            % > JSONENCODE Serialize entry array to JSON via struct conversion.
            n = numel(this);
            if n == 0, json = '[]'; return; end
            c = cell(1, n);
            for i = 1:n, c{i} = this(i).toStruct(); end
            json = jsonencode(c, varargin{:});
        end
    end

    methods (Static, Sealed, Access = protected)
        function obj = getDefaultScalarElement
            obj = ic.menu.Item("");
        end
    end
end

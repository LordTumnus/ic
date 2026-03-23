classdef (Abstract) Entry < matlab.mixin.Heterogeneous & ...
                            matlab.mixin.SetGetExactNames & ...
                            ic.event.TransportData
    % abstract base class for context menu entries.
    % Enables heterogeneous arrays so different entry types can be mixed.

    methods (Abstract)
        % serialize this entry to a struct for JSON transport
        s = toStruct(this)
    end

    methods (Sealed)
        function json = jsonencode(this, varargin)
            % serialize the entry array to JSON via struct conversion
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

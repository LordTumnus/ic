% > MEVENT is an event notified by a component when the view changes
classdef MEvent < event.EventData
    properties (Access = public)
        % > DATA any information coming from the view
        Data % any
    end


    methods
        function this = MEvent(data)
            this.Data = data;
        end
    end
end


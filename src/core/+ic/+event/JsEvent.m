% > JSEVENT is a JavaScript event that can be used to communicate with the view

% > EVENT object containing the information transferred between the model and the view
classdef JsEvent < handle & matlab.mixin.Heterogeneous
    properties (Access = public)
        % > COMPONENT the component throwing the event
        ComponentID string
        % > NAME name of the event
        Name string
        % > DATA any information transferred in the event
        Data % any
    end

    properties (SetAccess = private)
        % > ID the identifier of the event
        Id string
    end

    methods
        function this = JsEvent(componentId, name, data)
            % > JSEVENT constructs a JavaScript event
            arguments
                componentId (1,1) string
                name (1,1) string
                data % any
            end
            this.ComponentID = componentId;
            this.Name = name;
            this.Data = data;
            this.Id = matlab.lang.internal.uuid();
        end

        function json = jsonencode(this, varargin)
            % > JSONENCODE converts the event into a JSON text object that can be shared with the view
            obj = struct(...
                "component", this.ComponentID, ...
                "name", this.Name, ...
                "data", this.Data, ...
                "id", this.Id);
            json = jsonencode(obj, varargin{:});
        end
    end

    methods (Sealed, Hidden)
        function tf = eq(varargin)
            tf = eq@handle(varargin{:});
        end
    end
end

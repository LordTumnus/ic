classdef JsEvent < handle & matlab.mixin.Heterogeneous

    properties (Access = public)
        ComponentID string
        Name string
        Data % any
    end

    properties (SetAccess = private)
        Id string
    end

    methods
        function this = JsEvent(componentId, name, data)
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
            obj = struct( ...
                "component", this.ComponentID, ...
                "name", this.Name, ...
                "id", this.Id);
            obj.data = this.Data;
            json = jsonencode(obj, varargin{:});
        end
    end

    methods (Sealed, Hidden)
        function tf = eq(varargin)
            tf = eq@handle(varargin{:});
        end
    end
end

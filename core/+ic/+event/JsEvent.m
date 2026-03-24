classdef JsEvent < handle & matlab.mixin.Heterogeneous
   % wire-format event for all MATLAB-to-Svelte communication.
   % Carries information about the component publishing the event, the event name, payload data.

   properties (Access = public)
      % target component #ic.core.ComponentBase.ID
      ComponentID string

      % event name
      Name string

      % event payload
      Data % any
   end

   properties (SetAccess = private)
      % unique event identifier (uuid), used for request/response correlation when the frontend responds to this event.
      Id string
   end

   methods
      function this = JsEvent(componentId, name, data)
         arguments
            % target component ID
            componentId (1,1) string
            % event name
            name (1,1) string
            % event payload
            data % any
         end
         this.ComponentID = componentId;
         this.Name = name;
         this.Data = data;
         this.Id = matlab.lang.internal.uuid();
      end

      function s = toStruct(this)
         % convert to a plain struct for bridge transport.
         % {returns} struct with fields: component, name, id, data; or cell array of structs {/returns}
         if ~isscalar(this)
            s = cell(1, numel(this));
            for ii = 1:numel(this)
               s{ii} = this(ii).toStruct();
            end
            return
         end
         s = struct( ...
             'component', this.ComponentID, ...
             'name', this.Name, ...
             'id', this.Id);
         s.data = this.Data;
      end

      function json = jsonencode(this, varargin)
         % encode as JSON string; arrays produce a JSON array.
         % Data is assigned after the struct to avoid field-name restrictions
         % when Data differs across elements.
         if ~isscalar(this)
            parts = strings(1, numel(this));
            for ii = 1:numel(this)
               parts(ii) = jsonencode(this(ii), varargin{:});
            end
            json = char("[" + join(parts, ",") + "]");
            return;
         end
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

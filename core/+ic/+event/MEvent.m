classdef MEvent < event.EventData
   % event data wrapper for frontend-originated component events.
   % When a reactive event fires on the Svelte side, #ic.mixin.Reactive re-notifies it as a MATLAB event via notify().


   properties (Access = public)
      % payload delivered by the frontend event
      Data % any
   end

   methods
      function this = MEvent(data)
         % wrap a frontend payload as event data.
         this.Data = data;
      end
   end
end

classdef JsEffect < handle
   % handle to a frontend reactive effect created via #ic.core.ComponentBase.jsEffect()

   properties (SetAccess = private)
      % unique identifier for this effect
      ID string

      % the component that owns this effect
      Owner ic.core.ComponentBase

      % boolean flag that indicates whether this effect has been removed from the frontend effect manager.
      IsRemoved logical = false
   end

   methods
      function this = JsEffect(id, owner)
         arguments
            % unique effect identifier (uuid)
            id (1,1) string
            % component that created the effect via jsEffect()
            owner (1,1) ic.core.ComponentBase
         end
         this.ID = id;
         this.Owner = owner;
      end

      function remove(this)
         % stop and remove this effect from the frontend effect manager.
         if ~this.IsRemoved && isvalid(this.Owner)
            this.Owner.publish("@jsEffectRemove", struct("id", this.ID));
            this.IsRemoved = true;
         end
      end

      function delete(this)
         % clean up the frontend effect when this MATLAB handle is destroyed.
         try
            this.remove();
         catch
            % silently ignore since it may already be destroyed
         end
      end
   end
end

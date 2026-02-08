classdef JsEffect < handle
    % > JSEFFECT handle to a frontend reactive effect.
    % Returned by ComponentBase.jsEffect(). Call remove() to clean up.

    properties (SetAccess = private)
        ID string
        Owner ic.core.ComponentBase
        IsRemoved logical = false
    end

    methods
        function this = JsEffect(id, owner)
            arguments
                id (1,1) string
                owner (1,1) ic.core.ComponentBase
            end
            this.ID = id;
            this.Owner = owner;
        end

        function remove(this)
            % > REMOVE stops and removes this effect from the frontend
            if ~this.IsRemoved && isvalid(this.Owner)
                this.Owner.publish("@jsEffectRemove", struct("id", this.ID));
                this.IsRemoved = true;
            end
        end

        function delete(this)
            % > DELETE cleanup on MATLAB object deletion
            try
                this.remove();
            catch
                % Silently ignore — Owner may already be destroyed
            end
        end
    end
end

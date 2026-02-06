classdef JsEffect < handle
    % > JSEFFECT handle to a frontend reactive effect.
    % Returned by Frame.jsEffect(). Call remove() to clean up.

    properties (SetAccess = private)
        ID string
        Frame ic.Frame
        IsRemoved logical = false
    end

    methods
        function this = JsEffect(id, frame)
            arguments
                id (1,1) string
                frame (1,1) ic.Frame
            end
            this.ID = id;
            this.Frame = frame;
        end

        function remove(this)
            % > REMOVE stops and removes this effect from the frontend
            if ~this.IsRemoved && isvalid(this.Frame)
                this.Frame.publish("@jsEffectRemove", struct("id", this.ID));
                this.IsRemoved = true;
            end
        end

        function delete(this)
            % > DELETE cleanup on MATLAB object deletion
            try
                this.remove();
            catch
                % Silently ignore — Frame may already be destroyed
            end
        end
    end
end

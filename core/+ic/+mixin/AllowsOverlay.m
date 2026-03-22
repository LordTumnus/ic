% > ALLOWSOVERLAY mixin that grants a container the addOverlay method.
classdef (Abstract) AllowsOverlay < handle

    methods (Abstract, Access = {?ic.core.Container, ?ic.mixin.AllowsOverlay})
        insertChild
    end

    methods (Access = public)
        function addOverlay(this, child)
            % > ADDOVERLAY inserts a child into the implicit "overlay" target.
            % Only components inheriting ic.mixin.Overlay are accepted.
            arguments
                this
                child ic.core.Component
            end
            if ~isa(child, 'ic.mixin.Overlay')
                error("ic:AllowsOverlay:InvalidChild", ...
                    "Only overlay components can be added via addOverlay. " + ...
                    "'%s' does not inherit from ic.mixin.Overlay.", class(child));
            end
            this.insertChild(child, "overlay");
        end
    end

end

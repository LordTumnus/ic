classdef (Abstract) AllowsOverlay < handle
    % grants a container the ability to host overlay components in the "overlay" target.

    methods (Abstract, Access = {?ic.core.Container, ?ic.mixin.AllowsOverlay})
        insertChild
    end

    methods (Access = public)
        function addOverlay(this, child)
            % inserts a child into the implicit "overlay" target.
            % Only components inheriting #ic.mixin.Overlay are accepted.
            arguments
                this
                % component to insert as an overlay
                child ic.core.Component
            end
            if ~isa(child, 'ic.mixin.Overlay')
                error("ic:AllowsOverlay:InvalidChild", ...
                    "Only overlay components can be added via addOverlay. " + ...
                    "'%s' does not inherit from ic.mixin.Overlay.", class(child));
            end
            this.insertChild(child);
        end
    end

end

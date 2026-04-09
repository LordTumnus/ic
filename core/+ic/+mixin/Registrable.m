classdef (Abstract) Registrable < handle
    % tree-walking registration and deregistration of components in the #ic.Frame registry.
    % When a component is inserted into or removed from a container, this mixin recursively registers or deregisters the subtree for O(1) event dispatch.

    methods (Access = protected)
        function registerSubtree(this, component)
            % registers a component and all its descendants in the #ic.Frame registry.
            if isa(this, "ic.core.Component")
                frame = this.getFrame(); %#ok<MCNPN>
            else
                frame = [];
            end
            if ~isempty(frame)
                ic.mixin.Registrable.registerSubtreeWithFrame(component, frame);
            end
        end

        function deregisterSubtree(this, component)
            % removes a component and all its descendants from the #ic.Frame registry.
            if isa(this, "ic.core.Component")
                frame = this.getFrame(); %#ok<MCNPN>
            else
                frame = [];
            end
            if ~isempty(frame)
                ic.mixin.Registrable.deregisterSubtreeWithFrame(component, frame);
            end
        end
    end

    methods (Access = protected, Static)
        function registerSubtreeWithFrame(component, frame)
            % recursively registers a component and its descendants using the given #ic.Frame.
            frame.registerDescendant(component);
            if isa(component, "ic.core.Container")
                for ii = 1:numel(component.Children)
                    ic.mixin.Registrable.registerSubtreeWithFrame(...
                        component.Children(ii), frame);
                end
            end
        end

        function deregisterSubtreeWithFrame(component, frame)
            % recursively deregisters a component and its descendants using the given #ic.Frame.
            try
                frame.deregisterDescendant(component.ID);
                if isa(component, "ic.core.Container")
                    for ii = 1:numel(component.Children)
                        ic.mixin.Registrable.deregisterSubtreeWithFrame(...
                            component.Children(ii), frame);
                    end
                end
            catch
                % silently ignore errors during destruction
            end
        end
    end

end

% > REGISTRABLE mixin providing Frame registry operations for containers.
%
% When a component is inserted into a container, it must be registered
% with the root Frame for O(1) event dispatch. This mixin encapsulates
% the tree-walking registration and deregistration logic.
classdef (Abstract) Registrable < handle

    methods (Access = protected)
        function registerSubtree(this, component)
            % > REGISTERSUBTREE registers a component and all its
            % descendants in the Frame registry.
            if isa(this, "ic.core.Component")
                frame = this.getFrame(); %#ok<MCNPN>
            else
                frame = [];
            end
            if ~isempty(frame)
                ic.mixin.Registrable.registerSubtreeWithFrame(component, frame);
                % Also register static children added before attachment
                if isa(component, "ic.core.Container")
                    for child = component.Children
                        if child.IsStatic
                            ic.mixin.Registrable.registerSubtreeWithFrame(child, frame);
                        end
                    end
                end
            end
        end

        function deregisterSubtree(this, component)
            % > DEREGISTERSUBTREE removes a component and all its
            % descendants from the Frame registry.
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
            % > REGISTERSUBTREEWITHFRAME registers a component and its
            % descendants using the given Frame.
            frame.registerDescendant(component);
            if isa(component, "ic.core.Container")
                for ii = 1:numel(component.Children)
                    ic.mixin.Registrable.registerSubtreeWithFrame(...
                        component.Children(ii), frame);
                end
            end
        end

        function deregisterSubtreeWithFrame(component, frame)
            % > DEREGISTERSUBTREEWITHFRAME deregisters a component and its
            % descendants using the given Frame.
            try
                frame.deregisterDescendant(component.ID);
                if isa(component, "ic.core.Container")
                    for ii = 1:numel(component.Children)
                        ic.mixin.Registrable.deregisterSubtreeWithFrame(...
                            component.Children(ii), frame);
                    end
                end
            catch
                % Silently ignore errors during destruction
            end
        end
    end

end

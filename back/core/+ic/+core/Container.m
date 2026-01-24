% > CONTAINER base class for component containers
classdef Container < handle

    properties (SetAccess = private)
        % > Children list of components that are held by the container
        Children ic.core.Component
    end

    properties
        % > TARGETS the list of possible targets for the container's children
        Targets string = string.empty()
    end

    methods
        function delete(this)
            % DELETE invalidates the container and also deletes its children
            arguments (Input)
                % > THIS the container
                this (1,1) ic.core.Container
            end
            delete(this.Children);
        end
    end

    methods (Access = ?ic.core.Component, Hidden)

        function addChild(this, child)
            % > ADDCHILD inserts a new child inside the container. Used by the component whenever its parent property is reassigned
            this.Children(end + 1) = child;

            % register the child and its subtree in the Frame registry
            this.registerSubtree(child);

            % flush the queue into the parent
            child.flush();
        end

        function removeChild(this, child)
            % > REMOVECHILD removes a component from the list of children
            if isempty(this.Children)
                return;
            end
            childIDs = [this.Children.ID];
            mask = childIDs == child.ID;
            if any(mask)
                this.Children(mask) = [];
                this.deregisterSubtree(child);
            end
        end
    end

    methods (Access = protected)
        function registerSubtree(this, component)
            % > REGISTERSUBTREE registers a component and all its descendants in the Frame registry
            % > note: Finds Frame once and passes it down for efficiency
            if isa(this, "ic.core.Component")
                frame = this.getFrame(); %#ok<MCNPN>
            else
                frame = [];
            end
            if ~isempty(frame)
                this.registerSubtreeWithFrame(component, frame);
            end
        end

        function deregisterSubtree(this, component)
            % > DEREGISTERSUBTREE removes a component and all its descendants from the Frame registry
            % > note: Finds Frame once and passes it down for efficiency
            if isa(this, "ic.core.Component")
                frame = this.getFrame(); %#ok<MCNPN>
            else
                frame = [];
            end
            if ~isempty(frame)
                this.deregisterSubtreeWithFrame(component, frame);
            end
        end
    end

    methods (Access = protected, Static)
        function registerSubtreeWithFrame(component, frame)
            % > REGISTERSUBTREEWITHFRAME registers a component and its descendants using the given Frame
            frame.registerDescendant(component);
            if isa(component, "ic.core.Container")
                for ii = 1:numel(component.Children)
                    ic.core.Container.registerSubtreeWithFrame(...
                        component.Children(ii), frame);
                end
            end
        end

        function deregisterSubtreeWithFrame(component, frame)
            % > DEREGISTERSUBTREEWITHFRAME deregisters a component and its descendants using the given Frame
            % Note: try-catch handles edge cases during cascading deletes where
            % components may become invalid before deregistration completes
            try
                frame.deregisterDescendant(component.ID);
                if isa(component, "ic.core.Container")
                    for ii = 1:numel(component.Children)
                        ic.core.Container.deregisterSubtreeWithFrame(...
                            component.Children(ii), frame);
                    end
                end
            catch
                % Silently ignore errors during destruction - component already invalid
            end
        end
    end

end

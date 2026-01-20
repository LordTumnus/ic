% > CONTAINER base class for component containers
classdef Container < handle

    properties (SetAccess = private)
        % > Children list of components that are held by the container
        Children ic.core.Component
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


    methods (Access = public)
        function out = find(this, fn)
            % > FIND uses the breadth first traversal method to find the first descendant of the container that evaluates the test function to true
            arguments (Input)
                % > THIS the container
                this (1,1) ic.core.Container
                % > FN predicate that returns a single logical argument that determines whether a descendant passes or not the test
                fn (1,1) function_handle
            end
            arguments (Output)
                % > OUT the first descendant that satisfies the test function
                out ic.core.ComponentBase {mustBeScalarOrEmpty}
            end

            % check for the container itseld
            if fn(this)
                out = this;
                return
            end
            % initialize the queue with the direct children of the container
            queue = this.Children;
            while ~isempty(queue)
                % evaluate the predicate and return if true
                if fn(queue(1))
                    out = queue(1);
                    return;
                end
                % push children (if any)
                if isa(queue(1),"ic.core.Container")
                    children = queue(1).Children;
                    queue((end+1):(end+numel(children))) = children;
                end
                % pop visited component from queue
                queue(1) = [];
            end
            out = ic.core.ComponentBase.empty();
        end
    end

    methods (Access = ?ic.core.Component, Hidden)

        function addChild(this, child)
            % > ADDCHILD inserts a new child inside the container. Used by the component whenever its parent property is reassigned
            this.Children(end + 1) = child;

            data = struct("type", class(child), "id", child.ID);
            this.publish("@insert", data); %#ok<MCNPN>

            % register the child and its subtree in the Frame registry
            this.registerSubtree(child);

            % flush the queue into the parent
            child.flush();
        end

        function removeChild(this, child)
            % > REMOVECHILD removes a component from the list of children
            if isvalid(child) && any([this.Children.ID] == child.ID)
                this.Children([this.Children.ID] == child.ID) = [];
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
            frame.deregisterDescendant(component.ID);
            if isa(component, "ic.core.Container")
                for ii = 1:numel(component.Children)
                    ic.core.Container.deregisterSubtreeWithFrame(component.Children(ii), frame);
                end
            end
        end
    end

end

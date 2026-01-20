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

    methods (Access = private, Hidden)
        function safeFn(this, fn, varargin)
            % > SAFEFCN only evaluates the second input if the container is a valid object
            if this.isvalid()
                fn(varargin{:});
            end
        end
    end

    methods (Access = ?ic.Component, Hidden)

        function removeChild(this, child)
            % > REMOVECHILD removes a component from the list of children
            this.Children([this.Children.ID] == child.ID) = [];
        end

        function addChild(this, child)
            % > ADDCHILD inserts a new child inside the container. Used by the component whenever its parent property is reassigned
            this.Children(end + 1) = child;
            addlistener(child, "ObjectBeingDestroyed", ...
                @(src,~) this.safeFn(@(x) this.removeChild(x), src));

            % parent sends event to insert child
            if ~contains(child.ID, "/")
                data =  struct("type", class(child), "id", child.ID);
                this.publish("@ic.insert", data);
            end

            % flush the queue into the parent
            child.flush();
        end
    end


end

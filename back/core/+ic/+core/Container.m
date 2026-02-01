% > CONTAINER base class for component containers
classdef Container < handle

    properties (SetAccess = private)
        % > Children list of components that are held by the container
        Children ic.core.Component
    end

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > TARGETS the list of possible targets for the container's children
        Targets string = "default"
    end

    properties (Access = private)
        % > PREVIOUSTARGETS_ tracks previous targets for detecting removals
        PreviousTargets_ string = "default"
    end

    methods
        function this = Container()
            % > CONTAINER constructor sets up listeners for target changes
            addlistener(this, 'Targets', 'PostSet', @this.onTargetsChanged);
        end

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

        function validateTarget(~, ~)
            % > VALIDATETARGET hook for subclasses to validate target before insertion
            % Override in subclasses to restrict allowed targets.
            % Throw an error to reject the target.
        end

        function target = getDefaultTarget(this)
            % > GETDEFAULTTARGET returns the target to be used when adding a
            % child, if no targets are passed
            if isempty(this.Targets)
                error("ic:Container:noTargetsAvaliable", ...
                    "Container does not specify any target for its children");
            end
            if isscalar(this.Targets)
                target = this.Targets;
            else
                target = this.Targets(1);
            end
        end

        function addChild(this, child, target)
            % > ADDCHILD inserts a new child inside the container. Used by the component whenever its parent property is reassigned
            arguments
                this % ic.core.Container
                child ic.core.Component
                target string {mustBeNonempty} = this.getDefaultTarget()
            end

            % Allow parent to validate/reject the target before insertion
            this.validateTarget(target);

            addlistener(child, "ObjectBeingDestroyed", ...
                @(~,~) this.removeChild(child));

            if ~isempty(child.Parent)
                data = struct(...
                    "id", child.ID, "parent", newParent.ID, "target", target);
                this.publish("@reparent", data); %#ok<MCNPN>
                mask = [child.Parent.Children.ID] == child.ID;
                child.Parent.Children(mask) = [];

                child.Parent = this;
                child.Target = target;
                return;
            end

            % Get child definition via introspection
            definition = child.getComponentDefinition();
            data = struct("component", definition, "target", target);

            % Publish insert child
            this.publish("@insert", data); %#ok<MCNPN>

            child.Parent = this;
            child.Target = target;

            % Store & register child
            this.Children(end + 1) = child;
            this.registerSubtree(child);

            % flush the event queue into the parent
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
                % parent sends an event requesting for removal of the child
                data = struct("id", child.ID);
                this.publish("@remove", data); %#ok<MCNPN>

                child.Parent = [];
                child.Target = string.empty;
            end

        end
    end

    methods (Access = protected)
        function addStaticChild(this, child)
            % > ADDSTATICCHILD declares a child that is pre-rendered in Svelte
            arguments
                this
                child (1,1) ic.core.Component
            end
            % Set parent directly (bypasses setParent which would trigger @insert)
            child.Parent = this;
            child.Target = "static";
            child.IsStatic = true;

            % Add to Children immediately
            this.Children(end+1) = child;
            child.Parent = this;
        end

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
                % Also register static children added before attachment
                if isa(component, "ic.core.Container")
                    for child = component.Children
                        if child.IsStatic
                            this.registerSubtreeWithFrame(child, frame);
                        end
                    end
                end
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

    methods (Access = private)
        function onTargetsChanged(this, ~, ~)
            % > ONTARGETSCHANGED removes children in targets that were removed
            oldTargets = this.PreviousTargets_;
            newTargets = this.Targets;

            % Remove children in removed targets (reverse order for safety)
            removedTargets = setdiff(oldTargets, newTargets);
            if ~isempty(removedTargets)
                children = this.Children;
                for ii = numel(children):-1:1
                    child = children(ii);
                    if ~child.IsStatic && ismember(child.Target_, removedTargets)
                        child.Parent = [];  % Triggers @remove
                    end
                end
            end

            this.PreviousTargets_ = newTargets;
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

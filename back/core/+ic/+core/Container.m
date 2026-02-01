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

        function validateTarget(this, target)
            % > VALIDATETARGET validates target is in this.Targets
            % Override in subclasses for custom validation.
            % Throw an error to reject the target.
            if ~ismember(target, this.Targets)
                error("ic:core:Component:InvalidTarget", ...
                    "Target '%s' is not valid. Valid targets: %s", ...
                    target, strjoin(this.Targets, ", "));
            end
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
                @(~,~) ic.core.Container.safeRemoveChild(this, child));

            if ~isempty(child.Parent)
                oldParent = child.Parent;

                oldFrame = child.getFrame();
                if isa(this, "ic.core.Component")
                    newFrame = this.getFrame();
                else
                    newFrame = [];
                end

                if ~isequal(oldFrame, newFrame)
                    error("ic:core:Component:ReparentingAcrossFrames", ...
                        "Cannot reparent component across different Frames");
                end

                % Old parent publishes reparent event
                data = struct(...
                    "id", child.ID, "parent", this.ID, "target", target);
                oldParent.publish("@reparent", data);

                % Remove from old parent's Children
                mask = [oldParent.Children.ID] == child.ID;
                oldParent.Children(mask) = [];

                % Update child's references
                child.Parent = this;
                child.Target = target;

                % Add to new parent's Children
                this.Children(end + 1) = child;
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
        function addStaticChild(this, child, target)
            % > ADDSTATICCHILD declares a child that is pre-rendered in Svelte
            arguments
                this
                child (1,1) ic.core.Component
                target string
            end

            addlistener(child, "ObjectBeingDestroyed", ...
                @(~,~) ic.core.Container.safeRemoveChild(this, child));

            child.Parent = this;
            child.Target = target;
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

        function safeRemoveChild(container, child)
            % > SAFEREMOVECHILD safely removes a child, checking container validity first
            % Used as listener callback to handle cascading deletes gracefully
            if isvalid(container)
                container.removeChild(child);
            end
        end
    end

end

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

        function validateChild(this, child, target)
            % > VALIDATECHILD validates the child and its target
            % Override in subclasses for custom validation.
            % Throw an error to reject the child or target.
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

            % Allow parent to validate/reject the child before insertion
            this.validateChild(child, target);

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

                addlistener(child, "ObjectBeingDestroyed", ...
                @(~,~) ic.core.Container.safeRemoveChild(this, child));

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

            addlistener(child, "ObjectBeingDestroyed", ...
                @(~,~) ic.core.Container.safeRemoveChild(this, child));

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

        function children = getChildrenInTarget(this, target)
            % > GETCHILDRENINTARGET returns children belonging to a specific target
            arguments
                this
                target string {mustBeNonempty}
            end
            if isempty(this.Children)
                children = ic.core.Component.empty();
            else
                mask = [this.Children.Target] == target;
                children = this.Children(mask);
            end
        end

        function moveChild(this, child, index)
            % > MOVECHILD reorders a child within its target slot
            % > index can be a number (1-based), "start", or "end"
            arguments
                this
                child ic.core.Component
                index = "end"
            end

            % Validate child belongs to this container
            mask = [this.Children.ID] == child.ID;
            assert(any(mask), "ic:Container:ChildNotFound", ...
                "Child component is not in this container");

            % Get target and children in that target
            target = child.Target;
            targetChildren = this.getChildrenInTarget(target);
            numInTarget = numel(targetChildren);

            % Normalize index to numeric (1-based for MATLAB)
            if isstring(index) || ischar(index)
                if index == "start"
                    numericIndex = 1;
                elseif index == "end"
                    numericIndex = numInTarget;
                else
                    error("ic:Container:InvalidIndex", ...
                        "Index must be a number, 'start', or 'end'");
                end
            else
                numericIndex = index;
            end

            % Validate index bounds
            assert(numericIndex >= 1 && numericIndex <= numInTarget, ...
                "ic:Container:IndexOutOfBounds", ...
                "Index %d is out of bounds (1 to %d)", numericIndex, numInTarget);

            % Find current position within target
            targetMask = [targetChildren.ID] == child.ID;
            currentIndex = find(targetMask);

            % Early exit if already at target position
            if currentIndex == numericIndex
                return;
            end

            % Publish reorder event (0-based index for TypeScript)
            data = struct("id", child.ID, "index", numericIndex - 1, "target", target);
            this.publish("@reorder", data); %#ok<MCNPN>

            % Reorder the local Children array
            % Remove child from current position
            this.Children(mask) = [];

            % Find insertion point in full Children array
            % We need to insert at the correct position relative to other
            % children in the same target
            if numericIndex == 1
                % Insert before first child in target
                firstInTarget = targetChildren(1);
                if firstInTarget.ID == child.ID && numInTarget > 1
                    firstInTarget = targetChildren(2);
                end
                insertIdx = find([this.Children.ID] == firstInTarget.ID, 1);
                if isempty(insertIdx)
                    insertIdx = 1;
                end
            else
                % Insert after the child at (numericIndex - 1) position
                % Account for the fact that we removed 'child' from targetChildren
                adjustedIdx = numericIndex;
                if currentIndex < numericIndex
                    adjustedIdx = numericIndex; % Child was before, so indices shift down
                end
                if adjustedIdx > 1
                    targetChildren(targetMask) = [];
                    if adjustedIdx - 1 <= numel(targetChildren)
                        precedingChild = targetChildren(adjustedIdx - 1);
                        insertIdx = find([this.Children.ID] == precedingChild.ID, 1) + 1;
                    else
                        insertIdx = numel(this.Children) + 1;
                    end
                else
                    insertIdx = 1;
                end
            end

            % Insert at new position
            if insertIdx > numel(this.Children)
                this.Children(end + 1) = child;
            else
                this.Children = [this.Children(1:insertIdx-1), child, this.Children(insertIdx:end)];
            end
        end

        function moveChildBefore(this, child, referenceChild)
            % > MOVECHILDBEFORE moves child to the position before referenceChild
            % > Both children must be in the same target
            arguments
                this
                child ic.core.Component
                referenceChild ic.core.Component
            end

            % Validate both children belong to this container
            assert(any([this.Children.ID] == child.ID), ...
                "ic:Container:ChildNotFound", "Child not in container");
            assert(any([this.Children.ID] == referenceChild.ID), ...
                "ic:Container:ChildNotFound", "Reference child not in container");

            % Validate same target
            assert(child.Target == referenceChild.Target, ...
                "ic:Container:TargetMismatch", ...
                "Both children must be in the same target");

            % Find reference child's index in target
            targetChildren = this.getChildrenInTarget(child.Target);
            refIdx = find([targetChildren.ID] == referenceChild.ID);

            % Move child to that index
            this.moveChild(child, refIdx);
        end

        function moveChildAfter(this, child, referenceChild)
            % > MOVECHILDAFTER moves child to the position after referenceChild
            % > Both children must be in the same target
            arguments
                this
                child ic.core.Component
                referenceChild ic.core.Component
            end

            % Validate both children belong to this container
            assert(any([this.Children.ID] == child.ID), ...
                "ic:Container:ChildNotFound", "Child not in container");
            assert(any([this.Children.ID] == referenceChild.ID), ...
                "ic:Container:ChildNotFound", "Reference child not in container");

            % Validate same target
            assert(child.Target == referenceChild.Target, ...
                "ic:Container:TargetMismatch", ...
                "Both children must be in the same target");

            % Find reference child's index in target
            targetChildren = this.getChildrenInTarget(child.Target);
            refIdx = find([targetChildren.ID] == referenceChild.ID);

            % Move child to position after reference (refIdx + 1, clamped to end)
            newIdx = min(refIdx + 1, numel(targetChildren));
            this.moveChild(child, newIdx);
        end

        function swapChildren(this, child1, child2)
            % > SWAPCHILDREN swaps the positions of two children
            % > Both children must be in the same target
            arguments
                this
                child1 ic.core.Component
                child2 ic.core.Component
            end

            % Validate both children belong to this container
            assert(any([this.Children.ID] == child1.ID), ...
                "ic:Container:ChildNotFound", "Child1 not in container");
            assert(any([this.Children.ID] == child2.ID), ...
                "ic:Container:ChildNotFound", "Child2 not in container");

            % Validate same target
            assert(child1.Target == child2.Target, ...
                "ic:Container:TargetMismatch", ...
                "Both children must be in the same target");

            % Get indices in target
            targetChildren = this.getChildrenInTarget(child1.Target);
            idx1 = find([targetChildren.ID] == child1.ID);
            idx2 = find([targetChildren.ID] == child2.ID);

            % Early exit if same child
            if idx1 == idx2
                return;
            end

            % Swap by moving each child to the other's position
            % Order matters: move the earlier one first to preserve indices
            if idx1 < idx2
                this.moveChild(child1, idx2);
                this.moveChild(child2, idx1);
            else
                this.moveChild(child2, idx1);
                this.moveChild(child1, idx2);
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

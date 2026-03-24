classdef Container < handle & ic.mixin.Registrable
   % abstract base for objects that hold #ic.core.Component children.
   % Manages a #ic.core.Container.Children array and one or more target slots.Target slots are named insertion points that correspond to named Svelte slot positions in its template

   properties (SetAccess = private)
      % array of all components currently held by this container (all slots combined)
      Children ic.core.Component
   end

   properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
      % named target slots available to children. Removing a slot name from this array also removes all non-static children assigned to that slot.
      Targets string = "default"
   end

   properties (Access = private)
      % snapshot of #ic.core.Container.Targets before the last change
      PreviousTargets string = "default"
   end

   methods
      function this = Container()
         % set up the PostSet listener that removes orphaned children when Targets changes.
         addlistener(this, 'Targets', 'PostSet', @this.onTargetsChanged);
      end

      function delete(this)
         % destroy this container and cascade deletion to all children.
         arguments (Input)
            this (1,1) ic.core.Container
         end

         delete(this.Children);
      end
   end

   methods (Access = public, Hidden)

      function validateChild(this, ~, target)
         % hook for subclasses to accept or reject a child before insertion. Override in the subclass and throw an error to reject.
         if ~ismember(target, this.Targets)
            error("ic:core:Component:InvalidTarget", ...
                "Target '%s' is not valid. Valid targets: %s", ...
                target, strjoin(this.Targets, ", "));
         end
      end

      function target = getDefaultTarget(this)
         % return the default slot for #ic.core.Container.addChild when no target is specified.
         % {returns} the first target, or an error if there are no targets available {/returns}
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
   end

   methods (Access = public)

      function addChild(this, child, target)
         % validate and insert child into the given target slot.
         arguments
            this
            % component to add
            child ic.core.Component
            % slot to insert into; defaults to the first target in the container's targets array
            target string {mustBeNonempty} = this.getDefaultTarget()
         end

         % allow parent to validate/reject the child before insertion
         this.validateChild(child, target);
         this.insertChild(child, target);
      end

      function removeChild(this, child)
         % remove child from this container.
         arguments
            this
            % component to remove
            child ic.core.Component
         end
         if isempty(this.Children)
            return;
         end
         childIDs = [this.Children.ID];
         mask = childIDs == child.ID;
         if any(mask)
            this.Children(mask) = [];
            this.deregisterSubtree(child);
            % notify the frontend to remove the child's DOM element
            data = struct("id", child.ID);
            this.publish("@remove", data);

            child.Parent = [];
            child.Target = string.empty;
         end

      end

      function children = getChildrenInTarget(this, target)
         % return the subset of #ic.core.Container.Children assigned to the given target slot.
         % {returns} an ic.core.Component array with the children in the specified slot {/returns}
         arguments
            this
            % target slot to query
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
         % move child to a new position within its target slot.
         % {example}
         %   panel.moveChild(btn, 1);        % move to first position
         %   panel.moveChild(btn, "end");    % move to last position
         % {/example}
         arguments
            this
            % child to reorder; must already belong to the container
            child ic.core.Component
            % new position: integer, "start", or "end"
            index = "end"
         end

         % validate child belongs to this container
         mask = [this.Children.ID] == child.ID;
         assert(any(mask), "ic:Container:ChildNotFound", ...
             "Child component is not in this container");

         % get target and children in that target
         target = child.Target;
         targetChildren = this.getChildrenInTarget(target);
         numInTarget = numel(targetChildren);

         % normalize index to numeric (1-based for MATLAB)
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

         % validate index bounds
         assert(numericIndex >= 1 && numericIndex <= numInTarget, ...
             "ic:Container:IndexOutOfBounds", ...
             "Index %d is out of bounds (1 to %d)", numericIndex, numInTarget);

         % find current position within target
         targetMask = [targetChildren.ID] == child.ID;
         currentIndex = find(targetMask);

         % early exit if already at target position
         if currentIndex == numericIndex
            return;
         end

         % publish reorder event (0-based index for TypeScript)
         data = struct("id", child.ID, "index", numericIndex - 1, "target", target);
         this.publish("@reorder", data);

         % reorder the local Children array by removing then reinserting
         this.Children(mask) = [];

         % find insertion point in full Children array relative to the target slot
         if numericIndex == 1
            % insert before first child in target
            firstInTarget = targetChildren(1);
            if firstInTarget.ID == child.ID && numInTarget > 1
               firstInTarget = targetChildren(2);
            end
            insertIdx = find([this.Children.ID] == firstInTarget.ID, 1);
            if isempty(insertIdx)
               insertIdx = 1;
            end
         else
            % insert after the child at (numericIndex - 1) position
            % account for the fact that we removed 'child' from targetChildren
            adjustedIdx = numericIndex;
            if currentIndex < numericIndex
               adjustedIdx = numericIndex; % child was before, so indices shift down
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

         % insert at new position
         if insertIdx > numel(this.Children)
            this.Children(end + 1) = child;
         else
            this.Children = [this.Children(1:insertIdx-1), child, this.Children(insertIdx:end)];
         end
      end

      function moveChildBefore(this, child, referenceChild)
         % move child to the position immediately before referenceChild. Both children must be in the same target slot.
         arguments
            this
            % child to move
            child ic.core.Component
            % reference child to move before
            referenceChild ic.core.Component
         end

         % validate both children belong to this container
         assert(any([this.Children.ID] == child.ID), ...
             "ic:Container:ChildNotFound", "Child not in container");
         assert(any([this.Children.ID] == referenceChild.ID), ...
             "ic:Container:ChildNotFound", "Reference child not in container");

         % validate same target
         assert(child.Target == referenceChild.Target, ...
             "ic:Container:TargetMismatch", ...
             "Both children must be in the same target");

         % find reference child's index in target
         targetChildren = this.getChildrenInTarget(child.Target);
         refIdx = find([targetChildren.ID] == referenceChild.ID);

         % move child to that index
         this.moveChild(child, refIdx);
      end

      function moveChildAfter(this, child, referenceChild)
         % move child to the position immediately after referenceChild. Both children must be in the same target slot.
         arguments
            this
            % child to move
            child ic.core.Component
            % reference child to move after
            referenceChild ic.core.Component
         end

         % validate both children belong to this container
         assert(any([this.Children.ID] == child.ID), ...
             "ic:Container:ChildNotFound", "Child not in container");
         assert(any([this.Children.ID] == referenceChild.ID), ...
             "ic:Container:ChildNotFound", "Reference child not in container");

         % validate same target
         assert(child.Target == referenceChild.Target, ...
             "ic:Container:TargetMismatch", ...
             "Both children must be in the same target");

         % find reference child's index in target
         targetChildren = this.getChildrenInTarget(child.Target);
         refIdx = find([targetChildren.ID] == referenceChild.ID);

         % move to position after reference (clamped to end)
         newIdx = min(refIdx + 1, numel(targetChildren));
         this.moveChild(child, newIdx);
      end

      function swapChildren(this, child1, child2)
         % swap the positions of two children within their shared target slot.Both children must be in the same target slot.
         arguments
            this
            % first child to swap
            child1 ic.core.Component
            % second child to swap
            child2 ic.core.Component
         end

         % validate both children belong to this container
         assert(any([this.Children.ID] == child1.ID), ...
             "ic:Container:ChildNotFound", "Child1 not in container");
         assert(any([this.Children.ID] == child2.ID), ...
             "ic:Container:ChildNotFound", "Child2 not in container");

         % validate same target
         assert(child1.Target == child2.Target, ...
             "ic:Container:TargetMismatch", ...
             "Both children must be in the same target");

         % get indices in target
         targetChildren = this.getChildrenInTarget(child1.Target);
         idx1 = find([targetChildren.ID] == child1.ID);
         idx2 = find([targetChildren.ID] == child2.ID);

         % early exit if same child
         if idx1 == idx2
            return;
         end

         % swap by moving each to the other's position (move the earlier one first)
         if idx1 < idx2
            this.moveChild(child1, idx2);
            this.moveChild(child2, idx1);
         else
            this.moveChild(child2, idx1);
            this.moveChild(child1, idx2);
         end
      end
   end

   methods (Access = {?ic.core.Container, ?ic.mixin.AllowsOverlay})
      function insertChild(this, child, target)
         % raw child insertion without validation. Handles both fresh inserts and reparenting.
         arguments
            this
            % component to insert
            child ic.core.Component
            % slot to insert into
            target string {mustBeNonempty}
         end

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

            % old parent publishes reparent event
            data = struct(...
                "id", child.ID, "parent", this.ID, "target", target);
            oldParent.publish("@reparent", data);

            % remove from old parent's Children
            mask = [oldParent.Children.ID] == child.ID;
            oldParent.Children(mask) = [];

            % update child's references
            child.Parent = this;
            child.Target = target;

            % add to new parent's Children
            this.Children(end + 1) = child;
            return;
         end

         addlistener(child, "ObjectBeingDestroyed", ...
             @(~,~) ic.core.Container.safeRemoveChild(this, child));

         % get child definition via introspection
         definition = child.getComponentDefinition();
         data = struct("component", definition, "target", target);

         % publish insert child
         this.publish("@insert", data);

         child.Parent = this;
         child.Target = target;

         % store & register child
         this.Children(end + 1) = child;
         this.registerSubtree(child);

         % flush the event queue into the parent
         child.flush();
      end
   end

   methods (Access = protected)
      function addStaticChild(this, child, target)
         % declare a child that is pre-rendered in the Svelte template. Static children are "pre-known" subelements of their container, and have their definitions already included in the parent's insertion payload via #ic.core.ComponentBase.getComponentDefinition
         arguments
            this
            % pre-rendered component to register
            child (1,1) ic.core.Component
            % slot name as declared in the Svelte template
            target string
         end

         addlistener(child, "ObjectBeingDestroyed", ...
             @(~,~) ic.core.Container.safeRemoveChild(this, child));

         child.Parent = this;
         child.Target = target;
         child.IsStatic = true;

         % add to Children immediately
         this.Children(end+1) = child;
         child.Parent = this;
      end

   end

   methods (Access = private)
      function onTargetsChanged(this, ~, ~)
         % removes children in slots that were removed.
         oldTargets = this.PreviousTargets;
         newTargets = this.Targets;

         % remove children in removed targets (reverse order for safety)
         removedTargets = setdiff(oldTargets, newTargets);
         if ~isempty(removedTargets)
            children = this.Children;
            for ii = numel(children):-1:1
               child = children(ii);
               if ~child.IsStatic && ismember(child.Target, removedTargets)
                  child.Parent = [];  % triggers @remove
               end
            end
         end

         this.PreviousTargets = newTargets;
      end
   end

   methods (Access = protected, Static)
      function safeRemoveChild(container, child)
         % guards against cascading deletes where the container is also being destroyed.
         if isvalid(container)
            container.removeChild(child);
         end
      end
   end

end

classdef Container < handle & ic.mixin.Registrable
   % abstract base for objects that hold #ic.core.Component children.
   % Manages a flat #ic.core.Container.Children array. Each container is
   % responsible for organizing its children by type, order, or class.

   properties (SetAccess = private)
      % array of all components currently held by this container
      Children ic.core.Component
   end

   methods
      function this = Container()
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

      function validateChild(this, child) %#ok<INUSD>
         % hook for subclasses to accept or reject a child before insertion.
         % Override in the subclass and throw an error to reject.
      end

   end

   methods (Access = public)

      function addChild(this, child)
         % validate and insert child into this container.
         arguments
            this
            % component to add
            child ic.core.Component
         end

         this.validateChild(child);
         this.insertChild(child);
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
         end
      end

      function moveChild(this, child, index)
         % move child to a new position within the children array.
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

         numChildren = numel(this.Children);

         % normalize index to numeric (1-based for MATLAB)
         if isstring(index) || ischar(index)
            if index == "start"
               numericIndex = 1;
            elseif index == "end"
               numericIndex = numChildren;
            else
               error("ic:Container:InvalidIndex", ...
                   "Index must be a number, 'start', or 'end'");
            end
         else
            numericIndex = index;
         end

         % validate index bounds
         assert(numericIndex >= 1 && numericIndex <= numChildren, ...
             "ic:Container:IndexOutOfBounds", ...
             "Index %d is out of bounds (1 to %d)", numericIndex, numChildren);

         % find current position
         currentIndex = find(mask);

         % early exit if already at target position
         if currentIndex == numericIndex
            return;
         end

         % publish reorder event (0-based index for TypeScript)
         data = struct("id", child.ID, "index", numericIndex - 1);
         this.publish("@reorder", data);

         % reorder the local Children array
         this.Children(mask) = [];
         if numericIndex > numel(this.Children)
            this.Children(end + 1) = child;
         else
            this.Children = [this.Children(1:numericIndex-1), child, this.Children(numericIndex:end)];
         end
      end

      function moveChildBefore(this, child, referenceChild)
         % move child to the position immediately before referenceChild.
         arguments
            this
            child ic.core.Component
            referenceChild ic.core.Component
         end

         assert(any([this.Children.ID] == child.ID), ...
             "ic:Container:ChildNotFound", "Child not in container");
         assert(any([this.Children.ID] == referenceChild.ID), ...
             "ic:Container:ChildNotFound", "Reference child not in container");

         refIdx = find([this.Children.ID] == referenceChild.ID);
         this.moveChild(child, refIdx);
      end

      function moveChildAfter(this, child, referenceChild)
         % move child to the position immediately after referenceChild.
         arguments
            this
            child ic.core.Component
            referenceChild ic.core.Component
         end

         assert(any([this.Children.ID] == child.ID), ...
             "ic:Container:ChildNotFound", "Child not in container");
         assert(any([this.Children.ID] == referenceChild.ID), ...
             "ic:Container:ChildNotFound", "Reference child not in container");

         refIdx = find([this.Children.ID] == referenceChild.ID);
         newIdx = min(refIdx + 1, numel(this.Children));
         this.moveChild(child, newIdx);
      end

      function swapChildren(this, child1, child2)
         % swap the positions of two children.
         arguments
            this
            child1 ic.core.Component
            child2 ic.core.Component
         end

         assert(any([this.Children.ID] == child1.ID), ...
             "ic:Container:ChildNotFound", "Child1 not in container");
         assert(any([this.Children.ID] == child2.ID), ...
             "ic:Container:ChildNotFound", "Child2 not in container");

         idx1 = find([this.Children.ID] == child1.ID);
         idx2 = find([this.Children.ID] == child2.ID);

         if idx1 == idx2
            return;
         end

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
      function insertChild(this, child)
         % raw child insertion without validation. Handles both fresh inserts and reparenting.
         arguments
            this
            child ic.core.Component
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
            data = struct("id", child.ID, "parent", this.ID);
            oldParent.publish("@reparent", data);

            % remove from old parent's Children
            mask = [oldParent.Children.ID] == child.ID;
            oldParent.Children(mask) = [];

            child.Parent = this;

            this.Children(end + 1) = child;
            return;
         end

         addlistener(child, "ObjectBeingDestroyed", ...
             @(~,~) ic.core.Container.safeRemoveChild(this, child));

         % get child definition via introspection
         definition = child.getComponentDefinition();
         data = struct("component", definition);

         % publish insert child
         this.publish("@insert", data);

         child.Parent = this;

         % store & register child
         this.Children(end + 1) = child;
         this.registerSubtree(child);

         % flush the event queue into the parent
         child.flush();
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

classdef ComponentContainer < ic.core.Component & ...
                              ic.core.Container
   % base class for components that are themselves containers.
   % Combines #ic.core.Component (can be inserted into a parent) with
   % #ic.core.Container (can hold child components of its own)
   methods
      function this = ComponentContainer(props)
         arguments
            props struct = struct()
         end
         this@ic.core.Component(props);
      end

      function delete(this)
         % delete all children first, then run component teardown.
         delete@ic.core.Container(this);
         delete@ic.core.Component(this);
      end
   end

   methods (Access = public)
      function queue = flush(this)
         % #ic.mixin.Publishable.flush queued events for this component, then cascade into all children.
         % Ensures the entire component subtree is delivered in the correct order (parent before children) when #ic.core.Container.insertChild flushes the events upstream.
         queue = flush@ic.mixin.Publishable(this);
         for ii = 1:numel(this.Children)
            this.Children(ii).flush();
         end
      end
   end

   methods (Access = ?ic.core.Container)
      function definition = getComponentDefinition(this)
         % extend the base component definition with static children.
         % static children are registered via #ic.core.Container.addStaticChild in the MATLAB constructor and pre-rendered in the Svelte template.
         definition = getComponentDefinition@ic.core.ComponentBase(this);

         % collect static children for serialization
         staticKids = this.Children([this.Children.IsStatic]);
         definition.staticChildren = cell(1, numel(staticKids));
         if ~isempty(staticKids)
            for ii = 1:numel(staticKids)
               definition.staticChildren{ii} = struct(...
                   "component", getComponentDefinition(staticKids(ii)), ...
                   "target", staticKids(ii).Target);
            end
         end
      end
   end
end

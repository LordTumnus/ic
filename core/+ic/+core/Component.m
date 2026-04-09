classdef Component < ic.core.ComponentBase & matlab.mixin.SetGetExactNames & ...
                     ic.mixin.Stylable & ...
                     ic.mixin.Effectable & ...
                     ic.mixin.Keyable
   % concrete base for all IC UI components.
   % The constructor accepts a property struct from the subclass arguments block so every subclass gets a name-value constructor for free
   % Components are inserted into containers via container.addChild(component).

   properties (SetAccess = {?ic.core.Container, ?ic.mixin.Registrable})
      % owning container; empty until the component is inserted via addChild.
      Parent = [] % ic.core.Container
   end


   methods
      function this = Component(props)
         % create a component from a name-value property struct.
         % ID is extracted from the struct before calling set() because the
         % immutable ID property must be passed to ComponentBase before set() runs.
         % all remaining fields are applied in bulk via set().
         arguments
            % struct of name-value pairs; typically from props.?ic.SubClass
            props struct = struct()
         end

         if isfield(props, 'ID')
            id = props.ID;
            props = rmfield(props, 'ID');
         else
            id = "ic-" + matlab.lang.internal.uuid();
         end

         this@ic.core.ComponentBase(id);

         if ~isempty(fieldnames(props))
            nvPairs = namedargs2cell(props);
            set(this, nvPairs{:});
         end
      end
   end

   methods (Access = public, Hidden)
      function tf = isAttached(this)
         % check if the component is linked to a valid container
         % {returns} whether the parent exists and is valid {/returns}
         tf = ~isempty(this.Parent) && isvalid(this.Parent);
      end
   end

   methods (Access = protected)

      function send(this, evt)
         % delegate an event up the parent chain towards the view. If not yet attached, the event is buffered in #ic.core.ComponentBase.Queue and delivered automatically by #ic.core.Container.insertChild when the component is added.
         if ~this.isAttached()
            this.Queue((end + 1):(end + length(evt))) = evt;
            return;
         end
         this.Parent.send(evt);
      end
   end


   methods (Access = protected)
      function sendReactiveProperty(this, propertyName)
         % publish a @prop/<Name> event to push a reactive property value to the frontend. This method is called automatically by the PostSet listener wired by #ic.mixin.Reactive.setupReactivity().
         % Since the @insert event triggers the initial sync of all reactive properties when a component is added to a container, this method does nothing if the component is not yet attached to a container.
         if ~this.isAttached()
            return;
         end
         this.publish("@prop/" + propertyName, this.(propertyName));
      end
   end

   methods (Access = {?ic.core.Container, ?ic.mixin.Registrable}, Hidden)
      function frame = getFrame(this)
         % walk up the parent chain and return the root ic.Frame, or [] if not found.
         % {returns} ic.Frame, or [] if the component is not yet in a frame {/returns}
         frame = [];
         current = this.Parent;
         while ~isempty(current) && isvalid(current)
            if isa(current, "ic.Frame")
               frame = current;
               return;
            end
            if isa(current, "ic.core.Component")
               current = current.Parent;
            else
               % reached a container that is not a component (shouldn't happen)
               return;
            end
         end
      end
   end

end

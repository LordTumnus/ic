classdef (Abstract) ComponentBase < handle & matlab.mixin.Heterogeneous & ...
                                    ic.mixin.Publishable & ...
                                    ic.mixin.Reactive
   % abstract root of the IC class hierarchy; shared by all components and the #ic.Frame.
   % Defines the common ID property and the publish() method for sending events to the frontend.

   properties (SetAccess = immutable)
      % unique identifier; used as the HTMLElement id in the DOM and as the Registry key on the frontend to enable event routing and state management for the component.
      ID (1,1) string
   end

   methods
      function this = ComponentBase(id)
         % create a component with the given identifier and wire up reactivity.
         arguments (Input)
            % identifier for this component; defaults to "ic-<uuid>"
            id (1,1) string {mustBeValidCssIdent} = ...
                "ic-" + matlab.lang.internal.uuid();
         end
         arguments (Output)
            this (1,1) ic.core.ComponentBase
         end

         this.ID = id;
         this.setupReactivity();
      end
   end

   methods (Access = public, Hidden)
      function promise = publish(this, name, data)
         % send an event to the frontend.
         % {note} only @-prefixed internal events (e.g. "@prop/Label", "@insert") and reactive method names may be published. Attempting to publish a reactive method name directly is an error {/note}
         % {returns} optional #ic.async.Promise that resolves to #ic.async.Resolution when the frontend responds {/returns}

         arguments (Input)
            this (1,1) ic.core.ComponentBase
            % event name
            name (1,1) string
            % event payload
            data % any
         end

         arguments (Output)
            promise ic.async.Promise
         end

         if ~startsWith(name, "@") && ~this.isReactiveMethod(name)
            error("ic:core:ComponentBase:PublishReactiveMethod", ...
                  "Cannot publish reactive method '%s'. Reactive methods are invoked directly on the component instance.", name);
         end

         if nargout == 1
            promise = publish@ic.mixin.Publishable(this, name, data);
         else
            publish@ic.mixin.Publishable(this, name, data);
         end
      end
   end

   methods (Access = {?ic.core.Container})
      function definition = getComponentDefinition(this)
         % serialize this component's schema for the JS Factory.
         % the returned struct is sent as the payload of every @insert event and
         % tells the frontend which Svelte component to mount, which props/events/methods to wire, and which mixin capabilities are active.
         % {returns} struct with fields: id, type, mixins, props, events, methods {/returns}

         definition = struct(...
             'id', this.ID, ...
             'type', string(class(this)));

         % auto-discover mixins from the class hierarchy
         allSupers = string(superclasses(class(this)));
         mixinMask = startsWith(allSupers, "ic.mixin.");
         definition.mixins = lower(extractAfter( ...
             allSupers(mixinMask), "ic.mixin."));

         % reactive mixin contributes props / events / methods arrays
         [definition.props, definition.events, definition.methods] = ...
             this.gatherReactiveDefinition();
      end
   end

end

function mustBeValidCssIdent(id)
% validate that id is a valid CSS identifier.
% CSS idents allow letters (A-Z, a-z), digits (0-9), hyphens, and underscores.
% the string cannot be empty, cannot start with a digit, and cannot start with
% a hyphen followed by a digit.
% see: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/ident

    % build pattern for valid CSS ident characters
    validChar = lettersPattern(1) | digitsPattern(1) | characterListPattern("-_");

    % check non-empty
    if strlength(id) == 0
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID cannot be empty.");
    end

    % check all characters are valid (letters, digits, hyphens, underscores)
    if ~matches(id, asManyOfPattern(validChar, 1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' contains invalid characters. " + ...
              "Valid characters are: letters, digits, hyphens, and underscores.", id);
    end

    % cannot start with a digit
    if startsWith(id, digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a digit.", id);
    end

    % cannot start with hyphen followed by digit
    if startsWith(id, "-" + digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a hyphen followed by a digit.", id);
    end
end

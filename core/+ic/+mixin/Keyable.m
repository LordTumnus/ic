classdef (Abstract) Keyable < handle
    % keyboard shortcut registration for components.
    % allows registering keyboard shortcuts via #ic.mixin.Keyable.onKey and receiving
    % callbacks when the shortcut is pressed while the component has focus.
    % each registration returns a #ic.key.KeyBinding handle for independent removal

    properties (SetAccess = private, Hidden)
        % registered bindings: struct array with fields id, shortcut, callback, preventDefault, stopPropagation
        KeyBindings (:,1) struct = struct('id', {}, 'shortcut', {}, 'callback', {}, ...
            'preventDefault', {}, 'stopPropagation', {})

        % whether the @keyPressed subscription has been set up
        KeySubscribed (1,1) logical = false
    end

    methods (Abstract, Access = public)
        publish(this, name, data)
        subscribe(this, name, callback)
    end

    methods (Access = public)
        function binding = onKey(this, shortcut, callback, opts)
            % register a keyboard shortcut with a callback.
            % multiple callbacks can be registered for the same shortcut;
            % each is invoked independently when the shortcut matches.
            % {returns} a #ic.key.KeyBinding handle whose remove() method unregisters this specific callback {/returns}
            % {example}
            %   k = comp.onKey("Ctrl+S", @(src, data) disp(data));
            %   k = comp.onKey("Ctrl+Enter", @(src, data) compile(), ...
            %       "PreventDefault", true);
            %   k.remove();
            % {/example}
            arguments
                this (1,1) ic.mixin.Keyable
                % shortcut string (e.g. "Ctrl+S", "Escape", "Alt+Enter")
                shortcut (1,1) string
                % callback invoked as callback(comp, data) where data has fields: shortcut, key, code
                callback (1,1) function_handle
                % whether to call preventDefault() on the matched keyboard event
                opts.PreventDefault (1,1) logical = false
                % whether to call stopPropagation() on the matched keyboard event
                opts.StopPropagation (1,1) logical = false
            end

            % lazy subscribe to frontend @keyPressed events
            if ~this.KeySubscribed
                this.subscribe("@keyPressed", ...
                    @(comp, ~, data) comp.handleKeyPressed(data));
                this.KeySubscribed = true;
            end

            % check if this is the first callback for this shortcut
            isFirst = isempty(this.KeyBindings) || ...
                ~any(strcmp({this.KeyBindings.shortcut}, shortcut));

            % store binding
            bindingId = string(matlab.lang.internal.uuid());
            entry = struct('id', bindingId, 'shortcut', shortcut, ...
                'callback', callback, ...
                'preventDefault', opts.PreventDefault, ...
                'stopPropagation', opts.StopPropagation);
            this.KeyBindings(end+1) = entry;

            % create handle
            binding = ic.key.KeyBinding(this, bindingId, shortcut);

            % aggregate options across all bindings for this shortcut (OR)
            pd = false; sp = false;
            for jj = 1:numel(this.KeyBindings)
                if this.KeyBindings(jj).shortcut == shortcut
                    pd = pd || this.KeyBindings(jj).preventDefault;
                    sp = sp || this.KeyBindings(jj).stopPropagation;
                end
            end

            % notify frontend (always, so options stay in sync)
            if isFirst
                this.publish("@onKey", struct("shortcut", shortcut, ...
                    "preventDefault", pd, "stopPropagation", sp));
            elseif opts.PreventDefault || opts.StopPropagation
                % update frontend options if this binding added stricter behavior
                this.publish("@updateKey", struct("shortcut", shortcut, ...
                    "preventDefault", pd, "stopPropagation", sp));
            end
        end

        function clearKeys(this)
            % remove all keyboard shortcut bindings
            this.KeyBindings(:) = [];
            this.publish("@clearKeys", struct());
        end
    end

    methods (Access = {?ic.key.KeyBinding})
        function removeKeyBinding(this, bindingId)
            % remove a specific binding by ID.
            % called by #ic.key.KeyBinding.remove
            mask = strcmp({this.KeyBindings.id}, bindingId);
            if ~any(mask)
                return;
            end
            shortcut = this.KeyBindings(mask).shortcut;
            this.KeyBindings(mask) = [];

            % if last callback for this shortcut, notify frontend
            isLast = isempty(this.KeyBindings) || ...
                ~any(strcmp({this.KeyBindings.shortcut}, shortcut));
            if isLast
                this.publish("@offKey", struct("shortcut", shortcut));
            end
        end
    end

    methods (Access = private)
        function handleKeyPressed(this, data)
            % route incoming @keyPressed to all callbacks matching the shortcut
            shortcut = string(data.shortcut);
            for ii = 1:numel(this.KeyBindings)
                if this.KeyBindings(ii).shortcut == shortcut
                    this.KeyBindings(ii).callback(this, data);
                end
            end
        end
    end
end

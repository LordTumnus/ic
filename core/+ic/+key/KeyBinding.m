classdef KeyBinding < handle
    % handle to a registered keyboard shortcut created via #ic.mixin.Keyable.onKey

    properties (SetAccess = immutable)
        % the shortcut string this binding listens for
        Shortcut (1,1) string
    end

    properties (Access = private)
        % the component that owns this binding
        Owner

        % unique identifier for this binding
        BindingId (1,1) string

        % whether this binding has been removed
        IsRemoved (1,1) logical = false
    end

    methods
        function this = KeyBinding(owner, bindingId, shortcut)
            arguments
                % owning #ic.mixin.Keyable component
                owner (1,1) ic.mixin.Keyable
                % unique binding identifier
                bindingId (1,1) string
                % shortcut string
                shortcut (1,1) string
            end
            this.Owner = owner;
            this.BindingId = bindingId;
            this.Shortcut = shortcut;
        end

        function remove(this)
            % unregister this keyboard shortcut binding.
            % if this was the last callback for the shortcut, the frontend
            % listener is also removed
            if ~this.IsRemoved && ~isempty(this.Owner) && isvalid(this.Owner)
                this.Owner.removeKeyBinding(this.BindingId);
                this.IsRemoved = true;
            end
        end

        function delete(this)
            % clean up the keyboard binding when this handle is destroyed
            try
                this.remove();
            catch
                % silently ignore: owner may already be destroyed
            end
        end
    end
end

% > COMPONENTBASE is the abstract base class for interactive components.
%
% Composes the core mixins that every component needs:
%   - Publishable  — event messaging (pub/sub)
%   - Reactive     — automatic property/event sync with the frontend
%
% Capability mixins (Stylable, Effectable) are added by Component, not here,
% so that non-Component roots like Frame can pick only what they need.
%
% Optional mixins (Requestable) are inherited by individual component
% classes that need them.
% > superdoc
classdef (Abstract) ComponentBase < handle & matlab.mixin.Heterogeneous & ...
                                    ic.mixin.Publishable & ...
                                    ic.mixin.Reactive

    properties (SetAccess = immutable)
        % > ID unique identifier of the component
        ID (1,1) string
    end

    methods
        function this = ComponentBase(id)
            arguments (Input)
                % > ID unique identifier for the component
                id (1,1) string {mustBeValidCssIdent} = ...
                    "ic-" + matlab.lang.internal.uuid();
            end

            arguments (Output)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
            end

            this.ID = id;
            this.setupReactivity();
        end
    end

    methods (Access = public)
        function promise = publish(this, name, data)
            % > PUBLISH sends an event to the view with a reactive method guard.
            % Only @-prefixed internal events and reactive methods are allowed.

            arguments (Input)
                this (1,1) ic.core.ComponentBase
                name (1,1) string
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
            % > GETCOMPONENTDEFINITION returns a struct with the component
            % schema for the JavaScript side, including which mixins
            % (capabilities) are present.

            definition = struct(...
                'id', this.ID, ...
                'type', string(class(this)));

            % Auto-discover mixins from the class hierarchy
            allSupers = string(superclasses(class(this)));
            mixinMask = startsWith(allSupers, "ic.mixin.");
            definition.mixins = lower(extractAfter( ...
                allSupers(mixinMask), "ic.mixin."));

            % Reactive contributes props / events / methods
            [definition.props, definition.events, definition.methods] = ...
                this.gatherReactiveDefinition();
        end
    end

end

function mustBeValidCssIdent(id)
% MUSTBEVALIDCSSIDENT validates that the given string is a valid CSS identifier.
%
% CSS identifiers (idents) allow: letters (A-Z, a-z), digits (0-9),
% hyphens (-), underscores (_), and Unicode characters >= U+00A0.
%
% Restrictions:
%   - Cannot be empty
%   - Cannot start with a digit
%   - Cannot start with a hyphen followed by a digit
%
% See: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/ident

    % Build pattern for valid CSS ident characters
    validChar = lettersPattern(1) | digitsPattern(1) | characterListPattern("-_");

    % Check non-empty
    if strlength(id) == 0
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID cannot be empty.");
    end

    % Check all characters are valid (letters, digits, hyphens, underscores)
    if ~matches(id, asManyOfPattern(validChar, 1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' contains invalid characters. " + ...
              "Valid characters are: letters, digits, hyphens, and underscores.", id);
    end

    % Cannot start with a digit
    if startsWith(id, digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a digit.", id);
    end

    % Cannot start with hyphen followed by digit
    if startsWith(id, "-" + digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a hyphen followed by a digit.", id);
    end
end

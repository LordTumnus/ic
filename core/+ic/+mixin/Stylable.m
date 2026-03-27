classdef (Abstract) Stylable < handle
    % dynamic CSS styling capabilities for components.
    % Styles are scoped to the component wrapper DOM element (tagged with its #ic.core.ComponentBase.ID). Internally, it uses constructable stylesheets ([CSSStyleSheet](https://developer.mozilla.org/en-US/docs/Web/API/CSSStyleSheet)) for performant rule injection.
    % Note that styles shouldn't be applied to the wrapper element itself. Instead, children or descendants should be targeted via selectors
    % All style operations are accessed through the #ic.mixin.Stylable.css property, which returns a #ic.mixin.StyleBuilder instance.

    properties (SetAccess = {?ic.mixin.Stylable, ?ic.mixin.StyleBuilder}, ...
                GetAccess = {?ic.mixin.Stylable, ?ic.mixin.StyleBuilder}, Hidden)
        % dynamic CSS styles per selector
        Styles = dictionary(string.empty(), struct.empty());
    end

    properties (Dependent, SetAccess = private)
        % util #ic.mixin.StyleBuilder class that simplifies common style update patterns with a fluent syntax
        css
    end

    properties (Access = private, Hidden)
        % cached #ic.mixin.StyleBuilder instance
        StyleBuilder
    end

    methods (Abstract, Access = public)
        publish(this, name, data)
    end

    methods
        function builder = get.css(this)
            % returns a style builder object that allows chaining style updates in a fluent syntax.
            % {returns} a #ic.mixin.StyleBuilder bound to this component {/returns}
            if isempty(this.StyleBuilder)
                this.StyleBuilder = ic.mixin.StyleBuilder(this);
            end
            builder = this.StyleBuilder;
        end
    end
end

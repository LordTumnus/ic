classdef (Abstract) Blade < ic.core.Component & ic.mixin.Attachable
    % abstract base for all TweakPane leaf controls.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % display label shown next to the control
        Label (1,1) string = ""

        % whether this blade is disabled
        Disabled (1,1) logical = false

        % whether this blade is hidden
        Hidden (1,1) logical = false
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % insertion order within the parent container (set by the parent container or pane)
        BladeIndex (1,1) double = 0
    end

    methods
        function this = Blade(props)
            this@ic.core.Component(props);
        end
    end
end

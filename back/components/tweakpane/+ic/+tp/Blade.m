classdef (Abstract) Blade < ic.core.Component
    % > BLADE Abstract base for all TweakPane leaf controls.
    %
    % Subclasses: Slider, Checkbox, Text, Color, Point, List, Button,
    % Separator, Monitor, IntervalSlider, FpsGraph, RadioGrid, ButtonGrid,
    % CubicBezier, Ring, Wheel, Rotation, Textarea, Image.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display label for this blade
        Label (1,1) string = ""
        % > DISABLED whether this blade is disabled
        Disabled (1,1) logical = false
        % > HIDDEN whether this blade is hidden
        Hidden (1,1) logical = false
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % > BLADEINDEX insertion order within the parent container (set by parent)
        BladeIndex (1,1) double = 0
    end

    methods
        function this = Blade(props)
            this@ic.core.Component(props);
        end
    end
end

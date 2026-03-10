classdef List < ic.tp.Blade
    % > LIST Dropdown select blade for TweakPane.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE currently selected item
        Value (1,1) string = ""
        % > ITEMS list of selectable options
        Items (1,:) string = string.empty
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the selection changes
        ValueChanged
    end

    methods
        function this = List(props)
            arguments
                props.?ic.tp.List
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end

classdef SearchBar < ic.core.Component
    % tag-based search input.
    % Displays a search field where typing the separator character converts the typed text into a tag. Tags can have icons assigned via prefix triggers: if the text starts with a trigger string, it is stripped and the corresponding icon is shown.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % current tags as a string array
        Value string = string.empty

        % character that triggers closing a tag and starting a new one
        Separator string = ","

        % ghost text shown when there are no tags and the input is empty
        Placeholder string = "Search..."

        % whether the control is disabled and cannot be interacted with
        Disabled logical = false

        % whether to display a "x" close button in the input field to remove all tags at once
        Clearable logical = false

        % dimensions of the control relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"

        % map of prefix strings to Lucide icon names. If the user types a tag that starts with one of the prefix strings, that prefix is stripped and the corresponding icon is shown in the tag
        IconTriggers containers.Map
    end

    events (Description = "Reactive")
        % triggered when the tag list changes
        % {payload}
        % value | cell array or empty: current list of tags, or empty if all cleared
        % {/payload}
        ValueChanged

        % fires when Enter is pressed
        % {payload}
        % value | cell array: current list of tags at the time of submission
        % {/payload}
        Submitted
    end

    methods
        function this = SearchBar(props)
            arguments
                props.?ic.SearchBar
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.IconTriggers = containers.Map();
        end

        function set.Value(this, val)
            % normalize "" to string.empty (canonical "no tags")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            this.Value = val;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % programmatically focus the search input
            out = this.publish("focus", []);
        end

        function out = clear(this)
            % programmatically clear all tags
            out = this.publish("clear", []);
        end
    end
end

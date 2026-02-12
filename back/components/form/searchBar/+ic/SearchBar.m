classdef SearchBar < ic.core.Component
    % > SEARCHBAR Tag-based search input with separator-driven tag creation.
    %
    %   Displays a search field where typing the separator character
    %   (default ",") converts the typed text into a tag. Tags can have
    %   icons assigned via prefix triggers: if the text starts with a
    %   trigger string, it is stripped and the corresponding icon is shown.
    %
    %   Example:
    %       sb = ic.SearchBar();
    %       sb.Placeholder = "Add filters...";
    %       sb.Clearable = true;
    %       sb.Separator = ",";
    %       sb.IconTriggers = containers.Map(["/", "@"], ["folder", "user"]);
    %       % User types: hello,/docs,@admin,
    %       % Creates tags: [hello] [folder+docs] [user+admin]

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE current tags as a string array (string.empty = no tags)
        Value string = string.empty
        % > SEPARATOR character that triggers tag creation from typed text
        Separator string = ","
        % > PLACEHOLDER text shown when no tags and input is empty
        Placeholder string = "Search..."
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > CLEARABLE whether all tags can be cleared via an X button
        Clearable logical = false
        % > SIZE size of the control
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary"])} = "primary"
        % > ICONTRIGGERS map of prefix strings to Lucide icon names
        IconTriggers
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when the tag list changes
        ValueChanged
        % > SUBMITTED fires when Enter is pressed
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
            % Normalize "" to string.empty (canonical "no tags")
            if isscalar(val) && val == ""
                val = string.empty;
            end
            this.Value = val;
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the search input
            out = this.publish("focus", []);
        end

        function out = clear(this)
            % > CLEAR programmatically clear all tags
            out = this.publish("clear", []);
        end
    end
end

classdef SplitButton < ic.core.ComponentContainer
    % > SPLITBUTTON Button with a dropdown for additional actions.
    %
    %   Displays a main button (always showing the first item) with a
    %   chevron trigger that opens a dropdown listing all items with
    %   optional icons/images and descriptions.
    %
    %   Clicking the main button fires ItemSelected for the first item.
    %   Clicking a dropdown item fires ItemSelected for that item.
    %
    %   Example:
    %       sb = ic.SplitButton();
    %       sb.Items = ["Run", "Debug", "Profile"];
    %       sb.ItemDescriptions = ["Execute script", "Debug mode", "Run profiler"];
    %       sb.setIcon(1, ic.Icon.fromName("play"));
    %       sb.setIcon(2, ic.Icon.fromName("bug"));
    %       sb.setIcon(3, ic.Icon.fromName("activity"));
    %
    %   Listen to events:
    %       addlistener(sb, 'ItemSelected', @(~,e) disp(e.Data));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > ITEMS labels for each action (first item is always the main button label)
        Items (1,:) string = "Action"
        % > ITEMDESCRIPTIONS optional descriptions shown below each item label
        ItemDescriptions (1,:) string = string.empty
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "secondary", "destructive"])} = "primary"
        % > FILL fill style of the button
        Fill string {mustBeMember(Fill, ...
            ["solid", "outline", "ghost"])} = "solid"
        % > SIZE size of the button
        Size string {mustBeMember(Size, ["sm", "md", "lg"])} = "md"
        % > DISABLED whether the control is disabled
        Disabled logical = false
        % > SPLITDIRECTION chevron trigger position relative to the main button
        SplitDirection string {mustBeMember(SplitDirection, ...
            ["right", "bottom"])} = "right"
    end

    properties (Dependent)
        MainIcon  % Convenient access to the main button icon child
    end

    events (Description = "Reactive")
        % > ITEMSELECTED fires when an item is selected (main button or dropdown)
        ItemSelected
        % > OPENED fires when the dropdown opens
        Opened
        % > CLOSED fires when the dropdown closes
        Closed
    end

    methods
        function this = SplitButton(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(id);
            this.Targets = ["icon", this.Items];
        end

        % --- MainIcon dependent property ---
        function icon = get.MainIcon(this)
            for child = this.Children
                if child.Target == "icon"
                    icon = child;
                    return;
                end
            end
            icon = [];
        end

        function set.MainIcon(this, icon)
            delete(this.MainIcon);
            if ~isempty(icon)
                this.addChild(icon, "icon");
            end
        end

        % --- Items setter: update targets, clean up removed ---
        function set.Items(this, val)
            removed = setdiff(this.Items, val);
            for child = this.Children
                if ismember(child.Target, removed)
                    delete(child);
                end
            end
            this.Items = val;
            this.Targets = ["icon", val];
        end

        % --- Per-item icon management (index-based) ---
        function setIcon(this, idx, icon)
            % > SETICON Set or replace the icon/image for a dropdown item by index.
            %   sb.setIcon(1, ic.Icon.fromName("play"))
            %   sb.setIcon(2, ic.Image())
            %   sb.setIcon(1, [])  % removes the icon
            arguments
                this
                idx (1,1) double {mustBePositive, mustBeInteger}
                icon
            end
            assert(idx <= numel(this.Items), "ic:SplitButton:InvalidIndex", ...
                "Index %d exceeds number of Items (%d).", idx, numel(this.Items));
            item = this.Items(idx);
            for child = this.Children
                if child.Target == item
                    delete(child);
                end
            end
            if ~isempty(icon)
                this.addChild(icon, item);
            end
        end

        function icon = getIcon(this, idx)
            % > GETICON Get the icon/image for a dropdown item by index, or [] if none.
            arguments
                this
                idx (1,1) double {mustBePositive, mustBeInteger}
            end
            assert(idx <= numel(this.Items), "ic:SplitButton:InvalidIndex", ...
                "Index %d exceeds number of Items (%d).", idx, numel(this.Items));
            item = this.Items(idx);
            for child = this.Children
                if child.Target == item
                    icon = child;
                    return;
                end
            end
            icon = [];
        end

        % --- Child validation ---
        function validateChild(this, child, target)
            % > VALIDATECHILD ensures children are icons/images in valid targets
            assert(isa(child, "ic.Icon") || isa(child, "ic.Image"), ...
                "ic:SplitButton:InvalidChild", ...
                "SplitButton only accepts ic.Icon or ic.Image children.");
            assert(target == "icon" || ismember(target, this.Items), ...
                "ic:SplitButton:InvalidTarget", ...
                "Target must be 'icon' or one of Items: %s.", ...
                strjoin(this.Items, ", "));
        end
    end

    methods (Description = "Reactive")
        function out = focus(this)
            % > FOCUS programmatically focus the main button
            out = this.publish("focus", []);
        end
    end
end

classdef Splitter < ic.core.ComponentContainer
    % > SPLITTER Resizable split pane container.
    %
    % The Splitter divides space into resizable panes. The number of panes
    % is determined by the length of the Sizes array. Use addPaneAt() to
    % place components at specific pane indices.
    %
    % Example:
    %   splitter = ic.Splitter("split1");
    %   splitter.Direction = "horizontal";
    %   splitter.Sizes = [30, 40, 30];  % 3 panes
    %
    %   % Add components to specific panes (1-indexed)
    %   splitter.addPaneAt(ic.Panel("left"), 1);    % First pane
    %   splitter.addPaneAt(ic.Panel("center"), 2);  % Second pane
    %   splitter.addPaneAt(ic.Panel("right"), 3);   % Third pane

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SIZES percentage sizes for each pane (must sum to ~100)
        % Array length determines number of panes. Changing this updates
        % the available targets (pane-0, pane-1, ...).
        Sizes (1,:) double = [50, 50]

        % > MINSIZE minimum size in pixels. As a scalar, applies to all panels
        MinSize (1,:) double = 100

        % > MAXSIZE maximum size in pixels. As a scalar, applies to all panels
        MaxSize (1,:) double = Inf

        % > GUTTERSIZE size of draggable gutter between panes (pixels)
        GutterSize (1,1) double = 5

        % > DIRECTION split orientation: 'horizontal' or 'vertical'
        Direction (1,1) string {mustBeMember(Direction, ["horizontal", "vertical"])} = "horizontal"

        % > DISABLED disable resizing when true
        Disabled (1,1) logical = false

        % > SNAPOFFSET snap to min/max within this pixel offset
        SnapOffset (1,1) double = 30
    end

    properties (Dependent, SetAccess = private)
        % > PANES read-only list of components in pane slots
        Panes
    end

    events (Description = "Reactive")
        % > SIZESCHANGED fired when pane sizes change
        SizesChanged
    end

    methods
        function this = Splitter(id)
            arguments
                id (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(id);

            % Initialize targets based on default Sizes
            this.Targets = this.generatePaneTargets(numel(this.Sizes));

            addlistener(this, 'Sizes', 'PreSet', @this.validateSizesSum);
            addlistener(this, 'Sizes', 'PostSet', @this.onSizesChanged);
            addlistener(this, 'MinSize', 'PreSet', @this.validateSizeArray);
            addlistener(this, 'MaxSize', 'PreSet', @this.validateSizeArray);
        end

        function panes = get.Panes(this)
            % Returns children in pane slots (targets starting with "pane-")
            if isempty(this.Children)
                panes = ic.core.Component.empty();
            else
                panes = this.Children(startsWith([this.Children.Target], "pane-"));
            end
        end

        function addPaneAt(this, component, index)
            % > ADDPANEAT Add a component to a specific pane slot.
            %
            % The index is 1-based and must be <= numel(Sizes).
            % The pane must not already contain a component.
            %
            % Example:
            %   splitter.Sizes = [30, 70];  % 2 panes
            %   splitter.addPaneAt(btn1, 1);  % First pane
            %   splitter.addPaneAt(btn2, 2);  % Second pane
            arguments
                this
                component (1,1) ic.core.Component
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            if index > numel(this.Sizes)
                error('ic:Splitter:IndexOutOfBounds', ...
                    'Pane index %d exceeds number of panes (%d). Set Sizes first.', ...
                    index, numel(this.Sizes));
            end

            % Check if pane is already occupied
            target = sprintf("pane-%d", index - 1);  % 0-indexed for frontend
            existing = this.getChildrenInTarget(target);
            if ~isempty(existing)
                error('ic:Splitter:PaneOccupied', ...
                    'Pane %d is already occupied.', index);
            end

            this.addChild(component, target);
        end
    end

    methods (Description = "Reactive")
        function out = collapse(this, index)
            % > COLLAPSE closes the panel at the given index
            % Collapses the pane to its minimum size, redistributing space
            % to adjacent panes.
            arguments
                this
                index (1,1) double {mustBePositive, mustBeInteger}
            end

            if index > numel(this.Sizes)
                error('ic:Splitter:IndexOutOfBounds', ...
                    'Collapse index %d exceeds number of panes (%d).', ...
                    index, numel(this.Sizes));
            end

            % Convert to 0-indexed for frontend
            out = this.publish("collapse", index - 1);
        end
    end

    methods (Access = public)
        function validateTarget(this, target)
            % > VALIDATETARGET rejects "default" and validates pane-N format
            if target == "default"
                error('ic:Splitter:InvalidTarget', ...
                    'Splitter does not support the default target. Use addPaneAt(component, index).');
            end

            % Delegate to base class for target membership check
            validateTarget@ic.core.Container(this, target);
        end
    end

    methods (Access = private)
        function targets = generatePaneTargets(~, numPanes)
            % Generate target names: pane-0, pane-1, ..., pane-(n-1)
            targets = "pane-" + string(0:numPanes-1);
        end

        function validateSizesSum(~, ~, evt)
            newSizes = evt.AffectedObject.(evt.Source.Name);
            total = sum(newSizes);
            if abs(total - 100) > 1
                error('ic:Splitter:InvalidSizesSum', ...
                    'Sizes must sum to 100 (got %.2f)', total);
            end
        end

        function onSizesChanged(this, ~, ~)
            % Update Targets when Sizes changes
            % The Container.onTargetsChanged will handle removing children
            % from removed targets automatically
            this.Targets = this.generatePaneTargets(numel(this.Sizes));
        end

        function validateSizeArray(this, ~, evt)
            newValue = evt.AffectedObject.(evt.Source.Name);
            numPanes = numel(this.Sizes);
            if numel(newValue) > numPanes
                error('ic:Splitter:InvalidArraySize', ...
                    '%s array length (%d) cannot exceed number of panes (%d)', ...
                    evt.Source.Name, numel(newValue), numPanes);
            end
        end
    end

end

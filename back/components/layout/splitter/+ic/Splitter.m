classdef Splitter < ic.core.ComponentContainer
    % > SPLITTER Resizable split pane container.
    %
    % The Splitter divides space into resizable panes. Use addPane() to
    % create panes, then configure their Size, MinSize, MaxSize, and
    % SnapSize individually.
    %
    % Example:
    %   s = ic.Splitter();
    %   s.Direction = "horizontal";
    %   s.GutterSize = 8;
    %
    %   left = s.addPane(Size=30, MinSize=10);
    %
    %   right = s.addPane(Size=70);


    properties (SetObservable, AbortSet, Description = "Reactive")
        % > DIRECTION split orientation: 'horizontal' or 'vertical'
        Direction (1,1) string {mustBeMember(Direction, ...
            ["horizontal", "vertical"])} = "horizontal"

        % > GUTTERSIZE size of draggable gutter between panes (pixels)
        GutterSize (1,1) double = 5

        % > DISABLED disable resizing when true
        Disabled (1,1) logical = false
    end

    properties (Dependent, SetAccess = private)
        % > SIZES read-only: current percentage sizes of all panes
        Sizes

        % > PANES read-only: array of SplitterPane children
        Panes
    end

    events (Description = "Reactive")
        % > RESIZED fires after pane sizes change (drag end or collapse)
        Resized
    end

    methods
        function this = Splitter(props)
            % > SPLITTER Create a resizable split pane container.
            arguments
                props.?ic.Splitter
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end

        function val = get.Sizes(this)
            panes = this.Panes;
            if isempty(panes)
                val = [];
            else
                val = arrayfun(@(p) p.Size, panes);
            end
        end

        function panes = get.Panes(this)
            if isempty(this.Children)
                panes = ic.SplitterPane.empty();
            else
                panes = this.Children( ...
                    startsWith([this.Children.Target], "pane-"));
            end
        end

        function pane = addPane(this, props)
            % > ADDPANE Add a new pane to the splitter, returns the pane.
            %
            % Example:
            %   p = splitter.addPane(Size=40, MinSize=10);
            %   ic.Panel(p, Title="Content");
            arguments
                this
                props.?ic.SplitterPane
            end
            idx = numel(this.Panes);
            target = sprintf("pane-%d", idx);

            props.ID = this.ID + "-pane-" + idx;
            args = namedargs2cell(props);
            pane = ic.SplitterPane(args{:});

            % Update targets before adding child
            this.Targets = this.generatePaneTargets(idx + 1);

            this.addChild(pane, target);
        end
    end

    methods (Description = "Reactive")
        function out = collapsePane(this, index, direction)
            % > COLLAPSEPANE collapse the pane at the given 0-based index
            %
            % Direction controls which neighbor absorbs the freed space:
            %   "left"  — left/above neighbor (default)
            %   "right" — right/below neighbor
            arguments
                this
                index (1,1) double
                direction (1,1) string {mustBeMember(direction, ...
                    ["left", "right"])} = "left"
            end

            if index < 0 || index >= numel(this.Panes)
                error('ic:Splitter:IndexOutOfBounds', ...
                    'Collapse index %d out of bounds (0-%d).', ...
                    index, numel(this.Panes) - 1);
            end

            out = this.publish("collapsePane", ...
                struct('index', index, 'direction', direction));
        end
    end

    methods (Access = public)
        function validateChild(this, child, target)
            % > VALIDATECHILD only SplitterPane allowed as direct children
            assert(isa(child, "ic.SplitterPane"), ...
                "ic:Splitter:InvalidChild", ...
                "Splitter only accepts SplitterPane children. " + ...
                "Use splitter.addPane() to create panes.");

            % Check pane slot is not already occupied
            existing = this.getChildrenInTarget(target);
            if ~isempty(existing)
                error('ic:Splitter:PaneOccupied', ...
                    'Target "%s" is already occupied.', target);
            end

            validateChild@ic.core.ComponentContainer(this, child, target);
        end
    end

    methods (Access = private)
        function targets = generatePaneTargets(~, numPanes)
            targets = "pane-" + string(0:numPanes-1);
        end
    end

end

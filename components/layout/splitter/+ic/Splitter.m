classdef Splitter < ic.core.ComponentContainer
    % resizable split pane container.
    % Divides space into resizable panes separated by draggable gutters. Use #ic.Splitter.addPane to create panes, then configure the panes properties individually

    properties (SetObservable, AbortSet, Description = "Reactive")
        % split orientation
        Direction (1,1) string {mustBeMember(Direction, ...
            ["horizontal", "vertical"])} = "horizontal"

        % size of the draggable gutter between panes, in pixels
        GutterSize (1,1) double = 5

        % whether resizing is disabled
        Disabled (1,1) logical = false
    end

    properties (Dependent, SetAccess = private)
        % current percentage sizes of all panes
        Sizes

        % array of #ic.SplitterPane children
        Panes
    end

    events (Description = "Reactive")
        % fires after pane sizes change
        % {payload}
        % sizes | double array: percentage sizes of all panes after the resize
        % {/payload}
        Resized
    end

    methods
        function this = Splitter(props)
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
                mask = arrayfun(@(c) isa(c, 'ic.SplitterPane'), this.Children);
                panes = this.Children(mask);
            end
        end

        function pane = addPane(this, props)
            % add a new pane to the splitter.
            % {returns} the created #ic.SplitterPane {/returns}
            % {example}
            %   p = splitter.addPane(Size=40, MinSize=10);
            %   p.addChild(ic.Label(Text="Content"));
            % {/example}
            arguments
                this
                % name-value pairs for configuring the #ic.SplitterPane properties
                props.?ic.SplitterPane
            end
            idx = numel(this.Panes);

            props.ID = this.ID + "-pane-" + idx;
            args = namedargs2cell(props);
            pane = ic.SplitterPane(args{:});

            this.addChild(pane);
        end
    end

    methods (Description = "Reactive")
        function out = collapsePane(this, index, direction)
            % collapse the pane at the given index
            arguments
                this
                % index of the pane to collapse
                index (1,1) double
                % controls which neighbor absorbs the freed space: "left" means the left or above neighbor (default), "right" means the right or below neighbor.
                direction (1,1) string {mustBeMember(direction, ...
                    ["left", "right"])} = "left"
            end

            if index < 1 || index > numel(this.Panes)
                error('ic:Splitter:IndexOutOfBounds', ...
                    'Collapse index %d out of bounds (1-%d).', ...
                    index, numel(this.Panes));
            end

            out = this.publish("collapsePane", ...
                struct('index', index-1, 'direction', direction));
        end
    end

    methods (Hidden)
        function validateChild(this, child)
            assert(isa(child, "ic.SplitterPane"), ...
                "ic:Splitter:InvalidChild", ...
                "Splitter only accepts SplitterPane children. " + ...
                "Use splitter.addPane() to create panes.");

            validateChild@ic.core.ComponentContainer(this, child);
        end
    end

end

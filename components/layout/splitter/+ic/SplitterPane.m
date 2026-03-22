classdef SplitterPane < ic.core.ComponentContainer
    % > SPLITTERPANE A single pane within a Splitter container.
    %
    % SplitterPane holds sizing constraints and user content for one
    % pane of a Splitter. Create panes via Splitter.addPane(), not
    % directly.
    %
    % Example:
    %   s = ic.Splitter();
    %   pane = s.addPane();
    %   pane.Size = 30;
    %   pane.MinSize = 10;
    %   pane.SnapSize = 5;
    %   pane.collapse();

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > SIZE percentage size (0-100). NaN = auto-distribute
        Size (1,1) double = NaN

        % > MINSIZE minimum percentage size
        MinSize (1,1) double = 0

        % > MAXSIZE maximum percentage size
        MaxSize (1,1) double = 100

        % > SNAPSIZE snap threshold percentage; snaps to min when within minSize + snapSize
        SnapSize (1,1) double = 0
    end

    methods
        function this = SplitterPane(props)
            % > SPLITTERPANE Create a splitter pane.
            arguments
                props.?ic.SplitterPane
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end

        function set.Size(this, val)
            if ~isnan(val)
                val = max(this.MinSize, min(this.MaxSize, val));
            end
            this.Size = val;
        end

        function set.MinSize(this, val)
            this.MinSize = val;
            if ~isnan(this.Size) %#ok<*MCSUP>
                this.Size = max(val, this.Size);
            end
        end

        function set.MaxSize(this, val)
            this.MaxSize = val;
            if ~isnan(this.Size)
                this.Size = min(val, this.Size);
            end
        end

        function collapse(this, direction)
            % > COLLAPSE collapse this pane to its minimum size
            %
            % Direction controls which neighbor absorbs the freed space:
            %   "left"  — left/above neighbor (default)
            %   "right" — right/below neighbor
            arguments
                this
                direction (1,1) string {mustBeMember(direction, ...
                    ["left", "right"])} = "left"
            end
            idx = sscanf(this.Target, "pane-%d");
            this.Parent.collapsePane(idx, direction);
        end
    end
end

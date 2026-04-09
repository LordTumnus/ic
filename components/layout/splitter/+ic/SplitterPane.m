classdef SplitterPane < ic.core.ComponentContainer
    % single pane within an #ic.Splitter container.
    % Holds sizing constraints and user content for one pane. Create panes via #ic.Splitter.addPane, not directly.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % percentage size of this pane (0-100). NaN means the size is auto-distributed among remaining panes
        Size (1,1) double = NaN

        % minimum percentage size that this pane can be resized to
        MinSize (1,1) double = 0

        % maximum percentage size that this pane can be resized to
        MaxSize (1,1) double = 100

        % snap threshold percentage. When the pane is dragged within #ic.SplitterPane.MinSize + #ic.SplitterPane.SnapSize, it snaps to its minimum
        SnapSize (1,1) double = 0
    end

    methods (Access = ?ic.Splitter)
        function this = SplitterPane(props)
            arguments
                props.?ic.SplitterPane
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end

    methods
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
            % collapse this pane to its minimum size.
            arguments
                this
                % controls which neighbor absorbs the freed space: "left" means the left or above neighbor (default), "right" means the right or below neighbor.
                direction (1,1) string {mustBeMember(direction, ...
                    ["left", "right"])} = "left"
            end
            panes = this.Parent.Panes;
            idx = find(arrayfun(@(p) p == this, panes), 1);
            this.Parent.collapsePane(idx, direction);
        end
    end
end

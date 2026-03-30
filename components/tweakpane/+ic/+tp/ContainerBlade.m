classdef (Abstract) ContainerBlade < ic.core.ComponentContainer
    % abstract base for TweakPane structural containers

    properties (SetObservable, AbortSet, Description = "Reactive")
        % display label for this container blade
        Label (1,1) string = ""

        % whether this container is disabled
        Disabled (1,1) logical = false

        % whether this container is hidden
        Hidden (1,1) logical = false
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % insertion order within the parent container
        BladeIndex (1,1) double = 0
    end

    properties (Access = private, Hidden)
        % monotonic counter for stable blade targets
        NextBladeIndex (1,1) double = 0
    end

    methods
        function this = ContainerBlade(props)
            this@ic.core.ComponentContainer(props);
            this.Targets = string.empty;
        end
    end

    methods (Access = public)
        function blade = addSlider(this, props)
            % add a numeric slider blade
            % {returns} the new #ic.tp.Slider {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Slider properties
                props.?ic.tp.Slider
            end
            args = namedargs2cell(props);
            blade = ic.tp.Slider(args{:});
            this.insertBlade(blade);
        end

        function blade = addCheckbox(this, props)
            % add a boolean checkbox blade
            % {returns} the new #ic.tp.Checkbox {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Checkbox properties
                props.?ic.tp.Checkbox
            end
            args = namedargs2cell(props);
            blade = ic.tp.Checkbox(args{:});
            this.insertBlade(blade);
        end

        function blade = addText(this, props)
            % add a text input blade
            % {returns} the new #ic.tp.Text {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Text properties
                props.?ic.tp.Text
            end
            args = namedargs2cell(props);
            blade = ic.tp.Text(args{:});
            this.insertBlade(blade);
        end

        function blade = addColor(this, props)
            % add a color picker blade
            % {returns} the new #ic.tp.Color {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Color properties
                props.?ic.tp.Color
            end
            args = namedargs2cell(props);
            blade = ic.tp.Color(args{:});
            this.insertBlade(blade);
        end

        function blade = addPoint(this, props)
            % add a 2D/3D/4D point input blade
            % {returns} the new #ic.tp.Point {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Point properties
                props.?ic.tp.Point
            end
            args = namedargs2cell(props);
            blade = ic.tp.Point(args{:});
            this.insertBlade(blade);
        end

        function blade = addList(this, props)
            % add a dropdown list blade
            % {returns} the new #ic.tp.List {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.List properties
                props.?ic.tp.List
            end
            args = namedargs2cell(props);
            blade = ic.tp.List(args{:});
            this.insertBlade(blade);
        end

        function blade = addButton(this, props)
            % add a clickable button blade
            % {returns} the new #ic.tp.Button {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Button properties
                props.?ic.tp.Button
            end
            args = namedargs2cell(props);
            blade = ic.tp.Button(args{:});
            this.insertBlade(blade);
        end

        function blade = addSeparator(this, props)
            % add a visual separator
            % {returns} the new #ic.tp.Separator {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Separator properties
                props.?ic.tp.Separator
            end
            args = namedargs2cell(props);
            blade = ic.tp.Separator(args{:});
            this.insertBlade(blade);
        end

        function blade = addMonitor(this, props)
            % add a read-only value monitor blade
            % {returns} the new #ic.tp.Monitor {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Monitor properties
                props.?ic.tp.Monitor
            end
            args = namedargs2cell(props);
            blade = ic.tp.Monitor(args{:});
            this.insertBlade(blade);
        end

        function blade = addFolder(this, props)
            % add a collapsible folder container
            % {returns} the new #ic.tp.Folder {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Folder properties
                props.?ic.tp.Folder
            end
            args = namedargs2cell(props);
            blade = ic.tp.Folder(args{:});
            this.insertBlade(blade);
        end

        function blade = addTabGroup(this, props)
            % add a tab group container
            % {returns} the new #ic.tp.TabGroup {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.TabGroup properties
                props.?ic.tp.TabGroup
            end
            args = namedargs2cell(props);
            blade = ic.tp.TabGroup(args{:});
            this.insertBlade(blade);
        end

        function blade = addIntervalSlider(this, props)
            % add a dual-handle range slider
            % {returns} the new #ic.tp.IntervalSlider {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.IntervalSlider properties
                props.?ic.tp.IntervalSlider
            end
            args = namedargs2cell(props);
            blade = ic.tp.IntervalSlider(args{:});
            this.insertBlade(blade);
        end

        function blade = addFpsGraph(this, props)
            % add an FPS graph blade
            % {returns} the new #ic.tp.FpsGraph {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.FpsGraph properties
                props.?ic.tp.FpsGraph
            end
            args = namedargs2cell(props);
            blade = ic.tp.FpsGraph(args{:});
            this.insertBlade(blade);
        end

        function blade = addRadioGrid(this, props)
            % add a grid of radio buttons
            % {returns} the new #ic.tp.RadioGrid {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.RadioGrid properties
                props.?ic.tp.RadioGrid
            end
            args = namedargs2cell(props);
            blade = ic.tp.RadioGrid(args{:});
            this.insertBlade(blade);
        end

        function blade = addButtonGrid(this, props)
            % add a grid of buttons
            % {returns} the new #ic.tp.ButtonGrid {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.ButtonGrid properties
                props.?ic.tp.ButtonGrid
            end
            args = namedargs2cell(props);
            blade = ic.tp.ButtonGrid(args{:});
            this.insertBlade(blade);
        end

        function blade = addCubicBezier(this, props)
            % add a cubic bezier curve editor
            % {returns} the new #ic.tp.CubicBezier {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.CubicBezier properties
                props.?ic.tp.CubicBezier
            end
            args = namedargs2cell(props);
            blade = ic.tp.CubicBezier(args{:});
            this.insertBlade(blade);
        end

        function blade = addRing(this, props)
            % add a radial dial blade
            % {returns} the new #ic.tp.Ring {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Ring properties
                props.?ic.tp.Ring
            end
            args = namedargs2cell(props);
            blade = ic.tp.Ring(args{:});
            this.insertBlade(blade);
        end

        function blade = addWheel(this, props)
            % add a jog wheel blade
            % {returns} the new #ic.tp.Wheel {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Wheel properties
                props.?ic.tp.Wheel
            end
            args = namedargs2cell(props);
            blade = ic.tp.Wheel(args{:});
            this.insertBlade(blade);
        end

        function blade = addRotation(this, props)
            % add a 3D rotation input blade
            % {returns} the new #ic.tp.Rotation {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Rotation properties
                props.?ic.tp.Rotation
            end
            args = namedargs2cell(props);
            blade = ic.tp.Rotation(args{:});
            this.insertBlade(blade);
        end

        function blade = addTextarea(this, props)
            % add a multi-line text input blade
            % {returns} the new #ic.tp.Textarea {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Textarea properties
                props.?ic.tp.Textarea
            end
            args = namedargs2cell(props);
            blade = ic.tp.Textarea(args{:});
            this.insertBlade(blade);
        end

        function blade = addImage(this, props)
            % add a read-only image display blade
            % {returns} the new #ic.tp.Image {/returns}
            arguments
                this
                % name-value pairs for #ic.tp.Image properties
                props.?ic.tp.Image
            end
            args = namedargs2cell(props);
            blade = ic.tp.Image(args{:});
            this.insertBlade(blade);
        end
    end

    methods (Access = protected)
        function insertBlade(this, blade)
            % assigns index, target, and registers child
            idx = this.NextBladeIndex;
            this.NextBladeIndex = idx + 1;
            target = sprintf("blade-%d", idx);
            blade.BladeIndex = idx;
            this.Targets = [this.Targets, target];
            this.addChild(blade, target);
        end
    end
end

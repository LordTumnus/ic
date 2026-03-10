classdef (Abstract) ContainerBlade < ic.core.ComponentContainer
    % > CONTAINERBLADE Abstract base for TweakPane structural containers.
    %
    % Subclasses: Folder, TabGroup, TabPage.
    % These can hold child blades via the shared addXxx methods.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > LABEL display label for this container blade
        Label (1,1) string = ""
        % > DISABLED whether this container is disabled
        Disabled (1,1) logical = false
        % > HIDDEN whether this container is hidden
        Hidden (1,1) logical = false
    end

    properties (SetObservable, AbortSet, Description = "Reactive", Hidden)
        % > BLADEINDEX insertion order within the parent container (set by parent)
        BladeIndex (1,1) double = 0
    end

    properties (Access = private)
        % > NEXTBLADEINDEX monotonic counter for stable blade targets
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
            % > ADDSLIDER add a numeric slider blade
            arguments
                this
                props.?ic.tp.Slider
            end
            args = namedargs2cell(props);
            blade = ic.tp.Slider(args{:});
            this.insertBlade(blade);
        end

        function blade = addCheckbox(this, props)
            % > ADDCHECKBOX add a boolean checkbox blade
            arguments
                this
                props.?ic.tp.Checkbox
            end
            args = namedargs2cell(props);
            blade = ic.tp.Checkbox(args{:});
            this.insertBlade(blade);
        end

        function blade = addText(this, props)
            % > ADDTEXT add a text input blade
            arguments
                this
                props.?ic.tp.Text
            end
            args = namedargs2cell(props);
            blade = ic.tp.Text(args{:});
            this.insertBlade(blade);
        end

        function blade = addColor(this, props)
            % > ADDCOLOR add a color picker blade
            arguments
                this
                props.?ic.tp.Color
            end
            args = namedargs2cell(props);
            blade = ic.tp.Color(args{:});
            this.insertBlade(blade);
        end

        function blade = addPoint(this, props)
            % > ADDPOINT add a 2D/3D/4D point input blade
            arguments
                this
                props.?ic.tp.Point
            end
            args = namedargs2cell(props);
            blade = ic.tp.Point(args{:});
            this.insertBlade(blade);
        end

        function blade = addList(this, props)
            % > ADDLIST add a dropdown list blade
            arguments
                this
                props.?ic.tp.List
            end
            args = namedargs2cell(props);
            blade = ic.tp.List(args{:});
            this.insertBlade(blade);
        end

        function blade = addButton(this, props)
            % > ADDBUTTON add a clickable button blade
            arguments
                this
                props.?ic.tp.Button
            end
            args = namedargs2cell(props);
            blade = ic.tp.Button(args{:});
            this.insertBlade(blade);
        end

        function blade = addSeparator(this, props)
            % > ADDSEPARATOR add a visual separator
            arguments
                this
                props.?ic.tp.Separator
            end
            args = namedargs2cell(props);
            blade = ic.tp.Separator(args{:});
            this.insertBlade(blade);
        end

        function blade = addMonitor(this, props)
            % > ADDMONITOR add a read-only monitor blade
            arguments
                this
                props.?ic.tp.Monitor
            end
            args = namedargs2cell(props);
            blade = ic.tp.Monitor(args{:});
            this.insertBlade(blade);
        end

        function blade = addFolder(this, props)
            % > ADDFOLDER add a collapsible folder
            arguments
                this
                props.?ic.tp.Folder
            end
            args = namedargs2cell(props);
            blade = ic.tp.Folder(args{:});
            this.insertBlade(blade);
        end

        function blade = addTabGroup(this, props)
            % > ADDTABGROUP add a tab group container
            arguments
                this
                props.?ic.tp.TabGroup
            end
            args = namedargs2cell(props);
            blade = ic.tp.TabGroup(args{:});
            this.insertBlade(blade);
        end

        function blade = addIntervalSlider(this, props)
            % > ADDINTERVALSLIDER add a dual-handle range slider (plugin-essentials)
            arguments
                this
                props.?ic.tp.IntervalSlider
            end
            args = namedargs2cell(props);
            blade = ic.tp.IntervalSlider(args{:});
            this.insertBlade(blade);
        end

        function blade = addFpsGraph(this, props)
            % > ADDFPSGRAPH add an FPS graph blade (plugin-essentials)
            arguments
                this
                props.?ic.tp.FpsGraph
            end
            args = namedargs2cell(props);
            blade = ic.tp.FpsGraph(args{:});
            this.insertBlade(blade);
        end

        function blade = addRadioGrid(this, props)
            % > ADDRADIOGRID add a grid of radio buttons (plugin-essentials)
            arguments
                this
                props.?ic.tp.RadioGrid
            end
            args = namedargs2cell(props);
            blade = ic.tp.RadioGrid(args{:});
            this.insertBlade(blade);
        end

        function blade = addButtonGrid(this, props)
            % > ADDBUTTONGRID add a grid of buttons (plugin-essentials)
            arguments
                this
                props.?ic.tp.ButtonGrid
            end
            args = namedargs2cell(props);
            blade = ic.tp.ButtonGrid(args{:});
            this.insertBlade(blade);
        end

        function blade = addCubicBezier(this, props)
            % > ADDCUBICBEZIER add a cubic bezier curve editor (plugin-essentials)
            arguments
                this
                props.?ic.tp.CubicBezier
            end
            args = namedargs2cell(props);
            blade = ic.tp.CubicBezier(args{:});
            this.insertBlade(blade);
        end
    end

    methods (Access = protected)
        function insertBlade(this, blade)
            % > INSERTBLADE internal — assigns index, target, and adds child
            idx = this.NextBladeIndex;
            this.NextBladeIndex = idx + 1;
            target = sprintf("blade-%d", idx);
            blade.BladeIndex = idx;
            this.Targets = [this.Targets, target];
            this.addChild(blade, target);
        end
    end
end

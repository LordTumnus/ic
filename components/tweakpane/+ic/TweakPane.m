classdef TweakPane < ic.core.ComponentContainer
    % > TWEAKPANE Compact parameter control panel using Tweakpane.
    %
    % Create a pane and add controls:
    %   tp = ic.TweakPane(Title="Parameters");
    %   slider = tp.addSlider(Label="Speed", Min=0, Max=100, Value=50);
    %   tp.addCheckbox(Label="Enabled", Value=true);
    %   folder = tp.addFolder(Label="Advanced");
    %   folder.addSlider(Label="Detail", Min=0, Max=10, Value=5);
    %
    % Supports all ic.tp.* blade types: Slider, Checkbox, Text, Color,
    % Point, List, Button, Separator, Monitor, Folder, TabGroup,
    % IntervalSlider, FpsGraph, RadioGrid, ButtonGrid, CubicBezier,
    % Ring, Wheel, Rotation, Textarea, Image.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > TITLE optional title displayed at the top of the pane
        Title (1,1) string = ""
        % > EXPANDED whether the pane is expanded
        Expanded (1,1) logical = true
    end

    properties (Access = private)
        % > NEXTBLADEINDEX monotonic counter for stable blade targets
        NextBladeIndex (1,1) double = 0
    end

    methods
        function this = TweakPane(props)
            arguments
                props.?ic.TweakPane
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = string.empty;
        end
    end

    % --- Blade creation API (mirrors ContainerBlade) ---------------------

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
            % > ADDINTERVALSLIDER add a dual-handle range slider
            arguments
                this
                props.?ic.tp.IntervalSlider
            end
            args = namedargs2cell(props);
            blade = ic.tp.IntervalSlider(args{:});
            this.insertBlade(blade);
        end

        function blade = addFpsGraph(this, props)
            % > ADDFPSGRAPH add an FPS graph blade
            arguments
                this
                props.?ic.tp.FpsGraph
            end
            args = namedargs2cell(props);
            blade = ic.tp.FpsGraph(args{:});
            this.insertBlade(blade);
        end

        function blade = addRadioGrid(this, props)
            % > ADDRADIOGRID add a grid of radio buttons
            arguments
                this
                props.?ic.tp.RadioGrid
            end
            args = namedargs2cell(props);
            blade = ic.tp.RadioGrid(args{:});
            this.insertBlade(blade);
        end

        function blade = addButtonGrid(this, props)
            % > ADDBUTTONGRID add a grid of buttons
            arguments
                this
                props.?ic.tp.ButtonGrid
            end
            args = namedargs2cell(props);
            blade = ic.tp.ButtonGrid(args{:});
            this.insertBlade(blade);
        end

        function blade = addCubicBezier(this, props)
            % > ADDCUBICBEZIER add a cubic bezier curve editor
            arguments
                this
                props.?ic.tp.CubicBezier
            end
            args = namedargs2cell(props);
            blade = ic.tp.CubicBezier(args{:});
            this.insertBlade(blade);
        end

        function blade = addRing(this, props)
            % > ADDRING add a radial dial blade (plugin-camerakit)
            arguments
                this
                props.?ic.tp.Ring
            end
            args = namedargs2cell(props);
            blade = ic.tp.Ring(args{:});
            this.insertBlade(blade);
        end

        function blade = addWheel(this, props)
            % > ADDWHEEL add a jog wheel blade (plugin-camerakit)
            arguments
                this
                props.?ic.tp.Wheel
            end
            args = namedargs2cell(props);
            blade = ic.tp.Wheel(args{:});
            this.insertBlade(blade);
        end

        function blade = addRotation(this, props)
            % > ADDROTATION add a 3D rotation input blade (plugin-rotation)
            arguments
                this
                props.?ic.tp.Rotation
            end
            args = namedargs2cell(props);
            blade = ic.tp.Rotation(args{:});
            this.insertBlade(blade);
        end

        function blade = addTextarea(this, props)
            % > ADDTEXTAREA add a multi-line text input blade (plugin-textarea)
            arguments
                this
                props.?ic.tp.Textarea
            end
            args = namedargs2cell(props);
            blade = ic.tp.Textarea(args{:});
            this.insertBlade(blade);
        end

        function blade = addImage(this, props)
            % > ADDIMAGE add a read-only image display blade
            arguments
                this
                props.?ic.tp.Image
            end
            args = namedargs2cell(props);
            blade = ic.tp.Image(args{:});
            this.insertBlade(blade);
        end
    end

    methods (Access = private)
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

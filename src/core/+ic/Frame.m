% > FRAME is the root component that holds other interactive components and bridges them to the HTML view
classdef Frame < ic.core.ComponentBase & ic.core.Container

    properties (SetAccess = private)
        % > VIEW the view bridge that handles HTML communication
        View ic.core.View
    end

    properties (Dependent)
        Position (1,4) double
        Visible (1,1) matlab.lang.OnOffSwitchState
        Units (1,1) string
        Layout matlab.ui.layout.GridLayoutOptions
        UIParent (1,1) matlab.ui.container.Container
    end

    properties (Dependent, Hidden)
        Parent (1,1) matlab.ui.container.Container
    end

    methods
        function this = Frame(args)
            % > FRAME creates a frame component that can hold other interactive components
            arguments (Input)
                % > ARGS optional name-value pairs of properties of the frame
                args.?matlab.ui.componentcontainer.ComponentContainer
            end
            arguments (Output)
                % > THIS the frame
                this (1,1) ic.Frame
            end

            % call superclass constructor with frame ID
            this@ic.core.ComponentBase("@ic.frame");

            % initialize the view
            args = namedargs2cell(args);
            this.View = ic.core.View(this, args{:});
        end

        function delete(this)
            % DELETE cleans up the Frame and its View
            delete(this.View);
        end

        function position = get.Position(this)
            position = this.View.Position;
        end

        function visible = get.Visible(this)
            visible = this.View.Visible;
        end

        function units = get.Units(this)
            units = string(this.View.Units);
        end

        function layout = get.Layout(this)
            layout = this.View.Layout;
        end

        function parent = get.Parent(this)
            warning("Frame objects will not appear as Children of their uicontainer. To remove this warning, use UIParent instead");
            parent = this.View.Parent;
        end

        function uiparent = get.UIParent(this)
            uiparent = this.View.Parent;
        end


        function set.Position(this, position)
            this.View.Position = position;
        end

        function set.Visible(this, visible)
            this.View.Visible = visible;
        end

        function set.Units(this, units)
            this.View.Units = units;
        end

        function set.Layout(this, layout)
            this.View.Layout = layout;
        end

        function set.Parent(this, parent)
            warning("Frame objects will not appear as Children of their uicontainer. To remove this warning, use UIParent instead");
            this.View.Parent = parent;
        end

        function set.UIParent(this, uiparent)
            this.View.Parent = uiparent;
        end

    end

    methods (Access = public)
        function tf = isAttached(~)
            % > ISATTACHED Frame is always attached (it's the root)
            tf = true;
        end
    end

    methods (Access = protected)
        function send(this, evt)
            % > SEND delegates to the View instead of parent
            this.View.send(evt);
        end

        function moveEventToEnd(this, evt)
            % > MOVEEVENTTOEND delegates to the View
            this.View.moveEventToEnd(evt);
        end
    end

end

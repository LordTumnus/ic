% > FRAME is the root component that holds other interactive components and bridges them to the HTML view
classdef Frame < ic.core.ComponentBase & ic.core.Container

    properties (SetAccess = private)
        % > VIEW the view bridge that handles HTML communication
        View ic.core.View
        % > REGISTRY map of component IDs to components for O(1) event dispatch
        Registry = dictionary(string.empty(), ic.core.ComponentBase.empty())
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

    properties (Constan)
        % > TARGETS the list of possible targets for the frame's children (none, as frame is root)
        Targets string = string.empty()
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

            addlistener(this.View, "ObjectBeingDestroyed", ...
                @(~,~) this.delete());
        end

        function delete(this)
            % DELETE cleans up the Frame and its View
            if isvalid(this.View)
                this.View.delete();
            end
            delete@ic.core.Container(this);
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

        function registerSubtree(this, component)
            % > REGISTERSUBTREE registers a component and its subtree (Frame is the registry)
            ic.core.Container.registerSubtreeWithFrame(component, this);
        end

        function deregisterSubtree(this, component)
            % > DEREGISTERSUBTREE deregisters a component and its subtree (Frame is the registry)
            ic.core.Container.deregisterSubtreeWithFrame(component, this);
        end

        function definition = getComponentDefinition(this)
            % > GETCOMPONENTDEFINITION returns the component definition struct for this frame
            definition = getComponentDefinition@ic.core.ComponentBase(this);
            definition.targets = num2cell(string.empty());
    end

    methods (Access = {?ic.core.Container})
        function registerDescendant(this, component)
            % > REGISTERDESCENDANT adds a component to the registry for O(1) event dispatch
            this.Registry(component.ID) = component;
        end

        function deregisterDescendant(this, id)
            % > DEREGISTERDESCENDANT removes a component from the registry
            if this.Registry.isKey(id)
                this.Registry(id) = [];
            end
        end
    end

end

classdef Drawer < ic.core.ComponentContainer & ic.mixin.Overlay
    % #ic.mixin.Overlay slide-in panel with a title bar, content body, and optional backdrop.
    % {superclass}
    %   #ic.mixin.Overlay
    % {/superclass}

    properties (SetObservable, AbortSet, Description = "Reactive")
        % heading text displayed in the drawer header
        Title string = ""

        % whether the drawer is visible
        Open logical = false

        % edge from which the drawer slides in
        Side string {mustBeMember(Side, ["left", "right", "top", "bottom"])} = "right"

        % panel dimension (width or height, depending on #ic.Drawer.Side) relative to the font size of the component. "full" makes the drawer take the entire width/height of the viewport.
        Size string {mustBeMember(Size, ["sm", "md", "lg", "xl", "full"])} = "md"

        % whether the close button and Escape key to close the panel are enabled
        Closable logical = true

        % whether to show a backdrop behind the panel
        Overlay logical = true

        % whether clicking the backdrop closes the drawer
        CloseOnBackdropClick logical = true
    end

    properties (SetAccess = immutable)
        % container for the drawer header content
        Header ic.drawer.DrawerHeader

        % container for the drawer body content. Add children here.
        Body ic.drawer.DrawerBody
    end

    events (Description = "Reactive")
        % fires when the user dismisses the drawer (close button, Escape, or backdrop click)
        Closed
    end

    methods
        function this = Drawer(props)
            arguments
                props.?ic.Drawer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Header = ic.drawer.DrawerHeader();
            this.addChild(this.Header);
            this.Body = ic.drawer.DrawerBody();
            this.addChild(this.Body);
        end

        function open(this)
            % programmatically open the drawer
            this.Open = true;
        end

        function close(this)
            % programmatically close the drawer without firing the Closed event
            this.Open = false;
        end

        function effect = bindOpen(this, component, event)
            % utility function to wire a DOM event on a component to open the drawer
            % {note} Uses #ic.mixin.Effectable.jsEffect under the hood to inject a JavaScript event listener on the specified component that sets the drawer's open prop to true when triggered
            arguments
                this
                % component whose DOM event triggers the open
                component
                % DOM event name to listen for
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dw) => { c.el?.addEventListener('%s', () => { dw.props.open = true; }); }", ...
                event));
        end

        function effect = bindClose(this, component, event)
            % utility function to wire a DOM event on a component to close the drawer. See #ic.Drawer.bindOpen for details on how this function works under the hood
            arguments
                this
                % component whose DOM event triggers the close
                component
                % DOM event name to listen for
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dw) => { c.el?.addEventListener('%s', () => { dw.props.open = false; dw.props.closed?.({}); }); }", ...
                event));
        end
    end

    methods (Hidden)
        function validateChild(~, child)
            % Drawer only accepts its own sub-containers.
            % Use drawer.Body.addChild(...) or drawer.Header.addChild(...) instead.
            if ~isa(child, 'ic.drawer.DrawerBody') && ~isa(child, 'ic.drawer.DrawerHeader')
                error("ic:Drawer:InvalidChild", ...
                    "Cannot add children to Drawer directly. " + ...
                    "Use drawer.Body.addChild(...) or drawer.Header.addChild(...) instead.");
            end
        end
    end
end

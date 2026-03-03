classdef Drawer < ic.core.ComponentContainer & ic.mixin.Overlay
    % > DRAWER Slide-in panel overlay with title, body, and optional backdrop.
    %
    %   d = ic.Drawer(Title="Settings", Side="right", Size="md");
    %   d.addChild(ic.Label(Label="Panel content"));
    %   frame.addOverlay(d);
    %   d.open();
    %
    %   addlistener(d, 'Closed', @(~,~) disp("Drawer closed"));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > TITLE heading text displayed in the drawer header
        Title string = ""
        % > OPEN whether the drawer is visible
        Open logical = false
        % > SIDE edge from which the drawer slides in
        Side string {mustBeMember(Side, ["left", "right", "top", "bottom"])} = "right"
        % > SIZE panel width (left/right) or height (top/bottom)
        Size string {mustBeMember(Size, ["sm", "md", "lg", "xl", "full"])} = "md"
        % > CLOSABLE whether the close button and Escape key are enabled
        Closable logical = true
        % > OVERLAY whether to show the backdrop behind the panel
        Overlay logical = true
        % > CLOSEONBACKDROPCLICK whether clicking the backdrop closes the drawer
        CloseOnBackdropClick logical = true
    end

    events (Description = "Reactive")
        % > CLOSED fires when the user dismisses the drawer (close button, Escape, backdrop)
        Closed
    end

    methods
        function this = Drawer(props)
            arguments
                props.?ic.Drawer
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = ["body", "header"];
        end

        function open(this)
            % > OPEN programmatically open the drawer
            this.Open = true;
        end

        function close(this)
            % > CLOSE programmatically close the drawer (no Closed event)
            this.Open = false;
        end

        function effect = bindOpen(this, component, event)
            % > BINDOPEN wires a DOM event on a component to open the drawer.
            arguments
                this
                component
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dw) => { c.el?.addEventListener('%s', () => { dw.props.open = true; }); }", ...
                event));
        end

        function effect = bindClose(this, component, event)
            % > BINDCLOSE wires a DOM event on a component to trigger drawer close.
            arguments
                this
                component
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dw) => { c.el?.addEventListener('%s', () => { dw.props.open = false; dw.props.closed?.({}); }); }", ...
                event));
        end
    end
end

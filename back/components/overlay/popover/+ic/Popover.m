classdef Popover < ic.core.ComponentContainer
    % > POPOVER Floating panel anchored to a trigger component.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > OPEN whether the panel is visible
        Open logical = false
        % > SIDE edge of the trigger where the panel appears
        Side string {mustBeMember(Side, ["top","right","bottom","left"])} = "bottom"
        % > ALIGN alignment of the panel along the side axis
        Align string {mustBeMember(Align, ["start","center","end"])} = "center"
        % > OFFSET gap in pixels between trigger and panel
        Offset double = 4
        % > AVOIDCOLLISIONS reposition the panel to stay within the viewport
        AvoidCollisions logical = true
    end

    properties (SetAccess = private)
        % > TRIGGER the trigger component (read-only)
        Trigger
        % > PANEL the content panel component (read-only)
        Panel
        % > ISDELETING flag to check if the popover is being deleted
        IsDeleting logical = false
    end

    events (Description = "Reactive")
        % > OPENED fires when the panel becomes visible via user click
        Opened
        % > CLOSED fires when the panel is dismissed (click-outside, Escape, bindClose)
        Closed
    end

    methods
        function this = Popover(trigger, props)
            arguments
                trigger (1,1) ic.core.Component
                props.?ic.Popover
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);

            % Static children — no Targets, no external addChild
            this.Trigger = trigger;
            this.addStaticChild(trigger, "trigger");

            this.Panel = ic.popover.Panel(ID = this.ID + "-panel");
            this.addStaticChild(this.Panel, "panel");

            addlistener(trigger, 'ObjectBeingDestroyed', ...
                @(~,~) safeDelete(this));
        end

        function open(this)
            % > OPEN programmatically open the popover
            this.Open = true;
        end

        function close(this)
            % > CLOSE programmatically close the popover (no Closed event)
            this.Open = false;
        end

        function effect = bindClose(this, component, event)
            % > BINDCLOSE wires a DOM event on a component to close the popover.
            arguments
                this
                component
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, pop) => { c.el?.addEventListener('%s', () => { pop.props.open = false; pop.props.closed?.({}); }); }", ...
                event));
        end

        function delete(this)
            this.IsDeleting = true;
        end
    end
end

function safeDelete(obj)
    if isvalid(obj) && ~obj.IsDeleting, delete(obj); end
end

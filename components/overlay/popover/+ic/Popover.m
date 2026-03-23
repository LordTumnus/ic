classdef Popover < ic.core.ComponentContainer
    % floating panel anchored to a trigger component.
    % The popover opens when the user clicks the trigger and closes on click-outside or presses Escape. Add children to the panel via the #ic.popover.Panel returned by the Popover's Panel property.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % whether the panel is visible
        Open logical = false

        % edge of the trigger where the panel appears
        Side string {mustBeMember(Side, ["top","right","bottom","left"])} = "bottom"

        % alignment of the panel along the side axis
        Align string {mustBeMember(Align, ["start","center","end"])} = "center"

        % gap in pixels between trigger and panel
        Offset double = 4

        % whether to reposition the panel to stay within the viewport
        AvoidCollisions logical = true
    end

    properties (SetAccess = private)
        % the trigger component that anchors the popover
        Trigger

        % the content panel container
        Panel

        % internal flag used during deletion
        IsDeleting logical = false
    end

    events (Description = "Reactive")
        % fires when the panel becomes visible via user click on the trigger
        Opened

        % fires when the panel is dismissed (click-outside, Escape, or bindClose)
        Closed
    end

    methods
        function this = Popover(trigger, props)
            arguments
                % the component that anchors the popover
                trigger (1,1) ic.core.Component
                props.?ic.Popover
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);

            % static children
            this.Trigger = trigger;
            this.addStaticChild(trigger, "trigger");

            this.Panel = ic.popover.Panel(ID = this.ID + "-panel");
            this.addStaticChild(this.Panel, "panel");

            addlistener(trigger, 'ObjectBeingDestroyed', ...
                @(~,~) safeDelete(this));
        end

        function open(this)
            % programmatically open the popover
            this.Open = true;
        end

        function close(this)
            % programmatically close the popover without firing the Closed event
            this.Open = false;
        end

        function effect = bindClose(this, component, event)
            % utility function to wire a DOM event on a component to close the popover and fire the Closed event.
            arguments
                this
                % component whose DOM event triggers the close
                component
                % DOM event name to listen for
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, pop) => { c.el?.addEventListener('%s', () => { pop.props.open = false; pop.props.closed?.({}); }); }", ...
                event));
        end

        function delete(this)
            % override delete to clean up listeners and avoid firing events on deleted popovers
            this.IsDeleting = true;
        end
    end
end

function safeDelete(obj)
    if isvalid(obj) && ~obj.IsDeleting, delete(obj); end
end

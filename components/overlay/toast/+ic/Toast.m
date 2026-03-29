classdef Toast < ic.core.Component & ic.mixin.Overlay
    % ephemeral notification message.
    % Displays a brief message that auto-dismisses after #ic.Toast.Duration seconds. The toast auto-deletes when closed (either by timeout, close button, or #ic.Toast.dismiss).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % message text displayed in the toast
        Value string = ""

        % visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "success", "warning", "destructive", "info"])} = "primary"

        % seconds until auto-dismiss (use 0 for a persistent toast that must be dismissed manually)
        Duration double {mustBeNonnegative} = 3

        % vertical position on screen
        Position string {mustBeMember(Position, ["top", "bottom"])} = "bottom"

        % whether to show the close button
        Closable logical = true

        % custom icon displayed before the message. When empty, a default icon is shown based on the variant
        Icon ic.Asset = ic.Asset.empty
    end

    properties (Access = private)
        ClosedListener event.listener
    end

    events (Description = "Reactive")
        % fires when the toast is dismissed (timeout, close button, or programmatic dismiss). The toast is automatically deleted after this event
        Closed
    end

    methods
        function this = Toast(props)
            arguments
                props.?ic.Toast
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
            this.ClosedListener = addlistener(this, 'Closed', ...
                @(src, ~) delete(src));
        end
    end

    methods (Description = "Reactive")
        function out = dismiss(this)
            % programmatically dismiss and remove the toast
            % {example}
            %    t = ic.Toast("Value", "Data saved successfully!", "Variant", "success");
            %    frame.addChild(t);
            %    pause(2);
            %    t.dismiss();
            % {/example}

            out = this.publish("dismiss", []);
        end
    end
end

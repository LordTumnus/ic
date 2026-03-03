classdef Toast < ic.core.Component
    % > TOAST Ephemeral notification message.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE message text displayed in the toast
        Value string = ""
        % > VARIANT visual style variant
        Variant string {mustBeMember(Variant, ...
            ["primary", "success", "warning", "destructive", "info"])} = "primary"
        % > DURATION seconds until auto-dismiss (0 = persistent)
        Duration double {mustBeNonnegative} = 3
        % > POSITION vertical position on screen
        Position string {mustBeMember(Position, ["top", "bottom"])} = "bottom"
        % > CLOSABLE whether to show the close button
        Closable logical = true
        % > ICON custom icon (empty = default per variant)
        Icon ic.asset.Asset = ic.asset.Asset.empty
    end

    properties (Access = private)
        % > CLOSELISTENER listener for when the toast is closed in the view
        ClosedListener event.listener
    end

    events (Description = "Reactive")
        Closed
    end

    methods (Access = {?ic.Frame})
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
            % > DISMISS programmatically close and remove the toast
            out = this.publish("dismiss", []);
        end
    end
end

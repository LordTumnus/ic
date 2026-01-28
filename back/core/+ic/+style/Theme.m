% > THEME stores CSS custom property values with light/dark scheme support.
% Color properties store [light, dark] pairs; non-color properties store single values.
classdef Theme < handle

    properties (SetAccess = ?ic.Frame)
        % > BACKGROUND page and component background color
        Background (1,2) string = ["#ffffff", "#09090b"]
        % > FOREGROUND default text color
        Foreground (1,2) string = ["#09090b", "#fafafa"]

        % > PRIMARY main brand/action color
        Primary (1,2) string = ["#18181b", "#fafafa"]
        % > PRIMARYFOREGROUND text on primary backgrounds
        PrimaryForeground (1,2) string = ["#fafafa", "#18181b"]

        % > SECONDARY alternative action color
        Secondary (1,2) string = ["#f4f4f5", "#27272a"]
        % > SECONDARYFOREGROUND text on secondary backgrounds
        SecondaryForeground (1,2) string = ["#18181b", "#fafafa"]

        % > MUTED subtle background for less prominent elements
        Muted (1,2) string = ["#f4f4f5", "#27272a"]
        % > MUTEDFOREGROUND text on muted backgrounds
        MutedForeground (1,2) string = ["#71717a", "#a1a1aa"]

        % > ACCENT highlight/emphasis color
        Accent (1,2) string = ["#f4f4f5", "#27272a"]
        % > ACCENTFOREGROUND text on accent backgrounds
        AccentForeground (1,2) string = ["#18181b", "#fafafa"]

        % > DESTRUCTIVE error/danger color
        Destructive (1,2) string = ["#ef4444", "#7f1d1d"]
        % > DESTRUCTIVEFOREGROUND text on destructive backgrounds
        DestructiveForeground (1,2) string = ["#fafafa", "#fef2f2"]

        % > BORDER default border color
        Border (1,2) string = ["#e4e4e7", "#27272a"]
        % > INPUT input field border color
        Input (1,2) string = ["#e4e4e7", "#27272a"]
        % > RING focus ring color
        Ring (1,2) string = ["#18181b", "#d4d4d8"]

        % > RADIUS default border radius
        Radius (1,1) string = "0.5rem"
    end

    properties (GetAccess = public, SetAccess = ?ic.Frame)
        % > ACTIVESCHEME current color scheme
        ActiveScheme (1,1) string {mustBeMember(ActiveScheme, ["light", "dark"])} = "light"
    end

    methods
        function css = jsonencode(this, varargin)
            % > JSONENCODE returns CSS custom properties as a JSON string.
            % Called automatically when the Theme is serialized for the frontend.

            s = struct();

            % Color properties use light-dark() syntax
            colorProps = ["Background", "Foreground", ...
                          "Primary", "PrimaryForeground", ...
                          "Secondary", "SecondaryForeground", ...
                          "Muted", "MutedForeground", ...
                          "Accent", "AccentForeground", ...
                          "Destructive", "DestructiveForeground", ...
                          "Border", "Input", "Ring"];

            for ii = 1:numel(colorProps)
                propName = colorProps(ii);
                cssName = ic.utils.toKebabCase(propName);
                values = this.(propName);
                s.(cssName) = sprintf("light-dark(%s, %s)", values(1), values(2));
            end

            % Non-color properties are set directly
            s.radius = this.Radius;

            css = jsonencode(s, varargin{:});
        end
    end

end

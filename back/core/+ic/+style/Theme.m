% > THEME stores CSS custom property values with light/dark scheme support.
% Color properties store [light, dark] pairs; non-color properties store single values.
classdef Theme < handle

    properties (SetAccess = ?ic.Frame)
        % Slate-based engineering palette with blue accents

        % > BACKGROUND page and component background color
        Background (1,2) string = ["#f8fafc", "#0f172a"]
        % > FOREGROUND default text color
        Foreground (1,2) string = ["#0f172a", "#f1f5f9"]

        % > PRIMARY main brand/action color (engineering blue)
        Primary (1,2) string = ["#2563eb", "#3b82f6"]
        % > PRIMARYFOREGROUND text on primary backgrounds
        PrimaryForeground (1,2) string = ["#ffffff", "#ffffff"]

        % > SECONDARY alternative action color
        Secondary (1,2) string = ["#e2e8f0", "#1e293b"]
        % > SECONDARYFOREGROUND text on secondary backgrounds
        SecondaryForeground (1,2) string = ["#0f172a", "#f1f5f9"]

        % > MUTED subtle background for less prominent elements
        Muted (1,2) string = ["#f1f5f9", "#1e293b"]
        % > MUTEDFOREGROUND text on muted backgrounds
        MutedForeground (1,2) string = ["#64748b", "#94a3b8"]

        % > ACCENT highlight/emphasis color
        Accent (1,2) string = ["#dbeafe", "#1e3a5f"]
        % > ACCENTFOREGROUND text on accent backgrounds
        AccentForeground (1,2) string = ["#1e40af", "#93c5fd"]

        % > DESTRUCTIVE error/danger color
        Destructive (1,2) string = ["#dc2626", "#ef4444"]
        % > DESTRUCTIVEFOREGROUND text on destructive backgrounds
        DestructiveForeground (1,2) string = ["#ffffff", "#ffffff"]

        % > SUCCESS positive/success color
        Success (1,2) string = ["#16a34a", "#22c55e"]
        % > SUCCESSFOREGROUND text on success backgrounds
        SuccessForeground (1,2) string = ["#ffffff", "#ffffff"]

        % > WARNING caution/warning color
        Warning (1,2) string = ["#d97706", "#f59e0b"]
        % > WARNINGFOREGROUND text on warning backgrounds
        WarningForeground (1,2) string = ["#ffffff", "#18181b"]

        % > INFO informational color
        Info (1,2) string = ["#0284c7", "#38bdf8"]
        % > INFOFOREGROUND text on info backgrounds
        InfoForeground (1,2) string = ["#ffffff", "#18181b"]

        % > BORDER default border color
        Border (1,2) string = ["#cbd5e1", "#334155"]
        % > INPUT input field border color
        Input (1,2) string = ["#cbd5e1", "#475569"]
        % > RING focus ring color
        Ring (1,2) string = ["#2563eb", "#3b82f6"]

        % > RADIUS default border radius
        Radius (1,1) string = "0.375rem"
    end

    properties (GetAccess = public, SetAccess = ?ic.Frame)
        % > ACTIVESCHEME current color scheme
        ActiveScheme (1,1) string {mustBeMember(ActiveScheme, ["light", "dark"])} = "light"
    end

    methods
        function css = jsonencode(this, varargin)
            % > JSONENCODE returns CSS custom properties as a JSON string.
            % Called automatically when the Theme is serialized for the frontend.
            % Color properties are sent as [light, dark] arrays.
            % Frontend selects the value based on colorScheme.

            colorProps = ["Background", "Foreground", ...
                          "Primary", "PrimaryForeground", ...
                          "Secondary", "SecondaryForeground", ...
                          "Muted", "MutedForeground", ...
                          "Accent", "AccentForeground", ...
                          "Destructive", "DestructiveForeground", ...
                          "Success", "SuccessForeground", ...
                          "Warning", "WarningForeground", ...
                          "Info", "InfoForeground", ...
                          "Border", "Input", "Ring"];

            keys = cell(1, numel(colorProps) + 1);
            vals = cell(1, numel(colorProps) + 1);

            for ii = 1:numel(colorProps)
                propName = colorProps(ii);
                keys{ii} = char(ic.utils.toKebabCase(propName));
                values = this.(propName);
                vals{ii} = cellstr(values);  % [light, dark] array
            end

            % Non-color properties are set directly (as single values)
            keys{end} = 'radius';
            vals{end} = char(this.Radius);

            m = containers.Map(keys, vals);
            css = jsonencode(m, varargin{:});
        end
    end

end

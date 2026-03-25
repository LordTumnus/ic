classdef Theme < handle & ic.event.TransportData
    % CSS custom property values with light/dark scheme support. Changes to Theme properties trigger a event on the owning #ic.Frame, which sends the updated theme to the frontend to update the CSS variables. The frontend applies the appropriate value from each [light, dark] pair based on the current color scheme.

    properties (SetAccess = ?ic.Frame)
        % page and component background color
        Background (1,2) string = ["#f8fafc", "#0f172a"]

        % default text color
        Foreground (1,2) string = ["#0f172a", "#f1f5f9"]

        % main brand/action color
        Primary (1,2) string = ["#2563eb", "#3b82f6"]

        % text on primary backgrounds
        PrimaryForeground (1,2) string = ["#ffffff", "#ffffff"]

        % alternative action color
        Secondary (1,2) string = ["#e2e8f0", "#1e293b"]

        % text on secondary backgrounds
        SecondaryForeground (1,2) string = ["#0f172a", "#f1f5f9"]

        % subtle background for less prominent elements
        Muted (1,2) string = ["#f1f5f9", "#1e293b"]

        % text on muted backgrounds
        MutedForeground (1,2) string = ["#64748b", "#94a3b8"]

        % highlight/emphasis color
        Accent (1,2) string = ["#dbeafe", "#1e3a5f"]

        % text on accent backgrounds
        AccentForeground (1,2) string = ["#1e40af", "#93c5fd"]

        % error/danger color
        Destructive (1,2) string = ["#dc2626", "#ef4444"]

        % text on destructive backgrounds
        DestructiveForeground (1,2) string = ["#ffffff", "#ffffff"]

        % positive/success color
        Success (1,2) string = ["#16a34a", "#22c55e"]

        % text on success backgrounds
        SuccessForeground (1,2) string = ["#ffffff", "#ffffff"]

        % caution/warning color
        Warning (1,2) string = ["#d97706", "#f59e0b"]

        % text on warning backgrounds
        WarningForeground (1,2) string = ["#ffffff", "#18181b"]

        % informational color
        Info (1,2) string = ["#0284c7", "#38bdf8"]

        % text on info backgrounds
        InfoForeground (1,2) string = ["#ffffff", "#18181b"]

        % default border color
        Border (1,2) string = ["#cbd5e1", "#334155"]

        % input field border color
        Input (1,2) string = ["#cbd5e1", "#475569"]

        % focus ring color
        Ring (1,2) string = ["#2563eb", "#3b82f6"]

        % default border radius
        Radius (1,1) string = "0.375rem"
    end

    properties (GetAccess = public, SetAccess = ?ic.Frame)
        % current color scheme
        ActiveScheme (1,1) string {mustBeMember(ActiveScheme, ["light", "dark"])} = "light"
    end

    methods
        function s = toStruct(this)
            % convert to a plain struct with camelCase keys.
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
            s = struct();
            for ii = 1:numel(colorProps)
                propName = colorProps(ii);
                camelKey = char(ic.utils.toCamelCase(propName));
                s.(camelKey) = cellstr(this.(propName));
            end
            s.radius = this.Radius;
        end

        function css = jsonencode(this, varargin)
            % serialize as CSS custom properties in JSON form.
            % color properties are sent as [light, dark] arrays; the frontend
            % selects the value based on the active color scheme.

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
                vals{ii} = cellstr(values);
            end

            % non-color properties are set as single values
            keys{end} = 'radius';
            vals{end} = char(this.Radius);

            m = containers.Map(keys, vals);
            css = jsonencode(m, varargin{:});
        end
    end

end

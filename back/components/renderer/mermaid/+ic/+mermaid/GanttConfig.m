classdef GanttConfig < ic.event.TransportData
    % > GANTTCONFIG Mermaid Gantt chart configuration.
    %
    %   m.Config = ic.mermaid.GanttConfig(BarHeight=30, AxisFormat="%b %d")

    properties
        % > BARHEIGHT height of task bars (px)
        BarHeight (1,1) double {mustBeNonnegative} = 20

        % > BARGAP gap between task bars (px)
        BarGap (1,1) double {mustBeNonnegative} = 4

        % > TOPPADDING space above the chart area (px)
        TopPadding (1,1) double {mustBeNonnegative} = 50

        % > LEFTPADDING space for section labels on the left (px)
        LeftPadding (1,1) double {mustBeNonnegative} = 75

        % > RIGHTPADDING space for section labels on the right (px)
        RightPadding (1,1) double {mustBeNonnegative} = 75

        % > FONTSIZE font size for text in the chart (px)
        FontSize (1,1) double {mustBePositive} = 11

        % > SECTIONFONTSIZE font size for section labels (px)
        SectionFontSize (1,1) double {mustBePositive} = 11

        % > AXISFORMAT date/time format string for the x-axis (d3 time format)
        AxisFormat string = "%Y-%m-%d"

        % > TOPAXIS show date labels on top instead of bottom
        TopAxis (1,1) logical = false

        % > DISPLAYMODE "" for default, "compact" to pack tasks on fewer rows
        DisplayMode string {mustBeMember(DisplayMode, ["","compact"])} = ""

        % > WEEKDAY which day starts the week for week-based intervals
        Weekday string {mustBeMember(Weekday, ["sunday","monday","tuesday","wednesday","thursday","friday","saturday"])} = "sunday"
    end

    methods
        function this = GanttConfig(props)
            arguments
                props.?ic.mermaid.GanttConfig
            end
            fns = fieldnames(props);
            for i = 1:numel(fns)
                this.(fns{i}) = props.(fns{i});
            end
        end

        function s = toStruct(this)
            inner = struct();
            plist = properties(this);
            for i = 1:numel(plist)
                name = plist{i};
                inner.([lower(name(1)), name(2:end)]) = this.(name);
            end
            s = struct('gantt', inner);
        end

        function json = jsonencode(this, varargin)
            json = jsonencode(this.toStruct(), varargin{:});
        end
    end
end

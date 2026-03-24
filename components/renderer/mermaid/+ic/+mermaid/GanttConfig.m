classdef GanttConfig < ic.event.TransportData
    % configuration for Mermaid Gantt chart diagrams.
    % Pass an instance to #ic.Mermaid.Config to customize layout and appearance.

    properties
        % height of task bars, in pixels
        BarHeight (1,1) double {mustBeNonnegative} = 20

        % gap between task bars, in pixels
        BarGap (1,1) double {mustBeNonnegative} = 4

        % space above the chart area, in pixels
        TopPadding (1,1) double {mustBeNonnegative} = 50

        % space reserved for section labels on the left, in pixels
        LeftPadding (1,1) double {mustBeNonnegative} = 75

        % space reserved for section labels on the right, in pixels
        RightPadding (1,1) double {mustBeNonnegative} = 75

        % font size for text in the chart, in pixels
        FontSize (1,1) double {mustBePositive} = 11

        % font size for section labels, in pixels
        SectionFontSize (1,1) double {mustBePositive} = 11

        % d3 time format string for the x-axis labels
        AxisFormat string = "%Y-%m-%d"

        % whether to show date labels on the top axis instead of the bottom
        TopAxis (1,1) logical = false

        % row packing mode: "" for default, "compact" to pack tasks on fewer rows
        DisplayMode string {mustBeMember(DisplayMode, ["","compact"])} = ""

        % which day starts the week for week-based intervals
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

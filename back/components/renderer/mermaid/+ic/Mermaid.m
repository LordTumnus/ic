classdef Mermaid < ic.core.Component
    % > MERMAID Interactive diagram renderer using Mermaid.js.
    %
    %   m = ic.Mermaid(Value="graph LR; A-->B; B-->C;")
    %   m = ic.Mermaid(Value="sequenceDiagram; Alice->>Bob: Hello")
    %
    % Renders Mermaid diagram definitions as interactive SVGs with
    % pan/zoom controls. Supports all Mermaid diagram types: flowcharts,
    % sequence diagrams, class diagrams, state diagrams, ER diagrams,
    % Gantt charts, pie charts, and more.
    %
    % Diagram colors are derived from IC theme variables automatically.
    % Customize via style():
    %   m.style(".ic-mermaid", "--ic-mermaid-primary", "#8b5cf6")
    %
    % All rendering is client-side (no external resources needed).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE Mermaid diagram definition text
        Value string = ""

        % > HEIGHT container height (CSS value: number=px, string=any unit)
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % > TOOLBARONHOVER show zoom/reset toolbar on mouse hover
        ToolbarOnHover (1,1) logical = true

        % > HTMLLABELS use HTML labels in nodes (richer text wrapping)
        HtmlLabels (1,1) logical = true

        % > WRAP auto-wrap long text in nodes and messages
        Wrap (1,1) logical = true

        % > DARKMODE affects Mermaid's internal color derivation
        DarkMode (1,1) logical = false

        % > CONFIG diagram-specific Mermaid configuration
        %   Use typed config classes for validation and autocomplete:
        %     m.Config = ic.mermaid.FlowchartConfig(NodeSpacing=100)
        %     m.Config = ic.mermaid.SequenceConfig(MirrorActors=false)
        %     m.Config = ic.mermaid.GanttConfig(BarHeight=30)
        %   Or plain structs with camelCase keys for other diagram types:
        %     m.Config = struct('pie', struct('textPosition', 0.75))
        Config = struct()
    end

    methods
        function this = Mermaid(props)
            arguments
                props.?ic.Mermaid
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = zoomIn(this)
            % > ZOOMIN increase zoom level by one step
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % > ZOOMOUT decrease zoom level by one step
            out = this.publish("zoomOut", []);
        end

        function out = resetView(this)
            % > RESETVIEW reset to initial pan/zoom state
            out = this.publish("resetView", []);
        end
    end
end

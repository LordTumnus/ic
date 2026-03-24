classdef Mermaid < ic.core.Component
    % interactive diagram renderer using [Mermaid.js v10](https://mermaid.js.org/).
    % Renders diagram definitions as interactive SVGs with pan/zoom. Supports all Mermaid diagram types: flowcharts, sequence, class, state, ER, Gantt, pie, and more. Colors derive from IC theme variables automatically. All rendering is client-side.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % Mermaid diagram definition text
        Value string = ""

        % height of the container, in pixels or as a CSS size string
        Height {ic.check.CssValidators.mustBeSize} = "100%"

        % whether to show the zoom/reset toolbar on mouse hover
        ToolbarOnHover (1,1) logical = true

        % whether to use HTML labels in nodes for richer text wrapping
        HtmlLabels (1,1) logical = true

        % whether to auto-wrap long text in nodes and messages
        Wrap (1,1) logical = true

        % whether to use Mermaid's dark color scheme
        DarkMode (1,1) logical = false

        % diagram-specific Mermaid configuration.
        % {note} Use typed config classes for validation: #ic.mermaid.FlowchartConfig, #ic.mermaid.SequenceConfig, #ic.mermaid.GanttConfig. {/note}
        Config = struct()

        % whether to automatically re-render when Value changes
        RenderOnChange (1,1) logical = true
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
            % increase zoom level by one step
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("zoomIn", []);
        end

        function out = zoomOut(this)
            % decrease zoom level by one step
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("zoomOut", []);
        end

        function out = resetView(this)
            % reset pan and zoom to the initial state
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("resetView", []);
        end

        function out = render(this)
            % programmatically trigger a render of the current Value
            % {returns} a #ic.async.Promise with the fulfillment status from the view {/returns}
            out = this.publish("render", []);
        end
    end
end

classdef TabGroup < ic.tp.ContainerBlade
    % tab container blade for TweakPane.
    % add pages via #ic.tp.TabGroup.addTabPage. each page can hold its own set of blades.

    properties (Access = private)
        % monotonic counter for tab page indices
        NextPageIndex (1,1) double = 0
    end

    methods
        function this = TabGroup(props)
            arguments
                props.?ic.tp.TabGroup
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.ContainerBlade(props);
        end

        function page = addTabPage(this, props)
            % add a tab page to this group
            % {returns} the new #ic.tp.TabPage {/returns}
            % {example}
            %   tabs = pane.addTabGroup();
            %   general = tabs.addTabPage(Label="General");
            %   general.addSlider(Label="Speed", Min=0, Max=100);
            %   advanced = tabs.addTabPage(Label="Advanced");
            % {/example}
            arguments
                this
                % name-value pairs for #ic.tp.TabPage properties
                props.?ic.tp.TabPage
            end
            idx = this.NextPageIndex;
            this.NextPageIndex = idx + 1;
            props.PageIndex = idx;
            args = namedargs2cell(props);
            page = ic.tp.TabPage(args{:});
            this.insertBlade(page);
        end
    end
end

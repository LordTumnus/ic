classdef TabGroup < ic.tp.ContainerBlade
    % > TABGROUP Tab container blade for TweakPane.
    %
    %   tabs = pane.addTabGroup();
    %   page1 = tabs.addTabPage("General");
    %   page1.addSlider("Volume", Min=0, Max=100);

    properties (Access = private)
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
            % > ADDTABPAGE add a tab page to this group
            arguments
                this
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

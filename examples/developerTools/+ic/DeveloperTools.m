classdef DeveloperTools < handle
    % > DEVELOPERTOOLS Runtime inspector for IC components.
    %
    %   dt = ic.DeveloperTools(myComponent)
    %   dt = ic.DeveloperTools(myComponent, "ColorScheme", "dark")

    properties (SetAccess = private)
        % > FRAME the ic.Frame hosting the inspector
        Frame  ic.Frame

        % > TARGET the inspected component handle
        Target ic.core.ComponentBase
    end

    methods
        function this = DeveloperTools(component, frameArgs)
            arguments
                component (1,1) ic.core.ComponentBase
                frameArgs.?ic.Frame
            end

            assert(~component.isAttached(), ...
                "ic:DeveloperTools:HasParent", ...
                "Component must not have a parent.");

            fig = uifigure("Name", "IC DevTools - " + class(component));
            fig.Position(3:4) = [1200, 700];
            layout = uigridlayout(fig, ...
                "RowHeight", {'1x'}, "ColumnWidth", {'1x'}, ...
                "RowSpacing", 0, "Padding", [0 0 0 0]);

            args = namedargs2cell(frameArgs);
            this.Frame = ic.Frame("Parent", layout, args{:});
            this.Target = component;

            dt = ic.internal.DeveloperTools(component);
            this.Frame.addChild(dt);
        end
    end
end

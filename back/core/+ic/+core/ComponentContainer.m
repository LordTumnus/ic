% > COMPONENTCONTAINER is a base class for components that can hold other components
% It combines Component behavior (can be attached to a parent) with Container
% behavior (can hold children).
classdef ComponentContainer < ic.core.Component & ...
                              ic.core.Container

    methods
        function delete(this)
            % DELETE invalidates the component container and also deletes its children
            delete@ic.core.Component(this);
            delete@ic.core.Container(this);
        end
    end

    methods (Access = protected)
        function definition = getComponentDefinition(this)
            % > GETCOMPONENTDEFINITION returns the component definition struct for this component container
            definition = getComponentDefinition@ic.core.Component(this);
            definition.targets = num2cell(["default", this.Targets]);
        end
    end
end

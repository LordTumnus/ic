% > COMPONENTCONTAINER is a base class for components that can hold other components
% It combines Component behavior (can be attached to a parent) with Container
% behavior (can hold children).
classdef ComponentContainer < ic.core.Component & ...
                              ic.core.Container

    methods
        function this = ComponentContainer(props)
            arguments
                props struct = struct()
            end
            this@ic.core.Component(props);
        end

        function delete(this)
            % DELETE invalidates the component container and also deletes its children
            delete@ic.core.Container(this);
            delete@ic.core.Component(this);
        end
    end

    methods (Access = public)
        function queue = flush(this)
            % > FLUSH sends queued events and cascades into children.
            queue = flush@ic.mixin.Publishable(this);
            for ii = 1:numel(this.Children)
                this.Children(ii).flush();
            end
        end
    end

    methods (Access = ?ic.core.Container)
        function definition = getComponentDefinition(this)
            % > GETCOMPONENTDEFINITION returns the component definition struct for this component container
            definition = getComponentDefinition@ic.core.ComponentBase(this);

            % Collect static children for serialization
            staticKids = this.Children([this.Children.IsStatic]);
            definition.staticChildren = cell(1, numel(staticKids));
            if ~isempty(staticKids)
                for ii = 1:numel(staticKids)
                    definition.staticChildren{ii} = struct(...
                        "component", getComponentDefinition(staticKids(ii)), ...
                        "target", staticKids(ii).Target);
                end
            end
        end
    end
end

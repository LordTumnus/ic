% > COMPONENT objects are the core of the interactive component framework. They are the model that represent and control what the user sees on their screen.
% Components communicate with the view directly through event publishing and subscription. Using this interface, components can:
% - Publish events to the view
% - Subscribe to events from the view
% > superdoc
classdef Component < ic.core.ComponentBase

    properties (AbortSet)
        % > PARENT: The container that holds the component
        Parent ic.core.Container {mustBeScalarOrEmpty}
    end

    methods
        function this = Component(id)
            arguments (Input)
                % > ID unique identifier for the component
                id string = matlab.lang.internal.uuid();
            end

            arguments (Output)
                % > THIS the component
                this (1,1) ic.core.Component
            end

            this@ic.core.ComponentBase(id);
        end

        function delete(this)
            % DELETE invalidates the component and detaches it from its parent
            if ~isempty(this.Parent)
                this.detachFromParent();
            end
        end

        function set.Parent(this, parent)
            % > SET.PARENT reattaches the component to the newly defined parent

            if isempty(parent)
                % detach from parent if setting to empty
                this.detachFromParent();
                this.Parent = parent;
            elseif isempty(this.Parent)
                % originally detached, just attach to new parent
                this.Parent = parent;
                this.attachToParent(parent);
            else
                % reparenting
                oldParent = this.Parent;
                this.Parent = parent;
                this.switchParent(oldParent, parent);
            end
        end
    end

    methods (Access = public)
        function tf = isAttached(this)
            % > ISATTACHED returns a flag indicating whether the component has a valid parent or not
            tf = ~isempty(this.Parent) && isvalid(this.Parent);
        end
    end

    methods (Access = protected)
        function send(this, evt)
            % > SEND dispatches recursively an event to the parent, until the view is reached. If the component does not have a parent, then it stores the event in the queue until the component is attached
            if ~this.isAttached()
                this.Queue((end + 1):(end + length(evt))) = evt;
                return;
            end
            this.Parent.send(evt);
        end
    end

    methods (Access = protected, Hidden)
        function attachToParent(this, parent)
            % > ATTACHTOPARENT sends all the events stored in the queue through the parent

            % Get component definition via introspection
            definition = this.getComponentDefinition();

            data = struct(...
                "type", class(this), ...
                "id", this.ID, ...
                "props", definition.props, ...
                "events", definition.events, ...
                "methods", definition.methods);
            parent.publish("@insert", data);

            parent.addChild(this);
        end

        function detachFromParent(this)
            % > DETACHFROMPARENT asks the parent to remove the component from the view

            % parent sends an event requesting for removal of the child
            data = struct("id", this.ID);
            this.Parent.publish("@remove", data);

            % remove from parent children
            this.Parent.removeChild(this);
        end

        function switchParent(this, oldParent, newParent)
            % > SWITCHPARENT reassigns the component to a new parent container

            if isAttached(oldParent)
                % check that the new parent is attached to the same frame
                oldFrame = this.getFrame();
                newFrame = newParent.getFrame();

                if isempty(newFrame) || (oldFrame.ID ~= newFrame.ID)
                    error("ic:core:Component:ReparentingAcrossFrames", ......
                        "Cannot reparent component across different frames.");
                end
            end
            data = struct("id", this.ID, "parent", newParent.ID);
            oldParent.publish("@reparent", data);

            oldParent.removeChild(this);
            newParent.addChild(this);
        end
    end
    methods (Access = ?ic.core.Container, Hidden)
        function frame = getFrame(this)
            % > GETFRAME walks up the parent chain to find the Frame
            frame = [];
            current = this.Parent;
            while ~isempty(current) && isvalid(current)
                if isa(current, "ic.Frame")
                    frame = current;
                    return;
                end
                if isa(current, "ic.core.Component")
                    current = current.Parent;
                else
                    % Reached a Container that is not a Component (shouldn't happen in normal use)
                    return;
                end
            end
        end
    end

end

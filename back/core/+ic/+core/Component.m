% > COMPONENT objects are the core of the interactive component framework. They are the model that represent and control what the user sees on their screen.
% Components communicate with the view directly through event publishing and subscription. Using this interface, components can:
% - Publish events to the view
% - Subscribe to events from the view
% > superdoc
classdef Component < ic.core.ComponentBase

    properties (Access = private)
        % > PARENT_: backing property for Parent
        Parent_ = [] % ic.core.Container
        % > TARGET_: backing property for Target
        Target_ string = string.empty()
    end

    properties (Dependent, AbortSet)
        % > PARENT: The container that holds the component
        Parent
        % > TARGET: The target within the parent container where the component is placed
        Target
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

        function parent = get.Parent(this)
            % > GET.PARENT returns the parent container
            parent = this.Parent_;
        end

        function set.Parent(this, parent)
            % > SET.PARENT reattaches the component to the newly defined parent
            this.setParent(parent);
        end

        function target = get.Target(this)
            % > GET.TARGET returns the target
            target = this.Target_;
        end

        function set.Target(this, target)
            % > SET.TARGET reattaches the component to the parent using the newly defined target
            if isempty(this.Parent)
                error("ic:core:Component:NoParent", ...
                    "Cannot set Target when Parent is empty.");
            end
            this.setParent(this.Parent, target);
        end
    end

    methods (Access = public)
        function tf = isAttached(this)
            % > ISATTACHED returns a flag indicating whether the component has a valid parent or not
            tf = ~isempty(this.Parent) && isvalid(this.Parent);
        end

        function setParent(this, parent, target)
            % > SETPARENT sets the parent
            arguments (Input)
                this % ic.core.Component
                parent % ic.core.Container
                target string = string.empty()
            end

            if isempty(parent)
                % detach from parent if setting to empty
                this.detachFromParent();
            elseif isempty(this.Parent)
                % originally detached, just attach to new parent
                this.attachToParent(parent, target);
            else
                % reparenting
                this.switchParent(parent, target);
            end
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

    methods (Access = private, Hidden)

        function resolvedTarget = resolveAndValidateTarget(~, target, parent)
            % > RESOLVEANDVALIDATETARGET resolves empty target to "default" and validates
            if isempty(target)
                resolvedTarget = "default";
            else
                resolvedTarget = target;
            end

            % Validate target is allowed by parent (skip for "default" which is always valid)
            if ~strcmp(resolvedTarget, "default") && ~ismember(resolvedTarget, parent.Targets)
                error("ic:core:Component:InvalidTarget", ...
                    "The target '%s' is not valid for the parent container of type '%s'. Valid targets are: %s", ...
                    resolvedTarget, class(parent), strjoin(parent.Targets, ", "));
            end
        end

        function attachToParent(this, parent, target)
            % > ATTACHTOPARENT sends all the events stored in the queue through the parent
            % Note: target is already validated by setParent

            resolvedTarget = this.resolveAndValidateTarget(target, parent);
            this.Parent_ = parent;
            this.Target_ = resolvedTarget;

            % Get component definition via introspection
            definition = this.getComponentDefinition();

            data = struct( ...
                "component", struct( ...
                    "type", class(this), ...
                    "id", this.ID, ...
                    "props", definition.props, ...
                    "events", definition.events, ...
                    "methods", definition.methods), ...
                "target", resolvedTarget ...
            );
            % assign manually cell to struct
            data.component.targets = definition.targets;

            parent.publish("@insert", data);

            parent.addChild(this);
        end

        function detachFromParent(this)
            % > DETACHFROMPARENT asks the parent to remove the component from the view

            if isempty(this.Parent_)
                this.Parent_ = [];
                this.Target_ = string.empty();
                return;
            end

            % parent sends an event requesting for removal of the child
            data = struct("id", this.ID);
            this.Parent_.publish("@remove", data);

            % remove from parent children
            this.Parent_.removeChild(this);

            % clear parent linkage
            this.Parent_ = [];
            this.Target_ = string.empty();
        end

        function switchParent(this, newParent, target)
            % > SWITCHPARENT reassigns the component to a new parent container

            % resolve and validate target before updating state
            if isempty(target) && ~isempty(this.Target_) && ...
                ismember(this.Target_, newParent.Targets)
                resolvedTarget = this.Target_;
            else
                resolvedTarget = ...
                    this.resolveAndValidateTarget(target, newParent);
            end
            oldParent = this.Parent_;
            oldFrame = this.getFrame();
            newFrame = [];
            if isa(newParent, "ic.Frame")
                newFrame = newParent;
            elseif isa(newParent, "ic.core.Component")
                newFrame = newParent.getFrame();
            end
            if ~isempty(oldParent) && ...
               isvalid(oldParent) && ...
               isAttached(oldParent)
                if isempty(newFrame) || ~isequal(oldFrame, newFrame)
                    error("ic:core:Component:ReparentingAcrossFrames", ......
                        "Cannot reparent component across different frames.");
                end
            end

            this.Parent_ = newParent;
            this.Target_ = resolvedTarget;

            data = struct(...
                "id", this.ID, "parent", newParent.ID, "target", target);
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

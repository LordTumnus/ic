% > COMPONENT objects are the core of the interactive component framework. They are the model that represent and control what the user sees on their screen.
% Components communicate with the view directly through event publishing and subscription. Using this interface, components can:
% - Publish events to the view
% - Subscribe to events from the view
% > superdoc
classdef Component < ic.core.ComponentBase & matlab.mixin.SetGetExactNames

    properties (Access = ?ic.core.Container, Hidden)
        % > PARENT: backing property for Parent
        Parent = [] % ic.core.Container
        % > TARGET: backing property for Target
        Target string = string.empty()
        % > ISSTATIC: true if pre-rendered in Svelte
        IsStatic logical = false
    end


    methods
        function this = Component(props)
            % > COMPONENT constructor accepts a struct of name-value pairs.
            % Subclasses use `props.?ic.Subclass` in their arguments block
            % and pass the resulting struct here.
            arguments
                props struct = struct()
            end

            if isfield(props, 'ID')
                id = props.ID;
                props = rmfield(props, 'ID');
            else
                id = "ic-" + matlab.lang.internal.uuid();
            end

            this@ic.core.ComponentBase(id);

            if ~isempty(fieldnames(props))
                nvPairs = namedargs2cell(props);
                set(this, nvPairs{:});
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


    methods (Access = {?ic.Frame, ?ic.core.Component})
        function sendReactiveProperty(this, propertyName)
            % > SENDREACTIVEPROPERTY publishes an event with the name of the property being changed to the view
            if ~this.isAttached()
                return;
            end
            this.publish("@prop/" + propertyName, this.(propertyName));
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

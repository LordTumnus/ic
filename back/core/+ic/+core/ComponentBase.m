% > COMPONENTBASE is the abstract base class for interactive components.
% It provides the core event publishing/subscription infrastructure without defining the Parent property, allowing subclasses to define their own parent type.
classdef (Abstract) ComponentBase < handle & matlab.mixin.Heterogeneous & ...
                                    ic.mixin.Stylable

    properties (SetAccess = immutable)
        % > ID unique identifier of the component
        ID (1,1) string
    end

    properties (SetAccess = protected)
        % > QUEUE list of javascript events that will be published when the component is attached
        Queue = ic.event.JsEvent.empty();
        % > SUBSCRIPTIONS map between event names and callbacks that will be executed upon receiving those events
        Subscriptions = dictionary(string.empty(), function_handle.empty());
    end

    properties (Access = private)
        ReactivePropListeners = ...
            dictionary(string.empty(), event.listener.empty());
        % > REACTIVEEVENTLISTENERCOUNT tracks how many MATLAB listeners
        % exist per reactive event, so the view is only notified when the
        % first listener is added or the last one is removed.
        ReactiveEventListenerCount = ...
            dictionary(string.empty(), double.empty());
    end

    methods
        function this = ComponentBase(id)
            arguments (Input)
                % > ID unique identifier for the component
                id (1,1) string {mustBeValidCssIdent} = ...
                    "ic-" + matlab.lang.internal.uuid();
            end

            arguments (Output)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
            end

            this.ID = id;

            % setup reactivity for properties marked as "Reactive"
            mc = meta.class.fromName(class(this));
            metaProps = mc.PropertyList;
            reactiveProps = metaProps(...
                all([strcmp({metaProps.Description}, "Reactive"); ...
                [metaProps.SetObservable]]));
            for ii = 1:numel(reactiveProps)
                this.addPropReactivity(reactiveProps(ii).Name);
                this.subscribeToReactiveProperty(reactiveProps(ii).Name);
            end

            % setup reactivity for events marked as "Reactive"
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));
            for jj = 1:numel(reactiveEvents)
                this.addEventReactivity(reactiveEvents(jj).Name);
            end
        end

        function l = addlistener(this, varargin)
            % > ADDLISTENER adds a listener. When the first listener for a
            % reactive event is added, the view is notified so it starts
            % publishing that event. When the last listener is removed, the
            % view stops publishing.
            l = addlistener@handle(this, varargin{:});

            % Only handle scalar source, simple event form (eventName + callback)
            if ~isscalar(this) || numel(varargin) ~= 2
                return
            end

            eventName = string(varargin{1});
            if ~this.isReactiveEvent(eventName)
                return
            end

            % Increment listener count
            if this.ReactiveEventListenerCount.isKey(eventName)
                count = this.ReactiveEventListenerCount(eventName);
            else
                count = 0;
            end
            this.ReactiveEventListenerCount(eventName) = count + 1;

            % Notify view on first listener
            if count == 0
                this.publish("@listenEvent", ...
                    ic.utils.toCamelCase(eventName));
            end

            % When this listener is destroyed, decrement and notify
            addlistener(l, 'ObjectBeingDestroyed', ...
                @(~,~) this.onReactiveListenerRemoved(eventName));
        end
    end

    methods (Abstract, Access = public)
        % > ISATTACHED returns whether the component is connected to a view
        tf = isAttached(this)
    end

    methods (Abstract, Access = protected)
        % > SEND dispatches an event towards the view
        send(this, evt)
    end

    methods (Access = public)
        function promise = publish(this, name, data)
            % > PUBLISH sends an event with the specified name and data to the view. Optionally define an output promise that will be resolved when the view processes the event

            arguments (Input)
                % > THIS component sending the event
                this (1,1) ic.core.ComponentBase
                % > NAME name of the event
                name (1,1) string
                % > DATA any information carried within the event
                data % any
            end

            arguments (Output)
                % > PROMISE? a promise that resolves into a @Resolution when the view has received and processed the event
                promise ic.async.Promise
            end

            if ~startsWith(name, "@") && ~this.isReactiveMethod(name)
                error("ic:core:ComponentBase:PublishReactiveMethod", ...
                      "Cannot publish reactive method '%s'. Reactive methods are invoked directly on the component instance.", name);
            end

            evtName = ic.utils.toCamelCase(name);
            evt = ic.event.JsEvent(this.ID, evtName, data);
            this.send(evt);

            % initialize a promise and resolve it when the same event id is received from the view
            if (nargout == 1)
                promise = ic.async.Promise();
                evtName = "@resp/" + evt.Id;
                this.Subscriptions(evtName) = ...
                    @(~, ~, data) this.resolveAndUnsubscribe(...
                        promise, evtName, data);
            end
        end

        function subscribe(this, name, callback)
            % > SUBSCRIBE registers a callback that will be evaluated when an event with a given name is received from the view
            arguments (Input)
                % > THIS the component subscribing to the event
                this (1,1) ic.core.ComponentBase
                % > NAME the name of the event
                name (1,1) string
                % > CALLBACK the function executed every time the event is received.
                % The callback is a function that takes 3 arguments: the component receiving the event, the event name and the event data
                callback (1,1) function_handle
            end
            this.Subscriptions(name) = callback;
        end

        function unsubscribe(this, name)
            % > UNSUBSCRIBE stops listening to events with the specified name (clears the subscription)
            arguments (Input)
                % > THIS the component subscribing to the event
                this (1,1) ic.core.ComponentBase
                % > NAME the name of the event
                name (1,1) string
            end
            this.Subscriptions(name) = [];
        end

        function queue = flush(this)
            % > FLUSH sends all queued events and clears the queue
            if ~this.isAttached()
                return
            end
            queue = this.Queue;
            this.send(queue);
            this.Queue = ic.event.JsEvent.empty();
        end

        function effect = jsEffect(this, varargin)
            % > JSEFFECT creates a reactive expression that runs on the frontend.
            %
            % effect = comp.jsEffect(c1, c2, ..., "(p1, p2, ...) => { ... }")
            %
            % Components are mapped positionally to the arrow function
            % parameters. Arrays of components can be passed for a single
            % parameter.
            %
            % Each component proxy in the expression provides:
            %   .props    - Reactive properties (reads tracked, writes sync)
            %   .methods  - Callable methods (untracked, returns Resolution)
            %   .el       - Root DOM element (live getter)
            %   .id       - Component unique ID
            %   .type     - MATLAB class type
            %
            % Property writes inside the expression update the UI instantly
            % AND sync back to MATLAB asynchronously.
            %
            % Examples:
            %   % Bind slider to progress bar
            %   e = slider.jsEffect(progress, ...
            %       "(s, p) => { p.props.value = s.props.value }");
            %
            %   % Pass an array of components to one parameter
            %   e = f.jsEffect([slider1, slider2], gauge, ...
            %       "(sliders, g) => { g.props.value = sliders[0].props.value }");
            %
            %   % No component arguments
            %   e = f.jsEffect("() => { document.title = 'hello' }");
            %
            %   % Remove the effect
            %   e.remove();

            arguments (Input)
                this (1,1) ic.core.ComponentBase
            end
            arguments (Input, Repeating)
                varargin
            end

            assert(numel(varargin) >= 1, ...
                "ic:ComponentBase:jsEffect", ...
                "jsEffect requires at least an expression");

            expression = string(varargin{end});
            components = varargin(1:end-1);

            % Parse arrow function parameter names
            tokens = regexp(expression, ...
                '^\s*\(([^)]*)\)\s*=>', 'tokens', 'once');
            assert(~isempty(tokens), ...
                "ic:ComponentBase:jsEffect", ...
                "Expression must be an arrow function: (p1, p2, ...) => { ... }");

            paramStr = strtrim(string(tokens{1}));
            if paramStr == ""
                paramNames = string.empty();
            else
                paramNames = strtrim(split(paramStr, ","));
            end

            % Validate parameter count matches component count
            assert(numel(paramNames) == numel(components), ...
                "ic:ComponentBase:jsEffect", ...
                "Arrow function has %d parameter(s) but %d component argument(s) were given", ...
                numel(paramNames), numel(components));

            % Build component map: paramName → component ID(s)
            componentMap = struct();
            for ii = 1:numel(components)
                comp = components{ii};
                assert(isa(comp, 'ic.core.ComponentBase'), ...
                    "All arguments except the last must be components");

                if isscalar(comp)
                    componentMap.(paramNames(ii)) = comp.ID;
                else
                    ids = strings(1, numel(comp));
                    for jj = 1:numel(comp)
                        ids(jj) = comp(jj).ID;
                    end
                    componentMap.(paramNames(ii)) = ids;
                end
            end

            % Generate unique ID and create handle
            effectId = string(matlab.lang.internal.uuid());
            effect = ic.effect.JsEffect(effectId, this);

            % Send to frontend
            this.publish("@jsEffect", struct(...
                "id", effectId, ...
                "components", componentMap, ...
                "expression", expression));
        end
    end

    methods (Access = {?ic.core.View, ?matlab.uitest.TestCase}, Hidden)
        function receive(this, name, data)
            % > RECEIVE finds an event in the subscriptions and executes its callback
            % > note: RECEIVE is executed whenever an event from the view is received and the component id from the event matches the one stored in the component
            arguments
                this (1,1) ic.core.ComponentBase
                name (1,1) string
                data % any
            end

            % subscribed
            if this.Subscriptions.isKey(name)
                cb = this.Subscriptions(name);
                cb(this, name, data);
                return;
            end
        end
    end

    methods (Access = protected, Hidden)
        function addPropReactivity(this, propertyName)
            % > ADDPROPREACTIVITY establishes a connection between the property of the component with the given name and its view counterpart. Reactive properties will notify the view when they change, and they will also change when the view does

            % add a listener to the property post-set
            this.ReactivePropListeners(propertyName) = ...
                addlistener(this, propertyName, "PostSet", ...
                @(src, ~) this.sendReactiveProperty(src.Name));
        end

        function addEventReactivity(this, eventName)
            % > ADDEVENTREACTIVITY subscribes to events from the view with the specified name, and re-notifies them as Matlab events
            camelName = ic.utils.toCamelCase("@event/" + eventName);
            this.subscribe(camelName, ...
                @(~,~,data) notify(this, eventName, ic.event.MEvent(data)));
        end

        function setValueSilently(this, propName, value)
            % > SETVALUESILENTLY sets a reactive property without notifying the view.
            task = onCleanup(@() reenableListener(this, propName));
            this.ReactivePropListeners(propName).Enabled = false;
            this.(propName) = value;
            function reenableListener(obj, n)
                obj.ReactivePropListeners(n).Enabled = true;
            end
        end
    end

    methods (Access = {?ic.Frame, ?ic.core.Component})
        function resolveAndUnsubscribe(this, promise, name, evtData)
            % > RESOLVEANDUNSUBSCRIBE is the callback executed whenever the view replies to a publish call. Resolves the promise with the new event data and stops listening to that event
            promise.resolve(ic.async.Resolution(evtData.success, evtData.data));
            this.Subscriptions(name) = [];
        end

        function sendReactiveProperty(this, propertyName)
            % > SENDREACTIVEPROPERTY publishes an event with the name of the property being changed to the view
            this.publish("@prop/" + propertyName, this.(propertyName));
        end

        function subscribeToReactiveProperty(this, propertyName)
            % > SUBSCRIBETOREACTIVEPROPERTIES subscribes to property changes from the view, and sets the component property when the view notifies the event
            camelName = ic.utils.toCamelCase("@prop/" + propertyName);
            this.subscribe(camelName, ...
                @(~,~,data) this.setValueSilently(propertyName, data))
        end

        function isReactiveMethod = isReactiveMethod(this, methodName)
            % > ISREACTIVEMETHOD returns whether the specified method is marked as reactive
            mc = meta.class.fromName(class(this));
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));
            % Convert method names to camelCase strings and compare
            camelNames = arrayfun(@(m) ic.utils.toCamelCase(m.Name), ...
                reactiveMethods);
            isReactiveMethod = any(camelNames == methodName);
        end
    end

    methods (Access = private)
        function onReactiveListenerRemoved(this, eventName)
            % > ONREACTIVELISTENERREMOVED decrements the listener count for
            % the given event and notifies the view when the last listener
            % is removed.
            if ~isvalid(this)
                return
            end

            count = this.ReactiveEventListenerCount(eventName) - 1;
            this.ReactiveEventListenerCount(eventName) = count;

            if count == 0
                this.publish("@unlistenEvent", ...
                    ic.utils.toCamelCase(eventName));
            end
        end

        function tf = isReactiveEvent(this, eventName)
            % > ISREACTIVEEVENT returns whether the specified event is
            % marked as reactive.
            mc = meta.class.fromName(class(this));
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));
            tf = any(strcmp({reactiveEvents.Name}, eventName));
        end
    end

    methods (Access = ?ic.core.Container)
        function definition = getComponentDefinition(this)
            % > GETCOMPONENTDEFINITION returns a struct with all reactive
            % properties, events, and methods for the component.
            % This is used when inserting the component into the view to
            % provide the JavaScript side with the component schema.

            mc = meta.class.fromName(class(this));

            % Gather reactive properties
            metaProps = mc.PropertyList;
            reactiveProps = metaProps(...
                strcmp({metaProps.Description}, "Reactive") & ...
                [metaProps.SetObservable]);

            props = struct('name', {}, 'value', {});
            for ii = 1:numel(reactiveProps)
                propName = reactiveProps(ii).Name;
                props(ii).name = ic.utils.toCamelCase(propName);
                props(ii).value = this.(propName);
            end

            % Gather reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));

            events = struct('name', {});
            for jj = 1:numel(reactiveEvents)
                eventName = reactiveEvents(jj).Name;
                events(jj).name = ic.utils.toCamelCase(eventName);
            end

            % Gather reactive methods
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));

            methods = struct('name', {});
            for kk = 1:numel(reactiveMethods)
                methodName = reactiveMethods(kk).Name;
                methods(kk).name = ic.utils.toCamelCase(methodName);
            end

            % Return combined definition
            definition = struct(...
                'id', this.ID, ...
                'type', string(class(this)));
            % Note: assign as cells to ensure JSON arrays (not objects)
            definition.props = num2cell(props);
            definition.events = num2cell(events);
            definition.methods = num2cell(methods);
        end
    end

end

function mustBeValidCssIdent(id)
% MUSTBEVALIDCSSIDENT validates that the given string is a valid CSS identifier.
%
% CSS identifiers (idents) allow: letters (A-Z, a-z), digits (0-9),
% hyphens (-), underscores (_), and Unicode characters >= U+00A0.
%
% Restrictions:
%   - Cannot be empty
%   - Cannot start with a digit
%   - Cannot start with a hyphen followed by a digit
%
% See: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/ident

    % Build pattern for valid CSS ident characters
    validChar = lettersPattern(1) | digitsPattern(1) | characterListPattern("-_");

    % Check non-empty
    if strlength(id) == 0
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID cannot be empty.");
    end

    % Check all characters are valid (letters, digits, hyphens, underscores)
    if ~matches(id, asManyOfPattern(validChar, 1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' contains invalid characters. " + ...
              "Valid characters are: letters, digits, hyphens, and underscores.", id);
    end

    % Cannot start with a digit
    if startsWith(id, digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a digit.", id);
    end

    % Cannot start with hyphen followed by digit
    if startsWith(id, "-" + digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a hyphen followed by a digit.", id);
    end
end

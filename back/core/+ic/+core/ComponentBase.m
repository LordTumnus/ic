% > COMPONENTBASE is the abstract base class for interactive components.
% It provides the core event publishing/subscription infrastructure without defining the Parent property, allowing subclasses to define their own parent type.
classdef (Abstract) ComponentBase < handle & matlab.mixin.Heterogeneous

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
    end

    methods
        function this = ComponentBase(id)
            arguments (Input)
                % > ID unique identifier for the component
                id string = matlab.lang.internal.uuid();
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

            evt = ic.event.JsEvent(this.ID, name, data);
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
    end

    methods (Access = {?ic.core.View}, Hidden)
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
            this.subscribe("@event/" + eventName, ...
                @(~,~,data) notify(...
                    this, eventName, ic.event.MEvent(data)));
        end

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
                props(ii).name = propName;
                props(ii).value = this.(propName);
            end

            % Gather reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));

            events = struct('name', {});
            for jj = 1:numel(reactiveEvents)
                events(jj).name = reactiveEvents(jj).Name;
            end

            % Gather reactive methods
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));

            methods = struct('name', {});
            for kk = 1:numel(reactiveMethods)
                methods(kk).name = reactiveMethods(kk).Name;
            end

            % Return combined definition
            definition = struct(...
                'props', props, ...
                'events', events, ...
                'methods', methods);
        end
    end

    methods (Access = private)
        function resolveAndUnsubscribe(this, promise, name, evtData)
            % > RESOLVEANDUNSUBSCRIBE is the callback executed whenever the view replies to a publish call. Resolves the promise with the new event data and stops listening to that event
            promise.resolve(ic.async.Resolution(evtData.success, evtData.data));
            this.Subscriptions(name) = [];
        end

        function sendReactiveProperty(this, propertyName)
            % > SENDREACTIVEPROPERTY publishes an event with the name of the property being changed to the view
            evt = ic.event.JsEvent(...
             this.ID, ...
             "@prop/" + propertyName, ...
             struct("name", propertyName, "value", this.(propertyName)));
            this.send(evt);
        end

        function subscribeToReactiveProperty(this, propertyName)
            % > SUBSCRIBETOREACTIVEPROPERTIES subscribes to property changes from the view, and sets the component property when the view notifies the event
            this.subscribe("@prop/" + propertyName, ...
                @(~,~,data) setValueSilently(data.name, data.value))

            % nested function to avoid echoing the property change back to the view
            function setValueSilently(name, value)
                task = onCleanup(@() reenableListener(name));
                this.ReactivePropListeners(name).Enabled = false;
                this.(name) = value;
                function reenableListener(n)
                    this.ReactivePropListeners(n).Enabled = true;
                end
            end
        end

    end

end

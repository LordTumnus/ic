classdef (Abstract) Reactive < handle
    % automatic bidirectional synchronization of properties and events with the frontend.
    % Properties marked with Description = "Reactive" and SetObservable publish changes via events to the view, and subscribe to changes from the view. The view debounces property changes at 50ms to avoid flooding the communication channel, so rapid changes in the frontend only trigger one update.
    % Events marked with Description="Reactive" are forwarded from the frontend, and reach the component as a #ic.event.MEvent. One important property of events is that the view only starts publishing them once  a MATLAB listener is attached, and they stop being published when the last listener is removed.

    properties (Access = private)
        % PostSet listeners for reactive properties, keyed by property name
        ReactivePropListeners = ...
            dictionary(string.empty(), event.listener.empty());

        % reference count of MATLAB listeners per reactive event, used for
        % lazy activation
        ReactiveEventListenerCount = ...
            dictionary(string.empty(), double.empty());
    end

    methods (Abstract, Access = public)
        promise = publish(this, name, data)
        subscribe(this, name, callback)
    end

    methods
        function l = addlistener(this, varargin)
            % overrides MATALBs addlistener to track reactive event listeners.
            l = addlistener@handle(this, varargin{:});

            % only handle scalar source, simple event form
            if ~isscalar(this) || numel(varargin) ~= 2
                return
            end

            eventName = string(varargin{1});
            if ~this.isReactiveEvent(eventName)
                return
            end

            % increment listener count
            if this.ReactiveEventListenerCount.isKey(eventName)
                count = this.ReactiveEventListenerCount(eventName);
            else
                count = 0;
            end
            this.ReactiveEventListenerCount(eventName) = count + 1;

            % notify view on first listener
            if count == 0
                this.publish("@listenEvent", ...
                    ic.utils.toCamelCase(eventName));
            end

            % when this listener is destroyed, decrement and notify
            addlistener(l, 'ObjectBeingDestroyed', ...
                @(~,~) this.onReactiveListenerRemoved(eventName));
        end
    end

    methods (Access = protected)
        function setupReactivity(this)
            % introspects the class metadata and wires up all reactive
            % properties and events
            mc = meta.class.fromName(class(this));

            % properties marked Reactive + SetObservable
            metaProps = mc.PropertyList;
            reactiveProps = metaProps(...
                all([strcmp({metaProps.Description}, "Reactive"); ...
                [metaProps.SetObservable]]));
            for ii = 1:numel(reactiveProps)
                this.addPropReactivity(reactiveProps(ii).Name);
                this.subscribeToReactiveProperty(reactiveProps(ii).Name);
            end

            % events marked Reactive
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));
            for jj = 1:numel(reactiveEvents)
                this.addEventReactivity(reactiveEvents(jj).Name);
            end
        end
    end

    methods (Access = protected, Hidden)
        function addPropReactivity(this, propertyName)
            % attaches a PostSet listener that publishes property changes
            % to the view
            this.ReactivePropListeners(propertyName) = ...
                addlistener(this, propertyName, "PostSet", ...
                @(src, ~) this.sendReactiveProperty(src.Name));
        end

        function addEventReactivity(this, eventName)
            % subscribes to events from the view and re-notifies
            % as a MATLAB event with #ic.event.MEvent data.
            camelName = ic.utils.toCamelCase("@event/" + eventName);
            this.subscribe(camelName, ...
                @(~,~,data) notify(this, eventName, ic.event.MEvent(data)));
        end

        function setValueSilently(this, propName, value)
            % sets a reactive property without triggering a publish back
            % to the view, preventing echo loops.
            task = onCleanup(@() reenableListener(this, propName));
            this.ReactivePropListeners(propName).Enabled = false;
            this.(propName) = value;
            function reenableListener(obj, n)
                obj.ReactivePropListeners(n).Enabled = true;
            end
        end
    end

    methods (Access = protected)
        function sendReactiveProperty(this, propertyName)
            % publishes the property with the current value to the view.
            this.publish("@prop/" + propertyName, this.(propertyName));
        end

        function subscribeToReactiveProperty(this, propertyName)
            % subscribes to property events from the view and sets the
            % property silently (without echoing back).
            camelName = ic.utils.toCamelCase("@prop/" + propertyName);
            this.subscribe(camelName, ...
                @(~,~,data) this.setValueSilently(propertyName, data))
        end

        function tf = isReactiveMethod(this, methodName)
            % returns whether the specified method is marked as reactive
            % (Description="Reactive").
            mc = meta.class.fromName(class(this));
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));
            camelNames = arrayfun(@(m) ic.utils.toCamelCase(m.Name), ...
                reactiveMethods);
            tf = any(camelNames == methodName);
        end
    end

    methods (Access = protected)
        function [props, events, methods] = gatherReactiveDefinition(this)
            % collects reactive properties, events, and methods into struct
            % arrays for serialization in the component definition payload.
            mc = meta.class.fromName(class(this));

            % reactive properties
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

            % reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));

            events = struct('name', {});
            for jj = 1:numel(reactiveEvents)
                events(jj).name = ic.utils.toCamelCase(reactiveEvents(jj).Name);
            end

            % reactive methods
            metaMethods = mc.MethodList;
            reactiveMethods_ = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));

            methods = struct('name', {});
            for kk = 1:numel(reactiveMethods_)
                methods(kk).name = ic.utils.toCamelCase(reactiveMethods_(kk).Name);
            end

            % wrap as cells to ensure JSON arrays
            props = num2cell(props);
            events = num2cell(events);
            methods = num2cell(methods);
        end
    end

    methods (Access = private)
        function onReactiveListenerRemoved(this, eventName)
            % decrements the listener count and publishes an event
            % when the last MATLAB listener for a reactive event is removed.
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
            % returns whether the specified event is marked as reactive
            % (Description="Reactive").
            mc = meta.class.fromName(class(this));
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));
            tf = any(strcmp({reactiveEvents.Name}, eventName));
        end
    end

end

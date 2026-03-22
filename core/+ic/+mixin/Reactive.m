% > REACTIVE mixin providing automatic property/event synchronization with the frontend.
%
% Handles the "magic" that keeps MATLAB properties and the Svelte view
% in sync. Properties marked with Description="Reactive" + SetObservable
% automatically publish changes to the frontend, and events marked with
% Description="Reactive" are forwarded as MATLAB events when the frontend
% dispatches them.
%
% Host class must implement:
%   - publish(name, data) — send event to the view (from Publishable)
%   - subscribe(name, cb)  — listen for events from the view (from Publishable)
classdef (Abstract) Reactive < handle

    properties (Access = private)
        ReactivePropListeners = ...
            dictionary(string.empty(), event.listener.empty());
        % > REACTIVEEVENTLISTENERCOUNT tracks how many MATLAB listeners
        % exist per reactive event, so the view is only notified when the
        % first listener is added or the last one is removed.
        ReactiveEventListenerCount = ...
            dictionary(string.empty(), double.empty());
    end

    % --- Dependencies (satisfied by Publishable in the final class) ------
    methods (Abstract, Access = public)
        promise = publish(this, name, data)
        subscribe(this, name, callback)
    end

    % --- Public API -------------------------------------------------------
    methods
        function l = addlistener(this, varargin)
            % > ADDLISTENER adds a listener. When the first listener for a
            % reactive event is added, the view starts publishing that event.
            % When the last listener is removed, the view stops publishing.
            l = addlistener@handle(this, varargin{:});

            % Only handle scalar source, simple event form
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

    % --- Setup (called from ComponentBase constructor) --------------------
    methods (Access = protected)
        function setupReactivity(this)
            % > SETUPREACTIVITY introspects the class metadata and wires up
            % reactive properties and events.
            mc = meta.class.fromName(class(this));

            % Properties marked Reactive + SetObservable
            metaProps = mc.PropertyList;
            reactiveProps = metaProps(...
                all([strcmp({metaProps.Description}, "Reactive"); ...
                [metaProps.SetObservable]]));
            for ii = 1:numel(reactiveProps)
                this.addPropReactivity(reactiveProps(ii).Name);
                this.subscribeToReactiveProperty(reactiveProps(ii).Name);
            end

            % Events marked Reactive
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));
            for jj = 1:numel(reactiveEvents)
                this.addEventReactivity(reactiveEvents(jj).Name);
            end
        end
    end

    % --- Reactive property wiring -----------------------------------------
    methods (Access = protected, Hidden)
        function addPropReactivity(this, propertyName)
            % > ADDPROPREACTIVITY establishes a PostSet listener that
            % publishes property changes to the view.
            this.ReactivePropListeners(propertyName) = ...
                addlistener(this, propertyName, "PostSet", ...
                @(src, ~) this.sendReactiveProperty(src.Name));
        end

        function addEventReactivity(this, eventName)
            % > ADDEVENTREACTIVITY subscribes to events from the view and
            % re-notifies them as MATLAB events.
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

    % --- Overridable by Component / Frame ---------------------------------
    methods (Access = protected)
        function sendReactiveProperty(this, propertyName)
            % > SENDREACTIVEPROPERTY publishes an event with the name of
            % the property being changed to the view.
            this.publish("@prop/" + propertyName, this.(propertyName));
        end

        function subscribeToReactiveProperty(this, propertyName)
            % > SUBSCRIBETOREACTIVEPROPERTY subscribes to property changes
            % from the view, and sets the component property silently.
            camelName = ic.utils.toCamelCase("@prop/" + propertyName);
            this.subscribe(camelName, ...
                @(~,~,data) this.setValueSilently(propertyName, data))
        end

        function tf = isReactiveMethod(this, methodName)
            % > ISREACTIVEMETHOD returns whether the specified method is
            % marked as reactive.
            mc = meta.class.fromName(class(this));
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));
            camelNames = arrayfun(@(m) ic.utils.toCamelCase(m.Name), ...
                reactiveMethods);
            tf = any(camelNames == methodName);
        end
    end

    % --- Definition helper (called from ComponentBase aggregator) ---------
    methods (Access = protected)
        function [props, events, methods] = gatherReactiveDefinition(this)
            % > GATHERREACTIVEDEFINITION returns struct arrays of reactive
            % properties, events, and methods for serialization.
            mc = meta.class.fromName(class(this));

            % Reactive properties
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

            % Reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));

            events = struct('name', {});
            for jj = 1:numel(reactiveEvents)
                events(jj).name = ic.utils.toCamelCase(reactiveEvents(jj).Name);
            end

            % Reactive methods
            metaMethods = mc.MethodList;
            reactiveMethods_ = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));

            methods = struct('name', {});
            for kk = 1:numel(reactiveMethods_)
                methods(kk).name = ic.utils.toCamelCase(reactiveMethods_(kk).Name);
            end

            % Wrap as cells to ensure JSON arrays
            props = num2cell(props);
            events = num2cell(events);
            methods = num2cell(methods);
        end
    end

    % --- Private helpers --------------------------------------------------
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

end

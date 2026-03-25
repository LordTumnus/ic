classdef (Abstract) Publishable < handle
    % base class establishing the communication layer for exchanging events with the frontend.
    % Components can publish events to the view, subscribe to events from the
    % view, and queue events until the component is attached

    properties (SetAccess = protected)
        % queued #ic.event.JsEvent objects awaiting attachment to a view
        Queue = ic.event.JsEvent.empty();

        % map of event names to their callback handlers
        Subscriptions = dictionary(string.empty(), function_handle.empty());
    end

    methods (Abstract, Access = public)
        % returns whether the component is connected to a view
        tf = isAttached(this)
    end

    methods (Abstract, Access = protected)
        % dispatches one or more #ic.event.JsEvent towards the view
        send(this, evt)
    end

    methods (Access = public)
        function promise = publish(this, name, data)
            % sends a named event with data to the frontend view.
            % {note} The name of the event is converted to camelCase before dispatch {/note}
            % {returns} when called with an output argument, am #ic.async.Promise that resolves with the view response {/returns}

            arguments (Input)
                this (1,1) ic.mixin.Publishable
                % event name
                name (1,1) string
                % payload to send
                data % any
            end

            arguments (Output)
                promise ic.async.Promise
            end

            evtName = ic.utils.toCamelCase(name);
            evt = ic.event.JsEvent(this.ID, evtName, data);
            this.send(evt);

            % initialize a promise and resolve it when the same event id
            % is received from the view
            if (nargout == 1)
                promise = ic.async.Promise();
                evtName = "@resp/" + evt.Id;
                this.Subscriptions(evtName) = ...
                    @(~, ~, data) this.resolveAndUnsubscribe(...
                        promise, evtName, data);
            end
        end

        function subscribe(this, name, callback)
            % registers a callback for events with the given name
            arguments (Input)
                this (1,1) ic.mixin.Publishable
                % event name to listen for
                name (1,1) string
                % handler invoked as callback with signature @(comp, name, data) callback(comp, name, data), where comp is the component receiving the event, name is the event name, and data is the event payload
                callback (1,1) function_handle
            end
            this.Subscriptions(name) = callback;
        end

        function unsubscribe(this, name)
            % stops listening to events with the specified name.
            arguments (Input)
                this (1,1) ic.mixin.Publishable
                % event name to stop listening for
                name (1,1) string
            end
            this.Subscriptions(name) = [];
        end

        function queue = flush(this)
            % sends all queued events to the parent component and clears the queue. If and when the component is linked to a #ic.core.View, the events will reach the frontend
            % {returns} the flushed #ic.event.JsEvent array {/returns}
            if ~this.isAttached()
                return;
            end
            queue = this.Queue;
            this.send(queue);
            this.Queue = ic.event.JsEvent.empty();
        end
    end

    methods (Access = {?ic.core.View, ?matlab.uitest.TestCase}, Hidden)
        function receive(this, name, data)
            % dispatches an incoming event to the matching subscription callback.
            arguments
                this (1,1) ic.mixin.Publishable
                % event name received from the frontend
                name (1,1) string
                % event payload
                data % any
            end

            if this.Subscriptions.isKey(name)
                cb = this.Subscriptions(name);
                cb(this, name, data);
            end
        end
    end

    methods (Access = {?ic.Frame, ?ic.core.Component})
        function resolveAndUnsubscribe(this, promise, name, evtData)
            % resolves a publish promise and removes the @resp subscription.
            promise.resolve(ic.async.Resolution(evtData.success, evtData.data));
            this.Subscriptions(name) = [];
        end
    end

end

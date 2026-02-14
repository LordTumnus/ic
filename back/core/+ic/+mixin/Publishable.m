% > PUBLISHABLE mixin providing event messaging infrastructure.
%
% Provides the pub/sub communication layer that all components use to
% exchange events with the frontend view. Components can:
%   - Publish events to the view
%   - Subscribe to events from the view
%   - Queue events until the component is attached
%
% Host class must implement:
%   - isAttached() — whether the component is connected to a view
%   - send(evt)    — dispatch event(s) towards the view
classdef (Abstract) Publishable < handle

    properties (SetAccess = protected)
        % > QUEUE list of javascript events that will be published when the component is attached
        Queue = ic.event.JsEvent.empty();
        % > SUBSCRIPTIONS map between event names and callbacks that will be executed upon receiving those events
        Subscriptions = dictionary(string.empty(), function_handle.empty());
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
            % > PUBLISH sends an event with the specified name and data to the view

            arguments (Input)
                this (1,1) ic.mixin.Publishable
                name (1,1) string
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
            % > SUBSCRIBE registers a callback for events with the given name
            arguments (Input)
                this (1,1) ic.mixin.Publishable
                name (1,1) string
                callback (1,1) function_handle
            end
            this.Subscriptions(name) = callback;
        end

        function unsubscribe(this, name)
            % > UNSUBSCRIBE stops listening to events with the specified name
            arguments (Input)
                this (1,1) ic.mixin.Publishable
                name (1,1) string
            end
            this.Subscriptions(name) = [];
        end

        function queue = flush(this)
            % > FLUSH sends all queued events and clears the queue
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
            % > RECEIVE finds an event in the subscriptions and executes its callback
            arguments
                this (1,1) ic.mixin.Publishable
                name (1,1) string
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
            % > RESOLVEANDUNSUBSCRIBE resolves a publish promise and stops listening
            promise.resolve(ic.async.Resolution(evtData.success, evtData.data));
            this.Subscriptions(name) = [];
        end
    end

end

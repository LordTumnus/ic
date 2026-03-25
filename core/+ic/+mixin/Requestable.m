classdef (Abstract) Requestable < handle
    % frontend-initiated request/response communication.
    % Enables the Svelte frontend to send named requests to MATLAB and receive responses asynchronously. Used for load-on-demand patterns where the frontend pulls data (e.g., lazy loading of #ic.VirtualTree). Internally subscribes to a request event with a unique name, and on receiving, publishes a response event with the same unique ID

    methods (Abstract, Access = public)
        subscribe(this, name, callback)
    end

    methods (Abstract, Access = protected)
        send(this, evt)
    end

    methods (Access = public)
        function onRequest(this, name, callback)
            % registers a handler for frontend requests.
            arguments (Input)
                this (1,1) ic.mixin.Requestable
                % request name
                name (1,1) string
                % handler invoked as result, with signature @(comp, data) callback(comp, data)
                callback (1,1) function_handle
            end

            camelName = "@request/" + ic.utils.toCamelCase(name);
            this.subscribe(camelName, @(comp, ~, payload) ...
                comp.handleFrontendRequest(payload, callback));
        end
    end

    methods (Access = private)
        function handleFrontendRequest(this, payload, callback)
            % processes an incoming request and sends the response back
            try
                result = callback(this, payload.data);
                response = struct('success', true, 'data', []);
                response.data = result;
            catch ex
                response = struct('success', false, 'data', ex.message);
            end
            evt = ic.event.JsEvent(this.ID, ...
                "@resp/" + string(payload.id), response);
            % send directly to bypass publish
            this.send(evt);
        end
    end

end

% > REQUESTABLE mixin providing frontend-initiated request/response.
%
% Enables the Svelte frontend to send requests to MATLAB and receive
% responses. Used for load-on-demand patterns (e.g., VirtualTree).
%
%   comp.onRequest("LoadChunk", @(comp, data) comp.getChunk(data))
%
% Host class must implement:
%   - subscribe(name, cb) — listen for events from the view (from Publishable)
%   - send(evt)           — dispatch event towards the view (from Publishable)
classdef (Abstract) Requestable < handle

    % --- Dependencies (satisfied by Publishable in the final class) ------
    methods (Abstract, Access = public)
        subscribe(this, name, callback)
    end

    methods (Abstract, Access = protected)
        send(this, evt)
    end

    % --- Public API -------------------------------------------------------
    methods (Access = public)
        function onRequest(this, name, callback)
            % > ONREQUEST registers a handler for frontend requests.
            arguments (Input)
                this (1,1) ic.mixin.Requestable
                % > NAME the request name (PascalCase, e.g. "LoadChunk")
                name (1,1) string
                % > CALLBACK function that processes the request: result = callback(comp, data)
                callback (1,1) function_handle
            end

            camelName = "@request/" + ic.utils.toCamelCase(name);
            this.subscribe(camelName, @(comp, ~, payload) ...
                comp.handleFrontendRequest(payload, callback));
        end
    end

    % --- Private ----------------------------------------------------------
    methods (Access = private)
        function handleFrontendRequest(this, payload, callback)
            % > HANDLEFRONTENDREQUEST processes an incoming request from
            % the Svelte frontend and sends back a response.
            try
                result = callback(this, payload.data);
                response = struct('success', true, 'data', []);
                response.data = result;
            catch ex
                response = struct('success', false, 'data', ex.message);
            end
            evt = ic.event.JsEvent(this.ID, ...
                "@resp/" + string(payload.id), response);
            this.send(evt);
        end
    end

end

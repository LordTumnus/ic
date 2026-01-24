% > PROMISE Promises are objects that only contain a value when they are resolved.
%
% They are useful when fetching data from the view:
% - The fetch event is requested (through a @Component.publish call), and an unresolved promise is returned
% - The graphics queue is flushed
% - The fetch event is processed by the view, which replies with the value
% - The response is received by the controller, which resolves the promise with the value
classdef Promise < handle

    properties (SetAccess = private)
        % > VALUE the value to which the promise resolves
        Value % any
    end

    properties (SetAccess = private)
        % > FULLFILLED boolean indicating if the promise has been resolved
        Fullfilled (1,1) logical = false;
    end

    events (NotifyAccess = private)
        % > PROMISEFULLFILLED event triggered when the promise gets resolved into a non-promise value
        PromiseFullfilled
    end

    methods
        function tf = isResolved(this)
            % > ISRESOLVED returns a boolean indicating if the promise has been
            % fullfilled
            arguments (Input)
                % > THIS the promise
                this (1,1) ic.async.Promise
            end

            tf = this.Fullfilled;
        end

        function value = get(this)
            % > GET returns the value of the promise. If the promise has not been resolved yet, the output will be empty
            value = this.Value;
        end

        function resolve(this, value)
            % RESOLVE fullfills the promise with the specified value.
            arguments (Input)
                % > THIS the promise
                this (1,1) ic.async.Promise
                % > VALUE the value to which the promise resolves. If it is another promise, then the first promise does not get resolved until the new one does
                value % any
            end

            % if the resolution value is a new promise, then this one is not
            % considered to have resolved until the new one does.
            if isa(value, "ic.async.Promise")
                addlistener(value, "PromiseFullfilled", ...
                    @(~,~) this.resolve(value.get()));
                return;
            end

            this.Fullfilled = true;
            this.Value = value;
            this.notify("PromiseFullfilled");
        end

        function other = then(this, callback)
            % > THEN evaluates the callback right after the promise is resolved, with the resolved value. The output is therefore another promise
            % > note: This method allows concatenating actions. For example:
            %   >> promise.then(@(x) x+1).then(@(x) 2*x)
            %   resolves into 2(promise.get()+1)
            arguments (Input)
                % > THIS the promise
                this (1,1) ic.async.Promise
                % > CALLBACK the function executed when the promise resolves.
                % > type: @(value) fn(value);
                callback (1,1) function_handle = @(~) this.get();
            end

            arguments (Output)
                % > OTHER the new promise that resolves into the value of the callback
                other (1,1) ic.async.Promise
            end

            % create the output promise
            other = ic.async.Promise();
            % if this promise is already fullfilled, resolve other immediately
            if this.Fullfilled
                other.resolve(evaluateCallback(callback, this.get()));
                return;
            end
            % attach a listener that resolves "other" when this promise gets
            % fullfilled
            addlistener(this, "PromiseFullfilled", ...
                @(~,~) other.resolve(evaluateCallback(callback, this.get())));
        end

        function this = wait(this, maxTime, interval)
            % > WAIT blocks the execution thread until the promise gets fullfilled
            arguments (Input)
                % > THIS the promise
                this (1,1) ic.async.Promise
                % > MAXTIME the maximum time that the thread will be paused
                maxTime double = 1;
                % > INTERVAL the amount of time between pauses checking if the promise has been resolved
                interval double = .05;
            end

            % fForce a graphics update
            drawnow;
            time = 0;
            % pause matlabs execution until the promise has been fullfilled or until max time
            while ~this.Fullfilled && (time < maxTime)
                time = time + interval;
                pause(interval);
            end
        end
    end

    methods (Static)
        function this = all(promises)
            % > ALL returns a new promise that is fullfilled only after all the input promises have been resolved. The returned promise resolves into a cell array containing the results of the other promises
            arguments (Input, Repeating)
                % > PROMISES the group of promises that need to be resolved for the output one to also be resolved
                promises (1,1) ic.async.Promise
            end
            arguments (Output)
                % > THIS the output promise
                this (1,1) ic.async.Promise
            end

            promises = [promises{:}];
            this = ic.async.Promise();

            % early return if all promises are fullfilled
            fullfilled = [promises.Fullfilled];
            if all(fullfilled)
                values = arrayfun(@(p) p.get(), promises, 'UniformOutput', false);
                this.resolve(values);
                return;
            end

            % otherwise attach listener to unresolved promises
            arrayfun(@(x) addlistener(x, "PromiseFullfilled", ...
                @(~, ~) checkAll()), promises(~fullfilled));
            function checkAll()
                if all([promises.Fullfilled])
                    % Use arrayfun to collect all values (not just first)
                    values = arrayfun(@(p) p.get(), promises, 'UniformOutput', false);
                    this.resolve(values);
                end
            end
        end
    end

end

function out = evaluateCallback(cb, value)
nOut = nargout(cb);
[out{1:nOut}] = feval(cb, value);
if isempty(out)
    out = value;
else
    out = out{1};
end
end

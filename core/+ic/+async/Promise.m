classdef Promise < handle
   % represents a pending value from a client-side method call or request.
   % Users can check if the promise has fulfilled with#ic.async.Promise.isResolved and get the value with #ic.async.Promise.get. The promise fulfills when the client responds to the request, and the resolved value is passed to any callbacks registered with #ic.async.Promise.then. Users can also block execution until fulfillment with #ic.async.Promise.wait, which polls the promise's status until it fulfills or a timeout elapses

   properties (SetAccess = private)
      % resolved value; empty until the promise fulfills
      Value % any
   end

   properties (SetAccess = private)
      % whether the promise has fulfilled (resolved to a value)
      Fullfilled (1,1) logical = false;
   end

   events (NotifyAccess = private)
      % fires when the promise fulfills
      PromiseFullfilled
   end

   methods
      function tf = isResolved(this)
         % return true if the promise has fulfilled.
         % {returns} logical {/returns}
         arguments (Input)
            this (1,1) ic.async.Promise
         end
         tf = this.Fullfilled;
      end

      function value = get(this)
         % return the resolved value, or empty if not yet fulfilled.
         % {returns} resolved value, or [] if still pending {/returns}
         % {note} check #ic.async.Promise.isResolved before calling #ic.async.Promise.get to distinguish a fulfilled empty value from a still pending promise. {/note}
         value = this.Value;
      end

      function resolve(this, value)
         % fulfill the promise with the given value.
         % if value is another promise, waits for that promise to resolve first.
         arguments (Input)
            this (1,1) ic.async.Promise
            % fulfillment value; if another ic.async.Promise, chains to it
            value % any
         end

         % if the resolution value is another promise, chain to it
         if isa(value, "ic.async.Promise")
            if value.isResolved()
               value = value.get();
            else
               addlistener(value, "PromiseFullfilled", ...
                   @(~,~) this.resolve(value.get()));
               return;
            end
         end

         this.Fullfilled = true;
         this.Value = value;
         this.notify("PromiseFullfilled");
      end

      function other = then(this, callback)
         % register a callback to run when the promise fulfills
         % If the promise was already fulfilled, the callback runs immediately.
         % {returns} a new #ic.async.Promise that resolves to the callback's return value {/returns}
         % {example}
         %   p = comp.focus();
         %   p.then(@(res) disp(res.Data));
         %   result = p.then(@(x) x * 2).then(@(x) x + 1);
         % {/example}
         arguments (Input)
            this (1,1) ic.async.Promise
            % function called with the resolved value, with signature @(value) callback(value)
            callback (1,1) function_handle = @(~) this.get();
         end
         arguments (Output)
            other (1,1) ic.async.Promise
         end

         other = ic.async.Promise();
         if this.Fullfilled
            other.resolve(evaluateCallback(callback, this.get()));
            return;
         end
         addlistener(this, "PromiseFullfilled", ...
             @(~,~) other.resolve(evaluateCallback(callback, this.get())));
      end

      function this = wait(this, maxTime, interval)
         % block execution until the promise fulfills or the timeout elapses.
         % {example}
         %   p = comp.focus().wait(2);
         %   if p.isResolved(), disp(p.get()); end
         % {/example}
         arguments (Input)
            this (1,1) ic.async.Promise
            % maximum seconds to wait before giving up
            maxTime double = 1;
            % polling interval in seconds while waiting
            interval double = .05;
         end

         drawnow;
         time = 0;
         while ~this.Fullfilled && (time < maxTime)
            time = time + interval;
            pause(interval);
         end
      end
   end

   methods (Static)
      function this = all(promises)
         % return a new promise that fulfills when all input promises have fulfilled.
         % {returns} #ic.async.Promise resolving to a cell array of each promise's value {/returns}
         % {example}
         %   p1 = comp1.focus();
         %   p2 = comp2.focus();
         %   ic.async.Promise.all(p1, p2).wait();
         % {/example}
         arguments (Input, Repeating)
            % promises to wait for; pass each as a separate argument
            promises (1,1) ic.async.Promise
         end
         arguments (Output)
            this (1,1) ic.async.Promise
         end

         promises = [promises{:}];
         this = ic.async.Promise();

         % early return if all already fulfilled
         fullfilled = [promises.Fullfilled];
         if all(fullfilled)
            values = arrayfun(@(p) p.get(), promises, 'UniformOutput', false);
            this.resolve(values);
            return;
         end

         % attach listener to each unresolved promise
         arrayfun(@(x) addlistener(x, "PromiseFullfilled", ...
             @(~, ~) checkAll()), promises(~fullfilled));
         function checkAll()
            if all([promises.Fullfilled])
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

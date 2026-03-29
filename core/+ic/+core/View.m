classdef View < matlab.ui.componentcontainer.ComponentContainer
   % uihtml bridge between the MATLAB component tree and the Svelte frontend. Created and owned by #ic.Frame, users never instantiate View directly.
   %
   % Wraps a uihtml element that serves front/dist/index.html over a local
   % HTTPS server, and opens it in an <iframe> inside a uifigure.
   % Communication uses two named event channels:
   %   MATLAB → JS: components propagate their #ic.event.JsEvent up the tree until the view, responsible for calling __sendEventToHTMLSource(h, "ic", payload)__
   %   JS → MATLAB: uihtmls __HTMLEventReceivedFcn__ captures frontend events and routes them to the appropriate component handler via #ic.Frame.Registry lookup.
   %
   % Before each send, #ic.AssetRegistry.activate is called so
   % that asset deduplication (hash-only stubs for repeated assets) is
   % tracked for each view instance

   properties (SetAccess = private, Hidden)
      % uigridlayout that fills the panel area with a single 1×1 cell (no padding)
      GridLayout matlab.ui.container.GridLayout

      % uihtml element that hosts the compiled frontend app
      HTMLElement matlab.ui.control.HTML

      % true once the frontend has signalled that it is ready to receive
      Ready (1,1) logical = false

      % events queued while waiting for the frontend to become ready
      Queue = ic.event.JsEvent.empty()
   end

   properties (SetAccess = private)
      % the #ic.Frame instance that owns this view
      Frame % ic.Frame
   end

   properties (Constant, Hidden)
      % absolute path to the compiled Svelte entry point (front/dist/index.html)
      HTMLSource = fullfile(fileparts(mfilename("fullpath")), "..", "..", "..", "front", "dist", "index.html");
   end


   methods
      function this = View(frame, args)
         arguments (Input)
            % owning #ic.Frame instance
            frame % ic.Frame
         end
         arguments (Input, Repeating)
            args
         end
         this@matlab.ui.componentcontainer.ComponentContainer(args{:});
         this.Frame = frame;
      end
   end

   methods (Access = protected)
      function setup(this)
         % create the uigridlayout and uihtml elements and wire the event callback.
         this.GridLayout = uigridlayout( ...
            "Parent", this, ...
            "ColumnWidth", {'1x'}, "RowHeight",{'1x'}, "Padding", 0);

         this.HTMLElement = uihtml( ...
            "Parent", this.GridLayout, ...
            "HTMLSource", this.HTMLSource, ...
            "HTMLEventReceivedFcn", @(~,evt) this.onHTMLEvent(evt));
      end

      function update(~)
         % required by matlab.ui.componentcontainer.ComponentContainer. Intentionally empty.
      end
   end


   methods (Access = {?ic.Frame})
      function send(this, events)
         % send one or more events to the Svelte frontend.
         % Before the frontend signals readiness, events are queued
         % locally and flushed once the @ready handshake completes.
         % After that, events are sent directly.
         arguments
            this
            % array of #ic.event.JsEvent to send to the frontend
            events (1,:) ic.event.JsEvent
         end
         if this.Ready
            ic.AssetRegistry.activate(this);
            payload = ic.utils.toTransport(events.toStruct());
            sendEventToHTMLSource(this.HTMLElement, "ic", payload);
         else
            this.Queue = [this.Queue, events];
         end
      end
   end

   methods (Access = private)
      function onHTMLEvent(this, evt)
         % route raw __HTMLEventReceivedFcn__ events to the appropriate handler.
         if evt.HTMLEventName == "ic"
            this.onReceive(evt.HTMLEventData);
         elseif evt.HTMLEventName == "ready"
            this.onReady();
         end
      end

      function onReady(this)
         % called when the frontend signals that it is fully initialized
         % and ready to receive events. Flushes all pending events.
         this.Ready = true;
         if ~isempty(this.Queue)
            pending = this.Queue;
            this.Queue = ic.event.JsEvent.empty();
            ic.AssetRegistry.activate(this);
            payload = ic.utils.toTransport([pending.toStruct()]);
            sendEventToHTMLSource(this.HTMLElement, "ic", payload);
         end
      end

      function onReceive(this, raw)
         % parse and dispatch incoming events from the Svelte frontend to their respective MATLAB component handlers
         if isempty(raw)
            return;
         end

         if isstring(raw) || ischar(raw)
            data = jsondecode(raw);
         else
            data = raw;
         end

         if iscell(data)
            events = data;
         elseif isstruct(data)
            events = num2cell(data);
         else
            return;
         end

         for ii = 1:numel(events)
            evt = events{ii};
            if evt.component == "ic-frame"
               this.Frame.receive(evt.name, evt.data);
            elseif this.Frame.Registry.isKey(evt.component)
               comp = this.Frame.Registry(evt.component);
               comp.receive(evt.name, evt.data);
            end
         end
      end
   end

end

classdef View < matlab.ui.componentcontainer.ComponentContainer
   % uihtml bridge between the MATLAB component tree and the Svelte frontend. Created and owned by #ic.Frame, users never instantiate View directly.
   %
   % Wraps a uihtml element that serves front/dist/index.html over a local
   % HTTPS server, and opens it in an <iframe> inside a uifigure.
   % Communication uses two named event channels:
   %   MATLAB → JS: components propagate their #ic.event.JsEvent up the tree until the view, responsible for calling __sendEventToHTMLSource(h, "ic", payload)__
   %   JS → MATLAB: uihtmls __HTMLEventReceivedFcn__ captures frontend events and routes them to the appropriate component handler via #ic.Frame.Registry lookup.
   %
   % Before each send, #ic.asset.AssetRegistry.activate is called so
   % that asset deduplication (hash-only stubs for repeated assets) is
   % tracked for each view instance

   properties (SetAccess = private, Hidden)
      % uigridlayout that fills the panel area with a single 1×1 cell (no padding)
      GridLayout matlab.ui.container.GridLayout

      % uihtml element that hosts the compiled frontend app
      HTMLElement matlab.ui.control.HTML

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
         % Converts the event array to transport format via #ic.utils.toTransport, and then calls uihtml native __sendEventToHTMLSource__. Events sent before the page loads are buffered internally by uihtml.
         arguments
            this
            % array of #ic.event.JsEvent to send to the frontend
            events (1,:) ic.event.JsEvent
         end
         ic.asset.AssetRegistry.activate(this);
         payload = ic.utils.toTransport(events.toStruct());
         sendEventToHTMLSource(this.HTMLElement, "ic", payload);
      end
   end

   methods (Access = private)
      function onHTMLEvent(this, evt)
         % route raw __HTMLEventReceivedFcn__ events to the appropriate handler.
         if evt.HTMLEventName == "ic"
            this.onReceive(evt.HTMLEventData);
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

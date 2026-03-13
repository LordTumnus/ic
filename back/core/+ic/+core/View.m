% VIEW bridges MATLAB components to the HTML frontend via uihtml.
%
% MATLAB → JS: sendEventToHTMLSource("ic", event) — one event at a time
% JS → MATLAB: sendEventToMATLAB("ic", events)   — via HTMLEventReceivedFcn
%
% On startup, events are queued until the frontend sends "ic-ready".
classdef View < matlab.ui.componentcontainer.ComponentContainer

   properties (SetAccess = private, Hidden)
      GridLayout matlab.ui.container.GridLayout
      HTMLElement matlab.ui.control.HTML
      Ready logical = false
      Queue = ic.event.JsEvent.empty()
   end

   properties (SetAccess = private)
      Frame % ic.core.Frame
   end

   properties (Constant, Hidden)
      % TODO: fix the path of the source file
      HTMLSource = fullfile(fileparts(mfilename("fullpath")), "..", "..", "..", "..", "front", "dist", "index.html");
   end


   methods
      function this = View(frame, args)
         arguments (Input)
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
         this.GridLayout = uigridlayout( ...
            "Parent", this, ...
            "ColumnWidth", {'1x'}, "RowHeight",{'1x'}, "Padding", 0);

         this.HTMLElement = uihtml( ...
            "Parent", this.GridLayout, ...
            "HTMLSource", this.HTMLSource, ...
            "HTMLEventReceivedFcn", @(~,evt) this.onHTMLEvent(evt));
      end

      function update(~)
      end
   end


   methods (Access = {?ic.Frame})
      function send(this, events)
         if this.Ready
            ic.asset.AssetRegistry.activate(this);
            for ii = 1:numel(events)
               sendEventToHTMLSource(this.HTMLElement, "ic", jsonencode(events(ii)));
            end
         else
            this.Queue((end+1):(end+numel(events))) = events;
         end
      end
   end

   methods (Access = private)
      function onHTMLEvent(this, evt)
         if evt.HTMLEventName == "ic-ready"
            this.Ready = true;
            if ~isempty(this.Queue)
               ic.asset.AssetRegistry.activate(this);
               data = this.Queue;
               this.Queue = ic.event.JsEvent.empty();
               for ii = 1:numel(data)
                  sendEventToHTMLSource(this.HTMLElement, "ic", jsonencode(data(ii)));
               end
            end
         elseif evt.HTMLEventName == "ic"
            this.onReceive(evt.HTMLEventData);
         end
      end

      function onReceive(this, raw)
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

% VIEW implements the builtin ComponentContainer, and defines the methods used to transfer data between the components (in Matlab) and their views (in JS)
classdef View < matlab.ui.componentcontainer.ComponentContainer

   properties (SetAccess = private, Hidden)
      % > GRIDLAYOUT internal layout manager that forces the HTML frame to fill the whole area from the ComponentContainer
      GridLayout matlab.ui.container.GridLayout
      % > HTMLElement base <iframe> wrapper that loads the HTML source file and allows sharing data between Matlab and JS
      HTMLElement matlab.ui.control.HTML

      TicToc = false;
   end

   properties (SetAccess = {?ic.core.View, ?ic.Frame, ?matlab.uitest.TestCase})
      % > QUEUE list of events that will be published when the parent of the component is defined
      Queue = ic.event.JsEvent.empty();
   end

   properties (SetAccess = private)
      % > FRAME the frame component that this view is attached to
      Frame % ic.core.Frame
   end

   properties (Constant, Hidden)
      % > HTMLSOURCE path of the HTML file that will be loaded inside the HTML component
      % TODO: fix the path of the source file
      HTMLSource = fullfile(fileparts(mfilename("fullpath")), "..", "..", "..", "..", "front", "dist", "index.html");
   end


   methods
      function this = View(frame, args)
         % > VIEW creates a view for a frame component
         arguments (Input)
            frame % ic.Frame
         end
         arguments (Input, Repeating)
            args
         end

         % call superclass constructor with name-value pairs
         this@matlab.ui.componentcontainer.ComponentContainer(args{:});
         this.Frame = frame;
      end
   end

   % > overload: matlab.ui.componentcontainer.ComponentContainer
   methods (Access = protected)
      function setup(this)
         % > SETUP creates a [1,1] layout inside the container and appends to it the HTML element. In the view, this will cause the <iframe> to fill the full area of the containers <div>
         % > note: Called during instantiation, inside the constructor

         this.GridLayout = uigridlayout( ...
            "Parent", this, ...
            "ColumnWidth", {'1x'}, "RowHeight",{'1x'}, "Padding", 0);

         this.HTMLElement = uihtml( ...
            "Parent", this.GridLayout, ...
            "HTMLSource", this.HTMLSource, ...
            "DataChangedFcn", @(~,evt) this.onReceive(evt.Data));
      end

      function update(this)
         % > UPDATE sends the queued events to the view
         % > note: Called whenever Matlabs graphic event queue is flushed (including drawnow, pause, input)

         if isempty(this.Queue)
            return;
         end
         % copy the queued events and clear the queue
         data = this.Queue;
         this.Queue = ic.event.JsEvent.empty();
         % cast queue into a cell -> JSON encoded will allways be an array
         this.HTMLElement.Data = num2cell(data);

      end
   end


   methods (Access = {?ic.Frame})
      function send(this, event)
         % > SEND stores an event in the queue. Events are flushed from the queue when @View.update is called
         this.Queue((end+1):(end+numel(event))) = event;
         this.TicToc = ~this.TicToc;
      end
   end

   methods (Access = private)
      function onReceive(this, data)
         % > ONRECEIVE dispatches events from the view to the component they are targeted to
         % > note: Uses O(1) Registry lookup instead of O(n) tree traversal
         % > note: data is an array of events from JavaScript (cell array or struct array)
         if isempty(data)
            return;
         end

         % Handle both cell array and struct array formats from JSON
         if iscell(data)
            events = data;
         else
            events = num2cell(data);
         end

         for ii = 1:numel(events)
            evt = events{ii};
            if evt.component == "@ic.frame"
               % Event targeted at the Frame itself
               this.Frame.receive(evt.name, evt.data);
            elseif this.Frame.Registry.isKey(evt.component)
               comp = this.Frame.Registry(evt.component);
               comp.receive(evt.name, evt.data);
            end
         end
      end
   end

end

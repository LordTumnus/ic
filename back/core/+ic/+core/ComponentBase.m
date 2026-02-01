% > COMPONENTBASE is the abstract base class for interactive components.
% It provides the core event publishing/subscription infrastructure without defining the Parent property, allowing subclasses to define their own parent type.
classdef (Abstract) ComponentBase < handle & matlab.mixin.Heterogeneous

    properties (SetAccess = immutable)
        % > ID unique identifier of the component
        ID (1,1) string
    end

    properties (SetAccess = protected)
        % > QUEUE list of javascript events that will be published when the component is attached
        Queue = ic.event.JsEvent.empty();
        % > SUBSCRIPTIONS map between event names and callbacks that will be executed upon receiving those events
        Subscriptions = dictionary(string.empty(), function_handle.empty());
    end

    properties (Access = private)
        ReactivePropListeners = ...
            dictionary(string.empty(), event.listener.empty());
    end

    properties (SetAccess = private)
        % > STYLES stores dynamic CSS styles per selector (selector → struct of properties)
        Styles = dictionary(string.empty(), struct.empty());
    end

    methods
        function this = ComponentBase(id)
            arguments (Input)
                % > ID unique identifier for the component
                id (1,1) string {mustBeValidCssIdent} = ...
                    "ic-" + matlab.lang.internal.uuid();
            end

            arguments (Output)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
            end

            this.ID = id;

            % setup reactivity for properties marked as "Reactive"
            mc = meta.class.fromName(class(this));
            metaProps = mc.PropertyList;
            reactiveProps = metaProps(...
                all([strcmp({metaProps.Description}, "Reactive"); ...
                [metaProps.SetObservable]]));
            for ii = 1:numel(reactiveProps)
                this.addPropReactivity(reactiveProps(ii).Name);
                this.subscribeToReactiveProperty(reactiveProps(ii).Name);
            end

            % setup reactivity for events marked as "Reactive"
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));
            for jj = 1:numel(reactiveEvents)
                this.addEventReactivity(reactiveEvents(jj).Name);
            end
        end
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
            % > PUBLISH sends an event with the specified name and data to the view. Optionally define an output promise that will be resolved when the view processes the event

            arguments (Input)
                % > THIS component sending the event
                this (1,1) ic.core.ComponentBase
                % > NAME name of the event
                name (1,1) string
                % > DATA any information carried within the event
                data % any
            end

            arguments (Output)
                % > PROMISE? a promise that resolves into a @Resolution when the view has received and processed the event
                promise ic.async.Promise
            end

            if ~startsWith(name, "@") && ~this.isReactiveMethod(name)
                error("ic:core:ComponentBase:PublishReactiveMethod", ...
                      "Cannot publish reactive method '%s'. Reactive methods are invoked directly on the component instance.", name);
            end

            evtName = ic.utils.toCamelCase(name);
            evt = ic.event.JsEvent(this.ID, evtName, data);
            this.send(evt);

            % initialize a promise and resolve it when the same event id is received from the view
            if (nargout == 1)
                promise = ic.async.Promise();
                evtName = "@resp/" + evt.Id;
                this.Subscriptions(evtName) = ...
                    @(~, ~, data) this.resolveAndUnsubscribe(...
                        promise, evtName, data);
            end
        end

        function subscribe(this, name, callback)
            % > SUBSCRIBE registers a callback that will be evaluated when an event with a given name is received from the view
            arguments (Input)
                % > THIS the component subscribing to the event
                this (1,1) ic.core.ComponentBase
                % > NAME the name of the event
                name (1,1) string
                % > CALLBACK the function executed every time the event is received.
                % The callback is a function that takes 3 arguments: the component receiving the event, the event name and the event data
                callback (1,1) function_handle
            end
            this.Subscriptions(name) = callback;
        end

        function unsubscribe(this, name)
            % > UNSUBSCRIBE stops listening to events with the specified name (clears the subscription)
            arguments (Input)
                % > THIS the component subscribing to the event
                this (1,1) ic.core.ComponentBase
                % > NAME the name of the event
                name (1,1) string
            end
            this.Subscriptions(name) = [];
        end

        function queue = flush(this)
            % > FLUSH sends all queued events and clears the queue
            if ~this.isAttached()
                return
            end
            queue = this.Queue;
            this.send(queue);
            this.Queue = ic.event.JsEvent.empty();
        end

        function style(this, selector, varargin)
            % > STYLE applies CSS styles to elements matching the selector.
            % Styles are merged with existing styles for that selector.
            % To remove a property, set its value to "".

            arguments (Input)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
                % > SELECTOR CSS selector for target elements
                selector (1,1) string
            end

            arguments (Input, Repeating)
                % > VARARGIN name-value pairs or a single struct
                varargin
            end

            % Parse input into a struct of new styles
            if isscalar(varargin) && isstruct(varargin{1})
                newStyles = varargin{1};
            else
                if mod(numel(varargin), 2) ~= 0
                    error("ic:core:ComponentBase:InvalidStyleArgs", ...
                          "Style properties must be specified as name-value pairs.");
                end
                varargin(1:2:end) = ...
                  cellfun(@string, varargin(1:2:end), 'UniformOutput', false);
                newStyles = struct(varargin{:});
            end

            % Merge with existing styles for this selector
            if this.Styles.isKey(selector)
                existingStyles = this.Styles(selector);
            else
                existingStyles = struct();
            end

            % Apply new styles (merge), removing properties set to ""
            fields = fieldnames(newStyles);
            for jj = 1:numel(fields)
                fname = fields{jj};
                fvalue = newStyles.(fname);
                if isstring(fvalue) && fvalue == ""
                    % Remove property
                    if isfield(existingStyles, fname)
                        existingStyles = rmfield(existingStyles, fname);
                    end
                else
                    existingStyles.(fname) = fvalue;
                end
            end

            % Store merged styles
            this.Styles(selector) = existingStyles;

            % Convert property names to kebab-case for CSS
            mergedFields = fieldnames(existingStyles);
            kebabKeys = cell(1, numel(mergedFields));
            values = cell(1, numel(mergedFields));
            for kk = 1:numel(mergedFields)
                kebabKeys{kk} = char(ic.utils.toKebabCase(mergedFields{kk}));
                values{kk} = existingStyles.(mergedFields{kk});
            end
            cssStyles = containers.Map(kebabKeys, values);

            % Publish the complete styles for this selector
            this.publish("@style", struct( ...
                "selector", selector, ...
                "styles", cssStyles));
        end

        function styles = getStyle(this, selector)
            % > GETSTYLE returns the current styles for a selector.
            % Returns an empty struct if no styles are set for the selector.
            arguments (Input)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
                % > SELECTOR CSS selector to get styles for
                selector (1,1) string
            end

            arguments (Output)
                % > STYLES struct of current style properties
                styles (1,1) struct
            end

            if this.Styles.isKey(selector)
                styles = this.Styles(selector);
            else
                styles = struct();
            end
        end

        function clearStyle(this, selector)
            % > CLEARSTYLE removes all styles for a specific selector.
            arguments (Input)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
                % > SELECTOR CSS selector to clear styles for
                selector (1,1) string
            end

            if this.Styles.isKey(selector)
                this.Styles(selector) = [];
            end

            this.publish("@clearStyle", struct("selector", selector));
        end

        function clearStyles(this)
            % > CLEARSTYLES removes all dynamic styles for the component.
            arguments (Input)
                % > THIS the component
                this (1,1) ic.core.ComponentBase
            end

            this.Styles = dictionary(string.empty(), struct.empty());
            this.publish("@clearStyles", struct());
        end
    end

    methods (Access = {?ic.core.View, ?matlab.uitest.TestCase}, Hidden)
        function receive(this, name, data)
            % > RECEIVE finds an event in the subscriptions and executes its callback
            % > note: RECEIVE is executed whenever an event from the view is received and the component id from the event matches the one stored in the component
            arguments
                this (1,1) ic.core.ComponentBase
                name (1,1) string
                data % any
            end

            % subscribed
            if this.Subscriptions.isKey(name)
                cb = this.Subscriptions(name);
                cb(this, name, data);
                return;
            end
        end
    end

    methods (Access = protected, Hidden)
        function addPropReactivity(this, propertyName)
            % > ADDPROPREACTIVITY establishes a connection between the property of the component with the given name and its view counterpart. Reactive properties will notify the view when they change, and they will also change when the view does

            % add a listener to the property post-set
            this.ReactivePropListeners(propertyName) = ...
                addlistener(this, propertyName, "PostSet", ...
                @(src, ~) this.sendReactiveProperty(src.Name));
        end

        function addEventReactivity(this, eventName)
            % > ADDEVENTREACTIVITY subscribes to events from the view with the specified name, and re-notifies them as Matlab events
            camelName = ic.utils.toCamelCase("@event/" + eventName);
            this.subscribe(camelName, ...
                @(~,~,data) notify(this, eventName, ic.event.MEvent(data)));
        end
    end

    methods (Access = {?ic.Frame, ?ic.core.Component})
        function resolveAndUnsubscribe(this, promise, name, evtData)
            % > RESOLVEANDUNSUBSCRIBE is the callback executed whenever the view replies to a publish call. Resolves the promise with the new event data and stops listening to that event
            promise.resolve(ic.async.Resolution(evtData.success, evtData.data));
            this.Subscriptions(name) = [];
        end

        function sendReactiveProperty(this, propertyName)
            % > SENDREACTIVEPROPERTY publishes an event with the name of the property being changed to the view
            this.publish("@prop/" + propertyName, this.(propertyName));
        end

        function subscribeToReactiveProperty(this, propertyName)
            % > SUBSCRIBETOREACTIVEPROPERTIES subscribes to property changes from the view, and sets the component property when the view notifies the event
            camelName = ic.utils.toCamelCase("@prop/" + propertyName);
            this.subscribe(camelName, ...
                @(~,~,data) setValueSilently(propertyName, data))

            % nested function to avoid echoing the property change back to the view
            function setValueSilently(propName, value)
                task = onCleanup(@() reenableListener(propName));
                this.ReactivePropListeners(propName).Enabled = false;
                this.(propName) = value;
                function reenableListener(n)
                    this.ReactivePropListeners(n).Enabled = true;
                end
            end
        end

        function isReactiveMethod = isReactiveMethod(this, methodName)
            % > ISREACTIVEMETHOD returns whether the specified method is marked as reactive
            mc = meta.class.fromName(class(this));
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));
            % Convert method names to camelCase strings and compare
            camelNames = arrayfun(@(m) ic.utils.toCamelCase(m.Name), ...
                reactiveMethods);
            isReactiveMethod = any(camelNames == methodName);
        end
    end

    methods (Access = ?ic.core.Container)
        function definition = getComponentDefinition(this)
            % > GETCOMPONENTDEFINITION returns a struct with all reactive
            % properties, events, and methods for the component.
            % This is used when inserting the component into the view to
            % provide the JavaScript side with the component schema.

            mc = meta.class.fromName(class(this));

            % Gather reactive properties
            metaProps = mc.PropertyList;
            reactiveProps = metaProps(...
                strcmp({metaProps.Description}, "Reactive") & ...
                [metaProps.SetObservable]);

            props = struct('name', {}, 'value', {});
            for ii = 1:numel(reactiveProps)
                propName = reactiveProps(ii).Name;
                props(ii).name = ic.utils.toCamelCase(propName);
                props(ii).value = this.(propName);
            end

            % Gather reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(...
                strcmp({metaEvents.Description}, "Reactive"));

            events = struct('name', {});
            for jj = 1:numel(reactiveEvents)
                eventName = reactiveEvents(jj).Name;
                events(jj).name = ic.utils.toCamelCase(eventName);
            end

            % Gather reactive methods
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(...
                strcmp({metaMethods.Description}, "Reactive"));

            methods = struct('name', {});
            for kk = 1:numel(reactiveMethods)
                methodName = reactiveMethods(kk).Name;
                methods(kk).name = ic.utils.toCamelCase(methodName);
            end

            % Return combined definition
            definition = struct(...
                'id', this.ID, ...
                'type', string(class(this)));
            % Note: assign as cells to ensure JSON arrays (not objects)
            definition.props = num2cell(props);
            definition.events = num2cell(events);
            definition.methods = num2cell(methods);
        end
    end

end

function mustBeValidCssIdent(id)
% MUSTBEVALIDCSSIDENT validates that the given string is a valid CSS identifier.
%
% CSS identifiers (idents) allow: letters (A-Z, a-z), digits (0-9),
% hyphens (-), underscores (_), and Unicode characters >= U+00A0.
%
% Restrictions:
%   - Cannot be empty
%   - Cannot start with a digit
%   - Cannot start with a hyphen followed by a digit
%
% See: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/ident

    % Build pattern for valid CSS ident characters
    validChar = lettersPattern(1) | digitsPattern(1) | characterListPattern("-_");

    % Check non-empty
    if strlength(id) == 0
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID cannot be empty.");
    end

    % Check all characters are valid (letters, digits, hyphens, underscores)
    if ~matches(id, asManyOfPattern(validChar, 1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' contains invalid characters. " + ...
              "Valid characters are: letters, digits, hyphens, and underscores.", id);
    end

    % Cannot start with a digit
    if startsWith(id, digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a digit.", id);
    end

    % Cannot start with hyphen followed by digit
    if startsWith(id, "-" + digitsPattern(1))
        error("ic:core:ComponentBase:InvalidId", ...
              "Component ID '%s' cannot start with a hyphen followed by a digit.", id);
    end
end

classdef ComponentTest < matlab.uitest.TestCase
% COMPONENTBASETEST Tests ComponentBase reactivity and pub/sub system
%
%   Tests cover:
%     - Publish/subscribe mechanism
%     - Reactive property synchronization
%     - Reactive event forwarding
%     - Component definition introspection
%     - Event queuing when detached

    properties
        Figure
        Frame
    end

    methods (TestMethodSetup)
        function createFigure(testCase)
            testCase.Figure = uifigure('Visible', 'off');
            testCase.Frame = ic.Frame('Parent', testCase.Figure);
        end
    end

    methods (TestMethodTeardown)
        function clearFigure(testCase)
            if isvalid(testCase.Figure)
                delete(testCase.Figure);
            end
        end
    end

    methods (Test)
        function testSubscribeAndReceive(testCase)
            % Verify subscribe registers callback that fires on receive
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            received = [];
            function receiveData(name, data)
                received = struct('name', name, 'data', data);
            end
            comp.subscribe("testEvent", @(~, name, data) receiveData(name, data));

            % Manually trigger receive (simulating view response)
            comp.receive("testEvent", struct("value", 42));

            testCase.verifyEqual(received.name, "testEvent");
            testCase.verifyEqual(received.data.value, 42);
        end

        function testUnsubscribeRemovesCallback(testCase)
            % Verify unsubscribe stops callback from firing
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            callCount = 0;
            comp.subscribe("testEvent", @(~,~,~) evalin('caller', 'callCount = callCount + 1'));
            comp.unsubscribe("testEvent");

            % Should not throw, but callback should not fire
            comp.receive("testEvent", []);

            testCase.verifyEqual(callCount, 0);
        end

        function testPublishQueuesEventWhenDetached(testCase)
            % Verify publish stores events in queue when not attached
            comp = ic.core.Component(struct('ID', 'comp'));

            comp.publish("@myEvent", struct("x", 1));
            comp.publish("@myEvent", struct("x", 2));

            testCase.verifyLength(comp.Queue, 2);
            testCase.verifyEqual(comp.Queue(1).Name, "@myEvent");
            testCase.verifyEqual(comp.Queue(2).Data.x, 2);
        end

        function testPublishSendsEventWhenAttached(testCase)
            % Verify publish sends event through parent when attached
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            comp.publish("@customEvent", struct("payload", "test"));

            % Find the custom event in queue (after @insert)
            customEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@customEvent");

            testCase.verifyNotEmpty(customEvents);
            testCase.verifyEqual(customEvents(1).Data.payload, "test");
        end

        function testFlushSendsQueuedEvents(testCase)
            % Verify flush sends all queued events when attached
            container = ic.core.ComponentContainer(struct('ID', 'container'));
            child = ic.core.Component(struct('ID', 'child'));

            % Build subtree while detached
            container.addChild(child);
            child.publish("@event1", struct("n", 1));
            child.publish("@event2", struct("n", 2));

            % Attach - flush should happen automatically
            testCase.Frame.addChild(container);

            % Verify events reached the Frame's view queue
            names = [testCase.Frame.View.Queue.Name];
            testCase.verifyTrue(any(names == "@event1"));
            testCase.verifyTrue(any(names == "@event2"));
        end

        function testPublishReturnsPromise(testCase)
            % Verify publish returns a promise when output requested
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            promise = comp.publish("@fetchData", struct());

            testCase.verifyClass(promise, 'ic.async.Promise');
            testCase.verifyFalse(promise.isResolved());
        end

        function testPublishPromiseResolvesOnResponse(testCase)
            % Verify promise resolves when view responds
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            promise = comp.publish("@fetchData", struct());

            % Find the event ID to construct response
            fetchEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@fetchData");
            eventId = fetchEvents(end).Id;

            % Simulate view response
            comp.receive("@resp/" + eventId, struct("success", true, "data", 123));

            testCase.verifyTrue(promise.isResolved());
            testCase.verifyTrue(promise.get().Success);
            testCase.verifyEqual(promise.get().Data, 123);
        end
    end

    methods (Test)
        function testReactivePropertySendsEvent(testCase)
            % Verify changing reactive property sends @prop event
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);

            % Clear queue to isolate property change
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            comp.Value = 42;

            propEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@prop/value");

            testCase.verifyNotEmpty(propEvents);
            testCase.verifyEqual(propEvents(end).Data, 42);
        end

        function testReactivePropertyReceivesUpdate(testCase)
            % Verify receiving @prop event updates property without echo
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);

            % Simulate view updating the property
            comp.receive("@prop/value", 99);

            testCase.verifyEqual(comp.Value, 99);

            % Verify no echo event was sent back
            propEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@prop/value");
            testCase.verifyEmpty(propEvents);
        end
    end

    methods (Test)
        function testReactiveEventForwarding(testCase)
            % Verify JS events are forwarded as MATLAB events
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);

            eventData = [];
            function setEventData(evt)
                eventData = evt;
            end
            addlistener(comp, 'ButtonClicked', @(~, evt) setEventData(evt));

            % Simulate view sending event
            comp.receive("@event/buttonClicked", struct("button", "left"));

            testCase.verifyNotEmpty(eventData);
            testCase.verifyClass(eventData, 'ic.event.MEvent');
            testCase.verifyEqual(eventData.Data.button, "left");
        end
    end

    methods (Test)
        function testReactiveMethodPingCall(testCase)
            % Verify reactive method can be called from MATLAB
            comp = TestReactiveComponent(ID = "comp");

            out = comp.ping(123);

            testCase.verifyTrue(comp.Queue(end).Name == "ping");
            testCase.verifyInstanceOf(out, 'ic.async.Promise');
        end

        function testPublishPongErrors(testCase)
            % Verify publishing Pong errors (not a reactive method)
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);

            testCase.verifyError(@() comp.publish("pong", struct("value", 1)), ...
                "ic:core:ComponentBase:PublishReactiveMethod");
        end

        function testGetComponentDefinitionReturnsSchema(testCase)
            % Verify component definition includes props, events, methods, mixins
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);

            % Extract definition from the @insert event
            insertEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@insert");
            compInsert = insertEvents(...
                [insertEvents.Data.component.id] == "comp");
            definition = compInsert.Data.component;

            % Check reactive properties (cell array of structs)
            testCase.verifyNotEmpty(definition.props);
            allProps = [definition.props{:}];
            propNames = string({allProps.name});
            testCase.verifyTrue(any(propNames == "value"));

            % Check reactive events
            testCase.verifyNotEmpty(definition.events);
            allEvents = [definition.events{:}];
            eventNames = string({allEvents.name});
            testCase.verifyTrue(any(eventNames == "buttonClicked"));

            % Check reactive methods
            testCase.verifyNotEmpty(definition.methods);
            allMethods = [definition.methods{:}];
            methodNames = string({allMethods.name});
            testCase.verifyTrue(any(methodNames == "ping"));

            % Check mixins include expected capabilities
            testCase.verifyTrue(any(definition.mixins == "publishable"));
            testCase.verifyTrue(any(definition.mixins == "reactive"));
            testCase.verifyTrue(any(definition.mixins == "stylable"));
            testCase.verifyTrue(any(definition.mixins == "effectable"));
        end

        function testComponentContainerDefinitionIncludesTargets(testCase)
            % Verify ComponentContainer definition includes custom targets
            container = ic.core.ComponentContainer(struct('ID', 'container'));
            container.Targets = ["default", "left", "right"];
            testCase.Frame.addChild(container);

            % Check the @insert event data
            insertEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@insert");
            containerInsert = insertEvents(...
                [insertEvents.Data.component.id] == "container");

            % Targets is a reactive prop inside the props cell array
            allProps = [containerInsert.Data.component.props{:}];
            targetsProp = allProps(string({allProps.name}) == "targets");
            testCase.verifyNotEmpty(targetsProp);
            targets = targetsProp.value;
            testCase.verifyTrue(any(targets == "default"));
            testCase.verifyTrue(any(targets == "left"));
            testCase.verifyTrue(any(targets == "right"));
        end
    end

    methods (Test)
        function testComponentGeneratesUUID(testCase)
            % Verify component generates UUID when ID not provided
            comp1 = ic.core.Component();
            comp2 = ic.core.Component();

            testCase.verifyNotEmpty(comp1.ID);
            testCase.verifyNotEmpty(comp2.ID);
            testCase.verifyNotEqual(comp1.ID, comp2.ID);
        end

        function testComponentUsesProvidedID(testCase)
            % Verify component uses provided ID
            comp = ic.core.Component(struct('ID', 'myCustomID'));

            testCase.verifyEqual(comp.ID, "myCustomID");
        end
    end

    methods (Test)
        function testReceiveUnsubscribedEventNoError(testCase)
            % Verify receiving event with no subscriber doesn't error
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            % Should not throw
            comp.receive("unknownEvent", struct());

            testCase.verifyTrue(true);
        end
    end

    methods (Test)
        function testValidCssIdent(testCase)
            % Verify component accepts valid CSS identifier
            comp = ic.core.Component(struct('ID', 'my-component_123'));
            testCase.verifyEqual(comp.ID, "my-component_123");
        end

        function testInvalidCssIdent(testCase)
            % Verify component rejects invalid CSS identifier (starts with digit)
            testCase.verifyError(@() ic.core.Component(struct('ID', '123invalid')), ...
                "ic:core:ComponentBase:InvalidId");
        end
    end

    methods (Test)
        function testStyleSendsEvent(testCase)
            % Verify style() publishes @style event with CSS properties
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            comp.css.style(":host", "backgroundColor", "#ff0000", "padding", "10px");

            styleEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@style");
            testCase.verifyNotEmpty(styleEvents);
            testCase.verifyEqual(styleEvents(end).Data.selector, ":host");
            testCase.verifyEqual(styleEvents(end).Data.styles('background-color'), "#ff0000");
        end

        function testGetStyleReturnsStoredStyles(testCase)
            % Verify getStyle() returns previously set styles
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);

            comp.css.style(":host", "color", "blue");
            styles = comp.css.getStyle(":host");

            testCase.verifyEqual(styles.color, "blue");
        end

        function testClearStyleSendsEvent(testCase)
            % Verify clearStyle() publishes @clearStyle event
            comp = ic.core.Component(struct('ID', 'comp'));
            testCase.Frame.addChild(comp);
            comp.css.style(":host", "color", "red");
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            comp.css.clearStyle(":host");

            clearEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@clearStyle");
            testCase.verifyNotEmpty(clearEvents);
            testCase.verifyEqual(clearEvents(end).Data.selector, ":host");
        end
    end

    methods (Test)
        function testAddListenerPublishesListenEvent(testCase)
            % Verify addlistener on a reactive event publishes @listenEvent
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            addlistener(comp, 'ButtonClicked', @(~,~) []);

            listenEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@listenEvent");
            testCase.verifyNotEmpty(listenEvents);
            testCase.verifyEqual(listenEvents(end).Data, "buttonClicked");
        end

        function testSecondListenerDoesNotRepublish(testCase)
            % Verify adding a second listener for the same event does not
            % publish another @listenEvent
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);
            addlistener(comp, 'ButtonClicked', @(~,~) []);
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            addlistener(comp, 'ButtonClicked', @(~,~) []);

            testCase.verifyEmpty(testCase.Frame.View.Queue);
        end

        function testDeleteLastListenerPublishesUnlistenEvent(testCase)
            % Verify deleting the last listener publishes @unlistenEvent
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);
            l = addlistener(comp, 'ButtonClicked', @(~,~) []);
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            delete(l);

            unlistenEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@unlistenEvent");
            testCase.verifyNotEmpty(unlistenEvents);
            testCase.verifyEqual(unlistenEvents(end).Data, "buttonClicked");
        end

        function testDeleteOneOfTwoListenersDoesNotUnlisten(testCase)
            % Verify deleting one of two listeners does not publish
            % @unlistenEvent
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);
            l1 = addlistener(comp, 'ButtonClicked', @(~,~) []);
            l2 = addlistener(comp, 'ButtonClicked', @(~,~) []); %#ok<NASGU>
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            delete(l1);

            testCase.verifyEmpty(testCase.Frame.View.Queue);
        end

        function testAddListenerOnNonReactiveEventNoListenEvent(testCase)
            % Verify addlistener on a non-reactive event does not publish
            % @listenEvent (e.g. ObjectBeingDestroyed)
            comp = TestReactiveComponent(ID = "comp");
            testCase.Frame.addChild(comp);
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            addlistener(comp, 'ObjectBeingDestroyed', @(~,~) []);

            testCase.verifyEmpty(testCase.Frame.View.Queue);
        end
    end
end

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
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

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
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            callCount = 0;
            comp.subscribe("testEvent", @(~,~,~) evalin('caller', 'callCount = callCount + 1'));
            comp.unsubscribe("testEvent");

            % Should not throw, but callback should not fire
            comp.receive("testEvent", []);

            testCase.verifyEqual(callCount, 0);
        end

        function testPublishQueuesEventWhenDetached(testCase)
            % Verify publish stores events in queue when not attached
            comp = ic.core.Component("comp");

            comp.publish("myEvent", struct("x", 1));
            comp.publish("myEvent", struct("x", 2));

            testCase.verifyLength(comp.Queue, 2);
            testCase.verifyEqual(comp.Queue(1).Name, "myEvent");
            testCase.verifyEqual(comp.Queue(2).Data.x, 2);
        end

        function testPublishSendsEventWhenAttached(testCase)
            % Verify publish sends event through parent when attached
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            comp.publish("customEvent", struct("payload", "test"));

            % Find the custom event in queue (after @insert)
            customEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "customEvent");

            testCase.verifyNotEmpty(customEvents);
            testCase.verifyEqual(customEvents(1).Data.payload, "test");
        end

        function testFlushSendsQueuedEvents(testCase)
            % Verify flush sends all queued events when attached
            container = ic.core.ComponentContainer("container");
            child = ic.core.Component("child");

            % Build subtree while detached
            child.Parent = container;
            child.publish("event1", struct("n", 1));
            child.publish("event2", struct("n", 2));

            % Attach - flush should happen automatically
            container.Parent = testCase.Frame;

            % Verify events reached the Frame's view queue
            names = [testCase.Frame.View.Queue.Name];
            testCase.verifyTrue(any(names == "event1"));
            testCase.verifyTrue(any(names == "event2"));
        end

        function testPublishReturnsPromise(testCase)
            % Verify publish returns a promise when output requested
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            promise = comp.publish("fetchData", struct());

            testCase.verifyClass(promise, 'ic.async.Promise');
            testCase.verifyFalse(promise.isResolved());
        end

        function testPublishPromiseResolvesOnResponse(testCase)
            % Verify promise resolves when view responds
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            promise = comp.publish("fetchData", struct());

            % Find the event ID to construct response
            fetchEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "fetchData");
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
            comp = TestReactiveComponent("comp");
            comp.Parent = testCase.Frame;

            % Clear queue to isolate property change
            testCase.Frame.View.Queue = ic.event.JsEvent.empty();

            comp.Value = 42;

            propEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@prop/Value");

            testCase.verifyNotEmpty(propEvents);
            testCase.verifyEqual(propEvents(end).Data.value, 42);
        end

        function testReactivePropertyReceivesUpdate(testCase)
            % Verify receiving @prop event updates property without echo
            comp = TestReactiveComponent("comp");
            comp.Parent = testCase.Frame;

            % Simulate view updating the property
            comp.receive("@prop/Value", struct("name", "Value", "value", 99));

            testCase.verifyEqual(comp.Value, 99);

            % Verify no echo event was sent back
            propEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@prop/Value");
            testCase.verifyEmpty(propEvents);
        end
    end

    methods (Test)
        function testReactiveEventForwarding(testCase)
            % Verify JS events are forwarded as MATLAB events
            comp = TestReactiveComponent("comp");
            comp.Parent = testCase.Frame;

            eventData = [];
            function setEventData(evt)
                eventData = evt;
            end
            addlistener(comp, 'ButtonClicked', @(~, evt) setEventData(evt));

            % Simulate view sending event
            comp.receive("@event/ButtonClicked", struct("button", "left"));

            testCase.verifyNotEmpty(eventData);
            testCase.verifyClass(eventData, 'ic.event.MEvent');
            testCase.verifyEqual(eventData.Data.button, "left");
        end
    end

    methods (Test)
        function testGetComponentDefinitionReturnsSchema(testCase)
            % Verify getComponentDefinition returns complete schema
            comp = TestReactiveComponent("comp");

            % Access protected method via subclass exposure
            definition = comp.getDefinitionForTest();

            % Check reactive properties
            testCase.verifyNotEmpty(definition.props);
            propNames = {definition.props.name};
            testCase.verifyTrue(any(strcmp(propNames, 'Value')));

            % Check reactive events
            testCase.verifyNotEmpty(definition.events);
            eventNames = {definition.events.name};
            testCase.verifyTrue(any(strcmp(eventNames, 'ButtonClicked')));

            % Check default targets
            testCase.verifyEqual(definition.targets, {"default"});
        end

        function testComponentContainerDefinitionIncludesTargets(testCase)
            % Verify ComponentContainer definition includes custom targets
            container = ic.core.ComponentContainer("container");
            container.Targets = ["left", "right"];
            container.Parent = testCase.Frame;

            % Check the @insert event data
            insertEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@insert");
            containerInsert = insertEvents(...
                [insertEvents.Data.component.id] == "container");

            targets = [containerInsert.Data.component.targets{:}];
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
            comp = ic.core.Component("myCustomID");

            testCase.verifyEqual(comp.ID, "myCustomID");
        end
    end

    methods (Test)
        function testReceiveUnsubscribedEventNoError(testCase)
            % Verify receiving event with no subscriber doesn't error
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            % Should not throw
            comp.receive("unknownEvent", struct());

            testCase.verifyTrue(true);
        end
    end
end

classdef FrameTest < matlab.uitest.TestCase
    % FRAMETEST tests the ic.Frame class functionality
    %
    % Tests include:
    %   - Frame initialization
    %   - Adding Frame to a uifigure
    %   - Send and receive events through the View

    properties (TestParameter)
        % Test different position values
        Position = {[100 100 400 300], [0 0 200 200], [50 50 500 400]}
    end

    properties
        Figure matlab.ui.Figure
    end

    methods (TestMethodSetup)
        function createFigure(testCase)
            % Create a fresh figure for each test
            testCase.Figure = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(testCase.Figure));
        end
    end

    methods (TestMethodTeardown)
        function clearFigure(testCase)
            % Clear the figure after each test
            delete(testCase.Figure);
        end
    end

    methods (Test)
        function testFrameConstruction(testCase)
            % Test that Frame can be constructed without arguments
            frame = ic.Frame();
            testCase.addTeardown(@() delete(frame));

            testCase.verifyClass(frame, 'ic.Frame');
            testCase.verifyNotEmpty(frame.ID);
            testCase.verifyEqual(frame.ID, "@ic.frame");
        end

        function testFrameWithParent(testCase)
            % Test that Frame can be constructed with a Parent argument
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            testCase.verifyClass(frame, 'ic.Frame');
            testCase.verifyEqual(frame.UIParent, testCase.Figure);
            testCase.verifyClass(frame.View, 'ic.core.View');
        end


        function testAddFrameToGridLayout(testCase)
            % Test that Frame can be added to a grid layout
            grid = uigridlayout(testCase.Figure, [1 1]);
            frame = ic.Frame('Parent', grid);
            testCase.addTeardown(@() delete(frame));

            testCase.verifyEqual(frame.UIParent, grid);
        end

        function testFrameWithPosition(testCase, Position)
            % Test that Frame can be constructed with Position argument
            frame = ic.Frame('Parent', testCase.Figure, 'Position', Position);
            testCase.addTeardown(@() delete(frame));

            testCase.verifyEqual(frame.Position, Position);
        end

        function testFrameVisibility(testCase)
            % Test that Frame visibility can be set
            frame = ic.Frame('Parent', testCase.Figure, 'Visible', 'off');
            testCase.addTeardown(@() delete(frame));

            testCase.verifyEqual(frame.Visible, matlab.lang.OnOffSwitchState.off);

            frame.Visible = 'on';
            testCase.verifyEqual(frame.Visible, matlab.lang.OnOffSwitchState.on);
        end

        function testFrameUnits(testCase)
            % Test that Frame units property works
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            frame.Units = 'normalized';
            testCase.verifyEqual(frame.Units, "normalized");
        end
    end


    % Test: Send/Receive through View
    methods (Test)
        function testFrameCanPublishEvent(testCase)
            % Test that Frame can publish events to the View
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            % Publishing should not throw an error
            testCase.verifyWarningFree(@() frame.publish("test-event", struct('value', 42)));
        end

        function testFrameCanSubscribeToEvent(testCase)
            % Test that Frame can subscribe to events
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            received = false;
            frame.subscribe("test-event", @(~,~,~) assignin('caller', 'received', true));

            testCase.verifyTrue(frame.Subscriptions.isKey("test-event"));
        end

        function testFrameCanUnsubscribeFromEvent(testCase)
            % Test that Frame can unsubscribe from events
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            frame.subscribe("test-event", @(~,~,~) disp('test'));
            testCase.verifyTrue(frame.Subscriptions.isKey("test-event"));

            frame.unsubscribe("test-event");
            testCase.verifyFalse(frame.Subscriptions.isKey("test-event"));
        end

        function testViewQueueReceivesEvents(testCase)
            % Test that events published from Frame arrive in View queue
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            % Publish an event
            frame.publish("queue-test", struct('data', 'test'));

            % The event should be in the View's queue
            testCase.verifyGreaterThanOrEqual(numel(frame.View.Queue), 1);
        end

        function testFrameFindReturnsItself(testCase)
            % Test that find returns the Frame when predicate matches
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            found = frame.find(@(c) c.ID == "@ic.frame");
            testCase.verifyEqual(found, frame);
        end

        function testFrameFindReturnsEmptyWhenNoMatch(testCase)
            % Test that find returns empty when no component matches
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));

            found = frame.find(@(c) c.ID == "nonexistent-id");
            testCase.verifyEmpty(found);
        end
    end

    methods (Test)
        function testFrameDeleteCleansUp(testCase)
            % Test that deleting Frame properly cleans up
            frame = ic.Frame('Parent', testCase.Figure);
            view = frame.View;

            delete(frame);

            testCase.verifyFalse(isvalid(frame));
            testCase.verifyFalse(isvalid(view));
        end

        function testFrameViewDeletedOnFigureClose(testCase)
            % Test that closing the figure deletes the Frame's View
            frame = ic.Frame('Parent', testCase.Figure);
            view = frame.View;

            close(testCase.Figure);

            testCase.verifyFalse(isvalid(view));
        end
    end
end

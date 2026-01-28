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
        Figure % matlab.ui.Figure
    end

    methods (TestMethodSetup)
        function createFigure(testCase)
            % Create a fresh figure for each test
            testCase.Figure = uifigure('Visible', 'off');
        end
    end

    methods (TestMethodTeardown)
        function clearFigure(testCase)
            % Clear the figure after each test
            if isvalid(testCase.Figure)
                delete(testCase.Figure);
            end
        end
    end

    methods (Test)
        function testFrameConstruction(testCase)
            % Test that Frame can be constructed without arguments
            frame = ic.Frame();
            testCase.addTeardown(@() delete(frame.UIParent));

            testCase.verifyClass(frame, 'ic.Frame');
            testCase.verifyNotEmpty(frame.ID);
            testCase.verifyEqual(frame.ID, "ic-frame");
        end

        function testAddFrameToFigure(testCase)
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
    end


    methods (Test)
        function testFrameDeleteCleansUp(testCase)
            % Test that deleting Frame properly cleans up its View
            frame = ic.Frame('Parent', testCase.Figure);
            view = frame.View;

            delete(frame);

            testCase.verifyFalse(isvalid(frame));
            testCase.verifyFalse(isvalid(view));
        end

        function testFrameViewDeletedOnFigureClose(testCase)
            % Test that closing the figure deletes the Frame's View and Frame
            frame = ic.Frame('Parent', testCase.Figure);
            view = frame.View;

            close(testCase.Figure);

            testCase.verifyFalse(isvalid(view));
            testCase.verifyFalse(isvalid(frame));
        end
    end

    methods (Test)
        function testThemeUpdatesProperty(testCase)
            % Verify theme() updates the Theme property and triggers sync
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));
            frame.View.Queue = ic.event.JsEvent.empty();

            frame.theme("primary", "#123456");

            testCase.verifyEqual(frame.Theme.Primary(1), "#123456");
            propEvents = frame.View.Queue(...
                [frame.View.Queue.Name] == "@prop/theme");
            testCase.verifyNotEmpty(propEvents);
        end

        function testGlobalStyleSendsEvent(testCase)
            % Verify globalStyle() publishes @globalStyle event
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));
            frame.View.Queue = ic.event.JsEvent.empty();

            frame.globalStyle("ic.Button", ":host", "padding", "8px");

            styleEvents = frame.View.Queue(...
                [frame.View.Queue.Name] == "@globalStyle");
            testCase.verifyNotEmpty(styleEvents);
            testCase.verifyEqual(styleEvents(end).Data.type, "ic.Button");
            testCase.verifyEqual(styleEvents(end).Data.selector, ":host");
        end

        function testClearAllGlobalStylesSendsEvent(testCase)
            % Verify clearAllGlobalStyles() publishes event
            frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(frame));
            frame.globalStyle("ic.Button", ":host", "color", "red");
            frame.View.Queue = ic.event.JsEvent.empty();

            frame.clearAllGlobalStyles();

            clearEvents = frame.View.Queue(...
                [frame.View.Queue.Name] == "@clearAllGlobalStyles");
            testCase.verifyNotEmpty(clearEvents);
        end
    end
end

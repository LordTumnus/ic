classdef JsEventTest < matlab.unittest.TestCase
% JSEVENTTEST Tests the JsEvent class for JS communication
%
%   Tests cover:
%     - Event construction
%     - JSON serialization
%     - Unique ID generation
%     - Heterogeneous array behavior

    methods (Test)
        function testEventConstruction(testCase)
            % Verify event stores componentId, name, and data
            evt = ic.event.JsEvent("comp1", "click", struct("x", 10));

            testCase.verifyEqual(evt.ComponentID, "comp1");
            testCase.verifyEqual(evt.Name, "click");
            testCase.verifyEqual(evt.Data.x, 10);
        end

        function testEventHasUniqueId(testCase)
            % Verify each event gets a unique ID
            evt1 = ic.event.JsEvent("c", "e", []);
            evt2 = ic.event.JsEvent("c", "e", []);

            testCase.verifyNotEmpty(evt1.Id);
            testCase.verifyNotEmpty(evt2.Id);
            testCase.verifyNotEqual(evt1.Id, evt2.Id);
        end

        function testEventIdIsImmutable(testCase)
            % Verify event ID cannot be changed after construction
            evt = ic.event.JsEvent("c", "e", []);

            function setId()
                evt.Id = "newId";
            end

            testCase.verifyError(@setId, 'MATLAB:class:SetProhibited');
        end
    end

    methods (Test)
        function testJsonEncodeBasic(testCase)
            % Verify jsonencode produces valid JSON structure
            evt = ic.event.JsEvent("myComp", "myEvent", struct("val", 42));

            json = jsonencode(evt);
            decoded = jsondecode(json);

            % jsondecode returns char, convert to string for comparison
            testCase.verifyEqual(string(decoded.component), "myComp");
            testCase.verifyEqual(string(decoded.name), "myEvent");
            testCase.verifyEqual(decoded.data.val, 42);
            testCase.verifyEqual(string(decoded.id), evt.Id);
        end

        function testJsonEncodeWithArray(testCase)
            % Verify jsonencode handles array data
            evt = ic.event.JsEvent("c", "e", struct("arr", [1 2 3]));

            json = jsonencode(evt);
            decoded = jsondecode(json);

            testCase.verifyEqual(decoded.data.arr, [1; 2; 3]); % MATLAB decodes as column
        end

        function testJsonEncodeWithNestedStruct(testCase)
            % Verify jsonencode handles nested structures
            data = struct("outer", struct("inner", "value"));
            evt = ic.event.JsEvent("c", "e", data);

            json = jsonencode(evt);
            decoded = jsondecode(json);

            testCase.verifyEqual(string(decoded.data.outer.inner), "value");
        end

        function testJsonEncodeWithEmptyData(testCase)
            % Verify jsonencode handles empty data
            evt = ic.event.JsEvent("c", "e", []);

            json = jsonencode(evt);
            decoded = jsondecode(json);

            testCase.verifyEmpty(decoded.data);
        end

        function testJsonEncodeWithStringData(testCase)
            % Verify jsonencode handles string data
            evt = ic.event.JsEvent("c", "e", "simple string");

            json = jsonencode(evt);
            decoded = jsondecode(json);

            testCase.verifyEqual(string(decoded.data), "simple string");
        end
    end

    methods (Test)
        function testHeterogeneousArray(testCase)
            % Verify JsEvents can be stored in heterogeneous arrays
            evt1 = ic.event.JsEvent("c1", "e1", 1);
            evt2 = ic.event.JsEvent("c2", "e2", 2);

            arr = [evt1, evt2];

            testCase.verifyLength(arr, 2);
            testCase.verifyEqual(arr(1).ComponentID, "c1");
            testCase.verifyEqual(arr(2).ComponentID, "c2");
        end

        function testEmptyArray(testCase)
            % Verify empty JsEvent array can be created
            arr = ic.event.JsEvent.empty();

            testCase.verifyEmpty(arr);
            testCase.verifyClass(arr, 'ic.event.JsEvent');
        end

        function testArrayConcatenation(testCase)
            % Verify events can be appended to array
            arr = ic.event.JsEvent.empty();
            evt = ic.event.JsEvent("c", "e", []);

            arr(end+1) = evt;

            testCase.verifyLength(arr, 1);
        end

        function testJsonEncodeArray(testCase)
            % Verify jsonencode produces a valid JSON array for multiple events
            evt1 = ic.event.JsEvent("c1", "click", struct("x", 10));
            evt2 = ic.event.JsEvent("c2", "hover", "hello");
            arr = [evt1, evt2];

            json = jsonencode(arr);
            decoded = jsondecode(json);

            testCase.verifyLength(decoded, 2);
            testCase.verifyEqual(string(decoded(1).component), "c1");
            testCase.verifyEqual(string(decoded(1).name), "click");
            testCase.verifyEqual(decoded(1).data.x, 10);
            testCase.verifyEqual(string(decoded(2).component), "c2");
            testCase.verifyEqual(string(decoded(2).data), "hello");
        end
    end

    methods (Test)
        function testMEventConstruction(testCase)
            % Verify MEvent wraps data for MATLAB event system
            data = struct("button", "left", "x", 100);
            mevt = ic.event.MEvent(data);

            testCase.verifyClass(mevt, 'ic.event.MEvent');
            testCase.verifyTrue(isa(mevt, 'event.EventData'));
            testCase.verifyEqual(mevt.Data.button, "left");
            testCase.verifyEqual(mevt.Data.x, 100);
        end
    end
end

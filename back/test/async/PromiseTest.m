classdef PromiseTest < matlab.unittest.TestCase
% PROMISETEST Tests the Promise async coordination system
%
%   Tests cover:
%     - Basic resolve and get
%     - isResolved state tracking
%     - then() chaining
%     - Promise.all() aggregation
%     - Promise resolving to another promise
%     - wait() blocking behavior

    methods (Test)
        function testNewPromiseIsUnresolved(testCase)
            % Verify new promise starts unresolved
            p = ic.async.Promise();

            testCase.verifyFalse(p.isResolved());
            testCase.verifyEmpty(p.get());
        end

        function testResolveChangesState(testCase)
            % Verify resolve marks promise as fulfilled
            p = ic.async.Promise();

            p.resolve(42);

            testCase.verifyTrue(p.isResolved());
        end

        function testGetReturnsResolvedValue(testCase)
            % Verify get returns the resolved value
            p = ic.async.Promise();

            p.resolve("hello");

            testCase.verifyEqual(p.get(), "hello");
        end

        function testResolveWithStruct(testCase)
            % Verify promise can resolve to struct
            p = ic.async.Promise();
            data = struct("x", 1, "y", [1 2 3]);

            p.resolve(data);

            testCase.verifyEqual(p.get().x, 1);
            testCase.verifyEqual(p.get().y, [1 2 3]);
        end

    end

    methods (Test)
        function testThenReturnsNewPromise(testCase)
            % Verify then() returns a new promise
            p1 = ic.async.Promise();

            p2 = p1.then(@(x) x + 1);

            testCase.verifyClass(p2, 'ic.async.Promise');
            testCase.verifyFalse(p1 == p2);
        end

        function testThenExecutesAfterResolve(testCase)
            % Verify then callback executes when original resolves
            p1 = ic.async.Promise();
            p2 = p1.then(@(x) x * 2);

            testCase.verifyFalse(p2.isResolved());

            p1.resolve(5);

            testCase.verifyTrue(p2.isResolved());
            testCase.verifyEqual(p2.get(), 10);
        end

        function testThenChaining(testCase)
            % Verify multiple then() calls can be chained
            p = ic.async.Promise();

            result = p.then(@(x) x + 1) ...
                      .then(@(x) x * 2) ...
                      .then(@(x) x - 3);

            p.resolve(5);

            % (5 + 1) * 2 - 3 = 9
            testCase.verifyEqual(result.get(), 9);
        end

        function testThenWithVoidCallback(testCase)
            % Verify then with void callback returns original value
            p1 = ic.async.Promise();
            sideEffect = 0;

            function voidCallback(~)
                sideEffect = 1;
            end

            p2 = p1.then(@(~) voidCallback());

            p1.resolve(42);

            testCase.verifyEqual(sideEffect, 1);
            testCase.verifyEqual(p2.get(), 42);
        end

        function testThenOnAlreadyResolved(testCase)
            % Verify then() works on already-resolved promise
            p1 = ic.async.Promise();
            p1.resolve(10);

            p2 = p1.then(@(x) x + 5);

            % Need to trigger the listener (in real use, drawnow would do this)
            drawnow;

            testCase.verifyTrue(p2.isResolved());
            testCase.verifyEqual(p2.get(), 15);
        end
    end

    methods (Test)
        function testResolveWithPromiseChains(testCase)
            % Verify resolving with another promise chains them
            p1 = ic.async.Promise();
            p2 = ic.async.Promise();

            p1.resolve(p2);

            % p1 should not be resolved until p2 is
            testCase.verifyFalse(p1.isResolved());

            p2.resolve("final value");

            testCase.verifyTrue(p1.isResolved());
            testCase.verifyEqual(p1.get(), "final value");
        end

        function testDeepPromiseChaining(testCase)
            % Verify multiple levels of promise chaining
            p1 = ic.async.Promise();
            p2 = ic.async.Promise();
            p3 = ic.async.Promise();

            p1.resolve(p2);
            p2.resolve(p3);

            testCase.verifyFalse(p1.isResolved());
            testCase.verifyFalse(p2.isResolved());

            p3.resolve(999);

            testCase.verifyTrue(p1.isResolved());
            testCase.verifyTrue(p2.isResolved());
            testCase.verifyEqual(p1.get(), 999);
        end
    end

    methods (Test)
        function testAllWithSinglePromise(testCase)
            % Verify Promise.all with single promise
            p = ic.async.Promise();
            pAll = ic.async.Promise.all(p);

            testCase.verifyFalse(pAll.isResolved());

            p.resolve(1);

            testCase.verifyTrue(pAll.isResolved());
            testCase.verifyEqual(pAll.get(), {1});
        end

        function testAllWithMultiplePromises(testCase)
            % Verify Promise.all waits for all promises
            p1 = ic.async.Promise();
            p2 = ic.async.Promise();
            p3 = ic.async.Promise();

            pAll = ic.async.Promise.all(p1, p2, p3);

            p1.resolve("a");
            testCase.verifyFalse(pAll.isResolved());

            p2.resolve("b");
            testCase.verifyFalse(pAll.isResolved());

            p3.resolve("c");
            testCase.verifyTrue(pAll.isResolved());

            testCase.verifyEqual(pAll.get(), {"a", "b", "c"});
        end

        function testAllResolvesInAnyOrder(testCase)
            % Verify Promise.all works regardless of resolution order
            p1 = ic.async.Promise();
            p2 = ic.async.Promise();
            p3 = ic.async.Promise();

            pAll = ic.async.Promise.all(p1, p2, p3);

            % Resolve in reverse order
            p3.resolve(3);
            p1.resolve(1);
            p2.resolve(2);

            testCase.verifyTrue(pAll.isResolved());
            % Results should be in original order
            testCase.verifyEqual(pAll.get(), {1, 2, 3});
        end

        function testAllWithAlreadyResolvedPromises(testCase)
            % Verify Promise.all with pre-resolved promises
            p1 = ic.async.Promise();
            p2 = ic.async.Promise();

            p1.resolve(10);
            p2.resolve(20);

            pAll = ic.async.Promise.all(p1, p2);

            % May need drawnow to trigger listeners
            drawnow;

            testCase.verifyTrue(pAll.isResolved());
            testCase.verifyEqual(pAll.get(), {10, 20});
        end
    end

    methods (Test)
        function testWaitReturnsImmediatelyWhenResolved(testCase)
            % Verify wait returns immediately for resolved promise
            p = ic.async.Promise();
            p.resolve(42);

            tic;
            p.wait(1, 0.1);
            elapsed = toc;

            testCase.verifyLessThan(elapsed, 0.2);
        end

        function testWaitBlocksUntilResolved(testCase)
            % Verify wait blocks until promise resolves
            p = ic.async.Promise();

            % Use a timer to resolve after delay
            t = timer('ExecutionMode', 'singleShot', ...
                'StartDelay', 0.1, ...
                'TimerFcn', @(~,~) p.resolve("done"));
            start(t);
            testCase.addTeardown(@() delete(t));

            tic;
            p.wait(2, 0.05);
            elapsed = toc;

            testCase.verifyTrue(p.isResolved());
            testCase.verifyGreaterThan(elapsed, 0.05);
            testCase.verifyLessThan(elapsed, 1);
        end

        function testWaitTimesOut(testCase)
            % Verify wait respects maxTime timeout
            p = ic.async.Promise(); % Never resolved

            tic;
            p.wait(0.2, 0.05);
            elapsed = toc;

            testCase.verifyFalse(p.isResolved());
            testCase.verifyGreaterThanOrEqual(elapsed, 0.2);
            testCase.verifyLessThan(elapsed, 0.5);
        end

        function testWaitReturnsSelf(testCase)
            % Verify wait returns the promise for chaining
            p = ic.async.Promise();
            p.resolve(1);

            result = p.wait();

            testCase.verifyEqual(result, p);
        end
    end

    methods (Test)
        function testResolutionConstruction(testCase)
            % Verify Resolution object construction
            res = ic.async.Resolution(true, struct("data", 123));

            testCase.verifyTrue(res.Success);
            testCase.verifyEqual(res.Data.data, 123);
        end

        function testResolutionFailure(testCase)
            % Verify Resolution can represent failure
            res = ic.async.Resolution(false, "error message");

            testCase.verifyFalse(res.Success);
            testCase.verifyEqual(res.Data, "error message");
        end
    end
end

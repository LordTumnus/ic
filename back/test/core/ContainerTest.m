classdef ContainerTest < matlab.uitest.TestCase
    % CONTAINERTEST Tests component parent-child relationships
    %
    % Covers:
    %   - Attaching components to Frame
    %   - Building subtrees and attaching to Frame
    %   - Removing and detaching components
    %   - Re-parenting components between containers

    properties
        Figure
        Frame
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.Figure = uifigure('Visible', 'off');
            testCase.Frame = ic.Frame('Parent', testCase.Figure);
            testCase.addTeardown(@() delete(testCase.Figure));
        end
    end

    %% Attach Component to Frame
    methods (Test)
        function testAttachComponentToFrame(testCase)
            % Test that a Component can be attached to a Frame
            comp = ic.core.Component();
            testCase.addTeardown(@() testCase.safeDelete(comp));

            comp.Parent = testCase.Frame;

            testCase.verifyEqual(comp.Parent, testCase.Frame);
            testCase.verifyTrue(comp.isAttached());
            testCase.verifyLength(testCase.Frame.Children, 1);
        end

        function testAttachComponentContainerToFrame(testCase)
            % Test that a ComponentContainer can be attached to a Frame
            container = ic.core.ComponentContainer("container");
            testCase.addTeardown(@() testCase.safeDelete(container));

            container.Parent = testCase.Frame;

            testCase.verifyEqual(container.Parent, testCase.Frame);
            testCase.verifyTrue(container.isAttached());
            testCase.verifyLength(testCase.Frame.Children, 1);
        end

        function testAttachedComponentInRegistry(testCase)
            % Test that an attached component is registered in Frame registry
            comp = ic.core.Component("test-id");
            testCase.addTeardown(@() testCase.safeDelete(comp));

            comp.Parent = testCase.Frame;

            testCase.verifyTrue(testCase.Frame.Registry.isKey("test-id"));
            testCase.verifyEqual(testCase.Frame.Registry("test-id"), comp);
        end

        function testDetachedComponentNotInRegistry(testCase)
            % Test that a component without parent is not in registry
            comp = ic.core.Component();
            testCase.addTeardown(@() testCase.safeDelete(comp));

            testCase.verifyFalse(comp.isAttached());
            testCase.verifyEmpty(comp.Parent);
        end
    end

    %% Build Subtrees and Attach to Frame
    methods (Test)
        function testBuildSubtreeBeforeAttach(testCase)
            % Test that subtree can be built before attaching to Frame
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.Component("c2");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));

            c2.Parent = c1;

            % Child is attached to parent
            testCase.verifyTrue(c2.isAttached());
            % Root not attached yet (no Frame)
            testCase.verifyFalse(c1.isAttached());
            % Registry should be empty
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
        end

        function testAttachSubtreeToFrame(testCase)
            % Test that attaching subtree root registers all descendants
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(c3));

            c2.Parent = c1;
            c3.Parent = c2;
            c1.Parent = testCase.Frame;

            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c3"));
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
        end

        function testAttachComponentToAttachedContainer(testCase)
            % Test adding a component to an already-attached container
            container = ic.core.ComponentContainer("container");
            testCase.addTeardown(@() testCase.safeDelete(container));
            container.Parent = testCase.Frame;

            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(child));
            child.Parent = container;

            testCase.verifyTrue(testCase.Frame.Registry.isKey("container"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("child"));
            testCase.verifyLength(container.Children, 1);
        end

        function testAttachSubtreeToAttachedContainer(testCase)
            % Test attaching a pre-built subtree to an attached container
            c1 = ic.core.ComponentContainer("c1");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            c1.Parent = testCase.Frame;

            % Build detached subtree
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(c3));
            c3.Parent = c2;

            % Attach subtree
            c2.Parent = c1;

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c3"));
        end
    end

    %% Remove Components
    methods (Test)
        function testDetachComponentFromFrame(testCase)
            % Test that setting Parent to empty detaches from Frame
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            comp.Parent = [];

            testCase.verifyFalse(comp.isAttached());
            testCase.verifyEmpty(testCase.Frame.Children);
            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));
        end

        function testDeleteComponentFromFrame(testCase)
            % Test that deleting a component removes it from Frame
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            delete(comp);

            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));
            testCase.verifyEmpty(testCase.Frame.Children);
        end

        function testDetachSubtreeFromFrame(testCase)
            % Test that detaching subtree root deregisters all descendants
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.Component("c2");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));

            c2.Parent = c1;
            c1.Parent = testCase.Frame;
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 2);

            c1.Parent = [];

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
        end

        function testDetachMiddleNodeFromSubtree(testCase)
            % Test that detaching middle node deregisters its descendants
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(c3));

            c2.Parent = c1;
            c3.Parent = c2;
            c1.Parent = testCase.Frame;

            c2.Parent = [];

            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c3"));
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 1);
        end

        function testDeleteMiddleNodeFromSubtree(testCase)
            % Test that deleting middle node deregisters its descendants
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c3));

            c2.Parent = c1;
            c3.Parent = c2;
            c1.Parent = testCase.Frame;

            delete(c2);

            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c3"));
        end
    end

    %% Reparent Components
    methods (Test)
        function testReparentBetweenContainers(testCase)
            % Test moving a component from one container to another
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(child));

            c1.Parent = testCase.Frame;
            c2.Parent = testCase.Frame;
            child.Parent = c1;
            testCase.verifyLength(c1.Children, 1);

            child.Parent = c2;

            testCase.verifyLength(c1.Children, 0);
            testCase.verifyLength(c2.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("child"));
        end

        function testReparentFromFrameToContainer(testCase)
            % Test moving a component from Frame to a container
            container = ic.core.ComponentContainer("container");
            comp = ic.core.Component("comp");
            testCase.addTeardown(@() testCase.safeDelete(container));
            testCase.addTeardown(@() testCase.safeDelete(comp));

            container.Parent = testCase.Frame;
            comp.Parent = testCase.Frame;
            testCase.verifyLength(testCase.Frame.Children, 2);

            comp.Parent = container;

            testCase.verifyLength(testCase.Frame.Children, 1);
            testCase.verifyLength(container.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("comp"));
        end

        function testReparentSubtreeBetweenContainers(testCase)
            % Test moving an entire subtree between containers
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.ComponentContainer("c3");
            c4 = ic.core.Component("c4");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(c3));
            testCase.addTeardown(@() testCase.safeDelete(c4));

            c1.Parent = testCase.Frame;
            c2.Parent = testCase.Frame;
            c3.Parent = c1;
            c4.Parent = c3;

            c3.Parent = c2;

            testCase.verifyLength(c1.Children, 0);
            testCase.verifyLength(c2.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c3"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c4"));
        end

        function testReparentToDetachedContainer(testCase)
            % Test that moving to detached container deregisters from Frame
            c1 = ic.core.ComponentContainer("c1");
            comp = ic.core.Component("comp");
            detached = ic.core.ComponentContainer("detached");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(comp));
            testCase.addTeardown(@() testCase.safeDelete(detached));

            c1.Parent = testCase.Frame;
            comp.Parent = c1;

            comp.Parent = detached;

            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));
            testCase.verifyTrue(comp.isAttached()); % attached to detached container
            testCase.verifyLength(c1.Children, 0);
        end
    end

    %% Helper Methods
    methods (Access = private)
        function safeDelete(~, obj)
            if isvalid(obj)
                delete(obj);
            end
        end
    end
end

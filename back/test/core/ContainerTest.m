classdef ContainerTest < matlab.uitest.TestCase
    % CONTAINERTEST Tests component parent-child relationships
    %
    % Tests cover:
    %   - Adding components to Frame
    %   - Building and attaching subtrees
    %   - Removing components
    %   - Reparenting components

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
        function testAddComponentToFrame(testCase)
            % Verify Component attaches to Frame and registers
            comp = ic.core.Component("comp");
            testCase.addTeardown(@() testCase.safeDelete(comp));

            comp.Parent = testCase.Frame;

            testCase.verifyEqual(comp.Parent, testCase.Frame);
            testCase.verifyTrue(comp.isAttached());
            testCase.verifyTrue(testCase.Frame.Registry.isKey("comp"));
        end


        function testUnattachedComponentNotInRegistry(testCase)
            % Verify unattached component is not registered
            comp = ic.core.Component("comp");
            testCase.addTeardown(@() testCase.safeDelete(comp));

            testCase.verifyFalse(comp.isAttached());
            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));
        end
    end

    methods (Test)
        function testBuildSubtreeThenAttach(testCase)
            % Verify subtree built before attaching to Frame
            container = ic.core.ComponentContainer("container");
            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(container));
            testCase.addTeardown(@() testCase.safeDelete(child));

            child.Parent = container;

            testCase.verifyTrue(child.isAttached());
            testCase.verifyFalse(container.isAttached());
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
        end

        function testAttachSubtreeRegistersAll(testCase)
            % Verify attaching subtree root registers all descendants
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(c3));

            % define subtree
            c2.Parent = c1;
            c3.Parent = c2;
            % attach to Frame
            c1.Parent = testCase.Frame;

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c3"));
        end

        function testAddComponentToAttachedContainer(testCase)
            % Verify adding child to already-attached container
            container = ic.core.ComponentContainer("container");
            testCase.addTeardown(@() testCase.safeDelete(container));
            container.Parent = testCase.Frame;
            testCase.assertTrue(testCase.Frame.Registry.isKey("container"));

            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(child));
            child.Parent = container;

            testCase.verifyTrue(testCase.Frame.Registry.isKey("child"));
            testCase.verifyLength(container.Children, 1);
        end

        function testAddSubtreeToAttachedContainer(testCase)
            % Verify attaching pre-built subtree to attached container
            root = ic.core.ComponentContainer("root");
            testCase.addTeardown(@() testCase.safeDelete(root));
            root.Parent = testCase.Frame;
            testCase.assertTrue(testCase.Frame.Registry.isKey("root"));

            subtree = ic.core.ComponentContainer("subtree");
            leaf = ic.core.Component("leaf");
            testCase.addTeardown(@() testCase.safeDelete(subtree));
            testCase.addTeardown(@() testCase.safeDelete(leaf));
            leaf.Parent = subtree;

            subtree.Parent = root;

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
        end
    end

    methods (Test)
        function testDetachComponentFromFrame(testCase)
            % Verify setting Parent=[] detaches from Frame
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            comp.Parent = ic.core.ComponentContainer.empty();

            testCase.verifyFalse(comp.isAttached());
            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));
            testCase.verifyEmpty(testCase.Frame.Children);
        end

        function testDeleteComponentFromFrame(testCase)
            % Verify deleting component removes from Frame
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            delete(comp);

            testCase.verifyEmpty(testCase.Frame.Children);
        end

        function testDeleteContainerDeregistersAll(testCase)
            % Verify deleting container deregisters all descendants
            container = ic.core.ComponentContainer("container");
            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(container));
            testCase.addTeardown(@() testCase.safeDelete(child));

            child.Parent = container;
            container.Parent = testCase.Frame;
            testCase.assertEqual(testCase.Frame.Registry.numEntries, 2);

            delete(container);

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
            testCase.verifyFalse(isvalid(child));
        end

        function testDetachSubtreeDeregistersAll(testCase)
            % Verify detaching subtree root deregisters all descendants
            container = ic.core.ComponentContainer("container");
            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(container));
            testCase.addTeardown(@() testCase.safeDelete(child));

            child.Parent = container;
            container.Parent = testCase.Frame;
            testCase.assertEqual(testCase.Frame.Registry.numEntries, 2);

            container.Parent = ic.core.ComponentContainer.empty();

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
        end

        function testDetachMiddleNodeDeregistersDescendants(testCase)
            % Verify detaching middle node deregisters its descendants only
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(c3));

            c2.Parent = c1;
            c3.Parent = c2;
            c1.Parent = testCase.Frame;

            c2.Parent = ic.core.ComponentContainer.empty();

            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c3"));
        end
    end

    methods (Test)
        function testReparentBetweenContainers(testCase)
            % Verify moving component between attached containers
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            child = ic.core.Component("child");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(child));

            c1.Parent = testCase.Frame;
            c2.Parent = testCase.Frame;
            child.Parent = c1;

            child.Parent = c2;

            testCase.verifyEmpty(c1.Children);
            testCase.verifyLength(c2.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("child"));
        end

        function testReparentFromFrameToContainer(testCase)
            % Verify moving component from Frame to container
            container = ic.core.ComponentContainer("container");
            comp = ic.core.Component("comp");
            testCase.addTeardown(@() testCase.safeDelete(container));
            testCase.addTeardown(@() testCase.safeDelete(comp));

            container.Parent = testCase.Frame;
            comp.Parent = testCase.Frame;

            comp.Parent = container;

            testCase.verifyLength(testCase.Frame.Children, 1);
            testCase.verifyLength(container.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("comp"));
        end

        function testReparentSubtreeBetweenContainers(testCase)
            % Verify moving entire subtree between containers
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            subtree = ic.core.ComponentContainer("subtree");
            leaf = ic.core.Component("leaf");
            testCase.addTeardown(@() testCase.safeDelete(c1));
            testCase.addTeardown(@() testCase.safeDelete(c2));
            testCase.addTeardown(@() testCase.safeDelete(subtree));
            testCase.addTeardown(@() testCase.safeDelete(leaf));

            c1.Parent = testCase.Frame;
            c2.Parent = testCase.Frame;
            subtree.Parent = c1;
            leaf.Parent = subtree;

            subtree.Parent = c2;

            testCase.verifyEmpty(c1.Children);
            testCase.verifyLength(c2.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("subtree"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("leaf"));
        end

        function testReparentToDetachedContainer(testCase)
            % Verify moving to detached container deregisters from Frame
            attached = ic.core.ComponentContainer("attached");
            comp = ic.core.Component("comp");
            detached = ic.core.ComponentContainer("detached");
            testCase.addTeardown(@() testCase.safeDelete(attached));
            testCase.addTeardown(@() testCase.safeDelete(comp));
            testCase.addTeardown(@() testCase.safeDelete(detached));

            attached.Parent = testCase.Frame;
            comp.Parent = attached;

            comp.Parent = detached;

            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));
            testCase.verifyTrue(comp.isAttached());
            testCase.verifyEmpty(attached.Children);
        end
    end

    methods (Access = private)
        function safeDelete(~, obj)
            if isvalid(obj)
                delete(obj);
            end
        end
    end
end

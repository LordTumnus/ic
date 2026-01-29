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
            c1 = ic.core.Component("c1");

            c1.Parent = testCase.Frame;

            % check attachment and registration
            testCase.verifyEqual(c1.Parent, testCase.Frame);
            testCase.verifyTrue(c1.isAttached());
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));

            % check insertion event queued
            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@insert");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).ComponentID, "ic-frame");
            testCase.verifyEqual(testCase.Frame.View.Queue(end).Data.component.id, "c1");
        end


        function testUnattachedComponentNotInRegistry(testCase)
            % Verify unattached component is not registered
            c1 = ic.core.Component("c1");

            % check unattached and unregistered
            testCase.verifyFalse(c1.isAttached());
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c1"));
        end
    end

    methods (Test)
        function testBuildSubtreeNotAttached(testCase)
            % Verify subtree built without attaching to Frame
            container = ic.core.ComponentContainer("container");
            child = ic.core.Component("child");

            child.Parent = container;

            testCase.verifyTrue(child.isAttached());
            testCase.verifyFalse(container.isAttached());
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);

            testCase.assertNotEmpty(container.Queue);
            testCase.verifyEqual(container.Queue(end).Name, "@insert");
            testCase.verifyEqual(container.Queue(end).ComponentID, "container");
            testCase.verifyEqual(container.Queue(end).Data.component.id, "child");
        end

        function testAttachSubtreeRegistersAll(testCase)
            % Verify attaching subtree root registers all descendants
            % Frame -> c1 -> c2 -> c3
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");

            % define subtree
            c2.Parent = c1;
            c3.Parent = c2;
            % attach to Frame
            c1.Parent = testCase.Frame;

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("c3"));

            % check order of insertions
            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(1).Name, "@insert");
            testCase.verifyEqual(...
                    testCase.Frame.View.Queue(end).Name, "@insert");
            testCase.verifyEqual(...
                        testCase.Frame.View.Queue(1).Data.component.id, "c1");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.component.id, "c3");
        end

        function testAddComponentToAttachedContainer(testCase)
            % Verify adding child to already-attached container
            container = ic.core.ComponentContainer("container");
            container.Parent = testCase.Frame;
            testCase.assertTrue(testCase.Frame.Registry.isKey("container"));

            child = ic.core.Component("child");
            child.Parent = container;

            testCase.verifyTrue(testCase.Frame.Registry.isKey("child"));
            testCase.verifyLength(container.Children, 1);

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@insert");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.component.id, "child");
        end

        function testAddSubtreeToAttachedContainer(testCase)
            % Verify attaching pre-built subtree to attached container
            root = ic.core.ComponentContainer("root");
            root.Parent = testCase.Frame;
            testCase.assertTrue(testCase.Frame.Registry.isKey("root"));

            subtree = ic.core.ComponentContainer("subtree");
            leaf = ic.core.Component("leaf");
            leaf.Parent = subtree;

            subtree.Parent = root;

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@insert");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end-1).Data.component.id, "subtree");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.component.id, "leaf");
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

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@remove");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "comp");
        end

        function testDeleteComponentFromFrame(testCase)
            % Verify deleting component removes from Frame
            comp = ic.core.Component("comp");
            comp.Parent = testCase.Frame;

            delete(comp);

            testCase.verifyEmpty(testCase.Frame.Children);
            testCase.verifyFalse(testCase.Frame.Registry.isKey("comp"));

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@remove");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "comp");
        end

        function testDeleteContainerDeregistersAll(testCase)
            % Verify deleting container deregisters all descendants
            container = ic.core.ComponentContainer("container");
            child = ic.core.Component("child");

            child.Parent = container;
            container.Parent = testCase.Frame;
            testCase.assertEqual(testCase.Frame.Registry.numEntries, 2);

            delete(container);

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
            testCase.verifyFalse(isvalid(child));

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@remove");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "container");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end-1).Data.id, "child");
        end


        function testDetachMiddleNodeDeregistersDescendants(testCase)
            % Verify detaching middle node deregisters its descendants only
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");

            c2.Parent = c1;
            c3.Parent = c2;
            c1.Parent = testCase.Frame;

            c2.Parent = ic.core.ComponentContainer.empty();

            testCase.verifyTrue(testCase.Frame.Registry.isKey("c1"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c2"));
            testCase.verifyFalse(testCase.Frame.Registry.isKey("c3"));

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@remove");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "c2");
        end
    end

    methods (Test)
        function testReparentBetweenContainers(testCase)
            % Verify moving component between attached containers
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            child = ic.core.Component("child");

            c1.Parent = testCase.Frame;
            c2.Parent = testCase.Frame;
            child.Parent = c1;

            child.Parent = c2;

            testCase.verifyEmpty(c1.Children);
            testCase.verifyLength(c2.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("child"));

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@reparent");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).ComponentID, "c1");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "child");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.parent, "c2");
        end

        function testReparentAcrossFramesErrors(testCase)
            % Verify moving component across different frames errors
            fig2 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(fig2));
            frame2 = ic.Frame('Parent', fig2);

            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            child = ic.core.Component("child");

            c1.Parent = testCase.Frame;
            c2.Parent = frame2;
            child.Parent = c1;

            function reparentAcross()
                child.Parent = c2;
            end

            testCase.verifyError(@reparentAcross, ...
                "ic:core:Component:ReparentingAcrossFrames");
        end

        function testReparentFromFrameToContainer(testCase)
            % Verify moving component from Frame to container
            container = ic.core.ComponentContainer("container");
            comp = ic.core.Component("comp");

            container.Parent = testCase.Frame;
            comp.Parent = testCase.Frame;

            comp.Parent = container;

            testCase.verifyLength(testCase.Frame.Children, 1);
            testCase.verifyLength(container.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("comp"));

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@reparent");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).ComponentID, "ic-frame");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "comp");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.parent, "container");
        end

        function testReparentSubtreeBetweenContainers(testCase)
            % Verify moving entire subtree between containers
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            subtree = ic.core.ComponentContainer("subtree");
            leaf = ic.core.Component("leaf");

            c1.Parent = testCase.Frame;
            c2.Parent = testCase.Frame;
            subtree.Parent = c1;
            leaf.Parent = subtree;

            subtree.Parent = c2;

            testCase.verifyEmpty(c1.Children);
            testCase.verifyLength(c2.Children, 1);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("subtree"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("leaf"));

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@reparent");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).ComponentID, "c1");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "subtree");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.parent, "c2");
        end

        function testChangeTargetWithinContainer(testCase)
            % Verify changing Target triggers @reparent event
            container = ic.core.ComponentContainer("container");
            container.Targets = ["left", "right"];
            container.Parent = testCase.Frame;

            comp = ic.core.Component("comp");
            comp.setParent(container, "left");

            % Change target within same container
            comp.Target = "right";

            % Verify component stays in same container
            testCase.verifyLength(container.Children, 1);
            testCase.verifyEqual(comp.Target, "right");
            testCase.verifyTrue(testCase.Frame.Registry.isKey("comp"));

            % Verify @reparent event with new target
            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@reparent");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).ComponentID, "container");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "comp");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.parent, "container");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.target, "right");
        end

        function testChangeTargetToInvalidValueErrors(testCase)
            % Verify setting invalid Target throws error and state is unchanged
            container = ic.core.ComponentContainer("container");
            container.Targets = ["left", "right"];
            container.Parent = testCase.Frame;

            comp = ic.core.Component("comp");
            comp.setParent(container, "left");

            function setInvalidTarget()
                comp.Target = "invalid";
            end

            testCase.verifyError(@setInvalidTarget, ...
                "ic:core:Component:InvalidTarget");

            % Verify component state unchanged after failed target change
            testCase.verifyEqual(comp.Target, "left");
            testCase.verifyEqual(comp.Parent, container);
            testCase.verifyLength(container.Children, 1);
        end

        function testReparentToDetachedContainer(testCase)
            % Verify moving to detached container deregisters from Frame
            attached = ic.core.ComponentContainer("attached");
            comp = ic.core.Component("comp");
            detached = ic.core.ComponentContainer("detached");

            attached.Parent = testCase.Frame;
            comp.Parent = attached;

            function reparentGoneWrong()
                comp.Parent = detached;
            end

            testCase.verifyError(@reparentGoneWrong, ...
                "ic:core:Component:ReparentingAcrossFrames" );

        end
    end

    methods (Test)
        % Static Children Tests

        function testAddStaticChildBeforeAttachment(testCase)
            % Verify static children are in Children array immediately
            container = TestStaticContainer("container");

            testCase.verifyLength(container.Children, 2);
            testCase.verifyEqual(container.Children(1).ID, "container-child1");
            testCase.verifyEqual(container.Children(2).ID, "container-child2");
            % Static children have their Parent set to the container
            testCase.verifyEqual(container.Children(1).Parent, container);
        end

        function testStaticChildrenRegisteredOnAttach(testCase)
            % Verify static children are registered when parent attaches
            container = TestStaticContainer("container");

            container.Parent = testCase.Frame;

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("container"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("container-child1"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("container-child2"));
        end

        function testStaticChildrenInInsertPayload(testCase)
            % Verify @insert payload includes staticChildren
            container = TestStaticContainer("container");

            container.Parent = testCase.Frame;

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            insertEvt = testCase.Frame.View.Queue(1);
            testCase.verifyEqual(insertEvt.Name, "@insert");
            testCase.verifyTrue(isfield(insertEvt.Data.component, 'staticChildren'));
            testCase.verifyLength(insertEvt.Data.component.staticChildren, 2);
            testCase.verifyEqual(insertEvt.Data.component.staticChildren{1}.id, "container-child1");
            testCase.verifyEqual(insertEvt.Data.component.staticChildren{2}.id, "container-child2");
        end

        function testNoSeparateInsertForStaticChildren(testCase)
            % Verify static children don't trigger separate @insert events
            container = TestStaticContainer("container");

            container.Parent = testCase.Frame;

            % Should only have ONE @insert event (for the container)
            insertEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@insert");
            testCase.verifyLength(insertEvents, 1);
            testCase.verifyEqual(insertEvents(1).Data.component.id, "container");
        end

        function testStaticChildrenDefinitionHasIdAndType(testCase)
            % Verify staticChildren definitions include id and type
            container = TestStaticContainer("container");

            container.Parent = testCase.Frame;

            insertEvt = testCase.Frame.View.Queue(1);
            childDef = insertEvt.Data.component.staticChildren{1};
            testCase.verifyEqual(childDef.id, "container-child1");
            testCase.verifyEqual(childDef.type, "ic.core.Component");
        end

        function testDeleteContainerDeregistersStaticChildren(testCase)
            % Verify deleting container also deregisters static children
            container = TestStaticContainer("container");
            container.Parent = testCase.Frame;
            testCase.assertEqual(testCase.Frame.Registry.numEntries, 3);

            delete(container);

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
        end
    end
end

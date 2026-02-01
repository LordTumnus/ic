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

            testCase.Frame.addChild(c1);

            % check attachment and registration
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

            container.addChild(child);

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
            c1.addChild(c2);
            c2.addChild(c3);
            % attach to Frame
            testCase.Frame.addChild(c1);

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
            testCase.Frame.addChild(container);
            testCase.assertTrue(testCase.Frame.Registry.isKey("container"));

            child = ic.core.Component("child");
            container.addChild(child);

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
            testCase.Frame.addChild(root);
            testCase.assertTrue(testCase.Frame.Registry.isKey("root"));

            subtree = ic.core.ComponentContainer("subtree");
            leaf = ic.core.Component("leaf");
            subtree.addChild(leaf);

            root.addChild(subtree);

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
            % Verify removeChild detaches from Frame
            comp = ic.core.Component("comp");
            testCase.Frame.addChild(comp);

            testCase.Frame.removeChild(comp);

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
            testCase.Frame.addChild(comp);

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

            container.addChild(child);
            testCase.Frame.addChild(container);
            testCase.assertEqual(testCase.Frame.Registry.numEntries, 2);

            delete(container);

            % Both container and child should be deregistered
            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
            testCase.verifyFalse(isvalid(child));

            % @remove event sent for container (children deleted internally)
            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Name, "@remove");
            testCase.verifyEqual(...
                testCase.Frame.View.Queue(end).Data.id, "container");
        end


        function testDetachMiddleNodeDeregistersDescendants(testCase)
            % Verify detaching middle node deregisters its descendants only
            c1 = ic.core.ComponentContainer("c1");
            c2 = ic.core.ComponentContainer("c2");
            c3 = ic.core.Component("c3");

            c1.addChild(c2);
            c2.addChild(c3);
            testCase.Frame.addChild(c1);

            c1.removeChild(c2);

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

            testCase.Frame.addChild(c1);
            testCase.Frame.addChild(c2);
            c1.addChild(child);

            % Reparent by adding to new container
            c2.addChild(child);

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

            testCase.Frame.addChild(c1);
            frame2.addChild(c2);
            c1.addChild(child);

            function reparentAcross()
                c2.addChild(child);
            end

            testCase.verifyError(@reparentAcross, ...
                "ic:core:Component:ReparentingAcrossFrames");
        end

        function testReparentFromFrameToContainer(testCase)
            % Verify moving component from Frame to container
            container = ic.core.ComponentContainer("container");
            comp = ic.core.Component("comp");

            testCase.Frame.addChild(container);
            testCase.Frame.addChild(comp);

            % Reparent by adding to container
            container.addChild(comp);

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

            testCase.Frame.addChild(c1);
            testCase.Frame.addChild(c2);
            c1.addChild(subtree);
            subtree.addChild(leaf);

            % Reparent subtree to c2
            c2.addChild(subtree);

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
            % Verify changing target via addChild triggers @reparent event
            container = ic.core.ComponentContainer("container");
            container.Targets = ["left", "right"];
            testCase.Frame.addChild(container);

            comp = ic.core.Component("comp");
            container.addChild(comp, "left");

            % Change target by re-adding with new target
            container.addChild(comp, "right");

            % Verify component stays in same container
            testCase.verifyLength(container.Children, 1);
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
            % Verify adding with invalid target throws error
            container = ic.core.ComponentContainer("container");
            container.Targets = ["left", "right"];
            testCase.Frame.addChild(container);

            comp = ic.core.Component("comp");
            container.addChild(comp, "left");

            function addWithInvalidTarget()
                container.addChild(comp, "invalid");
            end

            testCase.verifyError(@addWithInvalidTarget, ...
                "ic:core:Component:InvalidTarget");

            % Verify component still in container after failed target change
            testCase.verifyLength(container.Children, 1);
        end

        function testReparentToDetachedContainer(testCase)
            % Verify moving to detached container errors
            attached = ic.core.ComponentContainer("attached");
            comp = ic.core.Component("comp");
            detached = ic.core.ComponentContainer("detached");

            testCase.Frame.addChild(attached);
            attached.addChild(comp);

            function reparentGoneWrong()
                detached.addChild(comp);
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
            % Static children are attached to the container
            testCase.verifyTrue(container.Children(1).isAttached());
        end

        function testStaticChildrenRegisteredOnAttach(testCase)
            % Verify static children are registered when parent attaches
            container = TestStaticContainer("container");

            testCase.Frame.addChild(container);

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 3);
            testCase.verifyTrue(testCase.Frame.Registry.isKey("container"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("container-child1"));
            testCase.verifyTrue(testCase.Frame.Registry.isKey("container-child2"));
        end

        function testStaticChildrenInInsertPayload(testCase)
            % Verify @insert payload includes staticChildren
            container = TestStaticContainer("container");

            testCase.Frame.addChild(container);

            testCase.assertNotEmpty(testCase.Frame.View.Queue);
            insertEvt = testCase.Frame.View.Queue(1);
            testCase.verifyEqual(insertEvt.Name, "@insert");
            testCase.verifyTrue(isfield(insertEvt.Data.component, 'staticChildren'));
            testCase.verifyLength(insertEvt.Data.component.staticChildren, 2);
            testCase.verifyEqual(insertEvt.Data.component.staticChildren{1}.component.id, "container-child1");
            testCase.verifyEqual(insertEvt.Data.component.staticChildren{2}.component.id, "container-child2");
        end

        function testNoSeparateInsertForStaticChildren(testCase)
            % Verify static children don't trigger separate @insert events
            container = TestStaticContainer("container");

            testCase.Frame.addChild(container);

            % Should only have ONE @insert event (for the container)
            insertEvents = testCase.Frame.View.Queue(...
                [testCase.Frame.View.Queue.Name] == "@insert");
            testCase.verifyLength(insertEvents, 1);
            testCase.verifyEqual(insertEvents(1).Data.component.id, "container");
        end

        function testStaticChildrenDefinitionHasComponentAndTarget(testCase)
            % Verify staticChildren definitions include component and target
            container = TestStaticContainer("container");

            testCase.Frame.addChild(container);

            insertEvt = testCase.Frame.View.Queue(1);
            childDef = insertEvt.Data.component.staticChildren{1};
            testCase.verifyEqual(childDef.component.id, "container-child1");
            testCase.verifyEqual(childDef.component.type, "ic.core.Component");
            testCase.verifyTrue(isfield(childDef, 'target'));
        end

        function testDeleteContainerDeregistersStaticChildren(testCase)
            % Verify deleting container also deregisters static children
            container = TestStaticContainer("container");
            testCase.Frame.addChild(container);
            testCase.assertEqual(testCase.Frame.Registry.numEntries, 3);

            delete(container);

            testCase.verifyEqual(testCase.Frame.Registry.numEntries, 0);
        end
    end
end

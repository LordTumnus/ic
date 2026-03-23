classdef Dialog < ic.core.ComponentContainer & ic.mixin.Overlay
    % modal overlay with a title, content body, and action buttons.
    % The dialog auto-deletes after submit or close when #ic.Dialog.DestroyOnClose is true.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % heading text displayed in the dialog header
        Title string = ""

        % whether the dialog is visible
        Open logical = false

        % maximum width of the dialog, relative to the component font size
        Size string {mustBeMember(Size, ["sm", "md", "lg", "xl"])} = "md"

        % whether the close button and Escape key are enabled to close and delete the dialog
        Closable logical = true

        % whether clicking the backdrop closes the dialog
        CloseOnBackdropClick logical = true

        % text for the submit button. Set to "" to hide the button
        SubmitLabel string = "OK"

        % text for the cancel button. Set to "" to hide the button
        CancelLabel string = "Cancel"
    end

    properties (SetAccess = immutable)
        % whether the dialog is automatically deleted after the Submitted or Closed event fires
        DestroyOnClose logical = true
    end

    events (Description = "Reactive")
        % fires when the user clicks the submit button
        Submitted

        % fires when the user dismisses the dialog (cancel button, close button, Escape, or backdrop click)
        Closed
    end

    methods
        function this = Dialog(props)
            arguments
                props.?ic.Dialog
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.Targets = ["body", "footer"];
            addlistener(this, 'Submitted', @(src, ~) src.autoDestroy());
            addlistener(this, 'Closed', @(src, ~) src.autoDestroy());
        end

        function open(this)
            % programmatically open the dialog
            this.Open = true;
        end

        function close(this)
            % programmatically close the dialog
            this.Open = false;
        end

        function effect = bindOpen(this, component, event)
            % utility function to wire a DOM event on a component to open the dialog
            arguments
                this
                % component whose DOM event triggers the open
                component
                % DOM event name to listen for
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dlg) => { c.el?.addEventListener('%s', () => { dlg.props.open = true; }); }", ...
                event));
        end

        function effect = bindSubmit(this, component, event)
            % utility function to wire a DOM event on a component to trigger the submit action
            arguments
                this
                % component whose DOM event triggers the submit
                component
                % DOM event name to listen for
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dlg) => { c.el?.addEventListener('%s', () => { dlg.props.open = false; dlg.props.submitted?.({}); }); }", ...
                event));
        end

        function effect = bindClose(this, component, event)
            % utility function to wire a DOM event on a component to close the dialog
            arguments
                this
                % component whose DOM event triggers the close
                component
                % DOM event name to listen for
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dlg) => { c.el?.addEventListener('%s', () => { dlg.props.open = false; dlg.props.closed?.({}); }); }", ...
                event));
        end
    end

    methods (Access = private)
        function autoDestroy(this)
            if this.DestroyOnClose && isvalid(this)
                 delete(this)
            end
        end
    end
end

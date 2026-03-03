classdef Dialog < ic.core.ComponentContainer & ic.mixin.Overlay
    % > DIALOG Modal overlay with title, body, and action buttons.
    %
    %   d = ic.Dialog(Title="Confirm", SubmitLabel="Delete", CancelLabel="Cancel");
    %   d.addChild(ic.Label(Label="Are you sure?"));
    %   frame.addChild(d);
    %   d.open();
    %
    %   addlistener(d, 'Submitted', @(~,~) disp("Confirmed"));
    %   addlistener(d, 'Closed',    @(~,~) disp("Cancelled"));

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > TITLE heading text displayed in the dialog header
        Title string = ""
        % > OPEN whether the dialog is visible
        Open logical = false
        % > SIZE maximum width of the dialog content
        Size string {mustBeMember(Size, ["sm", "md", "lg", "xl"])} = "md"
        % > CLOSABLE whether the close button and Escape key are enabled
        Closable logical = true
        % > CLOSEONBACKDROPCLICK whether clicking the backdrop closes the dialog
        CloseOnBackdropClick logical = true
        % > SUBMITLABEL text for the submit button (empty = hidden)
        SubmitLabel string = "OK"
        % > CANCELLABEL text for the cancel button (empty = hidden)
        CancelLabel string = "Cancel"
    end

    properties
        % > DESTROYONCLOSE whether to delete the dialog after submit or close
        DestroyOnClose logical = true
    end

    events (Description = "Reactive")
        % > SUBMITTED fires when the user clicks the submit button
        Submitted
        % > CLOSED fires when the user dismisses the dialog (cancel, X, Escape, backdrop)
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
            % > OPEN programmatically open the dialog
            this.Open = true;
        end

        function close(this)
            % > CLOSE programmatically close the dialog (no Closed event)
            this.Open = false;
        end

        function effect = bindOpen(this, component, event)
            % > BINDOPEN wires a DOM event on a component to open the dialog.
            arguments
                this
                component
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dlg) => { c.el?.addEventListener('%s', () => { dlg.props.open = true; }); }", ...
                event));
        end

        function effect = bindSubmit(this, component, event)
            % > BINDSUBMIT wires a DOM event on a component to trigger dialog submit.
            arguments
                this
                component
                event string = "click"
            end
            effect = this.jsEffect(component, this, sprintf( ...
                "(c, dlg) => { c.el?.addEventListener('%s', () => { dlg.props.open = false; dlg.props.submitted?.({}); }); }", ...
                event));
        end

        function effect = bindClose(this, component, event)
            % > BINDCLOSE wires a DOM event on a component to trigger dialog close.
            arguments
                this
                component
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

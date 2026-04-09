classdef DialogFooter < ic.core.ComponentContainer
    % content container for the footer area of an #ic.Dialog.
    % Created automatically by the Dialog constructor. Add buttons or
    % other controls here to replace the default OK/Cancel buttons.

    methods (Access = ?ic.Dialog)
        function this = DialogFooter(props)
            arguments
                props.?ic.dialog.DialogFooter
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end

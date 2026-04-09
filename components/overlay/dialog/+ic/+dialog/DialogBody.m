classdef DialogBody < ic.core.ComponentContainer
    % content container for the body area of an #ic.Dialog.
    % Created automatically by the Dialog constructor.

    methods (Access = ?ic.Dialog)
        function this = DialogBody(props)
            arguments
                props.?ic.dialog.DialogBody
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
        end
    end
end

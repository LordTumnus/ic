classdef Note < ic.node.Node
    % > NOTE Sticky note — non-functional annotation node.
    %   Resizable colored note with editable text content. Has no ports.
    %
    %   n = ic.node.Note(Content="TODO: add filter here")
    %   n = ic.node.Note(Color="#fef08a", Width=200, Height=120)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > CONTENT text displayed in the note
        Content (1,1) string = ""

        % > COLOR background color (default: sticky note yellow)
        Color (1,1) string = "#fef9c3"

        % > WIDTH note width in pixels
        Width (1,1) double {mustBePositive} = 160

        % > HEIGHT note height in pixels
        Height (1,1) double {mustBePositive} = 100
    end

    methods
        function this = Note(props)
            % > NOTE Construct a sticky note node.
            arguments
                props.?ic.node.Note
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.node.Node(props);
        end
    end

    methods (Access = protected)
        function defineDefaultPorts(~)
            % Notes have no ports — purely visual annotation.
        end
    end
end

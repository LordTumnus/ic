classdef SequenceConfig < ic.event.TransportData
    % configuration for Mermaid sequence diagrams.
    % Pass an instance to #ic.Mermaid.Config to customize layout and appearance.

    properties
        % horizontal gap between actor boxes, in pixels
        ActorMargin (1,1) double {mustBeNonnegative} = 50

        % vertical gap between messages, in pixels
        MessageMargin (1,1) double {mustBeNonnegative} = 35

        % whether to repeat actor boxes at the bottom of the diagram
        MirrorActors (1,1) logical = true

        % whether to number each message arrow
        ShowSequenceNumbers (1,1) logical = false

        % whether to use square corners instead of curved arrows
        RightAngles (1,1) logical = false

        % whether to auto-wrap long message text
        Wrap (1,1) logical = false

        % whether to hide actors with no messages
        HideUnusedParticipants (1,1) logical = false

        % width of activation rectangles, in pixels
        ActivationWidth (1,1) double {mustBeNonnegative} = 10

        % margin around note boxes, in pixels
        NoteMargin (1,1) double {mustBeNonnegative} = 10

        % text alignment for multiline messages
        MessageAlign string {mustBeMember(MessageAlign, ["left","center","right"])} = "center"

        % text alignment for notes
        NoteAlign string {mustBeMember(NoteAlign, ["left","center","right"])} = "center"

        % width of actor boxes, in pixels
        Width (1,1) double {mustBePositive} = 150

        % height of actor boxes, in pixels
        Height (1,1) double {mustBePositive} = 50
    end

    methods
        function this = SequenceConfig(props)
            arguments
                props.?ic.mermaid.SequenceConfig
            end
            fns = fieldnames(props);
            for i = 1:numel(fns)
                this.(fns{i}) = props.(fns{i});
            end
        end

        function s = toStruct(this)
            inner = struct();
            plist = properties(this);
            for i = 1:numel(plist)
                name = plist{i};
                inner.([lower(name(1)), name(2:end)]) = this.(name);
            end
            s = struct('sequence', inner);
        end

        function json = jsonencode(this, varargin)
            json = jsonencode(this.toStruct(), varargin{:});
        end
    end
end

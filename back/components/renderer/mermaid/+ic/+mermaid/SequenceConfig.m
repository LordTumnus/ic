classdef SequenceConfig
    % > SEQUENCECONFIG Mermaid sequence diagram configuration.
    %
    %   m.Config = ic.mermaid.SequenceConfig(MirrorActors=false, ShowSequenceNumbers=true)

    properties
        % > ACTORMARGIN horizontal gap between actor boxes
        ActorMargin (1,1) double {mustBeNonnegative} = 50

        % > MESSAGEMARGIN vertical gap between messages
        MessageMargin (1,1) double {mustBeNonnegative} = 35

        % > MIRRORACTORS repeat actor boxes at the bottom of the diagram
        MirrorActors (1,1) logical = true

        % > SHOWSEQUENCENUMBERS number each message arrow
        ShowSequenceNumbers (1,1) logical = false

        % > RIGHTANGLES use square corners instead of curved arrows
        RightAngles (1,1) logical = false

        % > WRAP auto-wrap long message text
        Wrap (1,1) logical = false

        % > HIDEUNUSEDPARTICIPANTS hide actors with no messages
        HideUnusedParticipants (1,1) logical = false

        % > ACTIVATIONWIDTH width of activation rectangles (px)
        ActivationWidth (1,1) double {mustBeNonnegative} = 10

        % > NOTEMARGIN margin around note boxes (px)
        NoteMargin (1,1) double {mustBeNonnegative} = 10

        % > MESSAGEALIGN multiline message text alignment
        MessageAlign string {mustBeMember(MessageAlign, ["left","center","right"])} = "center"

        % > NOTEALIGN note text alignment
        NoteAlign string {mustBeMember(NoteAlign, ["left","center","right"])} = "center"

        % > WIDTH width of actor boxes (px)
        Width (1,1) double {mustBePositive} = 150

        % > HEIGHT height of actor boxes (px)
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

        function json = jsonencode(this, varargin)
            s = struct();
            plist = properties(this);
            for i = 1:numel(plist)
                name = plist{i};
                s.([lower(name(1)), name(2:end)]) = this.(name);
            end
            json = jsonencode(struct('sequence', s), varargin{:});
        end
    end
end

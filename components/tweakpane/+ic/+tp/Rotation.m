classdef Rotation < ic.tp.Blade
    % > ROTATION 3D rotation input blade for TweakPane (plugin-rotation).
    %
    % Supports two modes:
    %   Euler:      Value = struct('x',0,'y',0,'z',0)
    %   Quaternion: Value = struct('x',0,'y',0,'z',0,'w',1)

    properties (SetObservable, AbortSet, Description = "Reactive")
        % > VALUE rotation struct: {x,y,z} for Euler, {x,y,z,w} for Quaternion
        Value (1,1) struct = struct('x', 0, 'y', 0, 'z', 0)
        % > MODE rotation representation
        Mode (1,1) string {mustBeMember(Mode, ["euler","quaternion"])} = "euler"
        % > ORDER Euler rotation order (only applies when Mode = "euler")
        Order (1,1) string {mustBeMember(Order, ["XYZ","YXZ","ZXY","ZYX","YZX","XZY"])} = "XYZ"
        % > UNIT angular unit (only applies when Mode = "euler")
        Unit (1,1) string {mustBeMember(Unit, ["rad","deg","turn"])} = "deg"
        % > PICKER display style for the 3D gizmo
        Picker (1,1) string {mustBeMember(Picker, ["inline","popup"])} = "inline"
    end

    events (Description = "Reactive")
        % > VALUECHANGED fires when rotation changes
        ValueChanged
    end

    methods
        function this = Rotation(props)
            arguments
                props.?ic.tp.Rotation
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.tp.Blade(props);
        end
    end
end

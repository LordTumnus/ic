classdef Rotation < ic.tp.Blade
    % 3D rotation input blade for TweakPane.
    % supports Euler angles (Value has fields x, y, z) and quaternions (x, y, z, w).
    % uses [@0b5vr/tweakpane-plugin-rotation](https://github.com/0b5vr/tweakpane-plugin-rotation).

    properties (SetObservable, AbortSet, Description = "Reactive")
        % rotation as a struct: {x,y,z} for Euler mode, {x,y,z,w} for Quaternion mode
        Value (1,1) struct = struct('x', 0, 'y', 0, 'z', 0)

        % rotation representation: Euler or Quaternion
        Mode (1,1) string {mustBeMember(Mode, ["euler","quaternion"])} = "euler"

        % Euler axis order (only applies when Mode = "euler")
        Order (1,1) string {mustBeMember(Order, ["XYZ","YXZ","ZXY","ZYX","YZX","XZY"])} = "XYZ"

        % angular unit (only applies when Mode = "euler")
        Unit (1,1) string {mustBeMember(Unit, ["rad","deg","turn"])} = "deg"

        % display style for the 3D gizmo
        Picker (1,1) string {mustBeMember(Picker, ["inline","popup"])} = "inline"
    end

    events (Description = "Reactive")
        % fires when the rotation changes
        % {payload}
        % value | struct: rotation struct matching Value fields (x, y, z; plus w for quaternion mode)
        % {/payload}
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

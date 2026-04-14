classdef Camera < ic.core.Component
    % controls the 3D globe camera. Mirrors the [CesiumJS Scene.camera](https://cesium.com/learn/cesiumjs/ref-doc/Camera.html) API.

    properties (SetObservable, AbortSet, Description = "Reactive")
        % camera geographic position as [lat, lon] in degrees
        Position (1,2) double = [0, 0]

        % camera altitude in meters above the ellipsoid
        Altitude (1,1) double = 1.5e7

        % compass heading in degrees (0 = north, 90 = east)
        Heading (1,1) double = 0

        % pitch in degrees (-90 = straight down, 0 = horizon)
        Pitch (1,1) double = -90

        % roll in degrees (0 = level)
        Roll (1,1) double = 0
    end

    events (Description = "Reactive")
        % fires after the camera settles (user drag or programmatic move).
        % {payload}
        % position | 1x2 double: [lat, lon]
        % altitude | double: meters
        % heading  | double: degrees
        % pitch    | double: degrees
        % roll     | double: degrees
        % bounds   | 2x2 double: visible viewport as [[south,west];[north,east]] in degrees; empty when looking off-globe
        % {/payload}
        Changed
    end

    methods (Access = ?ic.Globe)
        function this = Camera(props)
            arguments
                props.?ic.globe.Camera
                props.ID (1,1) string = "ic-" + matlab.lang.internal.uuid()
            end
            this@ic.core.Component(props);
        end
    end

    methods (Description = "Reactive")
        function out = flyTo(this, position, opts)
            % smoothly animate the camera to a target.
            arguments
                this
                % [lat, lon] target
                position (1,2) double
                % altitude in meters (default: current altitude)
                opts.Altitude (1,1) double = this.Altitude
                % heading in degrees
                opts.Heading (1,1) double = this.Heading
                % pitch in degrees
                opts.Pitch (1,1) double = this.Pitch
                % roll in degrees
                opts.Roll (1,1) double = this.Roll
                % animation duration in seconds (0 = instant)
                opts.Duration (1,1) double = 2
            end
            out = this.publish("flyTo", struct( ...
                'position', position, ...
                'altitude', opts.Altitude, ...
                'heading', opts.Heading, ...
                'pitch', opts.Pitch, ...
                'roll', opts.Roll, ...
                'duration', opts.Duration));
        end

        function out = setView(this, position, opts)
            % instantly set the camera view (no animation).
            arguments
                this
                position (1,2) double
                opts.Altitude (1,1) double = this.Altitude
                opts.Heading (1,1) double = this.Heading
                opts.Pitch (1,1) double = this.Pitch
                opts.Roll (1,1) double = this.Roll
            end
            out = this.publish("setView", struct( ...
                'position', position, ...
                'altitude', opts.Altitude, ...
                'heading', opts.Heading, ...
                'pitch', opts.Pitch, ...
                'roll', opts.Roll));
        end

        function out = lookAt(this, target, opts)
            % orbit-style: point the camera at a target from a fixed range.
            arguments
                this
                % [lat, lon] of the target point
                target (1,2) double
                % distance from target in meters
                opts.Range (1,1) double = 50000
                % orbit heading in degrees
                opts.Heading (1,1) double = 0
                % orbit pitch in degrees (negative tilts camera downward)
                opts.Pitch (1,1) double = -45
            end
            out = this.publish("lookAt", struct( ...
                'target', target, ...
                'range', opts.Range, ...
                'heading', opts.Heading, ...
                'pitch', opts.Pitch));
        end

        function out = flyHome(this, opts)
            % animate back to the default starting view.
            arguments
                this
                opts.Duration (1,1) double = 2
            end
            out = this.publish("flyHome", struct('duration', opts.Duration));
        end

        function out = fitBounds(this, bounds, opts)
            % fly the camera so a geographic rectangle fills the view.
            % {example}
            %   % frame continental Europe
            %   g.Camera.fitBounds([[36, -10]; [60, 30]]);
            % {/example}
            arguments
                this
                % 2x2 double: [[south, west]; [north, east]] in degrees
                bounds (2,2) double
                % animation duration in seconds (0 = instant)
                opts.Duration (1,1) double = 2
            end
            out = this.publish("fitBounds", struct( ...
                'bounds', bounds, ...
                'duration', opts.Duration));
        end
    end
end

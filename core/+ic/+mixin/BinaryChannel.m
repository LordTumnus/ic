classdef (Abstract) BinaryChannel < handle
    % file-based binary data transfer to the frontend.
    % Writes raw binary data to files in the front/dist/binary/ directory and notifies the frontend via lightweight bridge events. The frontend then fetches files as ArrayBuffer

    methods (Abstract, Access = public)
        subscribe(this, name, callback)
    end

    methods (Abstract, Access = protected)
        send(this, evt)
    end

    properties (Access = private, Transient)
        % monotonic version counter per channel name (for cache-busting)
        BinaryVersions = dictionary(string.empty(), double.empty())
    end

    methods (Access = public)
        function writeBinary(this, channel, data)
            % writes binary data to a file and notifies the frontend via the JSON bridge.
            % {example}
            %   bytes = typecast(single(terrainData(:)), 'uint8');
            %   this.writeBinary("terrain", bytes);
            % {/example}
            arguments (Input)
                this (1,1) ic.mixin.BinaryChannel
                % name identifying this binary stream
                channel (1,1) string
                % raw bytes to transfer
                data (:,1) uint8
            end

            binDir = this.getBinaryDir();
            if ~isfolder(binDir)
                mkdir(binDir);
            end

            filePath = fullfile(binDir, channel + ".bin");
            fid = fopen(filePath, 'w');
            cleanupFid = onCleanup(@() fclose(fid));
            fwrite(fid, data, 'uint8');
            delete(cleanupFid);

            if this.BinaryVersions.isKey(channel)
                v = this.BinaryVersions(channel) + 1;
            else
                v = 1;
            end
            this.BinaryVersions(channel) = v;

            relativePath = "binary/" + this.ID + "/" + channel + ".bin";
            this.publish( ...
                "@binary/" + channel, ...
                struct('file', relativePath, 'v', v, 'size', numel(data)));
        end

        function onBinaryRequest(this, channel, callback)
            % registers a handler for frontend-initiated binary data requests.
            % the callback must return a uint8 vector of raw bytes
            arguments (Input)
                this (1,1) ic.mixin.BinaryChannel
                % request channel name
                channel (1,1) string
                % handler invoked as callback(comp, data), must return uint8
                callback (1,1) function_handle
            end

            camelName = "@binaryRequest/" + ic.utils.toCamelCase(channel);
            this.subscribe(camelName, @(comp, ~, payload) ...
                comp.handleBinaryRequest(channel, payload, callback));
        end

        function clearBinary(this, channel)
            % deletes the binary file for a specific channel.
            arguments (Input)
                this (1,1) ic.mixin.BinaryChannel
                % channel name to clear
                channel (1,1) string
            end

            filePath = fullfile(this.getBinaryDir(), channel + ".bin");
            if isfile(filePath)
                delete(filePath);
            end

            if this.BinaryVersions.isKey(channel)
                this.BinaryVersions(channel) = [];
            end
        end

        function clearAllBinary(this)
            % deletes all binary files for this component.
            binDir = this.getBinaryDir();
            if isfolder(binDir)
                rmdir(binDir, 's');
            end
            this.BinaryVersions = dictionary(string.empty(), double.empty());
        end

        function delete(this)
            % clean up binary files on destruction.
            this.clearAllBinary();
        end
    end

    methods (Access = private)
        function dir = getBinaryDir(this)
            % returns the absolute path to this component's binary directory.
            dir = fullfile( ...
                fileparts(ic.core.View.HTMLSource), ...
                'binary', ...
                this.ID);
        end

        function handleBinaryRequest(this, channel, payload, callback)
            % processes an incoming binary request: invokes the callback, writes the result to a per-request file, and sends the file path back. Registers a one-shot evict listener to clean up after the frontend fetches the file.
            try
                result = callback(this, payload.data);

                perRequestChannel = channel + "_" + string(payload.id);
                this.writeBinary(perRequestChannel, uint8(result(:)));

                relativePath = "binary/" + this.ID + "/" + perRequestChannel + ".bin";
                v = this.BinaryVersions(perRequestChannel);

                evictEvent = "@binaryEvict/" + string(payload.id);
                this.subscribe(evictEvent, @(comp, name, ~) ...
                    comp.handleBinaryEvict(name, perRequestChannel));

                response = struct( ...
                    'file', relativePath, ...
                    'v', v, ...
                    'size', numel(result));
                evt = ic.event.JsEvent(this.ID, ...
                    "@binaryResp/" + string(payload.id), response);
                this.send(evt);
            catch ex
                evt = ic.event.JsEvent(this.ID, ...
                    "@binaryResp/" + string(payload.id), ...
                    struct('error', ex.message));
                this.send(evt);
            end
        end

        function handleBinaryEvict(this, evictEventName, perRequestChannel)
            % fires once after the frontend confirms a binary fetch completed. % Delete the backing file and remove the one-shot subscription
            filePath = fullfile(this.getBinaryDir(), perRequestChannel + ".bin");
            if isfile(filePath)
                delete(filePath);
            end
            if this.BinaryVersions.isKey(perRequestChannel)
                this.BinaryVersions(perRequestChannel) = [];
            end
            this.unsubscribe(evictEventName);
        end
    end

end

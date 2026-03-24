classdef Asset < ic.event.TransportData
   % universal source type for icons, images, and files.
   % Accepts a:
   %   - Lucide icon name
   %   - A local file path
   %   - A HTTP/HTTPS URL
   % Any of these types are automatically detected when constructing from a string, so components that type a property as ic.asset.Asset get implicit string conversion.
   % Assets from urls or files are hashed and cached in the #ic.asset.AssetRegistry to avoid redundant uploads to the frontend. If an asset has been sent before (hash match), only the hash is sent to the frontend; otherwise, the raw bytes are sent along with the hash and MIME type.

   properties (SetAccess = immutable, Hidden)
      % source kind: "" (empty), "name" (Lucide), "file" (local path), or "url"
      Type (1,1) string = ""

      % Lucide icon name, absolute file path, or URL
      Value (1,1) string = ""
   end

   methods
      function this = Asset(source)
         arguments
            source (1,1) string = ""
         end
         if source == ""
            return
         end
         if startsWith(source, ["http://", "https://"])
            this.Type = "url";
            this.Value = source;
         elseif isfile(source)
            this.Type = "file";
            this.Value = source;
         else
            if ~matches(source, regexpPattern('^[a-z0-9]+(-[a-z0-9]+)*$'))
               error('ic:asset:InvalidName', ...
                  'Lucide name must contain only lowercase letters, numbers and hyphens, got "%s"', ...
                  source);
            end
            this.Type = "name";
            this.Value = source;
         end
      end

      function s = toStruct(this)
         if isempty(this) || this.Type == ""
            s = [];
            return
         end
         if this.Type == "name"
            s = this.Value;
            return
         end
         % file or url → read raw bytes, compute hash
         if this.Type == "file"
            [raw, ext] = ic.asset.Asset.readFile(this.Value);
            hash = ic.asset.Asset.computeHash(raw);
         else
            [raw, ext, hash] = ic.asset.Asset.cachedUrlDownload(this.Value);
         end
         if ic.asset.AssetRegistry.hasSent(hash)
            s = struct('hash', hash);
         else
            ic.asset.AssetRegistry.markSent(hash);
            mime = ic.asset.Asset.mimeFromExt(ext);
            s = struct('hash', hash, 'mime', mime, ...
                       'data', string(matlab.net.base64encode(raw)));
         end
      end

      function json = jsonencode(this, varargin)
         json = jsonencode(this.toStruct(), varargin{:});
      end
   end

   methods (Static, Access = private)
      function [raw, ext, hash] = cachedUrlDownload(url)
         % download a URL and return its bytes; caches by URL to skip repeated HTTP requests.
         cache = ic.asset.AssetRegistry.getUrlCache();
         key = char(url);
         if cache.isKey(key)
            c = cache(key);
            raw = c.raw; ext = c.ext; hash = c.hash;
            return;
         end
         [raw, ext] = ic.asset.Asset.downloadUrl(url);
         hash = ic.asset.Asset.computeHash(raw);
         cache(key) = struct('raw', raw, 'ext', ext, 'hash', hash); %#ok<NASGU> handle
      end

      function [raw, ext] = readFile(path)
         % read a local file into raw bytes.
         absPath = string(path);
         fid = fopen(absPath, 'rb');
         raw = fread(fid, Inf, '*uint8');
         fclose(fid);
         [~, ~, ext] = fileparts(absPath);
      end

      function [raw, ext] = downloadUrl(url)
         % download a URL to a temp file and return raw bytes.
         [~, ~, ext] = fileparts(url);
         ext = regexprep(ext, '\?.*$', '');
         tmpFile = string(tempname) + ext;
         websave(tmpFile, url);
         fid = fopen(tmpFile, 'rb');
         raw = fread(fid, Inf, '*uint8');
         fclose(fid);
         delete(tmpFile);
      end

      function h = computeHash(data)
         % compute a pure-MATLAB fingerprint for deduplication (no Java dependency).
         data = uint8(data(:));
         n = numel(data);
         d = double(data);
         s1 = mod(sum(d .* mod((1:n)', 65521)), 2^52);
         s2 = mod(sum(d .* mod((1:n)' * 31, 65497)), 2^52);
         h = sprintf('%x%013x%013x', n, s1, s2);
      end

      function mime = mimeFromExt(ext)
         % map a file extension to a MIME type string; falls back to "application/octet-stream".
         ext = lower(ext);
         map = dictionary( ...
            [".svg", ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".ico", ...
             ".css", ".txt", ".json", ".pdf"], ...
            ["image/svg+xml", "image/png", "image/jpeg", "image/jpeg", ...
             "image/gif", "image/bmp", "image/webp", "image/x-icon", ...
             "text/css", "text/plain", "application/json", "application/pdf"]);
         if isKey(map, ext)
            mime = map(ext);
         else
            mime = "application/octet-stream";
         end
      end
   end
end

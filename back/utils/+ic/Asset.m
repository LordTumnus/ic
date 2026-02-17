classdef Asset
   % > ASSET Universal source: Lucide name, local file, or URL.
   %   ic.Asset("home")           → name (Lucide)
   %   ic.Asset("photo.png")      → file (isfile=true)
   %   ic.Asset("https://...")    → url
   %   ic.Asset() or ic.Asset("") → empty

   properties (SetAccess = immutable)
      % > TYPE source kind: "" | "name" | "file" | "url"
      Type (1,1) string = ""
      % > VALUE Lucide name, absolute file path, or URL
      Value (1,1) string = ""
   end

   methods
      function this = Asset(source)
         % > ASSET Construct from a string. Auto-detects source kind.
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
            this.Type = "name";
            this.Value = source;
         end
      end

      function json = jsonencode(this, varargin)
         % > JSONENCODE Encode asset for JSON transmission.
         if isempty(this) || this.Type == ""
            json = jsonencode([], varargin{:});
            return
         end
         if this.Type == "name"
            json = jsonencode(this.Value, varargin{:});
            return
         end
         % file or url → read raw bytes, compute hash, encode only if needed
         if this.Type == "file"
            [raw, ext] = ic.Asset.readFile(this.Value);
         else
            [raw, ext] = ic.Asset.downloadUrl(this.Value);
         end
         hash = ic.Asset.computeHash(raw);
         if ic.AssetRegistry.hasSent(hash)
            s = struct('hash', hash);
         else
            ic.AssetRegistry.markSent(hash);
            s = struct('hash', hash, ...
                       'mime', ic.Asset.mimeFromExt(ext), ...
                       'data', string(matlab.net.base64encode(raw)));
         end
         json = jsonencode(s, varargin{:});
      end
   end

   methods (Static, Access = private)
      function [raw, ext] = readFile(path)
         % > READFILE Read a local file into raw bytes.
         absPath = string(path);
         fid = fopen(absPath, 'rb');
         raw = fread(fid, Inf, '*uint8');
         fclose(fid);
         [~, ~, ext] = fileparts(absPath);
      end

      function [raw, ext] = downloadUrl(url)
         % > DOWNLOADURL Download a URL to a temp file, read raw bytes.
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
         % > COMPUTEHASH Pure-MATLAB fingerprint. No Java.
         data = uint8(data(:));
         n = numel(data);
         d = double(data);
         s1 = mod(sum(d .* mod((1:n)', 65521)), 2^52);
         s2 = mod(sum(d .* mod((1:n)' * 31, 65497)), 2^52);
         h = sprintf('%x%013x%013x', n, s1, s2);
      end

      function mime = mimeFromExt(ext)
         % > MIMEFROMEXT Map file extension to MIME type.
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

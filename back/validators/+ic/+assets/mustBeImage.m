function mustBeImage(asset)
   % > MUSTBEIMAGE Validates that an asset is a valid image source.
   %
   % Use as a property validator after implicit conversion:
   %   Source ic.asset.Asset {ic.assets.mustBeImage} = ic.asset.Asset()
   %
   % Accepts:
   %   - empty: no image
   %   - file: must have image extension
   %
   % Rejects name-type assets (Lucide icons are not images).
   if asset.Type == ""
      return
   end
   if asset.Type == "name"
      error('ic:assets:InvalidImage', ...
         'Image source must be a file or URL, not a name ("%s")', ...
         asset.Value);
   end
   if asset.Type == "url"
      return
   end
   % file → check extension
   validExts = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ...
                ".webp", ".svg", ".ico"];
   [~, ~, ext] = fileparts(asset.Value);
   if ~ismember(lower(ext), validExts)
      error('ic:assets:InvalidImage', ...
         'Image must be one of %s, got "%s"', ...
         strjoin(validExts, ", "), ext);
   end
end

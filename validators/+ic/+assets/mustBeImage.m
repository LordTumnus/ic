function mustBeImage(asset)
% validate that an asset is a valid image source.
% Accepts empty (no image), file (must have image extension), or url
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

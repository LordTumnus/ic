function mustBeIcon(asset)
% validate that an asset is a valid icon source.
% Accepts empty (no icon), name (Lucide), or file/url with .svg extension.

   if asset.Type == ""
      return
   end
   if asset.Type == "name"
      return   % lucide format already validated by ic.Asset constructor
   end
   [~, ~, ext] = fileparts(asset.Value);
   ext = lower(regexprep(ext, '\?.*$', ''));
   if ext ~= ".svg"
      error('ic:assets:InvalidIcon', ...
         'Icon source must be .svg, got "%s"', ext);
   end
end

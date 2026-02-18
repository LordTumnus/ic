function mustBeIcon(asset)
   % > MUSTBEICON Validates that an asset is a valid icon source.
   %
   % Use as a property validator after implicit conversion:
   %   Source ic.Asset {ic.assets.mustBeIcon} = ic.asset.Asset("info")
   %
   % Accepts:
   %   - empty: no icon
   %   - name: Lucide icon name (resolved on frontend)
   %   - file: must be .svg
   %   - url: must end in .svg (query string stripped)
   %
   % Rejects file/url assets with non-SVG extensions.
   if asset.Type == "" || asset.Type == "name"
      return
   end
   [~, ~, ext] = fileparts(asset.Value);
   ext = lower(regexprep(ext, '\?.*$', ''));
   if ext ~= ".svg"
      error('ic:assets:InvalidIcon', ...
         'Icon source must be .svg, got "%s"', ext);
   end
end

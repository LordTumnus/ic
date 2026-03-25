function mustBeIconOrImage(asset)
% validate that an asset is a valid icon or image.
% Accepts anything that passes #ic.assets.mustBeIcon or #ic.assets.mustBeImage

   try
      ic.assets.mustBeIcon(asset);
      return
   catch
   end
   try
      ic.assets.mustBeImage(asset);
      return
   catch
   end
   error('ic:assets:InvalidIconOrImage', ...
      'Asset must be a valid icon (.svg, Lucide name) or image, got type="%s" value="%s"', ...
      asset.Type, asset.Value);
end

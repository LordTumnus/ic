function mustBeIconOrImage(asset)
   % > MUSTBEICONORIMAGE Validates that an asset is a valid icon or image.
   %
   % Use as a property validator after implicit conversion:
   %   Icon ic.asset.Asset {ic.assets.mustBeIconOrImage} = ic.asset.Asset()
   %
   % Accepts anything that passes mustBeIcon OR mustBeImage.
   % Lucide name format is validated by ic.asset.Asset constructor.
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

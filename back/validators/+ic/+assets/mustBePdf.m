function mustBePdf(asset)
   % > MUSTBEPDF Validates that an asset is a valid PDF source.
   %
   % Use as a property validator after implicit conversion:
   %   Value ic.asset.Asset {ic.assets.mustBePdf} = ic.asset.Asset()
   %
   % Accepts:
   %   - empty: no document
   %   - file: must have .pdf extension
   %   - url: accepted (assumes PDF content)
   %
   % Rejects name-type assets (Lucide icons are not PDFs).
   if asset.Type == ""
      return
   end
   if asset.Type == "name"
      error('ic:assets:InvalidPdf', ...
         'PDF source must be a file or URL, not a name ("%s")', ...
         asset.Value);
   end
   if asset.Type == "url"
      return
   end
   % file -> check extension
   [~, ~, ext] = fileparts(asset.Value);
   if ~strcmpi(ext, ".pdf")
      error('ic:assets:InvalidPdf', ...
         'PDF source must be a .pdf file, got "%s"', ext);
   end
end

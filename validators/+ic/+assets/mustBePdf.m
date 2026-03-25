function mustBePdf(asset)
% validate that an asset is a valid PDF source.
% Accepts empty (no document), file (must be .pdf), or url
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
   % file → check extension
   [~, ~, ext] = fileparts(asset.Value);
   if ~strcmpi(ext, ".pdf")
      error('ic:assets:InvalidPdf', ...
         'PDF source must be a .pdf file, got "%s"', ext);
   end
end

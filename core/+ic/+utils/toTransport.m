function out = toTransport(data)
% recursively convert MATLAB data to bridge-ready form.
% Walks any MATLAB value and produces structs/cells with char/double/logical
% leaves that sendEventToHTMLSource can transmit directly as JS objects.
%
% {note}
% conversion rules:
%   - #ic.event.TransportData → call toStruct(), recurse result
%   - struct        → recurse each field
%   - cell          → recurse each element
%   - string scalar → char
%   - string array  → cell of char
%   - string.empty  → [] (JS null)
%   - Inf scalar    → [] (JS null)
%   - containers.Map→ struct (hyphens → underscores in keys)
%   - table         → cell array of row structs (recurse cell values)
%   - datetime      → char
%   - categorical   → char
%   - everything else (double, logical, char, uint8, …) → pass through
% {/note}

   % fast base cases (no allocation)
   if ischar(data) || islogical(data)
      out = data;
      return
   end

   if isnumeric(data)
      if isscalar(data) && isinf(data)
         out = [];
      else
         out = data;
      end
      return
   end

   % string → char
   if isstring(data)
      if isempty(data)
         out = [];
      elseif isscalar(data)
         out = char(data);
      else
         out = cellfun(@char, cellstr(data), 'UniformOutput', false);
      end
      return
   end

   % TransportData protocol (Asset, Node, Column, Entry, Theme, …)
   if isa(data, 'ic.event.TransportData')
      if isscalar(data)
         out = ic.utils.toTransport(data.toStruct());
      else
         n = numel(data);
         c = cell(1, n);
         for ii = 1:n
            c{ii} = ic.utils.toTransport(data(ii).toStruct());
         end
         out = c;
      end
      return
   end

   % containers.Map → struct (sanitize keys)
   if isa(data, 'containers.Map')
      keys = data.keys();
      out = struct();
      for ii = 1:numel(keys)
         k = keys{ii};
         fieldName = matlab.lang.makeValidName(k);
         out.(fieldName) = ic.utils.toTransport(data(k));
      end
      return
   end

   % struct (scalar or array) → recurse fields
   if isstruct(data)
      fns = fieldnames(data);
      for ii = 1:numel(data)
         for jj = 1:numel(fns)
            data(ii).(fns{jj}) = ic.utils.toTransport(data(ii).(fns{jj}));
         end
      end
      out = data;
      return
   end

   % cell → recurse elements
   if iscell(data)
      for ii = 1:numel(data)
         data{ii} = ic.utils.toTransport(data{ii});
      end
      out = data;
      return
   end

   % MATLAB table → cell array of row structs (recurse cell values)
   if istable(data)
      vars = data.Properties.VariableNames;
      n = height(data);
      rows = cell(n, 1);
      for ii = 1:n
         row = struct();
         for jj = 1:numel(vars)
            val = data.(vars{jj})(ii, :);
            if iscell(val) && isscalar(val)
               val = val{1};
            end
            row.(vars{jj}) = ic.utils.toTransport(val);
         end
         rows{ii} = row;
      end
      out = rows;
      return
   end

   % datetime → char
   if isa(data, 'datetime')
      if isscalar(data)
         out = char(string(data));
      else
         out = cellfun(@(d) char(string(d)), num2cell(data), 'UniformOutput', false);
      end
      return
   end

   % categorical → char
   if iscategorical(data)
      if isscalar(data)
         out = char(string(data));
      else
         out = cellfun(@char, cellstr(data), 'UniformOutput', false);
      end
      return
   end

   % fallback: pass through
   out = data;
end

classdef (Abstract, HandleCompatible) TransportData
   % > TRANSPORTDATA Abstract base for classes that cross the MATLAB→JS bridge.
   %
   % Subclasses implement toStruct() to produce a plain struct, cell, or
   % scalar that ic.utils.toTransport can send via sendEventToHTMLSource
   % without jsonencode.

   methods (Abstract)
      s = toStruct(this)
   end
end

classdef (Abstract, HandleCompatible) TransportData
   % protocol superclass for objects that cross the MATLAB → JS bridge.
   % subclasses implement toStruct() to produce a plain struct, cell, or scalar
   % that #ic.utils.toTransport can convert to a bridge-ready payload without
   % calling jsonencode

   methods (Abstract)
      s = toStruct(this)
   end
end

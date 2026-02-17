classdef AssetRegistry < handle
   % > ASSETREGISTRY Singleton per-View dedup tracker.
   % Tracks which asset hashes have been sent to each View, so that
   % repeated references only transmit {hash} instead of the full payload.
   % Single-threaded MATLAB: only one View encodes at a time.

   properties (Constant, Access = private)
      % > INSTANCE Singleton — evaluated once when the class first loads.
      Instance = ic.AssetRegistry()
   end

   properties (Access = private)
      % > VIEWMAP containers.Map: double(view) → containers.Map (sent hashes)
      ViewMap % containers.Map()
      % > CURRENTSENT handle ref to the active View's sent-hash map
      CurrentSent % containers.Map()
   end

   methods (Access = private)
      function this = AssetRegistry()
         this.ViewMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
         this.CurrentSent = containers.Map();
      end

      function cleanup(this, key)
         % > CLEANUP Remove a destroyed View from the map.
         if this.ViewMap.isKey(key)
            this.ViewMap.remove(key);
         end
      end
   end

   methods (Static, Access = private)
      function r = getInstance()
         % > GETINSTANCE Return the singleton.
         r = ic.AssetRegistry.Instance;
      end
   end

   methods (Static, Access = {?ic.core.View})
      function activate(view)
         % > ACTIVATE Set the active View. Creates its sent map on first call.
         r = ic.AssetRegistry.getInstance();
         key = double(view);
         if ~r.ViewMap.isKey(key)
            r.ViewMap(key) = containers.Map();
            addlistener(view, 'ObjectBeingDestroyed', @(~,~) r.cleanup(key));
         end
         r.CurrentSent = r.ViewMap(key);
      end
   end

   methods (Static, Access = {?ic.Asset})
      function tf = hasSent(hash)
         % > HASSENT Check if this hash was already sent to the active View.
         tf = ic.AssetRegistry.getInstance().CurrentSent.isKey(hash);
      end

      function markSent(hash)
         % > MARKSENT Record that this hash has been sent to the active View.
         r = ic.AssetRegistry.getInstance();
         r.CurrentSent(hash) = true;
      end
   end
end

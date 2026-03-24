classdef AssetRegistry < handle
   % per-view (uihtml) asset deduplication tracker.
   % tracks which #ic.asset.Asset hashes have been sent to each #ic.core.View so that repeated references only transmit a {hash} stub instead of the full base64 payload.
   % The #ic.core.View is responsible for activating the registry before encoding assets and for ensuring that view references in the registry are properly cleaned up on destruction.

   properties (Constant, Access = private)
      % singleton instance
      Instance = ic.asset.AssetRegistry()
   end

   properties (Access = private)
      % map from double(view) → containers.Map of sent hashes for that view
      ViewMap % containers.Map

      % handle ref to the currently active view's sent-hash map
      CurrentSent % containers.Map

      % shared URL download cache: URL string → struct(raw, ext, hash)
      UrlCache % containers.Map
   end

   methods (Access = private)
      function this = AssetRegistry()
         this.ViewMap = containers.Map('KeyType', 'double', 'ValueType', 'any');
         this.CurrentSent = containers.Map();
         this.UrlCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
      end

      function cleanup(this, key)
         % remove a destroyed view's sent-hash map.
         if this.ViewMap.isKey(key)
            this.ViewMap.remove(key);
         end
      end
   end

   methods (Static, Access = private)
      function r = getInstance()
         % return the singleton instance.
         r = ic.asset.AssetRegistry.Instance;
      end
   end

   methods (Static, Access = {?ic.core.View})
      function activate(view)
         % set the active view for the current encoding pass.
         % creates the view's sent-hash map on first call and registers a
         % cleanup listener for when the view is destroyed.
         r = ic.asset.AssetRegistry.getInstance();
         key = double(view);
         if ~r.ViewMap.isKey(key)
            r.ViewMap(key) = containers.Map();
            addlistener(view, 'ObjectBeingDestroyed', @(~,~) r.cleanup(key));
         end
         r.CurrentSent = r.ViewMap(key);
      end
   end

   methods (Static, Access = {?ic.asset.Asset})
      function m = getUrlCache()
         % return the shared URL download cache (handle ref, safe to write to).
         m = ic.asset.AssetRegistry.getInstance().UrlCache;
      end

      function tf = hasSent(hash)
         % return true if this hash has already been sent to the active view.
         tf = ic.asset.AssetRegistry.getInstance().CurrentSent.isKey(hash);
      end

      function markSent(hash)
         % record that this hash has been sent to the active view.
         r = ic.asset.AssetRegistry.getInstance();
         r.CurrentSent(hash) = true;
      end
   end
end

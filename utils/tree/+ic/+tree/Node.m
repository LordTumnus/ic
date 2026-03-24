classdef Node < handle & ic.event.TransportData
    % tree node for hierarchical data structures. Nodes form a tree via the #ic.tree.Node.Children property.
    % Children nodes can be added, searched, and removed. These methods use **Positional keys**, that are strings that represent the path to a node in the tree with indices separated by dashes. For example, "1-2-3" for the third child of the second child of the first root node)

    properties
        % display text for this node
        Label (1,1) string

        % icon to be displayed before the label
        Icon ic.asset.Asset {ic.assets.mustBeIconOrImage} = ic.asset.Asset()

        % child nodes
        Children ic.tree.Node = ic.tree.Node.empty

        % arbitrary payload struct
        Data struct
    end

    methods
        function this = Node(label, opts)

            arguments
                % display text
                label (1,1) string
                opts.Icon ic.asset.Asset = ic.asset.Asset()
                opts.Data struct = struct.empty
            end
            this.Label = label;
            this.Icon = opts.Icon;
            this.Data = opts.Data;
        end

        function child = add(this, label, opts)
            % create and attach a child node, returning it
            % {returns} the newly created child #ic.tree.Node {/returns}
            % {example}
            %   fruits = ic.tree.Node("Fruits");
            %   citrus = fruits.add("Citrus", Icon="citrus");
            %   citrus.add("Orange");
            %   citrus.add("Lemon");
            % {/example}
            arguments
                this
                % display text for the new child
                label (1,1) string
                % optional icon for the new child
                opts.Icon ic.asset.Asset = ic.asset.Asset()
                % optional data payload for the new child
                opts.Data struct = struct.empty
            end
            child = ic.tree.Node(label, Icon=opts.Icon, Data=opts.Data);
            this.Children(end+1) = child;
        end

        function node = find(this, label)
            % recursive search by label
            % {returns} the first #ic.tree.Node with a matching label, or empty if not found. Note that labels are not guaranteed to be unique. {/returns}
            % {example}
            %   node = tree.find("Target Label");
            % {/example}
            arguments
                this
                % label to search for
                label (1,1) string
            end
            node = ic.tree.Node.empty;
            for i = 1:numel(this)
                if this(i).Label == label
                    node = this(i); return;
                end
                if ~isempty(this(i).Children)
                    node = this(i).Children.find(label);
                    if ~isempty(node), return; end
                end
            end
        end

        function node = remove(this, key)
            % remove a node by positional key, returning it
            % {returns} the removed #ic.tree.Node {/returns}
            % {example}
            %   removedNode = tree.remove("1-2-3");
            % {/example}
            arguments
                this
                % positional key of the node to remove
                key (1,1) string
            end
            parts = sscanf(key, '%d-');
            assert(numel(parts) >= 2, "ic:tree:Node:CannotRemoveRoot", ...
                "Cannot remove a root node by key. Reassign the array instead.");
            parent = this(parts(1));
            for j = 2:numel(parts)-1
                parent = parent.Children(parts(j));
            end
            node = parent.Children(parts(end));
            parent.Children(parts(end)) = [];
        end

        function node = resolve(this, key)
            % find a node by positional key
            % {returns} the #ic.tree.Node at the specified key {/returns}
            % {example}
            %   node = tree.resolve("1-2-3");
            % {/example}
            arguments
                this
                % positional key of the node to find
                key (1,1) string
            end
            parts = sscanf(key, '%d-');
            node = this(parts(1));
            for j = 2:numel(parts)
                node = node.Children(parts(j));
            end
        end

        function s = toStruct(this)
            if isempty(this)
                s = struct('label', {}, 'icon', {}, ...
                           'children', {}, 'data', {});
                return;
            end
            c = arrayfun(@nodeToScalar, this, 'UniformOutput', false);
            s = [c{:}];
        end

        function json = jsonencode(this, varargin)
            json = jsonencode(this.toStruct(), varargin{:});
        end

        function key = keyOf(this, target)
            % find the positional key of a node
            % {returns} the positional key of the first occurrence of the target node {/returns}
            % {example}
            %   tree = ic.tree.Node("Root");
            %   child = tree.add("Child");
            %   key = tree.keyOf(child);
            % {/example}
            arguments
                this
                % target node to find
                target (1,1) ic.tree.Node
            end
            key = findKeyOf(this, target, "");
        end
    end
end

function key = findKeyOf(nodes, target, prefix)
    key = string.empty;
    for i = 1:numel(nodes)
        if prefix == ""
            currentKey = string(i);
        else
            currentKey = prefix + string(i);
        end
        if nodes(i) == target
            key = currentKey; return;
        end
        if ~isempty(nodes(i).Children)
            key = findKeyOf(nodes(i).Children, target, currentKey + "-");
            if ~isempty(key), return; end
        end
    end
end

function s = nodeToScalar(n)
    if isempty(n.Children)
        ch = [];
    else
        ch = n.Children.toStruct();
    end
    if isempty(n.Data)
        d = struct();
    else
        d = n.Data;
    end
    s = struct('label', n.Label, 'icon', n.Icon, 'children', ch, 'data', d);
end

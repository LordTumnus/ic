classdef Node < handle
    % > NODE Tree node for hierarchical data structures.
    %
    %   fruits = ic.tree.Node("Fruits");
    %   citrus = fruits.add("Citrus", Icon="citrus");
    %   citrus.add("Orange");
    %   citrus.add("Lemon");

    properties
        % > LABEL display text for this node
        Label (1,1) string

        % > ICON icon for this node
        Icon ic.IconType = ic.IconType.empty

        % > CHILDREN child nodes
        Children ic.tree.Node = ic.tree.Node.empty

        % > DATA arbitrary payload (column values for TreeTable, etc.)
        Data struct
    end

    methods
        function this = Node(label, opts)
            % > NODE Construct a tree node.
            %   n = ic.tree.Node("Fruits")
            %   n = ic.tree.Node("Fruits", Icon=ic.IconType.lucide("apple"))
            %   n = ic.tree.Node("Fruits", Data=struct('weight', 42))
            arguments
                label (1,1) string
                opts.Icon = ic.IconType.empty
                opts.Data struct = struct.empty
            end
            this.Label = label;
            this.Icon = opts.Icon;
            this.Data = opts.Data;
        end

        function child = add(this, label, opts)
            % > ADD Create and attach a child node, returning it.
            arguments
                this
                label (1,1) string
                opts.Icon = ic.IconType.empty
                opts.Data struct = struct.empty
            end
            child = ic.tree.Node(label, Icon=opts.Icon, Data=opts.Data);
            this.Children(end+1) = child;
        end

        function node = find(this, label)
            % > FIND Recursive search by Label, returns first match or empty.
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
            % > REMOVE Remove a node by positional key, returning it.
            %
            % The key must have at least 2 parts (cannot remove root nodes
            % from the array — reassign the array instead).
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
            % > RESOLVE Navigate to a node by positional key.
            parts = sscanf(key, '%d-');
            node = this(parts(1));
            for j = 2:numel(parts)
                node = node.Children(parts(j));
            end
        end

        function s = toStruct(this)
            % > TOSTRUCT Serialize to plain struct array for JSON.
            if isempty(this)
                s = struct('label', {}, 'icon', {}, ...
                           'children', {}, 'data', {});
                return;
            end
            c = arrayfun(@nodeToScalar, this, 'UniformOutput', false);
            s = [c{:}];
        end

        function json = jsonencode(this, varargin)
            % > JSONENCODE Serialize to JSON string.
            json = jsonencode(this.toStruct(), varargin{:});
        end

        function key = keyOf(this, target)
            % > KEYOF Find the positional key of a node by handle identity.
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
    if isempty(n.Icon), icon = [];
    else, icon = struct('type', n.Icon.Type, 'value', n.Icon.Value);
    end
    if isempty(n.Children), ch = [];
    else, ch = n.Children.toStruct();
    end
    if isempty(n.Data), d = struct();
    else, d = n.Data;
    end
    s = struct('label', n.Label, 'icon', icon, 'children', ch, 'data', d);
end

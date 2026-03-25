classdef DeveloperTools < ic.core.ComponentContainer & ic.mixin.Requestable
    % Chrome DevTools–style inspector for IC components.
    % Renders the inspected component on the left as a static child and a tabbed inspector panel on the right with Properties, Events,
    % Methods, Styles, DOM, and Console tabs.
    % The frontend fetches component metadata via the request
    % and can live-edit properties, apply CSS styles, and evaluate MATLAB
    % commands in a sandboxed console workspace.


    properties (SetAccess = immutable, Hidden)
        % component being inspected
        InspectedComponent  ic.core.ComponentBase
    end

    properties (Access = private)
        % persists user-defined variables across console eval calls within this session
        ConsoleWorkspace struct = struct()
    end

    methods
        function this = DeveloperTools(component, props)
            arguments
                % component to inspect
                component (1,1) ic.core.ComponentBase
                props.?ic.internal.DeveloperTools
                props.ID (1,1) string = "ic-devtools-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.InspectedComponent = component;

            this.addStaticChild(component, "component");

            % register request handlers for the inspector frontend
            this.onRequest("getComponentInfo", @(comp, ~) comp.handleGetComponentInfo());
            this.onRequest("setNestedProp", @(comp, data) comp.handleSetNestedProp(data));
            this.onRequest("setStyle", @(comp, data) comp.handleSetStyle(data));
            this.onRequest("eval", @(comp, data) comp.handleEval(data));
        end
    end

    methods (Access = private)
        function result = handleEval(this, data)
            % evaluate a MATLAB command in the console workspace.
            % The workspace merges base workspace variables with
            % console-local variables from prior commands
            command = string(data.command);
            try
                [output, this.ConsoleWorkspace] = ic.internal.evalConsole( ...
                    command, this.InspectedComponent, this.ConsoleWorkspace);
                % strip MATLAB hyperlinks: <a href="matlab:...">text</a> → text
                output = regexprep(output, '<a\s[^>]*>', '');
                output = strrep(output, '</a>', '');
                result = struct('output', char(strtrim(output)), 'isError', false);
            catch ex
                result = struct('output', char(ex.message), 'isError', true);
            end
        end

        function result = handleGetComponentInfo(this)
            % return the full reactive API metadata tree for the inspected component.
            result = this.getInfoForComponent(this.InspectedComponent);
        end

        function info = getInfoForComponent(this, comp)
            % recursively introspect a component's reactive API.
            % returns a struct with componentType, componentId, properties, events,
            % methods, mixins, isStylable, and children (recursive for containers).
            mc = meta.class.fromName(class(comp));

            % reactive properties
            metaProps = mc.PropertyList;
            reactiveFilter = strcmp({metaProps.Description}, "Reactive") ...
                & [metaProps.SetObservable];
            reactiveProps = metaProps(reactiveFilter);

            propInfos = cell(1, numel(reactiveProps));
            for ii = 1:numel(reactiveProps)
                mp = reactiveProps(ii);
                propInfos{ii} = struct( ...
                    'name',       char(ic.utils.toCamelCase(mp.Name)), ...
                    'matlabName', char(mp.Name), ...
                    'type',       char(class(comp.(mp.Name))), ...
                    'validation', this.extractValidation(mp), ...
                    'hidden',     mp.Hidden, ...
                    'readOnly',   ~isequal(mp.SetAccess, 'public'), ...
                    'typeInfo',   this.introspectType(comp.(mp.Name)));
            end

            % reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(strcmp({metaEvents.Description}, "Reactive"));
            eventInfos = cell(1, numel(reactiveEvents));
            for jj = 1:numel(reactiveEvents)
                eventInfos{jj} = struct( ...
                    'name',       char(ic.utils.toCamelCase(reactiveEvents(jj).Name)), ...
                    'matlabName', char(reactiveEvents(jj).Name));
            end

            % reactive methods
            metaMethods = mc.MethodList;
            reactiveMethods = metaMethods(strcmp({metaMethods.Description}, "Reactive"));
            methodInfos = cell(1, numel(reactiveMethods));
            for kk = 1:numel(reactiveMethods)
                mm = reactiveMethods(kk);
                methodInfos{kk} = struct( ...
                    'name',       char(ic.utils.toCamelCase(mm.Name)), ...
                    'matlabName', char(mm.Name), ...
                    'nInputs',    numel(mm.InputNames) - 1);
            end

            % mixins
            allSupers = string(superclasses(class(comp)));
            mixinMask = startsWith(allSupers, "ic.mixin.");
            mixins = lower(extractAfter(allSupers(mixinMask), "ic.mixin."));

            % children (recursive for containers)
            childInfos = {};
            if isa(comp, 'ic.core.Container')
                for tt = 1:numel(comp.Targets)
                    target = comp.Targets(tt);
                    kids = comp.getChildrenInTarget(target);
                    for cc = 1:numel(kids)
                        ci = this.getInfoForComponent(kids(cc));
                        ci.target = char(target);
                        childInfos{end+1} = ci; %#ok<AGROW>
                    end
                end
            end

            info = struct( ...
                'componentType', char(class(comp)), ...
                'componentId',   char(comp.ID), ...
                'properties',    {propInfos}, ...
                'events',        {eventInfos}, ...
                'methods',       {methodInfos}, ...
                'mixins',        {cellstr(mixins)}, ...
                'isStylable',    isa(comp, 'ic.mixin.Stylable'), ...
                'children',      {childInfos});
        end

        function info = extractValidation(~, metaProp)
            % extract mustBeMember enum values from the class source for a property.
            info = struct();
            try
                classFile = which(metaProp.DefiningClass.Name);
                if isempty(classFile), return; end
                src = string(fileread(classFile));
                % collapse line continuations so multi-line validators match
                src = regexprep(src, '\.\.\.\s*\n\s*', ' ');
                propName = metaProp.Name;

                pat = propName + "\s*.*?mustBeMember\(" + propName + ",\s*\[([^\]]+)\]";
                tokens = regexp(src, pat, 'tokens');
                if ~isempty(tokens)
                    members = regexp(tokens{1}{1}, '"([^"]*)"', 'tokens');
                    info.mustBeMember = cellfun(@(c) c{1}, members, ...
                        'UniformOutput', false);
                end
            catch
            end
        end

        function typeInfo = introspectType(this, value, depth)
            % recursively describe a value's structure for the property editor.
            % returns a struct with kind, className, size, children, and
            % elementTypeInfo. Depth-limited to 4 levels to prevent infinite loops.
            arguments
                this
                value
                depth (1,1) double = 0
            end
            MAX_DEPTH = 4;
            cls = char(class(value));
            typeInfo = struct('kind', 'primitive', 'className', cls, ...
                'size', size(value), 'children', {{}}, 'elementTypeInfo', []);

            % function handles are opaque (not serializable)
            if isa(value, 'function_handle')
                typeInfo.kind = 'function_handle';
                return;
            end

            % complex base types with special subscripting (table, datetime, …)
            if this.isOpaqueType(value)
                typeInfo.kind = 'opaque';
                return;
            end

            % primitives: numeric, logical, string, char, OnOffSwitchState, Asset
            if this.isPrimitiveValue(value)
                if ~isscalar(value) && ~ischar(value)
                    typeInfo.kind = 'array';
                    typeInfo.elementTypeInfo = struct('kind', 'primitive', ...
                        'className', cls, 'size', [1 1], ...
                        'children', {{}}, 'elementTypeInfo', []);
                end
                return;
            end

            % empty non-primitive
            if isempty(value)
                if isstruct(value), typeInfo.kind = 'struct'; end
                return;
            end

            % depth limit
            if depth >= MAX_DEPTH
                typeInfo.kind = 'truncated';
                return;
            end

            % struct
            if isstruct(value)
                if isscalar(value)
                    typeInfo.kind = 'struct';
                    fnames = fieldnames(value);
                    children = cell(1, numel(fnames));
                    for i = 1:numel(fnames)
                        children{i} = struct('key', fnames{i}, ...
                            'typeInfo', this.introspectType(value.(fnames{i}), depth + 1));
                    end
                    typeInfo.children = children;
                else
                    typeInfo.kind = 'structArray';
                    typeInfo.elementTypeInfo = this.introspectType(value(1), depth + 1);
                end
                return;
            end

            % cell array
            if iscell(value)
                typeInfo.kind = 'cell';
                n = min(numel(value), 50);
                children = cell(1, n);
                for i = 1:n
                    children{i} = struct('key', '', 'index', i - 1, ...
                        'typeInfo', this.introspectType(value{i}, depth + 1));
                end
                typeInfo.children = children;
                return;
            end

            % object (non-primitive, non-struct, non-cell)
            if isobject(value)
                if isscalar(value)
                    typeInfo.kind = 'object';
                    mc = meta.class.fromName(class(value));
                    allProps = mc.PropertyList;
                    pubMask = arrayfun(@(p) isequal(p.GetAccess, 'public') && ~p.Hidden, allProps);
                    pub = allProps(pubMask);
                    children = cell(1, numel(pub));
                    for i = 1:numel(pub)
                        try
                            pval = value.(pub(i).Name);
                        catch
                            pval = '<<error>>';
                        end
                        childStruct = struct('key', char(pub(i).Name), ...
                            'typeInfo', this.introspectType(pval, depth + 1));
                        v = this.extractValidation(pub(i));
                        if ~isempty(fieldnames(v))
                            childStruct.validation = v;
                        end
                        children{i} = childStruct;
                    end
                    typeInfo.children = children;
                else
                    typeInfo.kind = 'objectArray';
                    % introspect each element individually (heterogeneous
                    % arrays like ic.table.Column have different subclasses)
                    n = min(numel(value), 50);
                    children = cell(1, n);
                    for i = 1:n
                        children{i} = struct('key', '', 'index', i - 1, ...
                            'typeInfo', this.introspectType(value(i), depth + 1));
                    end
                    typeInfo.children = children;
                end
                return;
            end
        end

        function tf = isPrimitiveValue(~, value)
            % true for types the frontend property editor can display and edit directly.
            tf = isnumeric(value) || islogical(value) || ...
                isstring(value) || ischar(value) || ...
                isa(value, 'matlab.lang.OnOffSwitchState') || ...
                isa(value, 'ic.Asset');
        end

        function tf = isOpaqueType(~, value)
            % true for complex base types that should not be recursively
            % introspected (special subscripting, non-serializable, etc.).
            tf = istable(value) || istimetable(value) || ...
                isdatetime(value) || isduration(value) || ...
                iscalendarduration(value) || iscategorical(value) || ...
                isa(value, 'containers.Map');
        end

        function value = coerceValue(~, value, currentVal)
            % match the incoming JSON value to the MATLAB type of the target
            % property. The JSON bridge delivers JS types that may not match
            % (e.g. logical arrives as 0/1 double).
            if islogical(currentVal)
                value = logical(value);
            elseif isnumeric(currentVal) && (ischar(value) || isstring(value))
                value = str2double(value);
            elseif isstring(currentVal) && ~isstring(value)
                value = string(value);
            elseif ischar(currentVal) && ~ischar(value)
                value = char(string(value));
            end
        end

        function result = handleSetStyle(this, data)
            % apply CSS styles to a component via the #ic.mixin.Stylable mixin.
            % handles both regular properties and CSS custom properties (--var).
            % data fields: componentId, selector, properties (struct), cssVariables
            % (optional struct array with name/value pairs).
            comp = this.resolveComponent(data.componentId);
            if ~isa(comp, 'ic.mixin.Stylable')
                error('ic:devtools:notStylable', ...
                    'Component "%s" does not support styling.', class(comp));
            end

            selector = string(data.selector);
            hasRegular = isfield(data, 'properties') ...
                && ~isempty(fieldnames(data.properties));
            hasCssVars = isfield(data, 'cssVariables') ...
                && ~isempty(data.cssVariables);

            % regular properties go through the normal style() path
            if hasRegular
                comp.style(selector, data.properties);
            end

            % CSS custom properties (--var) can't be MATLAB struct fields.
            % build the full CSS map from internal state + variables and
            % re-publish the @style event directly.
            if hasCssVars
                existing = comp.getStyle(selector);
                fnames = fieldnames(existing);
                if ~isempty(fnames)
                    kk = cellfun(@(f) char(ic.utils.toKebabCase(f)), ...
                        fnames, 'UniformOutput', false);
                    vv = cellfun(@(f) existing.(f), fnames, ...
                        'UniformOutput', false);
                    cssMap = containers.Map(kk, vv);
                else
                    cssMap = containers.Map( ...
                        'KeyType', 'char', 'ValueType', 'any');
                end

                vars = data.cssVariables;
                if isstruct(vars), vars = num2cell(vars); end
                for ii = 1:numel(vars)
                    if iscell(vars), v = vars{ii}; else, v = vars(ii); end
                    varName = char(string(v.name));
                    varValue = string(v.value);
                    if varValue == ""
                        if cssMap.isKey(varName)
                            remove(cssMap, varName);
                        end
                    else
                        cssMap(varName) = char(varValue);
                    end
                end

                comp.publish("@style", struct( ...
                    "selector", selector, ...
                    "styles", cssMap));
            end

            result = struct('success', true);
        end

        function result = handleSetNestedProp(this, data)
            % set a possibly nested property on a component from the property editor.
            % data fields: componentId, propName (PascalCase), path (cell array of
            % {key:""} or {index:N} segments for nested access), value.
            comp = this.resolveComponent(data.componentId);

            propName = string(data.propName);
            path = data.path;

            if isempty(path)
                currentVal = comp.(propName);
                comp.(propName) = this.coerceValue(data.value, currentVal);
            else
                currentVal = comp.(propName);
                % build subsasgn S-struct from path segments.
                % jsondecode delivers struct array (homogeneous) or cell
                % array (heterogeneous), so index with {} or () accordingly.
                S = struct('type', {}, 'subs', {});
                for i = 1:numel(path)
                    if iscell(path), seg = path{i}; else, seg = path(i); end
                    if isfield(seg, 'key') && ~isempty(seg.key)
                        S(end + 1) = struct('type', '.', 'subs', seg.key); %#ok<AGROW>
                    elseif isfield(seg, 'index')
                        S(end + 1) = struct('type', '()', 'subs', {{seg.index + 1}}); %#ok<AGROW>
                    end
                end
                leafVal = subsref(currentVal, S);
                comp.(propName) = subsasgn(currentVal, S, ...
                    this.coerceValue(data.value, leafVal));
            end
            result = struct('success', true);
        end

        function comp = resolveComponent(this, componentId)
            % find a component by ID in the inspected subtree.
            root = this.InspectedComponent;
            if isempty(componentId) || componentId == ""
                comp = root;
                return;
            end
            if root.ID == string(componentId)
                comp = root;
                return;
            end
            comp = this.searchChildren(root, string(componentId));
            if isempty(comp)
                error('ic:devtools:notFound', ...
                    'Component "%s" not found.', componentId);
            end
        end

        function comp = searchChildren(this, container, targetId)
            % depth-first search through container children for a component ID.
            comp = [];
            if ~isa(container, 'ic.core.Container'), return; end
            for tt = 1:numel(container.Targets)
                kids = container.getChildrenInTarget(container.Targets(tt));
                for cc = 1:numel(kids)
                    if kids(cc).ID == targetId
                        comp = kids(cc);
                        return;
                    end
                    comp = this.searchChildren(kids(cc), targetId);
                    if ~isempty(comp), return; end
                end
            end
        end
    end
end

classdef DeveloperTools < ic.core.ComponentContainer & ic.mixin.Requestable
    % > DEVELOPERTOOLS Internal IC component for the inspector UI.
    %
    %   Hosts the inspected component as a static child and handles
    %   metadata/style requests from the Svelte frontend.

    properties (SetAccess = immutable, Hidden)
        % > INSPECTEDCOMPONENT the component being inspected
        InspectedComponent  ic.core.ComponentBase
    end

    methods
        function this = DeveloperTools(component, props)
            arguments
                component (1,1) ic.core.ComponentBase
                props.?ic.internal.DeveloperTools
                props.ID (1,1) string = "ic-devtools-" + matlab.lang.internal.uuid()
            end
            this@ic.core.ComponentContainer(props);
            this.InspectedComponent = component;

            this.addStaticChild(component, "component");

            this.onRequest("getComponentInfo",  @(comp, ~)    comp.handleGetComponentInfo());
            this.onRequest("setPropertyValue",  @(comp, data) comp.handleSetPropertyValue(data));
            this.onRequest("getStyles",         @(comp, ~)    comp.handleGetStyles());
            this.onRequest("setStyle",          @(comp, data) comp.handleSetStyle(data));
            this.onRequest("removeStyle",       @(comp, data) comp.handleRemoveStyle(data));
        end
    end

    methods (Access = private)
        function result = handleGetComponentInfo(this)
            comp = this.InspectedComponent;
            mc = meta.class.fromName(class(comp));

            % Reactive properties
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
                    'hidden',     mp.Hidden);
            end

            % Reactive events
            metaEvents = mc.EventList;
            reactiveEvents = metaEvents(strcmp({metaEvents.Description}, "Reactive"));
            eventInfos = cell(1, numel(reactiveEvents));
            for jj = 1:numel(reactiveEvents)
                eventInfos{jj} = struct( ...
                    'name',       char(ic.utils.toCamelCase(reactiveEvents(jj).Name)), ...
                    'matlabName', char(reactiveEvents(jj).Name));
            end

            % Reactive methods
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

            % Mixins
            allSupers = string(superclasses(class(comp)));
            mixinMask = startsWith(allSupers, "ic.mixin.");
            mixins = lower(extractAfter(allSupers(mixinMask), "ic.mixin."));

            result = struct( ...
                'componentType', char(class(comp)), ...
                'componentId',   char(comp.ID), ...
                'properties',    {propInfos}, ...
                'events',        {eventInfos}, ...
                'methods',       {methodInfos}, ...
                'mixins',        {cellstr(mixins)}, ...
                'isStylable',    isa(comp, 'ic.mixin.Stylable'));
        end

        function result = handleSetPropertyValue(this, data)
            comp = this.InspectedComponent;
            propName = string(data.matlabName);
            value = data.value;
            currentVal = comp.(propName);

            if islogical(currentVal)
                value = logical(value);
            elseif isnumeric(currentVal) && (ischar(value) || isstring(value))
                value = str2double(value);
            elseif isstring(currentVal)
                value = string(value);
            end

            comp.(propName) = value;
            result = true;
        end

        function result = handleGetStyles(this)
            comp = this.InspectedComponent;
            if ~isa(comp, 'ic.mixin.Stylable')
                result = containers.Map();
                return;
            end
            result = comp.getAllStyles();
        end

        function result = handleSetStyle(this, data)
            this.InspectedComponent.style( ...
                string(data.selector), string(data.property), string(data.value));
            result = true;
        end

        function result = handleRemoveStyle(this, data)
            this.InspectedComponent.style( ...
                string(data.selector), string(data.property), "");
            result = true;
        end

        function info = extractValidation(~, metaProp)
            info = struct();
            try
                classFile = which(metaProp.DefiningClass.Name);
                if isempty(classFile), return; end
                src = string(fileread(classFile));
                % Collapse line continuations so multi-line validators match
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
    end
end

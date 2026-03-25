classdef (Abstract) Effectable < handle
    % cross-component reactive expressions that run on the frontend.
    %
    % effects track property reads and re-run automatically when dependencies
    % change. the frontend counterpart compiles expressions into Svelte 5 $effect() runes with reactive component proxies exposing properties, methods, the component's root DOM element, and other metadata

    methods (Abstract, Access = public)
        promise = publish(this, name, data)
    end

    methods (Access = public)
        function effect = jsEffect(this, varargin)
            % creates a reactive expression that runs on the frontend and evaluates with all the components passed as arguments.
            % The expression is the last argument and must be an arrow function whose parameters correspond positionally to the component arguments, and whose body contains the reactive code to run on the frontend. The effect automatically tracks property reads on the component proxies and re-runs whenever those properties change.
            % In Javascript, each component proxy in the expression provides:
            %   .props    - reactive properties
            %   .methods  - callable methods
            %   .el       - root DOM element
            %   .id       - component unique ID
            %   .type     - MATLAB class type
            %
            % {returns} a #ic.effect.JsEffect handle whose remove() method destroys the effect {/returns}
            % {example}
            %   e = slider.jsEffect(progress, ...
            %       "(s, p) => { p.props.value = s.props.value }");
            %
            %   e.remove();
            % {/example}

            arguments (Input)
                this (1,1) ic.mixin.Effectable
            end
            arguments (Input, Repeating)
                varargin
            end

            assert(numel(varargin) >= 1, ...
                "ic:mixin:Effectable:jsEffect", ...
                "jsEffect requires at least an expression");

            expression = string(varargin{end});
            components = varargin(1:end-1);

            % parse arrow function parameter names
            tokens = regexp(expression, ...
                '^\s*\(([^)]*)\)\s*=>', 'tokens', 'once');
            assert(~isempty(tokens), ...
                "ic:mixin:Effectable:jsEffect", ...
                "Expression must be an arrow function: (p1, p2, ...) => { ... }");

            paramStr = strtrim(string(tokens{1}));
            if paramStr == ""
                paramNames = string.empty();
            else
                paramNames = strtrim(split(paramStr, ","));
            end

            % validate parameter count matches component count
            assert(numel(paramNames) == numel(components), ...
                "ic:mixin:Effectable:jsEffect", ...
                "Arrow function has %d parameter(s) but %d component argument(s) were given", ...
                numel(paramNames), numel(components));

            % build component map: paramName → component ID(s)
            componentMap = struct();
            for ii = 1:numel(components)
                comp = components{ii};
                assert(isa(comp, 'ic.core.ComponentBase'), ...
                    "All arguments except the last must be components");

                if isscalar(comp)
                    componentMap.(paramNames(ii)) = comp.ID;
                else
                    ids = strings(1, numel(comp));
                    for jj = 1:numel(comp)
                        ids(jj) = comp(jj).ID;
                    end
                    componentMap.(paramNames(ii)) = ids;
                end
            end

            % generate unique ID and create handle
            effectId = string(matlab.lang.internal.uuid());
            effect = ic.effect.JsEffect(effectId, this);

            % send to frontend
            this.publish("@jsEffect", struct(...
                "id", effectId, ...
                "components", componentMap, ...
                "expression", expression));
        end
    end

end

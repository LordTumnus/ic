% > EFFECTABLE mixin providing reactive JavaScript expressions.
%
% Allows creating cross-component reactive effects that run on the
% frontend. Effects track property reads and re-run automatically
% when dependencies change.
%
%   slider.jsEffect(progress, "(s, p) => { p.props.value = s.props.value }");
%
% Host class must implement:
%   - publish(name, data) — send event to the view (from Publishable)
%   - ID property          — unique component identifier (from ComponentBase)
%
classdef (Abstract) Effectable < handle

    % --- Dependencies (satisfied by the final class) ----------------------
    methods (Abstract, Access = public)
        promise = publish(this, name, data)
    end

    % --- Public API -------------------------------------------------------
    methods (Access = public)
        function effect = jsEffect(this, varargin)
            % > JSEFFECT creates a reactive expression that runs on the frontend.
            %
            % effect = comp.jsEffect(c1, c2, ..., "(p1, p2, ...) => { ... }")
            %
            % Components are mapped positionally to the arrow function
            % parameters. Arrays of components can be passed for a single
            % parameter.
            %
            % Each component proxy in the expression provides:
            %   .props    - Reactive properties (reads tracked, writes sync)
            %   .methods  - Callable methods (untracked, returns Resolution)
            %   .el       - Root DOM element (live getter)
            %   .id       - Component unique ID
            %   .type     - MATLAB class type
            %
            % Examples:
            %   e = slider.jsEffect(progress, ...
            %       "(s, p) => { p.props.value = s.props.value }");
            %
            %   e = f.jsEffect([slider1, slider2], gauge, ...
            %       "(sliders, g) => { g.props.value = sliders[0].props.value }");
            %
            %   e.remove();

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

            % Parse arrow function parameter names
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

            % Validate parameter count matches component count
            assert(numel(paramNames) == numel(components), ...
                "ic:mixin:Effectable:jsEffect", ...
                "Arrow function has %d parameter(s) but %d component argument(s) were given", ...
                numel(paramNames), numel(components));

            % Build component map: paramName → component ID(s)
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

            % Generate unique ID and create handle
            effectId = string(matlab.lang.internal.uuid());
            effect = ic.effect.JsEffect(effectId, this);

            % Send to frontend
            this.publish("@jsEffect", struct(...
                "id", effectId, ...
                "components", componentMap, ...
                "expression", expression));
        end
    end

end

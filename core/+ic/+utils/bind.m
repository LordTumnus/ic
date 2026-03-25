function effect = bind(frame, source, sourceProp, target, targetProp, transform)
    % create a one-way property binding between two components.
    % wraps #ic.Frame.jsEffect with a concise source→target expression.
    %
    % {example}
    %   effect = ic.utils.bind(f, slider, "value", progress, "value")
    %   effect = ic.utils.bind(f, slider, "value", label, "text", "x + '%'")
    % {/example}

    arguments
        % #ic.Frame that owns the binding
        frame (1,1) ic.Frame
        % component whose property drives the binding
        source (1,1) ic.core.ComponentBase
        % camelCase name of the source property
        sourceProp (1,1) string
        % component whose property receives the value
        target (1,1) ic.core.ComponentBase
        % camelCase name of the target property
        targetProp (1,1) string
        % optional JS expression using 'x' as the source value
        transform (1,1) string = "x"
    end

    expr = sprintf("target.props.%s = (%s)", targetProp, ...
        strrep(transform, "x", sprintf("source.props.%s", sourceProp)));
    effect = frame.jsEffect(source, target, expr);
end

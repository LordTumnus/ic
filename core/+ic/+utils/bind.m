function effect = bind(frame, source, sourceProp, target, targetProp, transform)
    % > BIND creates a one-way property binding (convenience wrapper for jsEffect).
    %
    % effect = ic.utils.bind(f, slider, "value", progress, "value")
    % effect = ic.utils.bind(f, slider, "value", label, "text", "x + '%'")
    %
    % Arguments:
    %   transform - Optional JS expression using 'x' as the source value

    arguments
        frame (1,1) ic.Frame
        source (1,1) ic.core.ComponentBase
        sourceProp (1,1) string
        target (1,1) ic.core.ComponentBase
        targetProp (1,1) string
        transform (1,1) string = "x"
    end

    expr = sprintf("target.props.%s = (%s)", targetProp, ...
        strrep(transform, "x", sprintf("source.props.%s", sourceProp)));
    effect = frame.jsEffect(source, target, expr);
end

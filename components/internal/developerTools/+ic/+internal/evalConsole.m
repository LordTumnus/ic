function [output, ws] = evalConsole(command, comp, ws)
    % > EVALCONSOLE evaluate a command with comp and workspace variables.
    %
    %   [output, ws] = ic.internal.evalConsole(command, comp, ws)
    %
    %   Unpacks all fields of ws into local variables, then imports base
    %   workspace variables (without overwriting ws fields or comp), runs
    %   evalc(command), and rebuilds ws from non-reserved local variables.
    %
    %   Variable priority (highest wins):
    %     1. comp          — always the inspected component
    %     2. ws fields     — console-local variables from prior commands
    %     3. base workspace — read-only import of user's base workspace
    %
    %   New/modified variables are saved into ws (not back to base).
    arguments
        command (1,1) string
        comp    (1,1) ic.core.ComponentBase %#ok used dynamically via evalc
        ws      (1,1) struct
    end

    reservedNames__ = {'command', 'comp', 'ws', 'output', ...
        'reservedNames__', 'fieldNames__', 'ii__', 'allVars__', 'jj__', ...
        'baseVars__', 'baseNames__'};

    % Import base workspace variables (lowest priority)
    baseVars__ = evalin('base', 'whos');
    baseNames__ = {baseVars__.name};
    fieldNames__ = fieldnames(ws);
    for ii__ = 1:numel(baseNames__)
        % Skip reserved names and anything already in ws (ws takes priority)
        if ~ismember(baseNames__{ii__}, reservedNames__) ...
                && ~ismember(baseNames__{ii__}, fieldNames__)
            eval([baseNames__{ii__} ' = evalin(''base'', ''' baseNames__{ii__} ''');']);
        end
    end

    % Unpack console workspace fields (higher priority, overwrites base vars)
    for ii__ = 1:numel(fieldNames__)
        if ~ismember(fieldNames__{ii__}, reservedNames__)
            eval([fieldNames__{ii__} ' = ws.' fieldNames__{ii__} ';']);
        end
    end

    % Evaluate the command, capturing printed output
    output = evalc(command);

    % Rebuild ws from current locals (handles new vars + cleared vars)
    ws = struct();
    allVars__ = setdiff(who, [reservedNames__, baseNames__]);
    for jj__ = 1:numel(allVars__)
        ws.(allVars__{jj__}) = eval(allVars__{jj__});
    end
end

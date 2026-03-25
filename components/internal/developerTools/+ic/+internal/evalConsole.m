function [output, ws] = evalConsole(command, comp, ws)
% evaluate a MATLAB command in a sandboxed console workspace. Used by #ic.internal.DeveloperTools to power the Console tab.
%
% Unpacks all fields of the local workspace into local variables, imports base workspace
% variables (without overwriting ws fields or comp), runs evalc(command),
% and rebuilds ws from non-reserved local variables.
%
% variable priority (highest wins):
%   1. comp: always the inspected component
%   2. ws fields: console-local variables from prior commands
%   3. base workspace: read-only import of user's base workspace
%
% new or modified variables are saved into the local workspace, not back to the base one.

    arguments
        command (1,1) string
        comp    (1,1) ic.core.ComponentBase %#ok used dynamically via evalc
        ws      (1,1) struct
    end

    reservedNames__ = {'command', 'comp', 'ws', 'output', ...
        'reservedNames__', 'fieldNames__', 'ii__', 'allVars__', 'jj__', ...
        'baseVars__', 'baseNames__'};

    % import base workspace variables (lowest priority)
    baseVars__ = evalin('base', 'whos');
    baseNames__ = {baseVars__.name};
    fieldNames__ = fieldnames(ws);
    for ii__ = 1:numel(baseNames__)
        % skip reserved names and anything already in ws (ws takes priority)
        if ~ismember(baseNames__{ii__}, reservedNames__) ...
                && ~ismember(baseNames__{ii__}, fieldNames__)
            eval([baseNames__{ii__} ' = evalin(''base'', ''' baseNames__{ii__} ''');']);
        end
    end

    % unpack console workspace fields (higher priority, overwrites base vars)
    for ii__ = 1:numel(fieldNames__)
        if ~ismember(fieldNames__{ii__}, reservedNames__)
            eval([fieldNames__{ii__} ' = ws.' fieldNames__{ii__} ';']);
        end
    end

    % evaluate the command, capturing printed output
    output = evalc(command);

    % rebuild ws from current locals (handles new vars + cleared vars)
    ws = struct();
    allVars__ = setdiff(who, [reservedNames__, baseNames__]);
    for jj__ = 1:numel(allVars__)
        ws.(allVars__{jj__}) = eval(allVars__{jj__});
    end
end

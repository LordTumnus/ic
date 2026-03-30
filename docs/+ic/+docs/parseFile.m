function out = parseFile(name)
% parse a MATLAB class or function file into a documentation struct.
% takes a fully-qualified name (e.g. "ic.Button") and returns a plain
% struct ready for jsonencode, with properties, methods, events, etc.
%
% {example}
%   s = ic.docs.parseFile("ic.Button");
%   disp(s.properties(1).name)   % "Label"
%   disp(s.events(1).name)       % "Clicked"
% {/example}

    arguments
        name (1,1) string
    end

    % resolve file location
    fileName = which(name);
    if isempty(fileName)
        error('ic:docs:parseFile:NotFound', ...
            'Could not find "%s" on the MATLAB path.', name);
    end

    % build the AST with comments
    tree = mtree(fileName, '-file', '-comments', '-cell');

    % check for parse errors
    if tree.count == 1 && strcmp(tree.kind(), 'ERR')
        error('ic:docs:parseFile:ParseError', ...
            'mtree parse error in "%s": %s', name, tree.string);
    end

    % detect class vs function
    cnode = tree.mtfind('Kind', 'CLASSDEF');
    if ~isempty(cnode)
        out = doParseClass(cnode);
        out.fullName = name;
        % add empty function-specific fields for uniform struct shape
        out.inputs    = string.empty();
        out.outputs   = string.empty();
        out.arguments = [];
    else
        % standalone function
        fIdx = indices(tree.mtfind('Kind', 'FUNCTION'));
        if isempty(fIdx)
            error('ic:docs:parseFile:NoContent', ...
                '"%s" contains no class or function.', name);
        end
        fcn = doParseFunction(tree.select(fIdx(1)));
        % wrap in the top-level schema (same fields as classes)
        out = struct( ...
            'name',         fcn.name, ...
            'fullName',     name, ...
            'kind',         "function", ...
            'description',  fcn.description, ...
            'abstract',     false, ...
            'hidden',       false, ...
            'superClasses', string.empty(), ...
            'properties',   [], ...
            'methods',      [], ...
            'events',       [], ...
            'enumerations', [], ...
            'inputs',       fcn.inputs, ...
            'outputs',      fcn.outputs, ...
            'arguments',    fcn.arguments);
    end
end


%% ---- class ----

function c = doParseClass(node)
% parse a classdef node into a struct.

    c = struct( ...
        'name',         "", ...
        'fullName',     "", ...
        'kind',         "class", ...
        'description',  string.empty(), ...
        'abstract',     false, ...
        'hidden',       false, ...
        'superClasses', string.empty(), ...
        'properties',   [], ...
        'methods',      [], ...
        'events',       [], ...
        'enumerations', []);

    % class attributes
    attrs = struct('Hidden', false, 'Abstract', false);
    if ~isempty(node.Cattr)
        attrs = doParseAttributes(node.Cattr.Arg, attrs);
    end
    c.abstract = logical(attrs.Abstract);
    c.hidden   = logical(attrs.Hidden);

    % name and superclasses
    cexpr = node.Cexpr;
    if cexpr.kind == "LT"
        c.superClasses = doParseSuperClasses(cexpr.Right);
        c.name = string(cexpr.Left);
    else
        c.name = string(cexpr);
    end

    % class description (comments right after classdef line)
    line = node.pos2lc(max(cexpr.Tree.endposition));
    body = node.Body;
    while ~isempty(body) && body.kind == "COMMENT" && body.lineno() == line + 1
        c.description(end + 1) = stripComment(string(body));
        line = line + 1;
        body = body.Next;
    end

    tree = node.Tree;

    % properties (flat: block attrs merged into each prop)
    propIdx = tree.mtfind('Kind', 'PROPERTIES').indices();
    for ii = 1:numel(propIdx)
        c.properties = [c.properties, doParseProperties(tree.select(propIdx(ii)))];
    end

    % methods (flat: block attrs merged into each method)
    methIdx = tree.mtfind('Kind', 'METHODS').indices();
    for ii = 1:numel(methIdx)
        c.methods = [c.methods, doParseMethods(tree.select(methIdx(ii)))];
    end

    % events (flat: block attrs merged into each event)
    eventIdx = tree.mtfind('Kind', 'EVENTS').indices();
    for ii = 1:numel(eventIdx)
        c.events = [c.events, doParseEvents(tree.select(eventIdx(ii)))];
    end

    % enumerations
    c.enumerations = doExtractEnumeration(tree);
end


%% ---- properties ----

function props = doParseProperties(ptree)
% parse a properties block; stamp block attrs onto each property.

    attrStruct = struct( ...
        'Description', "", ...
        'Hidden',      false, ...
        'SetAccess',   "public", ...
        'GetAccess',   "public", ...
        'Access',      "public", ...
        'Dependent',   false, ...
        'SetObservable', false, ...
        'AbortSet',    false);

    attr = ptree.Attr;
    if attr.count
        attrStruct = doParseAttributes(attr.Arg, attrStruct);
    end

    desc = strip(string(attrStruct.Description), '"');
    isReactive = desc == "Reactive" && attrStruct.SetObservable;

    if isfield(attrStruct, 'Access') && isstring(attrStruct.Access)
        if string(attrStruct.SetAccess) == "public"
            attrStruct.SetAccess = attrStruct.Access;
        end
        if string(attrStruct.GetAccess) == "public"
            attrStruct.GetAccess = attrStruct.Access;
        end
    end

    props = doParseProperty(ptree.Body);

    for ii = 1:numel(props)
        props(ii).hidden    = logical(attrStruct.Hidden);
        props(ii).reactive  = isReactive;
        props(ii).dependent = logical(attrStruct.Dependent);
        props(ii).setAccess = string(attrStruct.SetAccess);
        props(ii).getAccess = string(attrStruct.GetAccess);
    end
end


function propList = doParseProperty(node)
% parse individual properties from a property block body.

    propList = [];

    while ~isempty(node)
        description = string.empty();
        lines = [];
        while ~isempty(node) && node.kind == "COMMENT"
            lines(end + 1) = node.lineno(); %#ok<AGROW>
            description(end + 1) = stripComment(string(node)); %#ok<AGROW>
            node = node.Next;
        end

        if isempty(node), return, end

        prop = struct( ...
            'name',       "", ...
            'description', string.empty(), ...
            'type',       "", ...
            'size',       string.empty(), ...
            'default',    "", ...
            'enumValues', string.empty(), ...
            'validators', string.empty());

        n = node.Left;
        v = node.Right;

        if strcmp(n.kind, 'PROPTYPEDECL')
            prop.name = string(n.VarName);
            line = n.VarName.lineno();
            if ~isempty(n.VarType)
                prop.type = string(n.VarType);
            end
            prop.size = doParseSize(n.VarDimensions);
            [prop.validators, prop.enumValues] = doExtractValidators(n);
        elseif strcmp(n.kind, 'ATBASE')
            prop.name = string(n.Left);
            line = n.Left.lineno();
        else
            prop.name = string(n);
            line = n.lineno();
        end

        if ~v.isempty()
            prop.default = v.tree2str();
        end

        for ii = 1:numel(description)
            if lines(ii) == line - numel(description) + ii - 1
                prop.description(end + 1) = description(ii);
            end
        end

        propList = [propList, prop]; %#ok<AGROW>
        node = node.Next;
    end
end


%% ---- events ----

function events = doParseEvents(etree)
% parse an events block; stamp block attrs onto each event.

    attrStruct = struct('Description', "", 'Hidden', false);

    attr = etree.Attr;
    if attr.count
        attrStruct = doParseAttributes(attr.Arg, attrStruct);
    end

    desc = strip(string(attrStruct.Description), '"');
    isReactive = desc == "Reactive";

    events = doParseEvent(etree.Body);

    for ii = 1:numel(events)
        events(ii).hidden   = logical(attrStruct.Hidden);
        events(ii).reactive = isReactive;
    end
end


function eventList = doParseEvent(node)
% parse individual events from an events block body.

    eventList = [];

    while ~isempty(node)
        description = string.empty();
        lines = [];
        while ~isempty(node) && node.kind == "COMMENT"
            lines(end + 1) = node.lineno(); %#ok<AGROW>
            description(end + 1) = stripComment(string(node)); %#ok<AGROW>
            node = node.Next;
        end

        if isempty(node), return, end

        evt = struct('name', "", 'description', string.empty());

        if node.kind == "EVENT"
            evt.name = string(node.Left);
        else
            evt.name = string(node);
        end
        line = node.lineno();

        for ii = 1:numel(description)
            if lines(ii) == line - numel(description) + ii - 1
                evt.description(end + 1) = description(ii);
            end
        end

        eventList = [eventList, evt]; %#ok<AGROW>
        node = node.Next;
    end
end


%% ---- methods / functions ----

function methods = doParseMethods(mnode)
% parse a methods block; stamp block attrs onto each method.

    attrStruct = struct( ...
        'Description', "", ...
        'Hidden',      false, ...
        'Access',      "public", ...
        'Static',      false, ...
        'Abstract',    false);

    attr = mnode.Attr;
    if attr.count
        attrStruct = doParseAttributes(attr.Arg, attrStruct);
    end

    desc = strip(string(attrStruct.Description), '"');
    isReactive = desc == "Reactive";

    methods = [];
    mtreeObj = mnode.Tree;
    funIdx = indices(mtreeObj.mtfind('Kind', 'FUNCTION'));

    for ii = 1:numel(funIdx)
        f = mtreeObj.select(funIdx(ii));
        if f.trueparent.kind == "METHODS"
            fcn = doParseFunction(f);
            fcn.access   = string(attrStruct.Access);
            fcn.hidden   = logical(attrStruct.Hidden);
            fcn.static   = logical(attrStruct.Static);
            fcn.abstract = logical(attrStruct.Abstract);
            fcn.reactive = isReactive;
            methods = [methods, fcn]; %#ok<AGROW>
        end
    end
end


function fcn = doParseFunction(node)
% parse a function node into a struct.

    fcn = struct( ...
        'name',        "", ...
        'description', string.empty(), ...
        'inputs',      string.empty(), ...
        'outputs',     string.empty(), ...
        'arguments',   []);

    fcn.name    = string(node.Fname);
    fcn.inputs  = doParseIO(node.Ins);
    fcn.outputs = doParseIO(node.Outs);

    % find last line of function signature
    l = node.Fname.lineno;
    if ~node.Ins.isempty
        ep = node.Ins.Tree.endposition;
        if ~isempty(ep) && any(ep > 0)
            [endLine, ~] = node.pos2lc(max(ep));
            l = max(l, endLine);
        end
    end
    if ~node.Outs.isempty
        ep = node.Outs.Tree.endposition;
        if ~isempty(ep) && any(ep > 0)
            [endLine, ~] = node.pos2lc(max(ep));
            l = max(l, endLine);
        end
    end
    body = node.Body;
    while ~isempty(body) && body.kind == "COMMENT" && body.lineno == l + 1
        fcn.description(end + 1) = stripComment(string(body));
        l = l + 1;
        body = body.Next;
    end

    if ~isempty(node.Arguments)
        fcn.arguments = doParseArguments(node.Arguments);
    end
end


%% ---- arguments ----

function args = doParseArguments(node)
% parse arguments blocks inside a function.

    args = [];

    while ~isempty(node)
        attrStruct = struct('Repeating', false, 'Input', true, 'Output', false);
        if ~isempty(node.Attr)
            attrStruct = doParseAttributes(node.Attr.Arg, attrStruct);
        end

        arg = struct( ...
            'input',      logical(attrStruct.Input), ...
            'output',     logical(attrStruct.Output), ...
            'repeating',  logical(attrStruct.Repeating), ...
            'properties', []);

        arg.properties = doParseArgumentList(node.Body);

        args = [args, arg]; %#ok<AGROW>
        node = node.Next;
    end
end


function argList = doParseArgumentList(node)
% parse individual arguments inside an arguments block.

    argList = [];

    while ~isempty(node)
        description = string.empty();
        lines = [];
        while ~isempty(node) && node.kind == "COMMENT"
            description(end + 1) = stripComment(string(node)); %#ok<AGROW>
            lines(end + 1) = node.lineno(); %#ok<AGROW>
            node = node.Next;
        end

        if isempty(node), return, end

        prop = struct( ...
            'name',        "", ...
            'description', string.empty(), ...
            'type',        "", ...
            'size',        string.empty(), ...
            'default',     "");

        if node.kind ~= "ARGUMENT"
            node = node.Next;
            continue
        end

        varNameNode = node.ArgumentValidation.VarName;
        if strcmp(varNameNode.kind, 'NOT')
            prop.name = "~";
        else
            prop.name = convertCharsToStrings(string(varNameNode));
        end
        if ~isempty(node.ArgumentValidation.VarNamedField)
            prop.name = prop.name + "." + ...
                string(node.ArgumentValidation.VarNamedField);
        end

        if ~isempty(node.ArgumentValidation.VarType)
            prop.type = string(node.ArgumentValidation.VarType);
        end

        prop.size = doParseSize(node.ArgumentValidation.VarDimensions);

        line = node.lineno();
        for ii = 1:numel(description)
            if lines(ii) == line - numel(description) + ii - 1
                prop.description(end + 1) = description(ii);
            end
        end

        if ~isempty(node.ArgumentInitialization)
            prop.default = node.ArgumentInitialization.tree2str();
        end

        argList = [argList, prop]; %#ok<AGROW>
        node = node.Next;
    end
end


%% ---- validators & enumerations ----

function [names, enumValues] = doExtractValidators(propTypeNode)
% extract validator names and mustBeMember enum values from a PROPTYPEDECL node.

    names = string.empty();
    enumValues = string.empty();

    if isempty(propTypeNode) || ~strcmp(propTypeNode.kind, 'PROPTYPEDECL')
        return
    end

    valNode = propTypeNode.VarValidators;
    if isempty(valNode), return, end

    while ~isempty(valNode)
        if strcmp(valNode.kind, 'LP')
            funcName = string(valNode.Left.tree2str);
            names(end + 1) = funcName; %#ok<AGROW>

            if funcName == "mustBeMember" || endsWith(funcName, ".mustBeMember")
                firstArg = valNode.Right;
                if ~isempty(firstArg)
                    secondArg = firstArg.Next;
                    if ~isempty(secondArg)
                        enumValues = doExtractArrayValues(secondArg);
                    end
                end
            end
        else
            names(end + 1) = string(valNode.tree2str); %#ok<AGROW>
        end
        valNode = valNode.Next;
    end
end


function values = doExtractArrayValues(node)
% extract string values from a bracketed array node like ["a", "b", "c"].

    values = string.empty();

    if strcmp(node.kind, 'LB'), node = node.Arg; end
    if strcmp(node.kind, 'ROW'), node = node.Arg; end

    while ~isempty(node)
        val = strtrim(string(node));
        if startsWith(val, '"') && endsWith(val, '"')
            val = extractBetween(val, 2, strlength(val) - 1);
        end
        values(end + 1) = val; %#ok<AGROW>
        node = node.Next;
    end
end


function enums = doExtractEnumeration(tree)
% extract enumeration members from a classdef tree.

    enums = [];

    enumNodes = tree.mtfind('Kind', 'ENUMERATION');
    if isempty(enumNodes), return, end

    enumIdx = enumNodes.indices();
    for ii = 1:numel(enumIdx)
        body = tree.select(enumIdx(ii)).Body;

        while ~isempty(body)
            description = string.empty();
            lines = [];
            while ~isempty(body) && body.kind == "COMMENT"
                lines(end + 1) = body.lineno(); %#ok<AGROW>
                description(end + 1) = string(body); %#ok<AGROW>
                body = body.Next;
            end

            if isempty(body), return, end

            member = struct('name', "", 'description', string.empty());
            member.name = string(body);
            line = body.lineno();

            for jj = 1:numel(description)
                if lines(jj) == line - numel(description) + jj - 1
                    member.description(end + 1) = description(jj);
                end
            end

            enums = [enums, member]; %#ok<AGROW>
            body = body.Next;
        end
    end
end


%% ---- shared utilities ----

function s = doParseAttributes(node, s)
% walk an attribute list and fill a template struct.

    while ~isempty(node)
        n = node.Left;
        v = node.Right;

        if strcmp(n.kind, 'PROPTYPEDECL')
            name = string(n.VarName);
        elseif strcmp(n.kind, 'ATBASE')
            name = string(n.Left);
        else
            name = n.string;
        end

        if isfield(s, name)
            if ~v.isempty()
                s.(name) = v.tree2str();
            else
                s.(name) = true;
            end
        end

        node = node.Next;
    end
end


function io = doParseIO(node)
% parse a function input/output argument list.

    io = string.empty();
    while ~isempty(node)
        if node.kind == "NOT"
            io(end + 1) = "~"; %#ok<AGROW>
        else
            io(end + 1) = string(node); %#ok<AGROW>
        end
        node = node.Next;
    end
end


function sz = doParseSize(node)
% parse a dimension/size validation spec.

    sz = string.empty();
    while ~isempty(node)
        if node.kind == "COLON"
            sz(end + 1) = ":"; %#ok<AGROW>
        else
            sz(end + 1) = string(node); %#ok<AGROW>
        end
        node = node.Next;
    end
end


function s = doParseSuperClasses(node)
% recursively parse a superclass list.

    if node.kind == "AND"
        s = [doParseSuperClasses(node.Left), doParseSuperClasses(node.Right)];
    else
        s = convertCharsToStrings(string(node));
    end
end


function txt = stripComment(raw)
% strip the leading "% " or "%" prefix from a comment string.
    txt = regexprep(raw, '^%\s?', '');
end

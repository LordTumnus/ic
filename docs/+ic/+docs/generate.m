function generate()
% parse all IC files, apply manifest ordering, and write api.json.
%
% {example}
%   ic.docs.generate()
% {/example}

    fprintf('IC Documentation Generator \n\n');

    % 1. Parse all files
    fprintf('[1/3] Parsing all .m files...\n');
    allDocs = ic.docs.parseAll();
    fprintf('      Found %d items.\n\n', numel(allDocs));

    % 2. Get manifest and resolve ordering
    fprintf('[2/3] Resolving manifest ordering...\n');
    sections = ic.docs.Manifest.get();
    ordered = ic.docs.Manifest.resolve(sections, allDocs);

    totalItems = 0;
    for ii = 1:numel(ordered)
        items = ordered(ii).items;
        n = 0;
        for jj = 1:numel(items)
            entry = items{jj};
            if isstruct(entry) && isfield(entry, 'subsection')
                n = n + numel(entry.items);
            else
                n = n + 1;
            end
        end
        fprintf('      %s: %d items\n', ordered(ii).title, n);
        totalItems = totalItems + n;
    end
    fprintf('      Total: %d items in %d sections\n\n', ...
        totalItems, numel(ordered));

    % 3. Build output structure and write JSON
    fprintf('[3/3] Writing api.json...\n');
    output = struct();
    output.generated = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));

    % convert to cell array of section structs for proper JSON encoding
    sectionCells = cell(1, numel(ordered));
    for ii = 1:numel(ordered)
        sec = struct();
        sec.title = ordered(ii).title;
        % items is a cell array; each element is either a doc struct or
        % a subsection struct {subsection, items}. For doc structs, wrap
        % in a cell so jsonencode produces [{...}, {subsection:...}, ...]
        items = ordered(ii).items;
        encoded = cell(1, numel(items));
        for jj = 1:numel(items)
            entry = items{jj};
            if isstruct(entry) && isfield(entry, 'subsection')
                % subsection: wrap its items in cells for consistent JSON
                sub = struct();
                sub.subsection = entry.subsection;
                sub.items = num2cell(entry.items);
                encoded{jj} = sub;
            else
                encoded{jj} = entry;
            end
        end
        sec.items = encoded;
        sectionCells{ii} = sec;
    end
    output.sections = sectionCells;

    % write JSON
    docsDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    outDir = fullfile(docsDir, 'generated');
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    outFile = fullfile(outDir, 'api.json');

    jsonText = jsonencode(output, 'PrettyPrint', true);
    fid = fopen(outFile, 'w', 'n', 'UTF-8');
    fwrite(fid, jsonText, 'char');
    fclose(fid);

    fprintf('      Written to: %s\n', outFile);
    fprintf('      Size: %.1f KB\n', numel(jsonText) / 1024);
    fprintf('\nDone.\n');
end

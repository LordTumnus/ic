function results = parseAll()
% discover and parse all IC framework .m files.
% scans core/, components/, utils/, and validators/ for .m files, derives
% fully-qualified names from the package directory structure, and calls
% ic.docs.parseFile on each. files that fail to parse are logged and skipped.

    % determine the IC repo root (docs/ is a sibling of core/, components/, etc.)
    docsDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    repoRoot = fileparts(docsDir);

    % directories to scan
    scanDirs = ["core", "components", "utils", "validators"];
    % directories to skip
    skipPatterns = [fullfile(repoRoot, "test"), ...
                    fullfile(repoRoot, "examples"), ...
                    fullfile(repoRoot, "developerTools")];

    results = [];

    for dd = 1:numel(scanDirs)
        scanPath = fullfile(repoRoot, scanDirs(dd));
        if ~isfolder(scanPath)
            continue
        end

        % find all .m files recursively
        files = dir(fullfile(scanPath, '**', '*.m'));

        for ff = 1:numel(files)
            filePath = fullfile(files(ff).folder, files(ff).name);

            % skip excluded directories
            if any(startsWith(filePath, skipPatterns))
                continue
            end

            % derive the fully-qualified name from the path
            qualName = pathToQualifiedName(filePath);
            if qualName == ""
                continue
            end

            % parse the file
            try
                s = ic.docs.parseFile(qualName);
                results = [results, s]; %#ok<AGROW>
            catch ME
                fprintf('  [SKIP] %s — %s\n', qualName, ME.message);
            end
        end
    end

    fprintf('Parsed %d files.\n', numel(results));
end


function name = pathToQualifiedName(filePath)
% convert a file path to a fully-qualified MATLAB name.
% e.g. .../components/form/button/+ic/Button.m -> "ic.Button"

    parts = split(string(filePath), filesep);

    % find the first +package directory
    pkgMask = startsWith(parts, "+");
    firstPkg = find(pkgMask, 1, 'first');

    if isempty(firstPkg)
        % not in a package — skip (standalone scripts, etc.)
        name = "";
        return
    end

    % collect package segments and the filename
    segments = string.empty();
    for ii = firstPkg:numel(parts)
        seg = parts(ii);
        if startsWith(seg, "+")
            segments(end + 1) = extractAfter(seg, 1); %#ok<AGROW>
        else
            % last segment is the filename
            segments(end + 1) = extractBefore(seg, strlength(seg) - 1); %#ok<AGROW>
            break
        end
    end

    name = join(segments, ".");
end

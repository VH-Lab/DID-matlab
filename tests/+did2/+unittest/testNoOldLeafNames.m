function tests = testNoOldLeafNames
%TESTNOOLDLEAFNAMES Nothing under src/did/+did2 writes a pre-composition leaf.
%
%   did-schema #88: a statement is a direction class (observation, assertion,
%   manipulation, calculation) plus ONE value-kind mixin in `superclasses`,
%   built as did2.build.statement('<direction>', ..., 'ValueKind', '<kind>').
%   The only named statement classes are the eight vision calculators. Jess
%   Haley: "stop mentioning old leafs".
%
%   This scans the CODE (comments stripped) of every .m file under
%   src/did/+did2 for a quoted literal spelled '<x>_<direction>' -- a joined
%   leaf name -- or a bare '_<direction>' suffix (the piece that builds one by
%   concatenation). A hit fails unless it is one of the eight named
%   calculators or on the ALLOW list below, each entry with its reason. A
%   matcher that reads OLD-VINTAGE input does so through
%   did2.convert.statementKind, which needs no such literal.
%
%   The scan prints its DENOMINATOR first (files, code lines, literals
%   inspected) and refuses to pass over an empty tree; a second test plants a
%   violation to prove the scanner can see one.
tests = functiontests(localfunctions);
end

function testNoOldLeafLiteralIsWritten(testCase)
root = srcRoot();
files = mFilesUnder(root);
nLines = 0;
nLiterals = 0;
allowed = {};
hits = {};
for k = 1:numel(files)
    p = files{k};
    rel = strrep(p(numel(root) + 2:end), '\', '/');
    txt = fileread(p);
    lines = regexp(txt, '\r?\n', 'split');
    for i = 1:numel(lines)
        code = stripComment(lines{i});
        if isempty(strtrim(code)); continue; end
        nLines = nLines + 1;
        lits = quotedLiterals(code);
        nLiterals = nLiterals + numel(lits);
        for j = 1:numel(lits)
            if ~isOldLeafLiteral(lits{j}); continue; end
            where = sprintf('%s:%d: ''%s''', rel, i, lits{j});
            if isAllowed(rel, lits{j})
                allowed{end+1} = where; %#ok<AGROW>
            else
                hits{end+1} = where; %#ok<AGROW>
            end
        end
    end
end
fprintf(['testNoOldLeafNames DENOMINATOR: %d .m file(s) under %s, %d code ' ...
    'line(s), %d quoted literal(s) inspected; %d allow-listed, %d violation(s)\n'], ...
    numel(files), root, nLines, nLiterals, numel(allowed), numel(hits));
for k = 1:numel(allowed)
    fprintf('  allowed   %s\n', allowed{k});
end
for k = 1:numel(hits)
    fprintf('  VIOLATION %s\n', hits{k});
end
% an empty tree is "not measured", never "clean"
verifyGreaterThan(testCase, numel(files), 100, ...
    sprintf('only %d .m files found under %s: wrong root?', numel(files), root));
verifyGreaterThan(testCase, nLiterals, 1000);
verifyEmpty(testCase, hits, sprintf( ...
    ['%d pre-composition leaf literal(s) written under src/did/+did2. Build a ' ...
     'statement as the direction class with ''ValueKind'' (did2.build.statement), ' ...
     'or read one with did2.convert.statementKind:\n%s'], ...
    numel(hits), strjoin(hits, newline)));
end

function testTheScannerSeesAPlantedViolation(testCase)
% A scanner that cannot match proves nothing: plant one of each shape.
code = stripComment('x = did2.build.statement(''voltage_observation'', id); % ''term_assertion''');
lits = quotedLiterals(code);
verifyEqual(testCase, lits, {'voltage_observation'});   % the comment is not code
verifyTrue(testCase, isOldLeafLiteral('voltage_observation'));
verifyTrue(testCase, isOldLeafLiteral('_manipulation'));
verifyTrue(testCase, isOldLeafLiteral('harmonic_component_calculation'));
verifyFalse(testCase, isOldLeafLiteral('tuning_curve_calculation'));   % named calculator
verifyFalse(testCase, isOldLeafLiteral('observation'));
verifyFalse(testCase, isOldLeafLiteral('it''s an observation'));
% a doubled quote inside a literal does not end it
verifyEqual(testCase, quotedLiterals('a = ''it''''s''; b = x'';'), {'it''s'});
end

% ===================== the rules =========================================

function tf = isOldLeafLiteral(s)
tf = ~isempty(regexp(s, '^[a-z0-9_]*_(observation|manipulation|assertion|calculation)$', 'once')) ...
    && ~any(strcmp(s, namedCalculators()));
end

function names = namedCalculators()
% did-schema #88 stable/*_calculation.json: the eight named calculators.
names = {'tuning_curve_calculation', 'orientation_direction_tuning_calculation', ...
    'spatial_frequency_tuning_calculation', 'temporal_frequency_tuning_calculation', ...
    'speed_tuning_calculation', 'contrast_tuning_calculation', ...
    'receptive_field_calculation', 'contrast_sensitivity_calculation'};
end

function tf = isAllowed(rel, lit)
% {file (relative to src/did/+did2), literal, reason}. Every entry is a
% literal that is NOT a statement class name, or a matcher that only READS.
allow = {
    '+convert/epochMint.m', 'migrated_recording_observation', ...
        'a base.name stamp on pre-#88 documents (read, never a class)'
    '+convert/resolveEpochProbemap.m', 'migrated_recording_observation', ...
        'a base.name stamp on pre-#88 documents (read, never a class)'
    '+convert/resolveEpochProbemap.m', 'pyraview_kept_no_recording_observation', ...
        'a report counter name'
    '+convert/foldGenericFiles.m', '_observation', ...
        'MATCHER: accepts an old-vintage joined observation name on input (endsWith)'
    };
tf = false;
for k = 1:size(allow, 1)
    if strcmp(rel, allow{k, 1}) && strcmp(lit, allow{k, 2})
        tf = true;
        return;
    end
end
end

% ===================== a small MATLAB lexer =================================

function root = srcRoot()
here = fileparts(mfilename('fullpath'));            % <root>/tests/+did2/+unittest
repoRoot = fileparts(fileparts(fileparts(here)));
root = fullfile(repoRoot, 'src', 'did', '+did2');
end

function files = mFilesUnder(folder)
% Every .m file below FOLDER, walked explicitly (portable; no '**' glob).
files = {};
entries = dir(folder);
for k = 1:numel(entries)
    e = entries(k);
    if any(strcmp(e.name, {'.', '..'})); continue; end
    p = fullfile(folder, e.name);
    if e.isdir
        files = [files, mFilesUnder(p)]; %#ok<AGROW>
    elseif numel(e.name) > 2 && strcmp(e.name(end - 1:end), '.m')
        files{end + 1} = p; %#ok<AGROW>
    end
end
end

function code = stripComment(line)
% The line up to its first % that is not inside a quoted literal.
code = line;
inQuote = false;
prev = ' ';
k = 1;
while k <= numel(line)
    c = line(k);
    if inQuote
        if c == ''''
            if k < numel(line) && line(k + 1) == ''''
                k = k + 2;
                continue;
            end
            inQuote = false;
            prev = c;
        end
    elseif c == '%'
        code = line(1:k - 1);
        return;
    elseif c == '''' && ~opensTranspose(prev)
        inQuote = true;
    elseif c == '"'
        q = find(line(k + 1:end) == '"', 1);
        if isempty(q); return; end
        k = k + q + 1;
        prev = '"';
        continue;
    end
    if ~inQuote
        if isspace(c); prev = ' '; else; prev = c; end
    end
    k = k + 1;
end
end

function lits = quotedLiterals(code)
% Every single-quoted literal in CODE (a doubled quote is one quote).
lits = {};
prev = ' ';
k = 1;
n = numel(code);
while k <= n
    c = code(k);
    if c == '''' && ~opensTranspose(prev)
        j = k + 1;
        buf = '';
        while j <= n
            if code(j) == ''''
                if j < n && code(j + 1) == ''''
                    buf(end + 1) = ''''; %#ok<AGROW>
                    j = j + 2;
                    continue;
                end
                break;
            end
            buf(end + 1) = code(j); %#ok<AGROW>
            j = j + 1;
        end
        lits{end + 1} = buf; %#ok<AGROW>
        k = j + 1;
        prev = '''';
        continue;
    end
    if ~isspace(c); prev = c; else; prev = ' '; end
    k = k + 1;
end
end

function tf = opensTranspose(prev)
% A quote right after a name, a closing bracket, a dot or another quote is the
% transpose operator, not the start of a literal.
tf = isletter(prev) || any(prev == '0123456789_)]}.''');
end

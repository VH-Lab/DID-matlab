function tests = testRetiredNamesInCode
%TESTRETIREDNAMESINCODE Retired class and schema-set names stay out of code.
%
%   Three names left the schema and are read on CODE lines (comments stripped)
%   only where a line says why:
%
%     session_relative_reference, session_bounded_reference
%         the pre-#73 session anchors. jSessionAnchor writes a
%         `relative_time_reference` to the session entity, and nothing mints
%         the old classes; the pass that folded them is deleted
%         (DID-matlab #397). No code line reads the names.
%     'method_parameters' as a CLASS
%         the standalone class is `method` since did-schema #88; epochMint's
%         epoch_id stamping loop compares on 'method' (DID-matlab #398).
%     V_epsilon, V_zeta
%         brainstorm schema sets deleted with did-schema #88 (DID-matlab #402).
%         Only schemaVersionRank, which ranks a legacy STAMP on an old body,
%         names them.
%
%   The scan prints its DENOMINATOR first (files, code lines) and refuses to
%   pass over an empty tree; a second test plants each violation to prove the
%   scanner can see it.
tests = functiontests(localfunctions);
end

function testRetiredNamesAreReadOnlyWhereAllowed(testCase)
root = srcRoot();
files = mFilesUnder(root);
nLines = 0;
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
        names = retiredNamesIn(code);
        for j = 1:numel(names)
            where = sprintf('%s:%d: %s', rel, i, names{j});
            if isAllowed(rel, names{j})
                allowed{end+1} = where; %#ok<AGROW>
            else
                hits{end+1} = where; %#ok<AGROW>
            end
        end
    end
end
fprintf(['testRetiredNamesInCode DENOMINATOR: %d .m file(s) under %s, %d code ' ...
    'line(s) inspected; %d allow-listed, %d violation(s)\n'], ...
    numel(files), root, nLines, numel(allowed), numel(hits));
for k = 1:numel(allowed)
    fprintf('  allowed   %s\n', allowed{k});
end
for k = 1:numel(hits)
    fprintf('  VIOLATION %s\n', hits{k});
end
% an empty tree is "not measured", never "clean"
verifyGreaterThan(testCase, numel(files), 100, ...
    sprintf('only %d .m files found under %s: wrong root?', numel(files), root));
verifyGreaterThan(testCase, nLines, 10000);
verifyEmpty(testCase, hits, sprintf( ...
    '%d retired name(s) on code lines under src/did/+did2:\n%s', ...
    numel(hits), strjoin(hits, newline)));
% the allowed reads are still there: if one goes, its entry goes too
verifyNotEmpty(testCase, allowed);
end

function testTheScannerSeesAPlantedViolation(testCase)
% A scanner that cannot match proves nothing.
verifyEqual(testCase, retiredNamesIn( ...
    'tf = strcmp(c, ''session_relative_reference'');'), {'session_relative_reference'});
verifyEqual(testCase, retiredNamesIn( ...
    'x = {''session_bounded_reference''};'), {'session_bounded_reference'});
verifyEqual(testCase, retiredNamesIn( ...
    'if strcmp(cn, ''method_parameters''); end'), {'''method_parameters'''});
verifyEqual(testCase, retiredNamesIn('t = ''V_zeta''; u = ''V_epsilon'';'), ...
    {'V_zeta', 'V_epsilon'});
% a comment is not code, and a longer word is not the name
verifyEmpty(testCase, retiredNamesIn(stripComment('y = 1; % session_relative_reference')));
verifyEmpty(testCase, retiredNamesIn('r.method_parameters_seen = 0;'));
verifyEmpty(testCase, retiredNamesIn('s = ''V_zetas'';'));
verifyFalse(testCase, isAllowed('+convert/epochMint.m', 'session_relative_reference'));
end

% ===================== the rules =========================================

function names = retiredNamesIn(code)
% The retired names on one CODE line. 'method_parameters' counts only as a
% quoted literal (the class name); a field or counter of that spelling is not
% a class read.
names = regexp(code, ['(?<![A-Za-z0-9_])(session_relative_reference|' ...
    'session_bounded_reference|V_epsilon|V_zeta)(?![A-Za-z0-9_])'], 'match');
names = [names, regexp(code, '''method_parameters''', 'match')];
end

function tf = isAllowed(rel, name)
% {file (relative to src/did/+did2), name, reason}
allow = {
    '+convert/schemaVersionRank.m', 'V_epsilon', ...
        'ranks a legacy schema_version stamp on an old body (DID-matlab #402)'
    '+convert/schemaVersionRank.m', 'V_zeta', ...
        'ranks a legacy schema_version stamp on an old body (DID-matlab #402)'
    '+validate/epochStrings.m', '''method_parameters''', ...
        'the SOURCE label of the parked epoch string, not a class'
    '+convert/epochMint.m', '''method_parameters''', ...
        'reads that SOURCE label from did2.validate.epochStrings'
    '+build/private/methodShape.m', '''method_parameters''', ...
        'the pre-#88 schema shape, answered only when the schema has no method'
    '+build/private/checkRules.m', '''method_parameters''', ...
        'the method-entry rule also reads the pre-#88 block (both shapes)'
    '+convert/+roundtrip/session_in_a_dataset.m', '''method_parameters''', ...
        'the round trip reads the pre-#88 block name on a relation (both shapes)'
    };
tf = false;
for k = 1:size(allow, 1)
    if strcmp(rel, allow{k, 1}) && strcmp(name, allow{k, 2})
        tf = true;
        return;
    end
end
end

% ===================== a small MATLAB lexer (testNoOldLeafNames') ==========

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

function tf = opensTranspose(prev)
% A quote right after a name, a closing bracket, a dot or another quote is the
% transpose operator, not the start of a literal.
tf = isletter(prev) || any(prev == '0123456789_)]}.''');
end

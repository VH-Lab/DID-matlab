%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 10: ARE THE `%#ok<INUSA>` SUPPRESSIONS IN resolveDatasetEntities.m
%   DEAD, OR LOAD-BEARING? (code-scanning alerts 211/212, and 210 as a free
%   read on a file this session does not own.)
%
%   THE QUESTION. Alerts 211 and 212 say a Code Analyzer message "was once
%   suppressed here, but the message is no longer generated" at
%   resolveDatasetEntities.m lines 110 and 111 -- two of the THREE
%   `%#ok<INUSA>` directives in that file's `arguments` block. Line 109 carries
%   the identical directive and is NOT flagged, and that asymmetry is the whole
%   reason this needs measuring rather than deciding.
%
%   THE ALERTS ARE DATED, AND THEY ARE AGAINST THE CURRENT TIP. DID-schema
%   `V_eta_OPEN_WORK.md` row 90 records three alerts today that were artefacts
%   of a file state that no longer existed, so this was checked before anything
%   else:
%
%       $ for c in b59387f e1e9117 adf24f5 e101b12 e9ef734 32166b8 \
%                  8947827 b637d8e; do echo -n "$c: "; \
%             git show $c:src/did/+did2/+convert/resolveDatasetEntities.m \
%                 | sed -n '110p;111p' | tr '\n' '|'; echo; done
%       b59387f:     options.SchemaCache = [] %#ok<INUSA>|    options.TargetVersion (1,:) char = 'V_eta' %#ok<INUSA>|
%       e1e9117:         end|    end|
%       adf24f5:         end|    end|
%       ... every earlier revision the same
%
%   Only b59387f -- the commit this session pushed -- has a directive on those
%   lines at all. So 211/212 are CURRENT, not stale. What that does NOT settle
%   is whether they are RIGHT: the three directives are inherited, unchanged by
%   this session's edit, and only their line numbers moved.
%
%   WHY NOT JUST DELETE THEM. Removing a suppression that cannot be checked is
%   exactly how alerts 205/206 nearly cost two load-bearing `%#ok<AGROW>`
%   directives an hour ago. `INUSA` is "input argument might be unused"; if it
%   still fires under an `arguments` block, deleting the directive trades a
%   cosmetic alert for a real analyzer warning on every future run.
%
%   NO MUTATION IS NEEDED TO ANSWER IT. `checkcode`'s `-notok` flag reports the
%   messages that `%#ok` is SUPPRESSING, so running it twice -- once as the
%   analyzer normally sees the file, once with suppression disregarded -- says
%   which directives are doing work. A line that appears ONLY in the `-notok`
%   pass has a live suppression; a line that appears in NEITHER has a dead one.
%   No file is edited, on the runner or anywhere else.
%
%   READ IT THE RIGHT WAY ROUND:
%     INUSA present under -notok   -> the directive is LOAD-BEARING, the alert
%                                     is wrong, leave the file alone.
%     INUSA absent under -notok    -> the directive is DEAD, the alert is right
%                                     and the three lines can lose it.
%   Either answer is a result. Guessing is not.

fprintf('\n=============== PROBE 10: stale-suppression check ===============\n');

targets = { ...
    fullfile('src', 'did', '+did2', '+convert', 'resolveDatasetEntities.m'), ...
    fullfile('src', 'did', '+did2', '+validate', 'epochStringRetention.m')};

% DENOMINATOR FIRST AND UNCONDITIONALLY (operating rule 5): how many files this
% probe intends to read, whether each one is actually there, and how long it
% is. A checkcode run over a path that does not exist returns an empty message
% list, and an empty list is indistinguishable from a clean file unless the
% denominator is printed before the result.
fprintf('  DENOMINATOR: %d file(s) requested; pwd = %s\n', numel(targets), pwd);
for t = 1:numel(targets)
    p = targets{t};
    if isfile(p)
        txt = fileread(p);
        fprintf('    [%d] PRESENT  %-60s %d line(s)\n', t, p, ...
            numel(strfind(txt, newline)) + 1);
    else
        fprintf(2, '    [%d] ABSENT   %-60s <- "did not look", NOT "clean"\n', ...
            t, p);
    end
end

for t = 1:numel(targets)
    p = targets{t};
    if ~isfile(p); continue; end
    fprintf('\n--- %s ---\n', p);

    % The lines carrying a suppression, read out of the file rather than
    % remembered, so the report cannot describe a file that has moved on.
    lines = strsplit(fileread(p), newline);
    okLines = [];
    for k = 1:numel(lines)
        if contains(lines{k}, '%#ok<')
            okLines(end+1) = k; %#ok<AGROW>
        end
    end
    fprintf('  %d line(s) carry a %%#ok< directive: %s\n', numel(okLines), ...
        strjoin(arrayfun(@(x) sprintf('%d', x), okLines, ...
            'UniformOutput', false), ', '));
    for k = okLines
        fprintf('    %4d | %s\n', k, strtrim(lines{k}));
    end

    normal = checkcode(p, '-id', '-struct');
    notok  = checkcode(p, '-id', '-notok', '-struct');
    fprintf(['  checkcode: %d message(s) normally, %d with -notok ' ...
             '(difference = what the directives suppress)\n'], ...
        numel(normal), numel(notok));

    printMessages('  NORMAL ', normal);
    printMessages('  -NOTOK ', notok);

    % THE ANSWER, PER SUPPRESSED LINE, STATED RATHER THAN LEFT TO BE INFERRED.
    for k = okLines
        inNormal = anyOnLine(normal, k);
        inNotok  = anyOnLine(notok, k);
        if inNotok && ~inNormal
            verdict = 'LOAD-BEARING (a message is being suppressed here)';
        elseif ~inNotok
            verdict = 'DEAD (no message on this line even with -notok)';
        else
            verdict = 'MESSAGE REPORTED ANYWAY (the directive is not matching it)';
        end
        fprintf('    line %4d: %s\n', k, verdict);
    end
end

fprintf('\n=============== end probe 10 ===============\n');

function printMessages(label, msgs)
%PRINTMESSAGES Every message with its line and id. Zero prints as zero, named.
if isempty(msgs)
    fprintf('%s (no messages)\n', label);
    return;
end
for k = 1:numel(msgs)
    fprintf('%s line %4d  %-10s %s\n', label, msgs(k).line, ...
        msgs(k).id, msgs(k).message);
end
end

function tf = anyOnLine(msgs, lineNo)
tf = false;
for k = 1:numel(msgs)
    if msgs(k).line == lineNo; tf = true; return; end
end
end

%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 9: which assertion in testOneEpochKeepsTheSourceEpochIdsAndTheElementEdge
%   fails, and what is the actual value?
%
%   Three of the four new oneepoch tests pass, INCLUDING the one that runs with
%   validation on -- so the tombstone and the fold agree and the document
%   survives. Only this one fails, and it is the one asserting that the three
%   things worth keeping are kept: `oneepoch.epoch_ids`, the synthetic
%   `epochid.epochid`, and the `element_id` edge.
%
%   The fixture differs from the two that pass in exactly one way: it is the
%   SINGLE-clock case (`epoch_clock = 'dev_local_time'`, `t0_t1 = [0; 930.35]`)
%   where they are multi-clock. That is a lead, not a diagnosis.
%
%   I am not guessing which assertion it is. Probe 7 under-delivered precisely
%   because its diagnostic extraction was written blind, and the lesson recorded
%   there is: print the SHAPE first. So this prints class() and the raw value for
%   each of the three, then runs the comparisons one at a time so the failing one
%   names itself.
%
%   IT KEEPS PAYING FOR ITSELF.
%     probe 2/3  #63's family counter was reverted once as "undiagnosable" on a
%                pass/fail result. Probe 2 showed the detection logic was RIGHT;
%                probe 3 showed the counts were computed and never assigned.
%     probe 5    printed MATLAB's empty shapes instead of guessing: unique([]) is
%                0-by-1, so `for n = unique([])` iterates ONCE.
%     probe 6    checked the testCorpusPRED census wiring in 2 minutes instead of
%                assuming it across a 70-minute corpus run.
%     probe 7    UNDER-DELIVERED -- isolated WHICH tests failed but printed no
%                diagnostic, because the DiagnosticRecord walk was never verified.
%     probe 8    settled the oneepoch chain and, unprompted, showed the inherited
%                block arrives holding `clocks` rather than the did_v1
%                `epoch_clock`/`t0_t1`. A tombstone written from the template
%                would have matched no real document.

fprintf('=== PROBE 9: the failing oneepoch assertion ===\n\n');

% EXACTLY the fixture from testOneEpochKeepsTheSourceEpochIdsAndTheElementEdge.
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_1'});
v1.base = struct('id', 'oe_3', 'session_id', 'sess_09', ...
    'name', 'whole_session_ref1', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0; 930.35]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
fprintf('migrated: %d   quarantine: %d\n', numel(out.migrated), numel(out.quarantine));
for i = 1:numel(out.quarantine)
    fprintf('  QUARANTINE: %s\n', out.quarantine(i).reason);
end
if isempty(out.migrated)
    fprintf('nothing migrated -- stopping.\n');
    return;
end
d = out.migrated{1};

% ---- SHAPE FIRST, before any comparison ----
fprintf('\n--- the three values, raw ---\n');
show('oneepoch.epoch_ids', @() d.get('oneepoch.epoch_ids'));
show('epochid.epochid',    @() d.get('epochid.epochid'));

s = d.toStruct();
fprintf('\n--- depends_on as it actually is ---\n');
fprintf('  class(s.depends_on) = %s, numel = %d\n', ...
    class(s.depends_on), numel(s.depends_on));
if isstruct(s.depends_on)
    fprintf('  fieldnames: %s\n', strjoin(fieldnames(s.depends_on)', ', '));
    for k = 1:numel(s.depends_on)
        nm = s.depends_on(k).name;
        vl = s.depends_on(k).value;
        fprintf('   [%d] name=<%s> (%s)  value=<%s> (%s)\n', k, ...
            toChar(nm), class(nm), toChar(vl), class(vl));
    end
end

fprintf('\n--- the whole oneepoch block ---\n');
if isfield(s, 'oneepoch')
    fns = fieldnames(s.oneepoch);
    for k = 1:numel(fns)
        v = s.oneepoch.(fns{k});
        fprintf('  %s : %s  %s\n', fns{k}, class(v), sizeStr(v));
    end
else
    fprintf('  NO oneepoch BLOCK\n');
end

fprintf('\n--- top-level keys ---\n');
fns = fieldnames(s);
for k = 1:numel(fns); fprintf('  %s\n', fns{k}); end

% ---- now the three comparisons, one at a time, each naming itself ----
fprintf('\n--- comparisons ---\n');
check('epoch_ids', @() isequal(d.get('oneepoch.epoch_ids'), 't00001,t00002,t00003'));
check('epochid',   @() isequal(d.get('epochid.epochid'),    'whole_session_ref1'));
check('element_id edge', @() isequal(depValue(s, 'element_id'), 'elem_1'));

fprintf('\n=== PROBE 9 done ===\n');

% -------------------------------------------------------------------------

function show(label, fn)
try
    v = fn();
    fprintf('  %-22s %-12s %-14s <%s>\n', label, class(v), sizeStr(v), toChar(v));
catch err
    fprintf('  %-22s THREW %s: %s\n', label, err.identifier, err.message);
end
end

function check(label, fn)
try
    ok = fn();
    if ok
        fprintf('  %-22s PASS\n', label);
    else
        fprintf('  %-22s *** FAIL ***\n', label);
    end
catch err
    fprintf('  %-22s *** THREW *** %s: %s\n', label, err.identifier, err.message);
end
end

function s = sizeStr(v)
s = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%d', x), size(v), ...
    'UniformOutput', false), 'x'));
end

function c = toChar(v)
try
    if ischar(v)
        c = v;
    elseif isstring(v) && isscalar(v)
        c = char(v);
    elseif isnumeric(v)
        c = mat2str(v);
    elseif iscell(v)
        c = sprintf('cell{%d}', numel(v));
    else
        c = sprintf('<%s>', class(v));
    end
catch
    c = '<unprintable>';
end
end

function v = depValue(b, name)
v = '';
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, name); v = b.depends_on(k).value; return; end
end
end

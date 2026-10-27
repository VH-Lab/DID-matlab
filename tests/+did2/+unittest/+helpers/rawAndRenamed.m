function [raw, renamed, problems] = rawAndRenamed(batch)
%RAWANDRENAMED Migrate a batch on the raw-v1 path and on the universalRenames
%   path, and say where the outcomes differ.
%
%   [RAW, RENAMED, PROBLEMS] = did2.unittest.helpers.rawAndRenamed(BATCH).
%   BATCH is a cell of v1 documents. RAW is did2.convert.v1_to_v2 on it as the
%   switch runs it (did2.convert.rawV1Classes); RENAMED the same with
%   'RawV1Classes', {} (every class through universalRenames, as before the
%   switch). Both run with 'Validate', false. PROBLEMS is a cellstr, empty when
%   the switch changed no outcome:
%     - the same number of documents, passthroughs and quarantines;
%     - a document carried on one path is carried on the other (the raw carry
%       is the untouched v1 source; the renamed one is universalRenames'
%       output, so their bodies are not compared);
%     - every other document is equal on both paths, except that a
%       PASSTHROUGH keeps v1's own edge key (`value`) on the raw path where the
%       renamed one says `document_id`: its edges are compared by name and id.
%
%   ("keep behaviour identical", [migrators read raw v1], Jess Haley,
%   2026-10-26.)
%
%   See also did2.convert.v1_to_v2, did2.convert.rawV1Classes.

arguments
    batch cell
end

raw = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
renamed = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta', ...
    'RawV1Classes', {});
problems = {};
if numel(raw.quarantine) ~= numel(renamed.quarantine)
    problems{end+1} = sprintf('quarantined: raw %d, renamed %d', ...
        numel(raw.quarantine), numel(renamed.quarantine));
end
if numel(raw.passthrough) ~= numel(renamed.passthrough)
    problems{end+1} = sprintf('passed through or carried: raw %d, renamed %d', ...
        numel(raw.passthrough), numel(renamed.passthrough));
end
if numel(raw.migrated) ~= numel(renamed.migrated)
    problems{end+1} = sprintf('documents: raw %d, renamed %d', ...
        numel(raw.migrated), numel(renamed.migrated));
    return;
end
for j = 1:numel(raw.migrated)
    a = raw.migrated{j}.toStruct();
    b = renamed.migrated{j}.toStruct();
    ca = isV1(a);
    cb = isV1(b);
    if ca ~= cb
        problems{end+1} = sprintf('document %d: carried on one path only', j); %#ok<AGROW>
        continue;
    end
    if ca
        continue;
    end
    if isPassthrough(raw, a)
        if ~isequal(edgeMap(a), edgeMap(b))
            problems{end+1} = sprintf('document %d: the passthrough''s edges differ', j); %#ok<AGROW>
        end
        a = rmfieldIf(a, 'depends_on');
        b = rmfieldIf(b, 'depends_on');
    end
    if ~isequaln(a, b)
        problems{end+1} = sprintf('document %d differs: raw %s; renamed %s', j, ...
            jsonencode(a), jsonencode(b)); %#ok<AGROW>
    end
end
end

function tf = isV1(s)
tf = isfield(s, 'document_class') && isfield(s.document_class, 'schema_version') ...
    && strcmp(char(s.document_class.schema_version), 'did_v1');
end

function tf = isPassthrough(out, s)
tf = false;
id = '';
if isfield(s, 'base') && isfield(s.base, 'id'); id = char(s.base.id); end
for k = 1:numel(out.passthrough)
    if strcmp(char(out.passthrough(k).id), id)
        tf = true;
        return;
    end
end
end

function m = edgeMap(b)
m = struct();
if ~isfield(b, 'depends_on'); return; end
d = b.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    e = d{k};
    v = '';
    for key = {'document_id', 'value', 'id'}
        if isfield(e, key{1}) && ~isempty(e.(key{1}))
            v = char(e.(key{1}));
            break;
        end
    end
    m.(matlab.lang.makeValidName(char(e.name))) = v;
end
m = orderfields(m);
end

function s = rmfieldIf(s, f)
if isfield(s, f); s = rmfield(s, f); end
end

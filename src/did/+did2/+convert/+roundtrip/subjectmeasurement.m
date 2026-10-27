function [v1, spec] = subjectmeasurement(bodies)
%SUBJECTMEASUREMENT Rebuild a v1 `subjectmeasurement` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.subjectmeasurement(BODIES). V1 is the
%   document in NDI's v1 shape (subjectmeasurement.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8; no writer at that `main` outside its
%   tests). BODIES holds the `observation` and the time reference it names, or
%   the pass-1 passthrough (a measurement with no subject, no name or no one
%   number, private/passthroughInverse):
%
%     base.id, session_id, datestamp   the observation's
%     depends_on subject_id            the observation's entity_id
%     subjectmeasurement.measurement   the variable's name
%     subjectmeasurement.value         the quantity's source value
%     subjectmeasurement.datestamp     the absolute time reference's source
%                                      text; '' when the observation names the
%                                      session anchor instead
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.subjectmeasurement.

arguments
    bodies cell
end

CLASS = 'subjectmeasurement';
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    [v1, spec] = passthroughInverse(bodies, CLASS);
    return;
end
spec = emptySpec();
v1 = struct();
obs = [];
used = false(1, numel(bodies));
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'observation')
        obs = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(obs)
    spec.unplaced{end+1} = 'no observation was emitted';
    return;
end
base = rebuildBase(obs);
datestamp = '';
tr = edgeIds(obs, 'time_reference_id');
hit = 0;
for k = 1:numel(bodies)
    if ~used(k) && isscalar(tr) && strcmp(char(getIn(bodies{k}, 'base', 'id')), tr{1}) ...
            && strcmp(classNameOf(bodies{k}), 'absolute_time_reference')
        hit = k;
    end
end
if hit > 0
    used(hit) = true;
    datestamp = char(getIn(bodies{hit}, 'absolute_time_reference', 'value', 'start', 'source_value'));
    if isempty(datestamp)
        datestamp = char(getIn(bodies{hit}, 'absolute_time_reference', 'value', 'start', 'utc'));
    end
else
    [used, bad] = sessionAnchorOf(bodies, used, obs, base.session_id);
    spec.unplaced = [spec.unplaced, bad];
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a subjectmeasurement', ...
        k, classNameOf(bodies{k}));
end
[~, name] = termParts(getIn(obs, 'statement', 'variable'));
value = [];
[kind, vals] = statementValue(obs);
cells = asCell(vals);
if isempty(kind) || numel(cells) ~= 1
    spec.unplaced{end+1} = 'the observation does not state one number';
else
    value = numberOf(getIn(cells{1}, 'source_value'));
end
subject = edgeIds(obs, 'entity_id');
if isempty(subject); subject = {''}; end
v1.document_class = struct('class_name', CLASS);
v1.depends_on = struct('name', 'subject_id', 'value', subject{1});
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.(CLASS) = struct('measurement', name, 'value', value, 'datestamp', datestamp);
end

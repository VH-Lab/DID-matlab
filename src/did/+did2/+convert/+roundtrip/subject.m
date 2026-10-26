function [v1, spec] = subject(bodies)
%SUBJECT Rebuild a v1 `subject` from what did2.convert.migrators_j.subject
%   emitted: one `entity` of type organism.
%
%   [V1, SPEC] = did2.convert.roundtrip.subject(BODIES): BODIES is a cell of
%   the emitted document structs. V1 is the subject in NDI's v1 shape
%   (subject.json + base.json at the locked NDI-matlab `main`, 3cb19a8):
%
%     base.id, base.session_id, base.datestamp   from the entity (rebuildBase)
%     base.name                  the local identifier; '' is equally possible
%     subject.local_identifier   entity.local_identifier
%     subject.description        entity.description ('' when left out)
%
%   SPEC.equivalents: `base.name` can only have been the local identifier
%   (NDI ndi.subject.newdocument writes it so: a restatement of a kept value,
%   [lossless means round trip]) or '' (the template default, written by
%   +NDIMaker/subjectMaker: [writer default is not set]). Any other v1
%   base.name is not recoverable, and did2.convert.roundtrip.check reports it.
%
%   SPEC.unplaced lists any emitted document that is not one organism entity.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.subject.

arguments
    bodies cell
end

spec = struct('equivalents', struct('path', {}, 'values', {}, 'why', {}), ...
    'unplaced', {{}});
v1 = struct();
ent = [];
for k = 1:numel(bodies)
    b = bodies{k};
    if isEntityOfType(b, 'organism') && isempty(ent)
        ent = b;
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the one organism entity', ...
            k, classNameOf(b));
    end
end
if isempty(ent)
    spec.unplaced{end+1} = 'no organism entity was emitted';
    return;
end
[base, entity] = rebuildBase(ent);
li = fieldText(entity, 'local_identifier');
v1.document_class = struct('class_name', 'subject');
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', li, 'datestamp', base.datestamp);
v1.subject = struct('local_identifier', li, ...
    'description', fieldText(entity, 'description'));
spec.equivalents(end+1) = struct('path', 'base.name', 'values', {{li, ''}}, ...
    'why', ['ndi.subject writes the local identifier ([lossless means round ' ...
    'trip]: a restatement); subjectMaker leaves the template default '''' ' ...
    '([writer default is not set])']);
end

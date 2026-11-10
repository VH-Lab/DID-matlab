function [v1, spec] = openminds_element(bodies)
%OPENMINDS_ELEMENT Rebuild a v1 `openminds_element` from the term assertion
%   did2.convert.migrators_j.openminds_element converted it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds_element(BODIES). BODIES is
%   the one `assertion` about the element (its `element_id` edge becomes the
%   assertion's entity_id); private/openmindsInverse says what is rebuilt and
%   what is not. [openMINDS element description in notes] (Decided by Jess
%   Haley, 2026-11-10, did-schema did_v2_go_forward_class_audit.md): the
%   migrator writes v1 `fields.description` to the assertion's `notes` and
%   does not store `openminds_id`, which an openMINDS export rebuilds. So
%   `fields.description` is rebuilt from the notes, and the `openminds_id` v1
%   states is accepted as the one the export rebuilds (spec.same: any text);
%   the rebuilt field stays '', because the assertion does not record whether
%   v1 stated one and a document stating none would otherwise read as an
%   invented id. The other openMINDS fields v1 states (a definition, a
%   synonym, ...) are reported.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.openminds_element.

arguments
    bodies cell
end

[v1, spec] = openmindsInverse(bodies, 'openminds_element', 'element_id');
if ~isfield(v1, 'openminds')
    return;
end
notes = '';
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'assertion')
        notes = getIn(bodies{k}, 'statement', 'notes');
        break;
    end
end
if isstring(notes) && isscalar(notes); notes = char(notes); end
if ischar(notes) && ~isempty(strtrim(notes))
    v1.openminds.fields.description = notes;
end
spec.same(end+1) = struct('path', 'openminds.openminds_id', ...
    'fn', @(a, ~) ischar(a) || (isstring(a) && isscalar(a)), ...
    'why', ['an openminds_element''s openminds_id is not stored: an openMINDS ' ...
    'export rebuilds it ([openMINDS element description in notes], Jess Haley, ' ...
    '2026-11-10)']);
end

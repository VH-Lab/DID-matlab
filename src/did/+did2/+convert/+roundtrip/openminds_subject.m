function [v1, spec] = openminds_subject(bodies)
%OPENMINDS_SUBJECT Rebuild a v1 `openminds_subject` from the term assertion
%   did2.convert.migrators_j.openminds_subject converted it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds_subject(BODIES). BODIES is
%   the one `assertion` about the subject (its `subject_id` edge becomes the
%   assertion's entity_id); private/openmindsInverse says what is rebuilt and
%   what is not. `matlab_type` is compared as notation ([openMINDS subject
%   leftovers], Jess Haley, 2026-10-27: "`matlab_type` is notation"): any
%   openMINDS MATLAB class name ending in the rebuilt type's name states the
%   same type. A document the migrator carries (an `openminds_id` that does
%   not rebuild, a lab-made strain) is stamped did_v1 and never reaches this
%   inverse (did2.convert.roundtrip.check compares the carry itself).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.openminds_subject.

arguments
    bodies cell
end

[v1, spec] = openmindsInverse(bodies, 'openminds_subject', 'subject_id');
if isfield(v1, 'openminds')
    spec.same(end+1) = struct('path', 'openminds.matlab_type', ...
        'fn', @(a, b) sameTypeName(a, b), 'why', ['`matlab_type` is notation ' ...
        '([openMINDS subject leftovers], Jess Haley, 2026-10-27)']);
end
end

function tf = sameTypeName(a, b)
tf = false;
if ~(ischar(a) || isstring(a)) || ~(ischar(b) || isstring(b))
    return;
end
pa = strsplit(char(a), '.');
pb = strsplit(char(b), '.');
tf = ~isempty(pa) && ~isempty(pb) && strcmp(pa{end}, pb{end});
end

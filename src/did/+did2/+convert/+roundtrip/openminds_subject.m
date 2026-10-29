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
%   same type. A Species' `definition` and `synonym` are accepted
%   differences ([species text is the openMINDS equivalent], Jess Haley,
%   2026-10-29): compared by spec.same, they are reported as `equivalent`,
%   not lost. A document the migrator carries (an `openminds_id` that does
%   not rebuild, a lab-made strain) is stamped did_v1 and never reaches this
%   inverse (did2.convert.roundtrip.check compares the carry itself).

%   THE ROUND TRIP READ OF `openminds_id` ([term equivalents recorded], Jess
%   Haley, 2026-10-27: "Build pending: DID-matlab (the fill and the round trip
%   read)"). The migrator converts a document that states an `openminds_id`
%   only when the id rebuilds from the term through the registry's
%   `equivalent` list (did2.convert.openmindsIdRebuilds; [openMINDS subject
%   leftovers]); otherwise it carries it (carry-116). So the round trip reads
%   the id back through that same list: a v1 id the term's `equivalent` list
%   rebuilds is the same id (spec.same), compared by the function the
%   migrator used, so the round trip accepts exactly the ids the migrator
%   converted. The rebuilt field itself stays '' (private/openmindsInverse):
%   the assertion does not record whether v1 stated an id, and a writer
%   document that states none (JH's, testWholeBatchRoundTrip) would otherwise
%   be reported as an INVENTED id.
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
    node = termNodeOf(v1);
    spec.same(end+1) = struct('path', 'openminds.openminds_id', ...
        'fn', @(a, b) idRebuilds(node, a), 'why', ['the id is rebuilt from the ' ...
        'term through the registry''s `equivalent` list ([openMINDS subject ' ...
        'leftovers], [term equivalents recorded], Jess Haley, 2026-10-27)']);
    if endsWith(v1.openminds.openminds_type, '/Species')
        % [species text is the openMINDS equivalent] (Decided by Jess Haley,
        % 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "a v1
        % openMINDS subject's species `definition` and `synonym` are not stored
        % in V2: the term registry records the openMINDS species instance as
        % the term's equivalent ([term equivalents recorded]), and the round
        % trip reports the v1 text as an accepted difference". So whatever text
        % v1 states there is accepted (reported under `equivalent`, never lost).
        why = ['a species'' definition and synonym are openMINDS''s text for the ' ...
            'species instance the term registry records as the term''s equivalent ' ...
            '([species text is the openMINDS equivalent], Jess Haley, 2026-10-29)'];
        for f = {'definition', 'synonym'}
            spec.same(end+1) = struct('path', ['openminds.fields.' f{1}], ...
                'fn', @(a, ~) isText(a), 'why', why);
        end
    end
end
end

function tf = isText(v)
% the v1 value is text (char or one string): the openMINDS text accepted
tf = ischar(v) || (isstring(v) && isscalar(v));
end

function tf = idRebuilds(node, v1Id)
% the v1 `openminds_id` V1ID is the one the term NODE's `equivalent` list
% rebuilds (did2.convert.openmindsIdRebuilds, the migrator's own test)
tf = false;
if isempty(node) || ~(ischar(v1Id) || (isstring(v1Id) && isscalar(v1Id)))
    return;
end
tf = did2.convert.openmindsIdRebuilds(node, v1Id);
end

function node = termNodeOf(v1)
% the value term's node, which private/openmindsInverse writes to
% preferredOntologyIdentifier (a controlled term) or ontologyIdentifier (a
% Strain)
node = '';
if ~isfield(v1.openminds, 'fields') || ~isstruct(v1.openminds.fields)
    return;
end
f = v1.openminds.fields;
for nm = {'preferredOntologyIdentifier', 'ontologyIdentifier'}
    if isfield(f, nm{1}) && ischar(f.(nm{1})) && ~isempty(strtrim(f.(nm{1})))
        node = strtrim(f.(nm{1}));
        return;
    end
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

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
%   not rebuild) is stamped did_v1 and never reaches this inverse
%   (did2.convert.roundtrip.check compares the carry itself). A lab-made
%   strain converts; its `openminds_id` is accepted, because NDI's second
%   pass puts it on the strain entity's `global_identifier`.

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
if isfield(v1, 'openminds') && endsWith(v1.openminds.openminds_type, '/Strain')
    [v1, spec] = strainForTheSecondPass(v1, spec);
end
if isfield(v1, 'openminds')
    spec.same(end+1) = struct('path', 'openminds.matlab_type', ...
        'fn', @(a, b) sameTypeName(a, b), 'why', ['`matlab_type` is notation ' ...
        '([openMINDS subject leftovers], Jess Haley, 2026-10-27)']);
    node = termNodeOf(v1);
    if endsWith(v1.openminds.openminds_type, '/Strain') && isempty(node)
        % a LAB-MADE strain (a Strain with no ontology node, the migrator's
        % predicate): [openMINDS subject leftovers] (Jess Haley, 2026-10-27)
        % puts its `openminds_id` on the strain entity's `global_identifier` as
        % `openminds:<id>`, and NDI's second pass writes it there
        % (ndi.migrate.internal.subjectStrainAssembly, NDI-matlab a24ee16a,
        % #1107) from the v1 input. The assertion pass 1 writes is not that
        % entity, so any id v1 states is accounted for, not lost.
        spec.same(end+1) = struct('path', 'openminds.openminds_id', ...
            'fn', @(a, ~) isText(a), 'why', ['a lab-made strain''s id goes on ' ...
            'its strain entity''s global_identifier, written by NDI''s second ' ...
            'pass ([openMINDS subject leftovers], Jess Haley, 2026-10-27)']);
    else
        spec.same(end+1) = struct('path', 'openminds.openminds_id', ...
            'fn', @(a, b) idRebuilds(node, a), 'why', ['the id is rebuilt from the ' ...
            'term through the registry''s `equivalent` list ([openMINDS subject ' ...
            'leftovers], [term equivalents recorded], Jess Haley, 2026-10-27)']);
    end
    if isDecidedNode(v1.openminds.openminds_type, node)
        % A NODE FROM THE openMINDS IRI ([openMINDS ids rebuild the subject
        % terms], [knockin is NCIT Knock-in], Jess Haley, 2026-11-19;
        % Waltham-Data-Science/did-schema#212). The migrator writes a decided
        % node (did2.convert.openmindsInstanceNode) for a GeneticStrainType
        % term that names none, so v1 states the term in two spellings: the
        % node, or no node and the openMINDS IRI. The inverse rebuilds the
        % node; a v1 document that leaves it empty states the same term when
        % its id names that node, which the `openminds_id` row above checks
        % through openmindsIdRebuilds (an id that names another term is lost
        % there, not here).
        spec.same(end+1) = struct('path', 'openminds.fields.preferredOntologyIdentifier', ...
            'fn', @(a, b) isEmptyText(a), 'why', ['a GeneticStrainType node ' ...
            'resolved from its openMINDS IRI ([openMINDS ids rebuild the subject ' ...
            'terms], [knockin is NCIT Knock-in], Jess Haley, 2026-11-19)']);
    end
    if endsWith(v1.openminds.openminds_type, '/Species')
        % [species text is the openMINDS equivalent] (Decided by Jess Haley,
        % 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "a v1
        % openMINDS subject's species `definition` and `synonym` are not stored
        % in v2: the term registry records the openMINDS species instance as
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

function tf = isDecidedNode(openmindsType, node)
% NODE is a node did2.convert.openmindsInstanceNode decides for an instance
% of the openMINDS type OPENMINDSTYPE
tf = false;
if isempty(node)
    return;
end
[~, ~, table] = did2.convert.openmindsInstanceNode('');
for k = 1:numel(table)
    [n, ~] = did2.convert.openmindsInstanceNode(['openminds:' table(k).key], openmindsType);
    if ~isempty(n) && sameCurie(n, node)
        tf = true;
        return;
    end
end
end

function tf = isEmptyText(v)
% the v1 value is empty text: the document names no node of its own
tf = (ischar(v) || (isstring(v) && isscalar(v))) && isempty(strtrim(char(v)));
end

function [v1, spec] = strainForTheSecondPass(v1, spec)
%STRAINFORTHESECONDPASS A Strain's child edges and the fields NDI's second
%   pass builds from the v1 input, DEFERRED to that pass, not lost.
%
%   Decided by Jess Haley, 2026-11-19 ("4. 1") [strain fields checked after
%   the second pass] (did-schema did_v2_go_forward_class_audit.md;
%   Waltham-Data-Science/did-schema#212), as [archive segment lengths measured
%   after the second pass] defers an archive's segment lengths: the
%   assertion pass 1 writes holds the strain's term only; NDI-matlab's second
%   pass (ndi.migrate.internal.subjectStrainAssembly, strainLeftovers) reads
%   from the v1 document the `openminds_<n>` edges to the strain's openMINDS
%   children and `fields.geneticStrainType`, `species`, `backgroundStrain`
%   (their `ndi://` references) and `fields.description`, and builds the
%   strain entity, its assertions and its derived_from relations from them.
%   So the inverse writes none of them (the `subject_id` edge only) and lists
%   them in spec.deferred, pass 'second_pass': a value v1 states there is
%   DEFERRED (did2.convert.roundtrip.check; wholeBatch counts it in
%   deferred_to_second_pass). A childless strain's empty `openminds` edge (the
%   writer's placeholder, depends_on(2) = {'openminds', ''}) is restated. Any
%   other Strain field is compared as before.
why = ['a Strain''s child edges and the fields NDI''s second pass builds ' ...
    '([strain fields checked after the second pass], Jess Haley, 2026-11-19)'];
if isfield(v1, 'depends_on') && ~isempty(v1.depends_on)
    v1.depends_on = v1.depends_on(1);
end
f = v1.openminds.fields;
FIELDS = {'geneticStrainType', 'species', 'backgroundStrain', 'description'};
for k = 1:numel(FIELDS)
    if isfield(f, FIELDS{k}); f = rmfield(f, FIELDS{k}); end
end
v1.openminds.fields = f;
paths = strcat('openminds.fields.', FIELDS);
for e = 2:MAX_STRAIN_EDGES
    paths = [paths, {sprintf('depends_on(%d).name', e), sprintf('depends_on(%d).value', e)}]; %#ok<AGROW>
end
spec.deferred = struct('path', paths, 'pass', 'second_pass', 'why', why);
spec.equivalents(end+1) = struct('path', 'depends_on(2).name', 'values', {{'openminds'}}, ...
    'why', ['the writer''s empty `openminds` edge of a childless object ' ...
    '(ndi.database.fun.openMINDSobj2ndi_document)']);
end

function n = MAX_STRAIN_EDGES()
% depends_on positions a Strain's openminds_<n> edges may take: subject_id is
% the first, and the writer adds one edge per ndi:// child (Dab: 3, JH: 2)
n = 16;
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

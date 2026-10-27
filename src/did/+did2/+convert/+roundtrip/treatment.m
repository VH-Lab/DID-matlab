function [v1, spec] = treatment(bodies)
%TREATMENT Rebuild a v1 `treatment` from what did2.convert.migrators_j.treatment
%   emitted for it when it CONVERTED it (a carried treatment is compared by
%   did2.convert.roundtrip.check directly).
%
%   [V1, SPEC] = did2.convert.roundtrip.treatment(BODIES): BODIES is a cell of
%   the emitted document structs. V1 is the treatment in NDI's v1 shape
%   (treatment.json + base.json at the locked NDI-matlab `main`, 3cb19a8;
%   written by +NDIMaker/treatmentMaker, +database/+metadata/table2treatment,
%   +haley/doImport, +dabrowska/doImport):
%
%     base.id, session_id, datestamp   the manipulation (rebuildBase)
%     depends_on(1) subject_id   the manipulation's `entity_id`
%     treatment.ontologyName     statement.variable's node
%     treatment.name             statement.variable's name
%     treatment.numeric_value    a manipulation of the kind its term states
%                                (termNumberKind): the value's source_value;
%                                a dose / immersion: the `numeric value`
%                                condition (an unlabelled number)
%     treatment.string_value     the manipulation's notes; or the site
%                                observation's term node (the Dab "Target
%                                Location" idiom: the site CURIE); for an
%                                immersion the bath, NCIm:C0179246
%
%   SPEC: the template's other two depends_on entries (manipulation_id,
%   protocol_id) are restated by name when the writer left them empty
%   (ndi.document fills every template entry; an EMPTY one states nothing),
%   so a non-empty `manipulation_id` (table2treatment's group link) is
%   reported lost. `string_value` as a site or bath CURIE compares by node
%   (sameCurie: the registry writes its registered spelling).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.treatment.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
p = treatmentParts(bodies);
spec.unplaced = p.unplaced;
if isempty(p.manip)
    return;
end
[base, ~] = rebuildBase(p.manip);
[node, name] = termParts(getIn(p.manip, 'statement', 'variable'));

numeric = [];
if any(strcmp(p.kind, {'dose', 'formulation'}))
    numeric = conditionNumber(getIn(p.manip, 'statement', 'conditions'));
elseif ~isempty(p.kind)
    numeric = numberOf(getIn(p.manip, p.kind, 'value', 'source_value'));
end

stringValue = '';
[notes, hasNotes] = getIn(p.manip, 'statement', 'notes');
if hasNotes && ~isempty(notes)
    stringValue = char(notes);
elseif ~isempty(p.site)
    stringValue = termParts(getIn(p.site, 'term', 'value'));
elseif strcmp(p.kind, 'formulation')
    stringValue = 'NCIm:C0179246';
end

v1.document_class = struct('class_name', 'treatment');
v1.depends_on = struct('name', 'subject_id', 'value', firstId(p.manip, 'entity_id'));
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
v1.treatment = struct('ontologyName', node, 'name', name, ...
    'numeric_value', numeric, 'string_value', stringValue);

why = ['a template depends_on entry the writer left empty (ndi.document ' ...
    'writes every entry of treatment.json; an empty one states nothing)'];
for k = 2:3
    spec.equivalents(end+1) = struct('path', sprintf('depends_on(%d).name', k), ...
        'values', {{'manipulation_id', 'protocol_id'}}, 'why', why);
end
spec.same(end+1) = struct('path', 'treatment.string_value', ...
    'fn', @(a, b) sameCurie(a, b), 'why', ['a site or bath CURIE, compared ' ...
    'by node ([spelling is notation]; V_eta_prefix_spelling_plan.md)']);
end

function v = conditionNumber(conds)
v = [];
for c = asCell(conds)
    [~, name] = termParts(getIn(c{1}, 'variable'));
    if strcmp(name, 'numeric value')
        v = numberOf(getIn(c{1}, 'quantity', 'value'));
        return;
    end
end
end

function id = firstId(body, name)
ids = edgeIds(body, name);
id = '';
if ~isempty(ids)
    id = ids{1};
end
end

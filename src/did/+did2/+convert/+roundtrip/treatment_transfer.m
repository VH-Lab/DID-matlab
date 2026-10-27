function [v1, spec] = treatment_transfer(bodies)
%TREATMENT_TRANSFER Rebuild a v1 `treatment_transfer` from what
%   did2.convert.migrators_j.treatment_transfer emitted when it CONVERTED it:
%   a `manipulation` of value kind term on the recipient, a `derived_from`
%   directed_relation recipient <- donor, and the anchor.
%
%   [V1, SPEC] = did2.convert.roundtrip.treatment_transfer(BODIES). V1 is the
%   treatment_transfer in NDI's v1 shape (treatment/treatment_transfer.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8; written by
%   +NDIMaker/treatmentMaker create_treatment_transfer_doc from
%   +babu/TreatmentCreator.m's table):
%
%     base.id, session_id, datestamp   the manipulation (rebuildBase)
%     depends_on(1) recipient_id       the manipulation's `entity_id`
%     depends_on(2) donor_id           the relation's `parent_id`
%     entity_ontologyNode, entity_name statement.variable (also term.value)
%     method_name                      interaction.method's term name
%     method_ontologyNode              that term's node, when it has one
%     timestamp, clocktype             the relative anchor's start
%                                      source_value and clock name, when it
%                                      has a start ("during the session"
%                                      states neither)
%
%   SPEC.unplaced: a relation that is not `derived_from` from the recipient,
%   or more than one relation.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.treatment_transfer.

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
recipient = edgeIds(p.manip, 'entity_id');
if isempty(recipient); recipient = {''}; end
recipient = recipient{1};

donor = '';
for k = 1:numel(p.relations)
    r = p.relations{k};
    child = edgeIds(r, 'child_id');
    parent = edgeIds(r, 'parent_id');
    rel = getIn(r, 'directed_relation', 'relation');
    isDerived = strcmp(did2.build.vocabularyHandle('relation', rel), 'derived_from');
    if k == 1 && isDerived && isequal(child, {recipient}) && isscalar(parent)
        donor = parent{1};
    else
        spec.unplaced{end+1} = sprintf(['relation %d is not the one derived_from ' ...
            'edge from the recipient'], k);
    end
end

block = struct();
[block.entity_ontologyNode, block.entity_name] = ...
    termParts(getIn(p.manip, 'statement', 'variable'));
[mnode, mname] = termParts(getIn(p.manip, 'interaction', 'method', 'term'));
block.method_name = mname;
if ~isempty(mnode)
    block.method_ontologyNode = mnode;
end
if strcmp(classNameOf(p.anchor), 'relative_time_reference')
    [t, hasStart] = getIn(p.anchor, 'relative_time_reference', 'value', 'start', 'source_value');
    if hasStart && ~isempty(t)
        block.timestamp = t;
        [~, clk] = termParts(getIn(p.anchor, 'relative_time_reference', 'value', 'clock'));
        block.clocktype = clk;
    end
end

v1.document_class = struct('class_name', 'treatment_transfer');
v1.depends_on = struct('name', {'recipient_id', 'donor_id'}, ...
    'value', {recipient, donor});
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
v1.treatment_transfer = block;

spec.same(end+1) = struct('path', 'treatment_transfer.entity_ontologyNode', ...
    'fn', @(a, b) sameCurie(a, b), 'why', ['a node in the registry''s ' ...
    'spelling ([spelling is notation]; V_eta_prefix_spelling_plan.md)']);
end

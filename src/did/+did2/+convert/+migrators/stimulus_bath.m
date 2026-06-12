function v2Body = stimulus_bath(preBody)
%STIMULUS_BATH Migrate a did_v1 stimulus_bath to the V_epsilon shape.
%
%   V_epsilon re-roots stimulus_bath as a concrete subclass of `bath`
%   (bath <- pharmacological_manipulation <- manipulation <-
%   subject_interaction), dropping the legacy `epochid` superclass
%   (timing now lives in time_reference documents). The legacy fields
%   redistribute across the inherited blocks:
%
%       pharmacological_manipulation.mixture  <- mixture_table (CSV)
%       bath.location                         <- legacy location
%       bath.kind                             := "drug" (default; legacy
%                                                carries no kind — curator
%                                                backfills vehicle/wash/
%                                                tracer where applicable)
%       stimulus_bath (block)                 := {} (no own fields)
%       depends_on stimulus_element_id        <- carried forward
%
%   subject_id (required on every subject_interaction) and a
%   time_reference are not recoverable from a legacy stimulus_bath
%   (it carried neither a subject nor a wall-clock time, only an epoch
%   and a stimulator element); both are omitted and flagged for curator
%   backfill. The did2 validator enforces field/block shape, not
%   depends_on cardinality, so the document is valid in the meantime.
%
%   See did-schema schemas/V_epsilon/conversions/from_did_v1/stimulus_bath.md.

arguments
    preBody (1,1) struct
end

ic = did2.convert.interactionCommon;

if ~isfield(preBody, 'stimulus_bath') || ~isstruct(preBody.stimulus_bath)
    error('did2:convert:missingBlock', ...
        'stimulus_bath body is missing the stimulus_bath property block.');
end
block = preBody.stimulus_bath;

mixture = ic.mixtureFromTable(getField(block, 'mixture_table', ''));
if isempty(mixture)
    mixture = struct('chemical', ic.ontologyTerm('', ''), ...
        'amount', ic.concentration('', 0));
end

v2Body = struct();
v2Body.document_class = struct('class_name', 'stimulus_bath');
v2Body.base = ic.carryBase(preBody);
v2Body.pharmacological_manipulation = struct('mixture', mixture);
v2Body.bath = struct( ...
    'kind', 'drug', ...
    'location', locationToOntologyTerm(block, ic));
v2Body.stimulus_bath = struct();
v2Body.depends_on = ic.dependsOn({ ...
    'stimulus_element_id', ic.depDocId(preBody, 'stimulus_element_id')});
end

function term = locationToOntologyTerm(block, ic)
% Legacy location is a sub-struct {ontologyNode|node, name}.
term = ic.ontologyTerm('', '');
if ~isfield(block, 'location')
    return;
end
loc = block.location;
if ~isstruct(loc) || ~isscalar(loc)
    return;
end
if isfield(loc, 'node')
    term.node = char(loc.node);
elseif isfield(loc, 'ontologyNode')
    term.node = char(loc.ontologyNode);
elseif isfield(loc, 'ontology_node')
    term.node = char(loc.ontology_node);
end
if isfield(loc, 'name')
    term.name = char(loc.name);
end
end

function v = getField(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end

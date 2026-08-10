function bodies = jClockAlignmentBodies(preBody, block, epochDocIdA, epochDocIdB)
%JCLOCKALIGNMENTBODIES did_v1 `syncrule_mapping` -> `clock_alignment` + 2 references.
%
%   BODIES = jClockAlignmentBodies(PREBODY, BLOCK, EPOCHDOCIDA, EPOCHDOCIDB)
%   returns {clock_alignment, from_reference, to_reference} for the signed
%   sync-mapping model, or {} when the alignment cannot be stated without
%   inventing something. BLOCK is the `syncrule_mapping` property block.
%
%   THE CALLER IS RESPONSIBLE FOR THE GATE. This function is only reached with
%   two NON-EMPTY epoch DOCUMENT ids; see syncrule_mapping.m for why that gate is
%   closed on every did_v1 document today.
%
%   ---------------------------------------------------------------------
%   THE MODEL (TEAM-SIGN-OFF [sync mapping], 2026-08-08)
%   ---------------------------------------------------------------------
%       clock_alignment  ⊂ relation, polynomial      base.id PRESERVED
%          relation   ontology_term  "temporally aligned with"
%          cost       double
%          value      { coefficients, degree }       (on the `polynomial` block)
%          depends_on from_reference, to_reference,
%                     clock_alignment_configuration_id,
%                     clock_alignment_policy_id      -- all four REQUIRED
%
%   `mapping` -> `polynomial.value.coefficients` is a rename, not a reshape, and
%   the CONVENTION MATCHES EXACTLY -- which is the one thing that had to be
%   checked, because the two orders are silently interchangeable:
%
%     git show origin/main:src/ndi/ndi_common/schema_documents/ingestion/syncrule_mapping_schema.json
%        { "name": "mapping", "type": "matrix", "default_value": [1,0],
%          "documentation": "The mapping ([1xN] coefficients of a polynomial,
%                            high exponents first)" }
%
%   and polynomial.json says "Coefficients, HIGHEST ORDER FIRST -- MATLAB's
%   polyval convention". Same order. Nothing is reversed here, deliberately.
%
%   `degree` is stored and CHECKED (numel(coefficients) - 1) rather than derived:
%   did2 has no length predicate, so "which alignments are non-linear" -- the
%   interesting question about a clock mapping -- is expressible ONLY if degree
%   is a field. This is the same test that kept `axis.n`.
%
%   `relation` is STAGED as {node: '', name: 'temporally aligned with'} under
%   gate 2 of the cluster sign-off: "temporally aligned with" is a MAPPING
%   predicate, not an OWL-Time interval relation, so it cannot borrow
%   relative_reference's binding and needs an NDIC term (#67), harvested by the
%   empty-node sweep (#70). A staged empty node is the established practice at
%   34 existing +migrators_j sites (private/jOntologyTerm.m).
%
%   ---------------------------------------------------------------------
%   THE ENDPOINTS
%   ---------------------------------------------------------------------
%   v1's `epochnode_a` / `epochnode_b` each carry {epoch_id, epoch_session_id,
%   epochprobemap, epoch_clock, t0_t1, objectname, objectclass}. The plan
%   dissolves them into two `relative_reference` documents plus the `epoch`
%   document those anchor to:
%
%       relative_to   -> the epoch document        (REQUIRED -- team call)
%       value.clock   <- epoch_clock
%       value.start   <- t0_t1(1)     value.end <- t0_t1(2)
%       base.name     <- objectname
%
%   `objectname` on `base.name` is not decoration. It is string-matched at eight
%   live NDI sites (syncgraph.m:280, :283, :406-407; ctoe.m:157-158;
%   filefind.m:133-134) and the plan's own repair list says it is otherwise
%   "recoverable ONLY VIA epoch.instrument_id". Until the epoch pass carries
%   instrument_id, keeping it on the reference is what stops #58's repair being
%   undone by this build.
%
%   NO TIMES => NO REFERENCE. A reference whose extent is NaN is a hollow
%   document -- the thing silentLoss and isFragment exist to catch -- so a node
%   with clock 'no_time' or a non-finite t0/t1 yields NO reference, and this
%   function then returns {} rather than a clock_alignment with a blank REQUIRED
%   edge. Same rule, same wording, as private/jEpochClockReferences.m.
%
%   Shared helper for the Brainstorm-J (+migrators_j) clock-alignment migrators.

bodies = {};

coeffs = readMatrix(block, {'mapping'});
if isempty(coeffs) || ~isnumeric(coeffs) || ~all(isfinite(coeffs(:)))
    return;   % no polynomial => no alignment to state
end
coeffs = double(coeffs(:)');

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp');  datestamp  = preBody.base.datestamp;  end
end
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end

nodeA = subStruct(block, {'epochnode_a', 'epochNodeA'});
nodeB = subStruct(block, {'epochnode_b', 'epochNodeB'});
refA = referenceFor(nodeA, epochDocIdA, sessionId, datestamp);
refB = referenceFor(nodeB, epochDocIdB, sessionId, datestamp);
if isempty(refA) || isempty(refB)
    return;   % NO TIMES => NO REFERENCE => no alignment
end

% The two edges v1 already writes, and which V_eta had replaced with a phantom.
% `syncgraph_id` is RESTORED here as `clock_alignment_policy_id` and
% `syncrule_id` as `clock_alignment_configuration_id`; both target documents
% preserve their base.id through their own migrators (converted OR passed
% through), so these resolve either way.
policyId = jSyncDependency(preBody, 'syncgraph_id');
configId = jSyncDependency(preBody, 'syncrule_id');
if isempty(policyId) || isempty(configId)
    return;   % NEVER emit an empty required edge -- the epochid lesson, 5,316 docs
end

align = struct();
align.document_class = struct('class_name', 'clock_alignment', ...
    'class_version', '1.0.0', ...
    'superclasses', [struct('class_name', 'relation',   'class_version', '1.0.0'), ...
                     struct('class_name', 'polynomial', 'class_version', '1.0.0')], ...
    'schema_version', 'V_eta');
align.depends_on = [ ...
    struct('name', 'from_reference',                   'value', refA.base.id), ...
    struct('name', 'to_reference',                     'value', refB.base.id), ...
    struct('name', 'clock_alignment_configuration_id', 'value', configId), ...
    struct('name', 'clock_alignment_policy_id',        'value', policyId)];
% base.id PRESERVED (the signature says so, and the calculator lesson says why:
% dissolving a referenced document without keeping its id cost 11,448 orphans).
align.base = struct('id', baseField(preBody, 'id', did.ido.unique_id()), ...
    'session_id', sessionId, ...
    'name', baseField(preBody, 'name', 'migrated_clock_alignment'), ...
    'datestamp', datestamp);
align.polynomial = struct('value', struct( ...
    'coefficients', coeffs, ...
    'degree', numel(coeffs) - 1));
align.clock_alignment = struct( ...
    'relation', jOntologyTerm('', 'temporally aligned with'), ...
    'cost', readCost(block));

bodies = {align, refA, refB};
end

% ===================== the endpoint reference ==============================

function ref = referenceFor(node, epochDocId, sessionId, datestamp)
%REFERENCEFOR One epochnode -> a relative_reference anchored to its epoch document.
ref = [];
if ~isstruct(node) || isempty(epochDocId)
    return;
end
% The epochnode sub-fields are NESTED, so universalRenames (which snake_cases
% only the IMMEDIATE fields of a property block) leaves their raw v1 casing
% untouched: read snake-first with a camelCase fallback, as syncrule_mapping.m
% and every other +migrators_j nested read does.
clockName = jGetCharAny(node, {'epoch_clock', 'epochClock'});
if isempty(clockName) || strcmp(clockName, 'no_time')
    return;                                  % NO TIMES => NO REFERENCE
end
t = readMatrix(node, {'t0_t1', 't0t1'});
t = double(t(:)');
if numel(t) < 2 || ~all(isfinite(t(1:2)))
    return;                                  % NO TIMES => NO REFERENCE
end
% 'approx_' is how NDI's own clocktype vocabulary marks the ~5 s tier
% (+ndi/+time/clocktype.m:20-29); the unprefixed forms are within 0.1 ms.
approx = numel(clockName) >= 7 && strcmp(clockName(1:7), 'approx_');

objectName = jGetCharAny(node, {'objectname', 'objectName'});
if isempty(objectName); objectName = 'migrated_sync_endpoint'; end

ref = struct();
ref.document_class = struct('class_name', 'relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
ref.depends_on = struct('name', {'relative_to'}, 'value', {epochDocId});
ref.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', objectName, 'datestamp', datestamp);
ref.time_reference = struct('is_approximate', approx);
% `end` is the schema's field name AND a MATLAB keyword, so it is assigned
% dynamically. `relation` is OMITTED: it carries the qualitative Allen relation
% used when there is NO metric offset, and here the offsets are the content.
val = struct('start', durationCell(t(1), approx), ...
    'clock', jOntologyTerm('', clockName), ...
    'approximate', approx);
val.('end') = durationCell(t(2), approx);
ref.relative_reference = struct('value', val);
end

% ===================== small readers =======================================

function c = durationCell(seconds, approximate)
%DURATIONCELL The T14 one-`value` duration cell: canonical + source provenance.
%   NDI epoch clock times are already in SECONDS, so `seconds` and `source_value`
%   coincide and `source_unit` is 's'.
c = struct('seconds', double(seconds), 'source_unit', 's', ...
    'source_value', double(seconds), 'approximate', logical(approximate));
end

function v = readCost(block)
v = 0;
if isstruct(block) && isfield(block, 'cost') && isnumeric(block.cost) ...
        && isscalar(block.cost) && isfinite(block.cost)
    v = double(block.cost);
end
end

function m = readMatrix(block, names)
m = [];
if ~isstruct(block); return; end
for k = 1:numel(names)
    if isfield(block, names{k}) && isnumeric(block.(names{k}))
        m = block.(names{k});
        return;
    end
end
end

function s = subStruct(block, names)
s = struct();
if ~isstruct(block); return; end
for k = 1:numel(names)
    if isfield(block, names{k}) && isstruct(block.(names{k})) && isscalar(block.(names{k}))
        s = block.(names{k});
        return;
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

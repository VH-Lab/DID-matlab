function bodies = jClockAlignmentBodies(preBody, block, epochDocIdA, epochDocIdB)
%JCLOCKALIGNMENTBODIES did_v1 `syncrule_mapping` -> `clock_alignment` between
%   the two per-system references epochMint names.
%
%   BODIES = jClockAlignmentBodies(PREBODY, BLOCK, EPOCHDOCIDA, EPOCHDOCIDB)
%   returns {clock_alignment} (its ends the stamped `time_reference_id_1` /
%   `_2`, [device clocks on one epoch]) for the signed
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
%   SUPERSEDED 2026-10-26 ([device clocks on one epoch] (3)): the two ends are
%   the per-system references did2.convert.epochMint places on the epochs and
%   stamps here; the text below is the record of the earlier model.
%
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
%   `objectname` on `base.name` is not decoration. It is string-matched across
%   THREE syncrules and the syncgraph -- re-enumerated 2026-08-11 by grepping
%   `epochnode_[ab].objectname` for MATCH sites (not mentions) on NDI
%   `origin/main`:
%
%     +time/syncgraph.m                          :280 :283
%     +time/+syncrule/commonTriggersOverlappingEpochs.m  :110-113, :158-159
%     +time/+syncrule/filefind.m                 :133-136
%     +time/+syncrule/randomPulses.m             :104-107, :152-153
%
%   THE OLD CITATION READ "eight live NDI sites (syncgraph.m:280, :283, :406-407;
%   ctoe.m:157-158; filefind.m:133-134)" AND OMITTED randomPulses ENTIRELY.
%   `randomPulses.m:152-153` carries the byte-identical
%   `ndi.query('syncrule_mapping.epochnode_a.objectname','exact_string',...)`
%   pair that commonTriggersOverlappingEpochs does. That is the part that could
%   cost work: a #58-style repair validated against the two cited syncrules
%   would pass while silently breaking the third.
%
%   `ctoe.m` DOES NOT EXIST -- `git ls-tree origin/main | grep -ci ctoe.m` is 0.
%   It is a local abbreviation for commonTriggersOverlappingEpochs (used at
%   syncrule.m:44), so this was shorthand rather than fabrication; but no grep
%   for the cited filename can confirm the claim, which is the whole problem
%   with citing a name that is not the file's name. Its real lines are 158-159.
%
%   The plan's own repair list says it is otherwise
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
if isempty(datestamp); datestamp = did2.convert.migrationTime(); end

% [device clocks on one epoch] (3) (Decided by Jess Haley, 2026-10-26, did-schema
% V_eta_go_forward_class_audit.md): "A v1 `syncrule_mapping` becomes a
% `clock_alignment` between those two references" -- the per-system
% relative_time_references on the epochs (referent: the acquisition system).
% did2.convert.epochMint ties each endpoint to its system, checks objectname /
% objectclass / epochprobemap against it, and stamps the two reference ids
% (`time_reference_id_1` / `_2`); with either missing nothing is folded and the
% mapping stays, carried. This function mints no endpoint reference of its own.
refA = jSyncDependency(preBody, 'time_reference_id_1');
refB = jSyncDependency(preBody, 'time_reference_id_2');
if isempty(epochDocIdA) || isempty(epochDocIdB) || isempty(refA) || isempty(refB)
    return;
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

% did-schema #88: `clock_alignment` < relation, polynomial, built through
% did2.build: its two endpoints are `input_id` / `output_id`
% (`from_reference` / `to_reference` before), each a relative_time_reference.
edges = struct('input_id', refA, 'output_id', refB, ...
    'clock_alignment_configuration_id', configId, ...
    'clock_alignment_policy_id', policyId);
o = {'SessionId', char(sessionId), 'CreationTimestamp', datestamp, ...
    'Validate', false, 'Edges', edges, 'Id', baseField(preBody, 'id', '')};
align = did2.build.document('clock_alignment', struct( ...
    'value', struct('coefficients', coeffs, 'degree', numel(coeffs) - 1), ...
    'relation', jLabel('temporally aligned with'), ...
    'cost', readCost(block)), o{:});
bodies = {align};
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

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

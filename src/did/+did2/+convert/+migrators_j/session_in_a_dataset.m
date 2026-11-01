function v2Body = session_in_a_dataset(preBody)
%SESSION_IN_A_DATASET Brainstorm-J migrator: did_v1 session_in_a_dataset -> the
%   session<->dataset membership as a first-class relation. Now that `session` is
%   an `entity`, a session belonging to a dataset is a `directed_relation`
%   (session -part_of-> dataset), not a bookkeeping record.
%
%   1 -> N:
%     - dataset            the bare canonical dataset entity (id = D.id() =
%                          base.session_id); deduped by resolveDatasetEntities.
%     - directed_relation  session -part_of-> dataset, where the member session is
%                          the block's `session_id`. Tagged
%                          `migrated_session_membership`: the member session may be
%                          a LINKED session whose documents are not in this batch,
%                          so resolveDatasetEntities drops the edge if the child
%                          does not resolve (best-effort, like the deferred baths).
%
%   SINCE 2026-10-26 nothing is dropped ([session membership records linked or
%   ingested], Jess Haley, 2026-10-25): the relation's method says ingested or
%   linked, a linked session's opener class and path are its parameters, and
%   anything else carries the document as v1 (jMembershipBodies). The text below
%   is the record of the earlier drop:
%
%   Dropped: is_linked / session_creator / session_creator_input1..6 /
%   session_reference are NDI-internal session-assembly reconstruction handles
%   (how the session was linked/rebuilt into the dataset), not go-forward schema
%   content — the same disposition as the retired ndi_<x>_class config handles.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI session_in_a_dataset.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/dataset.m writes it). Every v1
%   field and where it goes; did2.convert.roundtrip.session_in_a_dataset
%   rebuilds the v1 document and testRawV1RoundTripSession compares the two:
%
%     base.session_id               -> the dataset entity's id (D.id()) and the
%                                      relation's parent
%     base.datestamp                -> the relation's creation_timestamp
%     base.id                       -> NOT KEPT (the relation's id is minted):
%                                      a known finding, a question for the team
%     base.name                     -> not kept ('' on every writer document)
%     session_in_a_dataset.session_id   -> the relation's child
%     .is_linked                    -> the method term (database linking /
%                                      database ingestion)
%     .session_creator              -> the "software class" parameter when
%                                      `ndi.session.dir`; any other opener
%                                      carries the document ([session opener
%                                      inputs], Jess Haley, 2026-10-27;
%                                      carry-119), and so does an unstated one
%                                      ([unstated session creator carried],
%                                      Jess Haley, 2026-10-29; carry-119)
%     .session_creator_input2       -> the "Pathname" parameter (a linked
%                                      session)
%     .session_reference            -> dropped when it equals the session
%                                      entity's local_identifier ([ingested
%                                      session membership]; for a linked
%                                      session [linked session reference
%                                      follows the ingested rule], Jess Haley,
%                                      2026-10-27); else carried; carry-069 when
%                                      the session is not in the batch
%                                      ([linked session not in the batch],
%                                      Jess Haley, 2026-10-29)
%     .session_creator_input1..3    -> dropped when a copy of the session's
%                                      reference or id ([session membership
%                                      records linked or ingested]); else
%                                      carried (jMembershipBodies)
%     .session_creator_input4..6    -> a non-empty one carries the document
%                                      ([session opener inputs]; carry-075)
%
%   A field, block or edge outside these, which the renamed path dropped
%   without a word, now carries the document whole as v1 (private/jRawAccount,
%   jRawCarry; carry-100, [fields outside the template are malformed]); what the renamed path would have
%   discarded (an `ndi_document` beside `base`, a depends_on `version`) is
%   carried, carry-100, [rename clashes are malformed].

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above): what the migrator does not read
% carries the untouched v1 document; a legacy identity block is read as base.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, ...
    struct('session_in_a_dataset', {{'session_id', 'session_reference', 'is_linked', ...
    'session_creator', 'session_creator_input1', 'session_creator_input2', ...
    'session_creator_input3', 'session_creator_input4', 'session_creator_input5', ...
    'session_creator_input6'}}), {});
if jRawCarry('session_in_a_dataset', src, collision, unplaced, 'carry-100')
    v2Body = {src};
    return;
end

block = struct();
if isfield(preBody, 'session_in_a_dataset') && isstruct(preBody.session_in_a_dataset)
    block = preBody.session_in_a_dataset;
end
v2Body = jMembershipBodies(preBody, block);
if isscalar(v2Body) && isequaln(v2Body{1}, preBody)
    v2Body = {src};     % a carry is the untouched v1 source
end
end

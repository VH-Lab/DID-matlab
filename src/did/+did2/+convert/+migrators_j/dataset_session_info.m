function v2Body = dataset_session_info(preBody)
%DATASET_SESSION_INFO Brainstorm-J migrator: did_v1 dataset_session_info -> the
%   session<->dataset membership as first-class relations. This is the legacy
%   AGGREGATE form of session_in_a_dataset: the `dataset_session_info` block holds
%   a `dataset_session_info` structure (scalar or array), one entry per member
%   session, each with the same fields (session_id, is_linked, session_creator,
%   session_creator_input1..6, session_reference). It dissolves exactly like
%   session_in_a_dataset — a bare dataset entity + one session -part_of-> dataset
%   edge per member session (best-effort; dropped by resolveDatasetEntities when a
%   linked member session is not in the batch). The assembly/reconstruction fields
%   are dropped as NDI-internal handles.
%
%   SINCE 2026-10-27 IT WRITES NO V2 DOCUMENT. [fit classes kept; session list
%   rebuilt] (Decided by Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md): "`dataset_session_info` ... is not
%   retired and writes no V2 document: the round trip rebuilds it from the
%   session entities' `included_in` relations to the dataset, and one that
%   does not rebuild exactly is carried whole as v1". The membership relations
%   are the session_in_a_dataset documents'; did2.convert.v1_to_v2
%   (carryUnrebuiltSessionLists) checks, after the batch, that those rebuild
%   this list exactly, and carries it otherwise. The dataset entity and the
%   relations it used to write here duplicated theirs.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-30; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (dataset_session_info.json + base.json at the locked
%   NDI-matlab `main`, 441530d: one block, `dataset_session_info`, holding the
%   list, and no edge). The list is compared with the batch's memberships by
%   v1_to_v2 (carryUnrebuiltSessionLists), which reads the v1 input itself, so
%   the raw read changes nothing it compares; a carry is now the untouched v1
%   source. What the renamed path would have discarded is carried, carry-049,
%   as before; a block, base field or edge outside the template (which the
%   renamed path dropped without a word when the list rebuilt) carries the
%   document whole as v1 (private/jRawAccount, jRawCarry; [fields outside the
%   template are malformed], carry-100). did2.convert.roundtrip.
%   dataset_session_info is the inverse of a carry or a stray passthrough;
%   testRawV1RoundTripSessionList compares the two.

arguments
    preBody (1,1) struct
end

[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'dataset_session_info', {{'dataset_session_info'}}), {});
if jRawCarry('dataset_session_info', preBody, collision, unplaced, 'carry-100')
    v2Body = {preBody};   % the carry of the untouched v1 source
    return;
end
v2Body = {};
end

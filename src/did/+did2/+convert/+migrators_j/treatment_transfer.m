function v2Body = treatment_transfer(preBody)
%TREATMENT_TRANSFER Brainstorm-J migrator: did_v1 treatment_transfer -- always
%   CARRIED whole as v1 under a needs-mapping register row (the document is
%   returned UNCHANGED).
%
%   [treatment transfer stays v1] (Decided by Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md): "To be honest, this is all dataset
%   specific. The only dataset that used treatment transfer was baby [Babu] and
%   we'll do a full reimport for it. I think treatment transfer should just stay
%   v1 passthrough as needs more info" -- a v1 `treatment_transfer` is carried
%   whole as v1 with a needs-mapping register row, for the Babu reimport; the
%   generic stage converts none. Supersedes, for the generic stage, [transfer
%   method keeps its node] and the transfer cases of [broken transfer values
%   are malformed]. The only writer is NDI-matlab
%   +setup/+conv/+babu/TreatmentCreator.m (through
%   +NDIMaker/treatmentMaker create_treatment_transfer_doc).
%
%   Until 2026-10-27 this migrator converted a transfer into a `manipulation`
%   with value kind term on the recipient, a recipient <- donor `derived_from`
%   relation and an anchor; that conversion, and its round-trip inverse, are
%   gone. The class stays in did2.convert.rawV1Classes so that the carry is the
%   untouched v1 source (on the renamed path the carry would be the
%   universalRenames output, which respells entity_ontologyNode and so on);
%   its inverse, did2.convert.roundtrip.treatment_transfer, is the passthrough
%   one and is never reached for a carry.
%
%   THE REGISTER ROW IS PENDING in did-schema: until it exists the note cites the
%   placeholder PENDING_ROW, which names no row (tools/check_carry_citations.py
%   lists this site as a reason with no row).

arguments
    preBody (1,1) struct
end

PENDING_ROW = 'carry-pending-treatment-transfer-needs-mapping';
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: none (needs-mapping row pending in did-schema; PENDING_ROW)
did2.convert.reportNote('carried_as_v1', 'treatment_transfer', id, ...
    ['[' PENDING_ROW '] needs_mapping: a treatment transfer is read by its ' ...
    'dataset''s import (Babu reimport) ([treatment transfer stays v1])']);
v2Body = {preBody};
end

function [rank, known] = schemaVersionRank(version)
%SCHEMAVERSIONRANK Where a schema version sits in the did_v1 -> V_eta line.
%
%   [RANK, KNOWN] = did2.convert.schemaVersionRank(VERSION) returns the
%   position of VERSION in the ordered schema line, and whether the name was
%   recognised at all. An unrecognised name returns RANK = NaN, KNOWN = false;
%   an EMPTY version (a did_v1 body, which carries none) returns RANK = 0.
%
%   WHY AN ORDER HAS TO EXIST SOMEWHERE
%   -----------------------------------
%   `isAlreadyTarget` compared `schema_version` to the target with `strcmp`,
%   and a string compare has no notion of BEFORE and AFTER. So a document
%   NEWER than the target was indistinguishable from one OLDER than it, and
%   both took the same branch: run the migrators. Converting an older document
%   forward is the whole point; running the same pipeline over a newer one is
%   the opposite of what is wanted, and it happened silently.
%
%   THE LINE, AND WHAT IS AND IS NOT IN IT
%   --------------------------------------
%   The names before V_eta were BRAINSTORM iterations -- design drafts, never
%   used for real data. did_v1 is the only vintage in the wild, and V_eta is
%   the first successor intended to hold anything. A name not listed is
%   refused like any unknown version.
%
%   AN UNKNOWN NAME IS `known = false`, NOT RANK 0, and the difference is the
%   point: rank 0 means "a did_v1 body, convert it", while an unknown name
%   means "this code does not recognise this vintage" -- which is what a
%   database written by a NEWER did2 than the one reading it looks like.
%   Collapsing the two would silently run v1 migrators over a future
%   document. Callers decide what to do with `known = false`; this function
%   refuses to guess.
%
%   THE STAMPS did_v1 AND did_v2 (Decided by Jess Haley, 2026-10-25
%   [document stamps], did-schema V_eta_go_forward_class_audit.md): a v1
%   document's `document_class.schema_version` is 'did_v1' and a V2
%   document's is 'did_v2'. 'did_v1' ranks with the empty name (0, a v1
%   document). The V2 names, rank 6, are did2.schema.v2Stamps -- the one
%   list. 'V_eta' is not on the line ([V_eta stamp not accepted], same
%   date: "Stop accepting veta"; no alias, as with V_delta): a document
%   stamped 'V_eta' is unknown and v1_to_v2 quarantines it as
%   did2:convert:unknownSchemaVersion. Every listed name is known.
%
%   Example:
%       [r, k] = did2.convert.schemaVersionRank('V_eta');     % NaN, false
%       [r, k] = did2.convert.schemaVersionRank('did_v2');    % 6, true
%       [r, k] = did2.convert.schemaVersionRank('did_v1');    % 0, true
%       [r, k] = did2.convert.schemaVersionRank('');          % 0, true
%       [r, k] = did2.convert.schemaVersionRank('V_omega');   % NaN, false
%
%   See also DID2.CONVERT.V1_TO_V2, DID2.SCHEMA.ISV1STAMP, DID2.SCHEMA.ISV2STAMP

arguments
    version (1,:) char = ''
end

% did_v1 documents written before [document stamps] carry no schema_version
% at all, so the empty name IS the origin of the line rather than a missing
% value; 'did_v1' is the same vintage, named. The V2 generation's names come
% from did2.schema.v2Stamps and are not repeated here.
v2 = did2.schema.v2Stamps();
NAMES = [{'', 'did_v1', 'V_alpha', 'V_beta', 'V_gamma', 'V_epsilon', 'V_zeta'}, v2(:)'];
RANKS = [0, 0, 1, 2, 3, 4, 5, repmat(6, 1, numel(v2))];

idx = find(strcmp(NAMES, version), 1);
if isempty(idx)
    rank = NaN;
    known = false;
    return;
end
rank = RANKS(idx);   % '' and did_v1 -> 0, V_alpha -> 1, ... the V2 stamps -> 6
known = true;
end

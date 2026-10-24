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
%   Example:
%       [r, k] = did2.convert.schemaVersionRank('V_eta');     % 6, true
%       [r, k] = did2.convert.schemaVersionRank('');          % 0, true
%       [r, k] = did2.convert.schemaVersionRank('V_omega');   % NaN, false
%
%   See also DID2.CONVERT.V1_TO_V2

arguments
    version (1,:) char = ''
end

% did_v1 carries no schema_version at all, so the empty name IS the origin of
% the line rather than a missing value.
ORDER = {'', 'V_alpha', 'V_beta', 'V_gamma', 'V_epsilon', ...
         'V_zeta', 'V_eta'};

idx = find(strcmp(ORDER, version), 1);
if isempty(idx)
    rank = NaN;
    known = false;
    return;
end
rank = idx - 1;      % '' -> 0, V_alpha -> 1, ... V_eta -> 7
known = true;
end

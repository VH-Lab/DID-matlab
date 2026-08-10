function [software, swId] = jSoftware(name, version, url, sessionId, datestamp, opts)
%JSOFTWARE Build a V_eta `software` ENTITY body (the R1 replacement for `app`).
%
%   [SOFTWARE, SWID] = jSoftware(NAME, VERSION, URL, SESSIONID, DATESTAMP)
%   returns the body of one `software` document (⊂ entity) and its base.id, for
%   a caller to emit alongside its own document and reference by a `software_id`
%   edge. Returns [] and '' when NAME is empty -- no identity, no entity, and
%   the caller omits the edge (rule: never emit an empty required edge).
%
%   [...] = jSoftware(..., 'RequireSession', true) ALSO returns [] and '' when
%   SESSIONID is empty. DEFAULT IS FALSE, which is exactly today's behaviour --
%   this option was added, not switched on, because four live callers
%   (daqreader, daqmetadatareader, filenavigator, jCalculation via
%   jSoftwareFromApp) already index the returned struct and would error on [].
%   See "THE EMPTY-SESSION HAZARD" below for why anyone would want it.
%
%   ---------------------------------------------------------------------
%   THIS IS THE ONE PLACE A `software` BODY IS BUILT
%   ---------------------------------------------------------------------
%   It had grown three implementations, two of which omitted the dedup key:
%     - private/jSyncSoftware.m   (syncrule / syncgraph implementation classes)
%     - a LOCAL softwareEntity() inside private/jMethodParameters.m
%   Both now delegate here, so every `software` document in the corpus carries
%   `local_identifier` and the deferred dedup pass has one shape to read.
%   jSyncSoftware's comment justifying its omission -- "jCalculation's software
%   entities do not set it either" -- was true when written and is now false:
%   jCalculation -> jSoftwareFromApp -> jSoftware, which sets it.
%
%   ---------------------------------------------------------------------
%   THE EMPTY-SESSION HAZARD (reported, not silently patched)
%   ---------------------------------------------------------------------
%   `base.session_id` is "mustBeNonEmpty": true (did-schema
%   schemas/V_eta/stable/base.json), so a `software` built with an empty
%   SESSIONID is a document that CANNOT validate -- and because v1_to_v2
%   quarantines the SOURCE when any body it produced fails, one such entity
%   takes its whole source document down with it. Only jMethodParameters
%   guarded against that; the other callers do not. RequireSession makes the
%   guard reusable without changing what any existing caller gets.
%
%   TEAM-SIGN-OFF [software], V_eta_tenet_audit.md:10 -- "the `app` mixin is
%   replaced by a `software` ENTITY (deduplicated by name+version) referenced
%   from a statement by `software_id`, with the run-specific os / interpreter
%   details in `execution_environment` on the interaction (R1)."
%
%   ---------------------------------------------------------------------
%   DEDUPLICATION IS NOT DONE HERE, AND CANNOT BE
%   ---------------------------------------------------------------------
%   "Deduplicated by name+version" is a WHOLE-CORPUS operation. A migrator sees
%   exactly one source document, so it cannot know that another document in
%   another session already minted `ndi.calc.vis.oridir @ 1.2`. Minting one
%   entity per consuming document and merging later is the only shape available
%   to pass 1; the alternative (a deterministic id derived from name+version)
%   would invent an id-minting convention that the rest of DID does not have
%   (did.ido.unique_id is time+random, and IDs are documented as sortable by
%   creation time).
%
%   So the merge is DEFERRED TO THE NDI SECOND PASS, which sees the whole
%   migrated body set. The precedent is exact:
%   ndi.migrate.internal.pathSPromotion -- "using the whole migrated body set
%   (the corpus-wide subject graph) that a single-document migrator cannot see"
%   -- mints part-subjects with a find-or-create/dedup keyed on (animal, site)
%   and RETARGETS the edges of the documents it merges. A software merge is the
%   same operation keyed on (name, version), retargeting `software_id`.
%
%   To make that pass cheap, this helper writes the dedup key where a merger can
%   read it without re-deriving it: `software.local_identifier` = NAME, or
%   NAME@VERSION when a version is known. (The schema calls local_identifier
%   "Optional human-facing handle for this entity, used to cross-reference it
%   within its dataset"; the dedup key is exactly that handle.) `base.name`
%   carries NAME for the same reason.
%
%   The DID-side batch pass did2.convert.resolveDatasetEntities does the
%   equivalent job for `dataset` entities, but only because every dataset
%   container mints on the SAME id (base.session_id) so no edge needs
%   retargeting. Software has no such shared key, so it needs the retargeting
%   form -- i.e. the second pass, not that post-pass.
%
%   Shared helper for the Brainstorm-J (+migrators_j) migrators.
arguments
    name (1,:) char
    version (1,:) char = ''
    url (1,:) char = ''
    sessionId = ''
    datestamp = ''
    opts.RequireSession (1,1) logical = false
end

software = [];
swId = '';
if isempty(name)
    return;     % no identity -> no entity (and the caller omits software_id)
end
if opts.RequireSession && isempty(char(sessionId))
    return;     % opt-in: no session to hang the entity on (see header)
end

swId = did.ido.unique_id();

% The citation id / homepage rides on entity.global_identifier (scheme 'URL' for
% a repository or homepage), matching openMINDS SoftwareVersion's homepage /
% repository slots. Kept as a 0x0 struct array when there is no URL so the field
% is present-and-empty rather than absent-and-guessed-at.
gids = struct('scheme', {}, 'value', {});
if ~isempty(url)
    gids(end+1) = struct('scheme', 'URL', 'value', url);
end

localId = name;
if ~isempty(version)
    localId = [name '@' version];
end

software = struct();
software.document_class = struct('class_name', 'software', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
software.depends_on = struct('name', {}, 'value', {});
% base.datestamp is mustBeNonEmpty on `base`; fall back to the same sentinel
% jSessionAnchor uses rather than emit a document that cannot validate.
ds = char(datestamp);
if isempty(ds)
    ds = '2024-01-01T00:00:00.000Z';
end
software.base = struct('id', swId, 'session_id', char(sessionId), ...
    'name', name, 'datestamp', ds);
software.entity = struct('global_identifier', {gids});
% NORMALISE THE EMPTY, and it is not cosmetic. `version` is declared
% `(1,:) char = ''` in the arguments block, and that size spec COERCES a 0x0
% `''` to a 1x0 char. Both serialise to `""`, so no document differs -- but
% MATLAB has more than one empty char and `verifyEqual(x, '')` compares SIZE,
% so every downstream assertion against `''` failed with
% "Actual 1x0 / Expected 0x0". That surfaced twice in one day, in two unrelated
% test files, and each time it read as a migration defect for a minute.
% Normalising here fixes it once for every caller instead of teaching each test
% about an argument-block artifact.
if isempty(version); version = ''; end
software.software = struct('name', name, 'version', version, ...
    'local_identifier', localId);
end

function [software, swId] = jSyncSoftware(preBody, implementationClass)
%JSYNCSOFTWARE A did_v1 implementation-class string -> a V_eta `software` ENTITY.
%
%   [SOFTWARE, SWID] = jSyncSoftware(PREBODY, IMPLEMENTATIONCLASS) returns
%   a `software` body naming IMPLEMENTATIONCLASS and the id to put on the
%   caller's `software_id` edge. Returns ([], '') when IMPLEMENTATIONCLASS is
%   empty -- NO IDENTITY, NO ENTITY, and the caller must then OMIT the edge
%   rather than emit it blank.
%
%   ---------------------------------------------------------------------
%   WHY THIS EXISTS SEPARATELY FROM jCalculation's jSoftwareFromApp
%   ---------------------------------------------------------------------
%   R1 (`V_eta_tenet_audit.md`, app -> software) folds the v1 `app` BLOCK --
%   {name, version, url, os, interpreter} -- into a `software` entity plus a
%   per-run `execution_environment`. The sync cluster has no `app` block. What it
%   has is a single bare class-name string:
%
%       git show origin/main:src/ndi/ndi_common/database_documents/daq/syncrule.json
%          "syncrule": { "ndi_syncrule_class": "ndi.time.syncrule",
%                        "parameters": [] }
%       git show origin/main:src/ndi/ndi_common/database_documents/daq/syncgraph.json
%          "syncgraph": { "ndi_syncgraph_class": "ndi_syncgraph" }
%
%   and the clock-alignment plan folds exactly that to a `software_id` edge
%   ("<- v1 `ndi_syncrule_class` (R1)" / "<- v1 `ndi_syncgraph_class` (R1)").
%   There is no version, no url and no environment to carry, so reusing
%   jSoftwareFromApp would mean fabricating an `app` block to read back.
%
%   NO DEDUP. One `software` document is emitted per source document, so a
%   session with 26 syncrules yields 26 software entities naming (at most) four
%   distinct implementations. That is the SAME behaviour jCalculation already
%   ships ("One software doc is emitted per calc; a dedup pass is deferred"), and
%   deduplicating here is impossible for the same reason it is impossible there:
%   a single-document migrator cannot see the batch. The software dedup + the
%   openMINDS crosswalk are already tracked together in `V_eta_tenet_audit.md`
%   ("STILL deferred: ... software dedup + openMINDS crosswalk"). The merge now
%   has a home: ndi.migrate.internal.softwareDedup, an NDI second pass that sees
%   the whole migrated body set. It merges on (base.session_id, software.name,
%   software.version) and retargets every inbound edge BY TARGET ID rather than
%   by edge name -- which is why the entity's shape, not its provenance, is what
%   the merge reads, and why this helper only had to start writing the handle.
%
%   `software.version` is left EMPTY, not guessed: nothing in the source records
%   which release of NDI computed the alignment.
%
%   ---------------------------------------------------------------------
%   THE BODY IS NOW BUILT BY private/jSoftware.m (#25, 2026-08-10)
%   ---------------------------------------------------------------------
%   This function used to build the struct itself and closed with the comment:
%
%       "`local_identifier` is deliberately not set (it is optional): the class
%        name is already the identity, and jCalculation's software entities do
%        not set it either."
%
%   THE SECOND CLAUSE IS NO LONGER TRUE -- and it was the whole justification.
%   jCalculation folds through private/jSoftwareFromApp.m, which calls
%   private/jSoftware.m, which HAS set `local_identifier` since the R1 build:
%
%       jSoftware.m:  localId = name;
%                     if ~isempty(version); localId = [name '@' version]; end
%                     software.software = struct('name', name, ...
%                         'version', version, 'local_identifier', localId);
%
%   So the sync entities were the only ones in the corpus with no dedup handle,
%   which would have forced the deferred dedup pass to special-case them. The
%   ONLY change to the emitted document is that `software.local_identifier` is
%   now present, carrying the bare class name (there is no version to append).
%   Everything else -- the empty `entity.global_identifier` array, the preserved
%   base fields, the '' version, the datestamp fallback -- is byte-for-byte what
%   jSoftware already produces, which is why this delegates rather than repeats.
%
%   The empty-global_identifier reasoning is unchanged and now lives in
%   jSoftware.m: a MATLAB class name is not an identifier in any scheme we can
%   name, so the array stays EMPTY rather than being given an invented scheme.
%
%   Shared helper for the Brainstorm-J (+migrators_j) clock-alignment migrators.

software = [];
swId = '';
implementationClass = char(implementationClass);
if isempty(implementationClass)
    return;
end

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp');  datestamp  = preBody.base.datestamp;  end
end

% RequireSession is NOT passed. This preserves the pre-consolidation behaviour
% exactly; switching it on here would silently drop the software_id edge on any
% sync document with an empty base.session_id, which is a change of behaviour
% and therefore a decision, not a cleanup.
[software, swId] = jSoftware(implementationClass, '', '', sessionId, datestamp);
end

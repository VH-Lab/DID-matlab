function [software, swId] = jSyncSoftware(preBody, implementationClass, label)
%JSYNCSOFTWARE A did_v1 implementation-class string -> a V_eta `software` ENTITY.
%
%   [SOFTWARE, SWID] = jSyncSoftware(PREBODY, IMPLEMENTATIONCLASS, LABEL) returns
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
%   ("STILL deferred: ... software dedup + openMINDS crosswalk").
%
%   `software.version` is left EMPTY, not guessed: nothing in the source records
%   which release of NDI computed the alignment.
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
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end

swId = did.ido.unique_id();
software = struct();
software.document_class = struct('class_name', 'software', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
software.depends_on = struct('name', {}, 'value', {});
software.base = struct('id', swId, 'session_id', sessionId, ...
    'name', implementationClass, 'datestamp', datestamp);
% `entity.global_identifier` is an ARRAY of {scheme, value}. A MATLAB class name
% is not an identifier in any scheme we can name, so the array stays EMPTY --
% inventing a scheme would be the same fabrication the ground-truth track exists
% to stop.
software.entity = struct('global_identifier', {struct('scheme', {}, 'value', {})});
software.software = struct('name', implementationClass, 'version', '', ...
    'local_identifier', char(label));
end

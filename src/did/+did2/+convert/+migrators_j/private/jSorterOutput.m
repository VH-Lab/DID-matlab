function bodies = jSorterOutput(preBody, sorterName, dirField)
%JSORTEROUTPUT Decompose a spike-sorting RUN output into the D-C analysis-tier
%   shape. Shared by the external-directory sorter classes (kilosort_clusters,
%   kiasort_clusters) whose doc holds a session-relative output DIRECTORY + a
%   curated-output MD5 rather than attached bytes:
%
%     count_observation           the id-preserved discoverable handle on the
%                                 recording subject (variable 'spike cluster
%                                 assignment', subject_interaction.method = the
%                                 sorter algorithm, storage_mode 'body'). Its id
%                                 IS the source doc id, so any inbound reference
%                                 to the sorter-output doc resolves to it.
%     opaque_body                 the unparsed sorter output directory -- an
%                                 uninterpreted blob (we do not read the sorter
%                                 output at migration time): filename = the
%                                 session-relative directory; description carries
%                                 the curated-output MD5; statement -> the obs.
%     session_relative_reference  the 'during' anchor.
%
%   1 -> 3. Sibling of migrators_j.jrclust_clusters (same family, same handle),
%   but jrclust attaches the *_res.mat BYTES -> a sampled_body, while these carry
%   an EXTERNAL directory -> an opaque_body. The MD5 is a regenerable file hash,
%   kept as a body note rather than re-expressed as data.
%
%   sorterName   the algorithm name for subject_interaction.method (e.g. 'kilosort').
%   dirField     the block field holding the output directory path (e.g.
%                'kilosort_directory').
%
%   ---------------------------------------------------------------------
%   THE `app` BLOCK WAS BEING DROPPED ON THE FLOOR (repaired here)
%   ---------------------------------------------------------------------
%   STATUS OF THIS REPAIR: NOT RUN. There is no MATLAB in the environment it
%   was written in, so nothing below has been executed. The gate is
%   tests/+did2/+unittest/testMigratorsJAppFold.m, which is also unrun.
%
%   kilosort_clusters and kiasort_clusters BOTH declare the `app` superclass on
%   NDI origin/main -- verified by reading the templates, not by memory:
%
%     git show origin/main:.../database_documents/apps/kilosort/kilosort_clusters.json
%     git show origin/main:.../database_documents/apps/kiasort/kiasort_clusters.json
%         superclasses: [ base.json, app.json ]
%
%   So a real document carries app.name / app.version / app.url plus the four
%   os/interpreter fields. This helper BUILDS NEW BODIES rather than passing the
%   source through, so until now every one of those facts was discarded: the
%   source `app` block simply had no successor in {count_observation,
%   opaque_body, session_relative_reference}. NOTHING COUNTED IT -- silentLoss
%   counts empty edges, vacuous fields and fragments, and a source block with no
%   successor is none of the three.
%
%   The R1 fold is what it becomes (TEAM-SIGN-OFF [software],
%   did-schema/schemas/V_eta_tenet_audit.md): a `software` ENTITY referenced by
%   `software_id`, with the per-run os/interpreter in `execution_environment`.
%   Both slots are DECLARED on the target -- checked, not assumed:
%
%     did-schema/schemas/V_eta/stable/subject_interaction.json
%         depends_on: software_id  (must_refer_to_document_class: software)
%         fields:     execution_environment {os, os_version, interpreter,
%                                            interpreter_version}
%     count_observation -> subject_observation -> subject_interaction
%
%   RequireSession IS TRUE HERE. `base.session_id` is mustBeNonEmpty and
%   v1_to_v2 quarantines the SOURCE when a body it produced fails, so an
%   unguarded mint can turn a clean fold into a loss. It costs nothing: the
%   count_observation, the opaque_body and the anchor all take their session_id
%   from the same preBody.base.session_id, so a document with no session was
%   already going to fail on those three -- the guard only makes it impossible
%   for the NEW body to be the reason.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

className = '';
if isfield(preBody, 'document_class') && isstruct(preBody.document_class) ...
        && isfield(preBody.document_class, 'class_name')
    className = char(preBody.document_class.class_name);
end
blk = struct();
if ~isempty(className) && isfield(preBody, className) && isstruct(preBody.(className))
    blk = preBody.(className);
end

directory = jGetChar(blk, dirField);
md5 = jGetCharAny(blk, {'curated_output_md5_checksum', 'curated_output_MD5_checksum'});

% ---- the id-preserved count_observation handle (the run) --------------------
obs = jStartInteraction(preBody, 'count_observation', 'subject_observation', ...
    {'count'}, jOntologyTerm('', 'spike cluster assignment'), ...
    {'element_id', 'subject_id'}, false);
obs.subject_statement.storage_mode = 'body';
obs.subject_interaction.method = jOntologyTerm('', sorterName);   % method = algorithm
obs.count = struct();   % value is body-backed (the opaque sorter output)
obsId = obs.base.id;

% ---- the session-relative 'during' anchor -----------------------------------
anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

% ---- the v1 `app` block -> a software entity + software_id + exec env -------
% Read through jSoftwareFromApp, which accepts BOTH spellings of the name and
% version fields: universalRenames rewrites app.name -> app.app_name and
% app.version -> app.app_version (universalRenames.m:145-164) before any
% migrator runs, and reading only one spelling is the bug that made the calc
% fold emit nothing on every real document for weeks.
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);
if ~isempty(swId)
    obs.depends_on(end+1) = struct('name', 'software_id', 'value', swId);
end
if ~isempty(fieldnames(execEnv))
    % Set only when populated: absence is how V_eta spells "unset", and an
    % empty struct here would add a field to every app-less document.
    obs.subject_interaction.execution_environment = execEnv;
end

% ---- the opaque_body: the external sorter output directory -------------------
sessionId = '';
datestamp = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        datestamp = preBody.base.datestamp;
    end
end
descr = sprintf('%s sorter output directory', sorterName);
if ~isempty(md5)
    descr = sprintf('%s (curated_output_md5_checksum: %s)', descr, md5);
end
body = struct();
body.document_class = struct('class_name', 'opaque_body', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_body', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', {'statement'}, 'value', {obsId});
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', sprintf('migrated_%s_output', sorterName), 'datestamp', datestamp);
% `data_body`, not `opaque_body`, since the #45 hoist (DID-schema
% 2026-08-14): the byte descriptors moved to the abstract parent and a property
% block is keyed by the declaring class. `compression` is EMPTY and that is a
% fact, not a placeholder -- an external sorter directory is stored as it lies.
body.data_body = struct('format', 'directory', 'compression', '', ...
    'filename', directory, 'description', descr);
% carry any attached output bytes verbatim (the external directory is the usual
% case, but a doc that ships files owns them on this body now).
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end

bodies = {obs, body, anchor};
if ~isempty(software)
    bodies{end+1} = software;
end
end

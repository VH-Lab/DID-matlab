function bodies = jSorterOutput(preBody, sorterName, dirField)
%JSORTEROUTPUT Decompose a spike-sorting RUN output into the D-C analysis-tier
%   shape. Shared by the external-directory sorter classes (kilosort_clusters,
%   kiasort_clusters) whose doc holds a session-relative output DIRECTORY + a
%   curated-output MD5 rather than attached bytes:
%
%     count_observation           the id-preserved discoverable handle on the
%                                 recording subject (variable 'spike cluster
%                                 assignment', method = "Spike sorting",
%                                 the sorter is the software; storage_mode 'body'). Its id
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
%   sorterName   the sorter's name (e.g. 'kilosort'): the `software` entity when
%                the v1 document has no `app` block, and the opaque_body's
%                description. NOT the method term: Decided by Jess Haley,
%                2026-10-26 [method terms are general] (did-schema
%                V_eta_go_forward_class_audit.md), the method term is the
%                general procedure, wikidata:Q2003571 "Spike sorting".
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
% did-schema #88: the assignment is an `observation` with a `count` value kind,
% about the recording element, whose value is the sorter's output, an
% opaque_body (the directory) named by its `owner_id`. `data_body` IS true:
% did-schema data_body AMENDMENT 5 (rule `value_inline_or_body`) says a value
% is inline or in data bodies, never neither, and this one has no inline
% value. No `data_type` is given: Jess Haley, 2026-10-21, data_type only for
% plain-array bytes; an opaque_body's `format` term is its encoding. (Until
% then `data_body` was left unset to avoid a byte `data_type` the directory
% does not have.)
anchor = jSessionAnchor(preBody, 'during');
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);
% a calculation names the run's operating system and interpreter
% (operating_system_id / interpreter_id), as jCalculation does
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
if isempty(swId)
    % a calculation requires its calculator (`software_id`, rule
    % require_inherited); with no v1 `app` block it is the sorter by name, as
    % jCalculation does for a calculator with no app block
    [software, swId] = jSoftware(sorterName, '', '', jSid(preBody), jStamp(preBody), ...
        'RequireSession', true);
end
swOpt = {'OperatingSystemId', osId, 'InterpreterId', interpreterId};
if ~isempty(swId); swOpt = [swOpt, {'SoftwareId', swId}]; end
% 2026-10-21: a CALCULATION with the `label` value kind (TEAM-SIGN-OFF
% [spike-sorter output] 2026-09-29: "migrate to label_calculation", and a
% cluster number is a label local to one run, not a count), about the sorted
% electrode. Decided by Jess Haley, 2026-10-21 [sorter input]: its input is the
% electrode's per-epoch recording observations when they exist -- those are
% minted by did2.convert.resolveEpochProbemap, which adds the `input_id` edges
% -- else the electrode entity (this entity_id). [sorter keys]: kilosort and
% kiasort carry NO keys; the output folder is the value as-is (this
% opaque_body, which has none).
obs = jStatement(preBody, 'calculation', ...
    jSubjectOf(preBody, {'element_id', 'subject_id'}), ...
    jLabel('spike cluster assignment'), [], ...
    'Fields', struct('method', jMethod(SPIKE_SORTING())), 'DataBody', true, ...
    'TimeReferenceIds', {anchor.base.id}, swOpt{:}, 'Id', char(preBody.base.id), 'ValueKind', 'label');
% Jess Haley, 2026-10-21 ("a"): the output directory is recorded BY LOCATION,
% as resolveEpochProbemap records an epoch's files -- body_data_0's location is
% the directory path, nothing ingested -- and the curated-output MD5 is the
% body's checksum (content_hash, hash_algorithm MD5), not free text.
descr = sprintf('%s sorter output directory', sorterName);
f = struct();
if ~isempty(directory); f.filename = directory; end
if ~isempty(md5)
    f.content_hash = lower(strtrim(md5));
    f.hash_algorithm = 'MD5';
end
o = jOpts(preBody, 'Notes', descr, 'Fields', f);
body = did2.build.opaqueBody(obs.base.id, ...
    did2.build.formatTerm(SORTER_DIRECTORY_FORMAT()), o{:});
if ~isempty(directory)
    body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
        'delete_original', 0, 'uid', did2.convert.mintId('file_uid'), 'location', directory, ...
        'parameters', '', 'location_type', 'file', 'ingest', 0));
else
    if isfield(preBody, 'files'); body.files = preBody.files; end
    if isfield(preBody, 'file');  body.file  = preBody.file;  end
end
bodies = [{obs, body, anchor}, software, runDocs];
end

function t = SORTER_DIRECTORY_FORMAT()
%SORTER_DIRECTORY_FORMAT The `format` of a sorter's output-directory body:
%   EMPTY:0000315 "directory of files" (Jess Haley, 2026-10-19, empty-ontology
%   d500863, minted for exactly the sorter output folder). The one place it is
%   named.
t = struct('node', 'EMPTY:0000315', 'name', 'directory of files');
end

function t = SPIKE_SORTING()
%SPIKE_SORTING The method term of a sorter's calculation: wikidata:Q2003571
%   "Spike sorting", the general procedure (Decided by Jess Haley, 2026-10-26
%   [method terms are general], did-schema V_eta_go_forward_class_audit.md;
%   registry row built in did-schema bf6bb62). The sorter itself (Kilosort,
%   Kiasort) is the `software` entity on software_id.
t = did2.convert.registeredTerm('wikidata:Q2003571', 'Spike sorting');
end

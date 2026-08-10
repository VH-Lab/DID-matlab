function tests = testMigratorsJAppFold
%TESTMIGRATORSJAPPFOLD The `app` -> `software` fold on the migrators that BUILD
%   NEW BODIES: jrclust_clusters, kilosort_clusters, kiasort_clusters,
%   neuron_extracellular, vmspikefit.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment this file was
%   written in, so every assertion below is UNVERIFIED. Read it as a
%   specification of intended behaviour, not as a passing suite.
%   Run with:  results = runtests('did2.unittest.testMigratorsJAppFold');
%
%   Do NOT merge these into testMigratorsJ.m -- that file is being edited
%   concurrently. See "TESTS ELSEWHERE THAT MUST BE INVERTED" below for the two
%   assertions in it that this change breaks ON PURPOSE.
%
%   ---------------------------------------------------------------------
%   THE SILENT LOSS THIS CLOSES
%   ---------------------------------------------------------------------
%   A did_v1 document that declares the `app` superclass carries the identity of
%   the program that wrote it: app.name, app.version, app.url, plus the four
%   run-time os/interpreter fields. A migrator that PASSES ITS SOURCE THROUGH
%   keeps that block on the tombstone. A migrator that BUILDS NEW BODIES keeps
%   only what it copies -- and these five copied nothing, so the software
%   provenance of every document they convert was discarded.
%
%   NO COUNTER SAW IT. did2.validate.silentLoss counts empty edges, vacuous
%   fields and fragments; did2.validate.isFragment counts bodies that carry
%   almost nothing. A SOURCE BLOCK WITH NO SUCCESSOR is none of those three: the
%   emitted documents are complete and correct as far as they go.
%
%   ---------------------------------------------------------------------
%   THE `app` SUPERCLASS IS REAL ON ALL FIVE -- NDI origin/main, read 2026-08-10
%   ---------------------------------------------------------------------
%     apps/jrclust/jrclust_clusters.json      superclasses [ base, app ]
%     apps/kilosort/kilosort_clusters.json    superclasses [ base, app ]
%     apps/kiasort/kiasort_clusters.json      superclasses [ base, app ]
%     neuron/neuron_extracellular.json        superclasses [ base, app ]
%     apps/vhlab_voltage2firingrate/vmspikefit.json
%                                             superclasses [ base, epochid, app ]
%
%   ---------------------------------------------------------------------
%   WHY EVERY TEST DRIVES did2.convert.v1_to_v2 AND NOT THE MIGRATOR
%   ---------------------------------------------------------------------
%   Not a stylistic choice. did2.convert.universalRenames runs FIRST on the real
%   pipeline and rewrites `app.name` -> `app.app_name` and `app.version` ->
%   `app.app_version` (universalRenames.m:145-164). A direct migrator call skips
%   it -- which is exactly how the calculator fold shipped reading a field name
%   that no real document has, minted nothing on any real document, and stayed
%   green for weeks because testMigratorsJ.m:1707 calls the migrator directly.
%   So the fixtures below spell the app block AS NDI'S TEMPLATE SPELLS IT
%   (`name`, `version`), and the pipeline does the rename. A test that
%   hand-wrote `app_name` would re-create the original blind spot.
%
%   ---------------------------------------------------------------------
%   WHERE THE EDGE IS ALLOWED TO GO -- CHECKED, NOT ASSUMED
%   ---------------------------------------------------------------------
%   `software_id` is declared ONCE in the statement tier, on
%   `subject_interaction` (did-schema schemas/V_eta/stable/subject_interaction.json,
%   must_refer_to_document_class `software`), alongside the
%   `execution_environment` field. So a body may carry the edge only if
%   subject_interaction is in its chain:
%
%       count_observation  -> subject_observation -> subject_interaction   YES
%       score_observation  -> subject_observation -> subject_interaction   YES
%       sampled_body / opaque_body -> data_body -> data -> base            NO
%       session_relative_reference -> time_reference -> base                NO
%       subject -> entity -> base                                          NO
%       directed_relation -> relation -> base                              NO
%
%   testSoftwareIdIsDeclaredWhereWeHangIt below asserts that from the SCHEMA at
%   run time, so an invented edge cannot creep back in behind a passing fold.
%
%   ---------------------------------------------------------------------
%   RequireSession IS TRUE ON ALL FIVE, AND WHY THAT COSTS NOTHING
%   ---------------------------------------------------------------------
%   `base.session_id` is mustBeNonEmpty (schemas/V_eta/stable/base.json) and
%   v1_to_v2 quarantines the SOURCE when any body it produced fails, so an
%   unguarded mint can turn a clean fold into a loss. It takes nothing away
%   here: every body these five migrators already emit takes its session_id from
%   the same preBody.base.session_id, so a sessionless source was already going
%   to fail on those. The guard only makes it impossible for the NEW body to be
%   the reason. testNoSessionMintsNoSoftware pins it.
%
%   ---------------------------------------------------------------------
%   TWO RESIDUAL LOSSES ARE ASSERTED AS LOSSES, NOT PAPERED OVER
%   ---------------------------------------------------------------------
%   `neuron_extracellular` emits its score_observation only when
%   `quality_number` is a numeric scalar, and `vmspikefit` emits its
%   score_observation only when `fit_sse` is. WITHOUT that observation there is
%   no body in the emitted set that declares `software_id`, so the app block
%   still has nowhere typed to go. This file asserts the CURRENT behaviour
%   (no software document) rather than inventing a slot -- inventing an edge on
%   a class that does not declare it is the pattern that produced the
%   invented-empty-edge family. INVERT the two tests named
%   *StillHasNowhereToPutItsSoftware when the team gives those bodies a home.
%
%   ---------------------------------------------------------------------
%   TESTS ELSEWHERE THAT MUST BE INVERTED (not patched) BY WHOEVER LANDS THIS
%   ---------------------------------------------------------------------
%   tests/+did2/+unittest/testMigratorsJ.m  (line numbers as of 2026-08-10; that
%   file is being edited concurrently, so trust the FUNCTION NAMES over them)
%     testKilosortClustersFoldsToCountObservationPlusOpaqueBody   :2281, assert :2299
%         `verifyEqual(testCase, numel(out), 3)` -- its fixture carries
%         `body.app` (:2294), so the correct count is now 4.
%     testKiasortClustersFoldsToCountObservationPlusOpaqueBody    :2317, assert :2331
%         same assertion, same fixture (:2326), same correction.
%   Both assert the OLD arity, which encoded the drop. They were right about the
%   shape and wrong about the count, and were left untouched here only because
%   testMigratorsJ.m is being edited concurrently.
%
%   NOT AFFECTED, checked one by one: testJrclustClustersFoldsToCountObservation
%   (:2250), testNeuronExtracellularMintsDerivedSubject (:2550) and
%   testVmspikefitFoldsToResidualScore (:2712) all use fixtures with NO `app`
%   block, so their counts are unchanged. testFixtureCorpus.m's
%   fx_kilosort_clusters / fx_kiasort_clusters DO carry `app` but assert only
%   0 quarantine / 0 orphans, which the extra entity does not disturb.
%
%   ---------------------------------------------------------------------
%   NOT COVERED HERE, DELIBERATELY: control_stimulus_ids
%   ---------------------------------------------------------------------
%   It is the sixth body-building migrator that drops an `app` block, and it is
%   the one case where the drop is NOT silent: `control_designation` is
%   `base`-only and declares no `software_id`, migrators_j/control_stimulus_ids.m
%   says so in its header ("deferred, tracked" item 2), and
%   testMigratorsJStimulusModel.m:307 ASSERTS the drop, citing the signed
%   stimulus plan's naming pass. Changing it is a team call on the schema, not a
%   migrator repair, so nothing here touches it.

tests = functiontests(localfunctions);
end

% ===================== harness =============================================

function out = runJ(v1)
%RUNJ The full pipeline at V_eta, validation OFF (transform assertions).
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runJValidated(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
end

function d = onlyClass(testCase, out, className)
d = [];
n = 0;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        d = out.migrated{k};
        n = n + 1;
    end
end
assertEqual(testCase, n, 1, sprintf('expected exactly one %s document', className));
end

function tf = hasClass(out, className)
tf = any(strcmp(classNames(out), className));
end

function v = depValue(doc, name)
%DEPVALUE Read an edge tolerantly: `value` on a body a migrator built,
%   `document_id` once universalRenames has normalised it. Same precedence as
%   +did2/+validate/references.m.
v = '';
s = doc;
if isa(doc, 'did2.document'); s = doc.toStruct(); end
if ~isfield(s, 'depends_on') || isempty(s.depends_on); return; end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name); continue; end
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    end
    return;
end
end

function app = ndiAppBlock()
%NDIAPPBLOCK The app block EXACTLY as NDI's template declares it and as
%   ndi.app.newdocument fills it (+ndi/app.m:105-113 -- 'app.name', 'app.version',
%   'app.url', 'app.os', 'app.os_version', 'app.interpreter',
%   'app.interpreter_version'). Spelled `name`/`version` on purpose: the rename
%   to app_name/app_version is universalRenames' job and must happen in the test,
%   not in the fixture.
app = struct('name', 'ndi.app.spikesorter', 'version', '1.4.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', ...
    'os', 'GLNXA64', 'os_version', '5.15.0', ...
    'interpreter', 'MATLAB', 'interpreter_version', '9.13');
end

% ===================== fixtures ============================================

function v1 = sorterBody(className, dirField, withApp, sessionId)
%SORTERBODY kilosort_clusters / kiasort_clusters as NDI's templates declare
%   them: superclasses [base, app], one element_id edge, a session-relative
%   output directory and a curated-output MD5.
if nargin < 4; sessionId = 'sess_09'; end
v1 = struct();
v1.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
v1.base = struct('id', 'srt_1', 'session_id', sessionId, 'name', 'srt', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
if withApp; v1.app = ndiAppBlock(); end
blk = struct('curated_output_MD5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');
blk.(dirField) = 'sorter_out/session1';
v1.(className) = blk;
end

function v1 = jrclustBody(withApp)
v1 = struct();
v1.document_class = struct('class_name', 'jrclust_clusters', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
v1.base = struct('id', 'jc_1', 'session_id', 'sess_09', 'name', 'jc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
if withApp; v1.app = ndiAppBlock(); end
v1.jrclust_clusters = struct('res_mat_md5_checksum', ...
    'd41d8cd98f00b204e9800998ecf8427e');
v1.files = struct('file_list', {{'clusters.mat'}});
end

function v1 = neuronBody(withApp, withQuality)
v1 = struct();
v1.document_class = struct('class_name', 'neuron_extracellular', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
v1.base = struct('id', 'ne_1', 'session_id', 'sess_09', 'name', 'ne', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
if withApp; v1.app = ndiAppBlock(); end
blk = struct('cluster_index', 7, 'number_of_channels', 4);
if withQuality; blk.quality_number = 3; end
v1.neuron_extracellular = blk;
end

function v1 = vmspikefitBody(withApp, withSse)
v1 = struct();
v1.document_class = struct('class_name', 'vmspikefit', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',     'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
v1.base = struct('id', 'vf_1', 'session_id', 'sess_09', 'name', 'vf', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00023');
if withApp; v1.app = ndiAppBlock(); end
blk = struct('fit_equation', 'exp2');
if withSse; blk.fit_sse = 3.25; end
v1.vmspikefit = blk;
end

% ===================== the schema-side guard ===============================

function testSoftwareIdIsDeclaredWhereWeHangIt(testCase)
% THE ANTI-INVENTION GUARD. Read from the built schema at run time, so this
% cannot drift out of step with a comment. The edge lives on subject_interaction
% and nowhere else in these chains -- adding it to a body whose chain does not
% include subject_interaction is the invented-empty-edge pattern.
cache = did2.schema.cache.shared();
for c = {'count_observation', 'score_observation'}
    chain = [c, cache.superclasses(c{1})];
    verifyTrue(testCase, any(strcmp(chain, 'subject_interaction')), ...
        sprintf('%s must reach subject_interaction to carry software_id', c{1}));
end
for c = {'sampled_body', 'opaque_body', 'session_relative_reference', ...
         'subject', 'directed_relation'}
    chain = [c, cache.superclasses(c{1})];
    verifyFalse(testCase, any(strcmp(chain, 'subject_interaction')), ...
        sprintf('%s does NOT declare software_id; nothing may hang it there', c{1}));
end
% jsondecode returns a CELL of structs when the depends_on entries do not all
% carry the same keys (subject_interaction's do not -- only `time_reference_#`
% has `multiple`/`min_count`), and a STRUCT ARRAY when they do. Handle both, or
% this guard breaks the next time a key is added and reads as a schema failure.
si = cache.getClass('subject_interaction');
deps = si.depends_on;
if ~iscell(deps); deps = num2cell(deps); end
found = false;
for k = 1:numel(deps)
    if strcmp(char(deps{k}.name), 'software_id'); found = true; end
end
verifyTrue(testCase, found, 'subject_interaction must declare software_id');
end

% ===================== kilosort / kiasort (via jSorterOutput) ==============

function testKilosortAppBecomesASoftwareEntityAndEdge(testCase)
% The whole fold in one document. Note `local_identifier`: jSoftware writes
% NAME@VERSION as the handle the deferred corpus-wide dedup pass reads, and two
% of the three historical software builders omitted it.
out = runJ(sorterBody('kilosort_clusters', 'kilosort_directory', true));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 4);   % obs + opaque_body + anchor + software

sw = onlyClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi.app.spikesorter');
verifyEqual(testCase, sw.get('software.version'), '1.4.2');
verifyEqual(testCase, sw.get('software.local_identifier'), 'ndi.app.spikesorter@1.4.2');
verifyEqual(testCase, sw.get('base.session_id'), 'sess_09');

obs = onlyClass(testCase, out, 'count_observation');
verifyEqual(testCase, depValue(obs, 'software_id'), sw.get('base.id'));
verifyEqual(testCase, obs.get('base.id'), 'srt_1');            % id still preserved
verifyEqual(testCase, depValue(obs, 'subject_id'), 'rec_sub_1');
end

function testKilosortExecutionEnvironmentIsCarried(testCase)
% The per-run os/interpreter is provenance of THIS EXECUTION, distinct from the
% software's identity, and it has its own typed slot on subject_interaction.
% These four field names are already snake_case, so universalRenames leaves them
% alone -- which is why the old fold populated them while minting no entity.
out = runJ(sorterBody('kilosort_clusters', 'kilosort_directory', true));
obs = onlyClass(testCase, out, 'count_observation');
verifyEqual(testCase, obs.get('subject_interaction.execution_environment.os'), 'GLNXA64');
verifyEqual(testCase, obs.get('subject_interaction.execution_environment.os_version'), '5.15.0');
verifyEqual(testCase, obs.get('subject_interaction.execution_environment.interpreter'), 'MATLAB');
verifyEqual(testCase, obs.get('subject_interaction.execution_environment.interpreter_version'), '9.13');
end

function testKilosortUrlRidesOnTheEntityGlobalIdentifier(testCase)
% app.url is the repository/homepage; jSoftware puts it on
% entity.global_identifier with scheme 'URL' (matching openMINDS
% SoftwareVersion.homepage/repository), not on a bespoke field.
out = runJ(sorterBody('kilosort_clusters', 'kilosort_directory', true));
sw  = onlyClass(testCase, out, 'software');
gid = sw.get('entity.global_identifier');
verifyEqual(testCase, numel(gid), 1);
verifyEqual(testCase, gid(1).scheme, 'URL');
verifyEqual(testCase, gid(1).value, 'https://github.com/VH-Lab/NDI-matlab');
end

function testKiasortFoldsTheSameWay(testCase)
% Sibling class, same helper (private/jSorterOutput.m). Asserted separately
% because "the sibling is covered by the other test" is how a divergence hides.
out = runJ(sorterBody('kiasort_clusters', 'kiasort_directory', true));
verifyEmpty(testCase, out.quarantine);
sw  = onlyClass(testCase, out, 'software');
obs = onlyClass(testCase, out, 'count_observation');
verifyEqual(testCase, depValue(obs, 'software_id'), sw.get('base.id'));
verifyEqual(testCase, obs.get('subject_interaction.method.name'), 'kiasort');
end

function testSorterWithoutAnAppBlockIsUnchanged(testCase)
% The fold must be free when there is nothing to fold: no entity, no edge, and
% NO empty execution_environment field manufactured on the observation
% (absence is how V_eta spells unset).
out = runJ(sorterBody('kilosort_clusters', 'kilosort_directory', false));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3);
verifyFalse(testCase, hasClass(out, 'software'));
obs = onlyClass(testCase, out, 'count_observation');
verifyEmpty(testCase, depValue(obs, 'software_id'));
verifyFalse(testCase, isfield(obs.get('subject_interaction'), 'execution_environment'));
end

function testNoSessionMintsNoSoftware(testCase)
% RequireSession = true. `base.session_id` is mustBeNonEmpty, and v1_to_v2
% quarantines the SOURCE when a body it produced fails -- so minting an entity
% that cannot validate would turn a clean fold into a loss. Nothing is taken
% away: the observation, the body and the anchor all carry the same empty
% session_id and fail on their own account under a validating run.
out = runJ(sorterBody('kilosort_clusters', 'kilosort_directory', true, ''));
verifyFalse(testCase, hasClass(out, 'software'));
obs = onlyClass(testCase, out, 'count_observation');
verifyEmpty(testCase, depValue(obs, 'software_id'));
end

function testKilosortFoldValidates(testCase)
% The bodies are only worth emitting if they get through the validator.
out = runJValidated(sorterBody('kilosort_clusters', 'kilosort_directory', true));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 4);
end

% ===================== jrclust_clusters ====================================

function testJrclustAppBecomesASoftwareEntityAndEdge(testCase)
% Same family, different body type (attached res.mat bytes -> sampled_body
% rather than an external directory -> opaque_body). The software fold is
% identical; only the payload differs.
out = runJ(jrclustBody(true));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 4);
verifyTrue(testCase, hasClass(out, 'sampled_body'));

sw  = onlyClass(testCase, out, 'software');
obs = onlyClass(testCase, out, 'count_observation');
verifyEqual(testCase, depValue(obs, 'software_id'), sw.get('base.id'));
verifyEqual(testCase, obs.get('base.id'), 'jc_1');             % id still preserved
verifyEqual(testCase, obs.get('subject_interaction.execution_environment.interpreter'), ...
    'MATLAB');
end

function testJrclustWithoutAnAppBlockIsUnchanged(testCase)
out = runJ(jrclustBody(false));
verifyEqual(testCase, numel(out.migrated), 3);
verifyFalse(testCase, hasClass(out, 'software'));
end

% ===================== neuron_extracellular ================================

function testNeuronExtracellularHangsSoftwareOnTheQualityObservation(testCase)
% Of the four bodies this migrator emits, only the score_observation reaches
% subject_interaction, so that is where the edge goes. The derived subject and
% the derived_from relation get NOTHING -- deliberately.
out = runJ(neuronBody(true, true));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 5);   % subject + relation + anchor + obs + software

sw   = onlyClass(testCase, out, 'software');
qobs = onlyClass(testCase, out, 'score_observation');
verifyEqual(testCase, depValue(qobs, 'software_id'), sw.get('base.id'));
verifyEqual(testCase, qobs.get('subject_interaction.execution_environment.os'), 'GLNXA64');

neuron = onlyClass(testCase, out, 'subject');
verifyEmpty(testCase, depValue(neuron, 'software_id'));
rel = onlyClass(testCase, out, 'directed_relation');
verifyEmpty(testCase, depValue(rel, 'software_id'));
end

function testNeuronExtracellularWithoutQualityStillHasNowhereToPutItsSoftware(testCase)
% A RESIDUAL LOSS, ASSERTED AS ONE. Without `quality_number` there is no
% score_observation, and none of {subject, directed_relation,
% session_relative_reference} declares `software_id`. No slot is invented for
% it. INVERT THIS TEST when the team gives those bodies a home -- do not patch
% it, because a patched version would assert whatever the code then did.
out = runJ(neuronBody(true, false));
verifyEmpty(testCase, out.quarantine);
verifyFalse(testCase, hasClass(out, 'score_observation'));
verifyFalse(testCase, hasClass(out, 'software'));
verifyEqual(testCase, numel(out.migrated), 3);
end

% ===================== vmspikefit ==========================================

function testVmspikefitHangsSoftwareOnTheResidualObservation(testCase)
% This class is where the software identity matters most: its own field-name
% repair turned on WHICH program wrote the fit (fit_sse, not r_squared), and the
% answer was being thrown away with the block.
out = runJ(vmspikefitBody(true, true));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3);   % obs + anchor + software

sw  = onlyClass(testCase, out, 'software');
obs = onlyClass(testCase, out, 'score_observation');
verifyEqual(testCase, depValue(obs, 'software_id'), sw.get('base.id'));
verifyEqual(testCase, obs.get('score.value.value'), 3.25, 'AbsTol', 1e-9);
verifyEqual(testCase, obs.get('subject_interaction.method.name'), 'exp2');
verifyEqual(testCase, obs.get('subject_interaction.execution_environment.interpreter_version'), ...
    '9.13');
end

function testVmspikefitWithoutSseStillHasNowhereToPutItsSoftware(testCase)
% The second RESIDUAL LOSS, asserted as one. No fit_sse -> no score_observation
% -> only a bare session anchor, which declares no software_id. INVERT when the
% team gives it a home; do not patch.
out = runJ(vmspikefitBody(true, false));
verifyEmpty(testCase, out.quarantine);
verifyFalse(testCase, hasClass(out, 'score_observation'));
verifyFalse(testCase, hasClass(out, 'software'));
verifyEqual(testCase, numel(out.migrated), 1);
end

function testVmspikefitFoldValidates(testCase)
out = runJValidated(vmspikefitBody(true, true));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3);
end

% ===================== the rename trap, pinned =============================

function testTheFoldSurvivesTheUniversalRename(testCase)
% THE REGRESSION TEST FOR THE BUG THAT MADE THIS FOLD EMIT NOTHING FOR WEEKS.
% universalRenames rewrites app.name -> app.app_name and app.version ->
% app.app_version (universalRenames.m:145-164). This asserts the RENAMED
% spelling is what actually reached the fold -- i.e. the software name did not
% come from a fixture that happened to also carry the old spelling.
v1 = sorterBody('kilosort_clusters', 'kilosort_directory', true);
renamed = did2.convert.universalRenames(v1);
verifyTrue(testCase, isfield(renamed.app, 'app_name'), ...
    'universalRenames must have produced app_name -- if not, this test is vacuous');
verifyFalse(testCase, isfield(renamed.app, 'name'));

out = runJ(v1);
sw  = onlyClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi.app.spikesorter');
end

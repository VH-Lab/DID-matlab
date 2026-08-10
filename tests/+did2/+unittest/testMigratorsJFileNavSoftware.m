function tests = testMigratorsJFileNavSoftware
%TESTMIGRATORSJFILENAVSOFTWARE Brainstorm-J: the file-navigation and software folds.
%
%   Covers the two signed families:
%
%     TEAM-SIGN-OFF [file navigation]  jess, 2026-08-06
%       (did-schema schemas/V_eta_daq_family_decisions.md:325)
%       "filenavigator becomes `epoch_file_pattern` with base.id preserved: the
%        two eval'd parameter strings become declared pattern lists
%        (data_file_pattern, epoch_map_pattern) plus epoch_map_format, and the
%        implementation class name becomes a software_id edge."
%
%     TEAM-SIGN-OFF [software]         jess, 2026-08-06
%       (did-schema schemas/V_eta_tenet_audit.md:10)
%       "the `app` mixin is replaced by a `software` ENTITY (deduplicated by
%        name+version) referenced from a statement by `software_id`, with the
%        run-specific os / interpreter details in `execution_environment` on the
%        interaction (R1). The class name stops being copied into every
%        calculator output."
%
%   ---------------------------------------------------------------------
%   EVERY TEST HERE DRIVES did2.convert.v1_to_v2, NOT THE MIGRATOR DIRECTLY
%   ---------------------------------------------------------------------
%   That is the point of the file, not a stylistic choice. testMigratorsJ.m's
%   software assertions call `did2.convert.migrators_j.oridirtuning_calc(body)`
%   with a hand-built body (testMigratorsJ.m:1707), which SKIPS
%   did2.convert.universalRenames. universalRenames renames `app.name` ->
%   `app.app_name` and `app.version` -> `app.app_version` before any migrator
%   runs (universalRenames.m:145-164), so the direct call and the real pipeline
%   hand the migrator two different bodies -- and the fold read only the
%   pre-rename spelling, so it minted no software entity on any real document
%   while the direct-call test stayed green. See private/jSoftwareFromApp.m.
%
%   Bodies come back as did2.document OBJECTS from v1_to_v2; read them with
%   .get('dotted.path') or .toStruct(). A depends_on entry is spelled `value` on
%   a body a migrator built and `document_id` after universalRenames, so depValue
%   below accepts both (the same precedence as +did2/+validate/references.m:176).
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring environment,
%   so these tests have never been run.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJFileNavSoftware');

tests = functiontests(localfunctions);
end

% ===================== family 1: file navigation ===========================

function testFilenavigatorFoldsToEpochFilePatternPlusSoftware(testCase)
% The whole signed mapping in one document. Source values are the ones NDI's own
% writers build: +ndi/+test/+daq/intan_flat_metadata.m:29 constructs
%   ndi.file.navigator(E, {'#\.rhd\>', '#\.tsv\>'})
% and +ndi/+test/+daq/build_intan_flat_exp.m:50 passes the epochprobemap
% parameter {'(.*)epochprobemap.ndi'}. ndi.file.navigator/newdocument
% (navigator.m:738,746) stores each through cell2str, so what a real document
% carries is that cell's TEXT: "{ 'a', 'b' }".
out = runJ(navBody('{ ''#\.rhd\>'', ''#\.tsv\>'' }', ...
    'ndi.epoch.epochprobemap_daqsystem', '{ ''(.*)epochprobemap.ndi'' }'));

verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);      % pattern + software
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'epoch_file_pattern')));
verifyTrue(testCase, any(strcmp(names, 'software')));

efp = out.migrated{find(strcmp(names, 'epoch_file_pattern'), 1)};
sw  = out.migrated{find(strcmp(names, 'software'), 1)};

% base.id PRESERVED. daqsystem.filenavigator_id and
% epochfiles_ingested.filenavigator_id are BOTH declared "mustbenotempty": 1 on
% NDI origin/main, and +ndi/+daq/system.m:36-44 looks the navigator up by that
% id, so minting a fresh one here would dangle every daqsystem in the corpus.
verifyEqual(testCase, efp.get('base.id'), 'fn_1');
verifyEqual(testCase, efp.get('base.session_id'), 'sess_1');
verifyEqual(testCase, efp.get('document_class.schema_version'), 'V_eta');

% the two eval'd strings became declared LISTS -- parsed, never eval'd
verifyEqual(testCase, efp.get('epoch_file_pattern.data_file_pattern'), ...
    {'#\.rhd\>', '#\.tsv\>'});
verifyEqual(testCase, efp.get('epoch_file_pattern.epoch_map_pattern'), ...
    {'(.*)epochprobemap.ndi'});
verifyEqual(testCase, efp.get('epoch_file_pattern.epoch_map_format'), ...
    'ndi.epoch.epochprobemap_daqsystem');

% the implementation class name became an EDGE, not a string field
verifyEqual(testCase, depValue(efp.toStruct(), 'software_id'), sw.get('base.id'));
verifyEqual(testCase, sw.get('software.name'), 'ndi.file.navigator');
% v1 records no version for the navigator class (the template has no version
% field), so the dedup handle is the bare name.
%
% verifyEmpty, NOT verifyEqual(...,''). verifyEqual compares SIZE, and MATLAB
% has more than one empty char: `''` is 0x0 while a char built by indexing or
% concatenation is commonly 1x0. This assertion failed on exactly that --
% "Actual char: 1x0 empty char array / Expected char: 0x0 empty char array" --
% which is a fact about how the empty was constructed, not about the migration.
% Pinning the shape tests the constructor; pinning emptiness and the class
% tests what the assertion is actually for.
verifyClass(testCase, sw.get('software.version'), 'char');
verifyEmpty(testCase, sw.get('software.version'));
verifyEqual(testCase, sw.get('software.local_identifier'), 'ndi.file.navigator');

% and the v1 block does not survive anywhere
verifyFalse(testCase, isfield(efp.toStruct(), 'filenavigator'));
end

function testFilenavigatorSinglePatternStaysAList(testCase)
% A one-element list is still a list. `ndi.file.navigator(E, '.*\.rhd\>')`
% (+ndi/+session/mock.m:54) is normalised to a cell by setfileparameters
% (navigator.m:403-409) before it is ever stored, so the stored text is braced
% even for one pattern -- and the migrated representation must not change shape
% with the number of patterns (the drift rule, V_eta_openminds_family_record.md
% Part 3).
out = runJ(navBody('{ ''.*\.rhd\>'' }', 'ndi.epoch.epochprobemap_daqsystem', ''));
verifyEmpty(testCase, out.quarantine);
efp = firstOfClass(out, 'epoch_file_pattern');
verifyEqual(testCase, efp.get('epoch_file_pattern.data_file_pattern'), {'.*\.rhd\>'});
% nothing was declared for the probe-map file, so the field is ABSENT rather
% than blank -- a blank required-ish field is what silentLoss counts as vacuous.
verifyFalse(testCase, isfield(efp.get('epoch_file_pattern'), 'epoch_map_pattern'));
end

function testFilenavigatorUnbracedParameterIsOneLiteralPattern(testCase)
% Defensive, and deliberately so: cell2str always braces its output, but
% navigator.m:45 recovers the field with a bare `eval`, which accepts an
% unbraced string too. Such a document is one pattern, not zero -- discarding it
% would be silent loss of the only thing the document says.
out = runJ(navBody('.*\.rhd\>', '', ''));
verifyEmpty(testCase, out.quarantine);
efp = firstOfClass(out, 'epoch_file_pattern');
verifyEqual(testCase, efp.get('epoch_file_pattern.data_file_pattern'), {'.*\.rhd\>'});
end

function testFilenavigatorEmptyListTextDeclaresNoPatterns(testCase)
% cell2str returns the literal '{}' for an empty cell (cell2str.m:19). That is
% "no patterns declared", not a pattern named "{}".
out = runJ(navBody('{}', 'ndi.epoch.epochprobemap_daqsystem', '{}'));
verifyEmpty(testCase, out.quarantine);
efp = firstOfClass(out, 'epoch_file_pattern');
blk = efp.get('epoch_file_pattern');
verifyFalse(testCase, isfield(blk, 'data_file_pattern'));
verifyFalse(testCase, isfield(blk, 'epoch_map_pattern'));
verifyEqual(testCase, blk.epoch_map_format, 'ndi.epoch.epochprobemap_daqsystem');
end

function testFilenavigatorWithNothingToDeclarePassesThrough(testCase)
% THE GUARD (the fitcurve / openminds_stimulus / probe_geometry shape). All four
% source fields empty means an epoch_file_pattern with no patterns, no format and
% no software edge -- a hollow document that validates clean and says nothing.
% The source class keeps its V_eta tombstone, so passing through loses nothing
% and shows up in `unconverted_by_class` where it can be counted.
v1 = navBody('', '', '');
v1.filenavigator.ndi_filenavigator_class = '';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'filenavigator');
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testFilenavigatorWithoutImplementationClassOmitsTheEdge(testCase)
% RULE: never emit an empty required edge; omit it. `software_id` is optional on
% epoch_file_pattern (mustBeNonEmpty: false), and an empty edge would be INVISIBLE
% rather than absent -- +did2/+validate/references.m:90 skips empty edges, which
% is exactly how 59 of 59 empty daqmetadatareader.daqsystem_id values passed
% every gate.
v1 = navBody('{ ''#.rhd'' }', 'ndi.epoch.epochprobemap_daqsystem', '');
v1.filenavigator.ndi_filenavigator_class = '';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);          % no software body
efp = firstOfClass(out, 'epoch_file_pattern');
verifyEqual(testCase, depValue(efp.toStruct(), 'software_id'), '');
verifyEqual(testCase, efp.get('epoch_file_pattern.data_file_pattern'), {'#.rhd'});
end

function testFilenavigatorSubclassNamesItsOwnSoftware(testCase)
% newdocument writes class(obj) (navigator.m:737), so a subclass records ITSELF:
% ndi.file.navigator.epochdir, .rhd_series, ndi.setup.file.navigator.vhPrairie2p.
% Two different implementations must not collapse into one software entity.
v1 = navBody('{ ''#.tif'' }', 'ndi.epoch.epochprobemap_daqsystem', '');
v1.filenavigator.ndi_filenavigator_class = 'ndi.setup.file.navigator.vhPrairie2p';
out = runJ(v1);
sw = firstOfClass(out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi.setup.file.navigator.vhPrairie2p');
verifyEqual(testCase, sw.get('base.name'), 'ndi.setup.file.navigator.vhPrairie2p');
end

% ===================== family 2: the app -> software fold ==================

function testAppBlockBecomesSoftwareOnTheFullPipeline(testCase)
% THE REGRESSION TEST. This is the same fold testMigratorsJ.m:1707 asserts, run
% through v1_to_v2 instead of by direct call -- so universalRenames runs first and
% the migrator sees `app_name` / `app_version` rather than `name` / `version`.
% Before private/jSoftwareFromApp.m read both spellings this produced 2 bodies
% (leaf + anchor) with no software entity and no software_id edge, while
% execution_environment (whose fields are not renamed) filled in normally.
v1 = struct();
v1.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'orientation_direction_tuning', 'class_version', '1.0.0'), ...
                      struct('class_name', 'tuning_fit', 'class_version', '1.0.0')]);
v1.depends_on = [ struct('name', 'element_id', 'value', 'neuron_9'), ...
                  struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_9')];
v1.base = struct('id', 'oc_2', 'session_id', 'sess_09', 'name', 'oc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% EXACTLY the seven fields NDI's app template declares
% (ndi_common/database_documents/app.json on origin/main).
v1.app = struct('name', 'ndi.calc.vis.oridir', 'version', '1.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
v1.oridirtuning_calc = struct('input_parameters', struct('independent_variable', 'direction'));
v1.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5));

out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    ['no software entity was minted -- the app fold read a field name that ' ...
     'universalRenames had already rewritten']);
sw = out.migrated{find(strcmp(names, 'software'), 1)};
verifyEqual(testCase, sw.get('software.name'), 'ndi.calc.vis.oridir');
verifyEqual(testCase, sw.get('software.version'), '1.2');

% the dedup key the deferred second pass will merge on
verifyEqual(testCase, sw.get('software.local_identifier'), 'ndi.calc.vis.oridir@1.2');
% the homepage rides on entity.global_identifier, scheme URL
gid = sw.get('entity.global_identifier');
verifyEqual(testCase, numel(gid), 1);
verifyEqual(testCase, gid(1).scheme, 'URL');

leaf = out.migrated{find(~strcmp(names, 'software') & ...
    ~strcmp(names, 'session_relative_reference'), 1)};
verifyEqual(testCase, depValue(leaf.toStruct(), 'software_id'), sw.get('base.id'));
% run-specific details go to execution_environment on the interaction, NOT onto
% the software entity (the software's identity is name+version; the os it
% happened to run on is a fact about this run).
verifyEqual(testCase, leaf.get('subject_interaction.execution_environment.interpreter'), ...
    'MATLAB');
verifyEqual(testCase, leaf.get('subject_interaction.execution_environment.os'), 'Linux');
% "The class name stops being copied into every calculator output": no app block
% survives on the migrated document.
verifyFalse(testCase, isfield(leaf.toStruct(), 'app'));
end

function testCalculatorWithNoAppBlockMintsNoSoftware(testCase)
% No identity -> no entity and NO edge, rather than a software document named ''
% with an edge pointing at it. Same rule as the navigator with no implementation
% class: an empty edge is invisible, an absent one is honest.
v1 = struct();
v1.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'orientation_direction_tuning', 'class_version', '1.0.0'), ...
                      struct('class_name', 'tuning_fit', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', 'neuron_9');
v1.base = struct('id', 'oc_3', 'session_id', 'sess_09', 'name', 'oc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.orientation_direction_tuning = struct('vector', struct('orientation_preference', 12));

out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'software')));
leaf = out.migrated{find(~strcmp(names, 'session_relative_reference'), 1)};
verifyEqual(testCase, depValue(leaf.toStruct(), 'software_id'), '');
end

function testSoftwareIsNotDedupedInPassOne(testCase)
% DEDUP BY (name, version) IS DEFERRED, and this pins that so the deferral is a
% recorded fact rather than an assumption. Two calculator outputs naming the SAME
% program mint TWO software entities in pass 1: a single-document migrator cannot
% know about a document it never sees. The merge is the NDI second pass's job --
% a whole-corpus find-or-create with edge retargeting, the shape of
% ndi.migrate.internal.pathSPromotion. Both entities carry the same
% local_identifier, which is the key that pass merges on.
%
% WHEN THAT PASS LANDS this test should be REPLACED, not deleted: assert one
% entity survives and both edges point at it.
a = calcBodyNamed('oc_a', 'ndi.calc.vis.oridir', '1.2');
b = calcBodyNamed('oc_b', 'ndi.calc.vis.oridir', '1.2');
out = runJ({a, b});
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
sw = out.migrated(strcmp(names, 'software'));
verifyEqual(testCase, numel(sw), 2);
verifyEqual(testCase, sw{1}.get('software.local_identifier'), 'ndi.calc.vis.oridir@1.2');
verifyEqual(testCase, sw{2}.get('software.local_identifier'), 'ndi.calc.vis.oridir@1.2');
verifyNotEqual(testCase, sw{1}.get('base.id'), sw{2}.get('base.id'));
end

% ===================== validation =========================================

function testNavigatorWithoutPatternListsValidates(testCase)
% THE ONE VALIDATING RUN. Both families at once, with the schema switched on:
% an epoch_file_pattern (scalar epoch_map_format only) plus its software entity
% must satisfy V_eta as declared. Realistic, not contrived --
% ndi.file.navigator's constructor defaults epochprobemap_class to
% 'ndi.epoch.epochprobemap_daqsystem' (navigator.m:92) whether or not any
% fileparameters were given, and newdocument stores '' for an unset
% fileparameters (navigator.m:740), so a navigator built as
% `ndi.file.navigator(E)` produces exactly this document.
%
% It deliberately carries NO pattern list -- not because a list cannot validate
% (it can, since data_file_pattern became `string` on 2026-08-10), but because
% this is the minimal shape ndi.file.navigator(E) actually produces. The list
% case has its own validating test, testEpochFilePatternListValidatesCleanly.
v1 = navBody('', 'ndi.epoch.epochprobemap_daqsystem', '');
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('quarantined under validation: [%s] %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 2);
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'epoch_file_pattern')));
verifyTrue(testCase, any(strcmp(names, 'software')));
end

function testEpochFilePatternListValidatesCleanly(testCase)
% RENAMED AND INVERTED 2026-08-10, ON THE INSTRUCTION OF ITS OWN PREDECESSOR.
%
% This was `testEpochFilePatternListIsBlockedByTheCharDeclaration`, a TRIPWIRE
% that asserted the quarantine caused by a schema defect: epoch_file_pattern
% declared data_file_pattern and epoch_map_pattern as
% "type": "char", "mustBeScalar": false -- plainly intending a list (its own
% documentation gives {'#\.rhd\>', '#\.tsv\>'} as the value) -- while the
% validator's char branch accepts only a char array or a SCALAR string
% (+did2/+schema/cache.m:965-970). Only the `string` branch takes a
% cell-of-chars, and it exists for exactly this case.
%
% Its header said, in these words: "THE FIX IS ONE WORD, TWICE, IN DID-schema
% ... WHEN IT LANDS THIS TEST FAILS -- that is its purpose. Replace it with an
% assertion that the document validates clean, and drop the corpus-run embargo."
%
% The fix landed, the test failed within one CI run (0 quarantines where it
% demanded 1), and this is that replacement. The embargo is lifted in
% filenavigator.m's header.
%
% Keep this test. The defect it guards is not gone, it is FIXED -- and a
% multi-pattern navigator is the only shape that exercises the cell-of-chars
% path, so without an assertion here a future re-tightening to `char` would
% quarantine every multi-pattern navigator in the corpus silently.
v1 = navBody('{ ''#\.rhd\>'', ''#\.tsv\>'' }', 'ndi.epoch.epochprobemap_daqsystem', '');
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf( ...
        ['a multi-pattern navigator must validate now that data_file_pattern ' ...
         'is `string`: [%s] %s'], ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 2);   % pattern + software
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'epoch_file_pattern')));
% the LIST survived as a list -- not joined, not padded, not drifted to a char
efp = out.migrated{find(strcmp(names, 'epoch_file_pattern'), 1)};
verifyEqual(testCase, efp.get('epoch_file_pattern.data_file_pattern'), ...
    {'#\.rhd\>', '#\.tsv\>'});
end

% ===================== helpers ============================================

function out = runJ(v1)
%RUNJ The full pipeline at V_eta with validation OFF (transform assertions).
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v1 = navBody(fileParams, mapClass, mapParams)
%NAVBODY A did_v1 filenavigator document, shaped as NDI's template declares it.
%   ndi_common/database_documents/daq/filenavigator.json: superclass base, NO
%   dependencies, and exactly four fields.
v1 = struct();
v1.document_class = struct('class_name', 'filenavigator', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', 'fn_1', 'session_id', 'sess_1', 'name', 'intan1_nav', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.filenavigator = struct( ...
    'ndi_filenavigator_class',      'ndi.file.navigator', ...
    'fileparameters',               fileParams, ...
    'epochprobemap_class',          mapClass, ...
    'epochprobemap_fileparameters', mapParams);
end

function v1 = calcBodyNamed(docId, appName, appVersion)
%CALCBODYNAMED A minimal calculator output naming a program in its app block.
v1 = struct();
v1.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'orientation_direction_tuning', 'class_version', '1.0.0'), ...
                      struct('class_name', 'tuning_fit', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', 'neuron_9');
v1.base = struct('id', docId, 'session_id', 'sess_09', 'name', 'oc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', appName, 'version', appVersion, 'url', '', ...
    'os', '', 'os_version', '', 'interpreter', '', 'interpreter_version', '');
v1.orientation_direction_tuning = struct('vector', struct('orientation_preference', 12));
end

function names = classNames(out)
names = cellfun(@(d) d.get('document_class.class_name'), out.migrated, ...
    'UniformOutput', false);
end

function doc = firstOfClass(out, className)
names = classNames(out);
idx = find(strcmp(names, className), 1);
assert(~isempty(idx), 'no %s document was emitted (got: %s)', className, ...
    strjoin(names, ', '));
doc = out.migrated{idx};
end

function v = depValue(b, name)
%DEPVALUE Read an edge off a RAW BODY STRUCT, accepting BOTH spellings.
%   universalRenames normalises v1's {name, value} to {name, document_id}
%   (universalRenames.m:372-380), so which one a body carries depends on where it
%   came from: a migrator that BUILT the edge still has `value`, an edge that
%   came through the rename has `document_id`. Precedence copied from
%   +did2/+validate/references.m:176-179.
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name); continue; end
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id); return;
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value); return;
    end
end
end

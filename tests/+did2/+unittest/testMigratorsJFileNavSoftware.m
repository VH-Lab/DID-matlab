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

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
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
verifyEqual(testCase, efp.get('document_class.schema_version'), 'did_v2');

% the two eval'd strings became declared LISTS -- parsed, never eval'd
verifyEqual(testCase, efp.get('epoch_file_pattern.file_pattern'), ...
    {'#\.rhd\>', '#\.tsv\>'});
verifyEqual(testCase, efp.get('epoch_file_pattern.epoch_map_pattern'), ...
    {'(.*)epochprobemap.ndi'});
verifyEqual(testCase, efp.get('epoch_file_pattern.epoch_map_format'), ...
    'ndi.epoch.epochprobemap_daqsystem');

% the implementation class name became an EDGE, not a string field
verifyEqual(testCase, depValue(efp.toStruct(), 'software_id'), sw.get('base.id'));
verifyEqual(testCase, sw.get('entity.name'), 'ndi.file.navigator');
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
% #88: the software is an entity; with no version there is no version
% assertion and the local identifier is the bare class name
verifyEqual(testCase, sw.get('entity.local_identifier'), 'ndi.file.navigator');

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
verifyEqual(testCase, efp.get('epoch_file_pattern.file_pattern'), {'.*\.rhd\>'});
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
verifyEqual(testCase, efp.get('epoch_file_pattern.file_pattern'), {'.*\.rhd\>'});
end

function testFilenavigatorEmptyListTextDeclaresNoPatterns(testCase)
% cell2str returns the literal '{}' for an empty cell (cell2str.m:19). That is
% "no patterns declared", not a pattern named "{}".
out = runJ(navBody('{}', 'ndi.epoch.epochprobemap_daqsystem', '{}'));
verifyEmpty(testCase, out.quarantine);
efp = firstOfClass(out, 'epoch_file_pattern');
blk = efp.get('epoch_file_pattern');
verifyFalse(testCase, isfield(blk, 'file_pattern'));
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
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'filenavigator');
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
verifyEqual(testCase, efp.get('epoch_file_pattern.file_pattern'), {'#.rhd'});
end

function testFilenavigatorSubclassNamesItsOwnSoftware(testCase)
% newdocument writes class(obj) (navigator.m:737), so a subclass records ITSELF:
% ndi.file.navigator.epochdir, .rhd_series, ndi.setup.file.navigator.vhPrairie2p.
% Two different implementations must not collapse into one software entity.
v1 = navBody('{ ''#.tif'' }', 'ndi.epoch.epochprobemap_daqsystem', '');
v1.filenavigator.ndi_filenavigator_class = 'ndi.setup.file.navigator.vhPrairie2p';
out = runJ(v1);
sw = firstOfClass(out, 'software');
verifyEqual(testCase, sw.get('entity.name'), 'ndi.setup.file.navigator.vhPrairie2p');
% #88: V_eta writes no base.name (#73 item 54); the class is the entity's handle
verifyEqual(testCase, sw.get('entity.local_identifier'), 'ndi.setup.file.navigator.vhPrairie2p');
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
v1.base = struct('id', 'oc_2', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% EXACTLY the seven fields NDI's app template declares
% (ndi_common/database_documents/app.json on origin/main).
v1.app = struct('name', 'ndi.calc.vis.oridir', 'version', '1.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
v1.oridirtuning_calc = struct('input_parameters', struct('independent_variable', 'direction'));
% response_units EMPTY (the writers' real value): a recognised spelling such as
% 'spikes/s' is replaced by a registered unit and kept nowhere, so since
% [generic stage is lossless] (Jess Haley, 2026-10-25) such a document is
% carried whole as v1 -- and this test is about the app fold.
props = struct();
props.response_units = [];
v1.orientation_direction_tuning = struct( ...
    'properties', props, ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5));

out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    ['no software entity was minted -- the app fold read a field name that ' ...
     'universalRenames had already rewritten']);
sw = out.migrated{find(strcmp(names, 'software'), 1)};
verifyEqual(testCase, sw.get('entity.name'), 'ndi.calc.vis.oridir');
% #88: the version is a text_assertion about the software (see local_identifier)

% the dedup key the deferred second pass will merge on
verifyEqual(testCase, sw.get('entity.local_identifier'), 'ndi.calc.vis.oridir@1.2');
% the homepage rides on entity.global_identifier, scheme URL
% (#88: a plain global identifier string)
verifyEqual(testCase, cellstr(sw.get('entity.global_identifier')), {'https://github.com/VH-Lab/NDI-matlab'});

leaf = out.migrated{find(strcmp(names, 'orientation_direction_tuning_calculation'), 1)};
verifyEqual(testCase, depValue(leaf.toStruct(), 'software_id'), sw.get('base.id'));
% run-specific details go to execution_environment on the interaction, NOT onto
% the software entity (the software's identity is name+version; the os it
% happened to run on is a fact about this run).
% #88: the os and interpreter are `software` entities the calculation names
verifyEqual(testCase, entityName(out, depValue(leaf.toStruct(), 'interpreter_id')), 'MATLAB');
verifyEqual(testCase, entityName(out, depValue(leaf.toStruct(), 'operating_system_id')), 'Linux');
% "The class name stops being copied into every calculator output": no app block
% survives on the migrated document.
verifyFalse(testCase, isfield(leaf.toStruct(), 'app'));
end

function testCalculatorWithNoAppBlockFoldsWithItsMethodSoftware(testCase)
% INVERTED AGAIN 2026-10-21 (was testCalculatorWithNoAppBlockMintsNoSoftware,
% itself an inversion of the pre-#88 behaviour). The reason it passed through
% -- #88's calculation REQUIRED an operating_system_id only `app.os` can supply
% -- is gone: the edge is OPTIONAL (Jess Haley, 2026-10-21
% [calculation-os-optional]). So a calculator output with no `app` block
% folds again, with a software entity minted from the calculator's name and
% no operating system (none is invented).
v1 = struct();
v1.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'orientation_direction_tuning', 'class_version', '1.0.0'), ...
                      struct('class_name', 'tuning_fit', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', 'neuron_9');
v1.base = struct('id', 'oc_3', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% A curve, so there is a value to state: a calculator output with NO curve
% passes through for that reason alone (jCalculation: the value is required),
% which is not what this test is about.
v1.orientation_direction_tuning = struct('vector', struct('orientation_preference', 12), ...
    'tuning_curve', struct('direction', [0; 90; 180; 270], 'mean', [1; 5; 2; 4]));
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'oridirtuning_calc')), ...
    'the document folds instead of passing through');
verifyEqual(testCase, sum(strcmp(names, 'software')), 1, ...
    'one software entity, minted from the calculator''s name; no OS, no interpreter');
end


function testSoftwareIsNotDedupedInPassOne(testCase)
% Two outputs of the same calculator each mint their own software entity in
% pass 1; the dedup is a later batch pass. UPDATED for #88: the fixture states
% an operating system (a calculation requires one), so each output also mints
% an OS software entity; the assertion is about the APP software, picked by name.
a = calcBodyNamed('oc_a', 'ndi.calc.vis.oridir', '1.2');
b = calcBodyNamed('oc_b', 'ndi.calc.vis.oridir', '1.2');
a.app.os = 'Linux'; b.app.os = 'Linux';
% and a tuning curve: with none the required result value is empty and the
% calculator passes through, minting no software at all
% (testCalculatorWithNoCurvePassesThrough).
a.orientation_direction_tuning.tuning_curve = struct('direction', [0 90], 'mean', [3 4]);
b.orientation_direction_tuning.tuning_curve = struct('direction', [0 90], 'mean', [3 4]);
out = runJ({a, b});
verifyEmpty(testCase, out.quarantine);
sw = {};
for k = 1:numel(out.migrated)
    if strcmp(did2.unittest.helpers.classKey(out.migrated{k}), 'software') ...
            && strcmp(out.migrated{k}.get('entity.name'), 'ndi.calc.vis.oridir')
        sw{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(sw), 2);
verifyEqual(testCase, sw{1}.get('entity.local_identifier'), 'ndi.calc.vis.oridir@1.2');
verifyEqual(testCase, sw{2}.get('entity.local_identifier'), 'ndi.calc.vis.oridir@1.2');
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
verifyEqual(testCase, efp.get('epoch_file_pattern.file_pattern'), ...
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
v1.base = struct('id', docId, 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', appName, 'version', appVersion, 'url', '', ...
    'os', '', 'os_version', '', 'interpreter', '', 'interpreter_version', '');
v1.orientation_direction_tuning = struct('vector', struct('orientation_preference', 12));
end

function names = classNames(out)
names = cellfun(@(d) did2.unittest.helpers.classKey(d), out.migrated, ...
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

function n = entityName(out, id)
% the entity.name of the document with base.id ID ('' when none)
n = '';
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), id)
        e = out.migrated{k}.get('entity');
        if isfield(e, 'name'); n = char(e.name); end
        return;
    end
end
end

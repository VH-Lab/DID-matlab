function tests = testMigratorsJDaqConfiguration
%TESTMIGRATORSJDAQCONFIGURATION The daq CONFIGURATION fold (#59), TargetVersion 'V_eta'.
%
%   Covers the three did_v1 configuration classes that had no migrator:
%
%     daqreader          -> `software`                    (dissolves, id preserved)
%     daqmetadatareader  -> `acquisition_metadata_reader` + `software`
%     daqsystem          -> `acquisition_system` + `software`   (LIVE 2026-08-12)
%
%   The fourth member of the family, `filenavigator` -> `epoch_file_pattern`,
%   already has a migrator and its own test file
%   (testMigratorsJFileNavSoftware.m); it is not duplicated here.
%
%   TEAM-SIGN-OFF [daq configuration]: jess@walthamdatascience.com / 2026-08-08
%     (did-schema schemas/V_eta_daq_family_decisions.md:471)
%     "daqreader DISSOLVES into a `software` entity (base.id preserved);
%      daqmetadatareader -> `acquisition_metadata_reader`; daqsystem ->
%      `acquisition_system` <- entity, base.id AND base.name preserved because
%      the name is the join key; the invented `file_extension` and
%      `metadata_names` are DELETED; `reader_string` is KEPT as the de-encoded
%      daqreader_ndr.ndr_reader_string."
%
%   ---------------------------------------------------------------------
%   THE FIXTURES ARE BUILT FROM THE WRITERS, NEVER FROM A DID-SIDE SCHEMA
%   ---------------------------------------------------------------------
%   Every body below carries exactly the keys the NDI writer sets, including the
%   ones that look like noise:
%
%     +ndi/+daq/reader.m:264-267
%        ndi.document('daqreader','daqreader.ndi_daqreader_class',class(obj),
%                     'base.id',obj.id(),'base.session_id',ndi.session.empty_id())
%     +ndi/+daq/metadatareader.m:193-197
%        ndi.document('daqmetadatareader',
%           'daqmetadatareader.ndi_daqmetadatareader_class',class(obj),
%           'daqmetadatareader.tab_separated_file_parameter',obj.tab_..._parameter,
%           'base.id',obj.id(),'base.session_id',ndi.session.empty_id())
%     +ndi/+daq/system.m:485-497
%        ndi.document('daqsystem','daqsystem.ndi_daqsystem_class',class(obj),
%                     'base.id',...,'base.name',...,'base.session_id',...)
%        + set_dependency_value('filenavigator_id'/'daqreader_id')
%        + add_dependency_value_n('daqmetadatareader_id') IN A LOOP
%
%   Two of those details are load-bearing and are asserted rather than tidied
%   away:
%
%     (a) base.session_id on a reader is ndi.session.empty_id(), the sentinel
%         '0000000000000000_0000000000000000' ("applies in any session",
%         +ndi/+session/empty_id.m) -- NOT an empty string. A fixture that used
%         '' would exercise a document base.session_id's mustBeNonEmpty rejects.
%     (b) a daqsystem carries the template's BARE, EMPTY `daqmetadatareader_id`
%         entry ALONGSIDE the numbered `_1`, `_2` entries the writer appends
%         (+ndi/document.m:119-120 builds '<name>_<n+1>'), so the family reader
%         has to skip an empty bare entry and re-index from 1.
%
%   ---------------------------------------------------------------------
%   THE daqsystem GUARD IS GONE (2026-08-12) AND TWO TESTS ARE INVERTED
%   ---------------------------------------------------------------------
%   `acquisition_system` declared NO fields, so the source's one field,
%   `ndi_daqsystem_class`, had nowhere to land -- and it is not dead weight: it
%   is the object-reconstruction key, read at
%   +ndi/+database/+fun/ndi_document2ndi_object.m:38-42 via a CONSTRUCTED field
%   name (`['ndi_' obj_parent_string '_class']`) that no literal grep finds, and
%   reached from +ndi/session.m:167-169 (daqsystem_load). So the migrator passed
%   every real document through, and half these tests drove the guard.
%
%   jess@walthamdatascience.com named the home on 2026-08-12: option A, a SECOND
%   software edge, `software_id`, so the class name folds to a `software` entity
%   like the other three in this family. (Prose, not a signature line; the
%   signature for this family is in did-schema
%   schemas/V_eta_daq_family_decisions.md.)
%
%   TWO TESTS WERE INVERTED IN PLACE, NOT DELETED, because the old ones asserted
%   a DELIBERATE non-conversion and one of them said in its own comment that
%   inversion -- not patching -- was the correct treatment:
%
%     testDaqsystemPassesThroughWhileTheClassNameHasNoHome
%         -> testDaqsystemClassNameNowFoldsToASoftwareEntity
%     testDaqsystemPassthroughValidatesUnderVEta
%         -> testDaqsystemClassNameFoldValidatesUnderVEta
%
%   A residual passthrough remains, and CI showed it does NOT do what this
%   paragraph claimed. It read: "a body with NO class name AND NO edges has
%   nothing to declare, so `daqsystem` stays in `_KEEP_INFRA` and its tombstone
%   still has to validate". The tombstone does not validate that body -- it
%   REQUIRES `filenavigator_id`, `daqreader_id` and the `ndi_daqsystem_class`
%   field non-empty, which are the same three absences that route a body to the
%   passthrough in the first place. The branch is therefore a quarantine path by
%   construction, unreachable for real data (NDI writes the class name on every
%   document), and pinned as such by
%   testTheResidualPassthroughIsAQuarantinePathByConstruction.
%
%   THAT CORRECTION IS WHY THE LINE BELOW MATTERS, and it stayed true for
%   exactly one commit: nothing here had been executed when it was written, and
%   the first execution refuted a claim in this header. `daqsystem` does stay in
%   `_KEEP_INFRA` -- that half is right, and unrelated to the passthrough.
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring environment,
%   so none of these tests has been run.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJDaqConfiguration');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== harness =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runJValidated(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
end

function assumeVEtaSchemas(testCase)
%ASSUMEVETASCHEMAS Skip unless the schema cache resolves the V_eta targets.
%   installSchemaPath only checks that SOME folder of *.json exists, so a
%   V_delta-only checkout would satisfy it and then fail these tests for the
%   wrong reason.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the V_eta daq-configuration validation tests');
try
    cache = did2.schema.cache.shared();
    cache.getClass('acquisition_system');
    cache.getClass('acquisition_metadata_reader');
    cache.getClass('software');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve the V_eta daq-configuration ' ...
         'targets (' err.message ').']);
end
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
end

function doc = firstOfClass(out, className)
doc = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        doc = out.migrated{k};
        return;
    end
end
end

function v = depValue(doc, name)
%DEPVALUE Read a depends_on target tolerantly.
%   A body a migrator MINTS spells the target `value`; a body that has been
%   through did2.convert.universalRenames spells it `document_id`. A passthrough
%   assertion and a fold assertion therefore read different keys off the same
%   field name, and hard-coding either one makes half of them silently read ''.
v = '';
deps = doc.get('depends_on');
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            v = char(d.(f));
            return;
        end
    end
    return;
end
end

function tf = hasDependency(doc, name)
tf = false;
deps = doc.get('depends_on');
for k = 1:numel(deps)
    d = deps(k);
    if isfield(d, 'name') && strcmp(char(d.name), name)
        tf = true;
        return;
    end
end
end

function msg = reasonsOf(out)
if isempty(out.quarantine)
    msg = 'no quarantined documents';
    return;
end
msg = '';
for k = 1:numel(out.quarantine)
    msg = [msg sprintf('[%s] %s\n', out.quarantine(k).class_name, ...
        out.quarantine(k).reason)]; %#ok<AGROW>
end
end

% ===================== fixtures, built from the writers ====================

function id = emptySessionId()
%EMPTYSESSIONID ndi.session.empty_id(): "applies in any session".
%   +ndi/+session/empty_id.m replaces every character of a fresh unique id with
%   '0', keeping the '_'. Reader and metadata-reader documents carry THIS, not ''.
id = '0000000000000000_0000000000000000';
end

function v1 = daqreaderV1(implClass)
v1 = struct();
v1.document_class = struct('class_name', 'daqreader', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', 'reader_id_1', 'session_id', emptySessionId(), ...
    'name', '', 'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqreader = struct('ndi_daqreader_class', implClass);
end

function v1 = daqmetadatareaderV1(implClass, tsvParameter)
v1 = struct();
v1.document_class = struct('class_name', 'daqmetadatareader', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', 'mdreader_id_1', 'session_id', emptySessionId(), ...
    'name', '', 'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqmetadatareader = struct( ...
    'ndi_daqmetadatareader_class', implClass, ...
    'tab_separated_file_parameter', tsvParameter);
end

function v1 = daqsystemV1(implClass, metadataIds)
%DAQSYSTEMV1 A daqsystem exactly as +ndi/+daq/system.m:485-497 writes one.
%   METADATAIDS is a cellstr of metadata-reader ids; the BARE, EMPTY
%   `daqmetadatareader_id` entry from the template is always present beside them,
%   because add_dependency_value_n appends '_1', '_2', ... rather than filling it.
if nargin < 2
    metadataIds = {};
end
v1 = struct();
v1.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', 'system_id_1', 'session_id', 'session_id_1', ...
    'name', 'intan1', 'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqsystem = struct('ndi_daqsystem_class', implClass);

names  = {'filenavigator_id', 'daqreader_id', 'daqmetadatareader_id'};
values = {'nav_id_1',         'reader_id_1',  ''};
for k = 1:numel(metadataIds)
    names{end+1}  = sprintf('daqmetadatareader_id_%d', k); %#ok<AGROW>
    values{end+1} = metadataIds{k};                        %#ok<AGROW>
end
v1.depends_on = struct('name', names, 'id', values);
end

% ===================== daqreader -> software ===============================

function testDaqreaderDissolvesIntoSoftware(testCase)
out = runJ(daqreaderV1('ndi.daq.reader.mfdaq.intan'));
verifyEqual(testCase, classNames(out), {'software'});
sw = out.migrated{1};
verifyEqual(testCase, sw.get('software.name'), 'ndi.daq.reader.mfdaq.intan');
verifyEqual(testCase, sw.get('software.local_identifier'), ...
    'ndi.daq.reader.mfdaq.intan');
% v1's daqreader template has NO version field, so nothing may be invented here.
% verifyEmpty + verifyClass, NOT verifyEqual(...,''): verifyEqual compares SIZE
% and MATLAB has more than one empty char. jSoftware declares `version` as
% `(1,:) char`, whose size spec coerces a 0x0 '' to 1x0, so this failed with
% "Actual 1x0 / Expected 0x0" -- a fact about an argument block, not about the
% migration. jSoftware now normalises the empty; this assertion no longer
% depends on which empty it is either way.
verifyClass(testCase, sw.get('software.version'), 'char');
verifyEmpty(testCase, sw.get('software.version'));
end

function testDaqreaderPreservesItsBaseId(testCase)
% THE POINT OF THE FOLD. daqreader_id is a declared dependency on FOUR NDI
% templates (daqsystem + the three ingest classes); minting a fresh id here
% would dangle every one of them -- the 11,448-orphan failure.
out = runJ(daqreaderV1('ndi.daq.reader.mfdaq.intan'));
verifyEqual(testCase, out.migrated{1}.get('base.id'), 'reader_id_1');
end

function testDaqreaderCarriesTheEmptySessionSentinel(testCase)
% ndi.session.empty_id() is a real 33-character value, not ''. Carrying it
% verbatim is what satisfies base.session_id's mustBeNonEmpty; a migrator that
% "cleaned it up" to '' would emit a document that cannot validate.
out = runJ(daqreaderV1('ndi.daq.reader.mfdaq.intan'));
verifyEqual(testCase, out.migrated{1}.get('base.session_id'), emptySessionId());
end

function testDaqreaderWithoutAClassNamePassesThrough(testCase)
% No identity -> no entity. jSoftware returns [] for an empty name precisely so
% a caller cannot mint a nameless `software`.
v1 = daqreaderV1('');
out = runJ(v1);
verifyEqual(testCase, classNames(out), {'daqreader'});
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testDaqreaderWithAReaderStringPassesThrough(testCase)
% `software` declares name / version / local_identifier and nothing else, so a
% reader's file-type string has no home. The signed decision KEEPS
% `reader_string` (it is the de-encoded daqreader_ndr.ndr_reader_string), so a
% body carrying one is passed through rather than folded lossily.
v1 = daqreaderV1('ndi.daq.reader.mfdaq.ndr');
v1.daqreader.reader_string = 'intan';
out = runJ(v1);
verifyEqual(testCase, classNames(out), {'daqreader'});
verifyEqual(testCase, out.migrated{1}.get('daqreader.reader_string'), 'intan');
end

% ===================== daqmetadatareader -> the reader class ===============

function testMetadataReaderFoldsToTheReaderPlusSoftware(testCase)
out = runJ(daqmetadatareaderV1('ndi.daq.metadatareader', '.*\.tsv\>'));
names = classNames(out);
verifyEqual(testCase, numel(names), 2);
verifyTrue(testCase, any(strcmp(names, 'acquisition_metadata_reader')));
verifyTrue(testCase, any(strcmp(names, 'software')));

reader = firstOfClass(out, 'acquisition_metadata_reader');
verifyEqual(testCase, reader.get('base.id'), 'mdreader_id_1');
verifyEqual(testCase, ...
    reader.get('acquisition_metadata_reader.metadata_file_pattern'), '.*\.tsv\>');

sw = firstOfClass(out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi.daq.metadatareader');
verifyEqual(testCase, depValue(reader, 'software_id'), sw.get('base.id'));
end

function testMetadataReaderPreservesItsBaseId(testCase)
% acquisition_metadata_file.acquisition_metadata_reader_id is declared REQUIRED
% and is filled from the SOURCE document's daqmetadatareader_id
% (migrators_j/daqmetadatareader_epochdata_ingested.m:74,94). A minted id here
% would leave that required edge pointing at nothing.
out = runJ(daqmetadatareaderV1('ndi.daq.metadatareader', '.*\.tsv\>'));
verifyEqual(testCase, ...
    firstOfClass(out, 'acquisition_metadata_reader').get('base.id'), ...
    'mdreader_id_1');
end

function testMetadataReaderMintsNoDaqsystemEdge(testCase)
% AN INVERTED-HISTORY PIN. V_eta used to declare a REQUIRED `daqsystem_id` on
% this class -- a name no did_v1 document has -- and it was empty on 59 of 59
% documents, 100% of the class, one row of the invented-empty-edge census. It
% validated clean, because +did2/+validate/references.m:90 skips empty edges.
% NDI declares the edge the OTHER way (daqsystem -> daqmetadatareader_id) and
% the schema half removed the invented one. Nothing may put it back.
out = runJ(daqmetadatareaderV1('ndi.daq.metadatareader', '.*\.tsv\>'));
reader = firstOfClass(out, 'acquisition_metadata_reader');
verifyFalse(testCase, hasDependency(reader, 'daqsystem_id'));
end

function testMetadataReaderWithoutAClassNameOmitsTheSoftwareEdge(testCase)
% A file parameter with no implementation class is a real, convertible document.
% software_id is OMITTED rather than written empty: an empty edge is skipped by
% the reference validator, so writing one would be invisible rather than absent.
out = runJ(daqmetadatareaderV1('', '.*\.tsv\>'));
verifyEqual(testCase, classNames(out), {'acquisition_metadata_reader'});
reader = out.migrated{1};
verifyFalse(testCase, hasDependency(reader, 'software_id'));
verifyEqual(testCase, ...
    reader.get('acquisition_metadata_reader.metadata_file_pattern'), '.*\.tsv\>');
end

function testMetadataReaderWithoutAPatternOmitsTheField(testCase)
% The base ndi.daq.metadatareader defaults tab_separated_file_parameter to ''
% (+ndi/+daq/metadatareader.m:36-39 reads it back and may find nothing), so this
% is the common subclassed case, not a contrivance. A blank field is what
% did2.validate.silentLoss counts as vacuous, so it is omitted.
out = runJ(daqmetadatareaderV1('ndi.daq.metadatareader.NewStimStims', ''));
reader = firstOfClass(out, 'acquisition_metadata_reader');
blk = reader.get('acquisition_metadata_reader');
verifyFalse(testCase, isfield(blk, 'metadata_file_pattern'));
end

function testMetadataReaderWithNothingToDeclarePassesThrough(testCase)
out = runJ(daqmetadatareaderV1('', ''));
verifyEqual(testCase, classNames(out), {'daqmetadatareader'});
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

% ===================== daqsystem -> acquisition_system =====================

function testDaqsystemClassNameNowFoldsToASoftwareEntity(testCase)
% THE INVERSION, 2026-08-12. This test was
% `testDaqsystemPassesThroughWhileTheClassNameHasNoHome` and asserted the exact
% opposite: a populated ndi_daqsystem_class meant PASS THROUGH, because
% `acquisition_system` had no home for the object-reconstruction key
% (+ndi/+database/+fun/ndi_document2ndi_object.m:38-42, reached from
% +ndi/session.m:167-169).
%
% The old test's own comment demanded this treatment -- "WHEN THE TEAM NAMES A
% HOME, THIS TEST IS INVERTED, NOT PATCHED" -- so the assertion is REVERSED in
% place rather than deleted, and the history stays legible. The team named the
% home on 2026-08-12 (jess@walthamdatascience.com, option A: a second software
% edge, `software_id`).
%
% THIS IS THE SHAPE OF EVERY REAL DOCUMENT: +ndi/+daq/system.m:486 writes
% class(obj) into ndi_daqsystem_class on every daqsystem NDI creates, so this
% test -- not the empty-class-name one below -- is the corpus path.
out = runJ(daqsystemV1('ndi.daq.system.mfdaq', {'md_id_1'}));
verifyEqual(testCase, classNames(out), {'acquisition_system', 'software'});
verifyEqual(testCase, out.summary.unconverted_count, 0);

sys = firstOfClass(out, 'acquisition_system');
sw  = firstOfClass(out, 'software');

% The class name is carried as the software entity's identity, and the edge
% points at THAT document -- not at a string field, which acquisition_system
% still does not have ("fields": []).
verifyEqual(testCase, sw.get('software.name'), 'ndi.daq.system.mfdaq');
verifyEqual(testCase, sw.get('software.local_identifier'), 'ndi.daq.system.mfdaq');
verifyEqual(testCase, depValue(sys, 'software_id'), sw.get('base.id'));

% v1's daqsystem template has ONE field and it is the class name, so there is no
% version to invent. verifyEmpty + verifyClass rather than verifyEqual(...,''),
% for the reason spelled out in testDaqreaderDissolvesIntoSoftware.
verifyClass(testCase, sw.get('software.version'), 'char');
verifyEmpty(testCase, sw.get('software.version'));
end

function testDaqsystemSoftwareIdIsDistinctFromReaderId(testCase)
% THE WHOLE POINT OF THE SECOND EDGE. Both point at `software`, and they must
% name DIFFERENT documents: `software_id` is the rig's OWN implementation class,
% `reader_id` is the daqreader's preserved base.id -- a different component
% entirely. A fold that collapsed them would silently claim the rig and its
% reader are the same software.
out = runJ(daqsystemV1('ndi.daq.system.mfdaq', {}));
sys = firstOfClass(out, 'acquisition_system');
verifyEqual(testCase, depValue(sys, 'reader_id'), 'reader_id_1');
verifyNotEqual(testCase, depValue(sys, 'software_id'), 'reader_id_1');
verifyNotEqual(testCase, depValue(sys, 'software_id'), '');
end

function testDaqsystemSoftwareTakesAFreshIdNotTheSystemsOwn(testCase)
% THE DIFFERENCE FROM daqreader.m, asserted so it cannot drift. daqreader
% DISSOLVES, so its base.id MOVES to the software document or four templates'
% `daqreader_id` edges dangle. A daqsystem does NOT dissolve -- its base.id stays
% on the acquisition_system, which is also where base.name (THE JOIN KEY) lives
% -- so the software entity gets a fresh id, as in filenavigator.m and
% daqmetadatareader.m. Overwriting it here would give two documents one id.
out = runJ(daqsystemV1('ndi.daq.system.mfdaq', {}));
sys = firstOfClass(out, 'acquisition_system');
sw  = firstOfClass(out, 'software');
verifyEqual(testCase, sys.get('base.id'), 'system_id_1');
verifyNotEqual(testCase, sw.get('base.id'), 'system_id_1');
end

function testDaqsystemWithAClassNameAndNoEdgesStillConverts(testCase)
% BEFORE 2026-08-12 THIS BODY PASSED THROUGH: a class name was not
% something-to-declare (it had no home), so a daqsystem with nothing but a class
% name fell into the "nothing to declare" branch. It now carries a document on
% its own, via software_id, so the branch had to learn about implClass. The
% companion assertion -- that a body with NEITHER a class name NOR edges still
% passes through -- is testDaqsystemWithNoEdgesAtAllPassesThrough below.
v1 = daqsystemV1('ndi.daq.system.image', {});
v1.depends_on = struct('name', {}, 'id', {});
out = runJ(v1);
verifyEqual(testCase, classNames(out), {'acquisition_system', 'software'});
sys = firstOfClass(out, 'acquisition_system');
verifyNotEqual(testCase, depValue(sys, 'software_id'), '');
verifyFalse(testCase, hasDependency(sys, 'reader_id'));
end

function testDaqsystemFoldsTheThreeEdges(testCase)
% The three v1 edges, driven through a body with no ndi_daqsystem_class so that
% ONLY the edge mapping is under test. This body is no longer "the one shape the
% guard lets past" -- there is no guard -- but it is still worth keeping
% separate: it is the one shape that emits an acquisition_system with NO
% software beside it, which is what makes software_id's optionality real rather
% than theoretical.
out = runJ(daqsystemV1('', {'md_id_1', 'md_id_2'}));
verifyEqual(testCase, classNames(out), {'acquisition_system'});
sys = out.migrated{1};
verifyFalse(testCase, hasDependency(sys, 'software_id'));
verifyEqual(testCase, depValue(sys, 'reader_id'), 'reader_id_1');
verifyEqual(testCase, depValue(sys, 'epoch_file_pattern_id'), 'nav_id_1');
verifyEqual(testCase, depValue(sys, 'acquisition_metadata_reader_1'), 'md_id_1');
verifyEqual(testCase, depValue(sys, 'acquisition_metadata_reader_2'), 'md_id_2');
end

function testDaqsystemPreservesIdAndName(testCase)
% base.name is THE JOIN KEY: strcmpi'd in +ndi/+daq/system.m:229 (getprobes,
% probe -> device attribution), named in every syncrule's daqsystem1_name /
% daqsystem2_name, and queried as base.name by +ndi/session.m:148-160
% (daqsystem_load). A depends_on sweep sees none of that.
out = runJ(daqsystemV1('', {}));
sys = out.migrated{1};
verifyEqual(testCase, sys.get('base.id'), 'system_id_1');
verifyEqual(testCase, sys.get('base.name'), 'intan1');
end

function testDaqsystemSkipsTheEmptyBareFamilyEntry(testCase)
% The template ships a BARE `daqmetadatareader_id` with an empty value and the
% writer appends '_1', '_2' beside it rather than filling it
% (+ndi/document.m:119-120). Emitting an acquisition_metadata_reader_# for the
% empty bare entry would create an empty edge -- invisible to the validator,
% which skips them -- and shift the numbering of the real ones.
out = runJ(daqsystemV1('', {'md_id_1'}));
sys = out.migrated{1};
verifyEqual(testCase, depValue(sys, 'acquisition_metadata_reader_1'), 'md_id_1');
verifyFalse(testCase, hasDependency(sys, 'acquisition_metadata_reader_2'));
end

function testDaqsystemWithNoMetadataReadersEmitsNoFamily(testCase)
% A daqsystem with no metadata reader never enters the writer's loop, which is
% why NDI marks the edge "mustbenotempty": 0 and V_eta gives
% acquisition_metadata_reader_# min_count 0. The family is ABSENT, not empty.
out = runJ(daqsystemV1('', {}));
sys = out.migrated{1};
verifyFalse(testCase, hasDependency(sys, 'acquisition_metadata_reader_1'));
verifyFalse(testCase, hasDependency(sys, 'daqmetadatareader_id'));
end

function testDaqsystemOmitsAnEdgeItCannotFill(testCase)
v1 = daqsystemV1('', {});
v1.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
                       'id',   {'nav_id_1',         ''});
out = runJ(v1);
sys = out.migrated{1};
verifyEqual(testCase, depValue(sys, 'epoch_file_pattern_id'), 'nav_id_1');
verifyFalse(testCase, hasDependency(sys, 'reader_id'));
end

function testDaqsystemWithNoEdgesAtAllPassesThrough(testCase)
v1 = daqsystemV1('', {});
v1.depends_on = struct('name', {}, 'id', {});
out = runJ(v1);
verifyEqual(testCase, classNames(out), {'daqsystem'});
end

% ===================== under the real V_eta validator ======================

function testDaqreaderFoldValidatesUnderVEta(testCase)
assumeVEtaSchemas(testCase);
out = runJValidated(daqreaderV1('ndi.daq.reader.mfdaq.intan'));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
verifyEqual(testCase, classNames(out), {'software'});
end

function testMetadataReaderFoldValidatesUnderVEta(testCase)
assumeVEtaSchemas(testCase);
out = runJValidated(daqmetadatareaderV1('ndi.daq.metadatareader', '.*\.tsv\>'));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
verifyEqual(testCase, numel(out.migrated), 2);
end

function testDaqsystemFoldValidatesUnderVEta(testCase)
assumeVEtaSchemas(testCase);
out = runJValidated(daqsystemV1('', {'md_id_1', 'md_id_2'}));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
verifyEqual(testCase, classNames(out), {'acquisition_system'});
end

function testDaqsystemClassNameFoldValidatesUnderVEta(testCase)
% THE CORPUS PATH UNDER THE REAL VALIDATOR, and it is the assertion that would
% have caught a REQUIRED `software_id`. #37 RequiredDependencies is ARMED by
% default (+did2/+schema/cache.m:967-968), so had the new edge been declared
% required, every daqsystem whose class name is absent would quarantine here.
% It is declared OPTIONAL, and this test plus testDaqsystemFoldsTheThreeEdges
% (which emits NO software at all) cover both sides of that choice.
%
% This test was `testDaqsystemPassthroughValidatesUnderVEta` and asserted that
% the same body survived validation AS A daqsystem. The passthrough it protected
% is gone; what it was really guarding -- that this body reaches the validator
% cleanly -- is kept, now against the folded shape.
assumeVEtaSchemas(testCase);
out = runJValidated(daqsystemV1('ndi.daq.system.mfdaq', {'md_id_1'}));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
verifyEqual(testCase, classNames(out), {'acquisition_system', 'software'});
end

function testTheResidualPassthroughIsAQuarantinePathByConstruction(testCase)
% INVERTED 2026-08-12, ON ITS FIRST EXECUTION. It was
% `testDaqsystemTombstoneStillExistsForTheEmptyBody` and asserted
% quarantine_count 0 with the body surviving as `daqsystem`. CI says 1 and
% nothing survives, and CI is right -- the assertion was written from intent
% while the schema says the opposite.
%
% THE CONTRADICTION, and it is exact. `migrators_j/daqsystem.m:251` takes the
% residual passthrough only when implClass AND navId AND readerId AND mdIds are
% ALL empty. The `daqsystem` tombstone requires three of those same things:
%
%     filenavigator_id       mustBeNonEmpty TRUE
%     daqreader_id           mustBeNonEmpty TRUE
%     ndi_daqsystem_class    mustBeNonEmpty TRUE   (a field)
%
% So THE ONLY BODY THAT REACHES THE PASSTHROUGH IS THE ONE THE TOMBSTONE CANNOT
% VALIDATE. With #37 RequiredDependencies and #38 NonVacuousFields both ARMED,
% that is a quarantine, not a rescue. The migrator's comment at :253 -- "the
% source at least still carries its base identity" -- describes a preservation
% that does not happen, and is corrected there.
%
% WHY THIS IS NOT A REGRESSION TO FIX BY RELAXING THE SCHEMA. Those three
% constraints are the tombstone restated from the NDI writer, which sets
% `ndi_daqsystem_class` on every document it creates and gives every real rig a
% filenavigator and a daqreader. An all-empty `daqsystem` is not a document NDI
% can produce; it is a hollow one, and #38 exists to catch exactly that. Loosening
% the tombstone to admit it would trade a real guard for an unreachable case.
%
% WHAT IS LEFT OPEN, and it belongs to the team rather than to this test: the
% residual branch is now DEAD FOR REAL DATA and a TRAP if it ever fires. Either
% it should go, or it should refuse loudly instead of emitting a body that
% quarantines downstream. This test pins the behaviour as it is so the choice is
% made deliberately and not discovered in a corpus run.
assumeVEtaSchemas(testCase);
v1 = daqsystemV1('', {});
v1.depends_on = struct('name', {}, 'id', {});
out = runJValidated(v1);
verifyEqual(testCase, out.summary.quarantine_count, 1, ...
    ['an all-empty daqsystem is a HOLLOW document: the tombstone requires ' ...
     'two edges and a field it does not have. Quarantine is #37/#38 working, ' ...
     'not a defect -- see this test''s header before changing either side.']);
verifyEmpty(testCase, classNames(out), ...
    'nothing survives, so the passthrough preserves nothing');
end

function testTheFoldsLeaveNoEmptyRequiredEdgeAndNoFragment(testCase)
% quarantine_count alone proves nothing here: every edge this family emits is
% OPTIONAL, and +did2/+validate/references.m:90 skips empty edges, so a hollow
% document would pass validation silently. These are the instruments that see it.
assumeVEtaSchemas(testCase);
out = runJValidated(daqmetadatareaderV1('ndi.daq.metadatareader', '.*\.tsv\>'));
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
verifyEqual(testCase, out.silent_loss.vacuous_field_count, 0);
verifyEqual(testCase, out.summary.fragment_count, 0);

out = runJValidated(daqsystemV1('', {'md_id_1'}));
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
verifyEqual(testCase, out.silent_loss.vacuous_field_count, 0);
verifyEqual(testCase, out.summary.fragment_count, 0);

% AND THE CORPUS SHAPE, added 2026-08-12 with the second software edge. This is
% the check condition 1 of the signed decision asks for by name
% (V_eta_daq_family_decisions.md:273 -- "check those edge names BY NAME in the
% silentLoss output rather than trusting quarantine=0"): every edge on
% acquisition_system is OPTIONAL and +did2/+validate/references.m:90 SKIPS empty
% edges, so quarantine_count alone cannot see a `software_id` that was declared
% and left blank.
out = runJValidated(daqsystemV1('ndi.daq.system.mfdaq', {'md_id_1'}));
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
verifyEqual(testCase, out.silent_loss.vacuous_field_count, 0);
verifyEqual(testCase, out.summary.fragment_count, 0);
end

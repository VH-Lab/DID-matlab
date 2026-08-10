function tests = testMigratorsJDaqConfiguration
%TESTMIGRATORSJDAQCONFIGURATION The daq CONFIGURATION fold (#59), TargetVersion 'V_eta'.
%
%   Covers the three did_v1 configuration classes that had no migrator:
%
%     daqreader          -> `software`                    (dissolves, id preserved)
%     daqmetadatareader  -> `acquisition_metadata_reader` + `software`
%     daqsystem          -> `acquisition_system`          (GUARDED -- see below)
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
%   HALF THE daqsystem TESTS DRIVE A GUARD, NOT A FOLD -- DELIBERATELY
%   ---------------------------------------------------------------------
%   `acquisition_system` declares NO fields, so the source's one field,
%   `ndi_daqsystem_class`, has nowhere to land -- and it is not dead weight: it
%   is the object-reconstruction key, read at
%   +ndi/+database/+fun/ndi_document2ndi_object.m:38-42 via a CONSTRUCTED field
%   name (`['ndi_' obj_parent_string '_class']`) that no literal grep finds, and
%   reached from +ndi/session.m:167-169 (daqsystem_load). Naming a second
%   software edge on `acquisition_system` is a team decision, so until it is
%   taken the migrator passes every real document through. Both branches are
%   tested: a test that drove only the fold would assert behaviour the corpus
%   never reaches, and a test that drove only the guard would not notice the
%   fold rotting.
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

function testDaqsystemPassesThroughWhileTheClassNameHasNoHome(testCase)
% THE LIVE BEHAVIOUR ON EVERY REAL DOCUMENT. +ndi/+daq/system.m:486 sets
% ndi_daqsystem_class on every daqsystem it writes, and `acquisition_system`
% declares no fields, so the fold would drop the object-reconstruction key
% (+ndi/+database/+fun/ndi_document2ndi_object.m:38-42, reached from
% +ndi/session.m:167-169). Passing through loses nothing and is visible in
% `unconverted_by_class`.
%
% WHEN THE TEAM NAMES A HOME, THIS TEST IS INVERTED, NOT PATCHED: it asserts a
% deliberate non-conversion, so "updating" it to expect a fold would erase the
% only record that the guard was intentional.
out = runJ(daqsystemV1('ndi.daq.system.mfdaq', {'md_id_1'}));
verifyEqual(testCase, classNames(out), {'daqsystem'});
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testDaqsystemFoldsTheThreeEdges(testCase)
% The fold itself, driven through a body with no ndi_daqsystem_class -- the one
% shape the guard lets past today.
out = runJ(daqsystemV1('', {'md_id_1', 'md_id_2'}));
verifyEqual(testCase, classNames(out), {'acquisition_system'});
sys = out.migrated{1};
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

function testDaqsystemPassthroughValidatesUnderVEta(testCase)
% The passthrough is only SAFE because `daqsystem` is still in the built set
% (build_v_eta.py `_KEEP_INFRA`, NOT `_DELETE_PHASE8`) and its depends_on was
% repaired in the schema half. Deleting a source tombstone ahead of its migrator
% is what put 2,484 corpus-B documents in quarantine once; this test is what
% would say so.
assumeVEtaSchemas(testCase);
out = runJValidated(daqsystemV1('ndi.daq.system.mfdaq', {'md_id_1'}));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
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
end

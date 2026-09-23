function tests = testMigratorsJIngested
%TESTMIGRATORSJINGESTED The daq ingested-payload family (#66), TargetVersion 'V_eta'.
%
%   Covers the three did_v1 ingestion classes and the mfdaq subtype that folds
%   into one of them:
%
%     daqmetadatareader_epochdata_ingested -> acquisition_metadata_file
%     daqreader_epochdata_ingested         -> + N relative_reference (source kept)
%     daqreader_image_epochdata_ingested   -> + N relative_reference (source kept)
%     daqreader_mfdaq_epochdata_ingested   -> de-encode, then the same lift
%
%   ---------------------------------------------------------------------
%   WHAT THE FIXTURES ARE BUILT FROM, AND WHY IT MATTERS
%   ---------------------------------------------------------------------
%   EVERY fixture below is built from the NDI WRITER on `origin/main`, never from
%   a DID-side schema and never from the template alone. The template says only
%   `epochtable: { epochclock: "", t0_t1: "" }`; the writer says what is inside:
%
%     +ndi/+daq/+reader/mfdaq.m:775-781  and  +ndi/+daq/+reader/image.m:182-189
%        ec_{i} = ec{i}.ndi_clocktype2char();          % CELL of char
%        ...epochtable.epochclock = ec_;
%        ...epochtable.t0_t1 = ndi.fun.doc.t0_t1cell2array(obj.t0_t1(epochfiles));
%     +ndi/+fun/+doc/t0_t1cell2array.m
%        t0t1_out = zeros(2,numel(t0t1_in));           % 2-by-Nclocks MATRIX
%     +ndi/+daq/metadatareader.m:134-144
%        epochid_struct.epochid = epoch_id;
%        d = d.set_dependency_value('daqmetadatareader_id', obj.id());
%        d = d.add_file('data.bin',[metadatafile '.nbf.tgz']);
%
%   Building a fixture from an ASSUMED shape is what produced the ~2,078
%   distance_metadata quarantines: the migrator's unit test passed against a
%   shape no real document has, so the migrator never worked on real data.
%
%   ---------------------------------------------------------------------
%   THE GUARD IS THE SUBJECT OF HALF THESE TESTS, NOT AN EDGE CASE
%   ---------------------------------------------------------------------
%   All three targets need an `epoch` DOCUMENT to point at, and no migrator mints
%   one yet (#60's migrator half). So on every real did_v1 document today these
%   migrators pass their input through, and the fold is exercised here by adding
%   the `epoch_id` edge the epoch pass will add. Both branches are tested,
%   deliberately: a test that only drove the fold would be asserting behaviour
%   the corpus never reaches, and a test that only drove the guard would not
%   notice the fold rotting.
%
%   UNVERIFIED: there is no MATLAB in the authoring environment, so none of these
%   tests has been executed. They are written from the code as it stands and from
%   the writer evidence quoted above.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJIngested');

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

function v = depVal(doc, name)
%DEPVAL Read a depends_on target tolerantly.
%   A body a migrator MINTS spells the target `value`; a body that has been
%   through did2.convert.universalRenames spells it `document_id`. A passthrough
%   test and a fold test therefore read different keys off the same field name,
%   and hard-coding either one makes half the assertions silently read ''.
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

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
end

function docs = docsOfClass(out, className)
docs = {};
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        docs{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
end

function assumeVEtaSchemas(testCase)
%ASSUMEVETASCHEMAS Skip unless the schema cache can resolve the V_eta classes.
%   installSchemaPath only checks that SOME folder of *.json exists, so a
%   V_delta-only checkout would satisfy it and then fail these tests for the
%   wrong reason. Probing the two classes the folds actually emit turns that into
%   an honest skip.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the V_eta validation tests');
try
    cache = did2.schema.cache.shared();
    cache.getClass('acquisition_metadata_file');
    cache.getClass('relative_reference');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve the V_eta ingested-payload ' ...
         'targets (' err.message ').']);
end
end

function names = fieldNamesOf(cache, className)
%FIELDNAMESOF Top-level field names declared anywhere in CLASSNAME's chain.
%   Reads the cache rather than a json path, so it follows superclasses and
%   cannot go stale against a moved file.
tagged = cache.fieldsFor(className);
names = {};
for k = 1:numel(tagged)
    fd = tagged(k).fieldDef;
    if isstruct(fd) && isfield(fd, 'name')
        names{end+1} = char(fd.name); %#ok<AGROW>
    end
end
end

function fd = namedField(cache, className, fieldName)
%NAMEDFIELD The declaration of one top-level field, or [] if absent.
fd = [];
tagged = cache.fieldsFor(className);
for k = 1:numel(tagged)
    d = tagged(k).fieldDef;
    if isstruct(d) && isfield(d, 'name') && strcmp(char(d.name), fieldName)
        fd = d;
        return;
    end
end
end

function names = subFieldNames(fieldDef)
%SUBFIELDNAMES Names nested one level inside a `structure` field declaration.
%   The json decoder gives `fields` as a struct array when every entry has the
%   same keys and a CELL array when they differ, and the axis entry mixes
%   shapes (ontology_term, boolean, structure), so both are handled. Returning
%   {} for a field with no nested declarations is correct, not an error.
names = {};
if ~isstruct(fieldDef) || ~isfield(fieldDef, 'fields')
    return;
end
sub = fieldDef.fields;
if iscell(sub)
    for k = 1:numel(sub)
        if isstruct(sub{k}) && isfield(sub{k}, 'name')
            names{end+1} = char(sub{k}.name); %#ok<AGROW>
        end
    end
elseif isstruct(sub)
    for k = 1:numel(sub)
        if isfield(sub(k), 'name')
            names{end+1} = char(sub(k).name); %#ok<AGROW>
        end
    end
end
end

% ===================== fixtures, built from the writer ======================

function v1 = metadataIngestedV1()
%METADATAINGESTEDV1 A daqmetadatareader_epochdata_ingested exactly as
%   +ndi/+daq/metadatareader.m:126-147 writes one: the epochid STRING block, the
%   daqmetadatareader_id edge, one file, and NO fields (the template's own
%   property block is `{}`).
v1 = struct();
v1.document_class = struct('class_name', 'daqmetadatareader_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'daqmetadatareader_id'}, 'value', {'mdr_1'});
v1.base = struct('id', 'amf_1', 'session_id', 'sess_09', ...
    'name', 'ingested_metadata', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00001');
v1.daqmetadatareader_epochdata_ingested = struct();
v1.files = struct('file_list', {{'data.bin'}});
end

function v1 = readerIngestedV1(epochclock, t0t1)
%READERINGESTEDV1 A daqreader_epochdata_ingested with the writer's epochtable.
%   EPOCHCLOCK is a cell of clock names; T0T1 is the 2-by-Nclocks matrix
%   t0_t1cell2array produces (or, for the round-trip degeneracy reader.m:93
%   documents, a bare 2-vector).
v1 = struct();
v1.document_class = struct('class_name', 'daqreader_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'daqreader_id'}, 'value', {'dr_1'});
v1.base = struct('id', 'ing_1', 'session_id', 'sess_09', ...
    'name', 'ingested', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00001');
v1.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {epochclock}, 't0_t1', t0t1));
% The recording archives mfdaq.m:829,916,955 attaches under runtime-computed
% names. The template declares NO files (#64, the undeclared-file gap), which is
% precisely why these bytes must survive the migration untouched.
v1.files = struct('file_list', {{'channel_list.bin', 'ai_group1_seg.nbf_1'}});
end

function v1 = imageIngestedV1()
%IMAGEINGESTEDV1 A daqreader_image_epochdata_ingested as
%   +ndi/+daq/+reader/image.m:164-232 writes one -- header + the INHERITED
%   daqreader_epochdata_ingested.epochtable + epochid + frames.bin, and exactly
%   ONE dependency, daqreader_id.
v1 = struct();
v1.document_class = struct('class_name', 'daqreader_image_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'daqreader_epochdata_ingested', 'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'daqreader_id'}, 'value', {'dr_img'});
v1.base = struct('id', 'img_1', 'session_id', 'sess_09', ...
    'name', 'ingested_frames', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00007');
v1.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 12.5]));
v1.daqreader_image_epochdata_ingested = struct( ...
    'dimension_order', 'YXCZT', ...
    'dimension_size', [64 64 1 1 3], ...
    'data_type', 'uint16', ...
    'num_frames', 3, ...
    'frametimes', [0 0.5 1.0], ...
    'clocktype', 'dev_local_time', ...
    'metadata', struct('israster', false, 'frame_period', NaN, ...
        'line_period', NaN, 'dwell_time', NaN, 'lines_per_frame', NaN, ...
        'pixels_per_line', NaN, 'bidirectional', false));
v1.files = struct('file_list', {{'frames.bin'}});
end

function v1 = withEpochEdge(v1, epochDocId)
%WITHEPOCHEDGE Add the `epoch_id` edge #60's epoch pass will add.
%   NO did_v1 DOCUMENT CARRIES THIS. It is added here, in the tests only, to
%   drive the fold branch; see jEpochDocId's header for the two commands showing
%   why it is absent today.
v1.depends_on(end+1) = struct('name', 'epoch_id', 'value', epochDocId);
end

% ===================== daqmetadatareader_epochdata_ingested ================

function testMetadataIngestedPassesThroughWithoutAnEpochDocument(testCase)
% PASS ONE, IN ISOLATION. This is the migrator's own behaviour with no epoch
% document in reach: 2,659 documents (B 1,242 / Dab 1,242 / Soph 175) pass
% through intact rather than becoming carriers with an empty required edge.
%
% WHAT CHANGED 2026-08-11, so this comment is not read as the pipeline's whole
% story: `did2.convert.epochMint` now ARMS the fold in the batch pass, after it
% has minted the epochs. It stamps the `epoch_id` edge onto exactly these
% passed-through bodies and re-runs this migrator, which is the handoff
% jEpochDocId's header describes. So a full pipeline run folds what pass 1
% leaves alone -- and this assertion stays exactly as it is, because pass 1
% must keep refusing on its own. See testEpochMint's ingested-metadata section
% for the batch half.
out = runJ(metadataIngestedV1());
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), ...
    'daqmetadatareader_epochdata_ingested');
% the epoch identity survives as the STRING, because that is all there is
verifyEqual(testCase, doc.get('epochid.epochid'), 't00001');
verifyEqual(testCase, depVal(doc, 'daqmetadatareader_id'), 'mdr_1');
% the bytes survive
verifyEqual(testCase, doc.get('files.file_list'), {'data.bin'});
% and it is REPORTED as a passthrough rather than counted as a success
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testMetadataIngestedFoldsWhenTheEpochEdgeIsPresent(testCase)
out = runJ(withEpochEdge(metadataIngestedV1(), 'epoch_doc_1'));
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), ...
    'acquisition_metadata_file');
verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_eta');
% base.id PRESERVED (T10)
verifyEqual(testCase, doc.get('base.id'), 'amf_1');
verifyEqual(testCase, doc.get('base.session_id'), 'sess_09');
% BOTH required edges populated -- the whole point of the guard
verifyEqual(testCase, depVal(doc, 'acquisition_metadata_reader_id'), 'mdr_1');
verifyEqual(testCase, depVal(doc, 'epoch_id'), 'epoch_doc_1');
% the bytes, which are the entire content of the class
verifyEqual(testCase, doc.get('files.file_list'), {'data.bin'});
% the class declares no fields but is CONCRETE, so the empty block must exist
verifyTrue(testCase, isfield(doc.toStruct(), 'acquisition_metadata_file'));
end

function testMetadataFoldDropsTheEpochidBlockForTheEdge(testCase)
% acquisition_metadata_file does NOT inherit `epochid`, so carrying the block
% over would trip did2:validation:undeclaredBlock. The epoch attribution is not
% lost -- it moves from the string to the edge, which is the whole reason the
% fold is gated on the edge existing.
out = runJ(withEpochEdge(metadataIngestedV1(), 'epoch_doc_1'));
s = out.migrated{1}.toStruct();
verifyFalse(testCase, isfield(s, 'epochid'));
verifyEqual(testCase, depVal(out.migrated{1}, 'epoch_id'), 'epoch_doc_1');
end

function testMetadataIngestedWithNoReaderEdgePassesThrough(testCase)
v1 = withEpochEdge(metadataIngestedV1(), 'epoch_doc_1');
v1.depends_on(1).value = '';          % daqmetadatareader_id emptied
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'daqmetadatareader_epochdata_ingested');
end

function testMetadataIngestedWithNoBytesPassesThrough(testCase)
% `data.bin` is REQUIRED on both the NDI schema document and the V_eta class,
% and unlike depends_on NOTHING skips an empty `file` -- so a byte-less carrier
% would be a hollow document with no excuse.
v1 = withEpochEdge(metadataIngestedV1(), 'epoch_doc_1');
v1.files = struct('file_list', {{}});
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'daqmetadatareader_epochdata_ingested');
end

function testMetadataIngestedReadsTheFileSpellingNDIAlsoUses(testCase)
% did2.validate.fileList accepts `files.file_list` and `file.file_list`; the
% migrator's guard has to agree with the auditor or a real document could be
% passed through for a reason the audit does not report.
v1 = withEpochEdge(metadataIngestedV1(), 'epoch_doc_1');
v1 = rmfield(v1, 'files');
v1.file = struct('file_list', {{'data.bin'}});
out = runJ(v1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'acquisition_metadata_file');
verifyEqual(testCase, out.migrated{1}.get('files.file_list'), {'data.bin'});
end

% ===================== daqreader_epochdata_ingested ========================

function testReaderIngestedPassesThroughWithoutAnEpochDocument(testCase)
out = runJ(readerIngestedV1({'dev_local_time'}, [0; 10]));
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), ...
    'daqreader_epochdata_ingested');
verifyEqual(testCase, out.summary.unconverted_count, 1);
% the recording archives are untouched -- for an ingested session they are the
% only copy, which is why the source is never retired here
verifyEqual(testCase, numel(doc.get('files.file_list')), 2);
end

function testReaderIngestedLiftsOneClockToARelativeReference(testCase)
out = runJ(withEpochEdge(readerIngestedV1({'dev_local_time'}, [0; 10]), 'epoch_doc_1'));
verifyEqual(testCase, numel(out.migrated), 2);
verifyTrue(testCase, any(strcmp(classNames(out), 'daqreader_epochdata_ingested')));

refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1);
ref = refs{1};
verifyEqual(testCase, depVal(ref, 'relative_to'), 'epoch_doc_1');
% INVERTED for #65 increment 2. THREE things this block used to assert are now
% wrong, and two of them were wrong before the change as well:
%   * `value.clock` was read as a bare CHAR while the schema has typed it
%     `ontology_term` since increment 1 -- the assertion agreed with the
%     migrator and with nothing else. It is now {node, name}, node STAGED EMPTY
%     (no NDIC authority is in any repo in scope).
%   * `value.end` no longer exists (CHANGE 1): the extent is `value.duration`,
%     t1 - t0, so an approximate anchor and an exact span stop contaminating
%     each other. 0..10 becomes start 0 + duration 10.
%   * `time_reference.is_approximate` is DEPRECATED (CHANGE 2) and this emitter
%     no longer writes it at all.
verifyEqual(testCase, ref.get('relative_reference.value.clock.name'), 'dev_local_time');
verifyEqual(testCase, ref.get('relative_reference.value.start.seconds'), 0);
val = ref.get('relative_reference.value');
verifyFalse(testCase, isfield(val, 'end'));
verifyEqual(testCase, val.duration.seconds, 10);
verifyEqual(testCase, val.duration.source_unit, 's');
% dev_local_time is the precise tier (within 0.1 ms). It states NO tolerance, so
% no clock_tolerance is written -- absence, not a fabricated zero.
tr = ref.get('time_reference');
verifyFalse(testCase, isfield(tr, 'clock_tolerance'));
verifyEqual(testCase, ref.get('base.session_id'), 'sess_09');
end

function testReaderIngestedSourceSurvivesTheLift(testCase)
% ADDITIVE, NOT A RETIREMENT. The class's other half -- the attached recording
% archives -- has no target until #30, so retiring the document would drop the
% only copy of an ingested session's data.
out = runJ(withEpochEdge(readerIngestedV1({'dev_local_time'}, [0; 10]), 'epoch_doc_1'));
src = docsOfClass(out, 'daqreader_epochdata_ingested');
verifyEqual(testCase, numel(src), 1);
verifyEqual(testCase, src{1}.get('base.id'), 'ing_1');
verifyEqual(testCase, src{1}.get('epochid.epochid'), 't00001');
verifyEqual(testCase, numel(src{1}.get('files.file_list')), 2);
end

function testReaderIngestedLiftsEveryClockInTheCellArray(testCase)
% epochclock is a CELL ARRAY -- one (clock, interval) pair per entry, several per
% epoch (+ndi/+daq/reader.m:83-90 loops over it). A single `clock` field would be
% lossy in exactly the way a flattened polynomial would have been. t0_t1's column
% k belongs to epochclock{k} (t0_t1cell2array), so the PAIRING is asserted here,
% not just the count.
t0t1 = [0 100; 10 110];      % column 1 = [0 10], column 2 = [100 110]
out = runJ(withEpochEdge( ...
    readerIngestedV1({'dev_local_time', 'exp_global_time'}, t0t1), 'epoch_doc_1'));
verifyEqual(testCase, numel(out.migrated), 3);

refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 2);
byClock = containers.Map();
for k = 1:numel(refs)
    v = refs{k}.get('relative_reference.value');
    % INVERTED for #65 increment 2: the clock is an ontology_term cell, and the
    % pair is (anchor, EXTENT) rather than (start, end). The pairing this test
    % exists to protect -- t0_t1's column k belongs to epochclock{k} -- is
    % unchanged and is still what a wrong answer here would reveal.
    byClock(v.clock.name) = [v.start.seconds, v.duration.seconds];
end
verifyEqual(testCase, byClock('dev_local_time'), [0 10]);
verifyEqual(testCase, byClock('exp_global_time'), [100 10]);
end

function testReaderIngestedAcceptsTheDegenerateVectorT0T1(testCase)
% NDI's own reader defends against this shape (reader.m:93, "this fixes a
% to-json, from-json, to-json conversion problem"): with one clock the 2x1
% column comes back as a bare 2-element vector.
out = runJ(withEpochEdge(readerIngestedV1({'dev_local_time'}, [0 10]), 'epoch_doc_1'));
refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1);
val = refs{1}.get('relative_reference.value');
verifyEqual(testCase, val.start.seconds, 0);
% INVERTED for #65 increment 2: the extent is `duration` (t1 - t0), not `end`.
verifyEqual(testCase, val.duration.seconds, 10);
end

function testNoTimeClockEmitsNoReference(testCase)
% NO TIMES => NO REFERENCE. `no_time` is reachable, not theoretical:
% +ndi/+daq/+reader/image.m:204-207 falls back to it for a clockless epoch and
% migrators_i/image_stack.m:182 does the same.
out = runJ(withEpochEdge(readerIngestedV1({'no_time'}, [0; 0]), 'epoch_doc_1'));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEmpty(testCase, docsOfClass(out, 'relative_reference'));
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testNaNIntervalEmitsNoReference(testCase)
% Also reachable: the abstract ndi.daq.reader.mfdaq/t0_t1 docstring says "The
% abstract class always returns {[NaN NaN]}". A NaN reference is a hollow
% document -- the exact thing silentLoss and isFragment exist to catch.
out = runJ(withEpochEdge( ...
    readerIngestedV1({'dev_local_time'}, [NaN; NaN]), 'epoch_doc_1'));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEmpty(testCase, docsOfClass(out, 'relative_reference'));
end

function testMixedClocksDropOnlyTheUninterpretableOne(testCase)
% A per-entry guard, not a per-document one: one usable clock beside `no_time`
% must still produce its reference.
t0t1 = [0 0; 10 0];
out = runJ(withEpochEdge( ...
    readerIngestedV1({'dev_local_time', 'no_time'}, t0t1), 'epoch_doc_1'));
refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1);
verifyEqual(testCase, refs{1}.get('relative_reference.value.clock.name'), 'dev_local_time');
end

function testApproxClockDeEncodesToAClockToleranceNotABoolean(testCase)
% INVERTED for #65 increment 2, and the inversion is the whole point of CHANGE 4.
% This test used to assert that `approx_utc` set two BOOLEANS. That was the error
% the team caught: the prefix hides a NUMBER in a docstring
% (+ndi/+time/clocktype.m:21 "within 5 seconds"), and a boolean has no magnitude,
% so the five seconds were being thrown away. It de-encodes to DATA instead --
% the bare clock plus an explicit tolerance on the ROOT -- and the four-term
% vocabulary has no `approx_utc` member for the clock term to have carried.
out = runJ(withEpochEdge(readerIngestedV1({'approx_utc'}, [0; 10]), 'epoch_doc_1'));
refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1);
verifyEqual(testCase, refs{1}.get('relative_reference.value.clock.name'), 'utc');
verifyEqual(testCase, refs{1}.get('time_reference.clock_tolerance.seconds'), 5);
% and the magnitude did NOT collapse back into a flag on either value cell
val = refs{1}.get('relative_reference.value');
verifyFalse(testCase, isfield(val, 'approximate'));
verifyFalse(testCase, logical(val.start.approximate));
end

function testReferenceOmitsRelationWhenItHasAMetric(testCase)
% `relation` is the qualitative Allen relation used when there is NO metric
% offset. Emitting both would assert the same fact twice, in two vocabularies.
out = runJ(withEpochEdge(readerIngestedV1({'dev_local_time'}, [0; 10]), 'epoch_doc_1'));
refs = docsOfClass(out, 'relative_reference');
val = refs{1}.get('relative_reference.value');
verifyFalse(testCase, isfield(val, 'relation'));
end

% ===================== daqreader_mfdaq_epochdata_ingested ==================

function testMfdaqIngestedStillReturnsAStructWhileGuarded(testCase)
% The migrator function is called DIRECTLY by an existing test in
% testMigratorsJ.m, which reads out.document_class.class_name off a struct. The
% delegation must not change that on the guarded path.
body = mfdaqIngestedV1();
out = did2.convert.migrators_j.daqreader_mfdaq_epochdata_ingested(body);
verifyTrue(testCase, isstruct(out));
verifyTrue(testCase, isscalar(out));
verifyEqual(testCase, out.document_class.class_name, 'daqreader_epochdata_ingested');
verifyEqual(testCase, out.daqreader_epochdata_ingested.parameters.sample_analog_segment, ...
    1000000);
verifyEqual(testCase, out.epochid.epochid, 't00001');
end

function testMfdaqIngestedDelegatesTheEpochLift(testCase)
% Without the delegation the mfdaq documents -- the ONLY ones carrying the real
% .nbf.tgz recording archives -- would be the one member of the family whose
% epochtable never became references, because v1_to_v2 looks the concrete
% migrator up once, on the class the document ARRIVED with.
out = runJ(withEpochEdge(mfdaqIngestedV1(), 'epoch_doc_1'));
verifyEqual(testCase, numel(out.migrated), 2);
verifyTrue(testCase, any(strcmp(classNames(out), 'daqreader_epochdata_ingested')));
refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1);
verifyEqual(testCase, refs{1}.get('relative_reference.value.clock.name'), 'dev_local_time');
% the de-encode still happened
src = docsOfClass(out, 'daqreader_epochdata_ingested');
verifyEqual(testCase, ...
    src{1}.get('daqreader_epochdata_ingested.parameters.sample_analog_segment'), ...
    1000000);
end

function v1 = mfdaqIngestedV1()
v1 = struct();
v1.document_class = struct('class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'daqreader_epochdata_ingested', 'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'daqreader_id'}, 'value', {'dr_1'});
v1.base = struct('id', 'mfdaq_1', 'session_id', 'sess_09', ...
    'name', 'ingested', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00001');
v1.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 10]));
v1.daqreader_mfdaq_epochdata_ingested = struct('parameters', ...
    struct('sample_analog_segment', 1000000, 'sample_digital_segment', 1000000));
end

% ===================== daqreader_image_epochdata_ingested ==================

function testImageIngestedPassesThroughWithoutAnEpochDocument(testCase)
out = runJ(imageIngestedV1());
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), ...
    'daqreader_image_epochdata_ingested');
verifyEqual(testCase, doc.get('daqreader_image_epochdata_ingested.num_frames'), 3);
verifyEqual(testCase, doc.get('files.file_list'), {'frames.bin'});
end

function testImageIngestedLiftsTheInheritedEpochTable(testCase)
% The clock extents live on the INHERITED daqreader_epochdata_ingested block,
% which the writer builds and passes as a separate property block
% (+ndi/+daq/+reader/image.m:187-188, 216-219) -- not on the image header.
out = runJ(withEpochEdge(imageIngestedV1(), 'epoch_doc_7'));
verifyEqual(testCase, numel(out.migrated), 2);
refs = docsOfClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1);
verifyEqual(testCase, depVal(refs{1}, 'relative_to'), 'epoch_doc_7');
% INVERTED for #65 increment 2: `value.end` is gone, the extent is
% `value.duration` = t1 - t0. The fixture's epoch runs 0 .. 12.5 s, so the span
% is the same number here -- which is exactly why the assertion has to name the
% new field rather than the old value.
verifyEqual(testCase, refs{1}.get('relative_reference.value.duration.seconds'), 12.5);
end

function testImageIngestedEmitsNoSubjectlessObservation(testCase)
% THE GUARD THAT IS THE POINT OF THIS CLASS. The writer sets exactly one
% dependency, daqreader_id (+ndi/+daq/+reader/image.m:220) -- no subject_id, no
% element_id, and there is no other construction site. image_observation
% requires subject_id (inherited from subject_statement), and an empty required
% edge validates clean because +did2/+validate/references.m:90 skips it. That is
% the image_stack husk, 4,563 JH documents, guarded three days ago at 5e53f79;
% this asserts the same shape is not rebuilt one class over.
out = runJ(withEpochEdge(imageIngestedV1(), 'epoch_doc_7'));
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'image_observation')));
verifyFalse(testCase, any(strcmp(names, 'sampled_body')));
end

function testImageIngestedKeepsTheMetadataThatHasNoHome(testCase)
% The 7-field acquisition-metadata struct (+ndi/+daq/+reader/image.m:373-380,
% `emptymetadata`) is declared by the V_eta source tombstone and by NEITHER
% image_observation NOR sampled_body. Retiring the source would drop it
% silently; the passthrough keeps it losslessly.
out = runJ(withEpochEdge(imageIngestedV1(), 'epoch_doc_7'));
src = docsOfClass(out, 'daqreader_image_epochdata_ingested');
verifyEqual(testCase, numel(src), 1);
md = src{1}.get('daqreader_image_epochdata_ingested.metadata');
verifyTrue(testCase, isfield(md, 'israster'));
verifyTrue(testCase, isfield(md, 'lines_per_frame'));
end

function testImageIngestedCarriesNoEdgeToASubjectOrElement(testCase)
% A DURABLE FACT about the did_v1 class, not a snapshot of unfinished work --
% this one never needs inverting, and it is the reason the signed fold
% (V_eta_ingested_payload_findings.md:275) cannot be built rather than merely
% being deferred.
%
% The writer sets exactly one dependency, `daqreader_id`
% (+ndi/+daq/+reader/image.m:220), and the template declares exactly that one.
% What was not recorded until 2026-08-12 is that a BATCH POST-PASS -- the usual
% rescue for a missing subject -- has nothing to walk either. Over the NDI
% template graph, all 91 origin/main templates parsed:
%
%   forward closure from this class:  {daqreader_image_epochdata_ingested,
%                                      daqreader};  neither declares subject_id
%                                      or element_id
%   pointing AT daqreader:            the three ingested classes + daqsystem,
%                                      whose own edges are filenavigator_id /
%                                      daqreader_id / daqmetadatareader_id
%   declaring a subject_id edge:      10 of 91 (element, image, imageCollection,
%                                      imageStack, measurement, openminds_subject,
%                                      subjectmeasurement, treatment,
%                                      treatment_drug, virus_injection)
%   of those 10, declaring daqreader_id or daqsystem_id: NONE
%
% The device-to-subject join is not in the database at all: +ndi/+daq/system.m:
% 229-234 matches `strcmpi(myprobemap.devicename, obj.name)` against the
% EPOCHPROBEMAP FILES and takes `subject_id` from `epc(ec).subjectstring`, one
% daqsystem to MANY probes. If this test ever goes red, a source shape gained an
% edge and the migrator header's blocker 1 is the thing to re-read first.
out = runJ(imageIngestedV1());
% ASSERT, not verify: everything below reads out.migrated{1}, and a verify on
% the count would let an empty result set pass the rest vacuously.
assertEqual(testCase, numel(out.migrated), 1, ...
    'the passthrough emitted no document; every assertion below would be vacuous');
doc = out.migrated{1};
deps = doc.get('depends_on');
assertEqual(testCase, numel(deps), 1, ...
    'daqreader_image_epochdata_ingested acquired a second edge; see the migrator header');
verifyEqual(testCase, char(deps(1).name), 'daqreader_id');
verifyEqual(testCase, depVal(doc, 'daqreader_id'), 'dr_img');
% stated separately from the count so a failure says WHICH edge appeared
verifyEmpty(testCase, depVal(doc, 'subject_id'));
verifyEmpty(testCase, depVal(doc, 'element_id'));
end

function testImageIngestedPassthroughKeepsEveryHeaderFieldWithNoDestination(testCase)
% THE PASSTHROUGH'S ACTUAL CONTRACT, asserted across the WHOLE header rather
% than the two fields that happened to be spot-checked.
%
% Revision 2 of the signed plan (V_eta_ingested_payload_findings.md:307-317)
% re-specifies the fold through the data_body AXIS ENTRY -- dimension_order to
% the order of the axes[] entries, dimension_size to each axis's n, data_type to
% `datum_type` ON THE STATEMENT, frametimes to the time axis's `values`.
%
% THIS COMMENT USED TO SAY THOSE DESTINATIONS DID NOT EXIST -- "`datum_type` has
% 0 declarations; `axes` [...] NOT by subject_statement; [...] NO axes shape
% declares a per-sample `values` slot". Measured over 245 json files on
% 2026-08-12; ALL THREE ARE FALSE AS OF THE SIGNED data_body BUILD, and the
% wording is corrected rather than dropped because it read as schema work
% outstanding when the schema work had landed. See the migrator header's 4' for
% the re-derivation (247 files / 241 classes / 1021 field paths), and
% testImageIngestedFoldDestinationsExistSoOnlyTheSubjectBlocks below, which
% MACHINE-CHECKS it so it cannot go stale silently a second time.
%
% What the fold still lacks is a SUBJECT, not a slot. Until that is answered,
% every one of these seven fields survives only because the document is carried
% whole -- which is what this asserts.
out = runJ(imageIngestedV1());
assertEqual(testCase, numel(out.migrated), 1, ...
    'the passthrough emitted no document; every assertion below would be vacuous');
doc = out.migrated{1};
blk = doc.get('daqreader_image_epochdata_ingested');
headerFields = {'dimension_order', 'dimension_size', 'data_type', 'num_frames', ...
                'frametimes', 'clocktype', 'metadata'};
% the loop's iterable is a literal, and its length is pinned so it cannot shrink
% to nothing and still pass
assertEqual(testCase, numel(headerFields), 7);
for k = 1:numel(headerFields)
    verifyTrue(testCase, isfield(blk, headerFields{k}), ...
        ['the passthrough dropped header field ' headerFields{k}]);
end
% and the values, not merely the keys -- a field present but blanked is the
% silent-loss shape this repository keeps paying for
verifyEqual(testCase, blk.dimension_order, 'YXCZT');
verifyEqual(testCase, blk.dimension_size, [64 64 1 1 3]);
verifyEqual(testCase, blk.data_type, 'uint16');
verifyEqual(testCase, blk.frametimes, [0 0.5 1.0]);
verifyEqual(testCase, blk.clocktype, 'dev_local_time');
% the INHERITED parent block, which is where the clock extents live, and the file
verifyEqual(testCase, ...
    doc.get('daqreader_epochdata_ingested.epochtable.t0_t1'), [0; 12.5]);
verifyEqual(testCase, doc.get('files.file_list'), {'frames.bin'});
end

function testImageIngestedFoldDestinationsExistSoOnlyTheSubjectBlocks(testCase)
% WHY THE SIGNED FOLD IS STILL UNBUILT, ASSERTED AGAINST THE SCHEMA RATHER THAN
% RESTATED IN PROSE. Four of this class's recorded blockers have now been
% checked twice by hand and gone stale twice in the SAME direction -- claiming
% less built than exists -- so the ones that can be machine-read are read.
%
% Two halves, and the test's whole point is that they now disagree:
%
%   the DESTINATIONS exist   -- revision 2 of the signed plan
%       (V_eta_ingested_payload_findings.md:307-317) routes the raster header
%       through the data_body axis entry, and every slot it names is in the
%       built tree since TEAM-SIGN-OFF [data_body] 2026-08-14.
%   the SUBJECT does not     -- image_observation requires `subject_id`, and
%       the did_v1 document carries exactly one edge, `daqreader_id`
%       (+ndi/+daq/+reader/image.m:220), with no id path to a subject anywhere
%       in the 91 templates.
%
% So a red line HERE means the schema moved and the migrator header's 4' needs
% re-deriving; a red line in
% testImageIngestedCarriesNoEdgeToASubjectOrElement means the SOURCE moved and
% blocker 1 -- the team question -- may have an answer. Those are different
% events and this file must not report them as one.
assumeVEtaSchemas(testCase);
cache = did2.schema.cache.shared();
% assumeVEtaSchemas probes `acquisition_metadata_file` and `relative_reference`,
% and BOTH are in schemas/V_eta/stable. The two classes this test is about are
% in schemas/V_eta/DRAFT, and did2.schema.cache reads ONE non-recursive folder
% (`dir(fullfile(obj.schemaPath, '*.json'))`), so a stable-only path satisfies
% that probe and would then make this test ERROR on a missing class rather than
% skip. CI assembles stable + draft + deprecated into one flat directory
% (test-code.yml:157); locally it may not. Probe what THIS test needs.
try
    cache.getClass('image_observation');
    cache.getClass('sampled_body');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH resolves the stable tier but not the DRAFT ' ...
         'classes this test reads (' err.message '). Point it at an ' ...
         'assembled stable+draft V_eta set.']);
end

% -- the subject is REQUIRED, on both unemitted targets -------------------
% stated as a set membership rather than a count: the assertion is about
% subject_id specifically, and a count would pass on the wrong edge.
obsRequired = cache.requiredDependencies('image_observation');
verifyTrue(testCase, any(strcmp(obsRequired, 'subject_id')), ...
    ['image_observation no longer requires subject_id; blocker 1 in ' ...
     '+migrators_j/daqreader_image_epochdata_ingested.m is the thing to re-read']);
bodyRequired = cache.requiredDependencies('sampled_body');
verifyTrue(testCase, any(strcmp(bodyRequired, 'statement')), ...
    ['sampled_body no longer requires `statement`; both unemitted targets ' ...
     'hung off that one edge, which is why the fold was one fact away']);

% -- and the destinations the header would land in DO exist ---------------
stmtFields = fieldNamesOf(cache, 'subject_statement');
verifyTrue(testCase, ismember('datum_type', stmtFields), ...
    'subject_statement.datum_type is where revision 2 puts `data_type`');
verifyTrue(testCase, ismember('axes', stmtFields), ...
    'subject_statement.axes is the statement half of the axis entry');

% the IRREGULAR case specifically -- `frametimes` is one time per frame
% (+ndi/+daq/+reader/image.m:180, :196-202), so origin/spacing cannot hold it
% and a `values` slot is the only landing place.
axesDef = namedField(cache, 'sampled_body', 'axes');
assertNotEmpty(testCase, axesDef, ...
    'sampled_body declares no `axes`; every assertion below would be vacuous');
axisSub = subFieldNames(axesDef);
verifyTrue(testCase, ismember('values', axisSub), ...
    'sampled_body.axes[].values is the only home for irregular frametimes');
verifyTrue(testCase, ismember('regular', axisSub), ...
    'without `regular` nothing distinguishes stored coordinates from generated ones');
verifyTrue(testCase, ismember('n', axisSub), ...
    'each axis`s `n` is where dimension_size lands');
end

% ===================== under the real V_eta validator ======================

function testMetadataFoldValidatesUnderVEta(testCase)
assumeVEtaSchemas(testCase);
out = runJValidated(withEpochEdge(metadataIngestedV1(), 'epoch_doc_1'));
verifyEqual(testCase, out.summary.quarantine_count, 0, ...
    reasonsOf(out));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'acquisition_metadata_file');
end

function testMetadataPassthroughValidatesUnderVEta(testCase)
% The passthrough is only SAFE because the source tombstone was repaired from
% the real template during the schema half. If it is ever deleted ahead of the
% fold, this test is what says so -- that mistake put 2,484 corpus-B documents
% in quarantine once.
assumeVEtaSchemas(testCase);
out = runJValidated(metadataIngestedV1());
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
end

function testReferenceLiftValidatesUnderVEta(testCase)
assumeVEtaSchemas(testCase);
out = runJValidated(withEpochEdge( ...
    readerIngestedV1({'dev_local_time'}, [0; 10]), 'epoch_doc_1'));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
verifyEqual(testCase, numel(docsOfClass(out, 'relative_reference')), 1);
end

function testTheFoldLeavesNoEmptyRequiredEdgeAndNoFragment(testCase)
% The two instruments that would see this family failing quietly. An
% acquisition_metadata_file with an empty epoch_id would validate, so
% quarantine_count alone proves nothing.
assumeVEtaSchemas(testCase);
out = runJValidated(withEpochEdge(metadataIngestedV1(), 'epoch_doc_1'));
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
verifyEqual(testCase, out.silent_loss.vacuous_field_count, 0);
verifyEqual(testCase, out.summary.fragment_count, 0);
% and the declared payload is actually carried (#64's first direction)
verifyEqual(testCase, out.file_list_audit.declared_absent_count, 0);
end

function msg = reasonsOf(out)
%REASONSOF The quarantine reasons, as a NON-EMPTY diagnostic.
%   A test that says only "expected 0, got 3" sends the reader back to a corpus
%   run to find out why; the reason text is already in hand here.
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

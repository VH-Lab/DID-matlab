function tests = testStrandedSourceTombstones
%TESTSTRANDEDSOURCETOMBSTONES `generic_file` and `valid_interval` -- the last two
%   did_v1 classes that STRANDED COMPLETELY.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment this file was
%   written in, so every assertion below is UNVERIFIED. Read it as a
%   specification of intended behaviour, not as a passing suite. Run
%       results = runtests('did2.unittest.testStrandedSourceTombstones');
%   and treat any red as a defect in the code or in these tests, not as a
%   surprise.
%
%   Do NOT merge these into testMigratorsJ -- that file is being edited
%   concurrently.
%
%   ---------------------------------------------------------------------
%   WHAT "STRANDED COMPLETELY" MEANT
%   ---------------------------------------------------------------------
%   Every other did_v1 class has a V_eta schema, or a migrator, or both. These
%   two had NEITHER:
%
%       ls +did2/+convert/+migrators_j/ | wc -l              ->  82
%       ls +did2/+convert/+migrators_j/ | grep -i generic\|valid   ->  (nothing)
%       ls +did2/+convert/+migrators/   | grep -i generic\|valid   ->  (nothing)
%       find DID-schema/schemas/V_eta -name 'generic_file.json'    ->  (nothing)
%       find DID-schema/schemas/V_eta -name 'valid_interval.json'  ->  (nothing)
%
%   With no migrator, v1_to_v2 falls back to did2.convert.migrators.identity
%   (v1_to_v2.m:370-376), so the document arrives at validation in its did_v1
%   shape -- and with no schema of that name there is nothing for it to validate
%   against. It is not migrated, not passed through, not quarantined-and-kept.
%   A dataset carrying one loses it.
%
%   THE FIX IS A TOMBSTONE, NOT A MODEL. Both classes are now restated in
%   DID-schema tools/build_v_eta.py from the NDI WRITER, marked `retire` (a v1
%   SOURCE name, never a go-forward class). No migrator is added, deliberately:
%   this is the vmspikefilteringparameters shape, where a correct tombstone IS
%   the whole fix. Whether generic_file folds to opaque_body + a statement, and
%   what tier valid_interval belongs to, are TEAM decisions that have not been
%   made -- see the report and DID-schema build_v_eta.py's own comment block.
%
%   ---------------------------------------------------------------------
%   THE FIXTURES, AND WHERE EACH ONE COMES FROM
%   ---------------------------------------------------------------------
%   Ground-truth rule: NDI origin/main templates are did_v1 truth, and where
%   TEMPLATE and WRITER disagree the WRITER wins. Fixtures are never built from
%   a DID-side schema. BOTH fixtures here are FROM THE WRITER; neither class is
%   in the writerless bucket.
%
%     generic_file    +ndi/+setup/+conv/+babu/import.m, TWO construction sites
%                     (:526-531 plasmid, :575-580 LC-MS), identical in shape:
%
%                       generic_file = struct('filename',<f>, ...
%                           'formatOntology','EMPTY:0000253', ...
%                           'checksum',checksum, ...
%                           'dateCreated',dateCreated,'dateUpdated',dateUpdated);
%                       doc = ndi.document('generic_file','generic_file',generic_file) ...
%                             + session.newdocument();
%                       doc = doc.add_file('generic_file.ext',file,'delete_original',0);
%                       doc = doc.set_dependency_value('document_id',<subject id>);
%
%                     All five fields always populated; the file always attached;
%                     the edge always set. dateCreated/dateUpdated are datenum
%                     DOUBLES (convertTo(...,'datenum') at :522-523, :571-572) and
%                     generic_file_schema.json types both `double` -- writer and
%                     schema AGREE, so the template's `""` literal is a
%                     placeholder, not evidence about documents.
%
%     valid_interval  +ndi/+app/markgarbage.m. markvalidinterval (:55-58) builds
%                     one entry {timeref_structt0, t0, timeref_structt1, t1};
%                     savevalidinterval (:79-96) reads the existing array back,
%                     APPENDS, deletes the old document and writes a new one
%                     holding the WHOLE array, then sets element_id to the
%                     epochset's id (:95). The epochset is a PROBE -- :76-78
%                     errors on anything else.
%
%   ---------------------------------------------------------------------
%   THE WRITER/TEMPLATE DIVERGENCE: `session_ID`
%   ---------------------------------------------------------------------
%   markgarbage.m:55,57 fill both timeref blocks from
%   ndi.time.timereference.ndi_timereference_struct(), which returns SIX fields
%   (timereference.m:106-111): referent_epochsetname, referent_classname,
%   clocktypestring, epoch, session_ID, time. The NDI TEMPLATE declares FIVE --
%   no session_ID -- and never has:
%
%       git log --all --oneline -S"session_ID" -- '*valid_interval.json'
%           (no output -- 0 commits)
%
%   Undeclared, that sixth field is did2:validation:undeclaredField on every real
%   document (cache.m:696-707). The tombstone declares it in its CAMEL spelling,
%   because universalRenames snake_cases only a block's IMMEDIATE field names and
%   session_ID is nested one level down (universalRenames.m:302-347, "nested
%   struct values are left alone"). testValidIntervalSessionIdSurvivesUnrenamed
%   pins both halves of that.
%
%   ---------------------------------------------------------------------
%   THE FABRICATED ENUM THAT WOULD HAVE QUARANTINED REAL DOCUMENTS
%   ---------------------------------------------------------------------
%   The V_zeta shape these tombstones replace constrained clocktypestring to SIX
%   values. NDI's real vocabulary is NINE (clocktype.m:69-71): utc, approx_utc,
%   exp_global_time, approx_exp_global_time, dev_global_time,
%   approx_dev_global_time, dev_local_time, no_time, inherited. The three the
%   enum omitted -- approx_exp_global_time, approx_dev_global_time, inherited --
%   would each have been rejected on a constraint DID invented. The tombstone now
%   enumerates nothing; testValidIntervalAcceptsTheClocksTheOldEnumOmitted pins
%   that, one document per omitted value.
%
%   ---------------------------------------------------------------------
%   THE OPEN QUESTION THIS FILE CANNOT CLOSE: THE ARRAY BLOCK
%   ---------------------------------------------------------------------
%   `valid_interval` is the ONLY one of NDI's 91 production templates whose
%   property block is a JSON ARRAY rather than an object (checked mechanically:
%   91 template files, 91 parsed, 0 unparseable, 1 array block). The writer
%   APPENDS, so a probe with three marked intervals is ONE document holding a
%   3-element struct array -- accumulation is the normal path, not an edge case.
%
%   The DID meta-schema declares `fields` on a scalar block and has no way to say
%   "the block is an array of these". So the tombstone is correct for the
%   single-interval document and UNDER-SPECIFIED for a multi-interval one, and
%   cache.validateField reads `block.(fieldName)` (cache.m:1227), which on a 1xN
%   struct is a comma-separated list.
%
%   testMultiIntervalIsNeverSILENTLYTruncated therefore asserts the one invariant
%   that must hold whichever way MATLAB resolves that -- a multi-interval
%   document must NOT validate clean while having lost intervals 2..N -- rather
%   than guessing which branch fires. It is written that way ON PURPOSE: an
%   assertion invented to match an unrun code path is the "test written from the
%   same premise as the code" failure, and the honest thing to encode is the
%   invariant, not a prediction. Whoever first runs MATLAB here learns the
%   answer; a human then decides what to do about it.

tests = functiontests(localfunctions);
end

% ===================== harness =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runJValidated(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
end

function d = onlyClass(testCase, out, className)
%ONLYCLASS The single migrated document of CLASSNAME (fails if not exactly one).
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

function verifyNoQuarantine(testCase, out, what)
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined: [%s] %s', what, ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
end

function v = depValue(doc, name)
% Read the edge tolerantly: a depends_on entry is spelled `value` on a body a
% migrator built and `document_id` once universalRenames has normalised it
% (universalRenames.m:369-422). Both shapes are live on this path.
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

% ===================== fixtures ============================================

function v1 = genericFileWriterBody(id, sessionId, ownerId)
% THE WRITER, +ndi/+setup/+conv/+babu/import.m:526-531 (the plasmid branch; the
% LC-MS branch at :575-580 differs only in the formatOntology CURIE and in
% pointing document_id at a subject rather than a subject_group).
%
% Field names are the v1 CAMEL spellings on purpose -- universalRenames
% snake_cases a block's immediate field names, and that pass is part of what
% these tests exercise. Do not pre-snake them here.
v1 = struct();
v1.document_class = struct('class_name', 'generic_file', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {'document_id'}, 'value', {ownerId});
v1.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'pAAV-hSyn-GCaMP6f', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.generic_file = struct( ...
    'filename', '/Users/lab/Documents/240601/plasmids/pAAV-hSyn-GCaMP6f.gb', ...
    'formatOntology', 'EMPTY:0000253', ...
    'checksum', 'd41d8cd98f00b204e9800998ecf8427e', ...
    'dateCreated', 739404.5, ...
    'dateUpdated', 739410.25);
v1.files = struct('file_list', {{'generic_file.ext'}});
end

function s = timerefStruct(clockType, epochValue)
% ndi_timereference_struct(), timereference.m:106-111 -- SIX fields. session_ID
% is the one no NDI template declares.
s = struct( ...
    'referent_epochsetname', 'ctx_probe_1', ...
    'referent_classname', 'ndi.probe.timeseries.mfdaq', ...
    'clocktypestring', clockType, ...
    'epoch', epochValue, ...
    'session_ID', '412ab9de00e4f2c1_40a0dc1e9f0011ef', ...
    'time', 0);
end

function v1 = validIntervalWriterBody(id, sessionId, elementId, entries)
% THE WRITER, markgarbage.m:93-96. ENTRIES is a struct array of
% {timeref_structt0, t0, timeref_structt1, t1} -- a 1-element array is the
% single-interval document, an N-element array is what savevalidinterval writes
% after N calls to markvalidinterval (it reads the array back and APPENDS,
% :79-89, then replaces the document).
v1 = struct();
v1.document_class = struct('class_name', 'valid_interval', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'app'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {elementId});
v1.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% v1 spells these `name` / `version`; universalRenames maps them to
% app_name / app_version (universalRenames.m:145-164).
v1.app = struct('name', 'ndi.app.markgarbage', 'version', '1.0', ...
    'url', '', 'os', '', 'os_version', '', ...
    'interpreter', '', 'interpreter_version', '');
v1.valid_interval = entries;
end

function e = intervalEntry(t0, t1, clockType, epochValue)
e = struct( ...
    'timeref_structt0', timerefStruct(clockType, epochValue), ...
    't0', t0, ...
    'timeref_structt1', timerefStruct(clockType, epochValue), ...
    't1', t1);
end

% ===================== generic_file ========================================

function testGenericFileHasASchemaAtAll(testCase)
% THE NEGATIVE CONTROL FOR THE WHOLE FILE. This is the assertion whose absence
% let the class strand: nothing anywhere checked that a did_v1 class the corpora
% could contain has SOMETHING to validate against. getClass raises
% did2:schema:missingClass when there is no schema file (cache.m:125-129).
cache = did2.schema.cache.shared();
s = cache.getClass('generic_file');
verifyEqual(testCase, char(s.document_class.class_name), 'generic_file');
s = cache.getClass('valid_interval');
verifyEqual(testCase, char(s.document_class.class_name), 'valid_interval');
end

function testGenericFilePassesThroughIdPreserved(testCase)
% No migrator, by decision: the identity fallback carries the document, and the
% tombstone is what lets it validate. The id must survive -- an ontologyLabel
% document points its `document_id` AT this one (import.m:534-537), so a changed
% id dangles that edge.
out = runJValidated(genericFileWriterBody('gf_1', 'sess_1', 'subjgrp_1'));
verifyNoQuarantine(testCase, out, 'generic_file');
d = onlyClass(testCase, out, 'generic_file');
verifyEqual(testCase, char(d.get('base.id')), 'gf_1');
verifyEqual(testCase, depValue(d, 'document_id'), 'subjgrp_1');
end

function testGenericFileKeepsEveryFieldTheWriterWrites(testCase)
% Five fields, all populated by both construction sites, none dropped. The
% CAMEL v1 spellings arrive snake_cased by universalRenames -- which is why the
% tombstone declares format_ontology / date_created / date_updated and not the
% template's spellings.
out = runJ(genericFileWriterBody('gf_2', 'sess_1', 'subjgrp_1'));
b = onlyClass(testCase, out, 'generic_file').get('generic_file');
verifyEqual(testCase, sort(fieldnames(b)), sort({'filename'; 'format_ontology'; ...
    'checksum'; 'date_created'; 'date_updated'}));
verifyEqual(testCase, char(b.format_ontology), 'EMPTY:0000253');
verifyEqual(testCase, char(b.checksum), 'd41d8cd98f00b204e9800998ecf8427e');
end

function testGenericFileDatesStayNumeric(testCase)
% dateCreated/dateUpdated are datenum DOUBLES from the writer
% (convertTo(...,'datenum')) and generic_file_schema.json types both `double`.
% Writer and schema agree, so `double` is the tombstone's type and the values
% must not be stringified on the way through -- `double` demands isnumeric
% (cache.m validateTypeShape), so a stringified date is a typeMismatch.
out = runJValidated(genericFileWriterBody('gf_3', 'sess_1', 'subjgrp_1'));
verifyNoQuarantine(testCase, out, 'generic_file');
b = onlyClass(testCase, out, 'generic_file').get('generic_file');
verifyTrue(testCase, isnumeric(b.date_created) && isscalar(b.date_created));
verifyTrue(testCase, isnumeric(b.date_updated) && isscalar(b.date_updated));
verifyEqual(testCase, b.date_created, 739404.5, 'AbsTol', 1e-9);
end

function testGenericFileKeepsItsFile(testCase)
% The bytes are the whole point of the class. NDI names the slot with a literal
% `.ext`; the real extension is recoverable only from `filename`, which is what
% downloadGenericFiles.m:107-126 reconstructs. Losing either loses the file.
out = runJ(genericFileWriterBody('gf_4', 'sess_1', 'subjgrp_1'));
s = onlyClass(testCase, out, 'generic_file').toStruct();
verifyTrue(testCase, isfield(s, 'files') || isfield(s, 'file'), ...
    'the generic_file.ext attachment must survive the passthrough');
end

function testGenericFileTemplatePlaceholdersDoNotReachTheValidator(testCase)
% THE TYPE TRAP, recorded rather than assumed. NDI's TEMPLATE carries `""` for
% all five fields, including the two its own schema types `double`. Nothing the
% Babu writer produces looks like that -- it fills every field -- so this is a
% statement about the template, not about documents. But a caller who
% constructed ndi.document('generic_file') and set nothing WOULD carry the
% placeholders, and `double` rejects '' (validateTypeShape demands isnumeric).
%
% ASSERTED AS TODAY'S BEHAVIOUR, NOT AS DESIRED BEHAVIOUR. There is no writer
% path that produces it and therefore no evidence about what should happen, so
% this pins the outcome rather than endorsing it. If a real corpus ever turns up
% blank-dated generic_file documents, the fix is a guarded migrator that DROPS
% the placeholders (the binaryseries_parameters precedent: absence is how V_eta
% spells unset), not a re-typing of the field.
v1 = genericFileWriterBody('gf_5', 'sess_1', 'subjgrp_1');
v1.generic_file.dateCreated = '';
v1.generic_file.dateUpdated = '';
out = runJValidated(v1);
verifyEqual(testCase, numel(out.quarantine), 1, ...
    'a template-placeholder date is expected to quarantine TODAY');
verifyEqual(testCase, char(out.quarantine(1).class_name), 'generic_file');
end

% ===================== valid_interval ======================================

function testValidIntervalPassesThroughIdAndEdgePreserved(testCase)
out = runJValidated(validIntervalWriterBody('vi_1', 'sess_1', 'probe_1', ...
    intervalEntry(10.5, 300.25, 'dev_local_time', 't00003')));
verifyNoQuarantine(testCase, out, 'valid_interval');
d = onlyClass(testCase, out, 'valid_interval');
verifyEqual(testCase, char(d.get('base.id')), 'vi_1');
% element_id, set at markgarbage.m:95 from the PROBE's id. migrators_j.element
% promotes elements to subjects with ids PRESERVED, so this edge resolves.
verifyEqual(testCase, depValue(d, 'element_id'), 'probe_1');
end

function testValidIntervalKeepsBothEndsAndTheirSeparateAnchors(testCase)
% markvalidinterval takes an INDEPENDENT timeref for each end
% (markgarbage.m:41,55-58), so t0 and t1 are anchored separately by design.
% Collapsing them to one anchor would be a model change, and no model is signed.
out = runJ(validIntervalWriterBody('vi_2', 'sess_1', 'probe_1', ...
    intervalEntry(10.5, 300.25, 'dev_local_time', 't00003')));
b = onlyClass(testCase, out, 'valid_interval').get('valid_interval');
verifyEqual(testCase, sort(fieldnames(b)), sort({'timeref_structt0'; 't0'; ...
    'timeref_structt1'; 't1'}));
verifyEqual(testCase, b.t0, 10.5, 'AbsTol', 1e-12);
verifyEqual(testCase, b.t1, 300.25, 'AbsTol', 1e-12);
end

function testValidIntervalSessionIdSurvivesUnrenamed(testCase)
% THE WRITER/TEMPLATE DIVERGENCE, both halves.
%
% (1) The writer emits session_ID (timereference.m:110) and NO NDI template has
%     ever declared it, so the tombstone had to declare it or every real
%     document would hit did2:validation:undeclaredField.
% (2) It keeps its CAMEL spelling: universalRenames snake_cases only a block's
%     IMMEDIATE field names (universalRenames.m:302-347), and session_ID is
%     nested inside timeref_structt0/t1. If that pass ever starts descending,
%     this test goes red BEFORE a corpus does -- which is the point of pinning
%     the spelling rather than accepting either.
out = runJValidated(validIntervalWriterBody('vi_3', 'sess_1', 'probe_1', ...
    intervalEntry(0, 60, 'dev_local_time', 't00001')));
verifyNoQuarantine(testCase, out, 'valid_interval');
b = onlyClass(testCase, out, 'valid_interval').get('valid_interval');
for blk = {'timeref_structt0', 'timeref_structt1'}
    t = b.(blk{1});
    verifyTrue(testCase, isfield(t, 'session_ID'), ...
        sprintf('%s.session_ID is written by the writer and must survive', blk{1}));
    verifyFalse(testCase, isfield(t, 'session_id'), ...
        'nested fields are NOT snake_cased; the tombstone declares the camel name');
    verifyEqual(testCase, char(t.session_ID), '412ab9de00e4f2c1_40a0dc1e9f0011ef');
end
end

function testValidIntervalAcceptsTheClocksTheOldEnumOmitted(testCase)
% THE FABRICATED CONSTRAINT, one document per omitted value.
%
% The V_zeta shape enumerated SIX clocktypestring values. NDI's real vocabulary
% is NINE (clocktype.m:69-71). Each of these three was a real clock NDI can
% write and DID would have rejected -- a quarantine caused by the schema, on a
% document that is perfectly well formed.
for ct = {'approx_exp_global_time', 'approx_dev_global_time', 'inherited'}
    out = runJValidated(validIntervalWriterBody(['vi_ct_' ct{1}], 'sess_1', ...
        'probe_1', intervalEntry(0, 1, ct{1}, 't00001')));
    verifyNoQuarantine(testCase, out, ['valid_interval/' ct{1}]);
end
end

function testValidIntervalAcceptsAnEmptyEpoch(testCase)
% timereference.m:71 sets `epoch = []` whenever the clocktype does not
% needsepoch(), so an empty epoch is a NORMAL document, not a defect. The V_zeta
% shape typed the field `char`, which rejects an empty numeric outright
% (validateTypeShape accepts only char/string for `char`); `string` accepts it.
%
% NOTE THE REMAINING HOLE, raised in the report and not papered over here: NDI
% documents `epoch` as "either a string or a number" (timereference.m:26,102),
% and `string` does NOT accept a non-empty numeric. The meta-schema has no union
% type. A numeric epoch number still quarantines. That is an open question for a
% human, so it is deliberately NOT asserted either way.
out = runJValidated(validIntervalWriterBody('vi_4', 'sess_1', 'probe_1', ...
    intervalEntry(0, 60, 'exp_global_time', [])));
verifyNoQuarantine(testCase, out, 'valid_interval with an empty epoch');
end

function testMultiIntervalIsNeverSILENTLYTruncated(testCase)
% THE OPEN QUESTION, encoded as the invariant rather than as a prediction.
%
% valid_interval is the only one of NDI's 91 templates whose property block is a
% JSON ARRAY, and savevalidinterval APPENDS (markgarbage.m:79-96) -- so a probe
% with three marked intervals is ONE document with a 3-element struct array. The
% DID meta-schema declares fields on a SCALAR block and cannot express that, and
% cache.validateField reads `block.(fieldName)` (cache.m:1227), which on a 1xN
% struct is a comma-separated list.
%
% What must hold either way: the document must not validate clean while having
% lost intervals 2..N. Losing which stretches of an epoch are good data, quietly,
% is the exact failure this whole file exists to stop -- and it would be worse
% than the stranding it replaces, because a quarantine is visible and a truncated
% document is not.
entries = [intervalEntry(0, 60, 'dev_local_time', 't00001'), ...
           intervalEntry(120, 180, 'dev_local_time', 't00001'), ...
           intervalEntry(240, 300, 'dev_local_time', 't00002')];
verifyEqual(testCase, numel(entries), 3, 'fixture must hold three intervals');

% (a) the passthrough itself must carry all three -- this is about identity /
%     universalRenames, and is verifiable independently of the validator.
out = runJ(validIntervalWriterBody('vi_5', 'sess_1', 'probe_1', entries));
b = onlyClass(testCase, out, 'valid_interval').get('valid_interval');
verifyEqual(testCase, numel(b), 3, ...
    'the identity passthrough must not drop intervals');

% (b) under validation: EITHER it quarantines (visible, recoverable) OR it
%     validates with all three still present. Never clean-and-truncated.
outV = runJValidated(validIntervalWriterBody('vi_6', 'sess_1', 'probe_1', entries));
if isempty(outV.quarantine)
    bv = onlyClass(testCase, outV, 'valid_interval').get('valid_interval');
    verifyEqual(testCase, numel(bv), 3, ...
        ['a multi-interval valid_interval validated CLEAN but no longer holds ' ...
         'three intervals -- silent truncation of curation data']);
else
    verifyEqual(testCase, char(outV.quarantine(1).class_name), 'valid_interval', ...
        'if the array block is rejected it must be rejected AS valid_interval');
end
end

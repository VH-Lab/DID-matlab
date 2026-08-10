function tests = testMigratorsJEpoch
%TESTMIGRATORSJEPOCH The epoch family under TargetVersion 'V_eta' (#60).
%
%   Covers `epochfiles_ingested` and `element_epoch`. Separate file from
%   testMigratorsJ deliberately: most of what these tests assert is that the
%   #60 build is NOT finished, and those assertions have to be as visible and as
%   easy to delete as the code that finishes it.
%
%   WHAT #60 SIGNED (V_eta_epoch_plan.md, TEAM-SIGN-OFF [epoch] 2026-08-08):
%   mint `epoch` as an entity, one per epoch id; `acquisition_epoch` dissolves;
%   `epochid` drops in favour of a uniform `epoch_id` edge; `epochfiles_ingested`
%   becomes `ingestion_manifest` with `filenavigator_id` restored.
%
%   WHAT IS BUILT: the schema half only. `epoch` and `ingestion_manifest` exist
%   as classes; nothing emits either. The migrator half is deferred, because both
%   of the fold's inputs are whole-corpus facts a single-document migrator cannot
%   see, and because the fold's target has nowhere to put `epochprobemap`. The
%   migrator headers carry the measurements; these tests PIN the resulting
%   behaviour so the deferral cannot rot into an accident.
%
%   THE ONE THING THAT MUST NOT HAPPEN. `ingestion_manifest.epoch_id` is a
%   REQUIRED edge with no pass-1 referent. Emitting the class with that edge
%   empty would validate clean -- +did2/+validate/references.m:90 skips empty
%   edges -- and would rebuild, under the repair's own name, the defect the
%   repair exists to remove: 6,921 of 6,921 `epochfiles_ingested` documents
%   carrying an empty required edge. testNoEpochEdgeIsEverEmitted is that pin.
%
%   Fixtures are copied VERBATIM from corpus B
%   (ndi-programming-development.s3.amazonaws.com/B.zip), not composed from the
%   V_eta schema -- the standing rule after migrators were found to have been
%   written against DID-schema's own V_alpha snapshot. Every count quoted in a
%   comment here was measured over B's 12,917 documents, 0 unreadable.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJEpoch');

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v = depValue(b, name)
%DEPVALUE Read an edge off a body STRUCT, accepting both spellings.
%   universalRenames normalises v1's {name, value} to {name, document_id}
%   (universalRenames.m), so which key a body carries depends on where it came
%   from: a migrator that BUILT the edge still has `value`; an edge that came
%   through the rename -- as any passthrough's does -- has `document_id`. This
%   precedence is copied from +did2/+validate/references.m, which needs the same
%   fallback. Returns '' when the entry is absent OR present-and-empty; use
%   hasDep to tell those apart.
v = '';
if ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if ~isfield(deps(k), 'name') || ~strcmp(char(deps(k).name), name); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v = char(deps(k).value);
    end
    return;
end
end

function tf = hasDep(b, name)
%HASDEP True when an edge NAME is DECLARED, whether or not it has a value.
%   The distinction matters here and nowhere else in the suite: an empty
%   required edge is precisely the failure mode being guarded against, so
%   "absent" and "present but empty" cannot be collapsed.
tf = false;
if ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
        tf = true; return;
    end
end
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = char(out.migrated{k}.get('document_class.class_name'));
end
end

function v1 = ingestedBody(docId, sessionId, epochId, navigatorId)
%INGESTEDBODY A did_v1 `epochfiles_ingested` body, verbatim in shape.
%
%   Copied from corpus B, not composed. The real bodies are UNIFORM: across all
%   2,484 of them the top-level key set is exactly
%   {base, depends_on, document_class, epochfiles_ingested}, the dependency name
%   set is exactly {filenavigator_id}, and the block key set is exactly
%   {epoch_id, epochprobemap, files}. So this shape is the shape, not a sample of
%   one.
%
%   Two v1-isms are reproduced on purpose rather than tidied away, because they
%   are what real bodies carry and the passthrough has to survive them:
%     * `depends_on` is a SCALAR struct (the class declares one edge), not an
%       array;
%     * `document_class.class_version` is the NUMBER 1, and the superclass entry
%       carries only a `definition` path -- universalRenames derives `base` from
%       its basename.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name',         'epochfiles_ingested', ...
    'property_list_name', 'epochfiles_ingested', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', navigatorId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
blk = struct();
blk.epoch_id = epochId;
% assigned after the struct() call: struct('files', {{...}}) is the classic
% cell-in-struct trap and this field is genuinely a cell of char in v1.
blk.files = { ...
    ['epochid://' epochId]; ...
    ['/Users/vanhoosr/Desktop/2013_treeshrew_transLGNctx/2008-08-07/' epochId '/reference.txt']; ...
    ['/Users/vanhoosr/Desktop/2013_treeshrew_transLGNctx/2008-08-07/' epochId '/spike2data.smr']};
% THE ATTRIBUTION TABLE, verbatim: (name, reference, type, devicestring,
% subjectstring), tab-delimited. Non-empty on 2,484 of 2,484 corpus-B documents.
blk.epochprobemap = sprintf( ...
    'name\treference\ttype\tdevicestring\tsubjectstring\ntet\t7\tn-trode\tvhspike2:ai11-14\tts0820@fitzpatrick_duke\n');
v1.epochfiles_ingested = blk;
end

function v1 = elementEpochBody(docId, sessionId, epochId, elementId)
%ELEMENTEPOCHBODY A did_v1 `element_epoch` body, verbatim in shape.
%   Corpus B: 1,239 of these over 149 distinct epoch-id strings -- i.e. MANY
%   documents share one epoch, which is the fact the class name hides. All 1,239
%   declare `files.file_list = {'epoch_binary_data.vhsb'}` with an `ndicloud`
%   location, and the single-clock `[t0 t1]` shape below is B's.
v1 = struct();
v1.document_class = struct('class_name', 'element_epoch', 'class_version', 1, ...
    'superclasses', [ struct('class_name', 'base',    'class_version', 1), ...
                      struct('class_name', 'epochid', 'class_version', 1)]);
v1.depends_on = struct('name', 'element_id', 'value', elementId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochid = struct('epochid', epochId);
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0, 452.709856]);
end

% ===================== epochfiles_ingested: the deferral ===============

function testIngestedDocumentStaysItsOwnClass(testCase)
% #60 renames the class to `ingestion_manifest`. THE RENAME IS NOT DONE IN PASS
% ONE and this asserts it, because a half-done rename is worse than none: the
% target declares `epoch_id -> epoch` REQUIRED, and no `epoch` document exists
% until the second pass mints one.
out = runJ(ingestedBody('efi_1', 'sess_A', 't00070', 'nav_1'));
verifyEmpty(testCase, out.quarantine, 'epochfiles_ingested must not quarantine');
verifyEqual(testCase, numel(out.migrated), 1, ...
    'the passthrough is 1 -> 1; a fan-out here means someone started the fold');
verifyEqual(testCase, classNames(out), {'epochfiles_ingested'}, ...
    ['the class must NOT be ingestion_manifest yet -- see the migrator header ' ...
     'for the two blockers (the epoch mint, and epochprobemap having no home)']);
end

function testNoEpochEdgeIsEverEmitted(testCase)
% THE LOAD-BEARING TEST OF THIS FILE.
%
% The invented-empty-edge pattern is invisible to every existing gate: a
% document with a REQUIRED depends_on left '' validates clean, because
% +did2/+validate/references.m:90 short-circuits on an empty documentId. That is
% how `epochfiles_ingested.epochid` stayed empty on 6,921 of 6,921 documents
% across three corpora (Dab 4,088 / B 2,484 / Soph 349) while every gate stayed
% green.
%
% So the assertion is about the edge's PRESENCE, not its value: no emitted body
% may DECLARE an epoch edge at all until it can be populated. hasDep, not
% depValue -- depValue returns '' for both "absent" and "present and empty",
% which is exactly the confusion that let the original defect through.
out = runJ(ingestedBody('efi_2', 'sess_A', 't00070', 'nav_1'));
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    verifyFalse(testCase, hasDep(s, 'epoch_id'), ...
        'an `epoch_id` edge with nothing to point at is the defect, not the fix');
    verifyFalse(testCase, hasDep(s, 'epochid'), ...
        'the invented `epochid` edge must stay gone');
end
end

function testNoEpochEntityIsMintedInPassOne(testCase)
% Minting one `epoch` per epoch id is a grouping over the whole corpus, so it
% belongs to the NDI second pass (ndi.migrate.local, beside pathSPromotion) and
% cannot happen here. Two independent whole-corpus lookups are involved and
% neither is available to a single document:
%
%   1. THE GROUPING KEY IS (session, id), NOT the id. Corpus B's 2,484
%      epochfiles_ingested documents carry 149 distinct `epoch_id` strings but
%      1,242 distinct (base.session_id, epoch_id) pairs -- grouping on the string
%      alone fuses 1,242 real epochs into 149. (`t00070` restarts in every
%      session directory. sourceCensus reports 142 of B's 149 ids as spanning >1
%      session, 142 for Dab, 12 for Soph.)
%   2. `epoch.session_id` must point at the session DOCUMENT, whose `base.id` is
%      a fresh uid (ndi.document.m:58) and is NOT the `base.session_id` every
%      other document carries: they differ on 14 of 14 corpus-B session
%      documents.
out = runJ(ingestedBody('efi_3', 'sess_A', 't00070', 'nav_1'));
verifyFalse(testCase, any(strcmp(classNames(out), 'epoch')), ...
    'pass 1 must mint no `epoch`; the mint is the second pass');
verifyFalse(testCase, any(strcmp(classNames(out), 'ingestion_manifest')), ...
    'and therefore must mint nothing that depends on one');
end

function testTheFilenavigatorEdgeSurvivesPopulated(testCase)
% `filenavigator_id` is the edge NDI actually writes
% (+ndi/+file/navigator.m:707) and the one V_eta had dropped in favour of the
% invented `epochid`. It needs no repair in pass 1 -- passing through preserves
% it -- but it does need a test, because "restored" is half of what #60 signed
% and the other half is deferred. Non-empty on 2,484 of 2,484 corpus-B documents.
out = runJ(ingestedBody('efi_4', 'sess_A', 't00070', 'nav_77'));
s = out.migrated{1}.toStruct();
verifyEqual(testCase, depValue(s, 'filenavigator_id'), 'nav_77');
end

function testTheProbemapAndEpochStringSurviveVerbatim(testCase)
% BLOCKER 2, pinned. `ingestion_manifest` declares no `epochprobemap` field --
% under option B each row becomes edges -- but option B is blocked on the
% raw-recording model (#30, unsigned), and the plan's decision for now is "B as
% the model, A as pass-1 behaviour", A being "keep the probemap as text".
%
% The probemap is the per-epoch subject attribution: (name, reference, type,
% devicestring, subjectstring). Losing it is not a formatting change, it is
% losing whose neurons a recording belongs to. Non-empty on 2,484 of 2,484
% corpus-B documents, so any fold that drops it drops all of them.
%
% The `epoch_id` STRING is asserted alongside for the same reason: it is the
% only handle the second pass has for grouping, and #60 removes it from the
% class. It may not leave before its replacement edge arrives.
out = runJ(ingestedBody('efi_5', 'sess_A', 't00070', 'nav_1'));
d = out.migrated{1};
verifyEqual(testCase, d.get('epochfiles_ingested.epoch_id'), 't00070');
pm = d.get('epochfiles_ingested.epochprobemap');
verifyNotEmpty(testCase, pm, 'the probemap must not be dropped');
verifySubstring(testCase, pm, 'ts0820@fitzpatrick_duke', ...
    'the subjectstring column is the attribution -- it is the part that matters');
verifySubstring(testCase, pm, 'vhspike2:ai11-14', ...
    'the devicestring column carries the device and channel halves');
files = d.get('epochfiles_ingested.files');
verifyEqual(testCase, numel(files), 3, 'the ingestion manifest itself must survive');
end

function testTwoSessionsSharingAnEpochStringStayDistinct(testCase)
% The measured collision, driven end to end. Two documents, same `epoch_id`
% string, different sessions -- the ordinary case in corpus B (149 strings over
% 1,242 session/id pairs), not a contrived one.
%
% Pass 1 must keep them as two documents with their own session ids, so that a
% second pass keying on (session, id) still can. This test is here to FAIL if
% anyone ever groups or dedups on the string, which would silently merge
% recordings from different animals.
out = runJ({ingestedBody('efi_6', 'sess_A', 't00070', 'nav_A'), ...
            ingestedBody('efi_7', 'sess_B', 't00070', 'nav_B')});
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2, ...
    'one epoch-id string under two sessions is two epochs, never one');
s1 = out.migrated{1}.toStruct();
s2 = out.migrated{2}.toStruct();
verifyEqual(testCase, {s1.base.session_id, s2.base.session_id}, {'sess_A', 'sess_B'});
verifyEqual(testCase, {depValue(s1, 'filenavigator_id'), ...
                       depValue(s2, 'filenavigator_id')}, {'nav_A', 'nav_B'});
end

function testTheDeferralIsCountedAsUnconverted(testCase)
% A deferral has to be VISIBLE. v1_to_v2 counts a body a migrator hands straight
% back in `unconverted_by_class`, which is what makes "deliberately deferred"
% and "the migrator read a field that does not exist" separable by expectation
% rather than by reading code. This class is expected to appear there until the
% second pass lands; when it stops appearing, the fold has happened.
out = runJ(ingestedBody('efi_8', 'sess_A', 't00070', 'nav_1'));
verifyEqual(testCase, out.summary.unconverted_count, 1);
verifyTrue(testCase, isfield(out.summary.unconverted_by_class, 'epochfiles_ingested'));
verifyEqual(testCase, out.summary.unconverted_by_class.epochfiles_ingested, 1);
end

function testTheV_alphaEpochEdgeIsRejected(testCase)
% The shape assertion, same stance as ontology_label's. NDI declares exactly one
% dependency on this class; the `epochid` edge existed only DID-side, and was
% empty on every document that ever had it. Measured across corpus B: the
% dependency name set is {filenavigator_id} on 2,484 of 2,484, so this cannot
% fire on a real document -- only on a fixture built from our own schema.
%
% Asserted through the pipeline rather than by calling the migrator directly:
% the error must reach QUARANTINE (visible) rather than be swallowed.
v1 = ingestedBody('efi_9', 'sess_A', 't00070', 'nav_1');
v1.depends_on = [struct('name', 'filenavigator_id', 'value', 'nav_1'), ...
                 struct('name', 'epochid',          'value', 'acq_epoch_1')];
out = runJ(v1);
verifyEmpty(testCase, out.migrated, 'a V_alpha-shaped body must not migrate');
verifyEqual(testCase, numel(out.quarantine), 1);
verifySubstring(testCase, out.quarantine(1).reason, 'filenavigator_id', ...
    'the message must name the edge NDI does declare, not just complain');
end

function testIngestedDocumentValidatesAgainstItsSourceTombstone(testCase)
% Validation ON. The passthrough only works because the source tombstone was
% restated from the NDI template after a rename deleted it -- corpus B, run #2:
% 2,484 quarantines reading "No schema file for class epochfiles_ingested". This
% is the test that would have caught that, and the one that will catch it again
% if the tombstone is removed before the fold exists to replace it.
%
% runJ deliberately passes Validate=false, so this calls v1_to_v2 directly.
% Requires the V_eta schema set on DID_SCHEMA_PATH (the quick gate assembles it).
out = did2.convert.v1_to_v2(ingestedBody('efi_10', 'sess_A', 't00070', 'nav_1'), ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('epochfiles_ingested quarantined under validation: %s', ...
        out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'epochfiles_ingested');
end

% ===================== element_epoch: the rename, still =================

function testElementEpochStillRenamesToAcquisitionEpoch(testCase)
% #60 DISSOLVES this class, and the dissolution is NOT built: three of its four
% targets are unsigned or unbuilt (relative_reference migration, sampled_body
% #45, the raw-recording observation #30). Dissolving into targets that do not
% exist strands the payload, so the rename stands and this pins it.
out = runJ(elementEpochBody('ee_1', 'sess_A', 't00069', 'elem_1'));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, classNames(out), {'acquisition_epoch'});
s = out.migrated{1}.toStruct();
verifyFalse(testCase, isfield(s, 'element_epoch'), ...
    'the v1 block must be renamed in lockstep with the class');
end

function testElementEpochKeepsItsClockElementAndEpochString(testCase)
% What the class actually holds, all three preserved:
%   clocks       -- the base migrator's array-of-records parse of epoch_clock +
%                   the 2-by-N t0_t1 (single clock in corpus B)
%   element_id   -- the edge that makes this ONE ELEMENT's slice of an epoch
%                   rather than the epoch; `element.m` promotes elements to
%                   subjects with ids preserved, so it is not a dangling edge
%   epochid      -- the string 30 live NDI sites match by exact_string, and the
%                   ONLY thing a second pass can group on. #60 removes it from
%                   the target; until the `epoch_id` edge replaces it, dropping
%                   it loses the epoch association outright (the plan's own
%                   ordering constraint).
d = runJ(elementEpochBody('ee_2', 'sess_A', 't00069', 'elem_1')).migrated{1};
clocks = d.get('acquisition_epoch.clocks');
verifyEqual(testCase, numel(clocks), 1);
verifyEqual(testCase, clocks(1).name, 'dev_local_time');
verifyEqual(testCase, clocks(1).t0, 0);
verifyEqual(testCase, clocks(1).t1, 452.709856, 'AbsTol', 1e-9);
verifyEqual(testCase, d.get('epochid.epochid'), 't00069');
verifyEqual(testCase, depValue(d.toStruct(), 'element_id'), 'elem_1');
end

function testManyElementEpochsOfOneEpochStayManyDocuments(testCase)
% The naming error that produced a decision about the wrong object, pinned as
% behaviour. `acquisition_epoch` reads as "the epoch"; it is not. From the
% writer (+ndi/element.m:367-378) there is one document per ELEMENT per EPOCH,
% and corpus B has 1,239 of them over 149 distinct epoch-id strings.
%
% So two element_epochs sharing an epoch id must stay TWO documents. If a future
% change ever collapses them, it has confused the per-element record with the
% epoch entity -- which is exactly the confusion #60's revision exists to undo.
out = runJ({elementEpochBody('ee_3', 'sess_A', 't00069', 'elem_1'), ...
            elementEpochBody('ee_4', 'sess_A', 't00069', 'elem_2')});
verifyEqual(testCase, numel(out.migrated), 2);
verifyEqual(testCase, depValue(out.migrated{1}.toStruct(), 'element_id'), 'elem_1');
verifyEqual(testCase, depValue(out.migrated{2}.toStruct(), 'element_id'), 'elem_2');
verifyFalse(testCase, any(strcmp(classNames(out), 'epoch')), ...
    'renaming element_epoch is not minting an epoch');
end

% ===================== small assertion helper ==========================

function verifySubstring(testCase, haystack, needle, msg)
verifyTrue(testCase, ~isempty(strfind(char(haystack), needle)), msg); %#ok<STREMP>
end

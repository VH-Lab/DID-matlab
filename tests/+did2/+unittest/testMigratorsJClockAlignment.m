function tests = testMigratorsJClockAlignment
%TESTMIGRATORSJCLOCKALIGNMENT The clock-alignment cluster at V_eta (#57).
%
%   Exercises the three migrators that implement the two signed decisions in
%   `V_eta_clock_alignment_cluster_plan.md` (both TEAM-SIGN-OFF lines,
%   jess@walthamdatascience.com / 2026-08-08):
%
%     syncrule         -> clock_alignment_configuration: a DEVICE-PAIR rule
%                         (commonTriggers/randomPulses/filefind) gains EXACTLY 2
%                         acquisition_channels + a software entity (1 -> 4); a
%                         FILE-BASED rule (filematch, no device pair) gains ZERO
%                         channels and carries its file criterion instead (1 -> 2)
%                         -- TEAM-SIGN-OFF [sync configuration amendment 1],
%                         which relaxed acquisition_channels_# to {0,2}.
%     syncgraph        -> clock_alignment_policy + a software entity (1 -> 2),
%                         or a guarded passthrough when there is no session to
%                         point the REQUIRED session_id edge at.
%     syncrule_mapping -> clock_alignment + two relative_reference endpoints
%                         (1 -> 3) WHEN the epochnodes can be anchored to an
%                         `epoch` document -- and #58's passthrough repair
%                         otherwise, which is every did_v1 document today.
%
%   EVERY FIXTURE IS BUILT FROM THE WRITER, NOT FROM A DID-SIDE SCHEMA. The
%   parameter sets below are the structs the four rule implementations actually
%   construct on NDI-matlab origin/main --
%   commonTriggersOverlappingEpochs.m:36, randomPulses.m:34, filefind.m:32,
%   filematch.m:25 -- each of which is a CLOSED set validated field-by-field in
%   `isvalidparameters`. The syncrule_mapping fixture is the shape
%   syncgraph.m:296-320 writes, with the seven epochnode sub-fields the template
%   (ndi_common/database_documents/ingestion/syncrule_mapping.json) declares.
%   Building a fixture from our own schema is what produced ~2,078
%   distance_metadata quarantines from a migrator whose unit test was green.
%
%   THE GATE IS THE POINT OF HALF THESE TESTS. `relative_reference.relative_to`
%   is REQUIRED and the only honest referent is an `epoch` DOCUMENT, which no
%   migrator mints yet (#60). So the conversion branch of syncrule_mapping is
%   driven by a fixture that carries `epoch_id_1` / `epoch_id_2`, and the
%   passthrough branch by one that does not -- both branches, deliberately, the
%   same way private/jEpochDocId's guarded callers are tested.
%
%   Most tests run with Validate=false so they assert the TRANSFORM; the last
%   ones run with Validate=true against the real assembled V_eta schema, because
%   a transform test cannot tell you the fold and the schema agree. The four
%   target classes are in the DRAFT tier, so a stable-only DID_SCHEMA_PATH fails
%   here rather than skipping. Deliberate: a skip reads as success.
%
%   ***** UNVERIFIED: THESE TESTS HAVE NEVER BEEN EXECUTED. *****
%   There is no MATLAB in the environment they were written in. They are written
%   against the pipeline's observed conventions, but "written carefully" is not
%   "run", and this project's own record says a test written from the same
%   premise as the code cannot catch the code. Treat the first CI run as the
%   first real evidence.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJClockAlignment');

tests = functiontests(localfunctions);
end

% ===================== fixtures (from the WRITER) ==========================

function v1 = syncruleFixture(kind)
%SYNCRULEFIXTURE A did_v1 syncrule as one of the four rule classes writes it.
%   syncrule.m:183-187 -- ndi.document('syncrule', 'syncrule.ndi_syncrule_class',
%   class(obj), 'base.id', obj.id(), 'base.session_id', ndi.session.empty_id(),
%   'syncrule.parameters', obj.parameters). Note the session id: a syncrule
%   carries the '0000000000000000_0000000000000000' sentinel, NOT a session.
switch kind
    case 'ctoe'
        implClass = 'ndi.time.syncrule.commonTriggersOverlappingEpochs';
        params = struct('daqsystem1_name', 'vhtaste_sync', ...
            'daqsystem2_name', 'vhtaste_bpod', ...
            'daqsystem_ch1', 'dep1', 'daqsystem_ch2', 'mk1', ...
            'epochclocktype', 'dev_local_time', ...
            'minEmbeddedFileOverlap', 1, 'errorOnFailure', true);
    case 'randomPulses'
        implClass = 'ndi.time.syncrule.randomPulses';
        params = struct('daqsystem1_name', 'daq1', 'daqsystem2_name', 'daq2', ...
            'daqsystem_ch1', 'dep1', 'daqsystem_ch2', 'mk1', ...
            'epochclocktype', 'dev_local_time', 'errorOnFailure', true);
    case 'filefind'
        implClass = 'ndi.time.syncrule.filefind';
        params = struct('number_fullpath_matches', 1, ...
            'syncfilename', 'syncfile.txt', ...
            'daqsystem1', 'mydaq1', 'daqsystem2', 'mydaq2');
    case 'filematch'
        implClass = 'ndi.time.syncrule.filematch';
        params = struct('number_fullpath_matches', 2);
    otherwise
        error('unknown fixture kind %s', kind);
end
v1 = struct();
v1.document_class = struct('class_name', 'syncrule', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});   % the template declares none
v1.base = struct('id', ['rule_' kind], ...
    'session_id', '0000000000000000_0000000000000000', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncrule = struct('ndi_syncrule_class', implClass, 'parameters', params);
end

function v1 = syncgraphFixture(ruleIds, sessionId)
%SYNCGRAPHFIXTURE A did_v1 syncgraph as syncgraph.m:845-851 writes it.
%   base.session_id is the REAL session (obj.session.id()), and each rule is
%   attached with add_dependency_value_n -> syncrule_id_1, syncrule_id_2, ...
if nargin < 2; sessionId = 'sess_0001'; end
v1 = struct();
v1.document_class = struct('class_name', 'syncgraph', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
names = cell(1, numel(ruleIds));
for k = 1:numel(ruleIds)
    names{k} = sprintf('syncrule_id_%d', k);
end
if isempty(names)
    v1.depends_on = struct('name', {}, 'value', {});
else
    v1.depends_on = struct('name', names, 'value', ruleIds);
end
v1.base = struct('id', 'graph_0001', 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncgraph = struct('ndi_syncgraph_class', 'ndi.time.syncgraph');
end

function node = epochNodeFixture(suffix, objectName)
%EPOCHNODEFIXTURE One epochnode, with all seven sub-fields the template declares.
%   `epochprobemap` is a CHAR, not a struct: syncgraph.m:313-314 calls
%   `.serialize()` before writing, and epochprobemap_daqsystem.m:136-143 says
%   "Create a CHARACTER ARRAY representation". The template agrees --
%   `"epochprobemap": ""`. A struct here is what made the old reader look
%   correct while dropping the field on every real document.
node = struct( ...
    'epoch_id',         ['t0000' suffix], ...
    'epoch_session_id', 'sess_0001', ...
    'epochprobemap',    sprintf('name\treference\ttype\ndev%s\t1\tn-trode\n', suffix), ...
    'epoch_clock',      'dev_local_time', ...
    't0_t1',            [0 100 + str2double(suffix)], ...
    'objectname',       objectName, ...
    'objectclass',      'ndi.daq.system.mfdaq');
end

function v1 = mappingFixture(withEpochEdges)
%MAPPINGFIXTURE A did_v1 syncrule_mapping as syncgraph.m:296-320 writes it.
%   `mapping` is documented in syncrule_mapping_schema.json as "[1xN]
%   coefficients of a polynomial, HIGH EXPONENTS FIRST" -- the same order
%   polynomial.value.coefficients declares, which is the one thing that had to
%   be checked before this fold could be a rename.
if nargin < 1; withEpochEdges = false; end
v1 = struct();
v1.document_class = struct('class_name', 'syncrule_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
names  = {'syncgraph_id', 'syncrule_id'};
values = {'graph_0001', 'rule_ctoe'};
if withEpochEdges
    % NOT a did_v1 shape -- this is what #60's epoch pass would stamp, and it is
    % the ONLY thing that opens the conversion branch. See syncrule_mapping.m.
    names  = [names,  {'epoch_id_1', 'epoch_id_2'}];
    values = [values, {'epochdoc_a', 'epochdoc_b'}];
end
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', 'map_0001', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncrule_mapping = struct('cost', 1, 'mapping', [1.0002 -0.5], ...
    'epochnode_a', epochNodeFixture('1', 'vhtaste_sync'), ...
    'epochnode_b', epochNodeFixture('2', 'vhtaste_bpod'));
end

% ===================== syncrule -> clock_alignment_configuration ===========

function testSyncruleFansOutToConfigurationChannelsAndSoftware(testCase)
out = runJ(syncruleFixture('ctoe'));
verifyEqual(testCase, numel(out.migrated), 4);
verifyEmpty(testCase, out.quarantine);
cfg = findClass(testCase, out, 'clock_alignment_configuration');
% base.id PRESERVED -- the signature says so, and syncgraph's syncrule_id_# and
% syncrule_mapping's syncrule_id both resolve through it.
verifyEqual(testCase, cfg.get('base.id'), 'rule_ctoe');
verifyEqual(testCase, cfg.get('document_class.schema_version'), 'V_eta');
verifyEqual(testCase, countClass(out, 'acquisition_channels'), 2);
verifyEqual(testCase, countClass(out, 'software'), 1);
end

function testConfigurationCarriesExactlyTwoAcquisitionChannelEdges(testCase)
% EXACTLY 2 and UNORDERED. The rule is symmetric
% (commonTriggersOverlappingEpochs.m:110-115 accepts the pair in either order
% and normalises afterwards), so the edges are a `_#` family, not from_/to_.
out = runJ(syncruleFixture('ctoe'));
cfg = findClass(testCase, out, 'clock_alignment_configuration');
id1 = depVal(cfg, 'acquisition_channels_1');
id2 = depVal(cfg, 'acquisition_channels_2');
verifyNotEmpty(testCase, id1);
verifyNotEmpty(testCase, id2);
verifyNotEqual(testCase, id1, id2);
verifyEmpty(testCase, depVal(cfg, 'acquisition_channels_3'));
% ...and both point at documents this same fold emitted.
verifyTrue(testCase, ismember(id1, emittedIds(out, 'acquisition_channels')));
verifyTrue(testCase, ismember(id2, emittedIds(out, 'acquisition_channels')));
end

function testChannelSpecDecomposesTheWayNdiParsesIt(testCase)
% 'dep1' -> type 'dep', numbers 1 -- the same split
% commonTriggersOverlappingEpochs.m:369-377 performs, and the device NAME rides
% on base.name because a syncrule stores a name, not a document id.
out = runJ(syncruleFixture('ctoe'));
ch = channelsNamed(testCase, out, 'vhtaste_sync');
block = ch.get('acquisition_channels');
verifyEqual(testCase, numel(block.channels), 1);
verifyEqual(testCase, block.channels(1).type.name, 'dep');
verifyEqual(testCase, block.channels(1).type.node, '');
verifyEqual(testCase, block.channels(1).numbers, 1);
end

function testAcquisitionSystemEdgeIsOmittedNotBlank(testCase)
% The edge is OPTIONAL and cannot be filled by a single-document migrator: the
% source stores a device NAME and must_refer needs a document ID. Emitting it
% blank would add another 100%-empty edge to the census for no gain.
out = runJ(syncruleFixture('ctoe'));
ch = channelsNamed(testCase, out, 'vhtaste_sync');
verifyEmpty(testCase, depVal(ch, 'acquisition_system_id'));
deps = depsOf(ch);
verifyFalse(testCase, any(strcmp({deps.name}, 'acquisition_system_id')));
end

function testDeclaredParametersReplaceTheBag(testCase)
% "parameters GONE. Not a bag -- the union of four closed sets, so all three
% surviving fields are DECLARED and queryable" (repair 4), and errorOnFailure is
% DROPPED (repair 5): throw-or-return-quietly is runtime behaviour.
out = runJ(syncruleFixture('ctoe'));
cfg = findClass(testCase, out, 'clock_alignment_configuration');
block = cfg.get('clock_alignment_configuration');
verifyFalse(testCase, isfield(block, 'parameters'));
verifyFalse(testCase, isfield(block, 'errorOnFailure'));
verifyFalse(testCase, isfield(block, 'error_on_failure'));
verifyEqual(testCase, block.minimum_embedded_file_overlap, 1);
% ontology_term, STAGED with an empty node (#67/#70) -- did_clocktype's own
% value_set carries "node": "" for all four terms.
verifyEqual(testCase, block.clock.name, 'dev_local_time');
verifyEqual(testCase, block.clock.node, '');
end

function testFilefindNamesDevicesWithNoChannels(testCase)
% filefind.m:32 stores daqsystem1/daqsystem2 (the OTHER spelling) and no channel
% strings at all. Both devices still become acquisition_channels documents --
% the device identity is the fact -- with an empty channels list.
out = runJ(syncruleFixture('filefind'));
cfg = findClass(testCase, out, 'clock_alignment_configuration');
verifyNotEmpty(testCase, depVal(cfg, 'acquisition_channels_1'));
verifyNotEmpty(testCase, depVal(cfg, 'acquisition_channels_2'));
ch = channelsNamed(testCase, out, 'mydaq1');
chBlock = ch.get('acquisition_channels');
verifyEmpty(testCase, chBlock.channels);
block = cfg.get('clock_alignment_configuration');
verifyEqual(testCase, block.sync_file_name, 'syncfile.txt');
verifyEqual(testCase, block.minimum_matching_file_paths, 1);
% filefind has no epochclocktype, so `clock` is OMITTED rather than emitted as
% an all-blank ontology_term (the vacuous value silentLoss:322 names).
verifyFalse(testCase, isfield(block, 'clock'));
end

function testFilematchBecomesAChannellessConfiguration(testCase)
% INVERTED 2026-08-18, NOT patched. This was
% `testFilematchPassesThroughRatherThanBreakingCardinality` and asserted a v1
% `syncrule` passthrough with `unconverted_count == 1`. That was written from
% the same premise as the guard it tested -- "a filematch rule has no channels,
% so it cannot be a configuration" -- and TEAM-SIGN-OFF [sync configuration
% amendment 1] retires that premise: `acquisition_channels_#` relaxed to {0,2},
% and a file-based rule becomes a `clock_alignment_configuration` with ZERO
% channels carrying its file criterion. So the assertion is reversed.
%
% filematch's ENTIRE parameter set is number_fullpath_matches (filematch.m:25),
% so the config carries that as `minimum_matching_file_paths`, no channels, and
% the software entity for its rule class.
out = runJ(syncruleFixture('filematch'));
cfg = findClass(testCase, out, 'clock_alignment_configuration');
% base.id PRESERVED, so syncgraph's syncrule_id_# still resolves.
verifyEqual(testCase, cfg.get('base.id'), 'rule_filematch');
% ZERO acquisition_channels -- the whole point of the amendment.
verifyEqual(testCase, countClass(out, 'acquisition_channels'), 0);
verifyEmpty(testCase, depVal(cfg, 'acquisition_channels_1'));
% the file criterion is carried, not bagged.
block = cfg.get('clock_alignment_configuration');
verifyEqual(testCase, block.minimum_matching_file_paths, 2);
% the rule class becomes a software entity, edged from the config.
verifyEqual(testCase, countClass(out, 'software'), 1);
verifyNotEmpty(testCase, depVal(cfg, 'software_id'));
% and it is NO LONGER an unconverted passthrough.
verifyEqual(testCase, out.summary.unconverted_count, 0);
verifyEqual(testCase, countClass(out, 'syncrule'), 0);
end

function testSoftwareCarriesTheImplementationClass(testCase)
% R1: v1's `ndi_syncrule_class` is the only thing on the document that says WHICH
% strategy this is. Dropping it without a software entity would lose it.
out = runJ(syncruleFixture('randomPulses'));
sw = findClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('software.name'), 'ndi.time.syncrule.randomPulses');
cfg = findClass(testCase, out, 'clock_alignment_configuration');
verifyEqual(testCase, depVal(cfg, 'software_id'), sw.get('base.id'));
end

% ===================== syncgraph -> clock_alignment_policy =================

function testSyncgraphPassesThroughUntilTheSessionDocumentResolves(testCase)
% INVERTED 2026-08-10 BY A CORPUS RUN. This asserted
% `depVal(policy,'session_id') == 'sess_0001'` -- and that assertion WAS THE
% DEFECT. `clock_alignment_policy.session_id` is
% `must_refer_to_document_class: session`, so it must name a session DOCUMENT's
% `base.id`; `base.session_id` is a different id space entirely
% (ndi.document.m:57 mints base.id from a fresh ido; ndi.session.m:215 sets
% base.session_id separately). The edge therefore dangled every time.
%
% MEASURED, corpus run 31438980133 (20211116): 1 orphan of 2814 edges, and the
% corpus holds exactly one syncgraph -- 100% of the class. The orphan gate is
% the reason this was caught at all: it is the one instrument that resolves
% edges against the real migrated set, which no unit fixture does.
%
% This test could never have caught it, because the fixture and the migrator
% shared the premise. That is the recorded lesson arriving through the DATA
% this time rather than through the code.
out = runJ(syncgraphFixture({'rule_a', 'rule_b', 'rule_c'}));
verifyEqual(testCase, numel(out.migrated), 1, ...
    'a did_v1 syncgraph must pass through -- no session document can be resolved in pass 1');
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'syncgraph');
verifyEqual(testCase, out.migrated{1}.get('base.id'), 'graph_0001', ...
    'base.id must survive, or syncrule_mapping.syncgraph_id and the live NDI query break');
end

function testSyncgraphFoldsWhenTheSessionResolves(testCase)
% THE DEAD BRANCH, driven deliberately. jSessionDocId answers '' for every
% did_v1 document, so this shape cannot occur today -- it occurs the moment a
% batch pass stamps `session_document_id` onto the body, exactly as
% jEpochDocId un-gates syncrule_mapping's fold.
%
% Keeping it alive is the point: when that wiring lands, the fold is already
% tested, and every assertion the old test made about MEMBERSHIP still holds.
v1 = syncgraphFixture({'rule_a', 'rule_b', 'rule_c'});
v1.depends_on(end+1) = struct('name', 'session_document_id', 'value', 'sessdoc_1');
out = runJ(v1);
policy = findClass(testCase, out, 'clock_alignment_policy');
verifyEqual(testCase, policy.get('base.id'), 'graph_0001');
verifyEqual(testCase, depVal(policy, 'session_id'), 'sessdoc_1', ...
    'the edge must name the session DOCUMENT, never base.session_id');
verifyEqual(testCase, depVal(policy, 'clock_alignment_configuration_1'), 'rule_a');
verifyEqual(testCase, depVal(policy, 'clock_alignment_configuration_2'), 'rule_b');
verifyEqual(testCase, depVal(policy, 'clock_alignment_configuration_3'), 'rule_c');
% the v1 edge name must not survive alongside the new one
verifyEmpty(testCase, depVal(policy, 'syncrule_id_1'));
end

function testRuleLessGraphEmitsNoConfigurationEdgeAtAll(testCase)
% Repair 3: syncrule_id_# was never invented -- V_eta TIGHTENED NDI's
% "mustbenotempty": 0 into a requirement. A rule-less graph is LEGAL, so the
% family is min_count 0 and the migrator emits ZERO edges, not one blank one.
%
% Driven through the resolved branch (see above) because that is the only
% branch that emits a policy at all.
v1 = syncgraphFixture({});
v1.depends_on(end+1) = struct('name', 'session_document_id', 'value', 'sessdoc_1');
out = runJ(v1);
policy = findClass(testCase, out, 'clock_alignment_policy');
deps = depsOf(policy);
verifyFalse(testCase, any(startsWith({deps.name}, 'clock_alignment_configuration_')));
verifyEqual(testCase, depVal(policy, 'session_id'), 'sessdoc_1');
end

function testGraphWithTheEmptySessionSentinelPassesThrough(testCase)
% ndi.session.empty_id() is '0000000000000000_0000000000000000' -- "no specific
% session". Pointing a REQUIRED edge at a document that by construction does not
% exist is an orphan, not a fact, so the document passes through instead.
out = runJ(syncgraphFixture({'rule_a'}, '0000000000000000_0000000000000000'));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'syncgraph');
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testPolicyNeverEmitsABlankRequiredSessionEdge(testCase)
% The whole point of the guard. Whichever branch is taken, there is no
% session_id edge that is present and empty -- the defect that put 5,316
% syncrule_mapping documents into the census while validating clean.
for sessionId = {'sess_0001', '0000000000000000_0000000000000000', ''}
    out = runJ(syncgraphFixture({'rule_a'}, sessionId{1}));
    for k = 1:numel(out.migrated)
        deps = depsOf(out.migrated{k});
        for d = 1:numel(deps)
            if strcmp(deps(d).name, 'session_id')
                verifyNotEmpty(testCase, depVal(out.migrated{k}, 'session_id'));
            end
        end
    end
end
end

% ===================== syncrule_mapping: the CLOSED gate ==================

function testMappingPassesThroughBecauseNoEpochDocumentExists(testCase)
% THE DEFAULT PATH FOR EVERY did_v1 DOCUMENT. relative_reference.relative_to is
% REQUIRED and the only honest referent is an `epoch` document; no migrator
% mints one (#60). So the document keeps its own class and its own fields.
out = runJ(mappingFixture(false));
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'syncrule_mapping');
verifyEqual(testCase, doc.get('base.id'), 'map_0001');
verifyEqual(testCase, doc.get('syncrule_mapping.mapping'), [1.0002 -0.5]);
end

function testPassthroughKeepsEverythingTheLiveNdiQueryReads(testCase)
% syncgraph.m:404-408 finds a session's saved rules with
%   ndi.query('','isa','syncrule_mapping') &
%   ndi.query('','depends_on','syncgraph_id', syncgraph.id()) &
%   ( ...epochnode_a.objectname exact_string dq.name |
%     ...epochnode_b.objectname exact_string dq.name )
% and commonTriggersOverlappingEpochs.m:156-160 reads .epoch_id as well. All
% four facts must survive migration or the rule recomputes from raw device files.
out = runJ(mappingFixture(false));
doc = out.migrated{1};
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_a.objectname'), 'vhtaste_sync');
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_b.objectname'), 'vhtaste_bpod');
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_a.time_reference.epoch_id'), 't00001');
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_a.t0_t1'), [0 101]);
verifyEqual(testCase, depVal(doc, 'syncgraph_id'), 'graph_0001');
verifyEqual(testCase, depVal(doc, 'syncrule_id'), 'rule_ctoe');
% the invented required edge stays REMOVED
verifyEmpty(testCase, depVal(doc, 'epochid'));

% epoch_clock -- THE SEVENTH WRITER FIELD, AND THE ONLY ONE NOTHING PINNED.
% The writer's field list is closed and is seven long:
%   syncgraph.m:253
%     epoch_node_fields = {'epoch_id','epoch_session_id','epochprobemap',
%                          'epoch_clock','t0_t1','objectname','objectclass'};
% Six of the seven were asserted across this test and the probe-map one;
% `epoch_clock` was asserted by neither, and it is the ONE field this branch
% RE-NESTS -- v1 stores it flat at `epochnode_a.epoch_clock`,
% reshapeEpochNode moves it under `time_reference`. Live NDI reads it at four
% sites: syncgraph.m:274-277 (the saved-rule match, which skips the document
% and RE-DERIVES the mapping from raw device files when the strcmp fails) and
% syncgraph.m:926,932 (the ingested-graph rebuild). A silent relocation here is
% the #58 failure exactly -- a field dropped on every real document with the
% suite green -- so it is pinned on BOTH endpoints.
verifyEqual(testCase, ...
    doc.get('syncrule_mapping.epochnode_a.time_reference.epoch_clock'), 'dev_local_time');
verifyEqual(testCase, ...
    doc.get('syncrule_mapping.epochnode_b.time_reference.epoch_clock'), 'dev_local_time');
% ...and the b-side epoch_id, which was a-side only. Both endpoints are read:
% commonTriggersOverlappingEpochs.m:156-157 ANDs epochnode_a.epoch_id with
% epochnode_b.epoch_id, and syncgraph.m:268,271 does the same.
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_b.time_reference.epoch_id'), 't00002');
end

function testPassthroughNoLongerDropsTheSerialisedProbeMap(testCase)
% The third field #58 missed. epochprobemap arrives as a CHAR (syncgraph.m:313
% serialises it; the template's default is ""), and the reader required
% isstruct, so it returned an empty struct on every real document. Nothing
% caught it because the unit fixture used a struct, which no writer produces.
out = runJ(mappingFixture(false));
doc = out.migrated{1};
pm = doc.get('syncrule_mapping.epochnode_a.epochprobemap');
verifyClass(testCase, pm, 'char');
verifyTrue(testCase, contains(pm, 'dev1'));
verifyTrue(testCase, contains( ...
    doc.get('syncrule_mapping.epochnode_b.epochprobemap'), 'dev2'));
% objectclass was already carried; assert it so the six-field node stays six.
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_a.objectclass'), ...
    'ndi.daq.system.mfdaq');
verifyEqual(testCase, doc.get('syncrule_mapping.epochnode_a.epoch_session_id'), ...
    'sess_0001');
end

function testTheSyncgraphEdgeStillResolvesAfterTheGraphConverts(testCase)
% The half of the live query that is NOT a field read. The syncgraph document
% becomes a clock_alignment_policy, but base.id is preserved, and must_refer is
% DECLARATIVE (existence-only), so the passed-through mapping's syncgraph_id
% still lands on the migrated document.
% The graph is driven through the RESOLVED branch: without a
% `session_document_id` stamp it passes through as `syncgraph` and there is no
% policy to find. The assertion below is about base.id surviving the FOLD, so
% the fold is the branch worth exercising -- and base.id is preserved on the
% passthrough branch too, which testSyncgraphPassesThroughUntilTheSession...
% pins separately.
graph = syncgraphFixture({'rule_ctoe'});
graph.depends_on(end+1) = struct('name', 'session_document_id', 'value', 'sessdoc_1');
out = did2.convert.v1_to_v2({graph, mappingFixture(false)}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
policy = findClass(testCase, out, 'clock_alignment_policy');
mapping = findClass(testCase, out, 'syncrule_mapping');
verifyEqual(testCase, depVal(mapping, 'syncgraph_id'), policy.get('base.id'));
end

% ===================== syncrule_mapping: the OPEN gate ====================

function testMappingConvertsWhenBothEndpointsHaveAnEpochDocument(testCase)
out = runJ(mappingFixture(true));
verifyEqual(testCase, numel(out.migrated), 3);
align = findClass(testCase, out, 'clock_alignment');
verifyEqual(testCase, align.get('base.id'), 'map_0001');       % PRESERVED
verifyEqual(testCase, countClass(out, 'relative_reference'), 2);
end

function testPolynomialKeepsTheSourceOrderAndChecksItsDegree(testCase)
% syncrule_mapping_schema.json: "[1xN] coefficients of a polynomial, high
% exponents first". polynomial.json: "HIGHEST ORDER FIRST". Same convention, so
% this is a rename -- nothing is reversed. {slope, intercept} would have been
% LOSSY (ndi.time.timemapping is a polynomial by its own docstring).
out = runJ(mappingFixture(true));
align = findClass(testCase, out, 'clock_alignment');
coeffs = align.get('polynomial.value.coefficients');
verifyEqual(testCase, coeffs, [1.0002 -0.5]);
verifyEqual(testCase, align.get('polynomial.value.degree'), numel(coeffs) - 1);
verifyEqual(testCase, align.get('clock_alignment.cost'), 1);
% STAGED with an empty node (gate 2): "temporally aligned with" is a MAPPING
% predicate, not an OWL-Time interval relation, so it cannot reuse
% relative_reference's binding and needs an NDIC term (#67 / #70).
rel = align.get('clock_alignment.relation');
verifyEqual(testCase, rel.name, 'temporally aligned with');
verifyEqual(testCase, rel.node, '');
end

function testAllFourRequiredEdgesAreFilled(testCase)
out = runJ(mappingFixture(true));
align = findClass(testCase, out, 'clock_alignment');
for name = {'from_reference', 'to_reference', ...
        'clock_alignment_configuration_id', 'clock_alignment_policy_id'}
    verifyNotEmpty(testCase, depVal(align, name{1}), ...
        sprintf('required edge %s is empty', name{1}));
end
% syncgraph_id RESTORED as the policy edge; syncrule_id as the configuration
% edge. Both target documents preserve base.id, so both resolve.
verifyEqual(testCase, depVal(align, 'clock_alignment_policy_id'), 'graph_0001');
verifyEqual(testCase, depVal(align, 'clock_alignment_configuration_id'), 'rule_ctoe');
end

function testEndpointsBecomeDirectedReferencesThatKeepObjectname(testCase)
% The rule is symmetric but its OUTPUT is directed (apply() returns its mapping
% only after fixing which system is 1), hence named endpoints rather than a
% `_#` family. objectname rides on base.name: it is string-matched at eight live
% NDI sites and is otherwise recoverable ONLY via epoch.instrument_id, which the
% epoch pass does not carry yet.
out = runJ(mappingFixture(true));
align = findClass(testCase, out, 'clock_alignment');
fromRef = docWithId(testCase, out, depVal(align, 'from_reference'));
toRef   = docWithId(testCase, out, depVal(align, 'to_reference'));
verifyEqual(testCase, fromRef.get('document_class.class_name'), 'relative_reference');
verifyEqual(testCase, fromRef.get('base.name'), 'vhtaste_sync');
verifyEqual(testCase, toRef.get('base.name'), 'vhtaste_bpod');
verifyEqual(testCase, depVal(fromRef, 'relative_to'), 'epochdoc_a');
verifyEqual(testCase, depVal(toRef, 'relative_to'), 'epochdoc_b');
val = fromRef.get('relative_reference.value');
verifyEqual(testCase, val.clock.name, 'dev_local_time');
verifyEqual(testCase, val.start.seconds, 0);
% INVERTED for #65 increment 2 (CHANGE 1): `value.end` no longer exists on
% relative_reference -- the extent is `value.duration` = t1 - t0. The endpoint
% still runs 0 .. 101 s; `end` stays exactly recoverable as start + duration.
verifyFalse(testCase, isfield(val, 'end'));
verifyEqual(testCase, val.duration.seconds, 101);
verifyEqual(testCase, val.start.source_unit, 's');
end

function testNoTimeClockYieldsNoConversionAtAll(testCase)
% NO TIMES => NO REFERENCE. A reference whose extent is NaN is a hollow
% document; rather than emit one, the migrator falls back to the passthrough,
% which preserves strictly more than the converted form would have.
v1 = mappingFixture(true);
v1.syncrule_mapping.epochnode_a.epoch_clock = 'no_time';
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'syncrule_mapping');
end

function testNonFiniteExtentYieldsNoConversionAtAll(testCase)
% ndi.daq.reader.mfdaq/t0_t1's own docstring: "The abstract class always returns
% {[NaN NaN]}". Real, reachable, and not a reference.
v1 = mappingFixture(true);
v1.syncrule_mapping.epochnode_b.t0_t1 = [NaN NaN];
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'syncrule_mapping');
end

% ===================== the counters =======================================

function testTheClusterHasNoOrphanEdges(testCase)
% The gate that actually matters on a corpus. The referents that migrate in
% their own right -- the session, and the epoch documents #60 will mint -- are
% supplied as KnownIds; everything else must resolve INSIDE the batch.
out = did2.convert.v1_to_v2( ...
    {syncruleFixture('ctoe'), syncgraphFixture({'rule_ctoe'}), mappingFixture(true)}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
report = did2.validate.references(out.migrated, 'KnownIds', ...
    {'sess_0001', 'epochdoc_a', 'epochdoc_b'});
% DENOMINATOR FIRST: an orphan count means nothing without the edges inspected.
verifyGreaterThanOrEqual(testCase, report.edges_examined, 10);
if report.orphan_count > 0
    verifyFail(testCase, sprintf('%d orphan edge(s), first: %s.%s -> %s', ...
        report.orphan_count, report.orphans(1).doc_class, ...
        report.orphans(1).edge_name, report.orphans(1).edge_document_id));
end
end

function testEdgeFamilyCardinalityIsSatisfied(testCase)
% #63: `acquisition_channels_#` declares min_count 2 / max_count 2, and
% silentLoss counts the EDGES PRESENT against that range (countFamily,
% silentLoss.m:243). A converted configuration must carry exactly two.
out = did2.convert.v1_to_v2( ...
    {syncruleFixture('ctoe'), syncgraphFixture({'rule_ctoe'})}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
report = did2.validate.silentLoss(out.migrated);
% DENOMINATOR FIRST -- silentLoss printed zeros for two days while reading
% nothing, so a zero is only evidence once total_docs is non-zero.
verifyEqual(testCase, report.total_docs, numel(out.migrated));
verifyEqual(testCase, report.skipped_docs, 0);
verifyEqual(testCase, report.family_violation_count, 0);
verifyEqual(testCase, report.empty_dependency_count, 0);
verifyEqual(testCase, report.vacuous_field_count, 0);
end

% ===================== validation ==========================================

function testConfigurationAndPolicyValidateAgainstTheRealVEtaSchema(testCase)
% The only tests here that prove the migrators and the schema agree. The others
% would pass just as happily against classes that do not exist. Needs the
% assembled V_eta set on DID_SCHEMA_PATH (stable + draft + deprecated) -- the
% quick gate builds exactly that, and all four target classes are in the DRAFT
% tier, so a stable-only schema path fails here rather than skipping.
graph = syncgraphFixture({'rule_ctoe'});
graph.depends_on(end+1) = struct('name', 'session_document_id', 'value', 'sessdoc_1');
out = did2.convert.v1_to_v2( ...
    {syncruleFixture('ctoe'), syncruleFixture('filematch'), ...
     graph, mappingFixture(false)}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined under validation: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
% 4 (ctoe fold) + 2 (filematch fold: config + software) + 2 (policy + software)
% + 1 (mapping). The filematch rule now FOLDS to a channel-less configuration
% (amendment 1) rather than passing through, so it contributes 2 bodies, not 1,
% and no `syncrule` survives. The graph carries a `session_document_id` stamp so
% the policy branch runs; without it the graph passes through and the count is 8.
verifyEqual(testCase, numel(out.migrated), 9);
verifyEqual(testCase, countClass(out, 'clock_alignment_configuration'), 2);
verifyEqual(testCase, countClass(out, 'clock_alignment_policy'), 1);
verifyEqual(testCase, countClass(out, 'syncrule'), 0);
verifyEqual(testCase, countClass(out, 'syncrule_mapping'), 1);
if isfield(out, 'silent_loss') && isfield(out.silent_loss, 'total_docs')
    verifyEqual(testCase, out.silent_loss.total_docs, 9);
    verifyEqual(testCase, out.silent_loss.skipped_docs, 0);
    verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
    verifyEqual(testCase, out.silent_loss.vacuous_field_count, 0);
    verifyEqual(testCase, out.silent_loss.family_violation_count, 0);
end
end

function testTheAlignmentFoldValidatesWhenTheGateIsOpen(testCase)
% The conversion branch, against the real schema. It is deliberately a SEPARATE
% test from the one above: this fixture carries edges no did_v1 document has, so
% a failure here means "#60's shape does not validate", not "the cluster is
% broken today".
out = did2.convert.v1_to_v2(mappingFixture(true), ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined under validation: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 3);
% RECORDED, NOT ASSERTED AS DESIRABLE: did2.validate.isFragment's signature is
% STRUCTURAL -- every time_reference or relation subclass is "scaffolding" -- and
% `clock_alignment` IS a relation subclass, so a fold consisting of one
% clock_alignment plus two relative_references is counted as a fragment even
% though the polynomial, the degree and the cost are the whole payload. The
% counter is REPORT-ONLY, so nothing breaks; but the census's "fragments 0"
% invariant would stop meaning what it means today the moment #60 opens this
% gate on real data. Flagged for the isFragment owner (#57 follow-up).
verifyEqual(testCase, out.summary.fragment_count, 1);
end

% ===================== helpers =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function deps = depsOf(doc)
%DEPSOF The document's depends_on as a struct array (never empty-indexable).
deps = struct('name', {}, 'value', {});
try
    raw = doc.get('depends_on');
catch
    return;   % did2.document.get THROWS on a missing path
end
if isstruct(raw) && ~isempty(raw)
    for k = 1:numel(raw)
        name = '';
        value = '';
        if isfield(raw(k), 'name'); name = char(raw(k).name); end
        for key = {'document_id', 'value', 'id'}
            f = key{1};
            if isfield(raw(k), f) && ~isempty(raw(k).(f))
                value = char(raw(k).(f));
                break;
            end
        end
        deps(end+1) = struct('name', name, 'value', value); %#ok<AGROW>
    end
end
end

function v = depVal(doc, name)
%DEPVAL Read one edge target. TOLERANT: a raw migrator body spells it `value`,
%   a body that has been through universalRenames spells it `document_id`.
v = '';
deps = depsOf(doc);
for k = 1:numel(deps)
    if strcmp(deps(k).name, name)
        v = deps(k).value;
        return;
    end
end
end

function n = countClass(out, className)
n = 0;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        n = n + 1;
    end
end
end

function ids = emittedIds(out, className)
ids = {};
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        ids{end+1} = out.migrated{k}.get('base.id'); %#ok<AGROW>
    end
end
end

function doc = findClass(testCase, out, className)
doc = [];
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
    if isempty(doc) && strcmp(names{k}, className)
        doc = out.migrated{k};
    end
end
if isempty(doc)
    % assertFail, not verifyFail: verifyFail records the failure and CONTINUES,
    % and the caller would then dereference an empty doc and report a MATLAB
    % error instead of the real one.
    assertFail(testCase, sprintf('no "%s" among {%s}', className, strjoin(names, ', ')));
end
end

function doc = channelsNamed(testCase, out, deviceName)
%CHANNELSNAMED The acquisition_channels document for one device name.
doc = [];
seen = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if ~strcmp(d.get('document_class.class_name'), 'acquisition_channels'); continue; end
    seen{end+1} = d.get('base.name'); %#ok<AGROW>
    if strcmp(seen{end}, deviceName) && isempty(doc)
        doc = d;
    end
end
if isempty(doc)
    assertFail(testCase, sprintf('no acquisition_channels named "%s" among {%s}', ...
        deviceName, strjoin(seen, ', ')));
end
end

function doc = docWithId(testCase, out, id)
doc = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), id)
        doc = out.migrated{k};
        return;
    end
end
assertFail(testCase, sprintf('no migrated document with base.id "%s"', id));
end

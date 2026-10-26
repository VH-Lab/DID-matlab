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
    % and, since [device clocks on one epoch] (Jess Haley, 2026-10-26), the two
    % per-system references epochMint places on the epochs and stamps
    names  = [names,  {'epoch_id_1', 'epoch_id_2', 'time_reference_id_1', 'time_reference_id_2'}];
    values = [values, {'epochdoc_a', 'epochdoc_b', 'tref_a', 'tref_b'}];
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
% INVERTED for did-schema #88. A CHANNEL-BASED rule (two named DAQ systems with
% channels) used to fan out to a configuration + two acquisition_channels +
% software. On #88 `acquisition_channels` names the system its channels are on
% only by an `acquisition_system_id` EDGE, while the v1 rule names its systems by
% NAME; resolving a name to the system's id needs the batch, and the pre-#73
% shape carried the name on base.name, which V_eta no longer writes. Folding
% here would drop which device each channel group is on, so the rule passes
% through unchanged (Jess's rule: pass through and list, never invent) and the
% resolution is an NDI second-pass need, listed in the port report.
out = runJ(syncruleFixture('ctoe'));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'syncrule');
verifyEqual(testCase, doc.get('base.id'), 'rule_ctoe');
verifyEqual(testCase, out.summary.unconverted_by_class.syncrule, 1);
verifyEqual(testCase, countClass(out, 'acquisition_channels'), 0);
verifyEqual(testCase, countClass(out, 'clock_alignment_configuration'), 0);
end


function testConfigurationCarriesExactlyTwoAcquisitionChannelEdges(testCase)
% UPDATED for #88 (channel-based rules pass through, see above): the passthrough
% keeps BOTH device names and BOTH channel specs verbatim, so the second pass
% has everything the fold would have needed.
out = runJ(syncruleFixture('ctoe'));
p = out.migrated{1}.get('syncrule.parameters');
verifyEqual(testCase, p.daqsystem1_name, 'vhtaste_sync');
verifyEqual(testCase, p.daqsystem2_name, 'vhtaste_bpod');
verifyEqual(testCase, p.daqsystem_ch1, 'dep1');
verifyEqual(testCase, p.daqsystem_ch2, 'mk1');
end


function testChannelSpecDecomposesTheWayNdiParsesIt(testCase)
% UPDATED for #88: a channel-based rule of ANY implementation class passes
% through -- randomPulses as well as commonTriggersOverlappingEpochs -- and
% nothing is emitted half-built (no software, no channels).
out = runJ(syncruleFixture('randomPulses'));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'syncrule');
verifyEqual(testCase, countClass(out, 'software'), 0);
end


function testAcquisitionSystemEdgeIsOmittedNotBlank(testCase)
% No document anywhere in the output carries a blank acquisition_system_id.
% UPDATED for #88: the channel rule passes through, so none is emitted at all.
out = runJ(syncruleFixture('ctoe'));
for k = 1:numel(out.migrated)
    deps = depsOf(out.migrated{k});
    verifyFalse(testCase, any(strcmp({deps.name}, 'acquisition_system_id')));
end
end


function testDeclaredParametersReplaceTheBag(testCase)
% A FILE-BASED rule folds, and its settings are the configuration's inline
% method.parameters (did-schema #88 V_eta_method_plan.md: one method shape);
% the v1 parameter bag is not carried. UPDATED for #88 (was asserted on the
% channel rule, which now passes through).
out = runJ(syncruleFixture('filematch'));
cfg = findClass(testCase, out, 'clock_alignment_configuration');
block = cfg.get('clock_alignment_configuration');
verifyFalse(testCase, isfield(block, 'parameters'));
verifyFalse(testCase, isfield(block, 'errorOnFailure'));
p = block.method.parameters;
verifyEqual(testCase, numel(p), 1);
verifyEqual(testCase, p(1).variable.name, 'minimum matching file paths');
verifyEqual(testCase, p(1).count, 2);
end


function testAnUnreadParameterBecomesAMethodParameter(testCase)
% [small unread settings] (3) (Jess Haley, 2026-10-26): a configuration-arm
% parameter the migrator does not read (errorOnFailure) becomes one more
% method parameter instead of being dropped.
v1 = syncruleFixture('filematch');
v1.syncrule.parameters.errorOnFailure = true;
out = runJ(v1);
cfg = findClass(testCase, out, 'clock_alignment_configuration');
block = cfg.get('clock_alignment_configuration');
p = block.method.parameters;
names = arrayfun(@(e) char(e.variable.name), p, 'UniformOutput', false);
verifyEqual(testCase, numel(p), 2, strjoin(names, ', '));
ix = find(strcmp(names, 'errorOnFailure'));
verifyNumElements(testCase, ix, 1, strjoin(names, ', '));
if isscalar(ix)
    verifyEqual(testCase, p(ix).quantity.value, 1);
end
end

function testAnUnreadParameterThatCannotBeWrittenCarriesTheRuleAsV1(testCase)
% ... and one that cannot be written (a number that is not finite) carries
% the rule whole as v1.
v1 = syncruleFixture('filematch');
v1.syncrule.parameters.someTolerance = NaN;
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'syncrule');
notes = out.summary.migration_notes;
verifyTrue(testCase, isfield(notes, 'carried_as_v1') && ...
    contains(notes.carried_as_v1.distinct_details{1}, 'someTolerance'));
end


function testFilefindNamesDevicesWithNoChannels(testCase)
% filefind names two DAQ systems (with no channels). UPDATED for #88: a rule
% that names its devices passes through for the same reason a channel rule does
% (the system name cannot be turned into an acquisition_system_id here); its
% file criterion stays on the passthrough.
out = runJ(syncruleFixture('filefind'));
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'syncrule');
p = doc.get('syncrule.parameters');
verifyEqual(testCase, p.daqsystem1, 'mydaq1');
verifyEqual(testCase, p.syncfilename, 'syncfile.txt');
verifyEqual(testCase, p.number_fullpath_matches, 1);
end


function testFilematchBecomesAChannellessConfiguration(testCase)
% A filematch rule (no devices, a file criterion) folds to a channel-less
% configuration + its software entity. UPDATED for #88: the criterion is a
% method.parameters entry.
out = runJ(syncruleFixture('filematch'));
cfg = findClass(testCase, out, 'clock_alignment_configuration');
verifyEqual(testCase, cfg.get('base.id'), 'rule_filematch');
verifyEqual(testCase, countClass(out, 'acquisition_channels'), 0);
verifyEmpty(testCase, depVal(cfg, 'acquisition_channels_id'));
p = cfg.get('clock_alignment_configuration.method').parameters;
verifyEqual(testCase, p(1).count, 2);
verifyEqual(testCase, countClass(out, 'software'), 1);
verifyNotEmpty(testCase, depVal(cfg, 'software_id'));
verifyEqual(testCase, out.summary.unconverted_count, 0);
verifyEqual(testCase, countClass(out, 'syncrule'), 0);
end


function testSoftwareCarriesTheImplementationClass(testCase)
% The configuration's software entity is named by the rule's implementation
% class. UPDATED for #88: shown on the folding (file-based) rule.
out = runJ(syncruleFixture('filematch'));
sw = findClass(testCase, out, 'software');
verifyEqual(testCase, sw.get('entity.name'), 'ndi.time.syncrule.filematch');
cfg = findClass(testCase, out, 'clock_alignment_configuration');
verifyEqual(testCase, depVal(cfg, 'software_id'), sw.get('base.id'));
end


% ===================== syncgraph -> clock_alignment_policy =================

function testSyncgraphPassesThroughUntilTheSessionDocumentResolves(testCase)
% INVERTED for did-schema #88. The policy's session edge named the session
% DOCUMENT, which pass 1 could not resolve, so a graph passed through until the
% batch pass stamped it. On #88 the session entity's id IS the session id and
% `session_id` is base.session_id as an edge (V_eta_relation_inheritance_plan),
% so pass 1 has everything it needs and the graph folds immediately, id
% preserved.
out = runJ(syncgraphFixture({'rule_a', 'rule_b', 'rule_c'}));
policy = findClass(testCase, out, 'clock_alignment_policy');
verifyEqual(testCase, policy.get('base.id'), 'graph_0001', ...
    'base.id must survive, or syncrule_mapping.syncgraph_id and the live NDI query break');
verifyEqual(testCase, depVal(policy, 'session_id'), 'sess_0001');
end


function testSyncgraphFoldsWhenTheSessionResolves(testCase)
% UPDATED for #88: the rules are the repeated `clock_alignment_configuration_id`
% edge (one per rule, in order), not a numbered family.
v1 = syncgraphFixture({'rule_a', 'rule_b', 'rule_c'});
v1.depends_on(end+1) = struct('name', 'session_document_id', 'value', 'sessdoc_1');
out = runJ(v1);
policy = findClass(testCase, out, 'clock_alignment_policy');
verifyEqual(testCase, policy.get('base.id'), 'graph_0001');
verifyEqual(testCase, depVal(policy, 'session_id'), ...
    did2.unittest.helpers.sessionDocumentId('sessdoc_1', 'sess_0001'), ...
    'the edge must name the session DOCUMENT, never base.session_id');
verifyEqual(testCase, depVals(policy, 'clock_alignment_configuration_id'), ...
    {'rule_a', 'rule_b', 'rule_c'});
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
verifyEqual(testCase, depVal(policy, 'session_id'), ...
    did2.unittest.helpers.sessionDocumentId('sessdoc_1', 'sess_0001'));
end

function testGraphWithTheEmptySessionSentinelPassesThrough(testCase)
% ndi.session.empty_id() is '0000000000000000_0000000000000000' -- "no specific
% session". Pointing a REQUIRED edge at a document that by construction does not
% exist is an orphan, not a fact, so the document passes through instead.
out = runJ(syncgraphFixture({'rule_a'}, '0000000000000000_0000000000000000'));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'syncgraph');
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
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'syncrule_mapping');
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
% [device clocks on one epoch] (3): the alignment alone -- its ends are the
% per-system references epochMint stamped; the migrator mints none
verifyEqual(testCase, numel(out.migrated), 1);
align = findClass(testCase, out, 'clock_alignment');
verifyEqual(testCase, align.get('base.id'), 'map_0001');       % PRESERVED
verifyEqual(testCase, countClass(out, 'relative_time_reference'), 0);
end

function testPolynomialKeepsTheSourceOrderAndChecksItsDegree(testCase)
out = runJ(mappingFixture(true));
align = findClass(testCase, out, 'clock_alignment');
coeffs = align.get('polynomial.value.coefficients');
verifyEqual(testCase, coeffs, [1.0002 -0.5]);
verifyEqual(testCase, align.get('polynomial.value.degree'), numel(coeffs) - 1);
verifyEqual(testCase, align.get('clock_alignment.cost'), 1);
rel = align.get('clock_alignment.relation');
verifyEqual(testCase, rel.name, 'temporally aligned with');
verifyFalse(testCase, isfield(rel, 'node') && ~isempty(rel.node), ...
    'no CURIE is invented for the relation');
end


function testAllFourRequiredEdgesAreFilled(testCase)
% UPDATED for #88: the endpoints are input_id / output_id.
out = runJ(mappingFixture(true));
align = findClass(testCase, out, 'clock_alignment');
for name = {'input_id', 'output_id', ...
        'clock_alignment_configuration_id', 'clock_alignment_policy_id'}
    verifyNotEmpty(testCase, depVal(align, name{1}), ...
        sprintf('required edge %s is empty', name{1}));
end
verifyEqual(testCase, depVal(align, 'clock_alignment_policy_id'), 'graph_0001');
verifyEqual(testCase, depVal(align, 'clock_alignment_configuration_id'), 'rule_ctoe');
end


function testTheEndsAreThePerSystemReferencesEpochMintStamped(testCase)
% INVERTS testEndpointsBecomeDirectedReferencesThatKeepObjectname, which had the
% migrator mint two references anchored at the epochs. Decided by Jess Haley,
% 2026-10-26 [device clocks on one epoch] (3): "A v1 syncrule_mapping becomes a
% clock_alignment between those two references" -- each system's reference on
% its epoch (referent: the acquisition system), stamped by epochMint
% (testEpochMintSyncruleArming checks objectname / objectclass / epochprobemap).
out = runJ(mappingFixture(true));
align = findClass(testCase, out, 'clock_alignment');
verifyEqual(testCase, depVal(align, 'input_id'), 'tref_a');
verifyEqual(testCase, depVal(align, 'output_id'), 'tref_b');
end

function testWithoutStampedReferencesThereIsNoConversion(testCase)
% REPLACES testNoTimeClockYieldsNoConversionAtAll and
% testNonFiniteExtentYieldsNoConversionAtAll: the endpoint's clock and extent
% are now checked where its system reference is placed (epochMint); a mapping
% that reaches the migrator without the two stamped references is not folded,
% and the passthrough preserves it.
v1 = mappingFixture(true);
keep = ~ismember({v1.depends_on.name}, {'time_reference_id_1', 'time_reference_id_2'});
v1.depends_on = v1.depends_on(keep);
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'syncrule_mapping');
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
    [{'sess_0001', 'epochdoc_a', 'epochdoc_b', 'tref_a', 'tref_b'}, ...
     did2.unittest.helpers.sessionKnownIds(out.migrated)]);
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
% The migrators and the schema agree under validation. UPDATED for #88: the
% channel rule passes through (1 body), the filematch rule folds (config +
% software), the graph folds (policy + software), the mapping passes through:
% 6 documents, 0 quarantined.
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
verifyEqual(testCase, numel(out.migrated), 6);
verifyEqual(testCase, countClass(out, 'clock_alignment_configuration'), 1);
verifyEqual(testCase, countClass(out, 'clock_alignment_policy'), 1);
verifyEqual(testCase, countClass(out, 'syncrule'), 1);
verifyEqual(testCase, countClass(out, 'syncrule_mapping'), 1);
if isfield(out, 'silent_loss') && isfield(out.silent_loss, 'total_docs')
    verifyEqual(testCase, out.silent_loss.total_docs, 6);
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
verifyEqual(testCase, numel(out.migrated), 1);
% (2026-10-26: the fold is the clock_alignment alone; its fragment count is not
% asserted.) RECORDED, NOT ASSERTED AS DESIRABLE: did2.validate.isFragment's signature is
% STRUCTURAL -- every time_reference or relation subclass is "scaffolding" -- and
% `clock_alignment` IS a relation subclass, so a fold consisting of one
% clock_alignment plus two relative_references is counted as a fragment even
% though the polynomial, the degree and the cost are the whole payload. The
% counter is REPORT-ONLY, so nothing breaks; but the census's "fragments 0"
% invariant would stop meaning what it means today the moment #60 opens this
% gate on real data. Flagged for the isFragment owner (#57 follow-up).
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
    if strcmp(did2.unittest.helpers.classKey(out.migrated{k}), className)
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
    names{k} = did2.unittest.helpers.classKey(out.migrated{k});
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

function v = depVals(doc, name)
% every value of a repeated edge, in order
v = {};
deps = depsOf(doc);
for k = 1:numel(deps)
    if strcmp(deps(k).name, name); v{end+1} = deps(k).value; end %#ok<AGROW>
end
end

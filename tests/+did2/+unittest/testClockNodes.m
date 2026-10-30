function tests = testClockNodes
%TESTCLOCKNODES The four clock values are written with their node and compared
%   by node first, then by name.
%
%   Decided by Jess Haley, 2026-10-26 [clock terms get nodes] (did-schema
%   V_eta_go_forward_class_audit.md): the `value.clock` values of
%   relative_time_reference (and clock_alignment_configuration.clock) -- utc,
%   dev_local_time, dev_global_time, exp_global_time -- get nodes:
%   wikidata:Q1536 "UTC", EMPTY:0000403 "device local time", EMPTY:0000404
%   "device global time", EMPTY:0000405 "experiment global time" (did-schema
%   V_eta_term_registry.json). "Build pending: DID-matlab and NDI-matlab
%   (compare clock nodes first), then did-schema (the binding's value names)."
%
%   Both shapes are tested:
%     * TODAY'S SCHEMA, whose binding lists the four with EMPTY nodes and the
%       snake_case names: the builder writes the decided node and the
%       schema's name, and the binding check still admits it (by name);
%     * THE FLIPPED SCHEMA, a scratch copy whose binding lists the nodes and
%       the labels, as did-schema will: the builder writes the node and the
%       label, and every reader still answers the v1 handle.
%   And documents written either way (node or no node) compare as one clock.
%
%   NEVER EXECUTED: written without MATLAB. Run with
%       results = runtests('did2.unittest.testClockNodes');
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping clock node tests');
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
testCase.TestData.schemaPath = did2.schema.cache.shared().schemaPath;
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the table ===========================================

function testTheHandlesHaveTheDecidedNodes(testCase)
want = {'utc', 'wikidata:Q1536'; 'dev_local_time', 'EMPTY:0000403'; ...
    'dev_global_time', 'EMPTY:0000404'; 'exp_global_time', 'EMPTY:0000405'};
for k = 1:size(want, 1)
    verifyEqual(testCase, did2.build.vocabulary('clock', want{k, 1}), want{k, 2}, want{k, 1});
end
% the registry's labels find the same nodes
verifyEqual(testCase, did2.build.vocabulary('clock', 'UTC'), 'wikidata:Q1536');
verifyEqual(testCase, did2.build.vocabulary('clock', 'device local time'), 'EMPTY:0000403');
verifyEqual(testCase, did2.build.vocabulary('clock', 'device global time'), 'EMPTY:0000404');
verifyEqual(testCase, did2.build.vocabulary('clock', 'experiment global time'), 'EMPTY:0000405');
% the clocks the four do not include have no node
for c = {'no_time', 'inherited', 'approx_utc'}
    verifyEqual(testCase, did2.build.vocabulary('clock', c{1}), '', c{1});
end
end

function testTheHandleIsReadByNodeFirst(testCase)
h = @(t) did2.build.vocabularyHandle('clock', t);
% by node, whatever name is beside it
verifyEqual(testCase, h(struct('node', 'EMPTY:0000403', 'name', 'dev_local_time')), 'dev_local_time');
verifyEqual(testCase, h(struct('node', 'EMPTY:0000403', 'name', 'device local time')), 'dev_local_time');
verifyEqual(testCase, h(struct('node', 'empty:0000404', 'name', '')), 'dev_global_time');
verifyEqual(testCase, h(struct('node', 'wikidata:Q1536', 'name', 'UTC')), 'utc');
% a node-less term: by its name, either spelling
verifyEqual(testCase, h(struct('node', '', 'name', 'exp_global_time')), 'exp_global_time');
verifyEqual(testCase, h(struct('node', '', 'name', 'experiment global time')), 'exp_global_time');
verifyEqual(testCase, h('dev_local_time'), 'dev_local_time');
% a clock outside the four answers its name unchanged
verifyEqual(testCase, h(struct('node', '', 'name', 'inherited')), 'inherited');
verifyEqual(testCase, h([]), '');
end

function testIsVocabularyComparesClocksByNode(testCase)
verifyTrue(testCase, did2.build.isVocabulary( ...
    struct('node', 'EMPTY:0000403', 'name', 'device local time'), 'clock', 'dev_local_time'));
verifyTrue(testCase, did2.build.isVocabulary( ...
    struct('node', '', 'name', 'dev_local_time'), 'clock', 'dev_local_time'));
% the node decides even when the name says something else
verifyFalse(testCase, did2.build.isVocabulary( ...
    struct('node', 'EMPTY:0000405', 'name', 'dev_local_time'), 'clock', 'dev_local_time'));
end

% ===================== writers, on today's schema ==========================

function testTheBuilderWritesTheNodeWithTheSchemasName(testCase)
c = did2.schema.cache.shared();
names = boundClockNames(c, 'relative_time_reference');
if isempty(names)
    assumeFail(testCase, 'the loaded schema binds relative_time_reference.value.clock to no values');
end
ref = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'dev_local_time', ...
    'Start', 0, 'SessionId', testCase.TestData.sid);
clk = ref.relative_time_reference.value.clock;
verifyEqual(testCase, clk.node, 'EMPTY:0000403');
% the name is the one the schema lists for that clock: 'dev_local_time'
% while the binding's nodes are empty, the label once they are filled
verifyTrue(testCase, any(strcmp(clk.name, names)), ...
    sprintf('"%s" is not a name the schema binds', clk.name));
verifyEqual(testCase, did2.build.vocabularyHandle('clock', clk), 'dev_local_time');
utc = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'utc', ...
    'Start', 0, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, utc.relative_time_reference.value.clock.node, 'wikidata:Q1536');
end

function testTheWrittenNodePassesTheBindingCheckOnTodaysSchema(testCase)
% The binding check admits a value whose node is in no member when its name
% is (did2.schema.cache, bindingValueNotInSet), so writing the node cannot be
% refused while the schema still lists empty nodes.
prev = did2.schema.cache.strictMode('BindingConformance', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('BindingConformance', prev));
for c = {'utc', 'dev_local_time', 'dev_global_time', 'exp_global_time'}
    ref = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', c{1}, ...
        'Relation', 'intervalDuring', ...   % value.relation is bound `required` too
        'Start', 0, 'SessionId', testCase.TestData.sid, 'Validate', true);
    verifyNotEmpty(testCase, ref.relative_time_reference.value.clock.node, c{1});
end
end

function testAClockAlignmentConfigurationWritesTheNode(testCase)
c = did2.schema.cache.shared();
if ~c.hasClass('clock_alignment_configuration')
    assumeFail(testCase, 'the loaded schema has no clock_alignment_configuration');
end
cfg = did2.build.document('clock_alignment_configuration', ...
    struct('clock', 'exp_global_time'), 'SessionId', testCase.TestData.sid, 'Validate', false);
verifyEqual(testCase, cfg.clock_alignment_configuration.clock.node, 'EMPTY:0000405');
verifyEqual(testCase, did2.build.vocabularyHandle('clock', cfg.clock_alignment_configuration.clock), ...
    'exp_global_time');
end

% ===================== writers and readers, after the flip =================

function testAfterTheFlipTheBuilderWritesTheLabel(testCase)
flipClocks(testCase);
ref = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'dev_local_time', ...
    'Start', 0, 'SessionId', testCase.TestData.sid, 'Validate', false);
clk = ref.relative_time_reference.value.clock;
verifyEqual(testCase, clk.node, 'EMPTY:0000403');
verifyEqual(testCase, clk.name, 'device local time');
verifyEqual(testCase, did2.build.vocabularyHandle('clock', clk), 'dev_local_time');
% a writer that already gives the node also gets the label
ref = did2.build.relativeTimeReference(did.ido.unique_id(), ...
    'Clock', struct('node', 'wikidata:Q1536', 'name', 'utc'), ...
    'Start', 0, 'SessionId', testCase.TestData.sid, 'Validate', false);
verifyEqual(testCase, ref.relative_time_reference.value.clock.name, 'UTC');
end

function testAfterTheFlipBothShapesPassTheBindingCheck(testCase)
flipClocks(testCase);
prev = did2.schema.cache.strictMode('BindingConformance', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('BindingConformance', prev));
ref = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'exp_global_time', ...
    'Relation', 'intervalDuring', ...   % value.relation is bound `required` too
    'Start', 0, 'SessionId', testCase.TestData.sid, 'Validate', true);
verifyEqual(testCase, ref.relative_time_reference.value.clock.node, 'EMPTY:0000405');
end

% ===================== the census: one clock, two shapes ===================

function testANodeAndANodelessMemberAreOneClock(testCase)
% The mixed family silentLoss's header warned about: one member written with
% the node, one without. They are the same clock and must collide.
docs = epochWithClocks({struct('node', 'EMPTY:0000403', 'name', 'dev_local_time'), ...
    struct('node', '', 'name', 'dev_local_time')});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.uniqueness_denominator.members_keyed_by_node, 1);
verifyEqual(testCase, rep.uniqueness_denominator.members_keyed_by_name, 1, ...
    'the denominator still says what the document stored');
verifyEqual(testCase, rep.family_uniqueness_violation_count, 1);
end

function testALabelAndAHandleAreOneClock(testCase)
docs = epochWithClocks({struct('node', '', 'name', 'device global time'), ...
    struct('node', '', 'name', 'dev_global_time')});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 1);
end

function testTwoClocksStayTwoInEitherShape(testCase)
docs = epochWithClocks({struct('node', 'EMPTY:0000403', 'name', 'dev_local_time'), ...
    struct('node', '', 'name', 'utc')});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0);
end

% ===================== helpers =============================================

function flipClocks(testCase)
% load a copy of the schema whose clock bindings list the decided nodes and
% the registry's labels, as did-schema will after this repository
src = testCase.TestData.schemaPath;
tmp = tempname;
mkdir(tmp);
did2.schema.cache.copySchemaSet(src, tmp);   % any layout ([schema folders by family])
testCase.addTeardown(@() rmdir(tmp, 's'));
flip = {'utc', 'wikidata:Q1536', 'UTC'; ...
    'dev_local_time', 'EMPTY:0000403', 'device local time'; ...
    'dev_global_time', 'EMPTY:0000404', 'device global time'; ...
    'exp_global_time', 'EMPTY:0000405', 'experiment global time'};
for f = {'relative_time_reference.json', 'clock_alignment_configuration.json'}
    p = fullfile(tmp, f{1});
    if ~isfile(p); continue; end
    txt = fileread(p);
    for k = 1:size(flip, 1)
        txt = regexprep(txt, ['"node"\s*:\s*""\s*,\s*"name"\s*:\s*"' flip{k, 1} '"'], ...
            ['"node": "' flip{k, 2} '", "name": "' flip{k, 3} '"']);
    end
    fid = fopen(p, 'w'); fwrite(fid, txt); fclose(fid);
end
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
names = boundClockNames(did2.schema.cache.shared(), 'relative_time_reference');
if ~any(strcmp(names, 'device local time'))
    assumeFail(testCase, 'the flipped copy lists no "device local time"; this test proves nothing');
end
end

function names = boundClockNames(c, className)
% the names relative_time_reference.value.clock's binding lists
names = {};
if ~c.hasClass(className); return; end
f = c.getClass(className).fields;
if isstruct(f); f = num2cell(f); end
v = f(cellfun(@(d) strcmp(char(d.name), 'value'), f));
if isempty(v) || ~isfield(v{1}, 'fields'); return; end
s = v{1}.fields;
if isstruct(s); s = num2cell(s); end
k = s(cellfun(@(d) strcmp(char(d.name), 'clock'), s));
if isempty(k); return; end
vals = k{1}.constraints.binding.values;
if isstruct(vals); vals = num2cell(vals); end
names = cellfun(@(m) char(m.name), vals, 'UniformOutput', false);
end

function docs = epochWithClocks(clocks)
% an epoch entity and one relative_time_reference per clock term, wired as
% repeated `time_reference_id` edges (the shape testFamilyUniqueness uses)
refs = {};
epochBody = bodyOf('entity', 'ep_1');
epochBody.entity = struct('type', struct('node', '', 'name', 'epoch'), 'local_identifier', 'ep_1');
deps = struct('name', {}, 'value', {});
for k = 1:numel(clocks)
    refId = sprintf('ref_%d', k);
    r = bodyOf('relative_time_reference', refId);
    r.document_class.superclasses = struct('class_name', {'time_reference'}, ...
        'class_version', {'4.0.0'});
    r.depends_on = struct('name', {'referent_id'}, 'value', {'ep_1'});
    r.relative_time_reference = struct('value', struct( ...
        'clock', clocks{k}, ...
        'start', struct('seconds', 0), ...
        'duration', struct('seconds', 10)));
    refs{end+1} = r; %#ok<AGROW>
    deps(end+1) = struct('name', 'time_reference_id', 'value', refId); %#ok<AGROW>
end
epochBody.depends_on = deps;
docs = {did2.document(epochBody)};
for k = 1:numel(refs)
    docs{end+1} = did2.document(refs{k}); %#ok<AGROW>
end
end

function b = bodyOf(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'did_v2');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end

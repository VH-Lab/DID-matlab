function tests = testBindingConformance
%TESTBINDINGCONFORMANCE Open item #32 (T8): make `constraints.binding` a rule
%   the validator READS, instead of a comment written in JSON.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment these tests
%   were written in, so every assertion below is UNVERIFIED. Read them as a
%   specification of intended behaviour, not as a passing suite. Run
%       results = runtests('did2.unittest.testBindingConformance');
%   before trusting any of it. The same sentence heads
%   testEnforceNonVacuousFields, and it was true there too.
%
%   WHAT WAS BROKEN
%   ---------------
%   did2.schema.cache/validateConstraints handled maxLength, minLength,
%   minimum, maximum and enum, and dropped every other key into `otherwise`.
%   `binding` -- the whole of T8's controlled-vocabulary story, carried on 14
%   V_eta fields -- fell into `otherwise`. A binding could name an admissible
%   set of four members and a document could carry a fifth, and nothing
%   anywhere would notice.
%
%   WHAT IS ENFORCED, AND WHAT IS NOT
%   ---------------------------------
%   Only what a binding STATES and a validator can check with NO ontology
%   loaded:
%     values     an inline admissible set enumerated on the field
%     node_form  `curie`: the value's `node` must look like `prefix:local`
%   MEMBERSHIP IN AN ONTOLOGY IS OUT OF SCOPE and is not tested below, because
%   it is not implemented: the admissible set for `variable` lives in NDIC.txt,
%   which moved to VH-Lab/ndi-ontology-matlab (commit 2c19bf24c). A binding
%   whose only content is `keyed_by` or `term_set` therefore rejects NOTHING,
%   and testABindingWithNothingBehindItRejectsNothing pins that so it cannot
%   quietly start rejecting on a half-built lookup.
%
%   DISARMED BY DEFAULT, and the first test asserts the default rather than
%   assuming it. That is the opposite of the two switches next door, on
%   purpose: #37 and #38 were armed against MEASURED costs (7,233 and 0), and
%   this one has no measurement at all -- nothing has ever read `binding`, so
%   the corpus being green on 627,526 documents says nothing about this rule.
%
%   Run with:
%       results = runtests('did2.unittest.testBindingConformance');

tests = functiontests(localfunctions);
end

% ===================== fixtures ============================================

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
testCase.TestData.fixtureDir = fixtureDir;
testCase.TestData.schemaDir = bindingFixtureDir(fixtureDir);
did2.schema.cache.setSchemaPath(testCase.TestData.schemaDir);
testCase.TestData.cache = did2.schema.cache.shared();
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
did2.schema.cache.strictMode('-reset');
end

function setup(testCase)
testCase.TestData.prior = did2.schema.cache.strictMode('BindingConformance');
end

function teardown(testCase)
did2.schema.cache.strictMode('BindingConformance', testCase.TestData.prior);
end

% ===================== the default ==========================================

function testBindingConformanceIsDISARMEDByDefault(testCase)
% The most important test in the file. A new gate arriving silently on a
% 600,000-document corpus is the failure this project has already paid for
% (2,484 corpus-B quarantines from a schema half that landed ahead of its
% migrator). If someone flips the default, this fails and says so.
did2.schema.cache.strictMode('-reset');
verifyFalse(testCase, did2.schema.cache.strictMode('BindingConformance'), ...
    'BindingConformance must be DISARMED after a reset -- the default is off');

doc = blankOf(testCase, 'demoBoundSet');
doc = doc.set('demoBoundSet.clock', struct('node', '', 'name', 'not_a_member'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, ...
    'with the default default, an out-of-set value must still pass');
end

function testTheSwitchCanBeArmedDeliberately(testCase)
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundSet');
doc = doc.set('demoBoundSet.clock', struct('node', '', 'name', 'not_a_member'));
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:bindingValueNotInSet');
end

% ===================== the inline admissible set ============================

function testAMemberOfTheSetPasses(testCase)
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundSet');
doc = doc.set('demoBoundSet.clock', struct('node', '', 'name', 'dev_local_time'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'a declared member must pass');
end

function testMembershipMatchesOnTheNodeToo(testCase)
% A NodeRef member is matched on EITHER slot. Matching only on `name` would
% make a document that carries the right CURIE and a different label
% (`UBERON:0000955` / `brain region`) fail for saying the same thing in the
% more precise way -- rejecting the better data is worse than rejecting none.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundNodes');
doc = doc.set('demoBoundNodes.term', struct('node', 'PATO:0000384', 'name', ''));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'a member matched by node must pass');
end

function testBareStringMembersAreReadAsNames(testCase)
% BOTH member shapes occur in V_eta: `epoch_clock` enumerates bare strings,
% the two clock fields enumerate {node, name} NodeRefs.
% check_binding_governance.py B4 counts three fields where the shape and the
% field type disagree, so a reader that assumed one shape would silently
% accept every value of the other.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundChar');
doc = doc.set('demoBoundChar.clock', 'utc');
doc.validate('SchemaCache', testCase.TestData.cache);

bad = blankOf(testCase, 'demoBoundChar');
bad = bad.set('demoBoundChar.clock', 'martian_time');
verifyError(testCase, @() bad.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:bindingValueNotInSet');
end

% ===================== node_form: curie =====================================

function testAWellFormedCuriePasses(testCase)
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundCurie');
doc = doc.set('demoBoundCurie.variable', ...
    struct('node', 'UBERON:0000955', 'name', 'brain'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true);
end

function testACamelCaseLocalPartPasses(testCase)
% OWL-Time's terms are `time:intervalDuring`, and relative_reference.value
% .relation enumerates thirteen of them. A local part restricted to digits
% would reject the one live value set that uses CURIEs today.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundCurie');
doc = doc.set('demoBoundCurie.variable', ...
    struct('node', 'time:intervalDuring', 'name', 'during'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true);
end

function testABareNameIsMalformedNotMissing(testCase)
% THE DISTINCTION THE THREE IDS EXIST FOR. `{node:'', name:'age'}` -- which is
% what the corpus is full of -- is not an absent value: the document said
% something. What it did not say is anything RESOLVABLE. Reporting that as
% "missing" would merge it into a quarantine row about hollow documents and
% make the repair unreadable.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundCurie');
doc = doc.set('demoBoundCurie.variable', struct('node', '', 'name', 'age'));
try
    doc.validate('SchemaCache', testCase.TestData.cache);
    verifyFail(testCase, 'expected a binding error');
catch err
    verifyEqual(testCase, err.identifier, 'did2:validation:bindingNodeMalformed');
end
end

function testAnAllBlankTermIsMissingNotMalformed(testCase)
% The other side of the same distinction. Note this document reaches the
% binding check at all only because the field is OPTIONAL -- a required one
% would have raised vacuousField first (#38), which is the correct precedence
% and is pinned by testVacuityIsCheckedBeforeBinding below.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundCurie');
doc = doc.set('demoBoundCurie.variable', struct('node', '  ', 'name', ''));
try
    doc.validate('SchemaCache', testCase.TestData.cache);
    verifyFail(testCase, 'expected a binding error');
catch err
    verifyEqual(testCase, err.identifier, 'did2:validation:bindingValueMissing');
end
end

function testAPrefixWithNoColonIsMalformed(testCase)
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundCurie');
doc = doc.set('demoBoundCurie.variable', ...
    struct('node', 'UBERON_0000955', 'name', 'brain'));
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:bindingNodeMalformed');
end

function testAnUnexpandablePrefixStillPasses(testCase)
% DELIBERATE, and the limit of what this check claims. `node_form` is about
% LEXICAL SHAPE. Whether `ZZZ:` expands to anything is a different question,
% checked schema-side by check_binding_governance.py B8 across the whole
% declaration set -- which is the right place for it, because a validator that
% rejected unregistered prefixes would be enforcing a registry nobody has
% finished writing.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoBoundCurie');
doc = doc.set('demoBoundCurie.variable', struct('node', 'ZZZ:1', 'name', 'x'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, ...
    'shape is checked; expansion is not, and that is on purpose');
end

% ===================== what must NOT reject =================================

function testAPreferredBindingNeverRejects(testCase)
% THE SECOND BRAKE, and the one that keeps V_eta's three pivot fields
% (subject_statement.variable, subject_interaction.method,
% interaction_purpose.purpose) harmless even with the switch armed. They are
% bound `preferred`. If `preferred` rejected, the word would mean nothing and
% arming the switch on a discovery run would quarantine most of the corpus
% instead of measuring it.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoPreferred');
doc = doc.set('demoPreferred.variable', struct('node', '', 'name', 'age'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'a `preferred` binding is advisory, by definition');
end

function testABindingWithNothingBehindItRejectsNothing(testCase)
% `keyed_by` needs the registry; `term_set` needs a pinned openMINDS instance
% library whose `version` is null. check_binding_governance.py B9 counts these
% four fields as unenforceable AS DECLARED, and the validator must agree with
% that count rather than invent a rule -- otherwise the schema-side number
% stops describing the gate.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoKeyedBy');
doc = doc.set('demoKeyedBy.value', struct('node', '', 'name', 'anything'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, ...
    'a binding that names no checkable rule must reject nothing');
end

function testAnUnknownNodeFormIsTolerated(testCase)
% Forward compatibility in the safe direction. A schema written by newer
% tooling that says `node_form: iri` must not make this code reject documents
% -- an old validator inventing a verdict about a rule it does not know is
% worse than one that says nothing.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoUnknownForm');
doc = doc.set('demoUnknownForm.variable', struct('node', 'plain', 'name', 'x'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true);
end

function testVacuityIsCheckedBeforeBinding(testCase)
% PRECEDENCE, pinned so the quarantine histogram stays legible. A required,
% all-blank composite is a #38 vacuousField -- it is hollow, which is a bigger
% and older problem than being unbound. If binding won the race, arming #32
% would move existing vacuousField rows into a new id and look like a
% regression that had not happened.
did2.schema.cache.strictMode('BindingConformance', true);
doc = blankOf(testCase, 'demoRequiredBound');
try
    doc.validate('SchemaCache', testCase.TestData.cache);
    verifyFail(testCase, 'expected an error');
catch err
    verifyEqual(testCase, err.identifier, 'did2:validation:vacuousField', ...
        'a hollow required composite is #38, not #32');
end
end

% ===================== the ids stay distinct ================================

function testTheThreeIdsAreDistinctFromEachOtherAndFromTheOldFive(testCase)
% One assertion, three documents, because the whole argument for separate ids
% is that a corpus report has to be readable per reason. maxLength / minLength
% / minimum / maximum / enum keep their own ids and are untouched.
did2.schema.cache.strictMode('BindingConformance', true);
cache = testCase.TestData.cache;

ids = {};
cases = { ...
    'demoBoundCurie', 'variable', struct('node', '', 'name', ''); ...
    'demoBoundCurie', 'variable', struct('node', 'nope', 'name', 'x'); ...
    'demoBoundSet',   'clock',    struct('node', '', 'name', 'not_a_member')};
for k = 1:size(cases, 1)
    doc = blankOf(testCase, cases{k, 1});
    doc = doc.set([cases{k, 1} '.' cases{k, 2}], cases{k, 3});
    try
        doc.validate('SchemaCache', cache);
        verifyFail(testCase, sprintf('case %d should have errored', k));
    catch err
        ids{end + 1} = err.identifier; %#ok<AGROW>
    end
end
verifyEqual(testCase, ids, {'did2:validation:bindingValueMissing', ...
    'did2:validation:bindingNodeMalformed', ...
    'did2:validation:bindingValueNotInSet'});
verifyEqual(testCase, numel(unique(ids)), 3, 'the three ids must be distinct');
end

% ===================== helpers =============================================

function doc = blankOf(testCase, className)
doc = did2.document.blank(className, 'SchemaCache', testCase.TestData.cache);
doc = doc.set('base.session_id', 'sess_0000111122223333');
end

function dirPath = bindingFixtureDir(fixtureDir)
% Throwaway classes, one per binding shape the rule has to get right. Every
% field is queryable:false so no queryable path is added and testSchemaCache's
% exact path list is untouched.
%
% All but one field is OPTIONAL (mustBeNonEmpty:false). That is not laziness:
% a required field would raise emptyField or vacuousField BEFORE the binding
% check runs, and every assertion here would then be verifying the wrong id.
% demoRequiredBound is the deliberate exception, and it exists to pin that
% precedence.
dirPath = tempname;
mkdir(dirPath);
copyfile(fullfile(fixtureDir, 'base.json'), fullfile(dirPath, 'base.json'));
curie = fullfile(fixtureDir, 'CURIE_lookups_meta.json');
if isfile(curie)
    copyfile(curie, fullfile(dirPath, 'CURIE_lookups_meta.json'));
end

nodeRefSubs = [sub('node', 'char', '""') ',' sub('name', 'char', '""')];

% inline set, NodeRef members matched on name
writeJSON(fullfile(dirPath, 'demoBoundSet.json'), classJSON('demoBoundSet', ...
    termField('clock', false, ...
        ['{"strength":"required","root":"did_clocktype","values":[' ...
         '{"node":"","name":"dev_local_time"},{"node":"","name":"utc"}]}'], ...
        nodeRefSubs)));

% inline set, NodeRef members matched on node
writeJSON(fullfile(dirPath, 'demoBoundNodes.json'), classJSON('demoBoundNodes', ...
    termField('term', false, ...
        ['{"strength":"required","values":[' ...
         '{"node":"PATO:0000384","name":"male"},' ...
         '{"node":"PATO:0000383","name":"female"}]}'], ...
        nodeRefSubs)));

% inline set on a CHAR field, bare-string members
writeJSON(fullfile(dirPath, 'demoBoundChar.json'), ...
    classJSON('demoBoundChar', charField('clock', ...
        '{"strength":"required","values":["dev_local_time","utc"]}')));

% node_form, required -- the shape rule with teeth
writeJSON(fullfile(dirPath, 'demoBoundCurie.json'), classJSON('demoBoundCurie', ...
    termField('variable', false, ...
        '{"strength":"required","node_form":"curie"}', nodeRefSubs)));

% node_form, PREFERRED -- V_eta's three pivot fields, verbatim
writeJSON(fullfile(dirPath, 'demoPreferred.json'), classJSON('demoPreferred', ...
    termField('variable', false, ...
        '{"strength":"preferred","node_form":"curie"}', nodeRefSubs)));

% keyed_by -- required, and nothing behind it
writeJSON(fullfile(dirPath, 'demoKeyedBy.json'), classJSON('demoKeyedBy', ...
    termField('value', false, ...
        ['{"strength":"required","keyed_by":"variable",' ...
         '"expansion":"descendants","node_kind":"class"}'], nodeRefSubs)));

% an unknown node_form from newer tooling
writeJSON(fullfile(dirPath, 'demoUnknownForm.json'), classJSON('demoUnknownForm', ...
    termField('variable', false, ...
        '{"strength":"required","node_form":"iri"}', nodeRefSubs)));

% required + bound: #38 must win
writeJSON(fullfile(dirPath, 'demoRequiredBound.json'), ...
    classJSON('demoRequiredBound', termField('variable', true, ...
        '{"strength":"required","node_form":"curie"}', nodeRefSubs)));
end

function s = classJSON(className, fieldsJSON)
s = ['{"document_class":{"class_name":"' className '","class_version":"1.0.0",' ...
     '"superclasses":[{"class_name":"base","class_version":"1.0.0"}]},' ...
     '"depends_on":[],"file":[],"fields":[' fieldsJSON ']}'];
end

function s = termField(name, required, bindingJSON, subsJSON)
s = sprintf(['{"name":"%s","type":"ontology_term","mustBeScalar":true,' ...
    '"mustBeNonEmpty":%s,"mustNotHaveNaN":false,"queryable":false,' ...
    '"documentation":"a bound term cell used by the #32 tests",' ...
    '"blank_value":{"node":"","name":""},' ...
    '"default_value":{"node":"","name":""},' ...
    '"constraints":{"binding":%s},"fields":[%s]}'], ...
    name, boolStr(required), bindingJSON, subsJSON);
end

function s = charField(name, bindingJSON)
s = sprintf(['{"name":"%s","type":"char","mustBeScalar":true,' ...
    '"mustBeNonEmpty":false,"mustNotHaveNaN":false,"queryable":false,' ...
    '"documentation":"a bound char field used by the #32 tests",' ...
    '"blank_value":"","default_value":"",' ...
    '"constraints":{"binding":%s}}'], name, bindingJSON);
end

function s = sub(name, type, blank)
s = sprintf(['{"name":"%s","type":"%s","mustBeScalar":true,' ...
    '"mustBeNonEmpty":false,"mustNotHaveNaN":false,"queryable":false,' ...
    '"documentation":"sub-field","blank_value":%s,"default_value":%s,' ...
    '"constraints":{}}'], name, type, blank, blank);
end

function s = boolStr(tf)
if tf
    s = 'true';
else
    s = 'false';
end
end

function writeJSON(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('did2:test:cannotWriteFixture', 'Could not write "%s".', path);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text);
end

function tests = testMigratorsJSession
%TESTMIGRATORSJSESSION `session.reference` -> `local_identifier`, TargetVersion 'V_eta'.
%
%   TEAM-SIGN-OFF [session]: jess@walthamdatascience.com / 2026-08-13
%   (did-schema schemas/V_eta_go_forward_class_audit.md)
%     "session.type/.date/.purpose are DELETED (V_zeta inventions, no writer);
%      session.reference becomes local_identifier, required, matching subject
%      and epoch."
%
%   ---------------------------------------------------------------------
%   WHY THIS FILE EXISTS AT ALL, AND WHY THE ROSTER GATE DID NOT ASK FOR IT
%   ---------------------------------------------------------------------
%   `tools/check_migrator_roster.py` counts a migrator as covered when a test
%   file contains a QUOTED CLASS-NAME LITERAL matching it. For almost every
%   migrator that is a sound proxy. For `session` it is not: the string
%   'session' appears as a quoted literal in dozens of tests that have nothing
%   to do with this migrator, so the gate reported `WITH NO TEST: 0` the moment
%   `+migrators_j/session.m` was added, without a single line exercising it.
%
%   That is the vacuous-instrument defect this repository has paid for
%   repeatedly -- `silentLoss` printing "0 empty edges" while reading nothing --
%   arriving inside the gate built to prevent it. The gate is not changed here
%   (its rule is right for the other 83); the hole it left for this one class is
%   filled with a real test.
%
%   ---------------------------------------------------------------------
%   THE FIXTURES ARE THE WRITER'S, NOT A SCHEMA'S
%   ---------------------------------------------------------------------
%     git show origin/main:src/ndi/ndi_common/database_documents/session.json
%        "session": { "reference": "" }
%
%   ONE field. `ndi.session.dir` writes it and nothing else:
%     +ndi/+session/dir.m:138
%        g = ndi.document('session','session.reference',...)
%
%   So `type`, `date` and `purpose` have no did_v1 source at all -- they came
%   from DID-schema's own V_zeta snapshot. The third test below feeds them in
%   ANYWAY, because "no writer emits this" is a statement about NDI today and
%   not about every body that can reach this pipeline: a V_zeta-vintage document
%   re-run would carry them, and after the schema change they are undeclared,
%   which quarantines. Removing them is cheap; assuming they cannot appear is
%   the reassuring direction this project's operating rules name by name.
%
%   UNVERIFIED: there is no MATLAB in the authoring environment, so none of
%   these tests has been executed. They are written from the code as it stands
%   and from the writer evidence quoted above.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJSession');

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

function msg = reasonsOf(out)
%REASONSOF The quarantine reasons, as a NON-EMPTY diagnostic.
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

function assumeVEtaSchemas(testCase)
%ASSUMEVETASCHEMAS Skip unless the cache resolves the POST-RENAME `session`.
%   installSchemaPath only checks that some folder of *.json exists, so a
%   pre-rename checkout would satisfy it and then fail for the wrong reason.
%   Probing the FIELD rather than the class is what makes the skip honest here:
%   `session` exists in every vintage, and only the renamed one declares
%   `local_identifier`.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the V_eta session rename validation test');
try
    cache = did2.schema.cache.shared();
    cls = cache.getClass('session');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve the `session` class (' ...
         err.message ').']);
    return;
end
names = {};
if isprop(cls, 'fields') || isfield(cls, 'fields')
    for k = 1:numel(cls.fields)
        names{end+1} = cls.fields(k).name; %#ok<AGROW>
    end
end
if ~any(strcmp(names, 'local_identifier'))
    assumeFail(testCase, ...
        ['the resolved `session` class declares no `local_identifier`; ' ...
         'DID_SCHEMA_PATH points at a pre-rename V_eta build.']);
end
end

% ===================== fixtures, built from the writer ======================

function v1 = sessionV1(reference)
%SESSIONV1 A did_v1 `session` exactly as ndi.session.dir writes one: one
%   property block carrying one field, no dependencies, no files.
v1 = struct();
v1.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.base = struct('id', 'sess_doc_1', 'session_id', 'sess_09', ...
    'name', 'ts_2024', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session = struct('reference', reference);
end

function v1 = sessionVZetaVintage(reference)
%SESSIONVZETAVINTAGE The same document as a V_zeta-era body carried it: the
%   three invented fields alongside the real one. No NDI writer produces this;
%   a re-run of an already-once-migrated corpus can.
v1 = sessionV1(reference);
v1.session.type = 'experiment';
v1.session.date = '2024-06-01';
v1.session.purpose = 'characterisation';
end

% ===================== the rename ==========================================

function testReferenceBecomesLocalIdentifierWithIdPreserved(testCase)
% 1 -> 1, id PRESERVED. Every fold in this project that changed a document id
% created dangling references, so base.id is asserted before anything else.
out = runJ(sessionV1('ts_2024'));
verifyEmpty(testCase, out.quarantine, reasonsOf(out));
% ASSERT, not verify: everything below reads out.migrated{1}, and a verify on
% the count would let an empty result set pass the rest vacuously.
assertEqual(testCase, numel(out.migrated), 1, ...
    'the session migrator emitted no document; every assertion below would be vacuous');
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'session');
verifyEqual(testCase, doc.get('base.id'), 'sess_doc_1');
verifyEqual(testCase, doc.get('base.session_id'), 'sess_09');
verifyEqual(testCase, doc.get('session.local_identifier'), 'ts_2024');
end

function testTheOldSpellingIsGoneNotMerelyShadowed(testCase)
% The rename COPIES then REMOVES. A body carrying both spellings would validate
% against a schema that declares neither twice, and the stale one would then be
% read by anything still looking for it -- one slot spelled two ways is the
% drift the rename exists to end.
out = runJ(sessionV1('ts_2024'));
assertEqual(testCase, numel(out.migrated), 1, 'nothing emitted');
blk = out.migrated{1}.document_properties.session;
verifyFalse(testCase, isfield(blk, 'reference'), ...
    'session.reference survived the rename alongside session.local_identifier');
end

function testTheThreeVZetaInventionsAreRemoved(testCase)
% Not "are absent" -- REMOVED. Fed in deliberately, because they are undeclared
% on the post-rename schema and would quarantine the document if carried.
out = runJ(sessionVZetaVintage('ts_2024'));
assertEqual(testCase, numel(out.migrated), 1, 'nothing emitted');
blk = out.migrated{1}.document_properties.session;
for f = {'type', 'date', 'purpose'}
    verifyFalse(testCase, isfield(blk, f{1}), ...
        sprintf('session.%s survived; it is undeclared and will quarantine', f{1}));
end
verifyEqual(testCase, out.migrated{1}.get('session.local_identifier'), 'ts_2024');
end

function testTheRenamedDocumentValidates(testCase)
% The one test that can catch a schema/migrator disagreement: everything above
% runs with Validate false.
assumeVEtaSchemas(testCase);
out = runJValidated(sessionVZetaVintage('ts_2024'));
verifyEmpty(testCase, out.quarantine, reasonsOf(out));
assertEqual(testCase, numel(out.migrated), 1, 'nothing emitted');
verifyEqual(testCase, out.migrated{1}.get('session.local_identifier'), 'ts_2024');
end

function testAnEmptyReferenceQuarantinesRatherThanBeingInvented(testCase)
% `local_identifier` is mustBeNonEmpty. A session with no reference is a FACT
% ABOUT THE SOURCE, and manufacturing a handle for it would be the
% hollow-document defect -- a document that validates while saying nothing.
% So the correct behaviour is a loud quarantine, not a quiet substitution.
assumeVEtaSchemas(testCase);
out = runJValidated(sessionV1(''));
verifyEmpty(testCase, out.migrated, ...
    'an empty session reference was migrated; nothing may invent a handle');
assertNotEmpty(testCase, out.quarantine, ...
    'an empty session.local_identifier passed validation; mustBeNonEmpty is not enforced');
verifyEqual(testCase, out.quarantine(1).class_name, 'session');
end

function testABodyWithNoSessionBlockPassesThroughUnchanged(testCase)
% The migrator guards on the block's presence. A body reaching it without one
% is not something to error on -- it is nothing to rewrite.
v1 = sessionV1('ts_2024');
v1 = rmfield(v1, 'session');
out = runJ(v1);
assertEqual(testCase, numel(out.migrated), 1, 'nothing emitted');
verifyEqual(testCase, out.migrated{1}.get('base.id'), 'sess_doc_1');
end

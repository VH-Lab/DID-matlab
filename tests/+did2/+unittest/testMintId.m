function tests = testMintId
%TESTMINTID did2.convert.mintId: deterministic ids for the documents the
%   migration mints (practice (b) of [migration reliability practices], Jess
%   Haley, 2026-10-26, did-schema V_eta_go_forward_class_audit.md): derived
%   from the source id and the role, so two runs on the same input give the
%   same ids; random outside a migration, as before.
tests = functiontests(localfunctions);
end

function teardown(~)
did2.convert.mintId('-reset');
end

function testTheFormatIsDidIdo(testCase)
did2.convert.mintId('-reset');
src = did.ido.unique_id();
did2.convert.mintId('-push', src);
a = did2.convert.mintId('build:manipulation');
verifyTrue(testCase, did.ido.isvalid(a), a);
verifyEqual(testCase, a(1:16), src(1:16), 'the time half is the source''s');
did2.convert.mintId('-push', 'not_a_did_ido_id');
b = did2.convert.mintId('build:manipulation');
verifyTrue(testCase, did.ido.isvalid(b), b);
end

function testTwoRunsGiveTheSameIds(testCase)
ids1 = run();
ids2 = run();
verifyEqual(testCase, ids1, ids2);
verifyEqual(testCase, numel(unique(ids1)), numel(ids1), 'ids within a run are distinct');
    function ids = run()
        did2.convert.mintId('-reset');
        ids = {};
        for s = {'41e1b2c3d4e5f607_0123456789abcdef', '41e1b2c3d4e5f608_0123456789abcdef'}
            did2.convert.mintId('-push', s{1});
            ids{end+1} = did2.convert.mintId('build:chemical'); %#ok<AGROW>
            ids{end+1} = did2.convert.mintId('build:chemical'); %#ok<AGROW>
            ids{end+1} = did2.convert.mintId('build:formulation'); %#ok<AGROW>
            ids{end+1} = did2.convert.mintId('file_uid', 'other_source'); %#ok<AGROW>
            did2.convert.mintId('-pop');
        end
    end
end

function testOutsideAContextItIsRandom(testCase)
did2.convert.mintId('-reset');
a = did2.convert.mintId('build:entity');
b = did2.convert.mintId('build:entity');
verifyNotEqual(testCase, a, b);
did2.convert.mintId('-push', '');
verifyNotEqual(testCase, did2.convert.mintId('x'), did2.convert.mintId('x'), ...
    'an empty key mints random ids');
end

function testPopToRestoresTheDepth(testCase)
did2.convert.mintId('-reset');
did2.convert.mintId('-push', 'a');
d = did2.convert.mintId('-depth');
did2.convert.mintId('-push', 'b');
did2.convert.mintId('-push', 'c');
did2.convert.mintId('-popto', d);
verifyEqual(testCase, did2.convert.mintId('-depth'), 1);
end

function testAMigratedBatchMintsTheSameIdsTwice(testCase)
% end to end: v1_to_v2 over the same v1 treatment_drug twice (a dose at a body
% site: the manipulation keeps the v1 id; chemicals, formulation, anchor and
% site observation are minted) gives the same ids both times
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', '41e1b2c3d4e5f609_0123456789abcdef', 'session_id', 'sess_09', ...
    'name', 'td', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_drug = struct('mixture_table', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'location_ontologyNode', 'UBERON:0001179', 'location_name', 'peritoneal cavity');
prev = did2.schema.cache.strictMode('TermRegistry', false);
cleanup = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev)); %#ok<NASGU>
r1 = did2.convert.v1_to_v2({v1}, 'Validate', false);
r2 = did2.convert.v1_to_v2({v1}, 'Validate', false);
verifyEmpty(testCase, r1.quarantine);
verifyGreaterThan(testCase, numel(r1.migrated), 1, 'the dose mints documents');
verifyEqual(testCase, idsOf(r1), idsOf(r2));
verifyEqual(testCase, did2.convert.mintId('-depth'), 0, 'v1_to_v2 closes its contexts');
end

function ids = idsOf(r)
ids = cellfun(@(d) char(d.get('base.id')), r.migrated, 'UniformOutput', false);
ids = sort(ids);
end

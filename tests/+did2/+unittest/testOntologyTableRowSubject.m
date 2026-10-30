function tests = testOntologyTableRowSubject
%TESTONTOLOGYTABLEROWSUBJECT The subject-attribution guard on ontology_table_row.
%
%   Corpus run #256 measured, on the Dab corpus alone, 76,766 observations and
%   assertions carrying an EMPTY subject_id -- intensity, count, term, duration,
%   frequency, date_assertion, term_assertion. Every one passed validation:
%   quarantine was 0, because validate/references.m skips empty edges and
%   mustBeNonEmpty on depends_on is not enforced.
%
%   ROOT CAUSE. The per-column fallback seeded every statement through
%   startStatement -> carrySubject(preBody), which scans the SOURCE document's
%   depends_on for a dependency named `subject_id`. The real NDI template
%   declares exactly one dependency and it is not that one:
%
%       ndi_common/database_documents/data/ontologyTableRow.json
%       depends_on: [ { "name": "document_id", "value": "" } ]
%
%   The scan therefore never succeeded on a real document, and the migrator
%   wrote subject_id = '' rather than noticing.
%
%   These tests are written from the REAL TEMPLATE SHAPE, not from a DID-side
%   schema. That distinction is the whole reason this defect existed: a fixture
%   built from our own assumption would have carried a subject_id dependency and
%   passed against the broken code.
%
%   SINCE 2026-10-30 every row is carried whole as v1 (Decided by Jess Haley,
%   [table rows carried as v1], did-schema V_eta_go_forward_class_audit.md):
%   the migrator resolves no subject and fans out no statements, with or
%   without a `subject_id` edge, and notes each row `carried_as_v1` citing
%   register row carry-026. The tests below pin that carry: one body, the
%   source unchanged, the note.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function realShapedRow = makeRealRow()
% A did_v1 ontologyTableRow exactly as NDI writes it: ONE dependency,
% `document_id`. No subject_id. Anything else is our assumption, not the data.
realShapedRow = struct();
realShapedRow.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0');
realShapedRow.depends_on = struct('name', 'document_id', 'value', 'doc-123');
realShapedRow.base = struct('id', 'row-1', 'session_id', 'sess-1', ...
    'name', 'a row', 'datestamp', '2024-01-01T00:00:00.000Z');
realShapedRow.ontology_table_row = struct( ...
    'names', 'Speed', 'variable_names', 'Speed', ...
    'ontology_nodes', 'NCIT:C1', 'data', '3.5');
end

function verifyCarriedWithNote(testCase, pre, out)
%VERIFYCARRIEDWITHNOTE One body, the v1 source unchanged, and exactly one
%   `carried_as_v1` note citing carry-026 and the decision tag.
verifyEqual(testCase, numel(out), 1, 'the v1 row, alone: no fan-out');
verifyEqual(testCase, out{1}, pre, 'returned unchanged');
notes = did2.convert.reportNote('collect');
verifyTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry is noted');
if isfield(notes, 'carried_as_v1')
    verifyEqual(testCase, notes.carried_as_v1.count, 1);
    d = notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-026] needs_mapping:'), d);
    verifyTrue(testCase, contains(d, '[table rows carried as v1]'), d);
end
end

function testSubjectlessRowIsCarriedWithANote(testCase)
% INVERTS testSubjectlessRowPassesThroughInsteadOfFanningOut. THE REGRESSION
% TEST still holds (no fan-out of statements with subject_id = ''), and the
% row is now carried with a carry-026 note rather than passed through silently
% for NDI's second pass ([table rows carried as v1], Jess Haley, 2026-10-30).
pre = makeRealRow();
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.ontology_table_row(pre);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'ontology_table_row', ...
    'the document must come back as its source class');
verifyCarriedWithNote(testCase, pre, out);
did2.convert.reportNote('reset');
end

function testNoEmittedBodyEverCarriesAnEmptySubjectId(testCase)
% The property that actually matters, stated independently of HOW it is
% achieved: nothing this migrator emits may declare subject_id and leave it
% blank. If a future edit reinstates the fan-out, this fails even if the
% passthrough test above is rewritten.
out = did2.convert.migrators_j.ontology_table_row(makeRealRow());
for i = 1:numel(out)
    b = out{i};
    if ~isfield(b, 'depends_on') || ~isstruct(b.depends_on); continue; end
    for k = 1:numel(b.depends_on)
        d = b.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, 'subject_id')
            verifyNotEmpty(testCase, d.value, sprintf( ...
                ['%s was emitted with an EMPTY subject_id -- an observation ' ...
                 'of nothing. This is the 76,766-document defect returning.'], ...
                b.document_class.class_name));
        end
    end
end
end

function testRowWithARealSubjectIsCarriedNotGuessed(testCase)
% INVERTS testRowWithARealSubjectStillMigrates. A row WITH a resolvable subject
% used to fan out into statements whose direction and value kind were chosen
% from label words. Decided by Jess Haley, 2026-10-26 [one correct reading],
% [dataset audit batch 1 and 2] (4): it is carried whole as v1 -- one body,
% the source unchanged -- with a `needs_mapping` note.
% [table rows carried as v1] (Jess Haley, 2026-10-30) keeps that carry for
% every row; this is also the shape of a row NDI's second pass re-folds with an
% added `subject_id` edge, which is carried too.
pre = makeRealRow();
pre.ontology_table_row = struct('rows', struct( ...
    'ontology_name', 'NCIT:C1', 'name', 'Speed', 'value', '3.5'));
pre.depends_on = [struct('name', 'document_id', 'value', 'doc-123'), ...
                  struct('name', 'subject_id',  'value', 'subj-9')];
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.ontology_table_row(pre);
verifyCarriedWithNote(testCase, pre, out);
did2.convert.reportNote('reset');
end

function testEveryRowLayoutIsCarriedTheSameWay(testCase)
% INVERTS testRealWriterShapeHasNoRowsField, which pinned that a current-writer
% row (four comma-joined strings, no `rows` field) passed through because
% extractRows() found no columns. extractRows() is gone with the fan-out: the
% migrator no longer reads the row's layout at all ([table rows carried as v1],
% Jess Haley, 2026-10-30). So every layout -- the current writer's, the `rows`
% vintage the Dab corpus held, and an unrecognised one -- is carried the same
% way: one body, the source unchanged, a carry-026 note.
writer = makeRealRow();
rowsVintage = makeRealRow();
rowsVintage.ontology_table_row = struct('rows', struct( ...
    'ontology_name', 'NCIT:C1', 'name', 'Speed', 'value', '3.5'));
unknown = makeRealRow();
unknown.ontology_table_row = struct('something_else', 1);
cases = {writer, rowsVintage, unknown};
for k = 1:numel(cases)
    did2.convert.reportNote('reset');
    out = did2.convert.migrators_j.ontology_table_row(cases{k});
    verifyCarriedWithNote(testCase, cases{k}, out);
end
did2.convert.reportNote('reset');
end

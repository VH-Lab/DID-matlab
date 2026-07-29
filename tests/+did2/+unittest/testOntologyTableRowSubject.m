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

tests = functiontests(localfunctions);
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

function testSubjectlessRowPassesThroughInsteadOfFanningOut(testCase)
% THE REGRESSION TEST. Before the guard this emitted a fan-out of statements,
% each with subject_id = ''. It must now carry the document through untouched
% for the NDI second pass.
out = did2.convert.migrators_j.ontology_table_row(makeRealRow());
verifyEqual(testCase, numel(out), 1, ...
    'a row with no resolvable subject must not fan out into statements');
verifyEqual(testCase, out{1}.document_class.class_name, 'ontology_table_row', ...
    'the document must pass through as its source class');
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

function testRowWithARealSubjectStillMigrates(testCase)
% The guard must not disable the migrator wholesale. A row that DOES carry a
% resolvable subject (as a mapped table or a second-pass-patched document does)
% still fans out into statements.
pre = makeRealRow();
pre.depends_on = [struct('name', 'document_id', 'value', 'doc-123'), ...
                  struct('name', 'subject_id',  'value', 'subj-9')];
out = did2.convert.migrators_j.ontology_table_row(pre);
verifyGreaterThan(testCase, numel(out), 1, ...
    'a row WITH a subject must still migrate into statements');
sawSubject = false;
for i = 1:numel(out)
    b = out{i};
    if ~isfield(b, 'depends_on') || ~isstruct(b.depends_on); continue; end
    for k = 1:numel(b.depends_on)
        if strcmp(b.depends_on(k).name, 'subject_id')
            verifyEqual(testCase, b.depends_on(k).value, 'subj-9');
            sawSubject = true;
        end
    end
end
verifyTrue(testCase, sawSubject, ...
    'at least one emitted statement should carry the resolved subject');
end

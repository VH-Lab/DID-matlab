function tests = testEdgeArityCensus
%TESTEDGEARITYCENSUS Tests for the UNGATED edge-arity block of
%   did2.validate.silentLoss -- "how many EXISTING documents carry a plural
%   edge".
%
%   WHY THE COUNTER EXISTS, stated here because it is what these tests are
%   really checking. The question "how many already-written documents carry a
%   plural `document_id`" had no answer anywhere and was being written down as
%   UNMEASURED. Three counters could have answered it and each is out of reach:
%
%     ndi.migrate.internal.imagedEntitySubjects.blocked_plural_document_id
%         NDI-side. The DID corpus harness never invokes that pass, so its zero
%         means "not run".
%     ndi.migrate.internal.ontologyRowSubjects
%         has no arity counter at all -- `resolved_via_document_id_edge` counts
%         RESOLUTIONS, so a row with three edges that resolves once adds one.
%     did2.validate.silentLoss.uniqueness_denominator.docs_multi_member
%         IS an arity counter and is GATED on the schema key
%         `referent_unique_by`. DID-schema's `_EDGE_REFERENT_UNIQUE`
%         (tools/build_v_eta.py:5583-5587) has THREE entries, every one of them
%         `time_reference_#`. `document_id` is not among them, so that counter
%         does not report zero for it -- it never looks.
%
%   NDI-matlab 40dc9aa86 repaired the WRITER (tableDocMaker no longer deletes
%   the dependency columns before `names`/`variableNames`/`ontologyNodes`/`data`
%   are built from them, so a new plural row can be traced edge-to-column). A
%   writer repair reaches no document already written, which is exactly why the
%   size of the existing population has to be measured rather than assumed.
%
%   WHERE THE FIXTURES COME FROM, AND WHY IT MATTERS. "A test written from the
%   same premise as the code cannot catch the code" is a standing rule in this
%   project -- three `epochid` tests had to be INVERTED, not updated, and
%   `silentLoss` itself shipped with no tests and measured nothing for two days.
%   So the fixtures below are built from NDI'S WRITER, not from the counter's
%   shape:
%
%     ndi/+setup/+NDIMaker/tableDocMaker.m:284-293
%         values = tableRow{:,dependencyVariable};
%         for d = 1:numel(values)
%             if isscalar(values)
%                 doc = doc.set_dependency_value('document_id',value);   % ONE
%             else
%                 doc = doc.add_dependency_value_n('document_id',value); % MANY
%             end
%         end
%
%     did/document.m:349 (add_dependency_value_n)
%         newName = [dependency_name '_' int2str(numel(d)+1)];
%
%   So a SINGULAR row is spelled with a BARE `document_id` and a PLURAL row is
%   spelled `document_id_1`, `document_id_2`. That asymmetry is the single fact
%   these tests exist to pin: a census keyed on the indexed spelling alone would
%   report every plural row with a ZERO singular row beside it -- a numerator
%   whose denominator had been defined away, which is the failure operating
%   rule 5 exists to stop.
%
%   STATUS: WRITTEN WITHOUT MATLAB AND NOT EXECUTED. No MATLAB, Octave or
%   octave-cli exists in the container these were authored in
%   (`command -v matlab octave octave-cli` exits 1 for each). The only checks
%   performed on this file and on the counter were STRUCTURAL. CI is their first
%   run, and if one fails there it is doing the job it was added for. A
%   mutation was deliberately NOT pushed to the shared branch to test it --
%   tools/mutationProbe.m records why that is forbidden and that
%   .github/workflows/matlab-scratch.yml + tools/scratch.m is the sanctioned
%   route.

tests = functiontests(localfunctions);
end

% ===================== rule 5: the denominator =============================

function testTheBlockCarriesItsOwnDenominator(testCase)
% The block must state how many documents it looked at, on its own, without a
% reader holding total_docs in their head -- and it must do so when it found
% nothing. This counter's whole purpose is to close a question currently
% recorded as UNMEASURED, so a zero with no denominator beside it would close
% that question with the wrong answer.
docs = {docObj('subject', 'sub_1'), docObj('subject', 'sub_2')};
rep = did2.validate.silentLoss(docs);
verifyTrue(testCase, isfield(rep, 'edge_arity'));
ea = rep.edge_arity;
verifyEqual(testCase, ea.docs_inspected, 2);
verifyEqual(testCase, ea.docs_unreadable, 0);
end

function testTheDenominatorIsPresentOnEveryPathOut(testCase)
% The early returns are the paths that matter: a block whose denominator is set
% only on the happy path reports zeros for a batch it never opened, which is
% the original silentLoss defect verbatim.
empt = did2.validate.silentLoss({});
verifyEqual(testCase, empt.edge_arity.docs_inspected, 0);
verifyEqual(testCase, empt.edge_arity.pairs_examined, 0);

bad = did2.validate.silentLoss({struct('nope', 1), struct('nope', 2)});
verifyEqual(testCase, bad.edge_arity.docs_inspected, 2, ...
    'documents that could not be parsed are still part of the denominator');
end

function testTheThreeDocumentStatesPartitionTheDenominator(testCase)
% unreadable + unclassifiable + classified == inspected, EXACTLY. A document
% that falls into none of the three is one this block silently stopped
% describing, which is the accounting hole the NDI-required block was repaired
% for. A MIXED batch, because a uniform one can satisfy the identity by
% accident -- one document of each state.
%
% THE THREE STATES ARE NAMED FROM `vBodies`, NOT GUESSED. This is where the
% sibling test in testSilentLoss.m went wrong: it asserted `docs_unreadable = 2`
% for two class-less structs and the truthful answer was 0, because
% `asStruct` returns ANY STRUCT UNCHANGED. So:
%   unreadable     asStruct could not produce a body at all -- `[]` is the
%                  minimal case, and it is the only one of the three that
%                  never reaches the loop
%   unclassifiable it parsed and carries no `document_class`
%   classified     it has a class name
noClass = struct('base', struct('id', 'x_1'));   % parses, no document_class
docs = {docObj('subject', 'sub_1'), noClass, []};
rep = did2.validate.silentLoss(docs);
ea = rep.edge_arity;
verifyEqual(testCase, ea.docs_inspected, 3);
verifyEqual(testCase, ea.docs_unreadable, 1);
verifyEqual(testCase, ea.docs_unclassifiable, 1);
verifyEqual(testCase, ea.docs_classified, 1);
verifyEqual(testCase, ...
    ea.docs_unreadable + ea.docs_unclassifiable + ea.docs_classified, ...
    ea.docs_inspected, ...
    'the three document states must partition the denominator exactly');
end

function testADocumentThatThrowsIsVisibleAndDoesNotBreakThePartition(testCase)
% `docs_errored` OVERLAPS the three partition states and is not one of them.
% A census that quietly gave up on part of its batch and said nothing is the
% defect this whole file exists to remove; a census that counted the same
% document twice would report MORE coverage than it has, which is the
% direction this project's errors always run.
%
% The throw is forced through `classNameOf`, which does `char(class_name)` --
% and a struct cannot be converted to char. It therefore throws BEFORE the
% document is classified, so the document takes the unclassifiable slot exactly
% once and the identity still holds.
b = bodyStruct('ontology_table_row', 'r1');
b.document_class.class_name = struct('not', 'a name');
docs = {b, rowBody('r2', {'document_id_1', 'document_id_2'}, {'a', 'b'})};
rep = did2.validate.silentLoss(docs);
ea = rep.edge_arity;
verifyEqual(testCase, ea.docs_inspected, 2);
verifyEqual(testCase, ea.docs_errored, 1, ...
    'a document the census could not finish must be visible');
verifyEqual(testCase, ...
    ea.docs_unreadable + ea.docs_unclassifiable + ea.docs_classified, ...
    ea.docs_inspected, ...
    'docs_errored must NOT be a fourth partition state');
verifyEqual(testCase, ea.pairs_plural, 1, ...
    'one bad document must not cost the batch its measurement');
end

% ===================== the two spellings NDI actually writes ================

function testASingularRowIsArityOneUnderTheBareSpelling(testCase)
% tableDocMaker.m:289 -- one referent, `set_dependency_value('document_id',..)`,
% so the edge carries NO index. This is the overwhelming majority shape.
b = rowBody('row_1', {'document_id'}, {'target_a'});
rep = did2.validate.silentLoss({b});
ea = rep.edge_arity;
verifyEqual(testCase, ea.pairs_examined, 1);
verifyEqual(testCase, ea.pairs_plural, 0);
verifyEqual(testCase, ea.docs_with_indexed_edge, 0, ...
    'a bare document_id is not an indexed edge');
verifyEqual(testCase, arityOf(rep, 'ontology_table_row', 'document_id', '1'), 1);
end

function testAPluralRowIsArityTwoUnderTheIndexedSpelling(testCase)
% tableDocMaker.m:291 -- several referents, `add_dependency_value_n`, which
% did/document.m:349 spells `document_id_1`, `document_id_2`. THE CASE THE
% WHOLE COUNTER EXISTS FOR.
b = rowBody('row_2', {'document_id_1', 'document_id_2'}, ...
    {'target_a', 'target_b'});
rep = did2.validate.silentLoss({b});
ea = rep.edge_arity;
verifyEqual(testCase, ea.pairs_examined, 1, ...
    'two members of one family are ONE (document, family) pair');
verifyEqual(testCase, ea.pairs_plural, 1);
verifyEqual(testCase, ea.docs_with_plural_family, 1);
verifyEqual(testCase, ea.docs_with_indexed_edge, 1);
verifyEqual(testCase, ea.indexed_edges_examined, 2);
verifyEqual(testCase, ea.max_arity_seen, 2);
verifyEqual(testCase, arityOf(rep, 'ontology_table_row', 'document_id', '2'), 1);
end

function testTheBareAndIndexedSpellingsAreOneFamily(testCase)
% If they were two families the singular documents would form their own row and
% the plural row would print with a zero denominator beside it. The one real
% consumer of the idiom folds them the same way -- NDI
% imagedEntitySubjects/dependencyValuesMatching matches `^<name>(_\d+)?$`.
b = rowBody('row_3', {'document_id', 'document_id_2'}, ...
    {'target_a', 'target_b'});
rep = did2.validate.silentLoss({b});
verifyEqual(testCase, rep.edge_arity.pairs_examined, 1, ...
    'the bare and indexed spellings must fold into ONE family');
verifyEqual(testCase, rep.edge_arity.pairs_plural, 1);
verifyEqual(testCase, ...
    arityOf(rep, 'ontology_table_row', 'document_id', '2'), 1);
end

% ===================== THE MIXED CASE =======================================

function testAMixedBatchReportsBothTheSingularAndThePluralRows(testCase)
% THE TEST THIS FILE IS FOR. A real corpus is not uniform: `ontology_table_row`
% is overwhelmingly singular with a small plural tail, because NDI's writer
% picks the spelling by arity. Both must appear, under ONE family name, with
% counts that can be read against each other -- 4 singular, 2 plural is a
% different fact from 4 singular out of 76,766.
%
% Deliberately NOT a uniform batch and deliberately NOT symmetric counts: equal
% counts would let a transposition or an off-by-one pass.
docs = {rowBody('r1', {'document_id'}, {'a'}), ...
        rowBody('r2', {'document_id'}, {'b'}), ...
        rowBody('r3', {'document_id'}, {'c'}), ...
        rowBody('r4', {'document_id'}, {'d'}), ...
        rowBody('r5', {'document_id_1', 'document_id_2'}, {'e', 'f'}), ...
        rowBody('r6', {'document_id_1', 'document_id_2', 'document_id_3'}, ...
                      {'g', 'h', 'i'})};
rep = did2.validate.silentLoss(docs);
ea = rep.edge_arity;
verifyEqual(testCase, ea.docs_inspected, 6);
verifyEqual(testCase, ea.docs_classified, 6);
verifyEqual(testCase, ea.docs_with_depends_on, 6);
verifyEqual(testCase, ea.pairs_examined, 6, ...
    'one (document, family) pair per document, singular or plural');
verifyEqual(testCase, ea.pairs_plural, 2);
verifyEqual(testCase, ea.docs_with_plural_family, 2);
verifyEqual(testCase, ea.docs_with_indexed_edge, 2, ...
    'only the plural rows carry the indexed spelling');
verifyEqual(testCase, ea.max_arity_seen, 3);
verifyEqual(testCase, ea.families_seen, 1);
verifyEqual(testCase, ea.plural_families_seen, 1);

% The distribution: the '1' row IS the denominator for the other two.
verifyEqual(testCase, arityOf(rep, 'ontology_table_row', 'document_id', '1'), 4);
verifyEqual(testCase, arityOf(rep, 'ontology_table_row', 'document_id', '2'), 1);
verifyEqual(testCase, arityOf(rep, 'ontology_table_row', 'document_id', '3+'), 1);

% And the buckets account for every pair -- a document in no bucket is a
% document the table silently stopped describing.
verifyEqual(testCase, ...
    arityOf(rep, 'ontology_table_row', 'document_id', '1') + ...
    arityOf(rep, 'ontology_table_row', 'document_id', '2') + ...
    arityOf(rep, 'ontology_table_row', 'document_id', '3+'), ...
    ea.pairs_examined);
end

function testTheHeadlineCountEqualsThePairsPluralDenominator(testCase)
% They are incremented on the same branch of the same loop, so they cannot
% legitimately differ. This file has already shipped an accumulator that was
% counted and never assigned (#63's famKeys), reporting 0 on a document the
% detector had just flagged, so the two are compared rather than trusted.
docs = {rowBody('r1', {'document_id'}, {'a'}), ...
        rowBody('r2', {'document_id_1', 'document_id_2'}, {'b', 'c'})};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.edge_arity_plural_count, rep.edge_arity.pairs_plural);
verifyEqual(testCase, rep.edge_arity_plural_count, 1);
end

function testThePluralFamilyRowCarriesTheLargestArityNotASum(testCase)
% A family whose worst case is 2 and one whose worst case is 40 are different
% problems, and the document count alone cannot tell them apart. `max_arity` is
% a MAXIMUM: summing it would report an arity no document has.
docs = {rowBody('r1', {'document_id_1', 'document_id_2'}, {'a', 'b'}), ...
        rowBody('r2', {'document_id_1', 'document_id_2', 'document_id_3', ...
                       'document_id_4'}, {'c', 'd', 'e', 'f'})};
rep = did2.validate.silentLoss(docs);
rows = rep.edge_arity.plural_by_family;
verifyEqual(testCase, numel(rows), 1);
verifyEqual(testCase, rows(1).class_name, 'ontology_table_row');
verifyEqual(testCase, rows(1).edge_name, 'document_id');
verifyEqual(testCase, rows(1).count, 2, ...
    'two documents carried more than one member');
verifyEqual(testCase, rows(1).max_arity, 4, ...
    'max_arity is a MAXIMUM (4), never a sum (6) and never a count (2)');
end

function testTheRowTablesReachTheReport(testCase)
% The accumulate-and-never-assign bug has shipped in silentLoss.m once already:
% the counter measured correctly and threw the answer away, so the report read
% 0 on a document the detector had just flagged. Both new row tables are
% asserted individually for that reason.
b = rowBody('r1', {'document_id_1', 'document_id_2'}, {'a', 'b'});
rep = did2.validate.silentLoss({b});
verifyNotEmpty(testCase, rep.edge_arity.arity_distribution, ...
    'the arity distribution was accumulated and never assigned');
verifyNotEmpty(testCase, rep.edge_arity.plural_by_family, ...
    'the plural-family table was accumulated and never assigned');
end

% ===================== THE GATING, WHICH IS THE POINT =======================

function testItSeesAPluralFamilyTheGatedCounterCannotSee(testCase)
% THE DISCRIMINATING TEST, and it is written from the premise of the BUG rather
% than of the code: on ONE batch, the gated counter reports nothing and the
% ungated one reports the plural. If this ever fails because both report the
% same thing, either `document_id` acquired a `referent_unique_by` (fine -- and
% then this test should be re-derived, not deleted) or the new census has
% quietly become gated too.
%
% `uniqueness_denominator.docs_multi_member` counts (document, family) pairs
% with more than one member, EXACTLY like `pairs_plural` -- but only for a
% family whose schema declares `referent_unique_by`. DID-schema declares it on
% three families, all `time_reference_#`
% (tools/build_v_eta.py:5583-5587), so `document_id` is never examined by it.
docs = {rowBody('r1', {'document_id_1', 'document_id_2'}, {'a', 'b'}), ...
        rowBody('r2', {'document_id_1', 'document_id_2'}, {'c', 'd'})};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.uniqueness_denominator.docs_multi_member, 0, ...
    ['the GATED counter must report nothing here -- if it does not, ' ...
     '`document_id` gained a referent_unique_by and this test needs ' ...
     're-deriving from the schema, not deleting']);
verifyEqual(testCase, rep.edge_arity.pairs_plural, 2, ...
    'the UNGATED counter must see both plural documents');
end

function testAClassNoSchemaDeclaresIsStillCounted(testCase)
% The strongest available statement that the block consults no schema. Every
% other block in silentLoss resolves the class chain, so a class the cache does
% not know is SKIPPED by all of them -- and this one must still measure it. A
% document nothing can classify is precisely the document an unmeasured
% population is made of.
b = rowBody('r1', {'document_id_1', 'document_id_2'}, {'a', 'b'});
b.document_class.class_name = 'a_class_no_schema_has_ever_declared';
rep = did2.validate.silentLoss({b});
verifyEqual(testCase, rep.edge_arity.docs_classified, 1);
verifyEqual(testCase, rep.edge_arity.pairs_plural, 1, ...
    'the census must not need a schema to count an edge');
verifyEqual(testCase, ...
    arityOf(rep, 'a_class_no_schema_has_ever_declared', 'document_id', '2'), 1);
end

% ===================== the zeros, told apart ================================

function testABatchWithNoEdgesIsNotAPluralZero(testCase)
% "No document carries an edge" and "every document carries exactly one" are
% different facts and must be distinguishable from the report alone. The first
% is the census failing to fire; the second is a result.
docs = {docObj('subject', 'sub_1'), docObj('subject', 'sub_2')};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.edge_arity.docs_with_depends_on, 0, ...
    'a zero here is the "could not fire" state, not a clean result');
verifyEqual(testCase, rep.edge_arity.pairs_examined, 0);
verifyEqual(testCase, rep.edge_arity.pairs_plural, 0);
end

function testASingularOnlyBatchIsAMeasuredZero(testCase)
% The other zero: pairs WERE examined and none was plural. The two must not
% print the same numbers.
docs = {rowBody('r1', {'document_id'}, {'a'}), ...
        rowBody('r2', {'document_id'}, {'b'})};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.edge_arity.pairs_examined, 2, ...
    'the denominator is what makes this zero readable');
verifyEqual(testCase, rep.edge_arity.pairs_plural, 0);
verifyEmpty(testCase, rep.edge_arity.plural_by_family);
end

% ===================== parsing, and what it must not drop ==================

function testAnUnnamedEntryIsCountedNotSilentlyDropped(testCase)
% An entry with no usable `name` cannot be attributed to a family. Dropping it
% is correct; dropping it SILENTLY is how a denominator quietly stops describing
% the batch.
b = rowBody('r1', {'document_id'}, {'a'});
b.depends_on(end+1) = struct('name', '', 'value', 'orphaned');
rep = did2.validate.silentLoss({b});
verifyEqual(testCase, rep.edge_arity.edges_unnamed, 1);
verifyEqual(testCase, rep.edge_arity.edges_examined, 2, ...
    'the unnamed entry is still an entry that was looked at');
verifyEqual(testCase, rep.edge_arity.pairs_examined, 1);
end

function testACellValuedDependsOnIsRead(testCase)
% jsondecode returns a CELL whenever the dependency objects do not all carry
% the same keys, which is normal in this pipeline. A struct-only reader answers
% "no edges" for every one of those documents WITHOUT LOOKING AT ONE -- the
% exact shape bug that made edgeIsPopulated report "not populated" for every
% edge of a cell-valued depends_on.
b = bodyStruct('ontology_table_row', 'r1');
b.depends_on = {struct('name', 'document_id_1', 'value', 'a'), ...
                struct('name', 'document_id_2', 'document_id', 'b')};
rep = did2.validate.silentLoss({b});
verifyEqual(testCase, rep.edge_arity.edges_examined, 2);
verifyEqual(testCase, rep.edge_arity.pairs_plural, 1, ...
    'a cell-valued depends_on must be read, not skipped');
end

function testAnEdgeWhoseTailIsNotDigitsIsNotIndexed(testCase)
% `subject_id` must not fold to a family called `subject`. The fold is on a
% trailing `_<digits>` run and nothing else.
b = bodyStruct('term_observation', 'obs_1');
b.depends_on = struct('name', {'subject_id', 'instrument_id'}, ...
                      'value', {'sub_1', 'inst_1'});
rep = did2.validate.silentLoss({b});
verifyEqual(testCase, rep.edge_arity.indexed_edges_examined, 0);
verifyEqual(testCase, rep.edge_arity.pairs_examined, 2, ...
    'two differently-named edges are two families, not one plural family');
verifyEqual(testCase, rep.edge_arity.pairs_plural, 0);
end

function testTwoDistinctFamiliesOnOneDocumentAreTwoPairs(testCase)
% A document carrying one `document_id` and two `derived_from_#` members is
% plural in ONE family, not two, and contributes ONE plural pair -- but is
% counted ONCE in `docs_with_plural_family`. Three counters, three meanings.
b = bodyStruct('ontology_table_row', 'r1');
b.depends_on = struct( ...
    'name',  {'document_id', 'derived_from_1', 'derived_from_2'}, ...
    'value', {'a', 'b', 'c'});
rep = did2.validate.silentLoss({b});
ea = rep.edge_arity;
verifyEqual(testCase, ea.pairs_examined, 2);
verifyEqual(testCase, ea.pairs_plural, 1);
verifyEqual(testCase, ea.docs_with_plural_family, 1);
verifyEqual(testCase, ea.families_seen, 2);
verifyEqual(testCase, ea.plural_families_seen, 1);
verifyEqual(testCase, ...
    arityOf(rep, 'ontology_table_row', 'document_id', '1'), 1);
verifyEqual(testCase, ...
    arityOf(rep, 'ontology_table_row', 'derived_from', '2'), 1);
end

function testItAcceptsRealDocumentObjects(testCase)
% did2.document is the type v1_to_v2 hands in. The original silentLoss defect
% was that it could not read that type at all and reported total_docs = 0.
d = did2.document(rowBody('r1', {'document_id_1', 'document_id_2'}, ...
    {'a', 'b'}));
rep = did2.validate.silentLoss({d});
verifyEqual(testCase, rep.edge_arity.docs_inspected, 1);
verifyEqual(testCase, rep.edge_arity.pairs_plural, 1);
end

function testTheCensusRaisesNothingOnMalformedInput(testCase)
% The audit must never be able to break a migration.
verifyWarningFree(testCase, @() did2.validate.silentLoss({[]}));
verifyWarningFree(testCase, @() did2.validate.silentLoss(struct([])));
b = bodyStruct('ontology_table_row', 'r1');
b.depends_on = 42;                                  % not a struct, not a cell
verifyWarningFree(testCase, @() did2.validate.silentLoss({b}));
rep = did2.validate.silentLoss({b});
verifyEqual(testCase, rep.edge_arity.docs_classified, 1);
verifyEqual(testCase, rep.edge_arity.pairs_examined, 0);
end

% ===================== helpers =============================================

function n = arityOf(rep, className, edgeName, bucket)
%ARITYOF Documents in one (class, family, bucket) cell of the distribution.
%   0 when the row is absent, which is the same thing the digest renders.
n = 0;
rows = rep.edge_arity.arity_distribution;
for k = 1:numel(rows)
    if strcmp(rows(k).class_name, className) && ...
            strcmp(rows(k).edge_name, edgeName) && ...
            strcmp(rows(k).arity, bucket)
        n = rows(k).count;
        return;
    end
end
end

function b = rowBody(id, names, values)
%ROWBODY An `ontology_table_row` body carrying the named edges.
%   The class is the real one the question was asked about, and its edge is the
%   real one NDI writes: the template declares exactly
%   `depends_on: [{ "name": "document_id", "value": "" }]`
%   (ndi_common/database_documents/data/ontologyTableRow.json).
b = bodyStruct('ontology_table_row', id);
b.depends_on = struct('name', names, 'value', values);
b.ontology_table_row = struct('names', '', 'variable_names', '', ...
    'ontology_nodes', '', 'data', struct());
end

function d = docObj(className, id)
d = did2.document(bodyStruct(className, id));
end

function b = bodyStruct(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end

function tests = testRawV1RoundTripGene
%TESTRAWV1ROUNDTRIPGENE The spatial-transcriptomics family read as raw v1,
%   and its round trip: cellTypeLabels, geneExpression, geneList,
%   geneListMapping, spatialGeneExpressionCells, spatialGeneExpressionPyramid,
%   spatialGeneExpressionTiles, spatialGeneExpressionROI (migrators
%   cell_type_labels, gene_expression, gene_list, gene_list_mapping,
%   spatial_gene_expression_cells, _pyramid, _tiles, _roi, joined by
%   did2.convert.rawV1Classes' table).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim) in
%   the shapes +ndi/+fun/+doc/+gene/makeGeneList.m, makeCellTypeLabels.m,
%   makeCells.m and makePyramid.m (pyramid and tiles) give them, with the
%   files storeDoc attaches, through jsonencode/jsondecode. geneExpression (a
%   superclass block in NDI's writers) and geneListMapping have no writer at
%   that `main`: their fixtures are the templates' own values, edges set. No
%   corpus of the four zips holds any of the seven. spatialGeneExpressionROI is
%   built from its template at the locked NDI-matlab `main` 73f46d19 (the
%   class is newer than 3cb19a8) in the shape +ndi/+fun/+doc/+gene/makeROI.m
%   gives it, as fromGEFbyROI calls it (both edges set); it has no files.
%
%   geneList CONVERTS (Decided by Jess Haley, 2026-11-01 [gene list as a term,
%   file kept]): a standalone `term`, its genes.tsv the term's opaque_body
%   (testGeneList* below); since 2026-11-07 ([gene-list facts split],
%   [gene-list history entities]) its two namespaces are conditions on that
%   body and its annotation and assembly are Data Set entities it is derived
%   from. geneListMapping CONVERTS on a schema that declares
%   the covariate `index` (and, for a symmetric mapping, `relatum_id`): a
%   relation between the two lists, a `logical` or `score` value and
%   mapping.tsv as its opaque_body (testGeneListMapping* below, on a schema
%   copy that declares both until did-schema does). THE OTHER FIVE PASS
%   THROUGH pass 1 unchanged, as before. The one difference the
%   switch makes: the raw passthrough keeps v1's class name (the ROI, which
%   had no route at all and quarantined, now passes through the same way), under which V_eta
%   keeps no class, so it is counted as a passthrough with no schema where the
%   renamed one was validated against the snake_case class (a `retire` class);
%   NDI's last step stores the v1 source either way. No known findings.
tests = functiontests(localfunctions);
end

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
f = fixtures();
for k = 1:size(f, 1)
    verifyTrue(testCase, any(strcmp(names, f{k, 3})), f{k, 3});
    verifyEqual(testCase, did2.convert.rawV1Classes(f{k, 3}), f{k, 4}, f{k, 3});
end
r = runRaw(f(:, 2)');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, size(f, 1));
end

function testFixturesRoundTripAsPassthroughs(testCase)
f = passthroughFixtures();
for k = 1:size(f, 1)
    [label, v1] = f{k, 1:2};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
    verifyEqual(testCase, char(out.migrated{1}.get('document_class.class_name')), f{k, 3}, ...
        [label ': the raw passthrough keeps the v1 class name']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testTheV1ClassPassesThroughUnderItsV1Name(testCase)
% with validation: no quarantine, one passthrough, under the v1 class name
f = passthroughFixtures();
for k = 1:size(f, 1)
    [label, v1, v1Name] = f{k, 1:3};
    raw = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'did_v2');
    verifyEmpty(testCase, raw.quarantine, [label ': raw']);
    verifyEqual(testCase, numel(raw.passthrough), 1, label);
    verifyEqual(testCase, raw.passthrough(1).class_name, v1Name, label);
end
end

function testAFieldOutsideTheTemplateCarriesTheDocument(testCase)
v1 = geneList();
v1.geneList.species = 'Mus musculus';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: geneList.species');
v1 = did2.unittest.helpers.setDependency(tiles(), 'element_id', 'el_1');
verifyCarried(testCase, v1, 'depends_on(element_id)');
v1 = pyramid();
v1.geneExpression.normalisation = 'none';
verifyCarried(testCase, v1, 'geneExpression.normalisation');
v1 = cellTypeLabels();
v1.app = struct('name', 'scanpy');
verifyCarried(testCase, v1, 'unplaced: app');
v1 = roi();
v1.spatialGeneExpressionROI.area = 12;
verifyCarried(testCase, v1, 'spatialGeneExpressionROI.area');
v1 = did2.unittest.helpers.setDependency(roi(), 'subject_id', '41268b6f5c6a3d4e_6e00000000000001');
verifyCarried(testCase, v1, 'depends_on(subject_id)');
end

function testTheROIIsNoLongerQuarantined(testCase)
% before spatial_gene_expression_roi, no route named the class: a v1 ROI was
% quarantined (did2:convert:noMigrator). It now passes through unchanged.
v1 = roi();
out = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.passthrough), 1);
verifyEqual(testCase, out.passthrough(1).id, v1.base.id);
got = out.migrated{1}.toStruct();
verifyEqual(testCase, double(got.spatialGeneExpressionROI.vertices_x(:)'), [3088 3200 3150]);
verifyEqual(testCase, double(got.spatialGeneExpressionROI.vertices_y(:)'), [36362 36362 36500]);
end

function testADifferentSourceIsReportedLost(testCase)
v1 = pyramid();
out = runRaw(v1);
v1.spatialGeneExpressionPyramid.tile_rows = 3;
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'spatialGeneExpressionPyramid.tile_rows'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = geneList();
out = runRaw(v1);
extra = runRaw(cells()).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== geneList converts ================================
% Decided by Jess Haley, 2026-11-01 [gene list as a term, file kept] (did-schema
% did_v2_go_forward_class_audit.md; "A ok B ok c ok"), with [gene list mapping
% in the generic stage] (the v1 id is kept, so a mapping's edges resolve).

function testGeneListBecomesATermWithItsFile(testCase)
v1 = geneList();
out = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough);
verifyEqual(testCase, numel(out.migrated), 6);
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
names = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
verifyEqual(testCase, sort(names), ...
    {'directed_relation', 'directed_relation', 'entity', 'entity', 'opaque_body', 'term'});
term = docs{strcmp(names, 'term')};
body = docs{strcmp(names, 'opaque_body')};
% the term keeps the v1 id; its value is in its body
verifyEqual(testCase, term.base.id, v1.base.id);
verifyTrue(testCase, logical(term.value.data_body));
% the body: owned by the term, genes.tsv unchanged, TSV, one Gene dimension
% of n_genes, the label as notes
owner = body.depends_on(strcmp({body.depends_on.name}, 'owner_id'));
verifyEqual(testCase, {owner.document_id}, {v1.base.id});
verifyEqual(testCase, body.data_body.format.node, 'EDAM:format_3475');
verifyEqual(testCase, body.data.dimensions.n, 377);
verifyEqual(testCase, body.data.dimensions.term.node, 'NCIT:C16612');
verifyEqual(testCase, body.data_body.notes, 'xenium_panel');
verifyEqual(testCase, body.files.file_list, v1.files.file_list);
verifyEqual(testCase, body.files.file_info.name, 'genes.tsv');
end

function testGeneListNamespacesAreBodyConditions(testCase)
% [gene-list facts split], [namespace variable terms], [gene symbol
% namespace kept]: the two namespaces say how to read genes.tsv
docs = migratedStructs(geneList());
body = docs{strcmp(classNames(docs), 'opaque_body')};
conds = body.data_body.conditions;
if ~iscell(conds); conds = num2cell(conds); end
verifyEqual(testCase, numel(conds), 2);
verifyEqual(testCase, conds{1}.variable.node, 'EMPTY:0000436');
verifyEqual(testCase, conds{1}.text, 'ENSEMBL');
verifyEqual(testCase, conds{2}.variable.node, 'EMPTY:0000437');
verifyEqual(testCase, conds{2}.text, 'MGI');
end

function testGeneListHistoryIsAChainOfDataSets(testCase)
% [gene-list history entities]: gene list -> annotation -> assembly, each a
% Data Set named by the v1 text; [annotation source is GENEPIO]: each
% relation's one parameter keeps the v1 text
v1 = geneList();
docs = migratedStructs(v1);
names = classNames(docs);
ents = docs(strcmp(names, 'entity'));
rels = docs(strcmp(names, 'directed_relation'));
entNames = cellfun(@(e) e.entity.name, ents, 'UniformOutput', false);
verifyEqual(testCase, sort(entNames), {'GRCm39', 'Xenium panel v1'});
for k = 1:2
    verifyEqual(testCase, ents{k}.entity.type.node, 'NCIT:C47824');
end
ann = ents{strcmp(entNames, 'Xenium panel v1')};
asm = ents{strcmp(entNames, 'GRCm39')};
fromTerm = rels{cellfun(@(r) isequal(edge(r, 'child_id'), {v1.base.id}), rels)};
verifyEqual(testCase, edge(fromTerm, 'parent_id'), {ann.base.id});
verifyEqual(testCase, fromTerm.directed_relation.relation.node, 'prov:wasDerivedFrom');
verifyEqual(testCase, fromTerm.relation.method.parameters.variable.node, 'GENEPIO:0000096');
verifyEqual(testCase, fromTerm.relation.method.parameters.text, 'Xenium panel v1');
fromAnn = rels{cellfun(@(r) isequal(edge(r, 'child_id'), {ann.base.id}), rels)};
verifyEqual(testCase, edge(fromAnn, 'parent_id'), {asm.base.id});
verifyEqual(testCase, fromAnn.relation.method.parameters.variable.node, 'NCIT:C164815');
verifyEqual(testCase, fromAnn.relation.method.parameters.text, 'GRCm39');
end

function testGeneListWithOnlyAnAssembly(testCase)
% no annotation: the term is derived from the assembly directly, and the
% parameter's variable says which fact it is
v1 = geneList();
v1.geneList.annotation_source = '';
v1.geneList.gene_symbol_namespace = '';
out = runRaw(v1);
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sort(classNames(docs)), ...
    {'directed_relation', 'entity', 'opaque_body', 'term'});
rel = docs{strcmp(classNames(docs), 'directed_relation')};
verifyEqual(testCase, edge(rel, 'child_id'), {v1.base.id});
verifyEqual(testCase, rel.relation.method.parameters.variable.node, 'NCIT:C164815');
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'geneList, assembly only', ...
    {'geneList.gene_name_completeness', 'geneList.n_duplicate_gene_names'});
end

function testGeneListWithNoFacts(testCase)
% makeGeneList's defaults ('') write no condition, entity or relation
v1 = geneList();
for f = {'genome_assembly', 'annotation_source', 'gene_id_namespace', 'gene_symbol_namespace'}
    v1.geneList.(f{1}) = '';
end
out = runRaw(v1);
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sort(classNames(docs)), {'opaque_body', 'term'});
body = docs{strcmp(classNames(docs), 'opaque_body')};
verifyTrue(testCase, ~isfield(body.data_body, 'conditions') || isempty(body.data_body.conditions));
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'geneList, no facts', ...
    {'geneList.gene_name_completeness', 'geneList.n_duplicate_gene_names'});
end

function testGeneListListsNothingAsNotConverted(testCase)
% [no source-facts list]: the run's report holds gaps and carries only
out = runRaw(geneList());
notes = out.summary.migration_notes;
verifyFalse(testCase, isfield(notes, 'not_converted') ...
    && any(contains(notes.not_converted.distinct_details, 'geneList.')));
end

function testGeneListAnnotationIsNotTheRunsDataset(testCase)
% a reference Data Set (the annotation, the assembly) is not the dataset the
% migration record points at: the record points at the session
v1 = geneList();
out = runRaw(v1);
[records, report] = did2.convert.migrationRecord(out.migrated, 'Validate', false, ...
    'Version', 'test');
verifyNumElements(testCase, records, 2);
verifyNumElements(testCase, report, 1);
m = records{1}.toStruct();
verifyEqual(testCase, char(m.depends_on(strcmp({m.depends_on.name}, 'session_id')).document_id), ...
    char(v1.base.session_id));
end

function testGeneListRoundTrip(testCase)
% label, n_genes, the four source facts, the file and the identity come
% back; what item 21 drops as computable from genes.tsv
% (gene_name_completeness, n_duplicate_gene_names) is the known finding
v1 = geneList();
out = runRaw(v1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'geneList', ...
    {'geneList.gene_name_completeness', 'geneList.n_duplicate_gene_names'});
end

function testAGeneListNoWriterMakesIsCarried(testCase)
v1 = geneList();
v1.files = struct('file_list', {{}});
v1 = jsondecode(jsonencode(v1));
verifyCarried(testCase, v1, '[carry-120] files (no genes.tsv attached)');
v1 = geneList();
v1.geneList.n_genes = -1;
verifyCarried(testCase, v1, '[carry-120] geneList.n_genes');
v1 = geneList();
v1.base.name = 'my list';
verifyCarried(testCase, v1, '[carry-120] base.name');
v1 = geneList();
v1.geneList.genome_assembly = 39;
verifyCarried(testCase, v1, '[carry-120] geneList.genome_assembly (not text)');
end

% ===================== geneListMapping converts =========================
% Decided by Jess Haley, 2026-11-01 (did-schema did_v2_go_forward_class_audit.md):
% [gene list mapping value shape], [gene list mapping value kind], [gene list
% mapping method text], [orthology mapping has no method term], [gene list
% mapping leftovers], [gene list mapping other types carried], [mapping rows
% counted, indices 0-based], [key covariate index], [undirected relation
% widened], [undirected ends are relata].

function testGeneListMappingPassesThroughWithoutIndex(testCase)
% siblings first: on a schema that does not declare the covariate `index`
% the mapping passes through, as before
if schemaDeclaresIndex()
    return;
end
out = runRaw(geneListMapping());
verifyEqual(testCase, numel(out.passthrough), 1);
verifyEqual(testCase, char(out.migrated{1}.get('document_class.class_name')), 'geneListMapping');
end

function testGeneListMappingOrthologIsDirected(testCase)
useMappingSchema(testCase);
[v1, tsv] = orthologMapping();
out = runMapping(v1, tsv, true);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough);
[rel, val, body] = mappingDocs(testCase, out, 'directed_relation', 'score');
listA = '41268b6f5c6a3d4e_6e0000000000000a';
listB = '41268b6f5c6a3d4e_6e00000000000011';
% the relation: list A -> list B, the v1 id, the label as notes
verifyEqual(testCase, rel.base.id, v1.base.id);
verifyEqual(testCase, edge(rel, 'child_id'), {listA});
verifyEqual(testCase, edge(rel, 'parent_id'), {listB});
verifyEqual(testCase, rel.directed_relation.relation.node, 'EMPTY:0000386');
verifyEqual(testCase, rel.relation.notes, 'mouse to human orthologs');
% [orthology mapping has no method term]: only the tool text, as a parameter
verifyFalse(testCase, isfield(rel.relation.method, 'term') && ~isempty(rel.relation.method.term) ...
    && ~isempty(rel.relation.method.term.node));
verifyEqual(testCase, rel.relation.method.parameters.text, 'OrthoFinder v2.5.5');
% [gene-list method text is a description]: the parameter's variable
verifyEqual(testCase, rel.relation.method.parameters.variable.node, 'NCIT:C25365');
verifyEqual(testCase, edge(rel, 'value_id'), {val.base.id});
% the value: one gene-pair dimension of 3 ([gene pair term is NCIT Pair]),
% two gene covariates keyed to A and B
verifyEqual(testCase, val.data.dimensions.n, 3);
verifyEqual(testCase, val.data.dimensions.term.node, 'NCIT:C48046');
covs = val.data.covariates;
verifyEqual(testCase, [covs.key], [0 1]);
verifyEqual(testCase, double(covs(1).index(:)'), [417 418 418]);
verifyEqual(testCase, double(covs(2).index(:)'), [1902 2044 2045]);
verifyEqual(testCase, covs(1).variable.node, 'NCIT:C16612');
verifyEqual(testCase, edge(val, 'key_id'), {listA, listB});
verifyTrue(testCase, logical(val.value.data_body));
% the body: mapping.tsv unchanged, TSV, owned by the value
verifyEqual(testCase, edge(body, 'owner_id'), {val.base.id});
verifyEqual(testCase, body.data_body.format.node, 'EDAM:format_3475');
verifyEqual(testCase, body.files.file_info.name, 'mapping.tsv');
% [gene list mapping value kind]: the score's scale is a gap in the run's
% migration report ([migration record]), not in the document
gaps = did2.convert.migrationReport('gaps', val.base.id);
verifyEqual(testCase, {gaps.field}, {'value.scale'});
% round trip: nothing lost (the three counts are recomputed from the file)
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'geneListMapping ortholog', {});
end

function testGeneListMappingSymmetricAliasIsUndirected(testCase)
useMappingSchema(testCase);
[v1, tsv] = aliasMapping();
out = runMapping(v1, tsv, true);
verifyEmpty(testCase, out.quarantine);
[rel, val, ~] = mappingDocs(testCase, out, 'undirected_relation', 'logical');
verifyEqual(testCase, did2.build.relatumIds(rel), ...
    {'41268b6f5c6a3d4e_6e0000000000000a', '41268b6f5c6a3d4e_6e00000000000011'});
verifyEqual(testCase, rel.undirected_relation.relation.node, 'EMPTY:0000381');
% an alias mapping's method term is ID mapping, the v1 text its parameter
verifyEqual(testCase, rel.relation.method.term.node, 'EDAM:operation_3282');
verifyEqual(testCase, rel.relation.method.parameters.text, 'GEF geneID/geneName pairing');
verifyEqual(testCase, val.data.dimensions.n, 2);
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'geneListMapping alias', {});
end

function testGeneListMappingCarries(testCase)
useMappingSchema(testCase);
[v1, tsv] = orthologMapping();
% [mapping rows counted, indices 0-based]: n_pairs disagrees with the file
bad = v1;
bad.geneListMapping.n_pairs = 4;
verifyMappingCarried(testCase, bad, tsv, '[carry-120] geneListMapping.n_pairs');
bad = v1;
bad.geneListMapping.n_genes_mapped_a = 3;
verifyMappingCarried(testCase, bad, tsv, '[carry-120] geneListMapping.n_genes_mapped_a');
% a gene index that is not an integer >= 0
verifyMappingCarried(testCase, v1, strrep(tsv, '417', '-1'), '[carry-120] mapping.tsv');
% a score that is not a number
verifyMappingCarried(testCase, v1, strrep(tsv, '0.9', 'high'), '[carry-120] mapping.tsv');
% [gene list mapping other types carried]
bad = v1;
bad.geneListMapping.mapping_type = 'paralog';
verifyMappingCarried(testCase, bad, tsv, '[carry-166] geneListMapping.mapping_type');
% a mapping.tsv this run cannot read (no reader; its location is not here)
[carried, notes] = mappingCarry(v1, []);
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-167] files mapping.tsv'), notes);
end

function tf = schemaDeclaresIndex()
s = did2.schema.cache.shared().getClass('data');
tf = false;
f = s.fields;
if ~iscell(f); f = num2cell(f); end
for k = 1:numel(f)
    if strcmp(char(f{k}.name), 'covariates')
        sub = f{k}.fields;
        if ~iscell(sub); sub = num2cell(sub); end
        tf = any(cellfun(@(x) strcmp(char(x.name), 'index'), sub));
    end
end
end

function useMappingSchema(testCase)
src = did2.schema.cache.shared().schemaPath;
p = did2.unittest.helpers.geneMappingSchema(testCase, src);
did2.schema.cache.setSchemaPath(p);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
end

function out = runMapping(v1, tsv, validate)
reader = [];
if ~isempty(tsv)
    reader = @(~, name) tsvFor(name, tsv);
end
out = did2.convert.v1_to_v2({v1}, 'Validate', validate, 'TargetVersion', 'did_v2', ...
    'V1FileReader', reader);
end

function t = tsvFor(name, tsv)
if ~strcmp(name, 'mapping.tsv')
    error('test:noSuchFile', 'no %s', name);
end
t = tsv;
end

function [carried, notes] = mappingCarry(v1, tsv)
out = runMapping(v1, tsv, false);
carried = numel(out.migrated) == 1 ...
    && did2.schema.isV1Stamp(out.migrated{1}.toStruct(), 'Explicit', true);
notes = '';
if isfield(out.summary.migration_notes, 'carried_as_v1')
    notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' || ');
end
end

function verifyMappingCarried(testCase, v1, tsv, part)
[carried, notes] = mappingCarry(v1, tsv);
verifyTrue(testCase, carried, [part ': not carried']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', part, notes));
end

function [rel, val, body] = mappingDocs(testCase, out, relClass, valClass)
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
names = cellfun(@(d) char(d.document_class.class_name), docs, 'UniformOutput', false);
verifyEqual(testCase, sort(names), sort({relClass, valClass, 'opaque_body'}));
rel = docs{strcmp(names, relClass)};
val = docs{strcmp(names, valClass)};
body = docs{strcmp(names, 'opaque_body')};
end

function ids = edge(doc, name)
d = doc.depends_on;
if ~iscell(d); d = num2cell(d); end
ids = {};
for k = 1:numel(d)
    if strcmp(char(d{k}.name), name)
        ids{end+1} = char(d{k}.document_id); %#ok<AGROW>
    end
end
end

function [d, tsv] = orthologMapping()
d = geneListMapping();
d.geneListMapping = struct('label', 'mouse to human orthologs', 'mapping_type', 'ortholog', ...
    'method', 'OrthoFinder v2.5.5', 'symmetric', 0, 'n_pairs', 3, ...
    'n_genes_mapped_a', 2, 'n_genes_mapped_b', 3, 'has_score', 1);
d.files = storedFiles({'mapping.tsv'});
d = jsondecode(jsonencode(d));
tsv = sprintf('gene_index_a\tgene_index_b\tscore\n417\t1902\t0.9\n418\t2044\t0.5\n418\t2045\t0.4\n');
end

function [d, tsv] = aliasMapping()
d = geneListMapping();
d.geneListMapping = struct('label', '', 'mapping_type', 'alias', ...
    'method', 'GEF geneID/geneName pairing', 'symmetric', 1, 'n_pairs', 2, ...
    'n_genes_mapped_a', 2, 'n_genes_mapped_b', 2, 'has_score', 0);
d.files = storedFiles({'mapping.tsv'});
d = jsondecode(jsonencode(d));
tsv = sprintf('gene_index_a\tgene_index_b\n0\t5\n1\t7\n');
end

% ===================== fixtures =========================================

function f = passthroughFixtures()
% the five classes pass 1 still passes through (geneList and geneListMapping
% convert)
f = fixtures();
f = f(~ismember(f(:, 3), {'geneList', 'geneListMapping'}), :);
end

function f = fixtures()
% {label, v1, v1 class, migrator}
f = { ...
    'geneList, makeGeneList', geneList(), 'geneList', 'gene_list'; ...
    'spatialGeneExpressionPyramid, makePyramid', pyramid(), 'spatialGeneExpressionPyramid', ...
        'spatial_gene_expression_pyramid'; ...
    'spatialGeneExpressionTiles, makePyramid', tiles(), 'spatialGeneExpressionTiles', ...
        'spatial_gene_expression_tiles'; ...
    'spatialGeneExpressionCells, makeCells', cells(), 'spatialGeneExpressionCells', ...
        'spatial_gene_expression_cells'; ...
    'cellTypeLabels, makeCellTypeLabels', cellTypeLabels(), 'cellTypeLabels', 'cell_type_labels'; ...
    'geneExpression, template', geneExpression(), 'geneExpression', 'gene_expression'; ...
    'geneListMapping, template', geneListMapping(), 'geneListMapping', 'gene_list_mapping'; ...
    'spatialGeneExpressionROI, makeROI', roi(), 'spatialGeneExpressionROI', ...
        'spatial_gene_expression_roi'};
end

function fl = storedFiles(names)
% storeDoc: add_file per name (ingested into the database)
info = struct('name', names, 'locations', struct('delete_original', 1, ...
    'uid', '41268b6f5c6a3d4e_6e000000000000f1', 'location', '/tmp/ndi_gene_file', ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
fl = struct('file_list', {names}, 'file_info', info);
end

function d = geneList()
d = did2.unittest.helpers.ndiDocument('geneList', 'Id', '41268b6f5c6a3d4e_6e0000000000000a');
d.geneList = struct('label', 'xenium_panel', 'n_genes', 377, 'genome_assembly', 'GRCm39', ...
    'gene_id_namespace', 'ENSEMBL', 'gene_symbol_namespace', 'MGI', ...
    'annotation_source', 'Xenium panel v1', 'gene_name_completeness', 1, ...
    'n_duplicate_gene_names', 0);
d.files = storedFiles({'genes.tsv'});
d = jsondecode(jsonencode(d));
end

function d = pyramid()
d = did2.unittest.helpers.ndiDocument('spatialGeneExpressionPyramid', ...
    'Id', '41268b6f5c6a3d4e_6e0000000000000b');
d.spatialGeneExpressionPyramid = struct('label', 'section_1', 'chip_serial', 'X123', ...
    'pipeline_version', '2.0', 'bin_sizes', [1 2 4 8 16 32], 'base_pixel_size_x', 0.5, ...
    'base_pixel_size_y', 0.5, 'pixel_size_units', 'micrometer', 'origin_x', 10, 'origin_y', 20, ...
    'extent_x', 4000, 'extent_y', 3000, 'tile_rows', 9, 'tile_columns', 9, ...
    'index_order', 'row-major', 'origin_corner', 'upper-left', 'byte_order', 'little');
d.geneExpression = struct('assay', 'Xenium', 'count_type', 'raw', 'count_units', 'UMI');
d = did2.unittest.helpers.setDependency(d, 'geneList_id', '41268b6f5c6a3d4e_6e0000000000000a');
d = did2.unittest.helpers.setDependency(d, 'subject_id', '41268b6f5c6a3d4e_6e00000000000001');
d.files = storedFiles({'gene_totals.tsv'});
d = jsondecode(jsonencode(d));
end

function d = tiles()
d = did2.unittest.helpers.ndiDocument('spatialGeneExpressionTiles', ...
    'Id', '41268b6f5c6a3d4e_6e0000000000000c');
d.spatialGeneExpressionTiles = struct('label', 'bin2', 'bin_size', 2, 'pixel_size_x', 1, ...
    'pixel_size_y', 1, 'pixel_size_units', 'micrometer', 'dimension_order', 'YXG', ...
    'dimension_labels', 'height,width,gene', 'dimension_size', [1500 2000 377], ...
    'dimension_scale', [1 1 1], 'dimension_scale_units', 'micrometer,micrometer,dimensionless', ...
    'tile_size_x_bins', 223, 'tile_size_y_bins', 167, 'n_tiles_stored', 2, ...
    'data_type_gene_index', 'uint32', 'data_type_count', 'uint16', 'data_type_offset', 'uint32', ...
    'data_type_coordinate', 'uint16', 'tile_compression', 'none', 'tile_format_version', 1, ...
    'tile_index_origin', 1);
d = did2.unittest.helpers.setDependency(d, 'spatialGeneExpressionPyramid_id', '41268b6f5c6a3d4e_6e0000000000000b');
d = did2.unittest.helpers.setDependency(d, 'subject_id', '41268b6f5c6a3d4e_6e00000000000001');
d.files = storedFiles({'tile.bin_1', 'tile.bin_2'});
d = jsondecode(jsonencode(d));
end

function d = cells()
d = did2.unittest.helpers.ndiDocument('spatialGeneExpressionCells', ...
    'Id', '41268b6f5c6a3d4e_6e0000000000000d');
d.spatialGeneExpressionCells = struct('label', 'cells', 'n_cells', 1200, ...
    'segmentation_method', 'xenium', 'segmentation_dilation', 0, 'coordinate_units', 'micrometer', ...
    'contours_present', 1, 'contour_reference', 'centroid', 'n_vertices_per_cell', 13, ...
    'data_type_vertex', 'int16', 'data_type_offset', 'uint32', 'contour_format_version', 1);
d = did2.unittest.helpers.setDependency(d, 'spatialGeneExpressionPyramid_id', '41268b6f5c6a3d4e_6e0000000000000b');
d = did2.unittest.helpers.setDependency(d, 'subject_id', '41268b6f5c6a3d4e_6e00000000000001');
d.files = storedFiles({'cells.tsv', 'contours.bin'});
d = jsondecode(jsonencode(d));
end

function d = cellTypeLabels()
d = did2.unittest.helpers.ndiDocument('cellTypeLabels', 'Id', '41268b6f5c6a3d4e_6e0000000000000e');
d.cellTypeLabels = struct('label', 'types', 'label_name', 'cell_type', 'taxonomy_level', 'class', ...
    'n_cells', 1200, 'n_categories', 9, 'n_unlabeled', 14, 'assignment_method', 'leiden', ...
    'is_unsupervised', 1);
d = did2.unittest.helpers.setDependency(d, 'cells_document_id', '41268b6f5c6a3d4e_6e0000000000000d');
d.files = storedFiles({'labels.tsv'});
d = jsondecode(jsonencode(d));
end

function d = roi()
% makeROI as fromGEFbyROI calls it: the pyramid built from the records inside
% the polygon and the shared source file, both edges set; no files
d = did2.unittest.helpers.ndiDocument('spatialGeneExpressionROI', ...
    'Id', '41268b6f5c6a3d4e_6e00000000000012');
polygon = [3088 36362; 3200 36362; 3150 36500];
d.spatialGeneExpressionROI = struct('label', 'subject 1', 'n_vertices', size(polygon, 1), ...
    'vertices_x', polygon(:, 1), 'vertices_y', polygon(:, 2), ...
    'coord_space', 'gef_base_pixel', 'coord_units', 'pixel', 'n_records_in', 5821, ...
    'roi_format_version', 1);
d = did2.unittest.helpers.setDependency(d, 'spatialGeneExpressionPyramid_id', '41268b6f5c6a3d4e_6e0000000000000b');
d = did2.unittest.helpers.setDependency(d, 'source_file_id', '41268b6f5c6a3d4e_6e00000000000013');
d = jsondecode(jsonencode(d));
end

function d = geneExpression()
d = did2.unittest.helpers.ndiDocument('geneExpression', 'Id', '41268b6f5c6a3d4e_6e0000000000000f');
d = jsondecode(jsonencode(d));
end

function d = geneListMapping()
d = did2.unittest.helpers.ndiDocument('geneListMapping', 'Id', '41268b6f5c6a3d4e_6e00000000000010');
d = did2.unittest.helpers.setDependency(d, 'geneList_id_a', '41268b6f5c6a3d4e_6e0000000000000a');
d = did2.unittest.helpers.setDependency(d, 'geneList_id_b', '41268b6f5c6a3d4e_6e00000000000011');
d = jsondecode(jsonencode(d));
end

% ===================== helpers =========================================

function docs = migratedStructs(v1)
out = runRaw(v1);
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
end

function names = classNames(docs)
names = cellfun(@(d) char(d.document_class.class_name), docs, 'UniformOutput', false);
end

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end

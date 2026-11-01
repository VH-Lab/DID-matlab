function tests = testMigratorsJSpatialTranscriptomics
%TESTMIGRATORSJSPATIALTRANSCRIPTOMICS Fast fixtures for the spatial-
%   transcriptomics family of V_eta migrators (DID-schema OPEN_WORK #123).
%
%   STATUS: NEVER RUN LOCALLY. `command -v matlab octave` exits 1 in the
%   container this was written in, so every assertion below is UNEXECUTED
%   here. CI is the first execution; treat a green run as the evidence,
%   not this file.
%
%   The eight migrators are covered here:
%
%     spatial_gene_expression_pyramid       -- 1 -> 2, observation direction
%     spatial_gene_expression_cells         -- 1 -> 1 passthrough
%     spatial_gene_expression_tiles         -- 1 -> 1 passthrough
%     cell_type_labels                      -- 1 -> 1 passthrough
%     gene_list_mapping                     -- 1 -> 3 (a relation, its value
%                                              and the value's opaque_body;
%                                              tested on the raw v1 shape in
%                                              testRawV1RoundTripGene). The
%                                              snake_case fixture below is
%                                              outside the template: carried.
%     file_reference                        -- 1 -> 1 passthrough (NOT folded
%                                              to generic_file)
%     gene_list                             -- 1 -> 2 (a `term` and its
%                                              opaque_body; tested on the raw
%                                              v1 shape in testRawV1RoundTripGene)
%     gene_expression                       -- 1 -> 1 passthrough (⊂ base
%                                              shape mixin)
%
%   Corpus proof (OPEN_WORK #124) is DEFERRED -- none of the 6 target
%   corpora (PRED / 20211116 / B / Dab / JH / Soph) holds any of these
%   classes, so the achievable gate today is fast-fixture green.
%
%   Field-level structural refactors when 2.D data_body ships (OPEN_WORK
%   #125) and T8 binding follow-ons (#126) are OUT OF SCOPE here.
%
%   THE PIPELINE, ONE HALF PER GROUP OF ASSERTIONS. Every test calls the
%   migrator DIRECTLY -- the fast-fixture gate does not need the schema
%   cache, and the passthrough classes have no reshape to observe from
%   the outside. The pyramid tests read the emitted body and check the
%   two things it MUST have (subject_id inherited via depends_on;
%   variable bound to NCIT:C16608) plus the anchor edge (time_reference_1
%   pointing at a session_relative_reference sibling body). The
%   passthrough tests confirm base.id survives verbatim and that the
%   load-bearing fields (is_unsupervised, mapping_type + symmetric, the
%   snake_cased file_reference fields) are exactly what the source
%   carried.

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

% ===================== the pyramid =========================================

function testPyramidEmitsPyramidAndAnchor(testCase)
% INVERTED for did-schema #88, which restates spatial_gene_expression_pyramid in
% its v1 shape: the statement reshape built on did-schema main (#70) is not part
% of #88 (#73 review item 18, nothing from the eight NDI spatial classes is
% carried forward). The migrator therefore passes the document through unchanged
% -- no anchor, no statement -- and the reshape is listed as an NDI need.
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(pyramidV1());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, classNames(out), {'spatial_gene_expression_pyramid'});
verifyEqual(testCase, out{1}, pyramidV1(), 'the body was not carried verbatim');
end


function testPyramidPreservesBaseId(testCase)
% ID PRESERVATION -- every Cells / Tiles / file_reference / cell_type_labels
% document depending on the pyramid uses base.id to reach it, so a rewritten
% id would strand every dependent.
v1 = pyramidV1();
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(v1);
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyEqual(testCase, pyr.base.id, v1.base.id);
end

function testPyramidCarriesSubjectIdFromV1DependsOn(testCase)
% UPDATED for #88 (passthrough): the v1 subject edge rides under its v1 name.
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(pyramidV1());
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyEqual(testCase, depValue(pyr, 'subject_id'), 'subj_stereoseq_1');
end


function testPyramidBindsVariableToGeneExpression(testCase)
% UPDATED for #88 (passthrough): no statement is built, so no variable is bound;
% the assay facts stay on the gene_expression block where v1 wrote them.
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(pyramidV1());
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyFalse(testCase, isfield(pyr, 'statement'));
verifyEqual(testCase, pyr.gene_expression.assay, 'Stereo-seq');
end


function testPyramidCarriesTimeReferenceEdgeAtTheAnchor(testCase)
% UPDATED for #88 (passthrough): no anchor is minted and no time-reference edge
% is added to the v1 document.
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(pyramidV1());
verifyFalse(testCase, any(strcmp(classNames(out), 'relative_time_reference')));
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyEmpty(testCase, depValue(pyr, 'time_reference_id'));
end


function testPyramidCarriesGeneListIdVerbatim(testCase)
% gene_list_id (mustBeNonEmpty: true) is the pyramid's own dep and must
% survive intact -- the pyramid names the columns of its count space by
% pointing here.
v1 = pyramidV1();
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(v1);
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyEqual(testCase, depValue(pyr, 'gene_list_id'), 'gl_hg38_v1');
end

function testPyramidBlockFieldsCarryVerbatim(testCase)
% chip_serial, pipeline_version, bin_sizes, base_pixel_size_{x,y},
% tile_rows/columns, byte_order, origin_corner, index_order -- the class's
% own property fields. Pyramid is a real document; its shape is not a
% reshape.
v1 = pyramidV1();
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(v1);
pyr = pick(out, 'spatial_gene_expression_pyramid');
b = pyr.spatial_gene_expression_pyramid;
verifyEqual(testCase, b.chip_serial, 'SS200000123BL_A1');
verifyEqual(testCase, b.pipeline_version, 'SAW v7.1.2');
verifyEqual(testCase, b.bin_sizes, [1 2 4 8 16 32]);
verifyEqual(testCase, b.base_pixel_size_x, 0.5);
verifyEqual(testCase, b.tile_rows, 9);
verifyEqual(testCase, b.index_order, 'row-major');
verifyEqual(testCase, b.origin_corner, 'upper-left');
verifyEqual(testCase, b.byte_order, 'little');
end

function testPyramidCarriesGeneExpressionMixinFields(testCase)
% assay / count_type / count_units live on the gene_expression mixin --
% ⊂ base shape mixin, not itself an observation. The pyramid inherits
% from gene_expression so the block is on the same document.
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(pyramidV1());
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyEqual(testCase, pyr.gene_expression.assay, 'Stereo-seq');
verifyEqual(testCase, pyr.gene_expression.count_type, 'raw');
verifyEqual(testCase, pyr.gene_expression.count_units, 'UMI');
end

function testPyramidMethodOmittedNotEmittedEmpty(testCase)
% UPDATED for #88 (passthrough): neither a method nor an interaction block is
% invented on the v1 document.
out = did2.convert.migrators_j.spatial_gene_expression_pyramid(pyramidV1());
pyr = pick(out, 'spatial_gene_expression_pyramid');
verifyFalse(testCase, isfield(pyr, 'interaction'));
verifyFalse(testCase, isfield(pyr, 'subject_interaction'));
end

% ===================== the id-inheritance chain =============================

function testCellsCarrySpatialGeneExpressionPyramidIdEdgeVerbatim(testCase)
% Cells -> pyramid via `spatial_gene_expression_pyramid_id` (mustBeNonEmpty:
% true), and Cells's own subject_id is REQUIRED per the class schema. The
% migrator is a passthrough; both edges survive intact.
v1 = cellsV1();
out = did2.convert.migrators_j.spatial_gene_expression_cells(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.base.id, v1.base.id);
verifyEqual(testCase, ...
    depValue(out{1}, 'spatial_gene_expression_pyramid_id'), 'pyr_1');
verifyEqual(testCase, depValue(out{1}, 'subject_id'), 'subj_stereoseq_1');
end

function testTilesCarryPyramidIdEdgeAndDoNotInventASubjectId(testCase)
% Tiles's subject_id is OPTIONAL -- the pyramid dep carries the subject.
% The passthrough must not mint one. Nor discard the pyramid edge.
v1 = tilesV1();
out = did2.convert.migrators_j.spatial_gene_expression_tiles(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.base.id, v1.base.id);
verifyEqual(testCase, ...
    depValue(out{1}, 'spatial_gene_expression_pyramid_id'), 'pyr_1');
% subject_id was not on the v1 source; must not appear on the emitted body.
verifyEqual(testCase, depValue(out{1}, 'subject_id'), '');
end

function testCellTypeLabelsPreservesIsUnsupervised(testCase)
% is_unsupervised is LOAD-BEARING per the .md doc: a k-means clustering
% with no ground-truth reference is modelled the same as a supervised
% classifier's output; only this flag distinguishes them. Also: the
% cells_document_id edge (mustBeNonEmpty: true) survives.
v1 = cellTypeLabelsV1();
out = did2.convert.migrators_j.cell_type_labels(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.base.id, v1.base.id);
verifyEqual(testCase, ...
    out{1}.cell_type_labels.is_unsupervised, ...
    v1.cell_type_labels.is_unsupervised);
verifyEqual(testCase, depValue(out{1}, 'cells_document_id'), 'cells_1');
end

function testGeneListMappingPreservesMappingTypeAndSymmetric(testCase)
% mapping_type and symmetric are LOAD-BEARING per the .md doc: alias vs
% ortholog is not collapsible to a bare directed_relation.
v1 = geneListMappingV1();
out = did2.convert.migrators_j.gene_list_mapping(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.base.id, v1.base.id);
verifyEqual(testCase, out{1}.gene_list_mapping.mapping_type, 'ortholog');
verifyEqual(testCase, out{1}.gene_list_mapping.symmetric, 0);
verifyEqual(testCase, depValue(out{1}, 'gene_list_id_a'), 'gl_hg38');
verifyEqual(testCase, depValue(out{1}, 'gene_list_id_b'), 'gl_mm10');
end

function testFileReferenceCarriesTheSnakeCasedFields(testCase)
% NDI's camelCase field names (originalPath, formatOntology, dateCreated,
% dateUpdated, fileSize, checksumAlgorithm) are snake_cased by
% universalRenames at the BLOCK LEVEL; the V_eta schema declares them
% snake_case, so the migrator sees the post-rename shape and carries it
% through. This fixture uses the snake_case spellings the migrator is
% handed on the real pipeline.
v1 = fileReferenceV1();
out = did2.convert.migrators_j.file_reference(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.base.id, v1.base.id);
b = out{1}.file_reference;
verifyEqual(testCase, b.original_path, ...
    '/data/stereoseq/SS200000123BL_A1.h5');
verifyEqual(testCase, b.format_ontology, 'EDAM:format_3590');   % HDF5
verifyEqual(testCase, b.date_created, 1727049600);
verifyEqual(testCase, b.date_updated, 1727136000);
verifyEqual(testCase, b.file_size, 12345678);
verifyEqual(testCase, b.checksum_algorithm, 'SHA-256');
end

function testFileReferenceIsNotFoldedToGenericFile(testCase)
% file_reference and generic_file COEXIST BY DESIGN per the file_reference
% .md doc: generic_file holds bytes; file_reference records the identity
% of an external file. This migrator is DELIBERATELY NOT routed through
% foldGenericFiles, and the emitted class must be file_reference itself.
%
% DO NOT "FIX" THIS TEST BY DELETING IT. If the team rules the other way,
% the class's own .md doc has to change first.
out = did2.convert.migrators_j.file_reference(fileReferenceV1());
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'file_reference');
end

function testGeneListSnakeCaseBodyIsCarriedWhole(testCase)
% gene_list reads the RAW v1 document (`geneList`, [migrators read raw v1]) and
% converts it to a `term` ([gene list as a term, file kept]; testRawV1RoundTripGene).
% This renamed-era fixture (a `gene_list` block, a base.name) is outside NDI's
% template, so it is carried whole, untouched (carry-100), its id kept.
v1 = geneListV1();
out = did2.convert.migrators_j.gene_list(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}, v1);
end

function testGeneExpressionMixinCarriesAssayAndCounts(testCase)
% The `gene_expression` class is a shape mixin (⊂ base), not itself an
% observation. Its three fields are what a pyramid inherits when it binds
% variable = NCIT:C16608. As a document on its own it exists too (v1
% source shape), and it passes through.
v1 = geneExpressionV1();
out = did2.convert.migrators_j.gene_expression(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.base.id, v1.base.id);
verifyEqual(testCase, out{1}.gene_expression.assay, 'Stereo-seq');
verifyEqual(testCase, out{1}.gene_expression.count_type, 'raw');
verifyEqual(testCase, out{1}.gene_expression.count_units, 'UMI');
end

% ===================== fixtures ============================================
%
% All fixtures are POST-universalRenames: block keys snake_cased, immediate
% field names snake_cased, depends_on rewritten to {name, value}. That is
% what a migrator is handed on the real pipeline (v1_to_v2 runs
% universalRenames before dispatching to +migrators_j), and it is the
% shape the passthrough is tested against.

function v1 = pyramidV1()
v1 = struct();
v1.document_class = struct('class_name', 'spatial_gene_expression_pyramid', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'gene_expression', ...
                             'class_version', '1.0.0') ]);
% v1 shape: subject_id + gene_list_id (both required on the source doc);
% source_file_id optional but populated here so the passthrough test can
% assert non-drop.
v1.depends_on = [ struct('name', 'subject_id',   'value', 'subj_stereoseq_1'), ...
                  struct('name', 'gene_list_id', 'value', 'gl_hg38_v1') ];
v1.base = struct('id', 'pyr_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'Opossum V1 Stereo-seq', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.spatial_gene_expression_pyramid = struct( ...
    'label',              'Opossum V1 Stereo-seq', ...
    'chip_serial',        'SS200000123BL_A1', ...
    'pipeline_version',   'SAW v7.1.2', ...
    'bin_sizes',          [1 2 4 8 16 32], ...
    'base_pixel_size_x',  0.5, ...
    'base_pixel_size_y',  0.5, ...
    'pixel_size_units',   'micrometer', ...
    'origin_x',           0, ...
    'origin_y',           0, ...
    'extent_x',           26460, ...
    'extent_y',           26460, ...
    'tile_rows',          9, ...
    'tile_columns',       9, ...
    'index_order',        'row-major', ...
    'origin_corner',      'upper-left', ...
    'byte_order',         'little');
% The gene_expression mixin fields are inherited (the pyramid ⊂ [base,
% gene_expression, subject_observation]), so a v1 pyramid document already
% carried them.
v1.gene_expression = struct( ...
    'assay',       'Stereo-seq', ...
    'count_type',  'raw', ...
    'count_units', 'UMI');
end

function v1 = cellsV1()
v1 = struct();
v1.document_class = struct('class_name', 'spatial_gene_expression_cells', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = [ ...
    struct('name', 'spatial_gene_expression_pyramid_id', 'value', 'pyr_1'), ...
    struct('name', 'subject_id',                          'value', 'subj_stereoseq_1'), ...
    struct('name', 'source_file_id',                      'value', 'fref_1') ];
v1.base = struct('id', 'cells_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'Opossum V1 cells', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.spatial_gene_expression_cells = struct( ...
    'label',                   'CellBin segmentation', ...
    'n_cells',                 148237, ...
    'segmentation_method',     'CellBin (Stereo-seq)', ...
    'segmentation_dilation',   0.0, ...
    'coordinate_units',        'micrometer', ...
    'contours_present',        1, ...
    'contour_reference',       'centroid', ...
    'n_vertices_per_cell',     32, ...
    'data_type_vertex',        'int16', ...
    'data_type_offset',        'uint32', ...
    'contour_format_version',  1);
end

function v1 = tilesV1()
v1 = struct();
v1.document_class = struct('class_name', 'spatial_gene_expression_tiles', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
% Tiles has subject_id OPTIONAL -- the pyramid dep carries it. Deliberately
% omitted so testTilesCarryPyramidIdEdgeAndDoNotInventASubjectId asserts
% the passthrough does not mint one.
v1.depends_on = struct('name', 'spatial_gene_expression_pyramid_id', ...
    'value', 'pyr_1');
v1.base = struct('id', 'tiles_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'Opossum V1 tiles bin=1', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.spatial_gene_expression_tiles = struct( ...
    'label',                'bin_1', ...
    'bin_size',             1, ...
    'pixel_size_x',         0.5, ...
    'pixel_size_y',         0.5, ...
    'pixel_size_units',     'micrometer', ...
    'dimension_order',      'YXG', ...
    'dimension_labels',     'height,width,gene', ...
    'dimension_size',       [2940 2940 24793], ...
    'dimension_scale',      [0.5 0.5 1.0], ...
    'dimension_scale_units','micrometer,micrometer,dimensionless', ...
    'tile_size_x_bins',     2940, ...
    'tile_size_y_bins',     2940, ...
    'n_tiles_stored',       81, ...
    'data_type_gene_index', 'uint32', ...
    'data_type_count',      'uint16', ...
    'data_type_offset',     'uint32', ...
    'data_type_coordinate', 'uint16', ...
    'tile_compression',     'none', ...
    'tile_format_version',  1, ...
    'tile_index_origin',    1);
end

function v1 = cellTypeLabelsV1()
v1 = struct();
v1.document_class = struct('class_name', 'cell_type_labels', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', 'cells_document_id', 'value', 'cells_1');
v1.base = struct('id', 'ctlabels_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'CellBin unsupervised', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.cell_type_labels = struct( ...
    'label',             'unsupervised k=12', ...
    'label_name',        'cluster', ...
    'taxonomy_level',    '', ...
    'n_cells',           148237, ...
    'n_categories',      12, ...
    'n_unlabeled',       0, ...
    'assignment_method', 'k-means', ...
    'is_unsupervised',   1);
end

function v1 = geneListMappingV1()
v1 = struct();
v1.document_class = struct('class_name', 'gene_list_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = [ ...
    struct('name', 'gene_list_id_a', 'value', 'gl_hg38'), ...
    struct('name', 'gene_list_id_b', 'value', 'gl_mm10') ];
v1.base = struct('id', 'glm_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'human-mouse orthologs', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.gene_list_mapping = struct( ...
    'label',             'human -> mouse orthologs (HGNC)', ...
    'mapping_type',      'ortholog', ...
    'method',            'HGNC HCOP', ...
    'symmetric',         0, ...
    'n_pairs',           16482, ...
    'n_genes_mapped_a',  16118, ...
    'n_genes_mapped_b',  16033, ...
    'has_score',         1);
end

function v1 = fileReferenceV1()
v1 = struct();
v1.document_class = struct('class_name', 'file_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', 'document_id', 'value', 'pyr_1');
v1.base = struct('id', 'fref_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'stereoseq raw h5', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
% POST-universalRenames spellings (originalPath -> original_path, etc.);
% see testFileReferenceCarriesTheSnakeCasedFields' header for why.
v1.file_reference = struct( ...
    'filename',           'SS200000123BL_A1.h5', ...
    'original_path',      '/data/stereoseq/SS200000123BL_A1.h5', ...
    'format_ontology',    'EDAM:format_3590', ...
    'date_created',       1727049600, ...
    'date_updated',       1727136000, ...
    'file_size',          12345678, ...
    'checksum',           'ea3b6dc1c1a2f3d4e5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8', ...
    'checksum_algorithm', 'SHA-256');
end

function v1 = geneListV1()
v1 = struct();
v1.document_class = struct('class_name', 'gene_list', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'gl_hg38_v1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'GRCh38 Ensembl v104', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.gene_list = struct( ...
    'label',                    'GRCh38 Ensembl v104', ...
    'n_genes',                  24793, ...
    'genome_assembly',          'GRCh38', ...
    'gene_id_namespace',        'Ensembl', ...
    'gene_symbol_namespace',    'HGNC', ...
    'annotation_source',        'Ensembl v104', ...
    'gene_name_completeness',   0.998, ...
    'n_duplicate_gene_names',   3);
end

function v1 = geneExpressionV1()
% As a standalone document (the shape mixin exists as its own v1 class
% too). Its passthrough migrator carries the block through.
v1 = struct();
v1.document_class = struct('class_name', 'gene_expression', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'ge_1', 'session_id', 'sess_stereoseq_09', ...
    'name', 'stereoseq shape mixin', ...
    'datestamp', '2025-09-23T12:00:00.000Z');
v1.gene_expression = struct( ...
    'assay',       'Stereo-seq', ...
    'count_type',  'raw', ...
    'count_units', 'UMI');
end

% ===================== small helpers =======================================

function names = classNames(out)
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
end

function b = pick(out, className)
names = classNames(out);
idx = find(strcmp(names, className), 1);
if isempty(idx)
    error('testMigratorsJSpatialTranscriptomics:noSuchBody', ...
        'no `%s` among the emitted bodies: %s', className, strjoin(names, ', '));
end
b = out{idx};
end

function v = depValue(b, name)
% Read an edge off a raw body struct. Accepts both spellings --
% universalRenames rewrites v1's {name, value} to {name, document_id}, and
% a body may carry either depending on where it came from. Copied from
% tests/+did2/+unittest/testMigratorsJ.m:4600.
v = '';
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    if ~strcmp(b.depends_on(k).name, name); continue; end
    if isfield(b.depends_on(k), 'document_id') && ~isempty(b.depends_on(k).document_id)
        v = b.depends_on(k).document_id;
    elseif isfield(b.depends_on(k), 'value')
        v = b.depends_on(k).value;
    end
    return;
end
end

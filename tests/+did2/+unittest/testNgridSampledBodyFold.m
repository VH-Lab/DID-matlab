function tests = testNgridSampledBodyFold
%TESTNGRIDSAMPLEDBODYFOLD The `ngrid` -> `sampled_body` fold, and its two guards.
%
%   STATUS: NEVER RUN LOCALLY. There is no MATLAB and no Octave in the container
%   these were written in, so every assertion below is unexecuted here. CI is the
%   first execution. Treat a green run as the evidence, not this file.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST  (#47)
%   ---------------------------------------------------------------------
%   TEAM DECISION (jess, in session, 2026-08-11): "The ngrid documents should be
%   migrated into sampled_bodys. However, the sampled_body needs a corresponding
%   subject_statement. For ontology_image, that's most likely an
%   image_observation."
%
%   Built as a third arm on +migrators_j/ontology_image.m, keyed on the SUBJECT
%   rather than on the vintage, with the mapping in the shared private helper
%   jNgridBody so the RF fold (#48) can reuse it. Two guards, tested in both
%   directions because a guard that fires on everything passes the same tests a
%   correct one does:
%
%     GUARD 1 (SUBJECT)      no subject => no observation, and no body either.
%                            The document passes through intact. This is the
%                            arm every real NDI document takes -- see guard 3
%                            below -- and it is the 4,563-husk lesson.
%     GUARD 2 (COORDINATES)  explicit coordinate positions are REFUSED, because
%                            `sampled_body.axes[]` declares {name, kind, length,
%                            regularity, spacing, unit} and NO coordinate array.
%                            The decided destination `axes[k].values` is #45,
%                            blocked on #32. Folding anyway would delete real
%                            data -- the exact loss +super/ngrid.m was written
%                            to stop, arriving through a different door.
%
%   ---------------------------------------------------------------------
%   PROVENANCE OF THE FIXTURES, STATED RATHER THAN ASSUMED
%   ---------------------------------------------------------------------
%   The `ngrid` block in every fixture below is the FOUR-FIELD shape NDI's only
%   writer produces, read from the writer and not from any DID-side schema:
%
%     $ git show origin/main:src/ndi/+ndi/+fun/+data/mat2ngrid.m
%         ngrid.data_size   = props.bytes/numel(x)
%         ngrid.data_type   = class(x)
%         ngrid.data_dim    = size(x)
%         ngrid.coordinates = [(1:d1)'; ... ; (1:dn)']     when nargin == 1
%     $ git show origin/main:src/ndi/+ndi/+setup/+NDIMaker/imageDocMaker.m
%         :121  ngrid_struct = ndi.fun.data.mat2ngrid(image);   <- ONE argument
%         :144  doc.add_file('ontologyImage.ngrid', filepath);
%
%   THE SUBJECT-BEARING FIXTURE IS CONSTRUCTED, AND THAT IS SAID OUT LOUD.
%   No NDI writer emits an `ontologyImage` carrying both a raster and a subject
%   edge: `createOntologyImageDoc` takes `options.ontologyTableRow_id` and
%   nothing else, and the (fabricated) vintage A that does carry `element_id`
%   has no `ngrid` block. So `foldableOntologyImage()` is the v1 ngrid block
%   plus a subject edge, assembled here to exercise an arm that today's writers
%   cannot reach. It is NOT evidence that such documents exist, and
%   testNoRealNDIShapeCanReachTheFoldArm pins that distinction so the fixture
%   cannot be mistaken for a population.

tests = functiontests(localfunctions);
end

% ===================== the fold ============================================

function testNgridFoldsToASampledBodyBesideAnImageObservation(testCase)
% 1 -> 4: the term_observation this migrator already emitted, the
% image_observation the team named, the sampled_body carrying the grid, and the
% shared session anchor.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 4, ...
    sprintf('expected 4 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyTrue(testCase, ismember('term_observation', names));
verifyTrue(testCase, ismember('image_observation', names));
verifyTrue(testCase, ismember('sampled_body', names));
verifyTrue(testCase, ismember('session_relative_reference', names));
end

function testTheBodyIsBoundToTheImageObservationNotTheTermObservation(testCase)
% The `statement` edge is what makes a body findable from the subject side, and
% pointing it at the wrong sibling would be invisible to every gate: both are
% real documents, so the edge resolves and no orphan is reported. The body IS
% the picture; the term says what the picture depicts.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
imgObs = pick(out, 'image_observation');
body   = pick(out, 'sampled_body');
verifyEqual(testCase, depValueOf(body, 'statement'), imgObs.base.id);
verifyNotEqual(testCase, depValueOf(body, 'statement'), ...
    pick(out, 'term_observation').base.id);
end

function testTheSourceIdStaysOnTheTermObservationAndTheImageObsGetsAFreshOne(testCase)
% The primary/sibling convention: an inbound edge naming the source document has
% to land on EXACTLY ONE emitted body, or a follower cannot tell which is which.
% ontology_table_row.m pays for this rule directly (its fan-out gave every body a
% fresh id and stranded every edge pointing at the row).
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
verifyEqual(testCase, pick(out, 'term_observation').base.id, 'oi_fold');
verifyNotEqual(testCase, pick(out, 'image_observation').base.id, 'oi_fold');
verifyNotEqual(testCase, pick(out, 'sampled_body').base.id, 'oi_fold');
end

function testDataDimBecomesOneAxisEntryPerDimension(testCase)
% V_eta_image_model_plan.md R4: "ngrid.data_dim -> one axis entry per dimension".
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
axes = pick(out, 'sampled_body').sampled_body.axes;
verifyEqual(testCase, numel(axes), 2, 'data_dim [4 4] is two dimensions');
verifyEqual(testCase, [axes.length], [4 4]);
% `name` is the ONE axis sub-field declared mustBeNonEmpty, so a blank would
% quarantine the body it describes. Positional names when no labels are given.
verifyEqual(testCase, {axes.name}, {'axis_1', 'axis_2'});
verifyEqual(testCase, {axes.kind}, {'index', 'index'});
verifyEqual(testCase, {axes.regularity}, {'regular', 'regular'});
end

function testDtypeIsCarriedVerbatimAndDataSizeIsDropped(testCase)
% data_type -> datum.dtype, VERBATIM including NDI's own 'ubit1' spelling for
% logical (mat2ngrid.m: `if islogical(x); ngrid.data_type = 'ubit1'; end`).
% Translating it here would lose the source's word for its own type.
% data_size is DROPPED per the plan: bytes-per-element restates the dtype.
v1 = foldableOntologyImage();
v1.ngrid.data_type = 'ubit1';
out = did2.convert.migrators_j.ontology_image(v1);
body = pick(out, 'sampled_body');
verifyEqual(testCase, body.sampled_body.datum.dtype, 'ubit1');
verifyEqual(testCase, body.sampled_body.datum.kind, 'array');
verifyEqual(testCase, body.sampled_body.datum.shape, [4 4]);
verifyFalse(testCase, isfield(body.sampled_body, 'data_size'));
verifyFalse(testCase, isfield(body.sampled_body.datum, 'data_size'));
% and the dtype is ALSO explicit on the composite -- R6 decision 4, because a
% dtype is not recoverable from a raster
verifyEqual(testCase, pick(out, 'image_observation').image.value.dtype, 'ubit1');
end

function testAnNgridHasNoTimeAxisSoTheBodyIsOneDatum(testCase)
% An ngrid declares no time dimension at all -- contrast image_stack, whose v1
% block carries dimension_order/T and really does have frames to count. n = 1
% with the extent in `shape`, rather than an invented cadence.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
st = pick(out, 'sampled_body').sampled_body.sample_time;
verifyEqual(testCase, st.n, 1);
verifyTrue(testCase, st.regular);
verifyEqual(testCase, st.t0.source_value, 0);
verifyEqual(testCase, st.dt.source_value, 0);
end

function testTheRasterBytesMoveToTheBodyUnderNDIsOwnFileName(testCase)
% universalRenames.m:308 skips the structural keys outright
% (document_class / depends_on / file / files), so a file name arrives VERBATIM
% and must be carried verbatim. The image_stack tombstone declared
% `imagestack_file` while NDI writes `imageStack` -- both directions of the file
% audit wrong at once, on every passed-through document. Same trap here:
% imageDocMaker.m:144 writes `ontologyImage.ngrid`.
v1 = foldableOntologyImage();
v1.file = struct('name', {'ontologyImage.ngrid'}, 'location', {struct()});
out = did2.convert.migrators_j.ontology_image(v1);
body = pick(out, 'sampled_body');
verifyTrue(testCase, isfield(body, 'file'));
verifyEqual(testCase, body.file(1).name, 'ontologyImage.ngrid');
% and the bytes do NOT stay on a statement -- a body-backed value has one home
verifyFalse(testCase, isfield(pick(out, 'image_observation'), 'file'));
end

function testStorageModeIsBodyAndTheStatementCarriesNoCadence(testCase)
% D1: one home for a body-backed value. storage_mode 'body' says the pixels live
% in the sampled_body, so `pixels` stays empty and the statement carries no
% sample_time (jStartInteraction seeds the inline single-point cadence, which is
% the wrong half here).
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
imgObs = pick(out, 'image_observation');
verifyEqual(testCase, imgObs.subject_statement.storage_mode, 'body');
verifyEmpty(testCase, imgObs.image.value.pixels);
verifyFalse(testCase, isfield(imgObs.subject_interaction, 'sample_time'));
end

function testTheDepictedTermIsTheVariableRatherThanAPlaceholder(testCase)
% The one thing this fold can do that image_stack cannot. image_stack.m:328-331
% emits `{node:'', name:'image'}` and defers to a second-pass join, because the
% ontology label lives on ANOTHER document. Here the term is on the document
% being migrated, so there is nothing to defer.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
v = pick(out, 'image_observation').subject_statement.variable;
verifyEqual(testCase, v.node, 'uberon:0002436');
verifyEqual(testCase, v.name, 'primary visual cortex');
end

function testTheImageObservationIsNeverEmittedWithAnEmptySubjectEdge(testCase)
% THE HUSK TEST, and it is built on a REAL divergence rather than a hypothetical
% one. Two functions used to answer "who is this an observation of":
%
%   jCarrySubject.m:20-22             accepts  d.value , d.document_id
%   ontology_image.m/dependencyValue  accepts  d.value , d.document_id , d.id
%
% So an edge whose value lives ONLY under `.id` passed the fold guard and then
% got an empty `subject_id` from jCarrySubject -- an image_observation about
% nobody. Nothing would have caught it: `subject_id` is mustBeNonEmpty, but
% +did2/+validate/references.m:90 SKIPS empty edges, so the document validates
% clean and is counted as a successful migration. That is exactly how 4,563 JH
% image_observations went unnoticed until a census found them months later.
%
% This fixture is the shape that separated the two readers. If the fold ever
% goes back to letting jStartInteraction re-read the edge, this reddens.
v1 = foldableOntologyImage();
v1.depends_on = struct('name', {'element_id'}, 'id', {'elem_9'});
out = did2.convert.migrators_j.ontology_image(v1);
imgObs = pick(out, 'image_observation');
verifyEqual(testCase, depValueOf(imgObs, 'subject_id'), 'elem_9', ...
    ['the fold guarded on a subject it then failed to write -- an ' ...
     'image_observation with an empty required edge validates clean']);
end

function testEveryEmittedStatementCarriesANonEmptySubject(testCase)
% The sweep, with its DENOMINATOR asserted first. Without that, an empty
% `out` (or a fold that stopped emitting statements at all) would make this
% vacuously true -- which is how a loop over `out.migrated` once looked
% half-harmless under a mutation that emptied the batch.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
statements = {};
for k = 1:numel(out)
    if isfield(out{k}, 'subject_statement')
        statements{end+1} = out{k}; %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(statements), 2, ...
    'expected the term_observation and the image_observation to be statements');
for k = 1:numel(statements)
    verifyNotEmpty(testCase, depValueOf(statements{k}, 'subject_id'), ...
        sprintf('%s carries an empty subject_id', ...
                statements{k}.document_class.class_name));
end
end

function testTheImageObservationIsAboutTheElementSubject(testCase)
% `element_id` is a SUBJECT edge, not a dangling non-subject one:
% +migrators_j/element.m promotes elements to subjects with ids PRESERVED. This
% is a recurring trap in this repo, so it is asserted rather than remembered.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
verifyEqual(testCase, depValueOf(pick(out, 'image_observation'), 'subject_id'), ...
    'elem_9');
end

% ===================== GUARD 1: the subject ================================

function testNoSubjectMeansNoObservationAndNoBodyEither(testCase)
% THE ARM EVERY REAL NDI DOCUMENT TAKES. Vintage B's only edge is a table row,
% and a table row is not a subject. Emitting an image_observation here would
% reproduce the 4,563-document `image_observation.subject_id` husk exactly, and
% emitting a sampled_body would strand a body whose `statement` names nothing.
v1 = productionOntologyImage();
out = did2.convert.migrators_j.ontology_image(v1);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}.document_class.class_name, 'ontology_image');
% the raster rides through INTACT, which is why `ontology_image` still needs its
% `ngrid` superclass and why retiring `ngrid` is NOT unblocked
verifyTrue(testCase, isfield(out{1}, 'ngrid'));
verifyEqual(testCase, out{1}.ngrid.coordinates, defaultCoords([4 4]));
verifyEqual(testCase, out{1}.ngrid.data_size, 8);
end

function testABlankSubjectEdgeIsTreatedAsNoSubject(testCase)
% A present-but-empty edge is not a subject. `did2.validate.references` SKIPS
% empty edges, so a body minted from one validates clean and orphans nothing --
% which is precisely how 7,233 invented-empty-edge documents stayed invisible.
%
% NOTE WHAT IS ASSERTED, AND WHAT IS NOT. This shape still emits the
% term_observation + anchor it always did -- with an empty subject_id, which is
% the pre-existing vintage-A behaviour and is NOT what this change touches. What
% must not happen is the RASTER fold: no image_observation, no sampled_body.
% Asserting `numel(out) == 1` here would have been asserting a passthrough that
% this arm has never done, and would have passed for the wrong reason.
v1 = foldableOntologyImage();
v1.depends_on(1).value = '';
out = did2.convert.migrators_j.ontology_image(v1);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 2, strjoin(names, ', '));
verifyFalse(testCase, ismember('image_observation', names));
verifyFalse(testCase, ismember('sampled_body', names));
end

function testATableRowEdgeIsNotAcceptedAsASubject(testCase)
% GUARD 1 IN THE OTHER DIRECTION. A guard that accepted any edge at all would
% pass every test above. `ontologyTableRow` documents carry no subject:
%   $ git show origin/main:src/ndi/+ndi/+setup/+NDIMaker/tableDocMaker.m \
%         | grep -n set_dependency_value
%     231:  doc = doc.set_dependency_value('document_id',value);
% one call, and it is not `subject_id`.
%
% THE FIXTURE MUST REACH THE FOLD PATH OR THIS TESTS NOTHING. A production
% (vintage B) body returns at the passthrough BEFORE `subjectOf` is ever
% consulted, so swapping its edge would pass no matter what the subject reader
% did. So this is the foldable shape with its `element_id` REPLACED by a table
% row: everything else about it is fold-ready, and only the edge kind decides.
v1 = foldableOntologyImage();
v1.depends_on = struct('name', {'ontology_table_row_id'}, 'value', {'otr_3'});
out = did2.convert.migrators_j.ontology_image(v1);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyFalse(testCase, ismember('image_observation', names), ...
    'a table row must not be accepted as the subject of an observation');
verifyFalse(testCase, ismember('sampled_body', names), ...
    'and no body may be minted for a statement that was not minted');
end

function testNoRealNDIShapeCanReachTheFoldArm(testCase)
% THE HONESTY TEST, and it is deliberately the awkward one. It asserts that the
% fold arm is UNREACHABLE from any shape NDI's writer can produce, so that a
% green suite is never read as "ngrid is folded on real data".
%
%   createOntologyImageDoc(obj, image, ontologyNodes, options) takes
%   `options.ontologyTableRow_id` and NO subject argument, so a production
%   document has at most that one edge. Vintage A, the only shape carrying
%   `element_id`, has no `ngrid` block at all (and never existed).
%
% If a future change makes one of these fold, this test fails and the change has
% to say so out loud instead of arriving as a silent count shift.
shapes = {productionOntologyImage(), vintageANoRaster()};
verifyEqual(testCase, numel(shapes), 2, ...
    'DENOMINATOR: both NDI-reachable ontologyImage shapes are checked');
for k = 1:numel(shapes)
    out = did2.convert.migrators_j.ontology_image(shapes{k});
    names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
    verifyFalse(testCase, ismember('sampled_body', names), ...
        sprintf(['shape %d reached the raster fold. No NDI writer emits an ' ...
                 'ontologyImage with both a raster and a subject -- if that ' ...
                 'has changed, re-read imageDocMaker.m before relaxing this.'], k));
end
end

% ===================== GUARD 2: the coordinates ============================

function testExplicitCoordinatePositionsAreRefusedNotSilentlyDropped(testCase)
% `sampled_body.axes[]` declares {name, kind, length, regularity, spacing, unit}
% and NO coordinate array:
%   $ python3 -c "import json;d=json.load(open('schemas/V_eta/draft/ \
%       sampled_body.json'));print([s['name'] for f in d['fields'] \
%       if f['name']=='axes' for s in f['fields']])"
% The decided destination `axes[k].values` is #45, blocked on #32. So a fold
% today has nowhere to put real positions, and folding anyway would delete them
% -- the same silent loss +super/ngrid.m exists to stop.
%
% `mat2ngrid(X,c1,...,cn)` is a DOCUMENTED signature, so such a document is
% well-formed: it is the model that cannot hold it, not the document that is
% malformed. Quarantine is visible; a drop is not.
v1 = foldableOntologyImage();
v1.ngrid.coordinates = [10; 20; 30; 40; 0.5; 1.5; 2.5; 3.5];
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ngridCoordinatesHaveNoHome');
end

function testDefaultIndexCoordinatesFoldBecauseTheyAreRecoverable(testCase)
% GUARD 2 IN THE OTHER DIRECTION. A guard that refused ALL coordinates would
% refuse every document the one in-tree writer produces -- imageDocMaker.m:121
% calls mat2ngrid with ONE argument, so every ontologyImage carries the default
% index vector, which holds nothing beyond `data_dim` (stored as datum.shape and
% as the axis lengths).
v1 = foldableOntologyImage();
v1.ngrid.coordinates = defaultCoords([4 4]);
out = did2.convert.migrators_j.ontology_image(v1);
verifyEqual(testCase, numel(out), 4);
end

function testAbsentAndEmptyCoordinatesBothFold(testCase)
% Nothing to drop in either case.
v1 = foldableOntologyImage();
v1.ngrid.coordinates = [];
verifyEqual(testCase, numel(did2.convert.migrators_j.ontology_image(v1)), 4);
v1.ngrid = rmfield(v1.ngrid, 'coordinates');
verifyEqual(testCase, numel(did2.convert.migrators_j.ontology_image(v1)), 4);
end

function testANearMissCoordinateVectorIsRefusedRatherThanAssumedDefault(testCase)
% Right LENGTH, different values. Length-only checking is how a counter prints a
% reassuring zero while reading nothing -- so the test is exact equality, and
% this pins that it is.
v1 = foldableOntologyImage();
c = defaultCoords([4 4]);
c(end) = 99;
v1.ngrid.coordinates = c;
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ngridCoordinatesHaveNoHome');
end

function testTheVDeltaOutputShapeIsRefusedByTheFoldToo(testCase)
% `dim_sizes`/`ndims` are the V_delta migrator's OUTPUT and have no did_v1
% existence. +super/ngrid.m makes the same refusal upstream; the fold repeats it
% because a body assembled from names NDI never wrote is a fixture-built-from-
% our-own-schema bug, which is the mistake that hid both the ontology_image and
% the distance_metadata defects.
v1 = foldableOntologyImage();
v1.ngrid = struct('dim_sizes', [4 4], 'ndims', 2, 'data_type', 'double');
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ngridVDeltaShape');
end

% ===================== end to end, under validation ========================

function testTheFoldedSetVALIDATESThroughTheDispatcher(testCase)
% With 'Validate', false this would pass even if image_observation required a
% field the fold never sets -- which is exactly how a half-landed change slips
% through. Validation ON is the point of this test.
out = did2.convert.v1_to_v2(foldableOntologyImage(), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, out.summary.migrated_count, 4);
end

function testTheProductionShapeStillPassesThroughUnderValidation(testCase)
% The passthrough must keep validating against the `ontology_image` tombstone --
% the schema half and the migrator half are LOCKSTEP, and this is the assertion
% that notices if the `ngrid` superclass is removed from that tombstone before
% the documents stop carrying the block.
out = did2.convert.v1_to_v2(productionOntologyImage(), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, out.summary.migrated_count, 1);
end

% ===================== fixtures ============================================

function c = defaultCoords(dataDim)
%DEFAULTCOORDS mat2ngrid's nargin==1 output: [(1:d1)'; ... ; (1:dn)'].
c = [];
for k = 1:numel(dataDim)
    c = [c; (1:dataDim(k))']; %#ok<AGROW>
end
end

function v1 = productionOntologyImage()
%PRODUCTIONONTOLOGYIMAGE The CURRENT (and only) NDI production shape.
%
%   imageDocMaker.m:121-127 + :144. `ontologyNodes` is a comma-joined sorted
%   CURIE list (the template's singular `ontologyNode` is stale; the WRITER
%   wins). The only edge is the table row. `coordinates` is the default index
%   vector because the writer passes one argument.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'ngrid'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'ontology_table_row_id'}, 'value', {'otr_3'});
v1.base = struct('id', 'oi_prod', 'session_id', 'sess_09', 'name', 'oi', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_nodes', 'uberon:0000955,uberon:0002436');
v1.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', defaultCoords([4 4]));
end

function v1 = vintageANoRaster()
%VINTAGEANORASTER The legacy shape -- which HAS NEVER EXISTED IN NDI.
%
%   Kept because it is what the existing vintage-A arm migrates and because it
%   is half of the reachability argument: it carries `element_id` and NO `ngrid`
%   block, so it cannot reach the raster fold either.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'oi_a', 'session_id', 'sess_09', 'name', 'oi', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_name', 'uberon:0002436', ...
    'ontology_region', 'primary visual cortex');
end

function v1 = foldableOntologyImage()
%FOLDABLEONTOLOGYIMAGE A raster AND a subject -- A SHAPE NO NDI WRITER EMITS.
%
%   Assembled, and labelled as assembled. The `ngrid` block is mat2ngrid's real
%   four-field output and the terms are vintage A's real two chars; what is
%   constructed is the COMBINATION, because `createOntologyImageDoc` takes no
%   subject argument and vintage A carries no raster. It exists to exercise the
%   fold arm, which is otherwise untestable, and
%   testNoRealNDIShapeCanReachTheFoldArm exists so this fixture is never mistaken
%   for a population.
v1 = vintageANoRaster();
v1.base.id = 'oi_fold';
v1.document_class.superclasses = struct('class_name', {'base', 'ngrid'}, ...
    'class_version', {'1.0.0', '1.0.0'});
v1.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', defaultCoords([4 4]));
end

% ===================== small readers =======================================

function b = pick(bodies, className)
%PICK The single body of CLASSNAME, erroring rather than returning the first of
%   several -- a silent first-match would hide a duplicate emission.
hits = {};
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        hits{end+1} = bodies{k}; %#ok<AGROW>
    end
end
assert(isscalar(hits), 'expected exactly one %s body, found %d', ...
    className, numel(hits));
b = hits{1};
end

function v = depValueOf(body, name)
v = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name) && isfield(d, 'value')
        v = char(d.value);
        return;
    end
end
end

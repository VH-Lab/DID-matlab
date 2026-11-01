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
%     GUARD 2 (COORDINATES)  explicit coordinate positions this fold cannot
%                            ACCOUNT FOR are REFUSED. Folding anyway would
%                            delete real data -- the exact loss +super/ngrid.m
%                            was written to stop, arriving through a different
%                            door.
%
%                            THE REASON CHANGED ON 2026-08-17 AND THE TESTS DID
%                            NOT, WHICH IS WHY THIS IS CORRECTED RATHER THAN
%                            DELETED. It read: "because `sampled_body.axes[]`
%                            declares {name, kind, length, regularity, spacing,
%                            unit} and NO coordinate array. The decided
%                            destination `axes[k].values` is #45, blocked on
%                            #32." Every clause is now false. `axes[].values`
%                            EXISTS, #45 was signed and unblocked 2026-08-14,
%                            and the carry is signed for this family
%                            (V_eta_ngrid_family_findings.md, TEAM-SIGN-OFF
%                            [receptive field fold]).
%
%                            WHAT STILL REFUSES, and it is a narrower thing:
%                            `coordinates` is ONE FLAT VECTOR whose segment
%                            order is the WRITER's -- `mat2ngrid` documents
%                            data_dim order and the Hartley writer stores
%                            [T; X; Y] against a data_dim of [X Y T 2]. So a
%                            caller must SUPPLY the per-axis vectors, and
%                            jNgridBody checks they re-concatenate to the
%                            stored one exactly. `ontology_image` supplies
%                            none, which is correct: its one in-tree writer
%                            passes a single argument to mat2ngrid, so its
%                            coordinates are always the default index vector
%                            and there is nothing to carry. The three tests
%                            below are unchanged and still pass, because the
%                            arm they exercise is unchanged.
%                            The CARRY arm is exercised by
%                            testMigratorsJHartleyCalc.m, on the one document
%                            class that has real positions.
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

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
% RE-ARMED 2026-10-21. These tests were filtered while did-schema #88's
% `calculation` required operating_system_id, which no v1 document records.
% Decided by Jess Haley, 2026-10-21 [calculation-os-optional]: "A calculation's
% `operating_system_id` is optional: required when the operating system is
% known, absent when the source never recorded it." So that reason is gone and
% the tests run unconditionally; a failure here is a migrator gap to report,
% not a reason to filter.
end

% ===================== the fold ============================================

function testNgridFoldsToASampledBodyBesideAnImageObservation(testCase)
% INVERTED 2026-10-21. Decided by Jess Haley, 2026-10-21 [ontology image is an
% observation of its region] (did-schema V_eta_spatial_transcriptomics_plan.md):
% the raster is ONE observation, and "this replaces item 51's separate term
% observation for ontologyImage". So 1 -> 3, not 1 -> 4: the intensity
% observation, the sampled_body carrying the grid, and the session anchor. The
% term observation this asserted present is now asserted ABSENT.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 3, ...
    sprintf('expected 3 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
% UPDATED 2026-10-21 for did-schema #88 and #73 review item 51: the raster is
% an `observation` with the `intensity` value kind (its pixels are an ordinary
% numeric image), the region an `observation` with the `term` value kind --
% each a DIRECTION class plus ONE value-kind mixin, never a leaf name -- and the
% anchor #88's one time-reference class.
verifyFalse(testCase, ismember('observation+term', names), ...
    'the separate term observation (item 51) is gone');
verifyTrue(testCase, ismember('observation+intensity', names));
verifyTrue(testCase, ismember('sampled_body', names));
verifyTrue(testCase, ismember('relative_time_reference', names));
end

function testTheBodyIsBoundToTheImageObservationNotTheTermObservation(testCase)
% The `statement` edge is what makes a body findable from the subject side, and
% pointing it at the wrong sibling would be invisible to every gate: both are
% real documents, so the edge resolves and no orphan is reported. The body IS
% the picture; the term says what the picture depicts.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
imgObs = pickKind(out, 'observation', 'intensity');
body   = pick(out, 'sampled_body');
% #88: the body names its owner by `owner_id` (was `statement`)
verifyEqual(testCase, depValueOf(body, 'owner_id'), imgObs.base.id);
% INVERTED 2026-10-21: there is no term sibling to point at by mistake any more
% ([ontology image is an observation of its region]); the owner is the ONE
% statement emitted.
names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
verifyFalse(testCase, ismember('observation+term', names));
end

function testTheSourceIdNowLandsOnTheImageObservation(testCase)
% The primary/sibling convention: an inbound edge naming the source document has
% to land on EXACTLY ONE emitted body, or a follower cannot tell which is which.
% ontology_table_row.m pays for this rule directly (its fan-out gave every body a
% fresh id and stranded every edge pointing at the row).
%
% INVERTED 2026-10-21 (was ...StaysOnTheTermObservationAndTheImageObsGetsAFreshOne):
% the term observation no longer exists ([ontology image is an observation of
% its region]), so the source id moves to the one observation that does. The
% rule itself is unchanged: exactly one body carries it.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
verifyEqual(testCase, pickKind(out, 'observation', 'intensity').base.id, 'oi_fold');
verifyNotEqual(testCase, pick(out, 'sampled_body').base.id, 'oi_fold');
ids = cellfun(@(b) char(b.base.id), out, 'UniformOutput', false);
verifyEqual(testCase, nnz(strcmp(ids, 'oi_fold')), 1, ...
    'exactly one emitted body carries the source id');
end

function testDataDimBecomesOneAxisEntryPerDimension(testCase)
% V_eta_image_model_plan.md R4: "ngrid.data_dim -> one axis entry per dimension".
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
% #88: a body's axes are on the `data` block; data_body AMENDMENT 6: its
% `dimensions`, each with the covariate along it (`keys` before)
axes = did2.unittest.helpers.axesOf(pick(out, 'sampled_body'));
verifyEqual(testCase, numel(axes), 2, 'data_dim [4 4] is two dimensions');
% UPDATED 2026-08-14 for the signed axis entry (DID-schema TEAM-SIGN-OFF
% [data_body] + AMENDMENT 1). The old shape {name, kind, length, regularity,
% spacing, unit} no longer exists; `variable` and `n` are the required pair.
%
% NOT AN INVERSION -- every property asserted here is the SAME property under a
% new field name, which is why the values are unchanged: two dimensions, extents
% [4 4], positional labels when none are supplied, and a regular index axis.
%
% THE THREE COMPOSITE SUB-FIELDS ARE READ WITH `arrayfun`, NOT WITH A CHAINED
% DOT. `axes` is a 1x2 STRUCT ARRAY, so `axes.variable` is a comma-separated
% list of two values and MATLAB refuses to index into one ("Intermediate dot
% indexing produced a comma-separated list with 2 values"). The chained form
% reads fine and cannot run. It is legal elsewhere in this suite only because
% those chains start at a SCALAR -- `rep.family_count_violation.edge_name`
% (testSilentLoss:131) has a scalar `rep`, so the first hop yields one value.
% The old shape hid this: `name`/`length`/`kind` were all leaf scalars, so a
% chained read was never needed until the signed entry made three of them
% composites.
verifyEqual(testCase, [axes.n], [4 4]);                       % was `.length`
% `variable` is now one of the two mustBeNonEmpty sub-fields (with `n`), so a
% blank would still quarantine the body it describes.
% UPDATED 2026-10-21: keyed as #73 review item 51 records for a raster,
% [y, x, (channel)] -- data_dim is size(image), rows first -- not positionally.
verifyEqual(testCase, ...
    arrayfun(@(a) did2.convert.axisKey(a.term), axes, 'UniformOutput', false), ...
    {'y', 'x'});                                              % was `.name`, then `.variable`
% written as the registry's Y-Coordinate / X-Coordinate where it holds them
verifyEqual(testCase, arrayfun(@(a) a.term.name, axes, 'UniformOutput', false), ...
    {did2.convert.axisTerm('y').name, did2.convert.axisTerm('x').name});
% INVERTED 2026-10-22 (asserted origin 1, spacing 1 on each): the coordinates
% are MATLAB's default index vector, which only repeats the dimensions'
% positions, and such a covariate is not written (Jess Haley 2026-10-22
% [covariate rules named] 6.2a, and "yes" to 1..n). Two bare dimensions.
verifyEqual(testCase, [axes.nCov], [0 0], 'no covariate repeats the positions');
end

function testAColourRasterIsKeyedYXChannel(testCase)
% #73 review item 51: a raster is keyed [y, x, (channel)]. A third dimension
% is the channel, in mat2ngrid's data_dim order (size(image)).
v1 = foldableOntologyImage();
v1.ngrid.data_dim = [4 4 3];
v1.ngrid.coordinates = defaultCoords([4 4 3]);
out = did2.convert.migrators_j.ontology_image(v1);
axes = did2.unittest.helpers.axesOf(pick(out, 'sampled_body'));
verifyEqual(testCase, [axes.n], [4 4 3]);
verifyEqual(testCase, ...
    arrayfun(@(a) lower(did2.convert.axisKey(a.term)), axes, 'UniformOutput', false), ...
    {'y', 'x', 'channel'});   % the registry's label (NCIT:C44170 'Channel', did-schema 34a15e2 [channel types])
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
% UPDATED 2026-08-14: `datum` collapsed (signed sec.5). Every property below is
% the SAME property in its new home, which is why the values are unchanged:
%   dtype -> subject_statement.datum_type, normalised, source spelling kept
%   kind  -> the axis COUNT (two entries), asserted above
%   shape -> [axes.n] in array order, asserted above as [4 4]
% NOT A WEAKENING: 'ubit1' still reaches the document, now as the SOURCE
% spelling beside its canonical 'bool', which is more than the old block said.
obs = pickKind(out, 'observation', 'intensity');
% #88: the plain array's element type is the value's `data_type`
verifyEqual(testCase, obs.value.data_type, 'bool');
verifyEqual(testCase, obs.value.source_data_type, 'ubit1');
verifyFalse(testCase, isfield(body.sampled_body, 'data_size'));
verifyFalse(testCase, isfield(body.sampled_body, 'datum'));
% and the dtype is ALSO explicit on the composite -- R6 decision 4, because a
% dtype is not recoverable from a raster
% INVERTED 2026-10-21: the `image` value retired (#73 item 51), so the dtype is
% NOT repeated on a composite -- `value.data_type` (above) is its one home, and
% no `image` block exists to carry a second copy.
verifyFalse(testCase, isfield(pickKind(out, 'observation', 'intensity'), 'image'));
end

function testAnNgridHasNoTimeAxisSoTheBodyIsOneDatum(testCase)
% An ngrid declares no time dimension at all -- contrast image_stack, whose v1
% block carries dimension_order/T and really does have frames to count.
%
% THE BLOCK THIS USED TO ASSERT IS GONE, AND IT WAS ENTIRELY PLACEHOLDER: it
% pinned `sample_time` as {regular: true, t0: 0, dt: 0, n: 1}, i.e. a regular
% timeline whose origin and spacing were both zero and whose length was "one
% datum" rather than one sample. Three of the four sub-fields carried no fact,
% and the fourth restated a cardinality `axes` already carries. The signed model
% retires the block (step 5); this writer had nothing in it to migrate, so the
% assertion becomes its ABSENCE plus the axes that do carry the extent.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
body = pick(out, 'sampled_body');
verifyFalse(testCase, isfield(body.sampled_body, 'sample_time') ...
    && ~isempty(fieldnames(body.sampled_body.sample_time)));
verifyTrue(testCase, isfield(body.data, 'dimensions'));   % AMENDMENT 6: dimensions, on `data`
verifyTrue(testCase, numel(body.data.dimensions) >= 1);
verifyFalse(testCase, isfield(body.data, 'keys'));
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
verifyFalse(testCase, isfield(pickKind(out, 'observation', 'intensity'), 'file'));
end

function testStorageModeIsBodyAndTheStatementCarriesNoCadence(testCase)
% D1: one home for a body-backed value. storage_mode 'body' says the pixels live
% in the sampled_body, so `pixels` stays empty and the statement carries no
% sample_time (jStartInteraction seeds the inline single-point cadence, which is
% the wrong half here).
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
imgObs = pickKind(out, 'observation', 'intensity');
% #88: `storage_mode` 'body' is `value.data_body` true (rule
% value_inline_or_body), and the inline value stays empty
verifyEqual(testCase, imgObs.value.data_body, true);
verifyEmpty(testCase, fieldnames(imgObs.intensity.value));
verifyFalse(testCase, isfield(imgObs.interaction, 'sample_time'));
end

function testTheVariableIsImagingSignalIntensityAndTheAreaIsASiteCondition(testCase)
% INVERTED 2026-10-21 (was testTheDepictedTermIsTheVariableRatherThanAPlaceholder,
% which pinned variable = uberon:0002436 "primary visual cortex"). Decided by
% Jess Haley, 2026-10-21 [ontology image is an observation of its region]: the
% variable is NCIT:C221750 "Imaging Signal Intensity", and an anatomical area
% makes the area's REGION PART the entity. Pass 1 cannot mint the part, so the
% area rides as an NCIT:C13717 "Anatomic Site" condition for NDI's second pass
% (ndi.migrate.internal.pathSPromotion) to promote; the observation stays about
% the subject until then. What did NOT change: the depicted term is on the
% document, so it is carried, never a placeholder.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
obs = pickKind(out, 'observation', 'intensity');
v = obs.statement.variable;
verifyEqual(testCase, v.node, 'NCIT:C221750');
verifyEqual(testCase, v.name, 'Imaging Signal Intensity');
c = obs.statement.conditions;
verifyEqual(testCase, numel(c), 1, 'one condition: the area');
verifyEqual(testCase, c(1).variable.node, 'NCIT:C13717');
verifyEqual(testCase, c(1).term.node, regNode('uberon:0002436'));
verifyEqual(testCase, c(1).term.name, 'primary visual cortex');
verifyEqual(testCase, depValueOf(obs, 'entity_id'), 'elem_9', ...
    'until the second pass promotes it, the observation is about the subject');
end

function testANonAreaNodeIsCountedThroughTheDispatcher(testCase)
% [non-area image node, revisited]: "kept on the observation as a condition
% with a plain label variable ... and counted". The count is the migration
% note the dispatcher collects; an UBERON node is not counted.
v1 = foldableOntologyImage();
v1.ontology_image.ontology_name = 'CL:0000540';
v1.ontology_image.ontology_region = 'neuron';
v1 = writerSpelled(v1);
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'non_area_ontology_node'));
verifyEqual(testCase, notes.non_area_ontology_node.count, 1);
verifyEqual(testCase, notes.non_area_ontology_node.details, {'CL:0000540'});
area = did2.convert.v1_to_v2(writerSpelled(foldableOntologyImage()), 'Validate', true, 'TargetVersion', 'V_eta');
verifyFalse(testCase, isfield(area.summary.migration_notes, 'non_area_ontology_node'));
end

function testAnUpperCaseUberonNodeIsStillAnArea(testCase)
% The UBERON test is case-insensitive: NDI writes `uberon:`, the registry
% `UBERON:`. A case-sensitive check would quietly send every upper-case area to
% the non-area arm, where pathSPromotion would never find it.
v1 = foldableOntologyImage();
v1.ontology_image.ontology_name = 'UBERON:0002436';
obs = pickKind(did2.convert.migrators_j.ontology_image(v1), 'observation', 'intensity');
verifyEqual(testCase, obs.statement.conditions(1).variable.node, 'NCIT:C13717');
end

function testANonAreaNodeIsAConditionThatIsNotAnAnatomicSite(testCase)
% THE OTHER DIRECTION. "Any non-area node is a condition on the same
% observation" ([ontology image is an observation of its region]). A guard that
% labelled every node an Anatomic Site would pass the test above and hand
% pathSPromotion a cell type to mint a region part for.
v1 = foldableOntologyImage();
v1.ontology_image.ontology_name = 'CL:0000540';
v1.ontology_image.ontology_region = 'neuron';
out = did2.convert.migrators_j.ontology_image(v1);
names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 3, strjoin(names, ', '));
obs = pickKind(out, 'observation', 'intensity');
verifyEqual(testCase, obs.statement.variable.node, 'NCIT:C221750');
c = obs.statement.conditions;
verifyEqual(testCase, numel(c), 1);
% UPDATED 2026-10-22, Decided by Jess Haley [non-area image node, revisited]:
% NOT decided; NCIT:C211970 is not used. The node is a condition with the plain
% label variable 'ontology node' (no node), and the case is counted.
verifyFalse(testCase, isfield(c(1).variable, 'node') && ~isempty(c(1).variable.node));
verifyEqual(testCase, c(1).variable.name, 'ontology node');
verifyEqual(testCase, c(1).term.node, 'CL:0000540');
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
imgObs = pickKind(out, 'observation', 'intensity');
verifyEqual(testCase, depValueOf(imgObs, 'entity_id'), 'elem_9', ...
    ['the fold guarded on a subject it then failed to write -- an ' ...
     'raster observation with an empty required edge validates clean']);
end

function testEveryEmittedStatementCarriesANonEmptySubject(testCase)
% The sweep, with its DENOMINATOR asserted first. Without that, an empty
% `out` (or a fold that stopped emitting statements at all) would make this
% vacuously true -- which is how a loop over `out.migrated` once looked
% half-harmless under a mutation that emptied the batch.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
statements = {};
for k = 1:numel(out)
    if isfield(out{k}, 'statement')    % #88: `statement` (was subject_statement)
        statements{end+1} = out{k}; %#ok<AGROW>
    end
end
% INVERTED 2026-10-21: 1, not 2 -- the term observation is gone ([ontology
% image is an observation of its region]).
verifyEqual(testCase, numel(statements), 1, ...
    'expected the intensity observation to be the one statement');
for k = 1:numel(statements)
    verifyNotEmpty(testCase, depValueOf(statements{k}, 'entity_id'), ...
        sprintf('%s carries an empty entity_id', ...
                statements{k}.document_class.class_name));
end
end

function testTheImageObservationIsAboutTheElementSubject(testCase)
% `element_id` is a SUBJECT edge, not a dangling non-subject one:
% +migrators_j/element.m promotes elements to subjects with ids PRESERVED. This
% is a recurring trap in this repo, so it is asserted rather than remembered.
out = did2.convert.migrators_j.ontology_image(foldableOntologyImage());
verifyEqual(testCase, depValueOf(pickKind(out, 'observation', 'intensity'), 'entity_id'), ...
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
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'ontology_image');
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
names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
% INVERTED 2026-10-21 for did-schema #88: `entity_id` is REQUIRED, so the
% term observation can no longer be emitted with an empty subject either. The
% document passes through whole (what #88 cannot express passes through, Jess
% Haley 2026-10-21), and still no raster fold: no intensity observation, no
% body.
verifyEqual(testCase, numel(out), 1, strjoin(names, ', '));
verifyEqual(testCase, names{1}, 'ontology_image');
verifyFalse(testCase, ismember('observation+intensity', names));
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
names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
verifyFalse(testCase, ismember('observation+intensity', names), ...
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
    names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
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
verifyEqual(testCase, numel(out), 3);   % 4 before 2026-10-21: no term observation
end

function testAbsentAndEmptyCoordinatesBothFold(testCase)
% Nothing to drop in either case.
v1 = foldableOntologyImage();
v1.ngrid.coordinates = [];
verifyEqual(testCase, numel(did2.convert.migrators_j.ontology_image(v1)), 3);
v1.ngrid = rmfield(v1.ngrid, 'coordinates');
verifyEqual(testCase, numel(did2.convert.migrators_j.ontology_image(v1)), 3);
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

function testTheBaseMigratorShapeIsRefusedByTheFoldToo(testCase)
% `dim_sizes`/`ndims` are the base (+migrators) migrator's OUTPUT and have no did_v1
% existence. +super/ngrid.m makes the same refusal upstream; the fold repeats it
% because a body assembled from names NDI never wrote is a fixture-built-from-
% our-own-schema bug, which is the mistake that hid both the ontology_image and
% the distance_metadata defects.
v1 = foldableOntologyImage();
v1.ngrid = struct('dim_sizes', [4 4], 'ndims', 2, 'data_type', 'double');
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ngridBaseMigratorShape');
end

% ===================== end to end, under validation ========================

function testTheFoldedSetVALIDATESThroughTheDispatcher(testCase)
% With 'Validate', false this would pass even if image_observation required a
% field the fold never sets -- which is exactly how a half-landed change slips
% through. Validation ON is the point of this test.
out = did2.convert.v1_to_v2(writerSpelled(foldableOntologyImage()), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, out.summary.migrated_count, 3);   % was 4: no term observation
end

function testTheProductionShapeStillPassesThroughUnderValidation(testCase)
% The passthrough must keep validating against the `ontology_image` tombstone --
% the schema half and the migrator half are LOCKSTEP, and this is the assertion
% that notices if the `ngrid` superclass is removed from that tombstone before
% the documents stop carrying the block.
%
% 2026-10-29: the production shape names only its table row, so it is now
% CARRIED whole as v1, needs_mapping ([ngrid with no statement carried], Jess
% Haley, did-schema V_eta_go_forward_class_audit.md). The body is the same
% passthrough as before; the carry is noted, and still nothing quarantines.
%
% 2026-10-30: a carried document is never validated against V_eta (v1_to_v2:
% `if options.Validate && ~carried`), so the `ontology_image` tombstone is no
% longer what this test exercises, and [one folder, final classes only] (Jess
% Haley, 2026-10-29) deletes it. Every assertion below holds with or without
% that file: no quarantine, one document, the carry noted.
out = did2.convert.v1_to_v2(writerSpelled(productionOntologyImage()), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, out.summary.migrated_count, 1);
verifyEqual(testCase, numel(out.passthrough), 1);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry is noted');
verifyTrue(testCase, startsWith(notes.carried_as_v1.distinct_details{1}, '[carry-124] needs_mapping: ngrid'));
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
v1.base = struct('id', 'oi_prod', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_nodes', 'uberon:0000955,uberon:0002436');
v1.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', defaultCoords([4 4]));
end

function v1 = writerSpelled(v1)
%WRITERSPELLED A fixture of this file in NDI's own spelling, for the dispatcher.
%   The fixtures here are spelled as the deleted rename pass (universalRenames)
%   left them, which the migrator called directly still reads; through
%   did2.convert.v1_to_v2 a class reaches its migrator only by its v1 name
%   ([migrators read raw v1]): `ontologyImage`, its block `ontologyImage`
%   (`ontologyNodes`; vintage A's `ontology_name` / `ontology_region` are v1's
%   own legacy names), and the edge `ontologyTableRow_id`.
v1.document_class.class_name = 'ontologyImage';
blk = v1.ontology_image;
if isfield(blk, 'ontology_nodes')
    blk.ontologyNodes = blk.ontology_nodes;
    blk = rmfield(blk, 'ontology_nodes');
end
v1.ontologyImage = blk;
v1 = rmfield(v1, 'ontology_image');
for k = 1:numel(v1.depends_on)
    if strcmp(v1.depends_on(k).name, 'ontology_table_row_id')
        v1.depends_on(k).name = 'ontologyTableRow_id';
    end
end
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
v1.base = struct('id', 'oi_a', 'session_id', 'sess_09', 'name', '', ...
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
    if strcmp(did2.unittest.helpers.classKey(bodies{k}), className)
        hits{end+1} = bodies{k}; %#ok<AGROW>
    end
end
assert(isscalar(hits), 'expected exactly one %s body, found %d', ...
    className, numel(hits));
b = hits{1};
end

function v = depValueOf(body, name)
%DEPVALUEOF An edge's target, spelled `value` or `document_id`.
v = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        end
        return;
    end
end
end

% ===================== did-schema #88 readers (added 2026-10-21) ==========

function b = pickKind(bodies, direction, kind)
%PICKKIND The single statement of DIRECTION with value kind KIND.
b = pick(bodies, [direction '+' kind]);
end

function n = regNode(node)
%REGNODE NODE as the loaded term registry spells it when it holds it ([migrator
%   writes the registry spelling], Jess Haley, 2026-10-26), else as given.
t = did2.convert.registeredTerm(node, '');
n = node;
if ~isempty(t.name); n = t.node; end
end

function n = regName(name)
%REGNAME NAME as the loaded term registry labels it when it holds it, else as
%   given ([term labels stay as the ontology spells them]).
t = did2.convert.registeredTerm('', name);
n = t.name;
end

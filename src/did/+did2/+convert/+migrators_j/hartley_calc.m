function bodies = hartley_calc(preBody)
%HARTLEY_CALC Brainstorm-J migrator: the ndi.calc.vis.hartley reverse-correlation
%   OUTPUT document -> the subject_calculation LEAF `receptive_field_calculation`
%   + the `receptive_field` result composite, id- and depends_on-PRESERVED, plus
%   the response volume in TWO `sampled_body` documents (one per plane) and the
%   windowed spike train as a THIRD, input-side body.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: WRITTEN 2026-08-17 IN A CONTAINER WITH NEITHER MATLAB NOR OCTAVE
%   (`command -v matlab octave` exits 1). NOT ONE LINE BELOW HAS BEEN EXECUTED.
%   test-migrators-quick.yml is the first thing with an opinion. Said in the
%   header rather than in a commit message because a header is what the next
%   reader sees.
%
%   ---------------------------------------------------------------------
%   THE SIGNED MODEL
%   ---------------------------------------------------------------------
%   DID-schema schemas/V_eta_ngrid_family_findings.md,
%   TEAM-SIGN-OFF [receptive field fold] + TEAM-SIGN-OFF [receptive field
%   naming], jess@walthamdatascience.com / 2026-08-17, verbatim in the parts
%   this file implements:
%
%     "A `hartley_calc` document migrates 1->1, id- and deps-PRESERVED, into a
%      `receptive_field_calculation` leaf (= `subject_calculation` +
%      `receptive_field`), with the payload in TWO `sampled_body` documents --
%      one for the STA plane, one for the p-value plane, because the writer
%      itself gives the length-2 dimension no coordinates (436 coordinate
%      values against a data_dim summing to 438). `ngrid.coordinates` folds
%      into `axes[].values` [...] `reverse_correlation.method` becomes a bound
%      term on the composite, NOT part of the class name. [...] `spiketimes` is
%      carried as CALCULATION INPUT with `derived_from` the neuron, not as
%      archival data; `stimulus_properties` is checked for equality against the
%      presentation's generator spec and dropped only when equal, refused and
%      reported when not."
%
%   WHAT THAT SIGNATURE EXPLICITLY DOES NOT COVER, and this file does not
%   touch: retiring the `ngrid` class (gated on BOTH consumers -- `ontology_image`
%   still consumes it), vintage B's raster home, and the unenforced-dependency
%   gap (already closed elsewhere: `RequiredDependencies` is ARMED BY DEFAULT).
%
%   ---------------------------------------------------------------------
%   THE SOURCE, MEASURED -- 210 REAL DOCUMENTS, NOT A TEMPLATE
%   ---------------------------------------------------------------------
%   Corpus 20211116, read directly off the unpacked corpus with python3. Every
%   claim this migrator relies on was checked against all 210, and the
%   denominator is stated first:
%
%     DENOMINATOR: 1220 json file(s) in the corpus; 210 of class `hartley_calc`
%       210  data_dim=[200, 200, 36, 2]        (one shape, no variation)
%       210  data_type='double'   data_size=8
%       210  len(coordinates)=436              (data_dim sums to 438)
%       210  method='Hartley'                  dimension_labels=''
%       210  len(T)=36 len(T_coords)=36 len(X_coords)=200 len(Y_coords)=200
%       210  T == reconstruction_properties.T_coords
%       210  coords segmented [36,200,200] == (T_coords, X_coords, Y_coords)
%       210  X_coords == 1..200      Y_coords == 1..200
%       210  dep names=['element_id', 'stimulus_presentation_id'], BOTH non-empty
%       210  files=['hartley_results.ngrid']
%       210  top blocks = app, base, depends_on, document_class, files,
%            hartley_calc, hartley_reverse_correlation, ngrid, reverse_correlation
%       len(frameTimes)=3360 in all 210; len(spiketimes) takes 194 distinct
%       values (4 .. 13379), i.e. it is genuinely per-document
%       21 distinct element_id x 10 distinct stimulus_presentation_id = 210
%
%   THE COORDINATE ORDER IS NOT THE data_dim ORDER, and that is the single
%   fact this fold turns on. `data_dim` is [200 200 36 2]; the stored
%   `coordinates` vector is [T(36); X(200); Y(200)]. The segmentation
%   [36,200,200] is the ONLY subset of the dims summing to 436 (438 - 2), so
%   the length-2 dimension has no coordinates -- which is the writer saying, in
%   the data, that it is not a coordinate axis. That is why two bodies and not
%   a length-2 axis.
%
%   BECAUSE THE ORDER IS THE WRITER'S AND NOT `mat2ngrid`'s, THIS MIGRATOR
%   SEGMENTS THE VECTOR ITSELF and hands jNgridBody the per-axis vectors, which
%   VERIFIES that they re-concatenate to the stored vector exactly. A caller
%   that guessed the order would silently mislabel two axes; jNgridBody refuses
%   rather than accept an unverifiable segmentation. See its header.
%
%   THE LAG AXIS IS CARRIED AS `values`, NOT AS origin+spacing, AND THAT IS A
%   LOSSLESSNESS RESULT RATHER THAN A PREFERENCE. T looks like
%   -0.1 : 0.01 : 0.25, and it is not:
%
%     DENOMINATOR: 210 hartley_calc document(s); 1 distinct T vector
%     T reproducible EXACTLY by origin -0.1 + k*0.01 :   0 of 210
%     6 of the 36 entries differ at the ulp (T(25) = 0.14 vs 0.13999999999999999)
%
%   So a regular axis would re-derive different doubles from the ones stored.
%   `values` keeps them. The two 200-axes ARE the default index vector
%   (verified 1..200 in 210/210), so they stay regular with origin 1 / spacing 1
%   and carry no `values` -- nothing is lost, because `n` restates them.
%
%   THE TWO 200-AXES ARE NAMED POSITIONALLY (`axis_1`, `axis_2`) ON PURPOSE.
%   Nothing in the document distinguishes X from Y: both coordinate vectors are
%   the identical default index vector, both dims are 200, and
%   `reverse_correlation.dimension_labels` -- the field whose job is to name the
%   axes -- is '' in 210 of 210. Naming one of them `x position` would be a
%   guess recorded as a fact, and `axes[].variable` is queryable. The lag axis
%   IS named, on positive evidence: its coordinates equal
%   `hartley_calc.input_parameters.T`, the reverse-correlation lag vector, in
%   210 of 210.
%
%   ---------------------------------------------------------------------
%   BLOCK-BY-BLOCK, AND WHERE EACH FIELD LANDS
%   ---------------------------------------------------------------------
%   Field names are the POST-`universalRenames` spellings. That pass
%   snake_cases block keys and the field names ONE level inside each block, and
%   nothing deeper (universalRenames.m snakeCasePropertyBlocks /
%   snakeCaseBlockFields). So `frameTimes` arrives as `frame_times` while
%   `T_coords`, `K_max`, `KXV` and friends -- all two levels down -- arrive
%   VERBATIM. Both spellings are accepted for the one block-level field that
%   moves, per the standing rule in DID-schema CLAUDE.md.
%
%     ngrid.data_dim            -> one axis entry per dimension, per PLANE
%     ngrid.coordinates         -> axes[].values (the lag axis) / dropped as
%                                  redundant (the two index axes)
%     ngrid.data_type 'double'  -> subject_statement.datum_type 'float64'
%                                  + source_datum_type 'double' (jDatumType)
%     ngrid.data_size 8         -> DROPPED. Bytes-per-element restates the
%                                  dtype; it is derivable, unlike coordinates.
%     reverse_correlation.method 'Hartley'
%                               -> receptive_field.value.method, a term. NOT in
%                                  the class name (T11: the name must not read
%                                  as how it was made).
%     reverse_correlation.dimension_labels ''
%                               -> DROPPED. Empty in 210 of 210, and the
%                                  signature names it droppable.
%     hartley_calc.input_parameters {T, X_sample, Y_sample}
%                               -> subject_interaction.method_parameters, via
%                                  jCalculation's shared reader.
%     hartley_reverse_correlation.reconstruction_properties.{T,X,Y}_coords
%                               -> the axis segmentation (above). They are the
%                                  un-concatenated form of `ngrid.coordinates`;
%                                  carrying both would be the drift T14 exists
%                                  to prevent, so they land ONCE, on axes[].
%     hartley_reverse_correlation.spiketimes
%                               -> a THIRD sampled_body, INPUT side, with
%                                  `derived_from_1` -> the neuron. See below.
%     hartley_reverse_correlation.stimulus_properties
%                               -> DROPPED, GUARDED. See below.
%     hartley_reverse_correlation.frame_times + .hartley_numbers
%                               -> method_parameters.stimulus_sequence. See below.
%     app                       -> a `software` entity + execution_environment
%                                  (jSoftwareFromApp, the R1 model).
%     base.id                   -> PRESERVED on the leaf. depends_on carried.
%
%   ---------------------------------------------------------------------
%   `spiketimes`: WHY A BODY, AND WHY ON THE CALCULATION
%   ---------------------------------------------------------------------
%   The signature diverges from finding F6 deliberately and says why: F6 read
%   these as "primary archival data on the neuron-subject" under the ensemble
%   model, and the team decided otherwise, on the data --
%   `neuron_extracellular` carries no spike train at all, and these spike times
%   are WINDOWED to one presentation (210 sets over 21 neurons x 10
%   presentations, reproduced in the census above). "Filing a windowed subset
%   as archival would make a partial train indistinguishable from a complete
%   one."
%
%   So the body's `statement` edge points at the CALCULATION, and a
%   `derived_from_1` edge points at the neuron the times came from. The event
%   times are the axis COORDINATES of a one-axis irregular body -- the same
%   idiom the signed model uses for `frameTimes` ("the irregular time axis")
%   -- because a `sampled_body` has no inline value slot and there are no bytes
%   to attach for this block.
%
%   `derived_from_1` IS NOT DECLARED ON `data_body`, WHICH DECLARES ONLY
%   `statement` (required) AND `filter_id`. An undeclared edge is TOLERATED:
%   +did2/+schema/cache.m allows `depends_on` as a whole (`allowedTop`, :898)
%   and only checks that DECLARED-required edges are non-empty (:910-928).
%   It resolves in the reference sweep because element ids are PRESERVED by
%   +migrators_j/element.m. Whether `data_body` should DECLARE the edge is a
%   team question and is reported as one; it is not decided here.
%
%   ---------------------------------------------------------------------
%   `stimulus_properties`: THE GUARD, AND THE HALF A MIGRATOR CANNOT DO
%   ---------------------------------------------------------------------
%   The signature says: checked for equality against the presentation's
%   generator spec, dropped only when equal, REFUSED AND REPORTED when not.
%
%   A SINGLE-DOCUMENT MIGRATOR CANNOT DO THE EQUALITY HALF. v1_to_v2 calls a
%   migrator as `feval(fqn, v2Body)` with exactly one argument (:621); there is
%   no batch, no database and no way to follow `stimulus_presentation_id`. This
%   is the same division resolveResponseParameters records for #61 ("A
%   single-document migrator cannot inline the parameters -- it cannot follow
%   `stimulus_response_scalar_parameters_id`").
%
%   SO THE CHECK IS SPLIT, and each half is done where it CAN be done:
%
%     HERE, and it refuses:  the drop is lossless only if the referenced
%       presentation is there to hold the spec, and only if every key in the
%       block is one the presentation's generator spec supplies. Both are
%       properties of THIS document, so both are checked, and a failure raises
%       `did2:convert:hartleyStimulusPropertiesUnverifiable` -- a visible
%       quarantine, not a silent drop.
%     did2.validate.sourceCensus, and it reports:  the value-by-value
%       comparison against the referenced presentation, over the v1 SOURCE
%       batch where both documents are in hand. Report-only, with its own
%       denominator.
%
%   THE EIGHT KEYS AND THEIR PRESENTATION COUNTERPARTS, measured over all 210
%   documents joined to their referenced presentation (10 presentations, all
%   resolved):
%
%     DENOMINATOR: 210 hartley_calc doc(s) x their referenced presentation
%       210  M == M            210  L_max == L_absmax   210  K_max == K_absmax
%       210  sf_max == sfmax   210  fps == fps          210  rect == rect
%       210  color_high == chromhigh                    210  color_low == chromlow
%       210  ALL 8 EQUAL: True
%
%   THAT IS A MEASUREMENT, NOT A LICENCE. It is one corpus, and the corpora are
%   a sample; that is exactly why the guard below tests the SHAPE per document
%   rather than trusting the number, and why the census re-measures the VALUES
%   on every run instead of citing this block.
%
%   ---------------------------------------------------------------------
%   `frame_times` + `hartley_numbers`: PARKED, AND SAID OUT LOUD
%   ---------------------------------------------------------------------
%   The signature sends `frameTimes` to "the irregular time axis of the
%   per-presentation `timed_sequence`", and says NOTHING about
%   `hartley_numbers` (S / KXV / KYV / ORDER, four parallel 3360-vectors that
%   name which basis function was shown on each frame). They are one table:
%   frame k showed stimulus (S, KXV, KYV, ORDER)(k) at time frame_times(k), and
%   3360 == 3360 in 210 of 210.
%
%   NEITHER CAN BE BUILT HERE. `timed_sequence` is DECLARED ABSTRACT
%   (schemas/V_eta/draft/timed_sequence.json) and +did2/+schema/cache.m raises
%   `did2:validation:abstractInstantiation` for any document naming an abstract
%   class, so the destination cannot be instantiated at all; it belongs to the
%   stimulus model (#31), which is out of this signature's scope.
%
%   THEY ARE THEREFORE CARRIED, NOT DROPPED, in
%   `subject_interaction.method_parameters.stimulus_sequence`. That field is
%   declared free-form and its documentation is "the calculator input_parameters
%   that produced it [...] Retaining it keeps the computation reproducible" --
%   and these two blocks ARE the reverse-correlation's regressors, i.e. exactly
%   what makes it reproducible. It is a HOLDING SLOT, not a model decision:
%   when #31 lands, the sequence moves to the `timed_sequence` and this key
%   goes. Dropping them instead would be a silent loss of 5 x 3360 real values
%   per document, which is the failure this repository's whole error history is
%   made of. Reported as a team question.
%
%   See also: did2.convert.migrators_j.private.jCalculation,
%             did2.convert.migrators_j.private.jNgridBody,
%             did2.convert.migrators_j.ontology_image,
%             did2.validate.sourceCensus

arguments
    preBody (1,1) struct
end

% The eight keys the referenced stimulus_presentation's generator spec
% supplies, and therefore the eight this document may drop. Named here, once,
% because the guard and the census must agree on the SAME list -- two lists
% that drift apart is how a check comes to pass while checking nothing.
% Measured against the real presentations: hartley key -> presentation key.
%   M -> M, L_max -> L_absmax, K_max -> K_absmax, sf_max -> sfmax, fps -> fps,
%   color_high -> chromhigh, color_low -> chromlow, rect -> rect
STIMULUS_PROPERTY_KEYS = {'M', 'L_max', 'K_max', 'sf_max', 'fps', ...
    'color_high', 'color_low', 'rect'};

rc  = blockOf(preBody, 'reverse_correlation');
hrc = blockOf(preBody, 'hartley_reverse_correlation');

% ---- GUARD 1: the ngrid block must be here ---------------------------------
% Without it there is no response volume, and a receptive_field with
% `storage_mode: body` and no body is a husk that validates clean -- the
% 4,563-document image_stack lesson.
if ~isfield(preBody, 'ngrid') || ~isstruct(preBody.ngrid)
    error('did2:convert:hartleyNgridBlockMissing', ...
        ['hartley_calc "%s" carries no `ngrid` block, so there is no response ' ...
         'volume to fold. NDIcalc-vis builds the document with `ngrid` as one ' ...
         'of its four blocks (V_eta_ngrid_family_findings.md F1), and all 210 ' ...
         'documents in corpus 20211116 carry it. Refusing rather than emitting ' ...
         'a receptive_field whose value lives nowhere.'], sourceId(preBody));
end

% ---- GUARD 2: stimulus_properties may only be dropped when it is redundant --
presentationId = firstDepValue(preBody, {'stimulus_presentation_id'});
checkStimulusPropertiesAreDroppable(preBody, hrc, presentationId, ...
    STIMULUS_PROPERTY_KEYS);

% ---- the axis segmentation, VERIFIED against the stored vector -------------
% One vector per data_dim entry of ONE PLANE, in data_dim order. jNgridBody
% checks that these re-concatenate (in some order) to `ngrid.coordinates`
% exactly, so a wrong assignment here fails loudly instead of mislabelling.
[planeDim, axisCoords, axisLabels] = planeAxes(preBody, hrc);

% ---- the leaf, via the shared calculator fold ------------------------------
% jCalculation owns everything that makes a calculator fold a calculator:
% base.id PRESERVED (so inbound refs resolve -- the 11,448-orphan lesson),
% element_id -> subject_id, the session anchor + its time_reference_1 edge,
% input_parameters -> method_parameters, and app -> a software entity.
% `valueOverride` is the documented hook for a composite whose value is
% RESHAPED rather than carried verbatim; the RF value is descriptors only,
% because the payload is body-backed.
bodies = jCalculation(preBody, 'receptive_field_calculation', 'receptive_field', ...
    'receptive field', 'ndi.calc.vis.hartley', 'hartley_calc', ...
    receptiveFieldValue(rc));

leaf = bodies{1};

% The payload is body-backed, and the statement says so. jCalculation seeds
% 'inline', which is right for the twelve calculators whose result is a small
% matrix and wrong here: a plane is 200x200x36 doubles.
leaf.subject_statement.storage_mode = 'body';

% The volume's encoding belongs to the STATEMENT (signed sec.5). jNgridBody
% reads it off `ngrid.data_type` and hands it back rather than writing it,
% because it mints bodies and the caller owns the statement.
[planeBodies, datumType, sourceDatumType] = planeSampledBodies(preBody, ...
    leaf.base.id, planeDim, axisCoords, axisLabels);
leaf.subject_statement.datum_type = datumType;
leaf.subject_statement.source_datum_type = sourceDatumType;

% The stimulus sequence the reverse correlation regressed against. PARKED, not
% modelled -- see the header. Appended to the parameters jCalculation already
% read off `hartley_calc.input_parameters`.
sequence = stimulusSequence(hrc);
if ~isempty(fieldnames(sequence))
    if ~isfield(leaf, 'subject_interaction') || ~isstruct(leaf.subject_interaction)
        leaf.subject_interaction = struct();
    end
    if ~isfield(leaf.subject_interaction, 'method_parameters') ...
            || ~isstruct(leaf.subject_interaction.method_parameters)
        leaf.subject_interaction.method_parameters = struct();
    end
    leaf.subject_interaction.method_parameters.stimulus_sequence = sequence;
end

% The presentation the field was computed against: provenance, not a subject.
% CONDITIONAL, never blank -- a declared-but-empty edge is the invented-empty-
% edge pattern (7,233 documents). Guard 2 above has already refused the
% document if this is missing, so the branch is belt-and-braces rather than a
% live alternative; it stays because a guard and its consumer drifting apart is
% how an empty edge gets emitted.
%
% jCalculation fills `derived_from_1` only from the three stimulus-response
% edge names (jCalculation.m firstDepValue), none of which a hartley_calc
% carries, so the slot is free and there is no collision to reason about.
if ~isempty(presentationId)
    leaf.depends_on(end+1) = struct('name', 'derived_from_1', ...
        'value', presentationId);
end

bodies{1} = leaf;

% ---- the bodies ------------------------------------------------------------
% ORDER IS LOAD-BEARING. `receptive_field.value.planes` is declared as "one
% entry per emitted body in emission order", so the two plane bodies are
% appended FIRST and in plane order. The spike-time body follows and is not a
% plane: it carries no file, its single axis is time, and its base.name says
% so. A reader pairing `planes` with bodies takes the first numel(planes).
for k = 1:numel(planeBodies)
    bodies{end+1} = planeBodies{k}; %#ok<AGROW>
end

spikeBody = spikeTimesBody(preBody, hrc, leaf);
if ~isempty(spikeBody)
    bodies{end+1} = spikeBody;
end
end

% ===================== the composite value =================================

function value = receptiveFieldValue(rc)
%RECEPTIVEFIELDVALUE The `receptive_field` descriptors. The volume is NOT here.
%
%   Three sub-fields, and only `planes` is mustBeNonEmpty:
%     method        `reverse_correlation.method`, verbatim as the term's name.
%                   'Hartley' in 210 of 210. The node is left blank: no CURIE
%                   has been minted for it, and inventing one would be a
%                   fragment (#70) rather than a binding.
%     storage_mode  'body'. The schema's own words: "`body` for a sampled_body
%                   per plane, which is the only mode a real receptive field
%                   uses."
%     planes        one entry per emitted body, IN EMISSION ORDER.
%
%   THE TWO PLANE NAMES COME FROM THE WRITER, which this container does not
%   hold -- the NDIcalc-vis clone is ephemeral and is not in scope now. They are
%   taken from the committed reading of it in
%   V_eta_ngrid_family_findings.md F2, quoted there from
%   `+ndi/+calc/+vis/hartley.m`:
%
%       ngridp.data_dim = [size(sta) 2];
%       fwrite(fid, cat(4, sta, p_val), 'double');
%
%   so plane 1 is the spike-triggered average (the response estimate) and plane
%   2 is the per-voxel p-value map (its significance). The schema's own
%   documentation for `planes[].quantity` names exactly that pair: "What this
%   plane holds (the response estimate, or its significance)."
value = struct();
value.method = jOntologyTerm('', jGetChar(rc, 'method'));
value.storage_mode = 'body';
% Assigned in its own statement and built by concatenation, NOT inside
% struct(...): a non-scalar struct passed to struct() DISTRIBUTES into a struct
% array of values instead of becoming one field. image_stack.m and jNgridBody.m
% both carry a comment about this trap.
planes = struct('quantity', jOntologyTerm('', 'response estimate'));
planes(2) = struct('quantity', jOntologyTerm('', 'significance'));
value.planes = planes;
end

% ===================== the axis segmentation ===============================

function [planeDim, axisCoords, axisLabels] = planeAxes(preBody, hrc)
%PLANEAXES Split `ngrid` into ONE PLANE's dims and their coordinate vectors.
%
%   Returns, for one plane:
%     planeDim    the data_dim entries that describe a plane, in order
%     axisCoords  1xN cell, the coordinate vector for each of them ([] = none)
%     axisLabels  1xN cellstr, the axis variable names ('' = positional)
%
%   THE PLANE DIMENSION IS FOUND BY SUBTRACTION, NOT BY POSITION. `data_dim` is
%   [200 200 36 2] and `coordinates` has 436 entries; 200+200+36 = 436 and
%   200+200+36+2 = 438, so the length-2 dimension is the one with no
%   coordinates. That is the signature's own reasoning ("the writer itself
%   gives the length-2 dimension no coordinates"), and it is re-derived per
%   document here rather than hard-coded, because a hard-coded 2 would silently
%   accept a document shaped differently.
%
%   THE COORDINATE VECTORS COME FROM `reconstruction_properties`, which holds
%   the SAME numbers un-concatenated -- T_coords, X_coords, Y_coords -- and
%   they are matched to dims BY LENGTH. jNgridBody then verifies that they
%   re-concatenate to `ngrid.coordinates` exactly, so a length collision that
%   produced a wrong assignment cannot pass silently.
%
%   `reconstruction_properties` is TWO levels down, so universalRenames does not
%   touch its field names: `T_coords` arrives verbatim (snakeCaseBlockFields
%   runs one level inside each block only).
block   = preBody.ngrid;
dataDim = numericRow(fieldOr(block, 'data_dim', []));
coords  = numericColumn(fieldOr(block, 'coordinates', []));

if isempty(dataDim)
    error('did2:convert:hartleyNgridDataDimMissing', ...
        ['hartley_calc "%s" declares no `ngrid.data_dim`, so the response ' ...
         'volume has no shape and no axis entry can be built. All 210 ' ...
         'documents in corpus 20211116 declare [200 200 36 2].'], ...
        sourceId(preBody));
end

recon = struct();
if isstruct(hrc) && isfield(hrc, 'reconstruction_properties') ...
        && isstruct(hrc.reconstruction_properties)
    recon = hrc.reconstruction_properties;
end
lagCoords = numericColumn(fieldOr(recon, 'T_coords', []));
xCoords   = numericColumn(fieldOr(recon, 'X_coords', []));
yCoords   = numericColumn(fieldOr(recon, 'Y_coords', []));
supplied  = {lagCoords, xCoords, yCoords};
% The lag axis is the ONLY one named, and the name rests on positive evidence:
% its coordinates equal `hartley_calc.input_parameters.T` in 210 of 210. The
% other two are positional -- see the header for why guessing X vs Y is not
% available from this document.
suppliedLabels = {'lag', '', ''};
supplied  = supplied(~cellfun(@isempty, supplied));
suppliedLabels = suppliedLabels(1:numel(supplied));

% Which dims does the coordinate vector account for? Drop dims from the END
% until the remainder sums to numel(coords) -- the trailing plane-count
% dimension is the writer's own layout (`data_dim = [size(sta) 2]`).
planeDim = dataDim;
while ~isempty(planeDim) && sum(planeDim) > numel(coords)
    planeDim(end) = [];
end
if isempty(planeDim) || sum(planeDim) ~= numel(coords)
    error('did2:convert:hartleyCoordinateCountUnaccounted', ...
        ['hartley_calc "%s": `ngrid.coordinates` has %d value(s) and no ' ...
         'leading run of data_dim [%s] sums to it, so which dimensions are ' ...
         'coordinate axes cannot be established. The measured shape is ' ...
         'data_dim [200 200 36 2] with 436 coordinates (the trailing 2-plane ' ...
         'dimension carries none) in 210 of 210 documents. Refusing rather ' ...
         'than guessing which axis the numbers describe.'], ...
        sourceId(preBody), numel(coords), num2str(dataDim));
end

% Match each plane dim to a supplied vector of the same length. A vector may be
% used once. An unmatched dim gets [] and becomes a plain index axis.
axisCoords = cell(1, numel(planeDim));
axisLabels = repmat({''}, 1, numel(planeDim));
used = false(1, numel(supplied));
for k = 1:numel(planeDim)
    for s = 1:numel(supplied)
        if ~used(s) && numel(supplied{s}) == planeDim(k)
            axisCoords{k}  = supplied{s};
            axisLabels{k}  = suppliedLabels{s};
            used(s) = true;
            break;
        end
    end
end
if any(~used)
    error('did2:convert:hartleyReconstructionCoordsUnplaced', ...
        ['hartley_calc "%s": %d of %d reconstruction_properties coordinate ' ...
         'vector(s) match no dimension of data_dim [%s]. They are the ' ...
         'un-concatenated form of `ngrid.coordinates`, so a vector with ' ...
         'nowhere to go means the two disagree about the volume. Refusing.'], ...
        sourceId(preBody), sum(~used), numel(supplied), num2str(planeDim));
end
end

% ===================== the bodies ==========================================

function [planeBodies, datumType, sourceDatumType] = planeSampledBodies( ...
        preBody, statementId, planeDim, axisCoords, axisLabels)
%PLANESAMPLEDBODIES One `sampled_body` per plane of the response volume.
%
%   TWO BODIES, ONE FILE, AND THAT IS STATED RATHER THAN HIDDEN. The v1
%   document attaches a single `hartley_results.ngrid` holding
%   `cat(4, sta, p_val)`, so both planes live in one byte stream and there is
%   no byte-range field anywhere in `data_body` to split it with. Both bodies
%   therefore declare the SAME file, and each says in `description` which plane
%   of it is its own. Declaring the file on only one body would make the other
%   plane's bytes unreachable from the document that describes them, which is
%   the worse of the two.
%
%   The file name is carried VERBATIM. universalRenames skips the structural
%   keys outright (skip = {'document_class','depends_on','file','files'}), so
%   `hartley_results.ngrid` arrives unrenamed and must leave unrenamed -- the
%   image_stack tombstone declared `imagestack_file` while NDI writes
%   `imageStack`, which is this exact mistake in both directions at once.
nPlanes = 2;
planeNames = {'response estimate', 'significance'};
planeBodies = cell(1, nPlanes);
datumType = '';
sourceDatumType = '';
for k = 1:nPlanes
    [b, dt, sdt] = jNgridBody(preBody, statementId, ...
        sprintf('migrated_receptive_field_plane_%d', k), axisLabels, ...
        'DataDim', planeDim, 'AxisCoordinates', axisCoords);
    if k == 1
        datumType = dt;
        sourceDatumType = sdt;
    end
    % `datum_order` IS SET AND `byte_order` IS NOT, and the difference is
    % evidence. The schema calls both "REQUIRED in practice" -- datum_order
    % whenever there is more than one axis, byte_order whenever the datum is
    % multi-byte -- and both are optional to the validator, so a wrong value
    % here would be silent.
    %   datum_order 'F'  A PROPERTY OF THE LANGUAGE, not a guess. The writer is
    %                    `fwrite(fid, cat(4, sta, p_val), 'double')`
    %                    (V_eta_ngrid_family_findings.md F2, quoting
    %                    +ndi/+calc/+vis/hartley.m), and MATLAB linearises an
    %                    array column-major. Without it a 200x200x36 volume
    %                    cannot be reassembled from the bytes at all.
    %   byte_order  ''   NOT INFERRED. The document records the producing
    %                    machine (`app.os` is 'MACA64' in all 210) and NOT its
    %                    endianness; reading one off the other would be a guess
    %                    recorded as a fact, and an empty field is a legal "not
    %                    stated" while a wrong one is undetectable.
    b.sampled_body.datum_order = 'F';
    b.data_body = struct( ...
        'filename', sourceFileName(preBody), ...
        'description', sprintf(['plane %d of %d in the source ngrid file: ' ...
            'the %s. The v1 writer stores both planes in one stream ' ...
            '(cat(4, sta, p_val)), so both bodies name the same file.'], ...
            k, nPlanes, planeNames{k}));
    if isfield(preBody, 'files'); b.files = preBody.files; end
    if isfield(preBody, 'file');  b.file  = preBody.file;  end
    planeBodies{k} = b;
end
end

function body = spikeTimesBody(preBody, hrc, leaf)
%SPIKETIMESBODY The windowed spike train, as CALCULATION INPUT.
%
%   Returns [] when there are no spike times: an empty body is a husk, and this
%   block is genuinely per-document (194 distinct lengths across the 210).
%
%   The times are the axis COORDINATES of a single irregular axis. That is the
%   signed idiom for event times ("the irregular time axis"), and it is the
%   only lossless one available: `sampled_body` carries values in bytes, and
%   this block has no attached file.
times = numericColumn(fieldOr(hrc, 'spiketimes', []));
if isempty(times)
    body = [];
    return;
end
body = jSampledBody(char(leaf.base.id), baseField(preBody, 'session_id', ''), ...
    baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'), ...
    'migrated_receptive_field_input_spiketimes');
body.sampled_body.axes = jAxis(jOntologyTerm('', 'time'), numel(times), ...
    'regular', false, ...
    'values', struct('values', times, 'source_values', times));
body.data_body = struct('description', ...
    ['the spike times the reverse correlation consumed, WINDOWED to one ' ...
     'stimulus presentation. Calculation input, not archival data: a ' ...
     'windowed subset filed as archival would be indistinguishable from a ' ...
     'complete train (TEAM-SIGN-OFF [receptive field fold]).']);

% The neuron the times came from. `element_id` IS a subject edge --
% +migrators_j/element.m promotes elements to subjects with their ids
% PRESERVED, which is a recurring trap in this repo and is why it is written
% down here. Appended only when it is non-empty; never blank.
neuronId = firstDepValue(preBody, {'element_id', 'subject_id'});
if ~isempty(neuronId)
    body.depends_on(end+1) = struct('name', 'derived_from_1', 'value', neuronId);
end
end

% ===================== the stimulus blocks =================================

function checkStimulusPropertiesAreDroppable(preBody, hrc, presentationId, keys)
%CHECKSTIMULUSPROPERTIESAREDROPPABLE Refuse a drop this document cannot justify.
%
%   TWO CONDITIONS, both properties of THIS document, because that is all a
%   single-document migrator can see. The value-by-value comparison is the
%   census's half -- see the header.
%
%     (1) THE REFERENT MUST EXIST. Dropping the block is lossless only because
%         the referenced `stimulus_presentation` holds the same spec, and that
%         document survives migration intact (+migrators_j/stimulus_presentation.m
%         is a guarded passthrough, deferring the decomposition to #31). With
%         no edge there is nothing holding the spec and the drop is a deletion.
%     (2) EVERY KEY MUST BE ONE THE SPEC SUPPLIES. A key outside the measured
%         eight is a field no presentation is known to carry, so its redundancy
%         has not been established for any document, let alone this one.
%
%   NOT TOLERANT, and deliberately so -- the same stance as jNgridBody's
%   coordinates guard. An unexpected key means the writer changed, and
%   "no corpus we looked at has one" is a fact about a SAMPLE.
if ~isstruct(hrc) || ~isfield(hrc, 'stimulus_properties') ...
        || ~isstruct(hrc.stimulus_properties)
    return;    % nothing to drop
end
if isempty(presentationId)
    error('did2:convert:hartleyStimulusPropertiesUnverifiable', ...
        ['hartley_calc "%s" carries a `stimulus_properties` block and NO ' ...
         '`stimulus_presentation_id` edge. The block is dropped only because ' ...
         'the referenced presentation holds the same generator spec ' ...
         '(TEAM-SIGN-OFF [receptive field fold]); with no referent the drop ' ...
         'is a deletion of the only copy. All 210 documents in corpus ' ...
         '20211116 carry the edge, populated. Refusing loudly instead.'], ...
        sourceId(preBody));
end
extra = setdiff(fieldnames(hrc.stimulus_properties), keys);
if ~isempty(extra)
    error('did2:convert:hartleyStimulusPropertiesUnverifiable', ...
        ['hartley_calc "%s": `stimulus_properties` carries key(s) {%s} that ' ...
         'are outside the eight the referenced presentation''s generator spec ' ...
         'is known to supply {%s}. Their redundancy has never been measured, ' ...
         'so dropping them would delete data on the strength of a sample. ' ...
         'Refusing loudly instead.'], ...
        sourceId(preBody), strjoin(extra(:)', ', '), strjoin(keys, ', '));
end
end

function sequence = stimulusSequence(hrc)
%STIMULUSSEQUENCE The parked stimulus regressors. See the header.
%
%   `frameTimes` is a BLOCK-LEVEL field, so universalRenames snake_cases it to
%   `frame_times`. Both spellings are read, per the standing rule -- the cost
%   is one line and the failure it prevents is a silent drop of 3,360 values.
sequence = struct();
frameTimes = fieldOr(hrc, 'frame_times', fieldOr(hrc, 'frameTimes', []));
if ~isempty(frameTimes)
    sequence.frame_times = frameTimes;
end
if isstruct(hrc) && isfield(hrc, 'hartley_numbers') ...
        && isstruct(hrc.hartley_numbers)
    sequence.hartley_numbers = hrc.hartley_numbers;
end
end

% ===================== small readers =======================================

function b = blockOf(preBody, name)
b = struct();
if isfield(preBody, name) && isstruct(preBody.(name)) && isscalar(preBody.(name))
    b = preBody.(name);
end
end

function v = fieldOr(s, nm, dflt)
v = dflt;
if isstruct(s) && isfield(s, nm)
    v = s.(nm);
end
end

function v = numericRow(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); end
end

function v = numericColumn(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)); end
end

function v = baseField(bodyStruct, nm, dflt)
v = dflt;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, nm) && ~isempty(bodyStruct.base.(nm))
    v = bodyStruct.base.(nm);
end
end

function name = sourceFileName(preBody)
%SOURCEFILENAME The v1 attachment's name, or '' -- never invented.
name = '';
if isfield(preBody, 'files') && isstruct(preBody.files) ...
        && isfield(preBody.files, 'file_list')
    raw = preBody.files.file_list;
    if ~iscell(raw); raw = {raw}; end
    if ~isempty(raw) && (ischar(raw{1}) || isstring(raw{1}))
        name = char(raw{1});
    end
elseif isfield(preBody, 'file') && isstruct(preBody.file) ...
        && ~isempty(preBody.file) && isfield(preBody.file, 'name')
    name = char(preBody.file(1).name);
end
end

function v = firstDepValue(preBody, names)
%FIRSTDEPVALUE The first present edge value among NAMES, or ''.
%
%   Reads `.value` AND `.document_id`, the two spellings jCarrySubject accepts.
%   ontology_image.m once read a third (`.id`) that jCarrySubject did not, and
%   the divergence produced an observation about nobody that validated clean.
v = '';
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
for s = 1:numel(names)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, names{s})
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value); return;
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id); return;
            end
        end
    end
end
end

function id = sourceId(preBody)
id = '<no base.id>';
if isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isfield(preBody.base, 'id') && ~isempty(preBody.base.id)
    id = char(preBody.base.id);
end
end

function bodies = neuron_extracellular(preBody)
%NEURON_EXTRACELLULAR Brainstorm-J migrator: did_v1 neuron_extracellular -> a
%   DERIVED SUBJECT (the sorted unit) + a derived_from relation + the MEAN SPIKE
%   WAVEFORM as a voltage_observation + the sorter's cluster index + a quality
%   observation (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   A neuron_extracellular is a spike-sorted unit on an extracellular recording,
%   tied to that recording's subject via element_id. #9 analysis-tier "grain B"
%   fold: a sorted cluster is not an observation OF the recording -- it is a
%   DERIVED entity in its own right, so it becomes a `subject` linked back to the
%   recording by a `derived_from` `directed_relation`:
%
%       subject            the sorted unit (bare identity; local_identifier
%                          'unit_<cluster_index>'; id fresh).
%       directed_relation  derived_from: the unit (child) <- the recording subject
%                          (parent). ro:0001000.
%       count_assertion    the sorter's own `cluster_index`, as an assertion ABOUT
%                          the unit. See "CLUSTER_INDEX" below -- this one is a
%                          proposal, not a signature.
%       voltage_observation  the mean spike waveform: microvolt-scale numbers over
%                          a time axis and a channel axis, INLINE on the statement.
%                          Emitted only when the source carries a waveform.
%       score_observation  the sort quality_number, as a scalar observation OF the
%                          unit (inline). Emitted only when quality_number is a
%                          numeric scalar.
%       session_relative_reference   the 'during' anchor shared by both observations.
%
%   1 -> 4 with none of the three conditional bodies; 1 -> 7 on every one of the
%   21 real documents in corpus 20211116, which carry cluster_index, a waveform,
%   quality_number AND an `app` block.
%
%   STILL DEFERRED, and only this: a `term_assertion` of the unit's cell-type kind
%   (subject_defining), and with it `quality_label` -- the human-readable twin of
%   `quality_number` ('multi' / 'single' in the corpus), which has no home on
%   `score` and is NOT folded here.
%
%   STATUS OF THE WAVEFORM FOLD: WRITTEN 2026-08-17 IN A CONTAINER WITH NEITHER
%   MATLAB NOR OCTAVE (`command -v matlab octave` exits 1). Not one line of it has
%   been executed. tests/+did2/+unittest/testMigratorsJNeuronExtracellular.m is
%   the first thing with an opinion; treat a green CI run as the evidence, not
%   this header.
%
%   ---------------------------------------------------------------------
%   WHAT THE 21 REAL DOCUMENTS CONTAIN -- MEASURED, NOT ASSUMED
%   ---------------------------------------------------------------------
%   Read directly off the unpacked corpus (the ground-truth rule: from the
%   documents and the writer, never from a DID-side schema):
%
%     DENOMINATOR: 1220 json file(s) in corpus 20211116; 21 of class
%                  `neuron_extracellular`; 21 readable, 0 skipped
%       21/21  blocks = app, base, depends_on, document_class, neuron_extracellular
%       21/21  NO `file` and NO `files` block  <- see "WHY NOT A sampled_body"
%       21/21  mean_waveform is 21x32, and all 21 are DISTINCT
%              (global range -316.7018 .. 259.4120)
%       21/21  waveform_sample_times has 21 entries; ONE distinct vector overall
%       21/21  number_of_samples_per_channel == 21 == size(mean_waveform,1)
%       21/21  number_of_channels           == 32 == size(mean_waveform,2)
%       21/21  cluster_index 1..21, all distinct;  quality_number in {1,4};
%              quality_label in {'multi','single'}
%       21/21  element_id POPULATED
%       21/21  spike_clusters_id DECLARED AND EMPTY   <- see "THE EMPTY EDGE"
%
%     THE TIME BASE IS EXACTLY REGULAR:
%       21 entries, distinct diffs [5e-05], origin -0.00025 s, spacing 5e-05 s
%       (20 kHz), and max |t(i) - (origin + i*spacing)| = 1.08e-19 across all 21.
%
%   `mean_waveform` IS (samples x channels), ON POSITIVE EVIDENCE, not on the
%   arithmetic that 21 ~= 32. Three independent statements say so:
%     NDI template schema  neuron_extracellular_schema.json, mean_waveform:
%                          "The mean waveform (NumSamples x NumChannels)."
%     an NDI READER        +ndi/+gui/+app/pyraview.m:722-723
%                            waveform = ...neuron_extracellular.mean_waveform; % N x C
%                            [numSamples, numChannels] = size(waveform);
%     an NDI WRITER        +ndi/+fun/+probe/+import/+kilosort/probe.m:546-548
%                            ne.number_of_samples_per_channel = max(size(meanWf,1),1);
%                            ne.number_of_channels           = max(size(meanWf,2),1);
%   That ordering is what `axes` asserts, so it is checked below rather than
%   trusted: axes[k] IS array dimension k, and a positional list has no partial
%   or approximate mode (the pyraview lesson).
%
%   ---------------------------------------------------------------------
%   THE STALE BLOCKER THIS FILE USED TO CARRY, CORRECTED
%   ---------------------------------------------------------------------
%   Until 2026-08-17 the header read:
%
%     "DEFERRED: the inline `mean_waveform` matrix (needs a body-serialization
%      decision -- a sampled_body carries files, not an inline matrix)"
%
%   That was true when written and is not now. `axes[]` landed 2026-08-14
%   (DID-schema V_eta_data_body_model_plan.md, TEAM-SIGN-OFF [data_body]), so an
%   extent no longer needs a body to describe it. The consequence was a real
%   drop, sized in DID-schema V_eta_go_forward_class_audit.md: 672 numbers per
%   document, unique to every neuron, 14,112 across this corpus -- the most
%   identifying physiological feature a sorted unit has -- reaching no emitted
%   document at all.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS AN INLINE STATEMENT AND NOT A `sampled_body`
%   ---------------------------------------------------------------------
%   THIS IS A DEVIATION FROM THE SHAPE THE INVESTIGATION SKETCHED, and it is
%   recorded here rather than done quietly. The audit note proposed "a
%   `sampled_body` with TWO axes: time and channel". Everything else in that
%   sketch is built exactly as written -- a `voltage_observation` of the
%   neuron-subject, over a time axis and a channel axis. What moved is WHERE the
%   axes mount, and the signed model makes that a consequence rather than a
%   choice:
%
%     V_eta_data_body_model_plan.md sec.3, and it is a CHECKED rule, not a style:
%       "storage_mode: inline -> subject_statement.axes[] populated; no bodies
%        storage_mode: body   -> each sampled_body.axes[] populated; statement EMPTY"
%     sec.7:  "Axes live with the thing whose extent they describe."
%
%   A `sampled_body` is bytes: `data_body` declares filename / format /
%   compression / content_hash and a `body_data` file, and there is no value slot
%   anywhere in it. THESE DOCUMENTS HAVE NO BYTES -- 0 of 21 carry a `file` or
%   `files` block, and NDI's own schema for the class declares `"file": [ ]`, so
%   there never will be any. A sampled_body here would describe a 21x32 array of
%   nothing, and all 672 numbers would still be dropped: the same
%   validates-cleanly husk as the 4,563 subject-less image_observations, arrived
%   at from the other direction. The inline path is the only one that actually
%   CARRIES the waveform, which is what the fold exists to do.
%
%   The value is `voltage.value`, a length-672 array of measurement composites --
%   series-as-cardinality (Brainstorm I), the same shape jMeasureArray already
%   builds for electrode_offset_voltage.
%
%   ONE THING THE INLINE PATH CANNOT SAY, AND IT IS A TEAM QUESTION, NOT A BUG.
%   `datum_order` (C | F) is declared on `sampled_body` ONLY. An inline value is
%   a flat array, so a two-axis inline statement has no declared place to say how
%   its dimensions were linearised. This fold flattens column-major -- `w(:)`,
%   MATLAB's own linearisation, which is the order hartley_calc records
%   explicitly as `datum_order = 'F'` and calls "a property of the language" --
%   and axes are emitted in source-dimension order (time, then channel), so
%   `reshape(values, [n_time n_channel])` is the inverse. Recorded rather than
%   worked around: the convention is not stated in the document, and where an
%   inline multi-axis value should state it is a schema decision.
%
%   ---------------------------------------------------------------------
%   THE UNIT IS DELIBERATELY UNSTATED
%   ---------------------------------------------------------------------
%   The waveform numbers are microvolt-SCALE (-316.7 .. 259.4), but no unit is
%   declared anywhere. Checked, and the checks are the claim:
%     NDI template            neuron_extracellular.json      -- no unit field
%     NDI schema doc          "The mean waveform (NumSamples x NumChannels)."
%     all three NDI writers   spikesorter.m:254, kilosort/probe.m:548,
%                             kiasort/probe.m:322 -- each assigns a bare matrix
%   So `source_unit` is left '' -- the honest "the source states no unit" -- and
%   the canonical `volts` sub-field is not written at all, because there is no
%   factor to convert by. Inferring microvolts from the magnitude would be a
%   guess recorded as a fact in a queryable field, which is this repository's
%   documented failure mode. Same stance as electrode_offset_voltage.m:90's
%   temperature qualifier ("Unit deliberately left unstated").
%
%   THE TIME AXIS UNIT IS DIFFERENT -- IT IS EVIDENCED, so it is stated as `s`:
%   +ndi/+fun/+probe/+import/+kilosort/probe.m:538 builds it as
%   `wst = ((0:size(meanWf,1)-1)' - (troughsamp-1)) / sample_rate`, samples over
%   a rate, and the V_eta tombstone's own documentation says "(seconds, in the
%   element's local clock)". `source_unit` carries it; the bound canonical `unit`
%   term is left blank, the pyraview.m:414 precedent, so no term is staged.
%
%   ---------------------------------------------------------------------
%   THE TWO COUNT FIELDS ARE DROPPED, AND THE DROP IS CHECKED PER DOCUMENT
%   ---------------------------------------------------------------------
%   `number_of_samples_per_channel` and `number_of_channels` are `size(...,1)`
%   and `size(...,2)` of the matrix beside them -- the writer assigns them from
%   exactly that (kilosort/probe.m:546-547). They go the way `ngrid.data_size`
%   goes: an axis already carries `n`, and storing the same fact twice is the #69
%   shape.
%
%   BUT REDUNDANT IS A PROPERTY OF THE DOCUMENT, NOT OF THE CLASS. A count that
%   disagrees with the matrix means one of the two is wrong, and silently
%   preferring the matrix would drop a real discrepancy. So each is compared and
%   a disagreement ERRORS -- the hartley_calc stance for a drop a document cannot
%   justify. It holds on 21 of 21 here. A count that is ABSENT or non-numeric is
%   not an error: it is simply nothing to check against.
%
%   ---------------------------------------------------------------------
%   CLUSTER_INDEX -- A PROPOSAL, PARKED IN THE OPEN
%   ---------------------------------------------------------------------
%   `cluster_index` is the sorter's own label for the unit, unique per neuron
%   (1..21 across the corpus). Before this change it survived only as TEXT inside
%   the derived subject's `local_identifier`, `unit_<cluster_index>` -- findable
%   by a human, not by a query.
%
%   IT IS EMITTED AS A `count_assertion` OF THE UNIT, and the team may overturn
%   that. The honest statement of the problem: a cluster index is a NOMINAL
%   integer -- a label that happens to be a number -- and V_eta has no nominal
%   integer type. The three candidates and why the others lose:
%
%     count_assertion  CHOSEN. There is an in-tree precedent for exactly this
%                      semantic: jSorterOutput.m:87 models the per-spike cluster
%                      LABEL series as a `count_observation` with variable
%                      'spike cluster assignment', and the team confirmed that
%                      shape for `jrclust_clusters` on 2026-08-17
%                      (V_eta_go_forward_class_audit.md, TEAM-SIGN-OFF
%                      [confirm sheet 2026-08-17]). `count.value.unit` is "what
%                      is counted", and a label counts nothing, so it is left
%                      BLANK rather than invented -- which is also the visible
%                      marker that this is not a cardinality.
%     term_assertion   REJECTED. `term.value` is an ontology_term and is a bound
%                      field; staging the string '7' there says the sorter's
%                      label is an ontology term, which it is not.
%     entity.global_identifier  REJECTED. The {scheme, value} shape fits an
%                      identifier perfectly, but the field's own documentation
%                      names cross-reference registries (ORCID | ROR | DOI |
%                      RRID | ...), and a cluster index is local to one sorting
%                      run -- the scheme string cannot even name that run.
%
%   THE OBJECTION, stated so nobody has to reconstruct it: a consumer that reads
%   every `count` document as a cardinality will pick this up. It is mitigated by
%   `variable` = 'spike sorter cluster index' and by the blank unit, and it is
%   one block on one document -- removable in a line if the team says no.
%   NOTHING HERE IS SIGNED. Operating Rule 4: this is a proposal.
%
%   ---------------------------------------------------------------------
%   THE EMPTY EDGE THAT IS NOT EMITTED
%   ---------------------------------------------------------------------
%   `spike_clusters_id` is DECLARED AND EMPTY on all 21 source documents. It is
%   not a V_eta defect and it is not repaired here -- it is simply never carried
%   onto any emitted body. `RequiredDependencies` is ARMED BY DEFAULT
%   (+did2/+schema/cache.m:72), so a required edge nothing can fill quarantines
%   the document; an optional one validates clean and is invisible, which is the
%   7,233-document invented-empty-edge pattern. Neither is created: no emitted
%   body declares the edge at all.
%
%   ---------------------------------------------------------------------
%   THE `app` BLOCK -> A software ENTITY (the residual is now SMALLER)
%   ---------------------------------------------------------------------
%   STATUS OF THIS REPAIR: NOT RUN. There is no MATLAB in the environment it was
%   written in. The gate is tests/+did2/+unittest/testMigratorsJAppFold.m, unrun.
%
%   `neuron_extracellular` declares the `app` superclass on NDI origin/main --
%   read from the template:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/neuron/neuron_extracellular.json
%         superclasses: [ base.json, app.json ]
%
%   This migrator builds new bodies, so the block had no successor and the
%   sorting program that produced the unit was discarded on every document.
%
%   R1 (TEAM-SIGN-OFF [software], V_eta_tenet_audit.md): the block becomes a
%   `software` ENTITY + a `software_id` edge + `execution_environment`. WHICH
%   EMITTED BODIES CAN CARRY THAT EDGE -- checked against the built schemas, not
%   assumed. `software_id` is declared once in the statement tier, on
%   `subject_interaction`:
%
%       subject                     -> entity -> base            NO software_id
%       directed_relation           -> relation -> base          NO software_id
%       session_relative_reference  -> time_reference -> base    NO software_id
%       count_assertion             -> subject_assertion
%                                   -> subject_statement         NO software_id
%       voltage_observation         -> subject_observation
%                                   -> subject_interaction       YES (+ exec env)
%       score_observation           -> subject_observation
%                                   -> subject_interaction       YES (+ exec env)
%
%   THE RESIDUAL IS SMALLER THAN IT WAS AND IS NOT CLOSED. Before the waveform
%   fold the only carrier was the score_observation, which is emitted only when
%   `quality_number` is a numeric scalar; a unit without a quality number had
%   nowhere typed to put its software. Now the waveform observation is a second
%   carrier, so the gap is only a document with NEITHER a quality number NOR a
%   waveform. That case still has nowhere to put it, and no slot is invented for
%   it -- inventing an edge on a class that does not declare it is the pattern
%   that produced the invented-empty-edge family. The `software` entity is
%   emitted ONLY when some body took the edge, so it is never left unreferenced.
%
%   ---------------------------------------------------------------------
%   FOUR UNMINTED TERMS ARE ADDED, NAMED HERE SO THE DEBT IS NOT ANONYMOUS
%   ---------------------------------------------------------------------
%   DID-schema tools/check_empty_ontology_nodes.py, the #70 ratchet, moves
%   56 -> 60 on this change. Every one of the four is a jOntologyTerm built with
%   a real name and a BLANK node -- staged, not minted:
%
%   (AND THE PHRASING OF THAT SENTENCE IS LOAD-BEARING. The harvester matches a
%   regex over the raw file and does NOT skip comments, so writing the call
%   pattern out literally in this header counted as a 61st emission with the
%   name `<computed: name>`. Caught by running the tool; the count was 61 before
%   this paragraph was reworded. Name the helper in prose, never spell the call.)
%
%       'mean spike waveform'         the statement's `variable`
%       'time'                        the time axis's `variable` (ONE call site;
%                                     the term is built above the regular/
%                                     irregular branch so it is not staged twice)
%       'channel'                     the channel axis's `variable`
%       'spike sorter cluster index'  the count_assertion's `variable`
%
%   NONE OF THEM COULD HAVE BEEN MINTED HERE. An NDI-side identifier is
%   `NDIC:<n>` and that table moved out of NDI to VH-Lab/ndi-ontology-matlab,
%   which is not in this session's scope -- the same reason recorded against
%   every other row of that backlog. THE BASELINE IS NOT RAISED FROM THIS
%   REPOSITORY: `BASELINE_MIGRATORS` lives in DID-schema and raising it is a
%   deliberate act by whoever owns that repo, which is exactly what the ratchet
%   is for. Until it is raised, that gate is RED on this change, by design.
%
%   `time` and `channel` are already staged unminted by pyraview.m:370,414 under
%   the same names, so this adds no NEW vocabulary for those two -- only new
%   call sites, which is what the instrument counts.
%
%   RequireSession is TRUE: base.session_id is mustBeNonEmpty and v1_to_v2
%   quarantines the SOURCE when a body it produced fails. It removes nothing --
%   all bodies take the same session_id, so a sessionless document already fails;
%   the guard only stops the new body being the cause.

arguments
    preBody (1,1) struct
end

blk = getBlock(preBody, 'neuron_extracellular');
recordingSubjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));

clusterIndex = getField(blk, 'cluster_index');
unitName = 'unit';
if isnumeric(clusterIndex) && isscalar(clusterIndex)
    unitName = sprintf('unit_%d', round(clusterIndex));
end

neuronId = did.ido.unique_id();
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');

% ---- the derived subject: the sorted unit ----------------------------------
neuron = struct();
neuron.document_class = struct('class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
neuron.depends_on = struct('name', {}, 'value', {});
neuron.base = struct('id', neuronId, 'session_id', sessionId, ...
    'name', unitName, 'datestamp', datestamp);
neuron.subject = struct('local_identifier', unitName, 'description', ...
    'spike-sorted extracellular unit (derived)');

% ---- the provenance relation: unit derived_from the recording subject -------
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', neuronId), ...
    struct('name', 'parent', 'value', recordingSubjectId)];
rel.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'derived_from', 'datestamp', datestamp);
rel.directed_relation = struct('relation', otTerm('ro:0001000', 'derived_from'));

% ---- the shared session anchor ('during') for the observations --------------
anchorId = did.ido.unique_id();
anchor = struct();
% PASS-1 HANDLE, NOT AN UNMIGRATED CLASS. The signed model retires this class in
% favour of `relative_reference`, but the same plan makes the change impossible
% here: `relative_to` is REQUIRED and is not fillable in pass 1 (this body holds
% base.session_id; the edge needs the session DOCUMENT's base.id). Emitting the
% new class with an empty required edge would be ~106k husks that validate clean.
% did2.convert.resolveSessionAnchors folds it in a batch pass, id PRESERVED. Full
% reasoning in +migrators_j/private/jSessionAnchor.m; the seam is pinned by
% tests/+did2/+unittest/testSessionAnchorEmitterContract.m.
anchor.document_class = classBlock('session_relative_reference', {'time_reference'});
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

bodies = {neuron, rel, anchor};

% ---- the sorter's cluster index (see "CLUSTER_INDEX" in the header) ---------
if isnumeric(clusterIndex) && isscalar(clusterIndex) && isfinite(clusterIndex)
    cidx = struct();
    cidx.document_class = classBlock('count_assertion', {'subject_assertion', 'count'});
    cidx.depends_on = struct('name', {'subject_id'}, 'value', {neuronId});
    cidx.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
        'name', 'migrated_sorter_cluster_index', 'datestamp', datestamp);
    cidx.subject_statement = struct( ...
        'variable', jOntologyTerm('', 'spike sorter cluster index'), ...
        'storage_mode', 'inline');
    % Assigned in its own statement rather than inside struct(...): the value of
    % `count` is a composite, and a non-scalar struct passed to struct()
    % DISTRIBUTES into a struct array of blocks instead of setting one field.
    % Scalar here, but the idiom is uniform across this file for that reason.
    cidx.count = struct();
    % `unit` is "what is counted" and this counts nothing -- BLANK, not invented.
    cidx.count.value = struct('value', round(double(clusterIndex)), ...
        'unit', otTerm('', ''), 'approximate', false);
    bodies{end+1} = cidx;
end

% ---- the v1 `app` block -> a software entity (+ the edge, on the obs) -------
% jSoftwareFromApp reads BOTH spellings of name/version (universalRenames has
% already rewritten app.name -> app.app_name by the time a migrator runs).
% The entity is emitted ONLY when some body took the edge -- see the header:
% none of {subject, directed_relation, session_relative_reference,
% count_assertion} declares `software_id`, and an unreferenced entity would
% record the software without recording what it produced.
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);
softwareIsReferenced = false;

% ---- the mean spike waveform as a voltage_observation OF the unit ----------
wobs = meanWaveformObservation(blk, neuronId, anchorId, sessionId, datestamp);
if ~isempty(wobs)
    if ~isempty(swId)
        wobs.depends_on(end+1) = struct('name', 'software_id', 'value', swId);
        softwareIsReferenced = true;
    end
    if ~isempty(fieldnames(execEnv))
        wobs.subject_interaction.execution_environment = execEnv;
    end
    bodies{end+1} = wobs;
end

% ---- the sort quality as a score_observation OF the unit (inline) -----------
quality = getField(blk, 'quality_number');
if isnumeric(quality) && isscalar(quality)
    qobs = struct();
    qobs.document_class = classBlock('score_observation', {'subject_observation', 'score'});
    qobs.depends_on = [ ...
        struct('name', 'subject_id',       'value', neuronId), ...
        struct('name', 'time_reference_1', 'value', anchorId)];
    qobs.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
        'name', 'migrated_sort_quality', 'datestamp', datestamp);
    qobs.subject_statement = struct('variable', otTerm('', 'spike sort quality'), ...
        'storage_mode', 'inline');
    qobs.subject_interaction = struct('method', otTerm('', ''), ...
        'sample_time', struct('kind', 'point'));
    qobs.subject_observation = struct();
    qobs.score = struct('value', struct('value', double(quality), ...
        'scale', otTerm('', ''), 'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false));
    if ~isempty(swId)
        qobs.depends_on(end+1) = struct('name', 'software_id', 'value', swId);
        softwareIsReferenced = true;
    end
    if ~isempty(fieldnames(execEnv))
        qobs.subject_interaction.execution_environment = execEnv;
    end
    bodies{end+1} = qobs;
end

if softwareIsReferenced && ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== the mean waveform ===================================

function obs = meanWaveformObservation(blk, neuronId, anchorId, sessionId, datestamp)
%MEANWAVEFORMOBSERVATION The mean spike waveform as an inline voltage_observation
%   of the sorted unit, over a time axis and a channel axis.
%
%   Returns [] when the source carries no waveform, and that is a REAL, EXPECTED
%   case rather than a defect: the writer sets both halves to empty together --
%   +ndi/+fun/+probe/+import/+kilosort/probe.m:543-545
%       else,
%           meanWf = [];
%           wst    = [];
%   -- when `waveform_source` is not 'templates'. An observation minted from
%   nothing would be a husk that validates clean, so nothing is minted.
obs = [];
w = getField(blk, 'mean_waveform');
t = getField(blk, 'waveform_sample_times');
if ~isnumeric(w) || isempty(w) || ~isnumeric(t) || isempty(t)
    return;
end
if ~ismatrix(w)
    error('did2:convert:neuronWaveformNotAMatrix', ...
        ['neuron_extracellular `mean_waveform` has %d dimensions. NDI declares ' ...
         'it (NumSamples x NumChannels) and all 21 documents in corpus ' ...
         '20211116 are 21x32; a higher-rank array cannot be described by the ' ...
         'two axes this fold emits. Refusing rather than mislabelling them.'], ...
        ndims(w));
end
nTime     = size(w, 1);
nChannels = size(w, 2);

% ---- the two count fields are droppable only if they AGREE ------------------
checkRedundantCount(blk, 'number_of_samples_per_channel', nTime, ...
    'size(mean_waveform,1)');
checkRedundantCount(blk, 'number_of_channels', nChannels, ...
    'size(mean_waveform,2)');

t = double(t(:));
if numel(t) ~= nTime
    error('did2:convert:neuronWaveformTimebaseMismatch', ...
        ['neuron_extracellular `waveform_sample_times` has %d entr(ies) but ' ...
         '`mean_waveform` has %d sample row(s). The writer assigns the two ' ...
         'together (kilosort/probe.m:547-548) and they match in 21 of 21 real ' ...
         'documents, so a disagreement means an unknown writer. The time axis ' ...
         'extent would have to be guessed; refusing instead.'], numel(t), nTime);
end

% ---- the time axis: regular ONLY IF this document's own vector says so ------
% The term is built ONCE, above the branch, rather than once per arm. Both arms
% describe the same axis, so two call sites would stage the same unminted term
% twice and count twice in DID-schema tools/check_empty_ontology_nodes.py -- the
% #70 backlog is the record of what still needs a CURIE, and inflating it with a
% duplicate makes it a worse record.
timeVariable = jOntologyTerm('', 'time');
[timeIsRegular, timeOrigin, timeSpacing] = regularTimebase(t);
if timeIsRegular
    timeAxis = jAxis(timeVariable, nTime, ...
        'regular',     true, ...
        'source_unit', 's', ...
        'origin',      struct('value', timeOrigin,  'source_value', timeOrigin), ...
        'spacing',     struct('value', timeSpacing, 'source_value', timeSpacing));
else
    % Lossless fallback, and it is not dead code: regularity is a property of
    % the stored vector, and hartley_calc's lag axis is the standing example of
    % a vector that looks regular and is not reproducible from origin+spacing at
    % the ulp. `values` keeps the stored doubles exactly.
    timeAxis = jAxis(timeVariable, nTime, ...
        'regular',     false, ...
        'source_unit', 's', ...
        'values',      struct('values', t, 'source_values', t));
end

% ---- the channel axis: an INDEX axis, no unit -------------------------------
% The convention pyraview.m:370 and jNgridBody both use: origin 1, spacing 1 and
% no unit. The document records no channel identities -- `site2channelmap` and
% `probe_geometry` are where those live -- so numbering them 1..N is the only
% thing this document actually says, and naming them would be a guess in a
% queryable field.
channelAxis = jAxis(jOntologyTerm('', 'channel'), nChannels, ...
    'regular', true, ...
    'origin',  struct('value', 1, 'source_value', 1), ...
    'spacing', struct('value', 1, 'source_value', 1));

obs = struct();
obs.document_class = classBlock('voltage_observation', ...
    {'subject_observation', 'voltage'});
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', neuronId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_mean_spike_waveform', 'datestamp', datestamp);

obs.subject_statement = struct( ...
    'variable', jOntologyTerm('', 'mean spike waveform'), ...
    'storage_mode', 'inline');
% Assigned separately, NOT inside struct(...): `axes` is a 1x2 struct array and
% struct() DISTRIBUTES a non-scalar struct value into a struct array of
% statements. Concatenation is safe only because jAxis gives both entries the
% same field set in the same order -- that is what the helper is for.
%
% BOTH AXES OR NEITHER. axes[k] IS array dimension k, so a one-entry list does
% not mean "here is one of the dimensions", it ASSERTS that dimension 1 is that
% axis. Both extents are known here, so both are stated.
obs.subject_statement.axes = [timeAxis, channelAxis];
% The encoding of the values belongs to the STATEMENT (signed sec.5). Read off
% the array's own class rather than defaulted -- image_stack.m's
% `firstNonEmpty(dataType, 'uint16')` is the defect not repeated.
[datumType, sourceDatumType] = jDatumType(class(w));
if ~isempty(datumType)
    obs.subject_statement.datum_type = datumType;
end
if ~isempty(sourceDatumType)
    obs.subject_statement.source_datum_type = sourceDatumType;
end

% `sample_time` IS DELIBERATELY ABSENT. Time is an ordinary axis now (signed
% sec.2, "both sample_time blocks retire"); writing the cadence into both would
% store one fact twice, which is the #69 shape the axis exists to remove. The
% score_observation above still carries `kind: 'point'` because a scalar quality
% has no axis at all -- that is a different statement, not an inconsistency.
obs.subject_interaction = struct('method', otTerm('', ''));
obs.subject_observation = struct();

% The values. COLUMN-MAJOR -- `w(:)` is MATLAB's own linearisation and matches
% the axis order emitted above, so reshape(values, [nTime nChannels]) inverts it.
% See the header: there is no `datum_order` slot on an inline statement to say so
% in the document, and that is a recorded team question.
%
% Assigned separately for the reason above: jMeasureArray returns a 1xN struct
% array (672 entries on a real document) and struct('value', thatArray) would
% distribute into 672 `voltage` blocks instead of one block holding 672 values.
obs.voltage = struct();
obs.voltage.value = jMeasureArray(double(w(:)), '');
end

function checkRedundantCount(blk, name, derived, derivedFrom)
%CHECKREDUNDANTCOUNT Refuse to drop a count that does not agree with the shape.
%   ABSENT or non-numeric is not an error -- there is simply nothing to check
%   against. A DISAGREEMENT is, because dropping the field is lossless only
%   BECAUSE it is derivable, and a mismatch means one of the two is wrong.
v = getField(blk, name);
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
    return;
end
if round(double(v)) ~= derived
    error('did2:convert:neuronWaveformShapeMismatch', ...
        ['neuron_extracellular `%s` is %g but %s is %d. This field is DROPPED ' ...
         'as derivable from the array shape (the writer assigns it from ' ...
         'exactly that, kilosort/probe.m:546-547), and that drop is lossless ' ...
         'only while the two agree -- they do in 21 of 21 real documents. ' ...
         'Refusing rather than silently preferring one of them.'], ...
        name, double(v), derivedFrom, derived);
end
end

function [isRegular, origin, spacing] = regularTimebase(t)
%REGULARTIMEBASE Is this stored vector reproducible from an origin and a step?
%   DERIVED PER DOCUMENT, never assumed. Corpus 20211116 has ONE distinct time
%   vector across all 21 documents -- 21 entries, one distinct diff (5e-05),
%   origin -0.00025 s, spacing 5e-05 s (20 kHz) -- and the reconstruction error
%   is 1.08e-19, i.e. the vector is regular to within a rounding of the double.
%   That is a measurement of these documents, not a property of the class, so it
%   is re-derived here and the irregular arm is real.
%
%   `spacing` is taken as the total span over (n-1) rather than as diff(t)(1):
%   the endpoint form is what a reader reconstructing the axis will use, so it
%   is the one whose error should be bounded.
n = numel(t);
origin  = t(1);
spacing = 0;
isRegular = false;
if n < 2
    % A single sample has no step. `regular` would have to invent one, so the
    % coordinate is stored instead.
    return;
end
spacing = (t(end) - t(1)) / (n - 1);
model = origin + spacing * (0:(n - 1))';
span = abs(t(end) - t(1));
tolerance = 1e-9 * max(span, eps);
isRegular = max(abs(model - t)) <= tolerance;
end

% ===================== small helpers =======================================

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function t = otTerm(node, name)
t = struct('node', char(node), 'name', char(name));
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(block, name)
v = [];
if isfield(block, name); v = block.(name); end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
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
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

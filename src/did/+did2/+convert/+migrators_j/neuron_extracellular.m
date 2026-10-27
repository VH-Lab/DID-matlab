function bodies = neuron_extracellular(preBody)
%NEURON_EXTRACELLULAR Brainstorm-J migrator: did_v1 neuron_extracellular -> a
%   DERIVED entity (the sorted unit) + a derived_from relation + CALCULATIONS
%   about the unit (+ the shared session anchor, the software and its run).
%
%   2026-10-21, did-schema #73 review item 48 (V_eta_spatial_transcriptomics_plan.md,
%   signed by [spatial_transcriptomics_family], 2026-09-29): "every statement
%   about the unit is a CALCULATION (computed from the spike sort) with
%   input_id -> the sorting output". Emitted:
%
%       entity (cell)      the sorted unit (local_identifier
%                          'unit_<cluster_index>'; id fresh).
%       directed_relation  derived_from: the unit (child) <- the recording
%                          element (parent). derived_from (node from the schema row).
%       calculation+label  `cluster_index` (a nominal label, not a count).
%       calculation+label  `quality_label` ('multi' / 'single'), variable
%                          'spike sort quality'.
%       calculation+voltage  the mean spike waveform, INLINE over a time key
%                          and a channel key. Only when the source has one.
%       calculation+score  `quality_number`, variable 'spike sort quality'.
%       relative_time_reference  (pass-1 session handle, folded later) the
%                          'during' anchor every calculation shares.
%       entity (software)  the `app` block (+ its version assertion), with the
%                          run's OS and interpreter entities.
%   Each calculation carries `input_id` = the source's `spike_clusters_id`
%   when it is populated (the sorting output; see the body), never empty.
%
%   The paragraphs below were written for the earlier observation shape; the
%   facts they record about the 21 corpus documents, the axes, the units and
%   the guards are unchanged. Where they name the earlier observation and
%   assertion shapes, read the calculations above.
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
%   [did-schema #88, Haley audit D-5, signed 2026-10-20: `datum_order` moved to
%   `data`, beside `keys` (now `dimensions`), so an inline value has the
%   slot, and EMPTY MEANS F.
%   On that schema this fold's column-major flatten is the declared default;
%   on did-schema main before #88 merged (2026-10-23) / v_eta-pre73 the
%   paragraph above held.]
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
%   preferring the matrix would drop a real discrepancy. So each is compared,
%   and since 2026-10-26 a disagreement (or a count that is not one finite
%   number) CARRIES THE DOCUMENT WHOLE AS V1 instead of erroring ([restated
%   values checked], Jess Haley, 2026-10-26). It holds on 21 of 21 here. A
%   count that is ABSENT is nothing to check against. With no waveform the
%   counts are not compared (the writer then sets each to 1, max(size(..),1)).
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

% ---- the two count fields are droppable only if they AGREE ------------------
% [restated values checked] (Jess Haley, 2026-10-26): `number_of_samples_per_channel`
% and `number_of_channels` stay unwritten because they restate the waveform's
% axis lengths; when one does not, the document is carried whole as v1 ([partly
% placed is carried as v1], Jess Haley, 2026-10-25). Until 2026-10-26 a
% disagreement raised did2:convert:neuronWaveformShapeMismatch (a quarantine).
w = getField(blk, 'mean_waveform');
% carryTag (set in both branches below): the carry register row this branch's carry cites
if isnumeric(w) && ~isempty(w) && ismatrix(w)
    carryTag = '[carry-018] ';
    unplaced = [checkRedundantCount(blk, 'number_of_samples_per_channel', ...
        size(w, 1), 'size(mean_waveform,1)'), ...
        checkRedundantCount(blk, 'number_of_channels', size(w, 2), ...
        'size(mean_waveform,2)')];
else
    % NO WAVEFORM: nothing to compare the counts with. They restate the
    % writer's own value for an empty waveform and are dropped only then:
    % 1 from the import writers, max(size(meanWf,k),1) (NDI-matlab
    % +ndi/+fun/+probe/+import/+kilosort/probe.m:551-552, +kiasort/probe.m:
    % 325-326, +jrclust/probe.m:309-310), 0 from +ndi/+app/spikesorter.m:252-253
    % (size(meanshape,k) of an empty mean shape), or absent / [] (the
    % template). Any other count states something nothing else does
    % ([lossless means round trip], Jess Haley, 2026-10-26): carried as v1.
    carryTag = '[carry-041] ';
    unplaced = [writerDefaultCount(blk, 'number_of_samples_per_channel'), ...
        writerDefaultCount(blk, 'number_of_channels')];
end
if ~isempty(unplaced)
    % carry-register: carry-018 (counts that differ from the waveform's axis
    % lengths); carry-041 (counts with no waveform that are not the writer's
    % default)
    did2.convert.reportNote('carried_as_v1', 'neuron_extracellular', ...
        char(baseField(preBody, 'id', '')), [carryTag 'unplaced: ' strjoin(unplaced, ', ')]);
    bodies = {preBody};
    return;
end

recordingSubjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));

clusterIndex = getField(blk, 'cluster_index');
unitName = 'unit';
if isnumeric(clusterIndex) && isscalar(clusterIndex)
    unitName = sprintf('unit_%d', round(clusterIndex));
end

% did-schema #88: built through did2.build. The neuron is an `entity` of type
% cell (a sorted unit); its derivation from the recording element is a
% `derived_from` relation; its statements hang off one session anchor.
neuronId = did2.convert.mintId('neuron');   % derived from the source id (practice (b))
neuron = jEntity(preBody, 'cell', struct('local_identifier', unitName, ...
    'description', 'spike-sorted extracellular unit (derived)'), 'Id', neuronId);
rel = jEntityRelation(preBody, neuronId, recordingSubjectId, 'derived_from');   % node from the schema's row (did2.build.vocabulary)
anchor = jSessionAnchor(preBody, 'during');
anchorId = anchor.base.id;

bodies = {neuron, rel, anchor};

% did-schema #73 review item 48 (V_eta_spatial_transcriptomics_plan.md,
% signed by the [spatial_transcriptomics_family] sign-off, 2026-09-29): every
% statement about the unit is COMPUTED from the spike sort, so each is a
% CALCULATION whose `input_id` names the sorting output -- `cluster_index` and
% `quality_label` with the `label` value kind, `quality_number` with `score`,
% `mean_waveform` with `voltage`. The unit entity and its derived_from
% relation are unchanged.
%
% THE INPUT. All four NDI writers set `spike_clusters_id` to the sorting
% output (origin/main: +ndi/+app/spikesorter.m:279 spike_clusters_doc;
% +ndi/+fun/+probe/+import/+kilosort/probe.m:562, +kiasort/probe.m:336 and
% +jrclust/probe.m:320 the *_clusters document). The kilosort / kiasort /
% jrclust sorter documents keep their ids as the `calculation + label` they
% migrate to (jSorterOutput, jrclust_clusters.m), so the edge carries over
% verbatim. EMPTY on all 21 documents of corpus 20211116, and then NO
% `input_id` is written: an empty edge validates clean and says nothing (the
% invented-empty-edge pattern). The spikesorter case points at a
% `spike_clusters` document, which pass 1 carries through unchanged for the
% NDI second pass (spike_clusters.m).
inputId = dependencyValue(preBody, 'spike_clusters_id');
inputOpt = {};
if ~isempty(inputId); inputOpt = {'InputIds', {inputId}}; end

% THE SOFTWARE: the `app` block's, with the run's OS and interpreter
% (operating_system_id / interpreter_id), as jCalculation and jSorterOutput do.
% Decided by Jess Haley, 2026-10-22 [sorter software]: "a sorted unit
% (`neuron_extracellular`) with no software record has no `software_id` (per
% [calculation-software-optional decided]), not an invented 'spike sorter'".
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
calcOpt = [{'TimeReferenceIds', {anchorId}, 'OperatingSystemId', osId, ...
    'InterpreterId', interpreterId}, inputOpt];
if ~isempty(swId); calcOpt = [calcOpt, {'SoftwareId', swId}]; end
nCalc = 0;

% cluster_index: the sorter's own label for the unit, a NOMINAL number (item
% 48: "a cluster index is a nominal label, not a count"). A `label` value is a
% string even when it looks numeric (did-schema `label`.value.name).
if isnumeric(clusterIndex) && isscalar(clusterIndex) && isfinite(clusterIndex)
    bodies{end+1} = jStatement(preBody, 'calculation', neuronId, ...
        jLabel('spike sorter cluster index'), ...
        struct('name', sprintf('%d', round(double(clusterIndex)))), ...
        calcOpt{:}, 'ValueKind', 'label');
    nCalc = nCalc + 1;
end

% quality_label: the human-readable twin of quality_number ('multi' /
% 'single' in the corpus), until now dropped.
qualityLabel = getField(blk, 'quality_label');
if (ischar(qualityLabel) || isstring(qualityLabel)) && ~isempty(strtrim(char(qualityLabel)))
    bodies{end+1} = jStatement(preBody, 'calculation', neuronId, ...
        jLabel('spike sort quality'), ...
        struct('name', strtrim(char(qualityLabel))), ...
        calcOpt{:}, 'ValueKind', 'label');
    nCalc = nCalc + 1;
end

wcalc = meanWaveformCalculation(preBody, blk, neuronId, calcOpt);
if ~isempty(wcalc)
    bodies{end+1} = wcalc;
    nCalc = nCalc + 1;
end

quality = getField(blk, 'quality_number');
if isnumeric(quality) && isscalar(quality)
    qv = did2.build.composite('score', 'value', ...
        struct('score', double(quality), 'approximate', false));
    bodies{end+1} = jStatement(preBody, 'calculation', neuronId, ...
        jLabel('spike sort quality'), qv, calcOpt{:}, 'ValueKind', 'score');
    nCalc = nCalc + 1;
end

% The software and run entities are emitted only when a calculation names
% them, so none is left unreferenced.
if nCalc > 0
    bodies = [bodies, software, runDocs];
end
end

function obs = meanWaveformCalculation(preBody, blk, neuronId, calcOpt)
%MEANWAVEFORMCALCULATION The mean spike waveform as an inline calculation
%   (value kind voltage, #73 item 48) about the sorted unit, over a time key
%   and a channel key.
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

% (the two count fields were checked against this shape on entry: a document
% whose counts disagree is carried whole as v1 before anything is built)

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
        'source_unit', 's', ...
        'origin',      struct('value', timeOrigin,  'source_value', timeOrigin), ...
        'spacing',     struct('value', timeSpacing, 'source_value', timeSpacing));
else
    % Lossless fallback, and it is not dead code: regularity is a property of
    % the stored vector, and hartley_calc's lag axis is the standing example of
    % a vector that looks regular and is not reproducible from origin+spacing at
    % the ulp. `values` keeps the stored doubles exactly.
    timeAxis = jAxis(timeVariable, nTime, ...
        'source_unit', 's', ...
        'quantity',    struct('value', t, 'source_value', t));
end

% ---- the channel axis: a BARE dimension -------------------------------------
% The document records no channel identities -- `site2channelmap` and
% `probe_geometry` are where those live -- so the only thing it says about a
% channel is its position. That is the dimension's own (0-based) position, and
% a covariate that only repeats it (1..N here until 2026-10-22) is not written
% (Jess Haley 2026-10-22 [covariate rules named] 6.2a, and "yes" to 1..N).
% MATLAB's channel number is position + 1.
channelAxis = jAxis(jOntologyTerm('', 'channel'), nChannels);

% time and channel dimensions, each with its positions as a covariate along
% it (data_body AMENDMENT 6; the former `time` and `channel` keys)
[dims, covs] = jDimCov({timeAxis, channelAxis});
[datumType, sourceDatumType] = jDatumType(class(w));
% the samples carry no unit in v1, so the cells carry only what was written
obs = jStatement(preBody, 'calculation', neuronId, ...
    jLabel('mean spike waveform'), ...
    jQuantity('voltage', double(w(:))', '', 'approximate', false), ...
    'Dimensions', dims, 'Covariates', covs, ...
    'DatumType', datumType, 'SourceDatumType', sourceDatumType, ...
    calcOpt{:}, 'ValueKind', 'voltage');
end

function why = writerDefaultCount(blk, name)
%WRITERDEFAULTCOUNT {} when a count beside NO waveform is what the writers
%   write for an empty one (absent, [], 0 or 1), else a one-element cell.
why = {};
v = getField(blk, name);
if isempty(v)
    return;
end
if ~isnumeric(v) || ~isscalar(v) || ~any(double(v) == [0 1])
    why = {sprintf('neuron_extracellular.%s (no waveform to restate it)', name)};
end
end

function why = checkRedundantCount(blk, name, derived, derivedFrom)
%CHECKREDUNDANTCOUNT {} when the count may be dropped, else a one-element cell
%   naming why not. ABSENT or empty is nothing to check. A value that is not
%   one finite number, or one that disagrees with the shape, is NOT restated by
%   the waveform, so dropping it would lose it ([restated values checked], Jess
%   Haley, 2026-10-26): the caller carries the document whole as v1.
why = {};
v = getField(blk, name);
if isempty(v)
    return;
end
if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
    why = {sprintf('neuron_extracellular.%s (not one finite number)', name)};
elseif double(v) ~= derived
    why = {sprintf('neuron_extracellular.%s %g (differs from %s %d)', ...
        name, double(v), derivedFrom, derived)};
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

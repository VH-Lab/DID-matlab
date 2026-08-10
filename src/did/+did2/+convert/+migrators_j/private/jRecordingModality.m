function [entries, disposition] = jRecordingModality(elementType)
%JRECORDINGMODALITY The element/probe `type` -> modality map for the raw-recording
%   observation assembler (open item #30, SIGNED 2026-08-10 in
%   V_eta_recording_observation_plan.md).
%
%   [ENTRIES, DISPOSITION] = jRecordingModality(ELEMENTTYPE)
%
%   DISPOSITION is one of:
%     'recording'   ELEMENTTYPE names an instrument that MEASURES the specimen.
%                   ENTRIES is a 1xN struct array, one per modality the type
%                   records, with fields:
%                     class         the V_eta observation leaf ('voltage_observation')
%                     mixin         its data_type superclass ('voltage')
%                     variable      the subject_statement.variable label
%                     multichannel  true when the type is a MULTI-SITE instrument
%                                   (the body gets a channel axis; see below)
%     'stimulator'  ELEMENTTYPE names an instrument that ACTS ON the specimen.
%                   ENTRIES is empty. NO observation is emitted -- a stimulus
%                   delivery is a subject_manipulation (T3 direction), and the
%                   stimulus model (#31/#43, timed_sequence_manipulation) is the
%                   thing that gives these their `instrument_id` edge. Until it
%                   lands the loose `observes` relation is KEPT for them, so
%                   nothing is lost in the meantime.
%     'unresolved'  Guard A. ENTRIES is empty; the caller records a queryable
%                   `modality unresolved` term_assertion naming the type, and
%                   keeps `observes`. See jRecordingObservation for why Guard A
%                   cannot be built in its signed form today.
%
%   ---------------------------------------------------------------------
%   THE DENOMINATOR, AND WHERE EVERY ROW COMES FROM
%   ---------------------------------------------------------------------
%   The element `type` universe is enumerable, and NDI says so in its own schema:
%
%     git show origin/main:src/ndi/ndi_common/schema_documents/element_schema.json
%        { "name": "type", ... "documentation": "The type of the element.
%          Common probe types are in probetype2object.json" }
%
%   TWO ground-truth files, read from NDI-matlab origin/main (42c94e53b):
%
%     A. src/ndi/ndi_common/probe/probetype2object.json -- 24 REGISTERED probe
%        types. This is a CLOSED set at runtime: +ndi/+probe/+fun/probestruct2probe.m
%        does `if ~isKey(probeTypeMap, probestruct(i).type)` and THROWS
%        ('NDI:Probe:ProbeTypeNotFound'), so a probe object cannot be built for a
%        type outside it.
%     B. src/ndi/docs/NDI-matlab/under_construction/PROBE-TYPES.md -- the
%        standard-types table, which is where the per-type MODALITY is actually
%        stated ("specifies voltage recording", "two channels; first is Vm,
%        second is I", the _Imaging_ / _Stimulators_ groupings). It documents 4
%        types that are NOT registered in (A) -- 'sharp-I', 'display',
%        'stim-n-trode', 'n-LED' -- and spells (A)'s 'electrode-$' as
%        'electrode-SPEC'.
%
%   DENOMINATOR: 24 registered types (A), of which
%       17  -> 'recording'   (an observation is emitted)
%        4  -> 'stimulator'  (intraoral-cannula, optogenetic-fiber, stimulator, event)
%        3  -> 'unresolved'  (lick-spout, reward-well, ppg)
%   plus 4 documented-but-unregistered types from (B), all 'stimulator'
%   (display, stim-n-trode, n-LED) or already covered ('sharp-I').
%
%   The three unresolved rows are unresolved for a stated reason, not by
%   omission:
%     lick-spout   ZERO occurrences in any .m file on origin/main outside
%     reward-well  probetype2object.json itself
%                    git grep -niE "lick-spout|reward-well" origin/main -- '*.m'
%                    (no output). Nothing states what the recorded channel
%                    measures -- a lick detector may be digital events, an
%                    analog force trace or a conductance.
%     ppg          photoplethysmogram. Two occurrences only -- a getprobes()
%                  call (+setup/+conv/+marder/marderprobe2uberon.m:11) and a
%                  comment (+gui/+app/pyraview.m:90). The recorded quantity
%                  (optical absorbance vs. a derived pulse signal) is stated
%                  nowhere.
%   Guessing a dimensioned quantity for these is exactly the failure the
%   migrator-vocabulary audit exists to stop, so they take Guard A and surface
%   as a worklist instead.
%
%   ---------------------------------------------------------------------
%   PER-ROW EVIDENCE (all from NDI origin/main)
%   ---------------------------------------------------------------------
%   ELECTRODES -- PROBE-TYPES.md, _Electrodes_ block, quoted verbatim:
%     'n-trode'         "A bundle of N extracellular electrodes that sample
%                        overlapping electric fields; the number of channels is
%                        calculated from the number of channels specified in the
%                        device string"                    -> voltage, MULTI-SITE
%     'electrode-SPEC'  "An electrode of a specification that is contained in a
%                        reference SPEC"                   -> voltage, MULTI-SITE
%                       registered as the literal 'electrode-$';
%                       +ndi/+database/+metadata_app/+fun/loadProbes.m:46 matches
%                       real data with `regexp(probes{i}.type, 'electrode-\d')`
%                       and classes it 'Electrode'; +ndi/+daq/daqsystemstring.m:13
%                       shows the underscored form in an epochprobemap
%                       ("a 4-channel extracellular recording ...
%                        type: 'extracellular_electrode-4'"), which is why the
%                       match here is a suffix-anchored prefix rule rather than
%                       an exact key.
%     'patch'           "two channels; first is Vm, second is I"
%                                                          -> voltage AND current
%     'patch-Vm'        "single channel, specifies voltage recording" -> voltage
%     'patch-I'         "single channel, specifies current recording" -> current
%     'patch-attached'  "single channel, specifies voltage recording" -> voltage
%     'sharp'           "two channels; first is voltage, second is current"
%                                                          -> voltage AND current
%     'sharp-Vm'        "single channel, specifies voltage recording" -> voltage
%     'sharp-I'         "single channel, specifies current recording" -> current
%     'sharp-Im'        the SHIPPED spelling of the same thing: it is the key in
%                       probetype2object.json and the value
%                       +setup/+conv/+marder/abf2probetable.m:54 writes. Both
%                       spellings are mapped; neither is guessed.
%
%   IMAGING -- PROBE-TYPES.md _Imaging_ block; all four are registered to
%   `ndi.probe.image` in probetype2object.json:
%     'wide-field-imaging', 'two-photon-imaging', 'one-photon-imaging',
%     'brightfield-imaging'                                -> image
%
%   NAMED-QUANTITY INSTRUMENTS. These four are registered to
%   ndi.probe.timeseries.mfdaq (i.e. sampled analog recordings -- +gui/+app/
%   pyraview.m:88-92 lists them as "multifunction-DAQ timeseries probe(s)
%   (n-trode, patch, sharp, ecg, eeg, ppg, accelerometer, etc.)"), and the type
%   string names the measured quantity outright:
%     'ecg'            electrocardiogram -> voltage.
%                      +setup/+conv/+gluckman/channelname2probename.m:26 sets
%                      probetype='ecg' from the recorded CHANNEL name.
%     'eeg'            electroencephalogram -> voltage.
%                      channelname2probename.m:23 (the default for a gluckman
%                      recording channel).
%     'accelerometer'  -> acceleration.
%                      +setup/+conv/+gluckman/channelnames2daqsystemstrings.m:57.
%     'thermometer'    -> temperature.
%                      +setup/+conv/+marder/abf2probetable.m:55-57 assigns it when
%                      the channel name contains 'temp';
%                      +setup/+conv/+marder/preptemptable.m:18 reads temperatures
%                      back off `S.getprobes('type','thermometer')`.
%   Recorded honestly: for these four the modality comes from what the
%   instrument's NAME means, corroborated by the writer that assigns it -- NDI
%   nowhere states a unit or quantity per probe type. That is a weaker warrant
%   than the PROBE-TYPES.md rows above, and it is the reason `datum.unit` is left
%   EMPTY on the body (see jRecordingObservation).
%
%   STIMULATORS -- probetype2object.json maps these to
%   `ndi.probe.timeseries.stimulator`, and pyraview.m:90-92 says of the mfdaq
%   filter "Stimulator and image probes are siblings of mfdaq under
%   ndi.probe.timeseries and are excluded by the isa() test":
%     'stimulator', 'event', 'intraoral-cannula', 'optogenetic-fiber'
%   plus PROBE-TYPES.md's _Stimulators_ block, which is registered nowhere:
%     'display', 'stim-n-trode', 'n-LED'
%
%   ---------------------------------------------------------------------
%   WHAT THIS MAP DELIBERATELY DOES NOT DO
%   ---------------------------------------------------------------------
%   It does not carry the CHANNEL COUNT, because the element document does not
%   have it and never did. PROBE-TYPES.md says so for 'n-trode' in the row quoted
%   above ("calculated from the number of channels specified in the device
%   string" -- the device string lives in the epochprobemap, not in the element
%   document), and +ndi/+fun/+probe/channelCount.m gets it the same way, via
%   `probe.getchanneldevinfo(epoch)`. So `multichannel` says only THAT there is a
%   channel dimension, never how long it is. Writing a count we do not have would
%   be the spikewaves bug (a body declaring zero spikes of zero samples each).
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

% NOTE: no `arguments` size specifiers on the char inputs. An absent `type` is
% the empty char '' (0x0), which does not satisfy a `(1,:) char` declaration --
% and an element with no type is a real, reachable case (+setup/+conv/+gluckman/
% channelname2probename.m:29-35 returns probetype = '' for counter/status/ACC
% channels). Validation is done by hand below instead.
if nargin < 1 || isempty(elementType); elementType = ''; end
elementType = char(elementType);

entries = emptyEntries();
disposition = 'unresolved';

key = lower(strtrim(elementType));
if isempty(key)
    return;   % no type at all -> Guard A, with the caller's best-known label
end

% ---- stimulators: the OTHER direction (T3). No observation, ever. -----------
if any(strcmp(key, {'stimulator', 'event', 'intraoral-cannula', ...
        'optogenetic-fiber', 'display', 'stim-n-trode', 'n-led'}))
    disposition = 'stimulator';
    return;
end

% ---- the multi-site electrode families -------------------------------------
% 'electrode-$' is registered as a literal but real types carry a spec/count
% suffix ('electrode-4'), and epochprobemaps carry an underscored prefix
% ('extracellular_electrode-4'). Anchor on the '...electrode-' stem so both
% reach the same row; 'stim-n-trode' cannot match (it has no 'electrode-').
if strcmp(key, 'n-trode') || ~isempty(regexp(key, '^([a-z0-9_]*_)?electrode-', 'once'))
    entries = mk('voltage_observation', 'voltage', 'voltage', true);
    disposition = 'recording';
    return;
end

switch key
    % --- pipettes: single-channel, modality stated by the type suffix -------
    case {'patch-vm', 'patch-attached', 'sharp-vm'}
        entries = mk('voltage_observation', 'voltage', 'voltage', false);
    case {'patch-i', 'sharp-i', 'sharp-im'}
        entries = mk('current_observation', 'current', 'current', false);

    % --- pipettes: TWO channels of TWO DIFFERENT quantities ----------------
    % PROBE-TYPES.md: patch = "two channels; first is Vm, second is I";
    % sharp = "two channels; first is voltage, second is current". Two
    % quantities are two `variable`s, so they are two observations -- see the
    % note in jRecordingObservation on why this is not the multi-channel case.
    case {'patch', 'sharp'}
        entries = [mk('voltage_observation', 'voltage', 'voltage', false), ...
                   mk('current_observation', 'current', 'current', false)];

    % --- imaging ------------------------------------------------------------
    case {'wide-field-imaging', 'two-photon-imaging', ...
          'one-photon-imaging', 'brightfield-imaging'}
        entries = mk('image_observation', 'image', 'image', false);

    % --- instruments whose name is the quantity ------------------------------
    case {'ecg', 'eeg'}
        entries = mk('voltage_observation', 'voltage', 'voltage', false);
    case 'accelerometer'
        entries = mk('acceleration_observation', 'acceleration', 'acceleration', false);
    case 'thermometer'
        entries = mk('temperature_observation', 'temperature', 'temperature', false);

    otherwise
        return;   % Guard A: 'lick-spout', 'reward-well', 'ppg', anything new
end
disposition = 'recording';
end

% ===================== small helpers =======================================

function e = emptyEntries()
e = struct('class', {}, 'mixin', {}, 'variable', {}, 'multichannel', {});
end

function e = mk(className, mixin, variable, multichannel)
e = struct('class', className, 'mixin', mixin, 'variable', variable, ...
    'multichannel', logical(multichannel));
end

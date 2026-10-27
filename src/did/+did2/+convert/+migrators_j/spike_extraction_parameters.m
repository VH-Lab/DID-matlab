function bodies = spike_extraction_parameters(preBody)
%SPIKE_EXTRACTION_PARAMETERS Brainstorm-J migrator: did_v1
%   spike_extraction_parameters -> ONE `method` document (`method_parameters`
%   before did-schema #88)
%   (+ the `software` entity its v1 `app` block names).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   1 -> 1 (2 with the software entity). base.id AND base.name are PRESERVED,
%   both load-bearing:
%
%     base.id    is pointed at by three templates --
%                spike_extraction_parameters_modification.extraction_parameters_id,
%                spikewaves.extraction_parameters_id and
%                spike_clusters.extraction_parameters_id. Both consumers are
%                deferred passthroughs in pass 1, so their edges must still
%                resolve after this fold, and they do because the id does not
%                move.
%     base.name  is the string the app looks a protocol up by:
%                spikeextractor.m:372
%                   ndi.query('base.name','exact_string',extraction_parameters_name,'')
%                It is preserved twice over -- verbatim on `base`, and again on
%                the declared `method_parameters.name` field, which exists for
%                exactly this query.
%
%   THIS IS A GLOBAL PROTOCOL, NOT A SCOPED ONE. The template declares NO
%   dependencies:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%         spikeextractor/spike_extraction_parameters.json
%        "superclasses": [ base, app ]        (no "depends_on" key at all)
%     git show origin/main:src/ndi/ndi_common/schema_documents/apps/\
%         spikeextractor/spike_extraction_parameters_schema.json
%        "depends_on": [ ]
%
%   and the writer adds none (spikeextractor.m:290-295 builds it from the
%   settings struct + newdocument() + base.name only). So subject_id, epoch_id
%   and derived_from_id are all legitimately absent here -- they are OPTIONAL on
%   the target, and jMethodParameters omits an edge it cannot fill rather than
%   writing it blank.
%
%   FIELD DISPOSITION -- all fifteen, nothing dropped. See
%   jSpikeExtractionSettings for the evidence behind each:
%
%     refractory_time            -> parameter `refractory period`
%     spike_start_time           -> parameter `waveform window start`
%     spike_end_time             -> parameter `waveform window duration`
%                                   (= end - start; `end` is exactly
%                                   recoverable and is not stored)
%     threshold_method           -> encoded in WHICH threshold variable is used
%     threshold_parameter        -> parameter `standard-deviation threshold`
%                                   or `absolute voltage threshold`
%     threshold_sign             -> other.threshold_sign
%     do_filter, filter_type, filter_low, filter_high, filter_order,
%     filter_ripple              -> other.filter.*  (the built class has no
%                                   filter_id edge; see jSpikeExtractionSettings)
%     center_range_time, overlap, read_time  -> other.*
%     app.*                      -> the `software` entity + software_id, with
%                                   os/interpreter parked in
%                                   other.execution_environment
%
%   NOTE ON `threshold_sign`: the plan's bound-variable list is "threshold,
%   refractory period, waveform window start and duration", and sign is not on
%   it, so it stays in the bag. It is arguably canonical (every detector has
%   one, and the superseded typed-block draft had it as an enum) -- raised as an
%   open question rather than decided here.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it:
%     ndi.app.spikeextractor struct2doc: the settings struct over
%     spike_extraction_parameters.json + app.json + base.json at the locked
%     NDI-matlab `main`, 3cb19a8, base.name the extraction name
%   Its block and edges are snake_case already, and the `app` block is read
%   in either spelling (jSoftwareFromApp), so the raw read changes nothing the
%   fold writes; a nameless app block's leftover keeps the bag spelling the
%   renamed path gave it (jMethodParameters). Every block field goes to a
%   bound parameter or the bag, as before. What the renamed path would have
%   discarded is carried, carry-049, as before; a block, base field or edge
%   no part of this fold reads, or an `app` field outside NDI's app.json (all
%   dropped without a word on the renamed path), now carries the document
%   whole as v1 (private/jRawAccount, jRawCarry; [fields outside the template
%   are malformed], carry-100).
%   Every writer document carries, carry-003, as before: ndi.app/newdocument
%   always writes the run's os and interpreter, which no method keeps. A carry
%   is the untouched v1 source. did2.convert.roundtrip.spike_extraction_parameters
%   rebuilds the v1 document; testRawV1RoundTripSpikeParameters compares the
%   two.
arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'spike_extraction_parameters') ...
        && isstruct(preBody.spike_extraction_parameters)
    blk = preBody.spike_extraction_parameters;
end

[entries, other] = jSpikeExtractionSettings(blk);

% THE RAW READ (see READS RAW v1 above). The bag reads every field of the
% block, so the block's own fields are all read; the other blocks, base and
% edges are checked.
src = preBody;
blockFields = fieldnames(blk);
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'spike_extraction_parameters', {blockFields(:)'}, ...
    'app', {{'name', 'version', 'url', 'os', 'os_version', 'interpreter', 'interpreter_version'}}), ...
    {'^element_id$', '^subject_id$', '^epoch_id$'});
if jRawCarry('spike_extraction_parameters', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

bodies = jMethodParameters(preBody, entries, other);
if isscalar(bodies) && isequaln(bodies{1}, preBody)
    bodies = {src};   % a carry is the untouched v1 source
end
end

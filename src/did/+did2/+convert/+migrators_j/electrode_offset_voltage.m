function bodies = electrode_offset_voltage(preBody)
%ELECTRODE_OFFSET_VOLTAGE Brainstorm-J migrator: did_v1 electrode_offset_voltage
%   -> an `observation` with value kind `voltage` about the probe's entity,
%   qualified by the temperature it was measured at (a condition), + the
%   session anchor. 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The
%   probe IS a `subject` (device-as-subject, D2), carried from the source
%   `probe_id` dependency -- the only dependency the real class has, so subject
%   resolution works from this document alone.
%
%   ---------------------------------------------------------------------
%   FIELD NAMES CORRECTED, AND THE VALUE IS A SCALAR, NOT A PER-CHANNEL ARRAY
%   ---------------------------------------------------------------------
%   This migrator used to read `offset_voltages` and `voltage_units`. NEITHER
%   EXISTS. The real NDI template is exactly two fields:
%
%       electrode_offset_voltage: { offset: "", temperature: "" }
%       depends_on: probe_id
%
%   The names came from DID-schema's own V_alpha snapshot (see
%   V_eta_ground_truth_plan.md). Because `offset_voltages` never matched, the
%   `isempty(offsets)` guard always fired and EVERY electrode_offset_voltage
%   document was carried through unconverted -- indistinguishable from a
%   deliberate deferral, which is why it went unnoticed.
%
%   The old header described "per-channel DC offsets ... one measurement
%   composite per channel". That is not what the class holds. The writer
%   (+ndi/+setup/+conv/+marder/makeVoltageOffsets.m) creates ONE DOCUMENT PER
%   (probe, offset, temperature) ROW of a CSV, with `offset` a SCALAR taken from
%   the column `offsetV` and `temperature` a scalar from column `T`. There is no
%   per-channel array anywhere. So the value is a single reading, which
%   jMeasureArray expresses as a length-1 array (series-as-cardinality).
%
%   TEMPERATURE IS A CONDITION, NOT A SECOND OBSERVATION. The offset was measured
%   AT a temperature; the two are one statement, not two. It therefore rides on
%   `subject_statement.conditions` (the D10 qualifier slot, same idiom as
%   jTuningFold) rather than becoming an independent temperature_observation
%   about the probe. The writer treats it as optional and skips it when NaN, so
%   the condition is emitted only when the value is finite.
%
%   UNITS. The class declares none, so both are inferred and recorded as SOURCE
%   units only (no canonical is asserted):
%     offset      -> 'V'. Evidence: the writer reads it from the CSV column
%                    named `offsetV`. This is an inference from a column name,
%                    not a declaration -- if the corpus turns out to be mV, this
%                    is the one line to change.
%     temperature -> '' (no claim). The column is just `T` and nothing in the
%                    class or the writer states a scale, so asserting Celsius
%                    would be inventing a fact.
%
%   THE GUARD. A body carrying `offset_voltages` or `voltage_units` is REJECTED
%   BY NAME: those are V_alpha inventions, so their presence means a fixture or
%   caller was built against our schema instead of the real document.
%
%   A document with no numeric offset carries unchanged (discovery fallback); the
%   unconverted-document counter makes that visible.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI probe/electrode_offset_voltage.json + base.json
%   at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+setup/+conv/+marder/makeVoltageOffsets.m writes it: one document per
%   CSV row, `offset` the row's offsetV, `temperature` its T, NaN when not
%   recorded, which reaches a corpus as an empty value). Every v1 field and where
%   it goes; did2.convert.roundtrip.electrode_offset_voltage rebuilds the v1
%   document and testRawV1RoundTripProbe compares the two:
%
%     base.id, session_id, datestamp     -> the observation's
%     base.name                          -> not written (the writer leaves '')
%     depends_on probe_id                -> the observation's entity_id
%     electrode_offset_voltage.offset    -> the voltage value (source unit 'V')
%     electrode_offset_voltage.temperature -> the `temperature` condition
%
%   What the renamed path would have discarded is carried, carry-049, as
%   before. A field, block or edge no part of this migrator reads ([fields
%   outside the template are malformed], carry-100), and a temperature that is
%   stated but is neither one finite number nor the writer's NaN (no register
%   row yet), both dropped without a word on the renamed path, now carry the
%   document whole as v1 (private/jRawAccount, jRawCarry). A passthrough and a
%   carry return the untouched v1 source.
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'electrode_offset_voltage') && isstruct(preBody.electrode_offset_voltage)
    blk = preBody.electrode_offset_voltage;
end

if isfield(blk, 'offset_voltages') || isfield(blk, 'voltage_units')
    error('did2:convert:electrodeOffsetInventedShape', ...
        ['electrode_offset_voltage body carries `offset_voltages`/' ...
         '`voltage_units`, which no did_v1 document has -- the real fields are ' ...
         '`offset` and `temperature`. This shape can only come from the V_alpha ' ...
         'snapshot or a fixture built against it.']);
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, ...
    struct('electrode_offset_voltage', {{'offset', 'temperature'}}), ...
    {'^probe_id$', '^element_id$', '^subject_id$'});
valueReasons = {};
if isfield(blk, 'temperature') && ~isempty(blk.temperature) ...
        && isempty(finiteScalar(blk, 'temperature')) && ~isNaNScalar(blk.temperature)
    % NaN is the writer's "not recorded" (it skips the temperature query for
    % it) and stays unwritten, as before; anything else that is not one finite
    % number has no place
    % (the writer, NDI-matlab +setup/+conv/+marder/makeVoltageOffsets.m, tests
    % ~isnan(temp) on the table's T value, so it writes a number or NaN only):
    % a value no NDI writer produces, [values no writer produces are
    % malformed] (Jess Haley, 2026-10-27, did-schema
    % V_eta_go_forward_class_audit.md), carry-120
    valueReasons{end+1} = '[carry-120] electrode_offset_voltage.temperature (not one finite number)';
end
if jRawCarry('electrode_offset_voltage', src, collision, unplaced, 'carry-100', valueReasons)
    bodies = {src};
    return;
end

offset = finiteScalar(blk, 'offset');
if isempty(offset)
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's V2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. Register row carry-133 covers it.
    % carry-register: carry-133
    did2.convert.reportNote('carried_as_v1', 'electrode_offset_voltage', jCarryId(src), ...
        '[carry-133] malformed: electrode_offset_voltage.offset is not one finite number, so nothing to fold ([passthrough stays v1])');
    bodies = {src};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

anchor = jSessionAnchor(preBody, 'during');
conditions = [];
temperature = finiteScalar(blk, 'temperature');
if ~isempty(temperature)
    % the offset was measured AT this temperature -- a qualifier on the same
    % statement, not a separate observation. Unit deliberately left unstated;
    % the number is kept as the source wrote it, as text.
    conditions = did2.build.condition(jLabel('temperature'), ...
        'Value', temperature, 'SourceValue', mat2str(temperature), 'Approximate', false);
end
obs = jStatement(preBody, 'observation', ...
    jSubjectOf(preBody, {'probe_id', 'element_id', 'subject_id'}), ...
    jLabel('electrode offset voltage'), ...
    jQuantity('voltage', offset, 'V', 'approximate', false), ...
    'TimeReferenceIds', {anchor.base.id}, 'Conditions', conditions, ...
    'Id', char(preBody.base.id), 'ValueKind', 'voltage');   % id preserved, as the pre-#88 fold did

bodies = {obs, anchor};
end

% ===================== local helpers ===================================

function v = finiteScalar(blk, name)
%FINITESCALAR The named field as a finite numeric scalar, or [] if absent,
%   non-numeric, or NaN. The writer stores NaN when a temperature was not
%   recorded, so NaN means "not measured", not "measured as nothing".
v = [];
if ~isfield(blk, name); return; end
x = blk.(name);
if isnumeric(x) && isscalar(x) && isfinite(x)
    v = double(x);
end
end

function tf = isNaNScalar(x)
%ISNANSCALAR One NaN: the writer's "temperature not recorded".
tf = isnumeric(x) && isscalar(x) && isnan(x);
end

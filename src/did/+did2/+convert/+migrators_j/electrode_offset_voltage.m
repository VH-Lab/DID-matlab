function bodies = electrode_offset_voltage(preBody)
%ELECTRODE_OFFSET_VOLTAGE Brainstorm-J migrator: did_v1 electrode_offset_voltage
%   -> a voltage_observation of the probe-subject, qualified by the temperature
%   it was measured at, + the session anchor. 1 -> 2.
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

offset = finiteScalar(blk, 'offset');
if isempty(offset)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

anchor = jSessionAnchor(preBody, 'during');
obs = jStartInteraction(preBody, 'voltage_observation', 'subject_observation', ...
    {'voltage'}, jOntologyTerm('', 'electrode offset voltage'), ...
    {'probe_id', 'element_id', 'subject_id'});
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.voltage = struct('value', jMeasureArray(offset, 'V'));

temperature = finiteScalar(blk, 'temperature');
if ~isempty(temperature)
    % the offset was measured AT this temperature -- a qualifier on the same
    % statement, not a separate observation. Unit deliberately left unstated.
    obs.subject_statement.conditions = struct( ...
        'variable', jOntologyTerm('', 'temperature'), ...
        'quantity', struct('value', jMeasureArray(temperature, '')));
end

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

function [entries, other] = jSpikeExtractionSettings(blk)
%JSPIKEEXTRACTIONSETTINGS Split a did_v1 spike-extraction settings block into
%   the bound `parameter[]` entries and the undeclared long tail.
%
%   Shared by spike_extraction_parameters and
%   spike_extraction_parameters_modification, whose payloads are IDENTICAL --
%   the same fifteen fields, in the same order, with the same defaults. Verified
%   against NDI origin/main rather than assumed:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%         spikeextractor/spike_extraction_parameters.json
%       center_range_time 0.0005  overlap 0.5  read_time 30
%       refractory_time 0.001  spike_start_time -0.00045  spike_end_time 0.001
%       do_filter 1  filter_type "cheby1high"  filter_low 0  filter_high 300
%       filter_order 4  filter_ripple 0.8
%       threshold_method "standard_deviation"  threshold_parameter -4
%       threshold_sign -1
%
%     ...spike_extraction_parameters_modification.json    SAME 15 FIELDS
%       + depends_on [extraction_parameters_id, element_id]
%
%   The schema_documents pair declares the same fifteen with types and ranges
%   (spike_extraction_parameters_schema.json), and the writer agrees with both.
%
%   ------------------------------------------------------------------
%   THE FOUR BOUND VARIABLES, and why exactly these four
%   ------------------------------------------------------------------
%   The plan's FINAL MODEL names them: "Bound entries where a variable exists
%   (threshold, refractory period, waveform window start and duration); `other`
%   for the tail". Nothing beyond that list is promoted here -- inventing a
%   fifth variable would be a modelling decision, and only the team makes those.
%
%     refractory period        <- refractory_time.  UNIFIES with
%                                 vmspikefilteringparameters.refract, which is
%                                 the same concept under a second v1 name; one
%                                 variable makes them comparable for the first
%                                 time. That unification is the whole point of
%                                 the extraction.
%     waveform window start    <- spike_start_time (negative: before the peak).
%     waveform window duration <- spike_end_time - spike_start_time, COMPUTED.
%                                 ANSWER 1 of the sign-off review: anchor and
%                                 extent, not two positions -- the same shape
%                                 the signed time_reference model uses, so one
%                                 interval spelling spans V_eta. `end` is
%                                 exactly recoverable as start + duration and is
%                                 deliberately NOT stored.
%     standard-deviation threshold  <- threshold_parameter when
%                                 threshold_method == 'standard_deviation'
%     absolute voltage threshold    <- threshold_parameter when
%                                 threshold_method == 'absolute'
%
%   THE THRESHOLD SPLITS INTO TWO VARIABLES AND THE METHOD FIELD DISAPPEARS
%   INTO THAT CHOICE. A standard-deviation multiple and an absolute level are
%   not the same quantity and must not be numerically comparable; making the
%   dimension depend on a sibling `threshold_method` field is the same mistake
%   as a `unit` field. The method universe is CLOSED -- the writer enumerates
%   exactly two and errors on anything else:
%
%     git show origin/main:src/ndi/+ndi/+app/spikeextractor.m | sed -n '211,225p'
%        switch(...threshold_method)
%           case 'standard_deviation'   ... threshold_parameter*stddev ...
%           case 'absolute'             ... threshold_parameter ...
%           otherwise
%              error('unknown threshold method');
%
%   so those two branches cover every document the app itself can consume. A
%   THIRD value cannot be given a dimension without inventing one, so it takes
%   the safe branch: threshold_method AND threshold_parameter both go to `other`
%   verbatim and no bound entry is emitted. That branch is unreachable for any
%   document NDI can read, and exists so a hand-written document cannot make
%   this migrator assert a quantity it does not know.
%
%   ------------------------------------------------------------------
%   source_unit IS '' EVERYWHERE IN THIS FAMILY, DELIBERATELY
%   ------------------------------------------------------------------
%   `source_unit` records what the SOURCE wrote. None of the four v1 templates
%   writes a unit for any field -- they are bare doubles. The canonical
%   `value.value` is seconds for the three time quantities, and that is read off
%   the WRITER's arithmetic rather than assumed: spikeextractor.m:140-143
%   multiplies center_range_time / refractory_time / spike_start_time /
%   spike_end_time by sample_rate to get SAMPLES, so the stored numbers are
%   seconds. Claiming source_unit 's' would put a unit in the record that v1
%   never recorded.
%
%   ------------------------------------------------------------------
%   THE TAIL IS BUILT BY SUBTRACTION, NOT BY AN ALLOW-LIST
%   ------------------------------------------------------------------
%   `other` starts as the WHOLE source block and loses only the fields this
%   function actually consumed. A field NDI adds later therefore survives by
%   default instead of being silently dropped by an allow-list that has not
%   heard of it -- the failure mode the migrator vocabulary audit exists to
%   catch, pointed the other way.
%
%   The filter settings are grouped under `other.filter` rather than left flat.
%   The plan routes them out to a `frequency_filter` document via a
%   `filter_id` edge -- but the BUILT class carries no such edge:
%
%     python3 -c "import json;print([d['name'] for d in json.load(open(
%       'schemas/V_eta/stable/method_parameters.json'))['depends_on']])"
%        ['software_id', 'subject_id', 'epoch_id', 'derived_from_id']
%
%   When artifact and prose disagree the artifact wins, so no filter_id is
%   invented here. Grouping them keeps them findable, whole, in one sub-struct
%   for the day that extraction is built.
%
%   Shared helper for the Brainstorm-J (+migrators_j) method_parameters fold.

arguments
    blk (1,1) struct
end

entries = struct('variable', {}, 'value', {});
other = blk;

% --- refractory period -------------------------------------------------------
v = numField(blk, 'refractory_time');
if ~isempty(v)
    entries(end+1) = jParameterEntry('refractory period', v, '', ...
        rawText(blk, 'refractory_time'));
    other = dropField(other, 'refractory_time');
end

% --- waveform window: anchor + extent ---------------------------------------
startT = numField(blk, 'spike_start_time');
endT   = numField(blk, 'spike_end_time');
if ~isempty(startT)
    entries(end+1) = jParameterEntry('waveform window start', startT, '', ...
        rawText(blk, 'spike_start_time'));
    other = dropField(other, 'spike_start_time');
    if ~isempty(endT)
        % source_value is EMPTY on purpose: v1 recorded an end, not a duration,
        % so there is no source spelling of this number to keep verbatim.
        entries(end+1) = jParameterEntry('waveform window duration', ...
            endT - startT, '', '');
        other = dropField(other, 'spike_end_time');
    end
end

% --- threshold ---------------------------------------------------------------
method = jGetChar(blk, 'threshold_method');
param  = numField(blk, 'threshold_parameter');
if ~isempty(param)
    variableName = '';
    switch lower(strtrim(method))
        case 'standard_deviation'
            variableName = 'standard-deviation threshold';
        case 'absolute'
            variableName = 'absolute voltage threshold';
    end
    if ~isempty(variableName)
        entries(end+1) = jParameterEntry(variableName, param, '', ...
            rawText(blk, 'threshold_parameter'));
        other = dropField(other, 'threshold_parameter');
        other = dropField(other, 'threshold_method');
    end
end

% --- group the filter settings so the frequency_filter build can find them ---
other = groupFields(other, 'filter', {'do_filter', 'filter_type', ...
    'filter_low', 'filter_high', 'filter_order', 'filter_ripple'});
end

% ===================== helpers =============================================

function v = numField(blk, name)
%NUMFIELD Scalar double from a numeric OR numeric-string field ([] if absent).
%   The string branch is not defensive padding: v1 writes
%   vmspikefilteringparameters.threshold as "0.030", a STRING, while its own
%   schema_documents pair declares it a number. Both spellings are real.
v = [];
if ~isstruct(blk) || ~isfield(blk, name)
    return;
end
x = blk.(name);
if isnumeric(x) && isscalar(x) && ~isnan(x)
    v = double(x);
elseif (ischar(x) && ~isempty(x)) || (isstring(x) && isscalar(x) && strlength(x) > 0)
    d = str2double(char(x));
    if ~isnan(d)
        v = d;
    end
end
end

function s = rawText(blk, name)
%RAWTEXT The source's own spelling of a value, for `value.source_value`.
s = '';
if ~isstruct(blk) || ~isfield(blk, name)
    return;
end
x = blk.(name);
if ischar(x)
    s = x;
elseif isstring(x) && isscalar(x)
    s = char(x);
elseif isnumeric(x) && isscalar(x)
    % 15 significant digits round-trips a double without printing the
    % floating-point noise that %.17g exposes (0.0005 -> "0.0005", not
    % "0.00050000000000000001").
    s = sprintf('%.15g', double(x));
end
end

function s = dropField(s, name)
if isfield(s, name)
    s = rmfield(s, name);
end
end

function s = groupFields(s, groupName, names)
%GROUPFIELDS Move NAMES, if present, into a sub-struct S.(GROUPNAME).
g = struct();
for i = 1:numel(names)
    if isfield(s, names{i})
        g.(names{i}) = s.(names{i});
        s = rmfield(s, names{i});
    end
end
if ~isempty(fieldnames(g))
    s.(groupName) = g;
end
end

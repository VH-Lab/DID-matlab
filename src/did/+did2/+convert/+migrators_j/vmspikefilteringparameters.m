function bodies = vmspikefilteringparameters(preBody)
%VMSPIKEFILTERINGPARAMETERS Brainstorm-J migrator: did_v1
%   vmspikefilteringparameters -> ONE `method_parameters` document (+ the
%   `software` entity its v1 `app` block names) -- GUARDED, because this class
%   mixes OUTPUT DATA into a configuration document.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   Until now this class had NO migrator at all -- it reached validation in its
%   did_v1 shape (see the "NOT MIGRATED AT ALL, deliberately" note this change
%   removes from Contents.m). It now folds like its three siblings.
%
%   GROUND TRUTH, read from NDI origin/main:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%         vhlab_voltage2firingrate/vmspikefilteringparameters.json
%        superclasses: base, epochid, app
%        depends_on:   element_id
%        sampling_rate 0   new_sampling_rate 0   threshold "0.030"
%        spiketimes ""     filter_algorithm "0"
%        filter_algorithm_parameters [ { filter_algorithm_parameter_name,
%                                        filter_algorithm_parameter_value } ]
%        rm60Hz 1          refract 0.0025
%
%   NOTE `rm60Hz`: did2.convert.universalRenames snake_cases block field names,
%   so this migrator sees `rm60_hz`. Both spellings are read.
%
%   THERE IS NO WRITER. Checked by bare class name across the whole repository,
%   not by one call idiom (the mistake that nearly lost `valid_interval`):
%
%     git grep -l -i "vmspikefilteringparameters" origin/main
%        .../database_documents/apps/vhlab_voltage2firingrate/binnedspikeratevm.json
%        .../database_documents/apps/vhlab_voltage2firingrate/vmspikefilteringparameters.json
%        .../resources/ndiDocumentAttributes.json
%        .../schema_documents/apps/vhlab_voltage2firingrate/vmspikefilteringparameters_schema.json
%     git grep -c -i "vmspikefilteringparameters" origin/main -- '*.m'
%        (no output -- 0 files)
%
%   That is the same missing `vhlab_voltage2firingrate` writer that keeps
%   binnedspikeratevm, vmneuralresponseresiduals and vmspikesummary as deferred
%   passthroughs. It constrains what may be asserted here, and it is why the
%   guard below exists.
%
%   ------------------------------------------------------------------
%   THE GUARD: `spiketimes` IS OUTPUT DATA AND HAS NO HOME HERE
%   ------------------------------------------------------------------
%   `spiketimes` is a list of detected event times sitting inside a
%   configuration document. It is NOT a parameter and must not be folded into
%   `method_parameters` -- the class is settings, and burying a result in the
%   settings bag would make it unfindable and would misrepresent it.
%
%   The plan's one-line disposition is "`spiketimes` leaves as an event-times
%   observation", but that is a sentence, not a model: no event-times leaf shape
%   is decided for this class, and with no writer the encoding (seconds? sample
%   indices? which clock?) is undocumented -- exactly the reason its three
%   sibling classes are deferred rather than migrated.
%
%   So: DEFERRED, WITH A GUARD RATHER THAN A DROP.
%     - `spiketimes` EMPTY (the template's own value, and any document that
%       stores settings only) -> fold to method_parameters.
%     - `spiketimes` NON-EMPTY -> pass the document through UNCHANGED, intact,
%       for the second pass. Nothing is lost and nothing is invented.
%   Passing through is the shape already used for fitcurve, openminds_stimulus
%   and probe_geometry. It is not a regression on today's behaviour either:
%   before this migrator existed EVERY document of this class went to the
%   tombstone unchanged.
%
%   ------------------------------------------------------------------
%   FIELD DISPOSITION on the folding path -- nothing dropped
%   ------------------------------------------------------------------
%     refract        -> parameter `refractory period`.  UNIFIES with
%                       spike_extraction_parameters.refractory_time: two v1
%                       names for one concept, comparable for the first time
%                       under one variable. That unification is the stated
%                       point of the extraction.
%     threshold      -> parameter `absolute voltage threshold`. The verbatim
%                       string "0.030" is kept in value.source_value while
%                       value.value carries 0.030 as a number. It is a SEPARATE
%                       variable from spike_extraction_parameters' SD-multiple
%                       threshold, deliberately: a standard-deviation multiple
%                       and an absolute level are not the same quantity and must
%                       not be numerically comparable.
%     sampling_rate  -> other.sampling_rate.  The plan says DROP it as a
%                       duplicate of the data body's own time axis (#45) -- but
%                       #45 is not built, this class has no body, and this
%                       document is the only place the number exists. Kept
%                       rather than dropped on a duplicate that does not yet
%                       exist; raised as an open question.
%     new_sampling_rate, filter_algorithm, filter_algorithm_parameters, rm60Hz
%                    -> other.* (filter settings grouped under other.filter, as
%                       in jSpikeExtractionSettings, because the built
%                       method_parameters class carries no filter_id edge)
%     epochid.epochid-> other.epochid, parked by jMethodParameters until the
%                       epoch pass can mint the `epoch` document to point at.
%     element_id     -> subject_id (D2: element ids are preserved as subjects).
%     app.*          -> the `software` entity + software_id.
%
%   source_unit is '' on both entries. v1 records no unit for either field, and
%   with no writer there is no arithmetic to read one off -- unlike
%   spike_extraction_parameters, whose seconds are provable from
%   spikeextractor.m:140-143. The numbers are carried as written.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'vmspikefilteringparameters') ...
        && isstruct(preBody.vmspikefilteringparameters)
    blk = preBody.vmspikefilteringparameters;
end

% ---------------------------------------------------------------- THE GUARD
if hasPayload(blk, 'spiketimes')
    bodies = {preBody};
    return;
end

entries = struct('variable', {}, 'value', {});
other = blk;

% `spiketimes` is provably empty on this path (the guard above), so removing it
% removes nothing. Kept out of the bag so an empty result field does not read
% as a stored result.
other = dropField(other, 'spiketimes');

% --- refractory period -------------------------------------------------------
v = numField(blk, 'refract');
if ~isempty(v)
    entries(end+1) = jParameterEntry('refractory period', v, '', ...
        rawText(blk, 'refract'));
    other = dropField(other, 'refract');
end

% --- absolute threshold ------------------------------------------------------
t = numField(blk, 'threshold');
if ~isempty(t)
    entries(end+1) = jParameterEntry('absolute voltage threshold', t, '', ...
        rawText(blk, 'threshold'));
    other = dropField(other, 'threshold');
end

% --- group the filter settings so the frequency_filter build can find them ---
other = groupFields(other, 'filter', {'filter_algorithm', ...
    'filter_algorithm_parameters', 'rm60_hz', 'rm60Hz'});

bodies = jMethodParameters(preBody, entries, other);
end

% ===================== helpers =============================================
% Local copies, deliberately: private/jSpikeExtractionSettings.m holds its own
% versions as local functions (invisible outside that file), and the codebase's
% convention is that a self-contained migrator keeps its own rather than growing
% the shared private/ surface for four one-liners.

function tf = hasPayload(blk, name)
%HASPAYLOAD Does the field carry actual data (not '' and not [])?
tf = false;
if ~isstruct(blk) || ~isfield(blk, name)
    return;
end
x = blk.(name);
if ischar(x)
    tf = ~isempty(strtrim(x));
elseif isstring(x)
    tf = any(strlength(strtrim(x)) > 0);
else
    tf = ~isempty(x);
end
end

function v = numField(blk, name)
%NUMFIELD Scalar double from a numeric OR numeric-string field ([] if absent).
%   The string branch is load-bearing here: v1 writes `threshold` as the STRING
%   "0.030" while its own schema_documents pair declares it a number.
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

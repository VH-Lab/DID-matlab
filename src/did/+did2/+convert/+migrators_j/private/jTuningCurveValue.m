function value = jTuningCurveValue(block)
%JTUNINGCURVEVALUE Reshape a v1 tuning result block into the unified `tuning_curve`
%   value (R2/R3 collapse, V_eta_tuning_model_plan.md). Emits ONLY the declared
%   tuning_curve sub-fields so the strict-fields validator is satisfied; reads the v1
%   block defensively (isfield-guarded) so an imperfect field name yields an empty
%   (but declared) slot rather than a validation failure.
%
%   The 6 v1 families differ: the fitted composites nest the curve under `tuning_curve`
%   and carry `significance` / `vector` / `fitless` / `fit*`; the raw
%   stimulus_tuningcurve is flat. Mapping:
%     v1 `vector`   -> circular_statistics   (circular_variance, preference, Hotelling)
%     v1 `fitless`  -> interpolated_values   (c50, l50, pref, bandwidth, …)
%     v1 `fit`/`fit_*` -> model_fit ARRAY    (each {model, coefficients, goodness})
%   The empirical curve (independent axis + mean/stddev/stderr/individual/control) maps
%   to the response_* fields.
%
%   "Field-name refinement (exact v1 keys) is a follow-up" -- PARTLY DONE, AND THE PART
%   THAT IS NOT DONE IS NAMED HERE RATHER THAN LEFT AS A BLANKET DISCLAIMER. Two reads
%   were corrected against the writers (NDIcalc-vis 65718ed); the evidence for each sits
%   on the helper that does it, so it is next to the code it justifies:
%     * controlBlock   read control_mean/_stddev/_stderr at BLOCK level, a level 0 of the
%                      writer's 64 mock documents populate, and never named
%                      control_mean_stddev / control_mean_stderr at all. Now reads the
%                      `tuning_curve` level, all six names.
%     * responseUnits  read `response_units` at BLOCK level -- correct for the FLAT raw
%                      stimulus_tuningcurve, wrong for all five fitted composites, which
%                      spell it `properties.response_units`. Now reads both, char-guarded.
%     * controlBlock (again) THE THIRD DEFECT, REPORTED THERE AND FIXED HERE -- but only
%                      THREE of its five names had a destination. The paragraph this
%                      replaces said the flat raw stimulus_tuningcurve "still contributes
%                      no control block"; it now contributes control_mean /
%                      control_stddev / control_stderr, aliased from the flat spellings.
%                      control_individual_responses_real and _imaginary are STILL
%                      unmapped, and that is a decision with evidence behind it rather
%                      than an omission -- see controlBlock's own header for both.
arguments
    block struct
end

% NOTE: build the scalar `value` WITHOUT passing a non-scalar struct array to struct()
% (that would distribute and make `value` itself an array). model_fit (a struct array) is
% assigned separately below.
value = struct( ...
    'independent_values', [], 'response_mean', [], 'response_stddev', [], ...
    'response_stderr', [], 'individual_responses', [], 'control_response', struct(), ...
    'response_units', '', 'model_fit', [], 'significance', struct(), ...
    'circular_statistics', struct(), 'interpolated_values', struct());
value.model_fit = emptyFits();

if ~isstruct(block) || ~isscalar(block); return; end

% The curve: fitted composites nest it under `tuning_curve`; the raw curve is flat.
tc = block;
if isfield(block, 'tuning_curve') && isstruct(block.tuning_curve)
    tc = block.tuning_curve;
end

value.response_mean       = getf(tc, {'mean', 'response_mean'});
value.response_stddev     = getf(tc, {'stddev', 'response_stddev'});
value.response_stderr     = getf(tc, {'stderr', 'response_stderr'});
value.individual_responses = getf(tc, {'individual', 'individual_responses', ...
                                       'individual_responses_real'});
value.independent_values  = independentAxis(tc, block);
value.response_units      = responseUnits(block);
value.control_response    = controlBlock(tc, block);

if isfield(block, 'significance') && isstruct(block.significance)
    value.significance = block.significance;
end
if isfield(block, 'vector') && isstruct(block.vector)
    value.circular_statistics = block.vector;
end
if isfield(block, 'fitless') && isstruct(block.fitless)
    value.interpolated_values = block.fitless;
end
value.model_fit = collectFits(block);
end

% ===================== helpers =============================================

function v = getf(s, names)
v = [];
if ~isstruct(s); return; end
for i = 1:numel(names)
    if isfield(s, names{i}); v = s.(names{i}); return; end
end
end

function ax = independentAxis(tc, block)
% The independent variable is named per family (direction / contrast / spatial_frequency
% / temporal_frequency / speed) and, for the raw curve, `independent_variable_value`.
ax = getf(tc, {'independent_variable_value', 'direction', 'contrast', ...
    'spatial_frequency', 'temporal_frequency', 'speed', 'independent_variable'});
if isempty(ax)
    ax = getf(block, {'independent_variable_value', 'independent_variable'});
end
end

function u = responseUnits(block)
% THE UNITS ARE SPELLED AT TWO DIFFERENT LEVELS, ONE PER SHAPE, AND BOTH ARE REAL.
%   * the FLAT raw `stimulus_tuningcurve` block carries `response_units` at BLOCK
%     level -- NDI-matlab +ndi/+app/+stimulus/tuning_response.m:405 declares it in the
%     emptystruct, and NDIcalc-vis +ndi/+calc/+vis/contrast_sensitivity.m:146 sets it
%     to 'Hz'. That is the level this function's predecessor read, and for this shape
%     it was right.
%   * the FIVE fitted composites carry it under `properties`, not on the block --
%     ALL FIVE writers, identically (NDIcalc-vis 65718ed):
%         contrast_tuning.m:213   oridir_tuning.m:207   spatial_frequency_tuning.m:234
%         speed_tuning.m:245      temporal_frequency_tuning.m:237
%             properties.response_units = tuning_doc.document_properties. ...
%                                            stimulus_tuningcurve.response_units;
%     Measured over the writer's own mock corpus: 64/64 documents across the five
%     families carry `properties.response_units`, and 0/64 carry a block-level one.
%     So the block-level read found nothing in every one of them.
%
% THE VALUE IS CHAR-GUARDED, AND THAT IS NOT DEFENSIVE PADDING -- IT IS THE POINT.
% `response_units` is declared in tuning_response.m's emptystruct (:405) and then
% NEVER ASSIGNED anywhere in that file, so it reaches the composites as the numeric
% EMPTY MATRIX: 64/64 of the mock documents have `properties.response_units = []`.
% V_eta types tuning_curve.value.response_units as `char` with blank_value '', and
% did2.schema.cache/validateTypeShape rejects a numeric for a char field
% (`did2:validation:typeMismatch`). Correcting the LEVEL without guarding the TYPE
% would therefore trade "reads nothing from the wrong place" for "reads an empty
% matrix into a char slot". A non-char value becomes the schema's own blank_value ''.
% The sibling helper jTuningFold/charField applies exactly this rule.
u = '';
levels = {block, subStruct(block, 'properties')};
for k = 1:numel(levels)
    v = getf(levels{k}, {'response_units', 'responseUnits'});
    if ischar(v) && ~isempty(v); u = v; return; end
    if isstring(v) && isscalar(v) && strlength(v) > 0; u = char(v); return; end
end
end

function c = controlBlock(tc, block)
% EVERY CONTROL FIELD LIVES INSIDE `tuning_curve`, IN ALL FIVE did_v1 FITTED TUNING
% WRITERS. This read used to take control_mean/_stddev/_stderr off the BLOCK, a level
% no writer populates, and never named the other two at all. Measured over the
% writer's own mock corpus (NDIcalc-vis 65718ed, +ndi/+calc/+vis/mock/):
%
%   DENOMINATOR: 64 mock document(s), 5 families; control_* at BLOCK level: 0/64
%   contrast_tuning       9/9   tuning_curve: control_stddev, control_stderr
%   orientation_direction 7/7   tuning_curve: control_individual
%   spatial_frequency    22/22  tuning_curve: control_mean, control_stddev,
%                               control_stderr, control_mean_stddev, control_mean_stderr
%   speed_tuning         18/18  tuning_curve: control_stddev, control_stderr
%   temporal_frequency    8/8   the same five as spatial_frequency
%
% Writer lines, one per family: contrast_tuning.m:237-238, oridir_tuning.m:232,
% spatial_frequency_tuning.m:258-262, speed_tuning.m:276-277,
% temporal_frequency_tuning.m:261-265 -- every one of them inside the
% `tuning_curve = struct(...)` call, none beside it.
%
% `tc` is block.tuning_curve when that sub-struct exists and `block` itself otherwise
% (the flat raw curve), so reading tc first and falling back to block covers both
% shapes without inventing a level. The camelCase fallback is the repo's standing rule
% for a NESTED read: universalRenames.m:32-37 snake_cases only the IMMEDIATE field
% names of a property block and leaves nested struct values alone.
%
% ---------------------------------------------------------------------------
% THE FLAT RAW CURVE SPELLS ITS CONTROL FIELDS DIFFERENTLY, AND THREE OF THE FIVE
% NAMES ARE ALIASED HERE. THE OTHER TWO ARE NOT, ON EVIDENCE.
% ---------------------------------------------------------------------------
% The flat `stimulus_tuningcurve` is written by NDI-matlab
% +ndi/+app/+stimulus/tuning_response.m. Its emptystruct declares SEVEN names across
% :403-405 -- six control fields plus response_units, which is listed with them because
% it fails in the same way. What each one actually HOLDS, read from the ASSIGNMENTS and
% not from the declaration -- the distinction matters, because two of the seven are
% declared and never assigned and so reach every document as the numeric []:
%
%   control_response_mean     :478  nanmean(all_control_responses) per independent
%                                   point, indexed (I) -> a 1xnum_points row.
%                                   :479-481 takes abs() if any element is complex,
%                                   so the stored value is ALWAYS real.
%   control_response_stddev   :482  nanstd,          same shape, same realness.
%   control_response_stderr   :483  vlt.data.nanstderr, same shape, same realness.
%   control_individual_responses_real       :445 cell(1,num_points), filled :464-465,
%                                   flattened to a matrix at :493.
%   control_individual_responses_imaginary  :446 / :466-467 / :494, the same.
%   control_stimid            :403  DECLARED, NEVER ASSIGNED anywhere in the file
%                                   (its only other mention, :304, is a name-value
%                                   argument to vlt.neuro.stimulus.stimulus_response_scalar
%                                   -- a different function's parameter, not this field).
%   response_units            :405  DECLARED, NEVER ASSIGNED -- see responseUnits above.
%
% MAPPED, because the flat name and the composite name are the same statistic of the
% same population and differ only by the word `response`, which is redundant inside a
% slot already called `control_response`:
%       control_response_mean   -> control_mean
%       control_response_stddev -> control_stddev
%       control_response_stderr -> control_stderr
% Composite-side citations: the writers' own mock corpus (recorded in the DENOMINATOR
% above, and in tests/+did2/+unittest/testTuningCurveLevels.m's fixtures, where
% spatial_frequency's control_mean is a per-point 4-vector while control_mean_stddev is
% a scalar -- i.e. control_mean is per-point, exactly like control_response_mean), and
% DID-schema schemas/V_eta/conversions/from_did_v1/{contrast,spatial_frequency,
% temporal_frequency}_tuning.md:34, which type control_stddev/control_stderr as
% matrix<double>.
%
% NOT MAPPED, and this is the evidenced refusal rather than an oversight:
%       control_individual_responses_real       -> (nothing)
%       control_individual_responses_imaginary  -> (nothing)
% They are the two halves of ONE COMPLEX quantity, not two quantities. The only reader
% of them in NDI recombines them before using either -- tuning_response.m:820-823:
%       control_ind{i} = ...control_individual_responses_real{i} + ...
%           sqrt(-1)*...control_individual_responses_imaginary{i};
%       control_ind_real{i} = control_ind{i};
%       if any(~isreal(control_ind_real{i})), control_ind_real{i} = abs(...); end
% So the real-valued per-trial control matrix that the composite slot `control_individual`
% holds (DID-schema conversions/from_did_v1/orientation_direction_tuning.md:38,75-77 and
% speed_tuning.md:34,59-62: "per-trial control responses", matrix<double>, rows index
% sampled points and columns index trials) is abs(real + i*imag), NOT the real part.
% Aliasing `_real` onto `control_individual` would therefore relabel a COMPONENT as the
% WHOLE, and would be wrong for exactly the modulated (F1) data the imaginary part exists
% for. The honest alternative -- minting `control_individual_real` and
% `control_individual_imaginary` -- invents two names that no writer and no V_eta slot
% has, so it is reported instead: `tuning_curve.value.control_response` is declared in
% DID-schema schemas/V_eta/draft/tuning_curve.json as a `structure` with "fields": [],
% i.e. ZERO named sub-slots, so nothing here is schema-checked and a fabricated name
% would pass silently. That is the reason to be strict by hand, not a licence.
%
% control_stimid is not mapped either, and cannot be: it is never assigned, so it is []
% in every document and the empty-guard below would drop it even if a slot existed.
c = struct();
% {canonical V_eta key, additional spellings the FLAT raw curve uses}. The canonical
% name is searched FIRST at every level, so the five fitted composites resolve exactly
% as they did before this alias list existed -- an ADDITION for a shape that yielded
% nothing, never a re-mapping of the shape that worked.
spec = { ...
    'control_individual',   {}; ...
    'control_mean',         {'control_response_mean'}; ...
    'control_stddev',       {'control_response_stddev'}; ...
    'control_stderr',       {'control_response_stderr'}; ...
    'control_mean_stddev',  {}; ...
    'control_mean_stderr',  {}};
for i = 1:size(spec, 1)
    nm = spec{i, 1};
    cands = [{nm}, spec{i, 2}];
    search = cell(1, 2 * numel(cands));
    for k = 1:numel(cands)
        search{2*k - 1} = cands{k};
        search{2*k}     = camelOf(cands{k});
    end
    v = getf(tc, search);
    if isempty(v); v = getf(block, search); end
    % THE EMPTY GUARD IS THE "INVENTS NOTHING" RULE, and it is load-bearing for the flat
    % shape in a way it never was for the composites: vlt.data.emptystruct declares all
    % five flat names on EVERY raw curve, so a document with no control data carries them
    % present-and-empty. Emitting them would mint five blank slots on every such
    % document -- the invented-empty-field pattern this repo keeps a census for.
    if ~isempty(v); c.(nm) = v; end
end
end

function b = subStruct(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end

function out = camelOf(nm)
% snake_case -> lowerCamelCase, for the nested-field fallback described above.
parts = strsplit(nm, '_');
out = parts{1};
for k = 2:numel(parts)
    p = parts{k};
    if isempty(p); continue; end
    p(1) = upper(p(1));
    out = [out p]; %#ok<AGROW>
end
end

function fits = collectFits(block)
% Every field whose name is `fit` or starts with `fit_` becomes one model_fit entry.
fits = emptyFits();
if ~isstruct(block); return; end
fns = fieldnames(block);
for i = 1:numel(fns)
    nm = fns{i};
    if strcmp(nm, 'fit') || (numel(nm) > 4 && strncmp(nm, 'fit_', 4))
        b = block.(nm);
        if ~isstruct(b); continue; end
        modelName = nm;
        if strcmp(nm, 'fit'); modelName = 'fit'; else; modelName = nm(5:end); end
        entry = struct('model', jOntologyTerm('', modelName), ...
            'coefficients', b, 'goodness', struct());
        if isempty(fits); fits = entry; else; fits(end+1) = entry; end %#ok<AGROW>
    end
end
end

function e = emptyFits()
e = struct('model', {}, 'coefficients', {}, 'goodness', {});
end

function ff = jFrequencyFilter(preBody)
%JFREQUENCYFILTER Build a V_eta `frequency_filter` document from a did_v1
%   `filter` superclass block. Returns [] when the block describes no filter
%   this model can represent, in which case the caller emits nothing and adds no
%   `filter_id` edge -- an unresolvable design must never become a guessed one.
%
%   TEAM-SIGN-OFF (jess, 2026-07-30, V_eta_frequency_filter_model_plan.md):
%   "Approved the frequency_filter model as written below: a referenced document
%   under base rather than an entity, band edges rather than a single cutoff,
%   typed gain fields rather than a coefficients bag, no sample_rate, and the
%   name frequency_filter."
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main -- AND THE WRITER WINS TWICE
%   ---------------------------------------------------------------------
%   `filter` is a class in its own right (ndi_common/database_documents/data/
%   filter.json) but NOTHING EVER CONSTRUCTS ONE: it is declared as a superclass
%   by exactly two files -- itself and data/pyraview.json -- and no `.m` file on
%   origin/main passes 'filter' to ndi.document() or newdocument(). It reaches
%   this migration ONLY as pyraview's inherited block.
%
%       filter: { label, type, algorithm, parameters }
%
%   The block-level names are already lowercase, so universalRenames leaves them
%   alone. `parameters` is a NESTED struct and universalRenames snake_cases only
%   ONE level (snakeCasePropertyBlocks -> snakeCaseBlockFields, no recursion), so
%   its sub-fields arrive in the writer's own camelCase. Both spellings are read
%   anyway -- the standing nested-read rule.
%
%   THE WRITER IS ndi.gui.app.pyraview.filterData (called by makePyraviewDoc.m:58
%   for the document's metadata and again at :108 for the data), and it disagrees
%   with the template's documentation in TWO places. The writer wins:
%
%       filterData.m:37-41   struct('sampleFrequency', sr, 'order', NaN, ...
%                                   'filterFrequency', NaN, 'passBandRipple', NaN,
%                                   'stopbandAttentuation', NaN)      <- all-pass
%       filterData.m:49-53   struct('sampleFrequency', sr, 'order', 4, ...
%                                   'filterFrequency', 300, 'passBandRipple', 0.8,
%                                   'stopbandAttentuation', NaN)
%
%     * `passBandRipple` has a CAPITAL B. filter.md and filter_schema.json both
%       document it as `passbandRipple`. git grep on origin/main: 2 hits for
%       `passBandRipple`, 0 for `passbandRipple`.
%     * `stopbandAttentuation` is MISSPELLED (an extra `tu`), in the writer AND
%       in the real PRED document. git grep: 2 hits for `stopbandAttentuation`,
%       0 for `stopbandAttenuation`. A migrator reading the correct spelling gets
%       nothing, silently -- the defect class the ground-truth track exists for.
%
%   ---------------------------------------------------------------------
%   THE MAPPING, FIELD BY FIELD
%   ---------------------------------------------------------------------
%     type      -> band          'high' -> high_pass, 'low' -> low_pass,
%                                'bandpass' -> band_pass. NDI's documented set is
%                                exactly {'bandpass','low','high','none'}
%                                (filter_schema.json + filter.md) and the writer
%                                only ever emits 'low'/'high'/'none'.
%                                'none' -> NO DOCUMENT (an all-pass is not a
%                                filter; the model's `band` is mustBeNonEmpty and
%                                its value_set has no 'none').
%                                NOTHING MAPS TO band_stop: v1 has no spelling
%                                for a notch, so this helper cannot emit one and
%                                does not pretend to. `stopband` is therefore
%                                never written either.
%     algorithm -> algorithm     the six value_set names pass through unchanged
%                                (chebyshev_1 | chebyshev_2 | butterworth |
%                                elliptic | bessel | fir). NDI adds 'none';
%                                that -> NO DOCUMENT, same reason.
%     parameters.filterFrequency -> passband edge, in Hz. `filterData` normalises
%                                by `nyquist = 0.5 * sr` where sr is the probe's
%                                sample rate in Hz, so the stored number is Hz.
%                                high_pass -> passband.low  (open above)
%                                low_pass  -> passband.high (open below)
%                                band_pass -> both, from a 2-element vector
%     parameters.order           -> order, when integer-valued. The field is
%                                typed `integer` and the validator rejects a
%                                non-integer, so a fractional order is dropped
%                                rather than quarantining the document.
%     parameters.passBandRipple  -> passband_ripple (`gain`, canonical decibels).
%                                cheby1's Rp argument is peak-to-peak passband
%                                ripple IN DECIBELS -- filterData.m:66,68 passes
%                                this number straight to cheby1(4, 0.8, ...) --
%                                so source_unit is 'dB' and the canonical value
%                                is the same number.
%     parameters.stopbandAttentuation -> stopband_attenuation, same treatment.
%
%   NOT CARRIED, both deliberately:
%     parameters.sampleFrequency   THE MODEL HAS NO sample_rate. This document is
%                                  a SPECIFICATION ("4th-order Chebyshev-I
%                                  high-pass at 300 Hz"), which is what makes it
%                                  shareable; the realised coefficients depend on
%                                  the rate, and the rate is already on the
%                                  recording.
%     label                        In the real PRED document `type` and `label`
%                                  are BOTH "high" -- the same fact twice. The
%                                  writer sets label to the user-facing band
%                                  (filterData.m:32) and type to the schema's
%                                  vocabulary, and they only diverge for the
%                                  all-pass case, which emits no document at all.
%
%   NaN MEANS INAPPLICABLE, NOT ZERO. Chebyshev-I has no stopband spec, so NDI
%   writes NaN. Per the rule already set for time references, an inapplicable
%   parameter is ABSENT, never NaN -- and `mustNotHaveNaN` is false on these
%   fields, so a NaN would have validated cleanly and silently.
%
%   preBody   the post-universalRenames source body carrying a `filter` block.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

ff = [];

blk = struct();
if isfield(preBody, 'filter') && isstruct(preBody.filter) && isscalar(preBody.filter)
    blk = preBody.filter;
end
if isempty(fieldnames(blk))
    return;
end

% `filter_type` IS READ FIRST, AND THAT IS NOT DEFENSIVENESS -- IT IS THE NAME
% THIS MIGRATOR ACTUALLY SEES. v1_to_v2 runs the SUPERCLASS migrators before the
% concrete one (v1_to_v2.m:154 applySuperclassMigrators, then :162
% runConcreteMigrator), unconditionally, for every TargetVersion. pyraview
% declares `filter` among its superclasses, so `did2.convert.migrators.filter`
% fires first and renames the field:
%
%     +migrators/filter.m:30-33   block.filter_type = char(block.type);
%                                 block = rmfield(block, 'type');
%
% Reading only `type` -- the name the NDI template and the writer both use --
% would therefore have returned '' on EVERY REAL DOCUMENT, the guard below would
% have fired every time, and this fold would have emitted nothing while looking
% like a correct, cautious guard. That is the ground-truth failure wearing the
% opposite disguise: right about the source, wrong about the pipeline. Bare
% `type` is kept as the fallback because a direct call to this migrator (as the
% unit tests make) has not been through the superclass pass.
algorithm = mapAlgorithm(readChar(blk, {'algorithm'}));
band      = mapBand(readChar(blk, {'filter_type', 'type'}));
if isempty(algorithm) || isempty(band)
    % 'none', blank, or a spelling v1 has never used. Guard and emit nothing;
    % the caller leaves its bodies without a filter_id.
    return;
end

params = struct();
if isfield(blk, 'parameters') && isstruct(blk.parameters) && isscalar(blk.parameters)
    params = blk.parameters;
end

edges = readNumVec(params, {'filterFrequency', 'filter_frequency'});
order = readNumScalar(params, {'order'});
ripple = readNumScalar(params, {'passBandRipple', 'pass_band_ripple', ...
    'passbandRipple', 'passband_ripple'});
% MISSPELLED FIRST -- that is the spelling the writer and the data use.
attenuation = readNumScalar(params, {'stopbandAttentuation', 'stopband_attentuation', ...
    'stopbandAttenuation', 'stopband_attenuation'});

block = struct('algorithm', jOntologyTerm('', algorithm), ...
    'band', jOntologyTerm('', band));

passband = struct();
switch band
    case 'high_pass'
        if ~isempty(edges); passband.low = hz(edges(1)); end
    case 'low_pass'
        if ~isempty(edges); passband.high = hz(edges(1)); end
    case 'band_pass'
        % A band-pass needs two edges. If the source gave only one there is no
        % way to know which end it is, so neither is asserted.
        if numel(edges) >= 2
            passband.low  = hz(edges(1));
            passband.high = hz(edges(2));
        end
end
if ~isempty(fieldnames(passband))
    block.passband = passband;
end

if ~isempty(order) && mod(order, 1) == 0
    block.order = order;
end
if ~isempty(ripple)
    block.passband_ripple = decibels(ripple);
end
if ~isempty(attenuation)
    block.stopband_attenuation = decibels(attenuation);
end

sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end

ff = struct();
ff.document_class = struct('class_name', 'frequency_filter', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
ff.depends_on = struct('name', {}, 'value', {});
% A FRESH ID. The filter is a SIBLING document split off the carrier, not the
% carrier itself -- the carrier keeps its own id (pyraview's observation does),
% so nothing dangles.
ff.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_frequency_filter', 'datestamp', ds);
ff.frequency_filter = block;
end

% ===================== small helpers =======================================

function out = mapAlgorithm(raw)
% The value_set from schemas/V_eta/stable/frequency_filter.json. NDI's own
% documented set (filter_schema.json) is the same list plus 'none', which maps
% to nothing on purpose.
out = '';
raw = lower(strtrim(raw));
known = {'chebyshev_1', 'chebyshev_2', 'butterworth', 'elliptic', 'bessel', 'fir'};
if any(strcmp(raw, known))
    out = raw;
end
end

function out = mapBand(raw)
% NDI `filter.type` -> V_eta `band`. NDI's documented set is
% {'bandpass','low','high','none'}; the identity spellings are accepted too so a
% body that has already been through this model round-trips.
out = '';
raw = lower(strtrim(raw));
switch raw
    case {'high', 'high_pass'}
        out = 'high_pass';
    case {'low', 'low_pass'}
        out = 'low_pass';
    case {'bandpass', 'band_pass'}
        out = 'band_pass';
end
end

function c = hz(v)
c = struct('hertz', double(v), 'source_unit', 'Hz', ...
    'source_value', double(v), 'approximate', false);
end

function c = decibels(v)
c = struct('decibels', double(v), 'source_unit', 'dB', ...
    'source_value', double(v), 'approximate', false);
end

function s = readChar(block, names)
s = '';
for k = 1:numel(names)
    if isstruct(block) && isfield(block, names{k})
        v = block.(names{k});
        if ischar(v) && ~isempty(v)
            s = v; return;
        elseif isstring(v) && isscalar(v) && strlength(v) > 0
            s = char(v); return;
        end
    end
end
end

function v = readNumScalar(block, names)
% [] for absent, non-numeric, non-scalar OR NaN. NaN is the source's way of
% saying "this parameter does not apply to this design"; an inapplicable
% parameter is ABSENT, never NaN.
v = [];
raw = readNumVec(block, names);
if isscalar(raw)
    v = raw;
end
end

function v = readNumVec(block, names)
v = [];
for k = 1:numel(names)
    if isstruct(block) && isfield(block, names{k})
        raw = block.(names{k});
        if isnumeric(raw) && ~isempty(raw)
            raw = double(raw(:)');
            raw = raw(~isnan(raw));
            if ~isempty(raw)
                v = raw; return;
            end
        end
    end
end
end

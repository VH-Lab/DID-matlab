function [ff, edgeName, unplaced] = jFrequencyFilter(preBody, nativeRate)
%JFREQUENCYFILTER Build the document a did_v1 `filter` superclass block
%   becomes, and name the edge a body points at it by. Returns [] when the
%   block describes no filter (an all-pass), in which case the caller emits
%   nothing and adds no edge -- an unresolvable design must never become a
%   guessed one.
%
%   UNPLACED (a cell of reasons, {} when none) names what of the block this
%   cannot place; the caller then carries its document whole as v1 ([small
%   unread settings] (2), Jess Haley, 2026-10-26; [partly placed is carried as
%   v1], 2026-10-25): a fractional order, a `label` that differs from the
%   `type`, a `sampleFrequency` with no method document to hold it, or a type /
%   algorithm spelling with no mapping (other than the all-pass 'none').
%
%   NATIVERATE (optional, [] when not given) is the caller's own sample rate
%   (a pyraview's `native_rate`). An all-pass's `sampleFrequency` equal to it
%   is not a carry: the V2 body keeps that rate, so it is recoverable
%   ([pass-through filter sample frequency], Jess Haley, 2026-10-26; NDI's
%   writer sets both from one variable, makePyraviewDoc.m:53/58/157). One that
%   differs carries the document, citing carry-061 (malformed).
%
%   FILTERS ARE METHODS (Jess Haley 2026-10-22 [filters are methods], N1a,
%   V_eta_frequency_filter_model_plan.md): `frequency_filter` is deleted (a V2
%   invention; 0 occurrences in NDI's ground truth) and the filter is a
%   `method` document -- term the filter design, parameters the band, the
%   passband edges in Hz, the filter order (a count), the passband ripple and
%   stopband attenuation in dB -- and a body's `filter_id` becomes `method_id`.
%   This builds only the `method` document (EDGENAME 'method_id'). The
%   frequency_filter path is removed: a LOADED schema whose sampled_body still
%   declares `filter_id` (did-schema before [filters are methods]) is an error,
%   did2:convert:schemaTooOld, never a carry and never a frequency_filter
%   ([pipeline defects are not carries], Jess Haley, 2026-10-26). One that
%   declares neither edge is an error too (did2:convert:noFilterEdge).
%
%   The band-edges / typed-gain reading below comes from the frequency_filter
%   model (TEAM-SIGN-OFF, jess, 2026-07-30, V_eta_frequency_filter_model_plan.md),
%   which [filters are methods] keeps as the method's parameters.
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
%                                non-integer, so a fractional order CARRIES THE
%                                DOCUMENT AS V1 ([small unread settings] (2),
%                                2026-10-26; it was dropped before).
%     parameters.passBandRipple  -> passband_ripple (`gain`, canonical decibels).
%                                cheby1's Rp argument is peak-to-peak passband
%                                ripple IN DECIBELS -- filterData.m:66,68 passes
%                                this number straight to cheby1(4, 0.8, ...) --
%                                so source_unit is 'dB' and the canonical value
%                                is the same number.
%     parameters.stopbandAttentuation -> stopband_attenuation, same treatment.
%
%     parameters.sampleFrequency -> a method parameter 'sample frequency' in
%                                hertz ([small unread settings] (2), Jess
%                                Haley, 2026-10-26; it was not carried, as the
%                                frequency_filter model has no sample_rate). For
%                                an all-pass (no method is built) it has no
%                                home and the document is carried as v1.
%     label                        Not written: in the real PRED document `type`
%                                  and `label` are BOTH "high" -- the same fact
%                                  twice. The writer sets label to the
%                                  user-facing band (filterData.m:32) and type
%                                  to the schema's vocabulary; they diverge for
%                                  the all-pass ('all' / 'none'). A `label` that
%                                  differs from `type` carries the document as
%                                  v1 ([small unread settings] (2)).
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
edgeName = '';
unplaced = {};

blk = struct();
if isfield(preBody, 'filter') && isstruct(preBody.filter) && isscalar(preBody.filter)
    blk = preBody.filter;
end
if isempty(fieldnames(blk))
    return;
end

% `type` is the name the NDI template and the writer use, and the name this
% migrator sees: pyraview reads raw v1 (did2.convert.rawV1Classes), so no
% superclass pass runs first. `filter_type` is still read, first, for a body
% that came through the renamed path while +migrators/filter.m existed (it
% renamed `type` -> `filter_type`; deleted by [unreached superclass migrators
% deleted], Jess Haley, 2026-10-27).
rawAlgorithm = readChar(blk, {'algorithm'});
rawType = readChar(blk, {'filter_type', 'type'});
algorithm = mapAlgorithm(rawAlgorithm);
band      = mapBand(rawType);

params = struct();
if isfield(blk, 'parameters') && isstruct(blk.parameters) && isscalar(blk.parameters)
    params = blk.parameters;
end

% [small unread settings] (2) (Jess Haley, 2026-10-26): what cannot be placed
label = readChar(blk, {'label'});
if ~isempty(label) && ~strcmp(strtrim(label), strtrim(rawType))
    unplaced{end+1} = sprintf('[carry-007] filter.label "%s" (differs from type "%s")', label, rawType);
end
sampleFrequency = readNumScalar(params, {'sampleFrequency', 'sample_frequency'});

if isempty(algorithm) || isempty(band)
    % 'none' or blank: an all-pass, no filter document and no edge. A spelling
    % with no mapping is not an all-pass: the caller carries the document.
    if ~(isNone(rawAlgorithm) && isNone(rawType))
        unplaced{end+1} = sprintf('[carry-042] filter.algorithm "%s" / type "%s" (no mapping)', ...
            rawAlgorithm, rawType);
    elseif ~isempty(sampleFrequency)
        if nargin < 2 || isempty(nativeRate)
            unplaced{end+1} = ['filter.parameters.sampleFrequency (an all-pass ' ...
                'has no method document to hold it)'];
        elseif double(sampleFrequency) ~= double(nativeRate)
            unplaced{end+1} = sprintf(['[carry-061] filter.parameters.sampleFrequency ' ...
                '%g (differs from the native rate %g)'], sampleFrequency, nativeRate);
        end
        % equal to the native rate: recoverable from the body, not written
    end
    return;
end

edges = readNumVec(params, {'filterFrequency', 'filter_frequency'});
order = readNumScalar(params, {'order'});
ripple = readNumScalar(params, {'passBandRipple', 'pass_band_ripple', ...
    'passbandRipple', 'passband_ripple'});
% MISSPELLED FIRST -- that is the spelling the writer and the data use.
attenuation = readNumScalar(params, {'stopbandAttentuation', 'stopband_attentuation', ...
    'stopbandAttenuation', 'stopband_attenuation'});

% names: the builder completes each from its field's bound value set
block = struct('algorithm', algorithm, 'band', band);

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
elseif ~isempty(order)
    unplaced{end+1} = sprintf('[carry-006] filter.parameters.order %g (not an integer)', order);
end
if ~isempty(ripple)
    block.passband_ripple = decibels(ripple);
end
if ~isempty(attenuation)
    block.stopband_attenuation = decibels(attenuation);
end

if ~isempty(unplaced)
    return;     % the caller carries the document whole as v1
end
% The LOADED schema must take the filter as a method. One whose sampled_body
% still declares filter_id is did-schema before [filters are methods]: that is
% the pipeline's defect, not the document's, so it is an error, never a carry
% and never a frequency_filter ([pipeline defects are not carries], Jess Haley,
% 2026-10-26, did-schema V_eta_go_forward_class_audit.md).
edges = sampledBodyEdges();
if ~any(strcmp(edges, 'method_id'))
    if any(strcmp(edges, 'filter_id'))
        error('did2:convert:schemaTooOld', ...
            ['%s "%s": the loaded schema is too old: its sampled_body declares ' ...
             '`filter_id` (the frequency_filter model, before [filters are methods], ' ...
             'Jess Haley 2026-10-22), not `method_id`, so the filter has no ' ...
             'home. Load a did-schema whose sampled_body declares method_id ' ...
             '(DID_SCHEMA_PATH); the document is not carried for a schema defect.'], ...
            classOf(preBody), idOf(preBody));
    end
    error('did2:convert:noFilterEdge', ...
        ['%s "%s": the loaded schema''s sampled_body declares no `method_id` ' ...
         '(edges: %s), so the filter has no home. Load a did-schema whose ' ...
         'sampled_body declares method_id (DID_SCHEMA_PATH).'], ...
        classOf(preBody), idOf(preBody), strjoin(edges, ', '));
end
ff = filterMethod(block, preBody, sampleFrequency);
edgeName = 'method_id';
end

function c = classOf(preBody)
c = 'pyraview';
if isfield(preBody, 'document_class') && isstruct(preBody.document_class) ...
        && isfield(preBody.document_class, 'class_name') ...
        && ~isempty(preBody.document_class.class_name)
    c = char(preBody.document_class.class_name);
end
end

function i = idOf(preBody)
i = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    i = char(preBody.base.id);
end
end

function tf = isNone(raw)
tf = any(strcmpi(strtrim(raw), {'', 'none'}));
end

function names = sampledBodyEdges()
% the edges the loaded schema's sampled_body (its chain) declares. Not wrapped
% in a try: a schema that cannot be read fails loudly here.
names = {};
c = did2.schema.cache.shared();
chain = c.classChain('sampled_body');
for k = 1:numel(chain)
    s = c.getClass(chain{k});
    if ~isfield(s, 'depends_on') || isempty(s.depends_on); continue; end
    d = s.depends_on;
    if isstruct(d); d = num2cell(d); end
    names = [names, cellfun(@(x) char(x.name), d, 'UniformOutput', false)]; %#ok<AGROW>
end
end

function m = filterMethod(block, preBody, sampleFrequency)
%FILTERMETHOD The filter as a `method` document ([filters are methods]): term
%   the design (its algorithm), parameters the band, the passband edges (Hz),
%   the order (a count) and the ripple / attenuation (dB). Every term is the
%   term registry's node and name (V_eta_frequency_filter_model_plan.md,
%   [filter terms from Wikidata] and [passband edges paired]): designs and
%   band values are Wikidata items, except Chebyshev type I / II, which are
%   EMPTY terms; the parameter variables are EMPTY terms.
designs = struct( ...
    'chebyshev_1', {{'EMPTY:0000387', 'Chebyshev type I filter'}}, ...
    'chebyshev_2', {{'EMPTY:0000388', 'Chebyshev type II filter'}}, ...
    'butterworth', {{'wikidata:Q1018162', 'Butterworth filter'}}, ...
    'elliptic', {{'wikidata:Q1051541', 'elliptic filter'}}, ...
    'bessel', {{'wikidata:Q830123', 'Bessel filter'}}, ...
    'fir', {{'wikidata:Q117785', 'Finite Impulse Response filter'}});
bands = struct( ...
    'high_pass', {{'wikidata:Q262754', 'high-pass filter'}}, ...
    'low_pass', {{'wikidata:Q918242', 'low-pass filter'}}, ...
    'band_pass', {{'wikidata:Q2718101', 'band-pass filter'}});
edges = struct( ...
    'low', {{'EMPTY:0000390', 'passband low edge'}}, ...
    'high', {{'EMPTY:0000391', 'passband high edge'}});
bandT = bands.(block.band);
p = {did2.build.parameter(did2.build.term('EMPTY:0000389', 'filter band'), ...
    'Term', did2.build.term(bandT{1}, bandT{2}))};
if isfield(block, 'passband')
    for e = {'low', 'high'}
        if isfield(block.passband, e{1})
            edgeT = edges.(e{1});
            p{end+1} = did2.build.parameter(did2.build.term(edgeT{1}, edgeT{2}), ...
                'Value', block.passband.(e{1}).hertz, 'Unit', did2.convert.registeredTerm('om:hertz', 'hertz'), ...
                'SourceValue', num2str(block.passband.(e{1}).source_value), 'SourceUnit', jSourceUnit('Hz')); %#ok<AGROW>
        end
    end
end
if isfield(block, 'order')
    p{end+1} = did2.build.parameter(did2.build.term('EMPTY:0000394', 'filter order'), ...
        'Count', block.order);
end
dbNames = {'passband_ripple', 'EMPTY:0000395', 'passband ripple'; ...
    'stopband_attenuation', 'EMPTY:0000396', 'stopband attenuation'};
for k = 1:size(dbNames, 1)
    if isfield(block, dbNames{k, 1})
        v = block.(dbNames{k, 1});
        p{end+1} = did2.build.parameter(did2.build.term(dbNames{k, 2}, dbNames{k, 3}), ...
            'Value', v.decibels, ...
            'Unit', did2.convert.registeredTerm('om:decibel', 'decibel'), 'SourceValue', num2str(v.source_value), ...
            'SourceUnit', jSourceUnit('dB')); %#ok<AGROW>
    end
end
% the design's sample frequency, as the writer states it (Hz: filterData
% normalises by 0.5 * sr) -- [small unread settings] (2), Jess Haley,
% 2026-10-26. The variable has no registered term yet, so it is name-only.
if ~isempty(sampleFrequency)
    p{end+1} = did2.build.parameter(jLabel('sample frequency'), ...
        'Value', sampleFrequency, 'Unit', did2.convert.registeredTerm('om:hertz', 'hertz'), ...
        'SourceValue', num2str(sampleFrequency, 17), 'SourceUnit', jSourceUnit('Hz'));
end
designT = designs.(block.algorithm);
m = did2.build.method(did2.build.term(designT{1}, designT{2}), did2.build.list(p{:}), ...
    'SessionId', jSid(preBody), 'CreationTimestamp', jStamp(preBody), 'Validate', false);
end

% ===================== small helpers =======================================

function out = mapAlgorithm(raw)
% The value_set of the deleted frequency_filter.json (each now a design term in
% filterMethod). NDI's own
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
c = struct('hertz', double(v), 'source_unit', jSourceUnit('Hz'), ...
    'source_value', double(v), 'approximate', false);
end

function c = decibels(v)
c = struct('decibels', double(v), 'source_unit', jSourceUnit('dB'), ...
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

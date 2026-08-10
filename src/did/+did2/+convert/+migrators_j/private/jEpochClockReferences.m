function refs = jEpochClockReferences(epochTable, epochDocId, sessionId, datestamp)
%JEPOCHCLOCKREFERENCES did_v1 `epochtable` -> one V_eta relative_reference per clock.
%
%   REFS = jEpochClockReferences(EPOCHTABLE, EPOCHDOCID, SESSIONID, DATESTAMP)
%   turns the `daqreader_epochdata_ingested.epochtable` block into a cell array
%   of `relative_reference` bodies -- one per (clock, interval) pair -- each
%   anchored to the epoch document EPOCHDOCID. Returns {} when there is nothing
%   interpretable to say.
%
%   ---------------------------------------------------------------------
%   THE SOURCE SHAPE, READ FROM THE WRITER (NOT FROM THE TEMPLATE)
%   ---------------------------------------------------------------------
%   The template says only `epochtable: { epochclock: "", t0_t1: "" }` and the
%   schema document types it `"type": "structure"`, so neither says what is
%   inside. Both writers do, identically:
%
%     +ndi/+daq/+reader/mfdaq.m:775-781   (and image.m:182-189, verbatim)
%        ec = obj.epochclock(epochfiles);            % cell of ndi.time.clocktype
%        for i=1:numel(ec); ec_{i} = ec{i}.ndi_clocktype2char(); end
%        daqreader_epochdata_ingested.epochtable.epochclock = ec_;
%        daqreader_epochdata_ingested.epochtable.t0_t1 = ...
%            ndi.fun.doc.t0_t1cell2array(obj.t0_t1(epochfiles));
%
%   So `epochclock` is a CELL ARRAY OF CHAR -- one clock name per entry, several
%   per epoch. (The polynomial lesson: a single `clock` field would be lossy in
%   exactly the way a flattened {slope, intercept} would have been.)
%
%   `t0_t1` is a 2-by-Nclocks MATRIX, column k belonging to epochclock{k}:
%
%     +ndi/+fun/+doc/t0_t1cell2array.m
%        t0t1_out = zeros(2,numel(t0t1_in));
%        t0t1_out(1,k) = t0t1_in{1,k}(1);   % t0
%        t0t1_out(2,k) = t0t1_in{1,k}(2);   % t1
%
%   NDI'S OWN READER ALREADY DEFENDS AGAINST A DEGENERATE ROUND-TRIP, and so does
%   this function -- the same three shapes, for the same reason:
%
%     +ndi/+daq/reader.m:89-101
%        t0t1_here = et.t0_t1;
%        if ~iscell(t0t1_here)
%           if isvector(t0t1_here)   % "this fixes a to-json, from-json, to-json
%              t{1} = t0t1_here(:)'; %  conversion problem" -- one clock arrives
%           else                     %  as a bare 2-vector, not a 2x1
%              for k=1:size(et.t0_t1,2); t{k} = t0t1_here(:,k)'; end
%           end
%        end
%
%   ---------------------------------------------------------------------
%   TWO GUARDS, BOTH FROM SIGNED DECISIONS -- NOT DEFENSIVENESS
%   ---------------------------------------------------------------------
%   NO TIMES => NO REFERENCE (`V_eta_time_reference_model_plan.md`). A reference
%   whose value is NaN is a hollow document -- precisely what did2.validate.
%   silentLoss and did2.validate.isFragment exist to catch -- so:
%
%     * clocktype 'no_time' (or absent)  -> NO document. `no_time` is a real,
%       reachable value: `ndi.time.clocktype` lists it, image.m:204-207 falls
%       back to it when an epoch has no clock, and migrators_i/image_stack.m:182
%       does the same.
%     * a non-finite t0 or t1           -> NO document. Also real and reachable:
%       the abstract `ndi.daq.reader.mfdaq/t0_t1` docstring says "The abstract
%       class always returns {[NaN NaN]}".
%
%   The reference is emitted with a METRIC (start/end) and no `relation`. Under
%   the signed time model `relation` carries the qualitative Allen relation used
%   when there is no metric offset; here the offsets ARE the content, and
%   `relation` is optional (mustBeNonEmpty: false in relative_reference.json).
%
%   `is_approximate` is derived from the clock name rather than guessed: NDI's
%   clocktype vocabulary marks the tier in the name itself ('approx_utc',
%   'approx_exp_global_time', 'approx_dev_global_time' are ~5 s;
%   the unprefixed forms are within 0.1 ms -- +ndi/+time/clocktype.m:20-29).
%
%   Shared helper for the Brainstorm-J (+migrators_j) ingested-payload migrators.

% No `arguments` size validation on epochDocId: the guarded callers pass '' (a
% 0-by-0 char) on the every-real-document-today path, and `(1,:) char` rejects
% that. The emptiness check below is the contract.
refs = {};
if isempty(epochDocId) || ~ischar(epochDocId) ...
        || ~isstruct(epochTable) || ~isscalar(epochTable)
    return;
end

clocks    = clockNames(epochTable);
intervals = intervalColumns(epochTable);
n = min(numel(clocks), numel(intervals));
% Deliberately min(): a mismatch means one of the two lists is not what the
% writer produces, and pairing a clock with the wrong interval is worse than
% emitting fewer references. The unpaired remainder stays on the source
% document, which these migrators preserve.

for k = 1:n
    clockName = clocks{k};
    if isempty(clockName) || strcmp(clockName, 'no_time')
        continue;                       % NO TIMES => NO REFERENCE
    end
    t = intervals{k};
    if numel(t) < 2 || ~all(isfinite(t(1:2)))
        continue;                       % NO TIMES => NO REFERENCE
    end
    approx = startsWithApprox(clockName);

    ref = struct();
    ref.document_class = struct('class_name', 'relative_reference', ...
        'class_version', '1.0.0', ...
        'superclasses', struct('class_name', 'time_reference', ...
            'class_version', '3.0.0'), ...
        'schema_version', 'V_eta');
    % relative_to is REQUIRED (team call, recorded in the time model plan: "a
    % relative time with no referent is not interpretable"). The caller has
    % already established it is non-empty; this function is never reached
    % otherwise.
    ref.depends_on = struct('name', {'relative_to'}, 'value', {epochDocId});
    ref.base = struct('id', did.ido.unique_id(), ...
        'session_id', sessionId, ...
        'name', 'migrated_epoch_extent', ...
        'datestamp', datestamp);
    ref.time_reference = struct('is_approximate', approx);
    ref.relative_reference = struct('value', struct( ...
        'start', durationCell(t(1), approx), ...
        'end',   durationCell(t(2), approx), ...
        'clock', clockName, ...
        'approximate', approx));
    refs{end+1} = ref; %#ok<AGROW>
end
end

% ===================== shape readers =======================================

function names = clockNames(epochTable)
%CLOCKNAMES The epoch's clock names, in writer order.
%   Accepts the cell-of-char the writer produces, plus the two shapes a
%   serialisation round-trip can leave behind (a bare char for a single clock, a
%   string array). The camelCase fallback is the standing migrator rule: only the
%   IMMEDIATE fields of a property block are snake_cased by universalRenames, and
%   `epochclock` sits one level down inside `epochtable`.
raw = subField(epochTable, {'epochclock', 'epochClock'});
names = {};
if isempty(raw)
    return;
end
if iscell(raw)
    for k = 1:numel(raw)
        names{end+1} = charOf(raw{k}); %#ok<AGROW>
    end
elseif isstring(raw)
    for k = 1:numel(raw)
        names{end+1} = char(raw(k)); %#ok<AGROW>
    end
elseif ischar(raw)
    if size(raw, 1) > 1
        for k = 1:size(raw, 1)
            names{end+1} = strtrim(raw(k, :)); %#ok<AGROW>
        end
    else
        names = {raw};
    end
end
end

function cols = intervalColumns(epochTable)
%INTERVALCOLUMNS The [t0 t1] pairs, one per clock, in writer order.
raw = subField(epochTable, {'t0_t1', 't0t1'});
cols = {};
if isempty(raw)
    return;
end
if iscell(raw)
    for k = 1:numel(raw)
        v = raw{k};
        if isnumeric(v); cols{end+1} = double(v(:)'); end %#ok<AGROW>
    end
    return;
end
if ~isnumeric(raw)
    return;
end
raw = double(raw);
if isvector(raw)
    % The round-trip degeneracy reader.m:93 documents: ONE clock's 2x1 column
    % comes back as a bare 2-element vector, not a matrix.
    cols = {raw(:)'};
    return;
end
for k = 1:size(raw, 2)
    cols{end+1} = raw(:, k)'; %#ok<AGROW>
end
end

function v = subField(s, candidates)
v = [];
for k = 1:numel(candidates)
    if isfield(s, candidates{k})
        v = s.(candidates{k});
        return;
    end
end
end

% ===================== small helpers =======================================

function tf = startsWithApprox(clockName)
tf = numel(clockName) >= 7 && strcmp(clockName(1:7), 'approx_');
end

function c = durationCell(seconds, approximate)
%DURATIONCELL The T14 one-`value` duration cell: canonical + source provenance.
%   NDI epoch clock times are already in SECONDS (`ndi.time.clocktype` documents
%   every tier in seconds), so `seconds` and `source_value` coincide and
%   `source_unit` is 's'. Recording both is not redundancy -- it is what lets a
%   later unit change stay lossless.
c = struct('seconds', double(seconds), ...
    'source_unit', 's', ...
    'source_value', double(seconds), ...
    'approximate', logical(approximate));
end

function s = charOf(v)
s = '';
if ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
end
end

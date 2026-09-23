function [hits, declined] = epochStrings(body)
%EPOCHSTRINGS Every did_v1 epoch-id STRING a document body carries, with its source.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB.
%   Nothing below has been run; the quick gate (test-migrators-quick.yml) is the
%   first thing that will have an opinion about it.
%
%   [HITS, DECLINED] = did2.validate.epochStrings(BODY) reads a document body
%   STRUCT -- did_v1 or migrated, it does not care -- and returns every epoch-id
%   string on it. HITS is a 1xN struct array {source, value}; DECLINED is the
%   same shape for strings this reader KNOWS ABOUT and deliberately does not
%   return (see "THE DECLINED SOURCE" below).
%
%   THIS IS THE ONE READER. It exists because there were three, they disagreed,
%   and the disagreements were invisible:
%
%     did2.validate.sourceCensus/epochIdOf     blocks named `epochid`/`epoch_id`
%                                              ONLY -- its own docstring was
%                                              corrected on 2026-08-10 after
%                                              crediting it with coverage it has
%                                              never had. `epochfiles_ingested`
%                                              contributed ZERO of corpus B's
%                                              6,207 documents / 149 distinct ids.
%     did2.convert.epochMint/epochStringOf     three sources, deliberately wider
%                                              than the census, and STILL blind to
%                                              the stimulus-response family.
%     each migrator                            reads its own block by hand.
%
%   A reader that silently omits a source produces a count that looks clean. The
%   fix is not a wider grep in one place: it is ONE function, with every source
%   NAMED, and the sources it refuses NAMED TOO so the omission is a number
%   rather than a silence.
%
%   ---------------------------------------------------------------------
%   THE SOURCES, EACH WITH THE EVIDENCE THAT IT IS A SOURCE
%   ---------------------------------------------------------------------
%   'epochid'
%       body.epochid.epochid -- the did_v1 mixin. 15 NDI classes carry the
%       `epochid` superclass and 11+ live NDI sites match `epochid.epochid` by
%       exact_string (CLAUDE.md, "A depends_on SWEEP IS NOT A REFERENCE CHECK").
%       The block is also read under its V_eta spelling `epoch_id`, and the
%       field under `epochid` / `epoch_id` / `epochId`.
%
%   'epochfiles_ingested'
%       body.epochfiles_ingested.epoch_id -- a PLAIN CHAR FIELD inside the
%       class's own block, which is why a reader that only visits blocks NAMED
%       `epochid` cannot see it:
%
%         git show origin/main:src/ndi/ndi_common/database_documents/ingestion/epochfiles_ingested.json
%            "epochfiles_ingested": { "epoch_id": "", "epochprobemap": "", ... }
%
%   'method_parameters'
%       body.method_parameters.other.epochid -- PARKED by
%       +migrators_j/private/jMethodParameters.m:120-127 precisely so a batch
%       pass can collect it. Present only on MIGRATED bodies.
%
%   'stimulus_response.element_epochid'          <- ADDED 2026-08-10
%   'stimulus_response.stimulator_epochid'       <- ADDED 2026-08-10
%       The stimulus-response family does NOT carry the `epochid` superclass, so
%       neither of the two readers above could ever see its epoch strings. From
%       the template:
%
%         git show origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_response.json
%            "superclasses": [ { ... base.json } ]
%            "stimulus_response": { "stimulator_epochid": [], "element_epochid": [] }
%         git show origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_response_scalar.json
%            "superclasses": [ { ... base.json }, { ... stimulus_response.json } ]
%
%       -- base + stimulus_response, no `epochid`. And from the WRITER, which is
%       what decides where template and writer disagree:
%
%         git show origin/main:src/ndi/+ndi/+app/+stimulus/tuning_response.m
%           :241-243  stim_timeref = ndi.time.timereference(ndi_stim_obj, ...
%                         ndi.time.clocktype(presentation_time(1).clocktype), ...
%                         stim_doc.document_properties.epochid.epochid, 0);
%           :245-246  [ts_epoch_t0_out, ts_epoch_timeref, msg] = ...
%                         E.syncgraph.time_convert(stim_timeref, ..., ...
%                             ndi_timeseries_obj, ndi.time.clocktype('dev_local_time'));
%           :317-318  stimulus_response_struct = struct( ...
%                         'stimulator_epochid', stim_doc.document_properties.epochid.epochid, ...
%                         'element_epochid',    ts_epoch_timeref.epoch);
%
%       THEY ARE TWO DIFFERENT EPOCHS, not two spellings of one. `time_convert`
%       maps the STIMULATOR's epoch onto the RECORDING ELEMENT's epoch, so the
%       two strings coincide only when both devices happen to share an epoch id.
%       Both are returned; a caller minting `epoch` entities wants both, and a
%       caller anchoring the response wants `element_epochid` specifically.
%
%   ---------------------------------------------------------------------
%   THE DECLINED SOURCE, NAMED SO THE GAP IS A NUMBER
%   ---------------------------------------------------------------------
%   'syncrule_mapping.epochnode_a/_b'
%       `syncrule_mapping` carries an epoch id per ENDPOINT --
%       `epochnode_a.epoch_id` on a did_v1 body, and
%       `epochnode_a.time_reference.epoch_id` after +migrators_j/syncrule_mapping.m's
%       #58 passthrough reshape. These are REAL epoch strings (5,316 documents in
%       the last measured census) and reading them would mint `epoch` entities for
%       them.
%
%       They are RETURNED IN `DECLINED`, NOT IN `HITS`, and that is a scope
%       decision rather than a judgement that they do not matter: turning them on
%       changes what `did2.convert.epochMint` mints on three corpora, and
%       `syncrule_mapping`'s own gate (`epoch_id_1` / `epoch_id_2`, NOT a bare
%       `epoch_id`) needs a per-endpoint answer this function's flat return shape
%       does not give. Counting them here means the day someone asks "why is the
%       sync family still unanchored" the report already has the number.
%       OPEN QUESTION for the team; see the notes returned to the caller.
%
%   ---------------------------------------------------------------------
%   WHAT IT DOES NOT DO
%   ---------------------------------------------------------------------
%   No de-duplication, no ordering guarantee beyond the declaration order above,
%   no session key. A (session, string) pair is the mint key -- NEVER the string
%   alone, because 142 of corpus B's 149 distinct ids are carried by documents in
%   more than one session -- and the session id is on `base`, which is the
%   caller's business, not this reader's.
%
%   See also: did2.convert.epochMint, did2.validate.epochStringRetention,
%   did2.validate.sourceCensus.

arguments
    body
end

hits     = struct('source', {}, 'value', {});
declined = struct('source', {}, 'value', {});

if ~isstruct(body) || ~isscalar(body)
    return;
end

% ---- 1. the did_v1 `epochid` mixin ---------------------------------------
for blk = {'epochid', 'epoch_id'}
    if ~isfield(body, blk{1}) || ~isstruct(body.(blk{1})) ...
            || ~isscalar(body.(blk{1}))
        continue;
    end
    v = charField(body.(blk{1}), {'epochid', 'epoch_id', 'epochId'});
    if ~isempty(v)
        hits(end+1) = struct('source', 'epochid', 'value', v); %#ok<AGROW>
        break;   % one mixin block per document; the two names are spellings
    end
end

% ---- 2. the ingestion manifest's own block --------------------------------
if isfield(body, 'epochfiles_ingested') && isstruct(body.epochfiles_ingested) ...
        && isscalar(body.epochfiles_ingested)
    v = charField(body.epochfiles_ingested, {'epoch_id', 'epochid', 'epochId'});
    if ~isempty(v)
        hits(end+1) = struct('source', 'epochfiles_ingested', 'value', v);
    end
end

% ---- 3. the parked string on a migrated method_parameters -----------------
if isfield(body, 'method_parameters') && isstruct(body.method_parameters) ...
        && isscalar(body.method_parameters) ...
        && isfield(body.method_parameters, 'other') ...
        && isstruct(body.method_parameters.other) ...
        && isscalar(body.method_parameters.other)
    v = charField(body.method_parameters.other, {'epochid', 'epoch_id'});
    if ~isempty(v)
        hits(end+1) = struct('source', 'method_parameters', 'value', v);
    end
end

% ---- 4/5. the stimulus-response family ------------------------------------
% Read snake-first with a camelCase fallback, per the standing migrator lesson:
% did2.convert.universalRenames snake_cases the IMMEDIATE fields of a property
% block, so `element_epochid` is already snake on a converted body -- but these
% are single lowercase words joined without separators (`element_epochid`), which
% the renamer leaves ALONE, so the raw v1 spelling is the same string. The
% fallbacks are for a body that never went through universalRenames.
if isfield(body, 'stimulus_response') && isstruct(body.stimulus_response) ...
        && isscalar(body.stimulus_response)
    sr = body.stimulus_response;
    v = charField(sr, {'element_epochid', 'elementEpochid', 'element_epoch_id'});
    if ~isempty(v)
        hits(end+1) = struct('source', 'stimulus_response.element_epochid', ...
            'value', v);
    end
    v = charField(sr, {'stimulator_epochid', 'stimulatorEpochid', ...
        'stimulator_epoch_id'});
    if ~isempty(v)
        hits(end+1) = struct('source', 'stimulus_response.stimulator_epochid', ...
            'value', v);
    end
end

% ---- DECLINED: the sync endpoints ----------------------------------------
if isfield(body, 'syncrule_mapping') && isstruct(body.syncrule_mapping) ...
        && isscalar(body.syncrule_mapping)
    sm = body.syncrule_mapping;
    for nd = {'epochnode_a', 'epochNodeA'; 'epochnode_b', 'epochNodeB'}'
        % nd is a 2x1 cell column: {snake; camel} for one endpoint.
        node = [];
        for j = 1:numel(nd)
            if isfield(sm, nd{j}) && isstruct(sm.(nd{j})) && isscalar(sm.(nd{j}))
                node = sm.(nd{j});
                break;
            end
        end
        if isempty(node); continue; end
        v = charField(node, {'epoch_id', 'epochId', 'epochID', 'epochid'});
        if isempty(v) && isfield(node, 'time_reference') ...
                && isstruct(node.time_reference) && isscalar(node.time_reference)
            % the #58 passthrough reshape nests it one level down
            v = charField(node.time_reference, {'epoch_id', 'epochId', 'epochid'});
        end
        if ~isempty(v)
            declined(end+1) = struct('source', 'syncrule_mapping.epochnode', ...
                'value', v); %#ok<AGROW>
        end
    end
end
end

% ===================== helpers =========================================

function v = charField(s, names)
%CHARFIELD First present, non-empty, char-like field among NAMES.
v = '';
for k = 1:numel(names)
    if ~isfield(s, names{k}); continue; end
    x = s.(names{k});
    if (ischar(x) || (isstring(x) && isscalar(x))) && ~isempty(char(x))
        v = char(x);
        return;
    end
end
end

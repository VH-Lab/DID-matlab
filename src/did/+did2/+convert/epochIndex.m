classdef epochIndex < handle
%EPOCHINDEX (session, epoch-string) -> the minted `epoch` document id. ONE RESOLVER.
%
%   STATUS: WRITTEN 2026-08-11 IN A CONTAINER WITH NO MATLAB AND NO OCTAVE
%   (`command -v matlab octave octave-cli` prints nothing and exits 1). NOT ONE
%   LINE BELOW HAS BEEN RUN HERE. test-migrators-quick.yml is the first thing
%   that will have an opinion about it; read it as a specification, and the CI
%   run ids as the only durable evidence.
%
%   IDX = did2.convert.epochIndex(RESULT) builds the index from the struct
%   did2.convert.epochMint returns, and
%
%       [epochDocumentId, why] = IDX.resolve(sessionId, localIdentifier)
%
%   is the mechanism open item #60's item 2 asks for: a carrier's
%   `epochid.epochid` STRING turned into the id of the `epoch` DOCUMENT the mint
%   created. `why` is '' on a hit and names the refusal on a miss. Every call is
%   counted in IDX.report.
%
%   ---------------------------------------------------------------------
%   WHY THIS FILE EXISTS: THERE WERE ALREADY THREE COPIES
%   ---------------------------------------------------------------------
%   The (session, string) -> epoch id lookup is hand-rolled, identically and
%   independently, in three places today:
%
%     did2.convert.epochMint            `epochIdByKey` + a local `pairKey`
%     did2.convert.resolveValidIntervals `epochIdByKey`/`epochCountByKey` + a
%                                        local `pairKey` whose comment says
%                                        "Identical to did2.convert.epochMint/
%                                        pairKey ON PURPOSE"
%     did2.validate.epochStringRetention a local `pairKey`, same body again
%
%   That is the shape of a defect this toolbox has already paid for once, one
%   level down: there were THREE epoch-string READERS, each with a different
%   blind spot, and the disagreements were invisible until they were
%   consolidated into did2.validate.epochStrings. A fourth copy written for the
%   #60 rewire would have been the fourth chance for the copies to disagree
%   about what a key means, and a key that differs between the writer and the
%   reader resolves to nothing while looking like a data problem.
%
%   THIS FILE ADDS NO FOURTH COPY AND REMOVES NONE OF THE THREE. Removing them
%   is a refactor of two live batch passes that cannot be executed in this
%   container; it is reported as follow-up rather than done blind. What this
%   file does provide is the ONE implementation any NEW consumer must use, and
%   `testEpochIndex` pins it against `did2.convert.epochMint`'s real output so
%   the two cannot drift silently.
%
%   ---------------------------------------------------------------------
%   THE KEY IS THE PAIR. HALF A KEY RESOLVES TO NOTHING, NEVER TO A GUESS.
%   ---------------------------------------------------------------------
%   MEASURED, corpus run 31415147934 (`02854c7`, 2026-08-10),
%   did2.validate.sourceCensus over 6 corpora / 221,827 v1 documents:
%   an `epochid.epochid` string is REUSED ACROSS SESSIONS -- 142 of corpus B's
%   149 distinct ids, 142 of Dab's 1,754, 12 of Soph's 18. Corpus run
%   31508009545 then measured the same fact from the mint side: 51,173 epoch
%   strings, 8,433 distinct (session, id) PAIRS, and 2,344 epochs that the
%   string key alone would have FUSED.
%
%   So:
%     * an empty session id           -> '' and `refused_no_session_id`
%     * an empty local identifier     -> '' and `refused_no_local_identifier`
%     * a pair with no epoch document -> '' and `refused_no_epoch_document`
%     * a pair claimed by TWO epochs  -> '' and `refused_ambiguous_epoch`
%
%   and, on the BODY-reading path, two more that are deliberately NOT one
%   counter -- "this document has no epoch string" and "this document has an
%   epoch string, just not from the source you named" are different defects
%   with different owners, and the second is the wrong-epoch hazard rather than
%   an absence:
%     * no epoch string anywhere      -> '' and `refused_no_epoch_string`
%     * none from the NAMED source    -> '' and `refused_source_not_present`
%
%   None of the four falls back to a string-only lookup. Resolving half a key by
%   matching on the other half is how 2,344 epochs from different sessions --
%   different animals -- become one.
%
%   `report.pairs_minus_strings` is that number for the batch in hand:
%   `pairs_indexed` minus `distinct_local_identifiers`. An implementation that
%   started keying on the string would drive it to 0, which is why it is
%   reported rather than merely commented.
%
%   ---------------------------------------------------------------------
%   IT NEVER INVENTS AN EDGE. THE SCHEMA DECIDES, NOT THE CALLER.
%   ---------------------------------------------------------------------
%   `stampEpochEdge` REFUSES to write `epoch_id` onto a body whose class does
%   not DECLARE that dependency, and it reads the declaration out of the schema
%   cache rather than a list kept here. Measured over the built V_eta set
%   (245 schema files, superclass chains walked, 2026-08-11) exactly FOUR
%   classes declare it:
%
%       acquisition_metadata_file   mustBeNonEmpty  -> epoch
%       ingestion_manifest          mustBeNonEmpty  -> epoch
%       directed_relation           optional        -> epoch
%       method_parameters           optional        -> epoch
%
%   -- against NINETEEN did_v1 classes that inherit the `epochid` superclass
%   (15 directly, plus daqreader_image_/mfdaq_epochdata_ingested, oneepoch and
%   pyraview transitively). Stamping the other fifteen is not a smaller version
%   of the rewire; it is the invented-edge pattern with the sign flipped, and
%   `+did2/+validate/references.m:90` skips empty edges, so the result would
%   validate clean and no gate would see it. The refusal is COUNTED
%   (`stamp_refused_class_does_not_declare`) so the size of the gap is a number
%   in the report instead of an omission.
%
%   `scanCarriers` is the same question asked of a whole batch without writing
%   anything: how many documents carry an epoch string, how many of those belong
%   to a class that could hold the edge, and how many of those would resolve.
%
%   ---------------------------------------------------------------------
%   THE BATCH IS THE AUTHORITY; THE PUBLISHED INDEX IS CROSS-CHECKED
%   ---------------------------------------------------------------------
%   `did2.convert.epochMint` publishes `result.epoch_mint.epoch_index`, and
%   `did2.convert.resolveValidIntervals` deliberately ignores it in favour of
%   reading the `epoch` documents out of `result.migrated`, for a good reason it
%   states: "one source of truth (the batch) cannot drift from itself".
%
%   The cost of that choice is that NOTHING has ever checked the published index
%   against the batch. This class reads BOTH: the batch is authoritative and is
%   what `resolve` answers from, and the published rows are compared row by row
%   into `published_rows_agreeing` / `_only_published` / `_only_batch` /
%   `_disagreeing`. A published index that has gone stale -- e.g. one naming an
%   epoch that failed validation and never reached `result.migrated` -- becomes
%   a number rather than a silent difference between two consumers.
%
%   ---------------------------------------------------------------------
%   ORDERING: THIS IS USELESS BEFORE did2.convert.epochMint
%   ---------------------------------------------------------------------
%   No `epoch` document exists until the mint runs (runCorpusDiscovery.m:137).
%   `did2.validate.silentLoss` is called exactly once, from v1_to_v2.m:382, i.e.
%   in PASS 1 -- so anything measured there sees a pre-mint world and a zero
%   there is a property of WHEN it ran (commit 203c1f7). An index built on a
%   pre-mint batch reports `epoch_documents_seen = 0` and `vacuous = true`, and
%   every resolve against it refuses with `refused_no_epoch_document`. That is
%   the correct answer, but it is NOT evidence that the strings do not resolve;
%   `vacuous` is in the report so the two readings cannot be confused.
%
%   Options (name-value):
%     SchemaCache   ([] or a did2.schema.cache)  override the shared cache. When
%                   [] the cache is resolved LAZILY, on the first question that
%                   needs it, so an index can be built and resolved against in a
%                   context with no schema path configured.
%
%   See also: did2.convert.epochMint, did2.convert.resolveValidIntervals,
%   did2.validate.epochStrings, did2.validate.epochStringRetention,
%   did2.convert.migrators_j.private.jEpochDocId.

    properties (SetAccess = private)
        % REPORT Denominators first, unconditionally. Every field is defined
        %   before a document is read, so "did not run" and "ran and found
        %   nothing" are different readings of the same struct rather than the
        %   same reading. That distinction is what `silentLoss` lacked while it
        %   measured nothing for two days.
        report
    end

    properties (Access = private)
        idByKey        % containers.Map pairKey -> epoch document id
        countByKey     % containers.Map pairKey -> how many epoch docs claim it
        declaresByClass % containers.Map className -> logical (memoised)
        schemaCache = []
    end

    methods
        function obj = epochIndex(source, options)
            arguments
                source = []
                options.SchemaCache = []
            end
            obj.schemaCache = options.SchemaCache;
            obj.idByKey    = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.countByKey = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.declaresByClass = containers.Map('KeyType', 'char', ...
                'ValueType', 'logical');
            obj.report = did2.convert.epochIndex.blankReport();
            % `[]` -- and ONLY numeric [] -- means "no source given": the index
            % is empty, `ran` stays FALSE and `vacuous` stays true. An empty
            % BATCH (`{}` or a result struct with `migrated = {}`) is a
            % different thing and is built: `ran` TRUE with every counter 0.
            % "Did not run" and "ran and found nothing" must not read the same.
            if isnumeric(source) && isempty(source)
                return;
            end
            obj.build(source);
        end

        function [epochDocumentId, why] = resolve(obj, sessionId, localIdentifier)
            %RESOLVE The `epoch` document id for one (session, epoch-string) PAIR.
            %   Returns '' and a named refusal for anything else. NEVER falls
            %   back to a string-only lookup -- see the class header.
            arguments
                obj
                sessionId
                localIdentifier
            end
            epochDocumentId = '';
            why = '';
            obj.report.resolve_calls = obj.report.resolve_calls + 1;
            sid = did2.convert.epochIndex.charOf(sessionId);
            lid = did2.convert.epochIndex.charOf(localIdentifier);
            % HALF A KEY IS NOT A KEY. Both halves are checked before the map is
            % consulted, and the two refusals are SEPARATE counters: "the
            % document has no session" and "the document has no epoch string"
            % are different defects with different owners.
            if isempty(sid)
                why = 'refused_no_session_id';
                obj.bumpRefusal(why);
                return;
            end
            if isempty(lid)
                why = 'refused_no_local_identifier';
                obj.bumpRefusal(why);
                return;
            end
            key = did2.convert.epochIndex.pairKey(sid, lid);
            if ~isKey(obj.idByKey, key)
                why = 'refused_no_epoch_document';
                obj.bumpRefusal(why);
                return;
            end
            if obj.countByKey(key) > 1
                % Guessing which of two epoch documents is meant is the quiet
                % decision that produces a graph nobody can audit later --
                % epochMint refuses the mirror-image case for the same reason.
                why = 'refused_ambiguous_epoch';
                obj.bumpRefusal(why);
                return;
            end
            epochDocumentId = obj.idByKey(key);
            obj.report.resolve_hits = obj.report.resolve_hits + 1;
        end

        function [epochDocumentId, why, epochString] = resolveBody(obj, body, sourceName)
            %RESOLVEBODY Resolve a document BODY through did2.validate.epochStrings.
            %   SOURCENAME (optional) selects ONE named reader source -- e.g.
            %   'epochid' for the did_v1 mixin, 'method_parameters' for the
            %   string jMethodParameters parks. Omit it and the FIRST hit is
            %   used.
            %
            %   NAMING THE SOURCE MATTERS AND IS NOT PEDANTRY. A document may
            %   carry SEVERAL epoch strings naming DIFFERENT epochs:
            %   `stimulus_response.stimulator_epochid` is the stimulator's epoch
            %   and `.element_epochid` is the recording element's, mapped onto
            %   each other by syncgraph.time_convert. Taking "whichever string
            %   this body has" would resolve to the wrong epoch roughly half the
            %   time on that family, silently.
            arguments
                obj
                body
                sourceName (1,:) char = ''
            end
            % `why` is deliberately NOT pre-initialised: EVERY path out of this
            % function assigns it (the three refusals below, and the delegation
            % to `resolve` at the end, which assigns on both its own paths). A
            % future path that forgets must fail LOUDLY -- MATLAB's "output
            % argument 'why' not assigned" -- rather than silently return ''
            % and read as a success. Note that `resolve` is the OPPOSITE case:
            % its `why = ''` IS load-bearing, because its success path assigns
            % only `epochDocumentId`. Do not apply one rule to both.
            epochDocumentId = '';
            epochString = '';
            b = did2.convert.epochIndex.bodyOf(body);
            if isempty(b)
                why = 'refused_unreadable_body';
                obj.bumpRefusal(why);
                return;
            end
            hits = did2.validate.epochStrings(b);
            if isempty(hits)
                % THE DOCUMENT CARRIES NO EPOCH STRING AT ALL.
                why = 'refused_no_epoch_string';
                obj.bumpRefusal(why);
                return;
            end
            if isempty(sourceName)
                epochString = hits(1).value;
            else
                for k = 1:numel(hits)
                    if strcmp(hits(k).source, sourceName)
                        epochString = hits(k).value;
                        break;
                    end
                end
                if isempty(epochString)
                    % A DIFFERENT FACT, AND IT GETS A DIFFERENT COUNTER. The
                    % document DOES carry an epoch string -- just not from the
                    % source the caller named. Folding this into
                    % `refused_no_epoch_string` would report "nothing to
                    % resolve" when the truth is "it has an epoch and we asked
                    % for a source it does not carry", which is precisely the
                    % wrong-epoch hazard this method's `sourceName` exists to
                    % prevent, made invisible in the report instead of counted.
                    % Live case: `stimulus_response` carries `element_epochid`
                    % AND `stimulator_epochid` and they name DIFFERENT epochs,
                    % so a document with only one of the two is a real and
                    % recurring shape, not a contrivance.
                    why = 'refused_source_not_present';
                    obj.bumpRefusal(why);
                    return;
                end
            end
            [epochDocumentId, why] = obj.resolve( ...
                did2.convert.epochIndex.baseField(b, 'session_id'), epochString);
        end

        function tf = classDeclaresEpochEdge(obj, className)
            %CLASSDECLARESEPOCHEDGE Does CLASSNAME declare an `epoch_id` dependency?
            %   Read off the SCHEMA, walking the superclass chain -- not off a
            %   list kept in this file, which is how a list goes stale the first
            %   time a class gains the edge. An unknown class, or no schema
            %   cache at all, answers FALSE: "we could not check" must not
            %   authorise a write.
            arguments
                obj
                className (1,:) char
            end
            tf = false;
            if isempty(className); return; end
            if isKey(obj.declaresByClass, className)
                tf = obj.declaresByClass(className);
                return;
            end
            c = obj.cache();
            if isempty(c)
                obj.report.schema_lookups_unavailable = ...
                    obj.report.schema_lookups_unavailable + 1;
                return;     % NOT memoised: a cache may appear later.
            end
            try
                chain = c.classChain(className);
            catch
                obj.report.schema_lookups_failed = ...
                    obj.report.schema_lookups_failed + 1;
                obj.declaresByClass(className) = false;
                return;
            end
            for k = 1:numel(chain)
                try
                    s = c.getClass(chain{k});
                catch
                    continue;
                end
                if ~isstruct(s) || ~isfield(s, 'depends_on'); continue; end
                deps = s.depends_on;
                % jsondecode returns a CELL whenever the dependency objects in
                % one class do not all carry the same keys, and `[deps{:}]`
                % throws on mismatched fieldnames -- the same trap
                % did2.schema.cache/requiredDependencies documents. Iterate
                % element-wise.
                if isstruct(deps)
                    items = num2cell(deps(:)');
                elseif iscell(deps)
                    items = deps(:)';
                else
                    continue;
                end
                for d = 1:numel(items)
                    dep = items{d};
                    if isstruct(dep) && isfield(dep, 'name') ...
                            && strcmp(char(dep.name), 'epoch_id')
                        tf = true;
                        break;
                    end
                end
                if tf; break; end
            end
            obj.declaresByClass(className) = tf;
        end

        function [body, why] = stampEpochEdge(obj, body, sourceName)
            %STAMPEPOCHEDGE Write `epoch_id` onto BODY, or refuse and say why.
            %   Returns BODY UNCHANGED -- the same value that was passed in,
            %   whatever its type -- on every refusal, so a caller that ignores
            %   `why` cannot accidentally emit a half-written document. On a
            %   WRITE it returns the body as a STRUCT, which is the shape every
            %   batch pass hands to did2.convert.v1_to_v2 for the re-fold.
            %
            %   FIVE REFUSALS, ALL COUNTED (the last two arrive from
            %   `resolveBody` and are kept apart there for the reason it gives):
            %     the class does not declare `epoch_id`  -> the invented-edge
            %       pattern with the sign flipped; the schema is the authority
            %     the edge is already populated          -> find-or-create, not
            %       create; ndi.migrate.local re-reads every document on a
            %       second pass over the same dataset
            %     the body carries no epoch string       -> nothing to resolve
            %     the pair does not resolve              -> `resolve`'s own
            %       refusal, propagated verbatim
            arguments
                obj
                body
                sourceName (1,:) char = ''
            end
            why = '';
            obj.report.stamp_calls = obj.report.stamp_calls + 1;
            b = did2.convert.epochIndex.bodyOf(body);
            if isempty(b)
                why = 'refused_unreadable_body';
                obj.report.stamp_refused_unreadable_body = ...
                    obj.report.stamp_refused_unreadable_body + 1;
                return;
            end
            className = did2.convert.epochIndex.classNameOf(b);
            if ~obj.classDeclaresEpochEdge(className)
                why = 'refused_class_does_not_declare';
                obj.report.stamp_refused_class_does_not_declare = ...
                    obj.report.stamp_refused_class_does_not_declare + 1;
                return;
            end
            if ~isempty(did2.convert.epochIndex.depValueOf(b, 'epoch_id'))
                why = 'refused_already_populated';
                obj.report.stamp_refused_already_populated = ...
                    obj.report.stamp_refused_already_populated + 1;
                return;
            end
            [epochDocumentId, resolveWhy] = obj.resolveBody(b, sourceName);
            if isempty(epochDocumentId)
                why = resolveWhy;
                obj.report.stamp_refused_unresolved = ...
                    obj.report.stamp_refused_unresolved + 1;
                return;
            end
            body = did2.convert.epochIndex.setDep(b, 'epoch_id', epochDocumentId);
            obj.report.stamp_edges_written = obj.report.stamp_edges_written + 1;
        end

        function rep = scanCarriers(obj, source)
            %SCANCARRIERS Measure the 19 -> 4 gap over a batch. WRITES NOTHING.
            %   For every document carrying an epoch string: does its class
            %   declare `epoch_id`, and if it does, would the pair resolve? The
            %   answer for the did_v1 carriers is expected to be "the class does
            %   not declare the edge", and the point of the counter is that the
            %   expectation becomes a measured number per corpus rather than a
            %   sentence in a plan document.
            %
            %   `carriers_by_class_without_edge` names the classes, so the
            %   remaining schema work in #60 is read off a run instead of
            %   re-derived by hand.
            arguments
                obj
                source
            end
            [bodies, unreadable] = did2.convert.epochIndex.bodiesOf(source);
            obj.report.carrier_scan_ran = true;
            obj.report.carriers_inspected = numel(bodies) + unreadable;
            obj.report.carriers_unreadable = unreadable;
            byClass = struct();
            for k = 1:numel(bodies)
                b = bodies{k};
                hits = did2.validate.epochStrings(b);
                if isempty(hits); continue; end
                obj.report.carriers_with_epoch_string = ...
                    obj.report.carriers_with_epoch_string + 1;
                cn = did2.convert.epochIndex.classNameOf(b);
                if ~obj.classDeclaresEpochEdge(cn)
                    obj.report.carriers_class_does_not_declare_edge = ...
                        obj.report.carriers_class_does_not_declare_edge + 1;
                    fn = matlab.lang.makeValidName(cn);
                    if isfield(byClass, fn)
                        byClass.(fn) = byClass.(fn) + 1;
                    else
                        byClass.(fn) = 1;
                    end
                    continue;
                end
                obj.report.carriers_class_declares_edge = ...
                    obj.report.carriers_class_declares_edge + 1;
                if ~isempty(did2.convert.epochIndex.depValueOf(b, 'epoch_id'))
                    obj.report.carriers_edge_already_populated = ...
                        obj.report.carriers_edge_already_populated + 1;
                    continue;
                end
                sid = did2.convert.epochIndex.baseField(b, 'session_id');
                resolved = false;
                for j = 1:numel(hits)
                    if ~isempty(obj.resolve(sid, hits(j).value))
                        resolved = true;
                        break;
                    end
                end
                if resolved
                    obj.report.carriers_resolvable = ...
                        obj.report.carriers_resolvable + 1;
                else
                    obj.report.carriers_unresolvable = ...
                        obj.report.carriers_unresolvable + 1;
                end
            end
            obj.report.carriers_by_class_without_edge = byClass;
            rep = obj.report;
        end
    end

    methods (Access = private)
        function build(obj, source)
            %BUILD Index the `epoch` documents in the batch, then cross-check
            %   the published `epoch_index` against them.
            published = [];
            batchSource = source;
            if isstruct(source) && isscalar(source) && isfield(source, 'migrated')
                batchSource = source.migrated;
                if isfield(source, 'epoch_mint') && isstruct(source.epoch_mint) ...
                        && isfield(source.epoch_mint, 'epoch_index')
                    published = source.epoch_mint.epoch_index;
                    obj.report.published_index_present = true;
                end
            end
            [bodies, unreadable] = did2.convert.epochIndex.bodiesOf(batchSource);
            obj.report.ran = true;
            obj.report.bodies_inspected  = numel(bodies) + unreadable;
            obj.report.bodies_unreadable = unreadable;

            localIds = {};
            for k = 1:numel(bodies)
                b = bodies{k};
                if ~strcmp(did2.convert.epochIndex.classNameOf(b), 'epoch'); continue; end
                obj.report.epoch_documents_seen = obj.report.epoch_documents_seen + 1;
                docId = did2.convert.epochIndex.baseField(b, 'id');
                sid   = did2.convert.epochIndex.baseField(b, 'session_id');
                lid   = '';
                if isfield(b, 'epoch') && isstruct(b.epoch) && isscalar(b.epoch)
                    lid = did2.convert.epochIndex.charField(b.epoch, ...
                        {'local_identifier'});
                end
                % An epoch document that cannot key itself is COUNTED, never
                % dropped silently -- it is an epoch nothing will ever anchor
                % to, which is a defect in whatever minted it.
                if isempty(lid)
                    obj.report.epoch_documents_without_local_identifier = ...
                        obj.report.epoch_documents_without_local_identifier + 1;
                    continue;
                end
                if isempty(sid)
                    obj.report.epoch_documents_without_session_id = ...
                        obj.report.epoch_documents_without_session_id + 1;
                    continue;
                end
                if isempty(docId)
                    obj.report.epoch_documents_without_id = ...
                        obj.report.epoch_documents_without_id + 1;
                    continue;
                end
                localIds{end+1} = lid; %#ok<AGROW>
                key = did2.convert.epochIndex.pairKey(sid, lid);
                if isKey(obj.countByKey, key)
                    obj.countByKey(key) = obj.countByKey(key) + 1;
                else
                    obj.countByKey(key) = 1;
                    obj.idByKey(key) = docId;
                end
            end
            % `.Count` returns UINT64 and uint64 arithmetic SATURATES, so a
            % subtraction done on it can never go negative -- a day when the
            % string count exceeded the pair count (which would mean the key or
            % the reader is broken) would report a reassuring 0 instead of a
            % negative number. double() first. Same trap epochMint documents.
            obj.report.pairs_indexed = double(obj.idByKey.Count);
            counts = values(obj.countByKey);
            for k = 1:numel(counts)
                if counts{k} > 1
                    obj.report.pairs_ambiguous = obj.report.pairs_ambiguous + 1;
                end
            end
            if isempty(localIds)
                obj.report.distinct_local_identifiers = 0;
            else
                obj.report.distinct_local_identifiers = numel(unique(localIds));
            end
            % THE MEASUREMENT THE PAIR KEY EXISTS FOR. Keying on the string
            % alone would produce `distinct_local_identifiers` groups; keying on
            % the pair produces `pairs_indexed`. The difference is the number of
            % epochs a string-only key would have FUSED -- 2,344 across the six
            % corpora, measured, not predicted.
            obj.report.pairs_minus_strings = ...
                obj.report.pairs_indexed - obj.report.distinct_local_identifiers;
            obj.report.vacuous = (obj.report.pairs_indexed == 0);

            obj.crossCheckPublished(published);
        end

        function crossCheckPublished(obj, published)
            %CROSSCHECKPUBLISHED Compare epochMint's published rows to the batch.
            %   The BATCH WINS -- `resolve` answers from it, for the reason
            %   resolveValidIntervals gives. This only measures the difference,
            %   which nothing has ever done.
            if isempty(published) || ~isstruct(published); return; end
            obj.report.published_index_rows = numel(published);
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for k = 1:numel(published)
                row = published(k);
                sid = '';
                lid = '';
                pid = '';
                if isfield(row, 'session_id');        sid = did2.convert.epochIndex.charOf(row.session_id); end
                if isfield(row, 'local_identifier');  lid = did2.convert.epochIndex.charOf(row.local_identifier); end
                if isfield(row, 'epoch_document_id'); pid = did2.convert.epochIndex.charOf(row.epoch_document_id); end
                if isempty(sid) || isempty(lid)
                    obj.report.published_rows_unkeyable = ...
                        obj.report.published_rows_unkeyable + 1;
                    continue;
                end
                key = did2.convert.epochIndex.pairKey(sid, lid);
                seen(key) = true;
                if ~isKey(obj.idByKey, key)
                    obj.report.published_rows_only_published = ...
                        obj.report.published_rows_only_published + 1;
                elseif strcmp(obj.idByKey(key), pid)
                    obj.report.published_rows_agreeing = ...
                        obj.report.published_rows_agreeing + 1;
                else
                    obj.report.published_rows_disagreeing = ...
                        obj.report.published_rows_disagreeing + 1;
                end
            end
            allKeys = keys(obj.idByKey);
            for k = 1:numel(allKeys)
                if ~isKey(seen, allKeys{k})
                    obj.report.published_rows_only_batch = ...
                        obj.report.published_rows_only_batch + 1;
                end
            end
        end

        function bumpRefusal(obj, why)
            obj.report.(why) = obj.report.(why) + 1;
            obj.report.refused_total = obj.report.refused_total + 1;
        end

        function c = cache(obj)
            %CACHE The schema cache, resolved LAZILY and never fatally.
            c = obj.schemaCache;
            if ~isempty(c); return; end
            try
                c = did2.schema.cache.shared();
            catch
                c = [];
            end
            obj.schemaCache = c;
        end
    end

    methods (Static)
        function k = pairKey(sessionId, localIdentifier)
            %PAIRKEY The mint key, length-prefixed so no separator can be forged.
            %   `[sessionId '|' localIdentifier]` would let a session id ending
            %   in '|' collide with another pair. Cheap to prevent, expensive to
            %   notice. Byte-identical to did2.convert.epochMint/pairKey,
            %   did2.convert.resolveValidIntervals/pairKey and
            %   did2.validate.epochStringRetention/pairKey -- testEpochIndex
            %   pins this against epochMint's real output so the four cannot
            %   drift apart in silence.
            k = sprintf('%d:%s|%s', numel(sessionId), sessionId, localIdentifier);
        end

        function report = blankReport()
            %BLANKREPORT Every counter, defined before anything is read.
            report = struct( ...
                'ran',                                     false, ...
                'vacuous',                                 true, ...
                'bodies_inspected',                        0, ...
                'bodies_unreadable',                       0, ...
                'epoch_documents_seen',                    0, ...
                'epoch_documents_without_local_identifier', 0, ...
                'epoch_documents_without_session_id',      0, ...
                'epoch_documents_without_id',              0, ...
                'pairs_indexed',                           0, ...
                'pairs_ambiguous',                         0, ...
                'distinct_local_identifiers',              0, ...
                'pairs_minus_strings',                     0, ...
                'published_index_present',                 false, ...
                'published_index_rows',                    0, ...
                'published_rows_agreeing',                 0, ...
                'published_rows_disagreeing',              0, ...
                'published_rows_only_published',           0, ...
                'published_rows_only_batch',               0, ...
                'published_rows_unkeyable',                0, ...
                'resolve_calls',                           0, ...
                'resolve_hits',                            0, ...
                'refused_no_session_id',                   0, ...
                'refused_no_local_identifier',             0, ...
                'refused_no_epoch_document',               0, ...
                'refused_ambiguous_epoch',                 0, ...
                'refused_no_epoch_string',                 0, ...
                'refused_source_not_present',              0, ...
                'refused_unreadable_body',                 0, ...
                'refused_total',                           0, ...
                'stamp_calls',                             0, ...
                'stamp_edges_written',                     0, ...
                'stamp_refused_class_does_not_declare',    0, ...
                'stamp_refused_already_populated',         0, ...
                'stamp_refused_unresolved',                0, ...
                'stamp_refused_unreadable_body',           0, ...
                'schema_lookups_unavailable',              0, ...
                'schema_lookups_failed',                   0, ...
                'carrier_scan_ran',                        false, ...
                'carriers_inspected',                      0, ...
                'carriers_unreadable',                     0, ...
                'carriers_with_epoch_string',              0, ...
                'carriers_class_declares_edge',            0, ...
                'carriers_class_does_not_declare_edge',    0, ...
                'carriers_edge_already_populated',         0, ...
                'carriers_resolvable',                     0, ...
                'carriers_unresolvable',                   0, ...
                'carriers_by_class_without_edge',          struct());
        end
    end

    % THE HELPERS BELOW ARE PUBLIC STATIC ON PURPOSE, not from carelessness.
    % Two reasons. (1) They are the SAME readers the batch passes hand-roll --
    % `bodiesOf`/`bodyOf` carry vBodies' contract (unreadable documents are
    % COUNTED, never dropped) and `setDep`/`depValueOf` carry references.m's
    % three-spelling tolerance -- so a caller adopting this class should be able
    % to reach them instead of writing a fourth copy. (2) Private STATIC access
    % from a fully-qualified call inside the class is a rule this container
    % cannot execute a line of MATLAB to verify; public removes the question
    % entirely, at the cost of a wider surface and nothing else.
    methods (Static)
        function [bodies, unreadable] = bodiesOf(docs)
            %BODIESOF Cell of did2.document, cell of structs, or a struct array.
            %   Unreadable documents are COUNTED, never dropped -- the
            %   `silentLoss` failure (`total_docs=0` on all five corpora because
            %   every document was silently discarded) came from dropping them.
            bodies = {};
            unreadable = 0;
            if isempty(docs); return; end
            if iscell(docs)
                items = docs(:)';
            elseif isstruct(docs)
                items = num2cell(docs(:)');
            else
                items = arrayfun(@(x) {x}, docs(:)');
            end
            for k = 1:numel(items)
                b = did2.convert.epochIndex.bodyOf(items{k});
                if isempty(b)
                    unreadable = unreadable + 1;
                else
                    bodies{end+1} = b; %#ok<AGROW>
                end
            end
        end

        function s = bodyOf(d)
            %BODYOF The document body as a plain struct, or [] if unreadable.
            %   THE PROPERTY IS `documentProperties`. Asking for
            %   `document_properties` is what made every document read as []
            %   and the census measure nothing; the snake_case spellings stay
            %   as fallbacks for the older did.document shape, tried SECOND.
            s = [];
            if isstruct(d) && isscalar(d)
                s = d;
                return;
            end
            if isempty(d); return; end
            for prop = {'documentProperties', 'document_properties', 'body'}
                try
                    v = d.(prop{1});
                    if isstruct(v) && ~isempty(fieldnames(v))
                        s = v;
                        return;
                    end
                catch
                    % wrong shape for this accessor -- try the next
                end
            end
            try
                v = d.toStruct();
                if isstruct(v) && ~isempty(fieldnames(v)); s = v; end
            catch
                % not a did2.document either
            end
        end

        function cn = classNameOf(b)
            cn = '';
            if isfield(b, 'document_class') && isstruct(b.document_class) ...
                    && isscalar(b.document_class) ...
                    && isfield(b.document_class, 'class_name')
                cn = char(b.document_class.class_name);
            end
        end

        function v = baseField(b, name)
            v = '';
            if ~isfield(b, 'base') || ~isstruct(b.base) || ~isscalar(b.base) ...
                    || ~isfield(b.base, name)
                return;
            end
            v = did2.convert.epochIndex.charOf(b.base.(name));
        end

        function v = charField(s, names)
            v = '';
            for k = 1:numel(names)
                if ~isfield(s, names{k}); continue; end
                v = did2.convert.epochIndex.charOf(s.(names{k}));
                if ~isempty(v); return; end
            end
        end

        function v = charOf(x)
            v = '';
            if ischar(x)
                v = x;
            elseif isstring(x) && isscalar(x)
                v = char(x);
            end
        end

        function v = depValueOf(b, name)
            %DEPVALUEOF One depends_on value, '' when absent OR blank.
            %   Tolerant of all three key spellings, same precedence as
            %   +did2/+validate/references.m: a body a migrator built spells the
            %   target `value`, one that has been through universalRenames
            %   spells it `document_id`, an unconverted v1 body spells it `id`.
            v = '';
            if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
            deps = b.depends_on;
            if iscell(deps)
                items = deps(:)';
            elseif isstruct(deps)
                items = num2cell(deps(:)');
            else
                return;
            end
            for k = 1:numel(items)
                d = items{k};
                if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
                    continue;
                end
                for key = {'document_id', 'value', 'id'}
                    if isfield(d, key{1})
                        v = did2.convert.epochIndex.charOf(d.(key{1}));
                    end
                    if ~isempty(v); return; end
                end
                return;
            end
        end

        function b = setDep(b, name, value)
            %SETDEP Add or overwrite one depends_on entry on a body STRUCT.
            %   An EXISTING entry is updated in whichever keys it already has; a
            %   NEW entry is given the same key set as its neighbours, because a
            %   struct array cannot hold two field sets. On an empty
            %   `depends_on` the shape is `value`, which is the shape the
            %   v1_to_v2 re-fold is proven on.
            entry = struct('name', name, 'value', value);
            if ~isfield(b, 'depends_on') || isempty(b.depends_on)
                b.depends_on = entry;
                return;
            end
            deps = b.depends_on;
            if iscell(deps)
                for k = 1:numel(deps)
                    if isstruct(deps{k}) && isfield(deps{k}, 'name') ...
                            && strcmp(char(deps{k}.name), name)
                        deps{k} = entry;
                        b.depends_on = deps;
                        return;
                    end
                end
                deps{end+1} = entry;
                b.depends_on = deps;
                return;
            end
            for k = 1:numel(deps)
                if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
                    if isfield(deps, 'value');       deps(k).value = value; end
                    if isfield(deps, 'document_id'); deps(k).document_id = value; end
                    b.depends_on = deps;
                    return;
                end
            end
            fn = fieldnames(deps);
            newEntry = struct();
            for k = 1:numel(fn)
                switch fn{k}
                    case 'name';        newEntry.name = name;
                    case 'value';       newEntry.value = value;
                    case 'document_id'; newEntry.document_id = value;
                    otherwise;          newEntry.(fn{k}) = '';
                end
            end
            if ~isfield(newEntry, 'name'); newEntry.name = name; end
            b.depends_on = [deps(:)', newEntry];
        end
    end
end

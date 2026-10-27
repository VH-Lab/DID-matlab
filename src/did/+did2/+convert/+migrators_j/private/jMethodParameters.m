function bodies = jMethodParameters(preBody, entries, other, opts)
%JMETHODPARAMETERS Fold a did_v1 settings document 1 -> 1 (id + base.name
%   PRESERVED) into a V_eta `method_parameters` document, plus -- when the v1
%   `app` block names one -- the `software` ENTITY it configures.
%
%   TEAM-SIGN-OFF quoted in schemas/V_eta_method_parameters_plan.md, 2026-08-09:
%   the four settings classes fold into ONE generic `method_parameters` document
%   (id and `base.name` preserved; optional `software_id`, `subject_id`,
%   `epoch_id -> epoch`, and a `derived_from_id` self-edge carrying LINEAGE
%   only); the settings shape is a `parameter[]` entry modelled on the `axis`
%   entry, identity in a bound `variable`, with no `unit` field and no
%   `data_type` field; it keeps the field name `method_parameters` in BOTH mount
%   points; routing is per class -- a name and an id in the source means a
%   document.
%
%   All four sources qualify for the DOCUMENT route on v1's own evidence: they
%   have a base.id three templates point at and a base.name two apps query by
%   string.
%
%       git show origin/main:src/ndi/+ndi/+app/spikeextractor.m | sed -n 372p
%          extract_searchq = ndi.query('base.name','exact_string',extraction_parameters_name,'') & ...
%       git show origin/main:src/ndi/+ndi/+app/spikesorter.m | sed -n 373p
%          sorting_search = ndi.query('base.name','exact_string',sorting_parameters_name,'') & ...
%
%       git grep -n -E "extraction_parameters_id|sorting_parameters_id" origin/main -- '*.json'
%          .../spikeextractor/spike_extraction_parameters_modification.json:14
%          .../spikeextractor/spikewaves.json:15
%          .../spikesorter/spike_clusters.json:15  (sorting_parameters_id)
%          .../spikesorter/spike_clusters.json:23  (extraction_parameters_id)
%
%   Because base.id is preserved, all three inbound edges keep resolving -- the
%   same id-preserving mechanism the calculator fold uses, and for the same
%   reason (dissolving a referenced document is what cost 11,448 orphans).
%
%   ------------------------------------------------------------------
%   WHAT THIS EMITS, AND WHAT IT REFUSES TO EMIT
%   ------------------------------------------------------------------
%   depends_on, ALL FOUR OPTIONAL on the target schema and each written only
%   when it has a real referent -- never blank. An empty required edge is the
%   pattern that put thousands of documents into the silent-loss census while
%   validating clean (+did2/+validate/references.m:90 skips empty edges), so a
%   missing referent means the edge is OMITTED, not emitted hollow:
%
%     subject_id      <- v1 `element_id`. D2: element.m promotes an element to a
%                        `subject` with its id PRESERVED, so the edge resolves.
%     epoch_id        <- jEpochDocId(preBody), which answers '' for every did_v1
%                        document today by construction (no source carries the
%                        edge, and no migrator mints an `epoch`; open item #60).
%                        So this edge is omitted today and the v1 epoch SCOPE
%                        STRING is parked in `other.epochid` rather than dropped
%                        -- see below.
%     derived_from_id <- the caller's named v1 edge (extraction_parameters_id on
%                        spike_extraction_parameters_modification). LINEAGE
%                        ONLY: precedence comes from subject_id + epoch_id, not
%                        from this edge, and the variant carries a COMPLETE copy
%                        of every setting rather than a diff.
%     software_id     <- the `software` entity minted here from the v1 `app`
%                        block, so its referent is always in the same batch.
%
%   THE `app` BLOCK HAS NO OTHER HOME. `method_parameters` subclasses `base`
%   ONLY -- there is no `app` block on the target -- while every one of the four
%   v1 classes declares the `app` superclass and NDI populates it for real
%   (ndi.app/newdocument sets app.name/version/url/os/os_version/interpreter/
%   interpreter_version at src/ndi/+ndi/app.m:105-114). Rather than drop it:
%     - name + version + url  -> the `software` entity (R1, app -> software).
%     - os / os_version / interpreter / interpreter_version -> NO HOME on a
%       method, by design: [small unread settings] (1) (Jess Haley,
%       2026-10-26) -- the OS is where the settings were SAVED (ndi.app/
%       newdocument stamps every app document), not a property of the recipe;
%       V2 puts a run's OS and interpreter on the CALCULATION, and `method` is
%       NOT to gain OS or interpreter links. A document whose app block names
%       any of the four is CARRIED WHOLE AS V1 (they were dropped, reported,
%       until 2026-10-26).
%   When the app block names no software, or base.session_id is empty (a minted
%   entity could not satisfy base's required session_id and would quarantine the
%   whole source body), the WHOLE app block is parked in `other.app` instead and
%   no edge is written.
%
%   entries  1xN struct array of jParameterEntry rows (may be 0x0).
%   other    scalar struct: the undeclared long tail, kept whole.
%   opts.DerivedFromSrc  v1 depends_on name to carry into `derived_from_id`.
%
%   Shared helper for the Brainstorm-J (+migrators_j) method_parameters fold.

arguments
    preBody (1,1) struct
    entries   % a cell of parameter entries (did2.build.parameter), or a struct array
    other (1,1) struct
    % `char` without a size spec: the default '' is 0-by-0 and would fail a
    % `(1,:) char` constraint.
    opts.DerivedFromSrc char = ''
end

% did-schema #88 (V_eta_method_plan.md, Jess 2026-10-21): the standalone
% class `method_parameters` is `method` {name, term, parameters}, scoped by
% `entity_id` (`subject_id` before) and `epoch_id`, with `software_id`.
% ENTRIES are the mapped knobs. OTHER, the settings with no mapped entry
% (and, before #88, the parked epoch string and execution environment), has
% no block of its own on #88: each of its leaves becomes one more parameter
% (jParameterList), so nothing is dropped -- a CONSERVATIVE CHOICE, recorded.
% The run environment is not a method's (the software edge is): a document
% that states one is carried whole as v1 below ([small unread settings]). The
% epoch STRING is parked as a parameter named
% 'epochid' (text); did2.convert.epochMint stamps the `epoch_id` edge from it
% and removes the entry.
% [small unread settings] (1) (Jess Haley, 2026-10-26): an app block that names
% the OS or interpreter the settings were saved on carries the document whole
% as v1; `method` gains no OS or interpreter link.
envNamed = {};
if isfield(preBody, 'app') && isstruct(preBody.app) && isscalar(preBody.app)
    for f = {'os', 'os_version', 'interpreter', 'interpreter_version'}
        if ~isempty(jGetChar(preBody.app, f{1}))
            envNamed{end+1} = ['app.' f{1}]; %#ok<AGROW>
        end
    end
end
if ~isempty(envNamed)
    % carry-register: carry-002 carry-003 carry-004 carry-005 (by class: carryRowOf)
    did2.convert.reportNote('carried_as_v1', classNameOf(preBody), ...
        char(preBody.base.id), [carryRowOf(classNameOf(preBody)) 'unplaced: ' ...
        strjoin(envNamed, ', ')]);
    bodies = {preBody};
    return;
end
[software, softwareId, ~, appLeftover] = ...
    jSoftwareFromApp(preBody, 'RequireSession', true);
if ~isempty(fieldnames(appLeftover))
    % a raw v1 block (did2.convert.rawV1Classes) spells name / version as v1
    % does; the bag keeps the spelling the renamed path gave it (app_name /
    % app_version), so the switch changes no emitted parameter
    for f = {'name', 'version'}
        if isfield(appLeftover, f{1}) && ~isfield(appLeftover, ['app_' f{1}])
            appLeftover.(['app_' f{1}]) = appLeftover.(f{1});
            appLeftover = rmfield(appLeftover, f{1});
        end
    end
    other.app = appLeftover;
end
epochDocId = jEpochDocId(preBody);
epochString = '';
if isfield(preBody, 'epochid') && isstruct(preBody.epochid)
    epochString = jGetChar(preBody.epochid, 'epochid');
end
if isfield(other, 'epochid'); other = rmfield(other, 'epochid'); end
if isfield(other, 'execution_environment')
    other = rmfield(other, 'execution_environment');
end

params = {};
if iscell(entries)
    params = reshape(entries, 1, []);
elseif ~isempty(entries)
    params{end+1} = entries;
end
rest = jParameterList(other);
if ~isempty(rest)
    params{end+1} = rest;
end
if isempty(epochDocId) && ~isempty(epochString)
    params{end+1} = did2.build.parameter(jLabel('epochid'), 'Text', epochString);
end
f = struct();
nm = baseName(preBody);
if ~isempty(nm); f.name = nm; end
if ~isempty(params)
    f.parameters = did2.build.list(params{:});
end

edges = struct();
subjectId = firstDepValue(preBody, {'element_id', 'subject_id'});
if ~isempty(subjectId); edges.entity_id = subjectId; end
if ~isempty(epochDocId); edges.epoch_id = epochDocId; end
if ~isempty(opts.DerivedFromSrc)
    derivedId = firstDepValue(preBody, {opts.DerivedFromSrc});
    if ~isempty(derivedId)
        % a modification is a variant of the protocol it names (lineage only)
        edges.parent_id = derivedId;
    end
end
if ~isempty(softwareId); edges.software_id = softwareId; end
o = jOpts(preBody, 'Edges', edges, 'Id', char(preBody.base.id));
mp = did2.build.document('method', f, o{:});
bodies = [{mp}, software];
end

function tag = carryRowOf(cn)
%CARRYROWOF The carry register row of a settings document carried because its
%   app block names an OS or interpreter, as the note's leading tag ([carry
%   register], Jess Haley, 2026-10-26, did-schema
%   schemas/V_eta_carry_register.json); '' for a class the register has no row
%   for (tools/check_carry_citations.py lists such carries).
switch cn
    case 'sorting_parameters';                       tag = '[carry-002] ';
    case 'spike_extraction_parameters';              tag = '[carry-003] ';
    case 'spike_extraction_parameters_modification'; tag = '[carry-004] ';
    case 'vmspikefilteringparameters';               tag = '[carry-005] ';
    otherwise;                                       tag = '';
end
end

function cn = classNameOf(preBody)
cn = '';
if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
    cn = char(preBody.document_class.class_name);
end
end

function n = baseName(preBody)
n = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    n = jGetChar(preBody.base, 'name');
end
end

function v = firstDepValue(preBody, names)
% Read an edge tolerantly. A v1 body spells the target `id`, a body that has
% been through did2.convert.universalRenames spells it `document_id`, and a body
% a migrator built spells it `value` -- all three are live on this code path.
% Same precedence as +did2/+validate/references.m:176-179.
v = '';
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
for s = 1:numel(names)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if ~isfield(d, 'name') || ~strcmp(char(d.name), names{s})
            continue;
        end
        for key = {'document_id', 'value', 'id'}
            f = key{1};
            if isfield(d, f) && ~isempty(d.(f))
                v = char(d.(f));
                return;
            end
        end
    end
end
end

% softwareEntity() -- DELETED 2026-08-10, consolidated onto
% private/jSoftwareFromApp.m + private/jSoftware.m (#25). It was a third copy of
% the same fold and the only one that did NOT write `software.local_identifier`,
% which is the handle the deferred corpus-wide dedup pass reads. Its two
% behaviours that the shared helpers lacked are now options on them, so nothing
% about this class's output changed except the added local_identifier:
%   - the no-session guard  -> jSoftware/jSoftwareFromApp 'RequireSession'
%   - parking the app block -> jSoftwareFromApp's 4th output
% Its one remaining difference is a widening, not a change: it read the URL as
% `url` only, and jSoftwareFromApp reads {'url','app_url'}. NDI's app template
% declares `url` (git show origin/main:.../database_documents/app.json), and
% universalRenames does not touch a single lowercase word, so the extra spelling
% cannot fire on a real document -- it is there for parity with the other
% callers, not because a document needs it.

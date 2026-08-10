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
%     - os / os_version / interpreter / interpreter_version -> parked in
%       `other.execution_environment`. `execution_environment` is a
%       subject_interaction field and method_parameters is not a statement, so
%       these four have NO TYPED HOME on this class. Parked, not dropped, and
%       reported as an open question.
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
    entries struct
    other (1,1) struct
    % `char` without a size spec: the default '' is 0-by-0 and would fail a
    % `(1,:) char` constraint.
    opts.DerivedFromSrc char = ''
end

TV = 'V_eta';

% ---------------------------------------------------------------- app/software
[software, softwareId, execEnv, appLeftover] = softwareEntity(preBody);
if ~isempty(fieldnames(execEnv))
    other.execution_environment = execEnv;
end
if ~isempty(fieldnames(appLeftover))
    other.app = appLeftover;
end

% ---------------------------------------------------------------- epoch scope
% The did_v1 `epochid` block is a bare string ('t00001'); V_eta replaces it with
% an `epoch_id` EDGE. jEpochDocId is the switch: until the epoch pass mints the
% documents it answers '', so the edge is omitted and the string is parked so
% the second pass can resolve it. Dropping it would lose the only record that
% these settings were scoped to one epoch -- and for
% spike_extraction_parameters_modification that scope is the WRITER's, not the
% template's (spikeextractor.m:310 sets 'epochid.epochid' on a class whose
% template declares only base + app), so it is exactly the kind of fact the
% ground-truth rule exists to protect.
epochDocId = jEpochDocId(preBody);
epochString = '';
if isfield(preBody, 'epochid') && isstruct(preBody.epochid)
    epochString = jGetChar(preBody.epochid, 'epochid');
end
if isempty(epochDocId) && ~isempty(epochString)
    other.epochid = epochString;
end

% ---------------------------------------------------------------- the document
mp = struct();
mp.document_class = struct('class_name', 'method_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', TV);

deps = struct('name', {}, 'value', {});
subjectId = firstDepValue(preBody, {'element_id', 'subject_id'});
if ~isempty(subjectId)
    deps(end+1) = struct('name', 'subject_id', 'value', subjectId);
end
if ~isempty(epochDocId)
    deps(end+1) = struct('name', 'epoch_id', 'value', epochDocId);
end
if ~isempty(opts.DerivedFromSrc)
    derivedId = firstDepValue(preBody, {opts.DerivedFromSrc});
    if ~isempty(derivedId)
        deps(end+1) = struct('name', 'derived_from_id', 'value', derivedId);
    end
end
if ~isempty(softwareId)
    deps(end+1) = struct('name', 'software_id', 'value', softwareId);
end
mp.depends_on = deps;

% base VERBATIM: base.id keeps the three inbound edges resolving, and base.name
% keeps the two by-name queries answerable.
if isfield(preBody, 'base') && isstruct(preBody.base)
    mp.base = preBody.base;
end

blk = struct();
blk.name = baseName(preBody);
blk.method_parameters = entries;
blk.other = other;
mp.method_parameters = blk;

bodies = {mp};
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== helpers =============================================

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

function [software, softwareId, execEnv, appLeftover] = softwareEntity(preBody)
%SOFTWAREENTITY v1 `app` block -> a V_eta `software` entity + the leftovers.
%
%   Reads BOTH spellings of every field. did2.convert.universalRenames rewrites
%   app.name -> app.app_name and app.version -> app.app_version
%   (universalRenames.m:145-164), so a migrator running after it sees the
%   prefixed names; a body read with RenameClassNames=false still carries the
%   bare ones.
software = []; softwareId = ''; execEnv = struct(); appLeftover = struct();
if ~isfield(preBody, 'app') || ~isstruct(preBody.app) || ~isscalar(preBody.app)
    return;
end
app = preBody.app;

name    = jGetCharAny(app, {'app_name', 'name'});
version = jGetCharAny(app, {'app_version', 'version'});
url     = jGetChar(app, 'url');

% the per-run environment: no typed home on method_parameters (V_eta puts
% execution_environment on subject_interaction, and this is not a statement).
envFields = {'os', 'os_version', 'interpreter', 'interpreter_version'};
for i = 1:numel(envFields)
    s = jGetChar(app, envFields{i});
    if ~isempty(s)
        execEnv.(envFields{i}) = s;
    end
end

sessionId = '';
datestamp = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    sessionId = jGetChar(preBody.base, 'session_id');
    ds = jGetChar(preBody.base, 'datestamp');
    if ~isempty(ds); datestamp = ds; end
end

if isempty(name) || isempty(sessionId)
    % No software identity, or no session to hang a minted entity on. Minting
    % one anyway would fail base's required session_id and quarantine the whole
    % SOURCE body (v1_to_v2 quarantines the input when any produced body fails),
    % turning a clean fold into a loss. Park the block whole instead.
    appLeftover = app;
    execEnv = struct();
    return;
end

gids = struct('scheme', {}, 'value', {});
if ~isempty(url)
    gids(end+1) = struct('scheme', 'URL', 'value', url);
end

softwareId = did.ido.unique_id();
software = struct();
software.document_class = struct('class_name', 'software', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
software.depends_on = struct('name', {}, 'value', {});
software.base = struct('id', softwareId, 'session_id', sessionId, ...
    'name', name, 'datestamp', datestamp);
software.entity = struct();
software.entity.global_identifier = gids;
software.software = struct('name', name, 'version', version);
end

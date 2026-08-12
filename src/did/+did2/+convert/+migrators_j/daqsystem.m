function bodies = daqsystem(preBody)
%DAQSYSTEM Brainstorm-J migrator: did_v1 daqsystem -> `acquisition_system`
%   (<- entity) + a `software` entity for its own implementation class.
%   1 -> 2, or 1 -> 1 when there is no class name. base.id AND base.name
%   PRESERVED on the acquisition_system.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: NOT VERIFIED BY EXECUTION. There is no MATLAB in the authoring
%   environment, so not one line of this file has been run.
%
%   STATUS, SECOND HALF: THE GUARD IS GONE AND THE FOLD IS LIVE (2026-08-12).
%   This block used to read "ON EVERY REAL did_v1 DOCUMENT THIS MIGRATOR IS A
%   PASSTHROUGH TODAY", because the source's one field had nowhere to land and
%   the NDI writer sets it on every document it creates. The team named a home
%   on 2026-08-12 (option A -- a second software edge, `software_id`), so the
%   fold now runs on real documents and `daqsystem` should LEAVE
%   `unconverted_by_class`. See "WHAT CHANGED" and "THE CORPUS CONSEQUENCE".
%
%   TEAM-SIGN-OFF [daq configuration]: jess@walthamdatascience.com / 2026-08-08
%   (did-schema schemas/V_eta_daq_family_decisions.md:471) --
%   "daqsystem -> `acquisition_system` <- entity, base.id AND base.name
%    preserved because the name is the join key".
%
%   The signed shape (same document, :210-214, as corrected 2026-08-08), plus
%   the 2026-08-12 addition marked below:
%
%       acquisition_system <- entity   base.id PRESERVED  base.name "intan1"
%          depends_on: software_id                   -> software   <- ADDED
%                      reader_id                     -> software
%                      epoch_file_pattern_id         -> epoch_file_pattern
%                      acquisition_metadata_reader_# -> acquisition_metadata_reader
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main -- TEMPLATE, SCHEMA AND WRITER AGREE
%   ---------------------------------------------------------------------
%   git show origin/main:src/ndi/ndi_common/database_documents/daq/daqsystem.json
%      superclasses  base
%      depends_on    filenavigator_id, daqreader_id, daqmetadatareader_id
%      daqsystem { "ndi_daqsystem_class": "" }
%
%   git show origin/main:src/ndi/ndi_common/schema_documents/daq/daqsystem_schema.json
%      filenavigator_id      "mustbenotempty": 1
%      daqreader_id          "mustbenotempty": 1
%      daqmetadatareader_id  "mustbenotempty": 0
%
%   git show origin/main:src/ndi/+ndi/+daq/system.m   (newdocument, :485-497)
%      ndi_document_obj_set{3} = ndi.document('daqsystem',...
%          'daqsystem.ndi_daqsystem_class', class(ndi_daqsystem_obj),...
%          'base.id', ndi_daqsystem_obj.id(),...
%          'base.name', ndi_daqsystem_obj.name,...
%          'base.session_id', ndi_daqsystem_obj.session.id());
%      ... set_dependency_value('filenavigator_id', ...)
%      ... set_dependency_value('daqreader_id', ...)
%      for i=1:numel(ndi_daqsystem_obj.daqmetadatareader)
%          ... add_dependency_value_n('daqmetadatareader_id', ...)
%
%   THE EDGE MAPPING (all three targets keep the SOURCE id, so every edge
%   resolves by existence -- must_refer_to_document_class is DECLARATIVE):
%
%      filenavigator_id       -> epoch_file_pattern_id
%                                (migrators_j/filenavigator.m, id preserved)
%      daqreader_id           -> reader_id
%                                (migrators_j/daqreader.m -> software, id preserved)
%      daqmetadatareader_id_# -> acquisition_metadata_reader_#
%                                (migrators_j/daqmetadatareader.m, id preserved)
%
%   `daqmetadatareader_id` is a NUMBERED FAMILY, not a scalar. NDI's
%   add_dependency_value_n appends entries named '<name>_<n+1>'
%   (+ndi/+document.m:119-120) while the TEMPLATE's own bare `daqmetadatareader_id`
%   entry stays behind with an empty value. So a real document carries
%   daqmetadatareader_id (empty) plus daqmetadatareader_id_1 ... _N, and the
%   family is re-indexed contiguously from 1 here. A system with no metadata
%   reader never enters the loop, which is why NDI marks it "mustbenotempty": 0
%   and V_eta gives acquisition_metadata_reader_# min_count 0.
%
%   ---------------------------------------------------------------------
%   base.name IS PRESERVED, AND IT IS THE JOIN KEY -- NOT DECORATION
%   ---------------------------------------------------------------------
%   `daqsystem_id` is referenced by NOTHING as an edge, and a depends_on sweep
%   therefore says this class is unreferenced. It is not. The name is matched by
%   string at live NDI sites:
%
%      +ndi/+daq/system.m:229    strcmpi(myprobemap.devicename, obj.name)
%                                  -- getprobes(): probe -> device attribution
%      +ndi/+time/+syncrule/commonTriggersOverlappingEpochs.m
%                                  parameters.daqsystem1_name / daqsystem2_name
%      +ndi/session.m:137-174    daqsystem_load('name', ...) rewrites 'name' to
%                                  a base.name query
%
%   Dissolving the name would silently break probe -> device attribution. It is
%   carried verbatim with the rest of `base`.
%
%   ---------------------------------------------------------------------
%   THE GUARD IS GONE (2026-08-12) -- `ndi_daqsystem_class` HAS A HOME NOW
%   ---------------------------------------------------------------------
%   THIS SECTION IS KEPT RATHER THAN DELETED, because the reason the guard
%   existed is the reason the new edge is shaped the way it is. Read it as
%   history down to "WHAT CHANGED".
%
%   The signed `acquisition_system` declared THREE dependencies and NO fields
%   (schemas/V_eta/stable/acquisition_system.json: "fields": []). The source's
%   one field, `ndi_daqsystem_class` ('ndi.daq.system.mfdaq' /
%   'ndi.daq.system.image'), had nowhere to land.
%
%   A name-grep says it is written once and read nowhere:
%
%      DENOMINATOR: 1,002 .m files and 251 .json files on NDI origin/main
%      git grep -n "ndi_daqsystem_class" origin/main -- '*.m'
%         src/ndi/+ndi/+daq/system.m:486        <- the only hit, and it is a WRITE
%
%   THAT READING IS WRONG, in exactly the way this project has been wrong before
%   -- the field name is CONSTRUCTED, so no literal grep can find the reader:
%
%      +ndi/+database/+fun/ndi_document2ndi_object.m:38-42
%          obj_struct = getfield(doc.document_properties, obj_parent_string);
%          obj_string = getfield(obj_struct,['ndi_' obj_parent_string '_class']);
%          o = eval([obj_string '(ndi_session_obj, ndi_document_obj);']);
%
%      +ndi/session.m:167-169   (daqsystem_load, reached from 8+ call sites)
%          dev_doc = ndi_session_obj.database_search(q);   % isa daqsystem
%          dev{i} = ndi.database.fun.ndi_document2ndi_object(dev_doc{i}, ...);
%
%   So `ndi_daqsystem_class` is the OBJECT-RECONSTRUCTION KEY for this class, and
%   the same generic site reads `ndi_daqreader_class`, `ndi_daqmetadatareader_class`
%   and `ndi_filenavigator_class` (+ndi/+daq/system.m:57-61). The signed model
%   gives the other three a home -- each becomes a `software` entity, and the
%   sign-off says so in general terms ("The class NAMES all move to deduplicated
%   `software` entities", V_eta_daq_family_decisions.md:264-265) -- but the
%   `acquisition_system` shape it declared had only ONE software edge,
%   `reader_id`, which is spoken for by the daqreader.
%
%   ---------------------------------------------------------------------
%   WHAT CHANGED -- OPTION A, DECIDED 2026-08-12
%   ---------------------------------------------------------------------
%   jess@walthamdatascience.com decided it on 2026-08-12: OPTION A --
%   `acquisition_system` gains a SECOND software edge so `ndi_daqsystem_class`
%   has a home. (Recorded in prose; the signature for this family lives in
%   did-schema schemas/V_eta_daq_family_decisions.md, and is not written here.)
%
%   The edge is `software_id`, built in did-schema tools/build_v_eta.py beside
%   the class it belongs to, with the naming argument in full there. In short:
%   it is the SAME concept the two siblings minted from the same decision
%   already spell `software_id` (epoch_file_pattern.software_id <-
%   ndi_filenavigator_class, acquisition_metadata_reader.software_id <-
%   ndi_daqmetadatareader_class), so T11's "one canonical spelling per concept"
%   settles the name. The pair on this class reads:
%
%       software_id   the rig's OWN implementation -- what this document IS
%       reader_id     a DIFFERENT component's identity, from v1 `daqreader_id`
%                     -- what this rig acquires THROUGH
%
%   IT IS OPTIONAL (`mustBeNonEmpty: false`), and that is not timidity: #37
%   RequiredDependencies is ARMED BY DEFAULT (+did2/+schema/cache.m:967-968), so
%   a required edge this migrator cannot always populate would QUARANTINE the
%   document. It cannot always populate it -- NDI's own schema gives
%   `ndi_daqsystem_class` "default_value": "" and no "mustbenotempty", and
%   jSoftware returns [] for an empty name, so the no-software path is real.
%
%   THE ROUTING FOLLOWS THE ESTABLISHED PATTERN, not a new one: the class name
%   goes to private/jSoftware.m exactly as filenavigator.m:147 and
%   daqmetadatareader.m:128-131 send theirs, this document emits the `software`
%   body ALONGSIDE its own, and the corpus-wide merge on (session, name,
%   version) is the deferred NDI second pass
%   (ndi.migrate.internal.softwareDedup), which retargets inbound edges BY
%   TARGET ID rather than by edge name -- so a second software edge on one
%   document needs nothing added there.
%
%   base.id IS NOT PRESERVED ON THE software BODY HERE, and that is the
%   difference from daqreader.m. daqreader DISSOLVES, so its id has to move to
%   the software document or four templates' `daqreader_id` edges dangle. A
%   daqsystem does NOT dissolve: its base.id stays on the `acquisition_system`
%   document (and its base.name is the join key), so the software entity takes
%   a fresh id -- the same choice filenavigator.m and daqmetadatareader.m make.
%
%   WHAT REMAINS A PASSTHROUGH. Only a document with NOTHING to declare: no
%   class name AND no edges. That is unchanged in kind, but it is now much
%   narrower -- a real NDI-written daqsystem always carries the class name
%   (+ndi/+daq/system.m:486 writes class(obj)), so the corpus stops passing
%   through. See "THE CORPUS CONSEQUENCE" next.
%
%   ---------------------------------------------------------------------
%   THE CORPUS CONSEQUENCE -- STATED IN ADVANCE, NOT DISCOVERED LATER
%   ---------------------------------------------------------------------
%   THREE numbers move, and each is visible in a named place:
%
%     1. `unconverted_by_class.daqsystem` goes from its FULL corpus count to 0.
%        Visible in v1_to_v2/printSummary and in the corpus report the census
%        digest rolls up (tools/census_digest.py).
%     2. `acquisition_system` appears in the migrated counts for the FIRST time,
%        at that same count. Nothing has ever emitted one on real data.
%     3. THE TOTAL DOCUMENT COUNT RISES, because this is a 1 -> 2 fold on every
%        document that carries a class name (the acquisition_system plus its
%        `software` entity), exactly as filenavigator and daqmetadatareader
%        already behave. "Total-doc counts are the invariant" is a rule about
%        classes DISSOLVING; a fold that mints an entity is the other case, and
%        saying so here is cheaper than explaining a surprise later.
%
%   THE COUNT ITSELF IS QUOTED, NOT MEASURED, AND THE DIFFERENCE MATTERS.
%   No corpus report exists on the authoring container -- did-schema
%   `status_board --check` prints "census roots: 0 walked, 2 missing" -- so
%   nothing here re-derives it. The figure on record is
%   did-schema schemas/V_eta_daq_family_decisions.md:359, written for a
%   different argument (the filenavigator naming):
%
%       "178 filenavigator : 178 daqsystem across four corpora, while
%        daqreader is NOT exact -- Dab has 40 systems and 39 readers"
%
%   and V_eta_statement_referent_findings.md:17 puts 96 of those 178 in Soph.
%   SIX corpora run today, not four, so treat 178 as a LOWER BOUND on a stale
%   denominator, not as the expected number. The check on the next corpus run is
%   the SHAPE, which does not depend on the figure: `daqsystem` absent from
%   `unconverted_by_class`, `acquisition_system` present at the same count, and
%   `software` up by that count.
%
%   AND WATCH `software_id` BY NAME, not `quarantine == 0`. Every edge on
%   `acquisition_system` is OPTIONAL and +did2/+validate/references.m:90 SKIPS
%   empty edges, so a migrator that failed to populate one would emit a hollow
%   document that validates. That is condition 1 of the signed decision
%   (V_eta_daq_family_decisions.md:273, "check those edge names BY NAME in the
%   silentLoss output rather than trusting quarantine=0"), and it now covers a
%   fifth name.
%
%   ONE RECORD IS KNOWINGLY LEFT STALE, because Claude may not write to
%   did-schema `schemas/` (operating rule 1). `V_eta_migration_targets.json`'s
%   hand-authored `flags` prose for this row still says "BUILT BUT GUARDED, AND
%   ON EVERY REAL did_v1 DOCUMENT IT IS A PASSTHROUGH TODAY", and
%   `V_eta_coverage_ledger.md` renders it verbatim.
%   `refresh_migration_targets.py` derives `targets` only and says so in its own
%   words -- "their `how`/`flags` prose ... is NOT touched by this tool: rewrite
%   it by hand". It needs a hand edit by someone who may make one. The stale
%   direction is the safe one (it claims LESS progress than exists), but it is
%   recorded here rather than left to be found.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'daqsystem') && isstruct(preBody.daqsystem) ...
        && isscalar(preBody.daqsystem)
    blk = preBody.daqsystem;
end

implClass = jGetChar(blk, 'ndi_daqsystem_class');

navId    = jSyncDependency(preBody, 'filenavigator_id');
readerId = jSyncDependency(preBody, 'daqreader_id');
mdIds    = dependencyFamily(preBody, 'daqmetadatareader_id');

if isempty(implClass) && isempty(navId) && isempty(readerId) && isempty(mdIds)
    % Nothing to declare. An acquisition_system with no edges and no fields is a
    % hollow document.
    %
    % THE NEXT CLAUSE USED TO READ "the source at least still carries its base
    % identity", AND THAT IS FALSE. Measured on this branch's first execution of
    % it (CI, 2026-08-12): the body passed through here QUARANTINES. The
    % `daqsystem` tombstone requires `filenavigator_id` and `daqreader_id`
    % non-empty and the `ndi_daqsystem_class` FIELD non-empty -- the same three
    % facts whose absence is the condition for arriving here. So the only body
    % that reaches this branch is the only body the tombstone rejects, and with
    % #37 RequiredDependencies and #38 NonVacuousFields armed it is dropped, not
    % preserved. The passthrough rescues nothing.
    %
    % IT IS LEFT AS IT IS, DELIBERATELY, and pinned by
    % testTheResidualPassthroughIsAQuarantinePathByConstruction. NDI sets
    % `ndi_daqsystem_class` on every document it writes and gives every real rig
    % a filenavigator and a daqreader, so this branch is unreachable for real
    % data; relaxing the tombstone to admit a hollow document would trade a live
    % guard for a case that cannot occur. Whether the branch should be deleted or
    % made to refuse LOUDLY is a team call, recorded rather than taken here.
    %
    % `implClass` JOINED THIS TEST WHEN THE GUARD WAS DELETED. Before 2026-08-12
    % a class name meant "pass through" (it had no home); now it is the one fact
    % that can carry a document on its own, via the software_id edge, so it has
    % to be counted as something-to-declare or a class-name-only daqsystem would
    % fall into a passthrough that is no longer warranted.
    bodies = {preBody};
    return;
end

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    sessionId = jGetChar(preBody.base, 'session_id');
    datestamp = jGetChar(preBody.base, 'datestamp');
end

% The implementation class name becomes an ENTITY, not a string field -- the
% same fold filenavigator.m:147 and daqmetadatareader.m:128-131 make of theirs,
% through the one place a `software` body is built. v1 records no version for a
% daqsystem (the template has one field and it is the class name), so the entity
% carries a name only and the corpus-wide merge on (session, name, version) is
% the deferred NDI second pass, ndi.migrate.internal.softwareDedup.
%
% GUARDED CALL, as in daqmetadatareader.m: jSoftware does return [] for an empty
% name, but its `name (1,:) char` arguments block is a size constraint a 0x0 ''
% does not obviously satisfy, and there is no MATLAB here to settle it.
software = [];
swId     = '';
if ~isempty(implClass)
    [software, swId] = jSoftware(implClass, '', '', sessionId, datestamp);
end

out = struct();
out.document_class = struct('class_name', 'acquisition_system', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');

% Every edge is OPTIONAL on acquisition_system, and an absent one is OMITTED
% rather than written empty: +did2/+validate/references.m:90 skips empty edges,
% so an empty edge is invisible rather than absent, which is the mechanism
% behind the whole invented-empty-edge census.
names  = {};
values = {};
% software_id FIRST, matching the schema's declaration order and the reading
% "what this rig IS, then what it acquires through".
if ~isempty(swId)
    names{end+1} = 'software_id';            values{end+1} = swId;
end
if ~isempty(readerId)
    names{end+1} = 'reader_id';              values{end+1} = readerId;
end
if ~isempty(navId)
    names{end+1} = 'epoch_file_pattern_id';  values{end+1} = navId;
end
for k = 1:numel(mdIds)
    names{end+1}  = sprintf('acquisition_metadata_reader_%d', k); %#ok<AGROW>
    values{end+1} = mdIds{k};                                     %#ok<AGROW>
end
out.depends_on = struct('name', names, 'value', values);

% base carried verbatim: id AND name PRESERVED (see above), with session_id and
% datestamp.
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    out.base = preBody.base;
else
    out.base = struct('id', did.ido.unique_id(), 'session_id', '', ...
        'name', '', 'datestamp', '2024-01-01T00:00:00.000Z');
end

% `entity` is abstract but declares `global_identifier` with the default
% (declaring_class) placement, so it contributes a block that must be present
% (+did2/+schema/cache.m:248,268). v1 records no cross-reference identifier for
% a rig, so the array is present-and-empty rather than absent-and-guessed-at --
% the same shape private/jSoftware.m uses.
out.entity = struct('global_identifier', {struct('scheme', {}, 'value', {})});
% acquisition_system declares NO fields, but it is a CONCRETE class, so
% resolvePlacement lists it in blocksContributed and the (empty) block must
% exist -- the same reason migrators_j/daqmetadatareader_epochdata_ingested.m
% writes an empty acquisition_metadata_file block.
out.acquisition_system = struct();

bodies = {out};
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== helpers =============================================

function ids = dependencyFamily(bodyStruct, baseName)
%DEPENDENCYFAMILY The populated members of a NUMBERED depends_on family, in order.
%   Reads '<baseName>' and '<baseName>_<n>' and returns their non-empty target
%   ids as a 1xN cellstr ordered by n (the bare, unsuffixed entry first).
%
%   The bare entry is included because NDI's TEMPLATE ships it -- with an empty
%   value -- and add_dependency_value_n appends '_1', '_2', ... beside it
%   (+ndi/+document.m:119-120) rather than filling it. So on a real document the
%   bare entry contributes nothing and the suffixed ones carry the family; a
%   document written by another route could populate the bare one, and dropping
%   it on that assumption is the kind of shape-guess that produced the ~2,078
%   distance_metadata quarantines.
ids = {};
if ~isfield(bodyStruct, 'depends_on') || isempty(bodyStruct.depends_on) ...
        || ~isstruct(bodyStruct.depends_on)
    return;
end
deps = bodyStruct.depends_on;
order  = [];
values = {};
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name')
        continue;
    end
    nm = char(d.name);
    if strcmp(nm, baseName)
        idx = 0;
    else
        prefix = [baseName '_'];
        if numel(nm) <= numel(prefix) || ~strncmp(nm, prefix, numel(prefix))
            continue;
        end
        suffix = nm(numel(prefix)+1:end);
        if any(~ismember(suffix, '0123456789'))
            continue;   % '<baseName>_something_else' is a different edge
        end
        idx = str2double(suffix);
    end
    v = '';
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            v = char(d.(f));
            break;
        end
    end
    if isempty(v)
        continue;
    end
    order(end+1)  = idx; %#ok<AGROW>
    values{end+1} = v;   %#ok<AGROW>
end
if isempty(order)
    return;
end
[~, sortIdx] = sort(order);
ids = values(sortIdx);
end

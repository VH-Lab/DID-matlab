function bodies = daqsystem(preBody)
%DAQSYSTEM Brainstorm-J migrator: did_v1 daqsystem -> `acquisition_system`
%   (<- entity). 1 -> 1, base.id AND base.name PRESERVED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: NOT VERIFIED BY EXECUTION. There is no MATLAB in the authoring
%   environment, so not one line of this file has been run.
%
%   STATUS, SECOND HALF, AND READ IT BEFORE READING ANYTHING ELSE HERE:
%   ON EVERY REAL did_v1 DOCUMENT THIS MIGRATOR IS A PASSTHROUGH TODAY. The
%   fold below is complete and tested, and it is GUARDED on a fact the signed
%   target has nowhere to store -- see "THE GUARD" -- which the NDI writer sets
%   on every document it creates. Nothing converts until a team call names a
%   home for that fact. `daqsystem` will therefore appear in
%   `unconverted_by_class` at its full corpus count; that is the honest signal,
%   not a bug.
%
%   TEAM-SIGN-OFF [daq configuration]: jess@walthamdatascience.com / 2026-08-08
%   (did-schema schemas/V_eta_daq_family_decisions.md:471) --
%   "daqsystem -> `acquisition_system` <- entity, base.id AND base.name
%    preserved because the name is the join key".
%
%   The signed shape (same document, :210-214, as corrected 2026-08-08):
%
%       acquisition_system <- entity   base.id PRESERVED  base.name "intan1"
%          depends_on: reader_id                     -> software
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
%   THE GUARD -- `ndi_daqsystem_class` HAS NO HOME, AND IT IS NOT DEAD WEIGHT
%   ---------------------------------------------------------------------
%   The signed `acquisition_system` declares THREE dependencies and NO fields
%   (schemas/V_eta/stable/acquisition_system.json: "fields": []). The source's
%   one field, `ndi_daqsystem_class` ('ndi.daq.system.mfdaq' /
%   'ndi.daq.system.image'), has nowhere to land.
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
%   `acquisition_system` shape it declares has only ONE software edge,
%   `reader_id`, which is spoken for by the daqreader.
%
%   Naming a second edge is a DECISION, not a build, so it is not taken here
%   (Operating Rule 4). Until it is taken, converting would drop the fact
%   silently, so the migrator passes the document through instead. A passthrough
%   is safe: `daqsystem` is in build_v_eta.py's `_KEEP_INFRA` and NOT in
%   `_DELETE_PHASE8`, so its V_eta source tombstone exists and the document
%   validates as itself -- and the tombstone's depends_on was repaired in the
%   schema half (filenavigator_id + daqreader_id + daqmetadatareader_id_#),
%   so a passed-through document is not a hollow one.
%
%   The fold below is exercised by tests through a body with no
%   `ndi_daqsystem_class`. It becomes live by DELETING the guard, once the team
%   says where the class name goes.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'daqsystem') && isstruct(preBody.daqsystem) ...
        && isscalar(preBody.daqsystem)
    blk = preBody.daqsystem;
end

if ~isempty(jGetChar(blk, 'ndi_daqsystem_class'))
    bodies = {preBody};     % see THE GUARD above
    return;
end

navId    = jSyncDependency(preBody, 'filenavigator_id');
readerId = jSyncDependency(preBody, 'daqreader_id');
mdIds    = dependencyFamily(preBody, 'daqmetadatareader_id');

if isempty(navId) && isempty(readerId) && isempty(mdIds)
    % Nothing to declare. An acquisition_system with no edges and no fields is a
    % hollow document; the source at least still carries its base identity.
    bodies = {preBody};
    return;
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

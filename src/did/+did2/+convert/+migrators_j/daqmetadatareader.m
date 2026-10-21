function bodies = daqmetadatareader(preBody)
%DAQMETADATAREADER Brainstorm-J migrator: did_v1 daqmetadatareader ->
%   `acquisition_metadata_reader` (+ the `software` entity for the
%   implementation class). 1 -> 2, or 1 -> 1, or a guarded passthrough.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: NOT VERIFIED BY EXECUTION. There is no MATLAB in the authoring
%   environment, so not one line of this file has been run.
%
%   TEAM-SIGN-OFF [daq configuration]: jess@walthamdatascience.com / 2026-08-08
%   (did-schema schemas/V_eta_daq_family_decisions.md:471) --
%   "daqmetadatareader -> `acquisition_metadata_reader`".
%
%   NAME DECIDED separately, team 2026-08-06 (same document, :366-374):
%     "I accept the suggested naming acquisition_metadata_reader /
%      acquisition_metadata_file."
%   The reader finds and parses the companion trial spreadsheet; the file class
%   is that spreadsheet's bytes, preserved per epoch (#66,
%   migrators_j/daqmetadatareader_epochdata_ingested.m).
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main -- TEMPLATE, SCHEMA AND WRITER AGREE
%   ---------------------------------------------------------------------
%   git show origin/main:src/ndi/ndi_common/database_documents/daq/\
%       daqmetadatareader.json
%      superclasses  base
%      depends_on    (none declared)
%      daqmetadatareader {
%         "ndi_daqmetadatareader_class": "ndi.daq.metadatareader",
%         "tab_separated_file_parameter": "" }
%
%   git show origin/main:src/ndi/ndi_common/schema_documents/daq/\
%       daqmetadatareader_schema.json
%      depends_on: [ ]          <- EXPLICITLY NONE
%      both fields "type": "string"
%
%   git show origin/main:src/ndi/+ndi/+daq/metadatareader.m   (newdocument, :193-197)
%      ndi_document_obj = ndi.document('daqmetadatareader',...
%          'daqmetadatareader.ndi_daqmetadatareader_class',class(obj),...
%          'daqmetadatareader.tab_separated_file_parameter', ...
%               obj.tab_separated_file_parameter, ...
%          'base.id', obj.id(),...
%          'base.session_id',ndi.session.empty_id());
%
%   THE MAPPING:
%
%      ndi_daqmetadatareader_class  -> a `software` entity + a software_id edge
%      tab_separated_file_parameter -> acquisition_metadata_reader
%                                        .metadata_file_pattern
%
%   `tab_separated_file_parameter` is GENUINE, not a template leftover: it is
%   read back as a document field at +ndi/+daq/metadatareader.m:36
%   (`tsv_p = varargin{2}.document_properties.daqmetadatareader.` ...
%   `tab_separated_file_parameter`) and drives the per-epoch file search at :69-81.
%   Its sibling `metadata_names` was INVENTED (0 hits across 1,002 .m files and
%   251 .json files on origin/main) and is deleted schema-side by the same
%   sign-off; this migrator therefore has nothing to read for it.
%
%   Note `base.session_id` is `ndi.session.empty_id()` -- the sentinel
%   '0000000000000000_0000000000000000' meaning "applies in any session"
%   (+ndi/+session/empty_id.m) -- not an empty string. It is carried verbatim and
%   satisfies base.session_id's mustBeNonEmpty.
%
%   ---------------------------------------------------------------------
%   base.id IS PRESERVED -- TWO CLASSES REFERENCE IT
%   ---------------------------------------------------------------------
%     daqsystem.daqmetadatareader_id_#                (a NUMBERED FAMILY:
%        +ndi/+daq/system.m:495 loops with add_dependency_value_n)
%     daqmetadatareader_epochdata_ingested.daqmetadatareader_id
%        -> which migrates to acquisition_metadata_file
%           .acquisition_metadata_reader_id, declared REQUIRED
%
%   That second edge is the reason preservation is not optional here: the
%   ingested-payload carrier's REQUIRED edge is filled from the SOURCE
%   document's daqmetadatareader_id (migrators_j/
%   daqmetadatareader_epochdata_ingested.m:74,94), so if this fold minted a new
%   id the carrier would point at nothing.
%
%   ---------------------------------------------------------------------
%   THE GUARD
%   ---------------------------------------------------------------------
%   Nothing to declare -- no class name AND no file parameter -- means an
%   `acquisition_metadata_reader` with an empty optional field, no edge and no
%   content: a hollow document that validates clean and says nothing. Pass the
%   source through instead. Safe because `daqmetadatareader` is in
%   build_v_eta.py's `_KEEP_INFRA` and NOT in `_DELETE_PHASE8`, so its V_eta
%   source tombstone still exists and the document validates as itself.
%
%   A class name with no file parameter, or a file parameter with no class name,
%   are both REAL and both convert -- the second simply omits software_id rather
%   than writing it empty, because +did2/+validate/references.m:90 SKIPS empty
%   edges, so an empty edge is invisible rather than absent.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'daqmetadatareader') && isstruct(preBody.daqmetadatareader) ...
        && isscalar(preBody.daqmetadatareader)
    blk = preBody.daqmetadatareader;
end

implClass   = jGetChar(blk, 'ndi_daqmetadatareader_class');
filePattern = jGetChar(blk, 'tab_separated_file_parameter');

if isempty(implClass) && isempty(filePattern)
    bodies = {preBody};     % see THE GUARD above
    return;
end

sessionId = jSid(preBody);
datestamp = jStamp(preBody);
software = {};
swId     = '';
if ~isempty(implClass)
    [software, swId] = jSoftware(implClass, '', '', sessionId, datestamp);
end
% did-schema #88: `acquisition_metadata_reader` is `epoch_parameter_reader`;
% the tab-separated file parameter is its `file_regex`.
edges = struct();
if ~isempty(swId); edges.software_id = swId; end
f = struct();
if ~isempty(filePattern); f.file_regex = filePattern; end
o = jOpts(preBody, 'Edges', edges, 'Id', char(preBody.base.id));
reader = did2.build.document('epoch_parameter_reader', f, o{:});
bodies = [{reader}, software];
end

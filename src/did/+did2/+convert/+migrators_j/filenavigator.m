function bodies = filenavigator(preBody)
%FILENAVIGATOR Brainstorm-J migrator: did_v1 filenavigator -> epoch_file_pattern
%   (+ the `software` entity for the implementation class). 1 -> 1 or 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [file navigation]: jess, 2026-08-06 (V_eta_daq_family_decisions.md:325)
%     "filenavigator becomes `epoch_file_pattern` with base.id preserved: the two
%      eval'd parameter strings become declared pattern lists (data_file_pattern,
%      epoch_map_pattern) plus epoch_map_format, and the implementation class name
%      becomes a software_id edge. `directory` is NOT a did_v1 source and is
%      unaffected."
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main (template AND writer agree)
%   ---------------------------------------------------------------------
%   ndi_common/database_documents/daq/filenavigator.json declares FOUR fields and
%   NO dependencies, and filenavigator_schema.json declares the same four:
%
%       ndi_filenavigator_class       "the ndi.file.navigator class type"
%       fileparameters                "the file parameters for finding epochs"
%       epochprobemap_class           "the ndi.epoch.probemap class type"
%       epochprobemap_fileparameters  "file parameters for finding epochprobemaps"
%
%   The writer is ndi.file.navigator/newdocument (navigator.m:729-755). It writes
%   class(obj) into ndi_filenavigator_class -- so the value is a MATLAB class
%   name: 'ndi.file.navigator', 'ndi.file.navigator.epochdir',
%   'ndi.file.navigator.rhd_series', 'ndi.setup.file.navigator.vhPrairie2p' --
%   and cell2str(...) into the two parameter fields.
%
%   The mapping:
%
%       ndi_filenavigator_class       -> a `software` entity + a software_id edge
%       fileparameters                -> epoch_file_pattern.data_file_pattern
%       epochprobemap_fileparameters  -> epoch_file_pattern.epoch_map_pattern
%       epochprobemap_class           -> epoch_file_pattern.epoch_map_format
%
%   epoch_map_format stays a plain char by decision: it is a MATLAB class name
%   and really the FORMAT of the epochprobemap file, closer to a content type
%   than to software, and binding it buys nothing until #32 makes bindings real
%   (V_eta_daq_family_decisions.md, "3. epoch_map_format stays a plain char").
%   So only ONE of the two class-name fields becomes software; that asymmetry is
%   the signed decision, not an oversight.
%
%   ---------------------------------------------------------------------
%   base.id IS PRESERVED -- TWO REQUIRED EDGES DEPEND ON IT
%   ---------------------------------------------------------------------
%   `filenavigator_id` is declared on two NDI classes and is REQUIRED on both:
%
%       database_documents/daq/daqsystem.json:13              filenavigator_id
%       schema_documents/daq/daqsystem_schema.json:5          "mustbenotempty": 1
%       database_documents/ingestion/epochfiles_ingested.json:13   filenavigator_id
%       schema_documents/ingestion/epochfiles_ingested_schema.json:5  "mustbenotempty": 1
%
%   and it is queried live by id at +ndi/+daq/system.m:36-44,491,512 and
%   +ndi/+file/navigator.m:237,499,707,723. Minting a fresh id here would dangle
%   every daqsystem and every ingested-epoch document in the corpus -- the
%   11,448-orphan mistake. base.id, base.session_id, base.name and base.datestamp
%   are carried verbatim.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NOTHING TO DECLARE => PASS THE DOCUMENT THROUGH
%   ---------------------------------------------------------------------
%   Same shape as fitcurve / openminds_stimulus / probe_geometry. If the
%   `filenavigator` block is missing, or all four of its fields are empty, this
%   migrator would emit an epoch_file_pattern with no patterns, no format and no
%   software edge -- a hollow document that validates clean and says nothing.
%   The source class still has its V_eta tombstone (V_eta/stable/filenavigator.json,
%   whose four fields match the NDI template exactly), so passing through loses
%   nothing and is visible in `unconverted_by_class`.
%
%   ---------------------------------------------------------------------
%   OPEN, AND IT BLOCKS A CORPUS RUN -- READ BEFORE ENABLING THIS
%   ---------------------------------------------------------------------
%   V_eta/stable/epoch_file_pattern.json declares data_file_pattern and
%   epoch_map_pattern as  "type": "char", "mustBeScalar": false  -- i.e. it
%   intends a LIST (its own documentation says {'#\.rhd\>', '#\.tsv\>'}), but
%   the validator's char branch accepts only a char array or a SCALAR string:
%
%       +did2/+schema/cache.m:965-970
%           case {'char', 'did_uid', 'timestamp'}
%               if ~(ischar(value) || (isstring(value) && isscalar(value)))
%                   error('did2:validation:typeMismatch', ...);
%
%   Only the `string` branch (cache.m:971-1001) accepts a cell-of-chars, and it
%   was written for exactly this case ("MATLAB's jsondecode produces a
%   cell-of-chars for JSON arrays of strings"). The family's own sibling already
%   uses it: epochfiles_ingested.files is "type": "string", "mustBeScalar": false.
%
%   This migrator emits the cellstr the sign-off asks for. Under the schema AS
%   DECLARED TODAY that means a multi-pattern navigator QUARANTINES with
%   did2:validation:typeMismatch. That is the deliberate direction: a quarantine
%   is visible, and the alternatives all lose data silently -- joining the list
%   into one char destroys it, a char matrix pads short patterns with spaces
%   (changing the regex), and emitting a char for one pattern but a cell for
%   several is the representation drift V_eta_openminds_family_record.md Part 3
%   rules out.
%
%   THE FIX IS ONE WORD, TWICE, IN DID-schema (out of scope here):
%   epoch_file_pattern.json data_file_pattern / epoch_map_pattern
%   "type": "char" -> "type": "string". Until that lands, do not include this
%   migrator in a corpus run. testMigratorsJFileNavSoftware.m pins the current
%   behaviour so the day the schema changes, the pin fails and gets updated.
%
%   1 -> 2 (epoch_file_pattern + software), or 1 -> 1 when the implementation
%   class name is absent, or a passthrough when there is nothing to declare.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'filenavigator') && isstruct(preBody.filenavigator) ...
        && isscalar(preBody.filenavigator)
    blk = preBody.filenavigator;
end

implClass  = jGetChar(blk, 'ndi_filenavigator_class');
mapFormat  = jGetChar(blk, 'epochprobemap_class');
dataList   = jFileMatchList(rawField(blk, 'fileparameters'));
mapList    = jFileMatchList(rawField(blk, 'epochprobemap_fileparameters'));

if isempty(implClass) && isempty(mapFormat) && isempty(dataList) && isempty(mapList)
    bodies = {preBody};     % nothing to declare -- see THE GUARD above
    return;
end

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    sessionId = jGetChar(preBody.base, 'session_id');
    datestamp = jGetChar(preBody.base, 'datestamp');
end

% The implementation class name becomes an ENTITY, not a string field (the
% signed model). v1 records no version for it -- the template has no version
% field -- so the software carries a name only, and the corpus-wide merge by
% (name, version) is deferred to the NDI second pass (see jSoftware.m).
[software, swId] = jSoftware(implClass, '', '', sessionId, datestamp);

pattern = struct();
pattern.document_class = struct('class_name', 'epoch_file_pattern', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');

% software_id is OPTIONAL on epoch_file_pattern (mustBeNonEmpty: false). It is
% omitted rather than written empty when there is no implementation class -- an
% empty edge is skipped by +did2/+validate/references.m:90, so writing one would
% be invisible rather than absent.
if isempty(swId)
    pattern.depends_on = struct('name', {}, 'value', {});
else
    pattern.depends_on = struct('name', 'software_id', 'value', swId);
end

% id PRESERVED (see above), together with name / session_id / datestamp.
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    pattern.base = preBody.base;
else
    pattern.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
        'name', '', 'datestamp', '2024-01-01T00:00:00.000Z');
end

% Each field is OMITTED when it has no value rather than written blank: the
% schema's blank_value for the two lists is [], which the char branch of the
% validator would reject as a type mismatch, and a blank field is precisely what
% did2.validate.silentLoss counts as vacuous.
efp = struct();
if ~isempty(dataList); efp.data_file_pattern = dataList; end
if ~isempty(mapList);  efp.epoch_map_pattern = mapList;  end
if ~isempty(mapFormat); efp.epoch_map_format = mapFormat; end
pattern.epoch_file_pattern = efp;

bodies = {pattern};
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== helpers =============================================

function v = rawField(block, name)
%RAWFIELD The field value untouched (jGetChar would coerce a cell away).
v = [];
if isstruct(block) && isfield(block, name)
    v = block.(name);
end
end

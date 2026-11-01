function [carried, notes, out] = carryNote(batch)
%CARRYNOTE Migrate a batch on the raw-v1 path; say whether its first document
%   was carried as its untouched v1 source, and with which notes.
%
%   [CARRIED, NOTES, OUT] = did2.unittest.helpers.carryNote(BATCH). CARRIED is
%   true when the documents emitted for BATCH{1} are exactly one, stamped
%   'did_v1', equal to BATCH{1} but for that stamp. NOTES is the text of every
%   distinct `carried_as_v1` note of the run, joined by ' || ' ('' when none).
%   OUT is did2.convert.v1_to_v2's result ('Validate', false).
%
%   See also did2.convert.reportNote.

arguments
    batch cell
end

out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'did_v2');
v1 = batch{1};
id = '';
if isfield(v1, 'base') && isfield(v1.base, 'id'); id = char(v1.base.id); end
mine = {};
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    if isfield(s, 'base') && isfield(s.base, 'id') && strcmp(char(s.base.id), id)
        mine{end+1} = s; %#ok<AGROW>
    end
end
carried = false;
if isscalar(mine) && isfield(mine{1}.document_class, 'schema_version') ...
        && strcmp(char(mine{1}.document_class.schema_version), 'did_v1')
    s = mine{1};
    if isfield(v1.document_class, 'schema_version')
        s.document_class.schema_version = v1.document_class.schema_version;
    else
        s.document_class = rmfield(s.document_class, 'schema_version');
    end
    carried = isequaln(s, v1);
end
notes = '';
n = out.summary.migration_notes;
if isfield(n, 'carried_as_v1')
    notes = strjoin(cellstr(n.carried_as_v1.distinct_details), ' || ');
end
end

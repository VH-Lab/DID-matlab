function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-J migrator: did_v1 ontology_table_row -> the v1
%   row, carried whole (1 -> 1).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   EVERY row is carried whole as v1: the untouched source comes back with a
%   `carried_as_v1` note citing register row carry-026 (`needs_mapping`). The
%   generic stage resolves no subject and fans out no statements, because a v1
%   row does not state which entity each column is about (a v1 subject, or an
%   entity v1 never made, such as a plate or a patch), nor each column's
%   direction, value kind or unit. Each dataset's import maps its own tables.
%
%   Decided by Jess Haley, 2026-10-30 [table rows carried as v1], did-schema
%   V_eta_go_forward_class_audit.md ("the generic migration carries every v1
%   `ontologyTableRow` whole as v1; it resolves no subject and fans out no
%   statements"), under [migration not generalizable] and [dataset-specific
%   logic leaves the generic migration]. It supersedes the earlier split
%   (a row with no `subject_id` edge passed through without a note for NDI's
%   second pass; a row with one carried with a note, [one correct reading],
%   [dataset audit batch 1 and 2] (4)): the two now get the same carry.
%
%   NDI's second pass may re-fold a row with an added `subject_id` edge back
%   through this migrator; that row is carried too, which is intended.
%
%   NO PER-TABLE MAPS. The JH C. elegans encounter map and bacterial-patch
%   geometry map that once lived here encoded one dataset's tables, and left
%   the generic migration ([dataset-specific logic leaves the generic
%   migration], [dataset audit batch 1 and 2]); the Haley dataset's V2 shape
%   comes from its V2 re-import (ndi.setup.conv.haley.import_V2).
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-30; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1 writes the class `ontologyTableRow`
%   (data/ontologyTableRow.json + base.json at the locked NDI-matlab `main`,
%   441530d: block `ontologyTableRow` {names, variableNames, ontologyNodes,
%   data}, edge `document_id`; written by +NDIMaker/tableDocMaker.m), which
%   did2.convert.rawV1Classes' table joins to this migrator, and v1_to_v2 hands
%   it over unchanged. The block is required in either spelling (v1's
%   `ontologyTableRow`, or `ontology_table_row`, the renamed spelling a fixture
%   or a body that reaches this migrator by its snake_case class name still
%   has). Every row is carried, so the carry is now the untouched v1 source,
%   which NDI's second pass counts under either class name
%   (ndi.migrate.internal.ontologyRowsCarried). Its round trip is the
%   passthrough inverse (did2.convert.roundtrip.ontologyTableRow; a carry
%   reads back as itself).

arguments
    preBody (1,1) struct
end

if ~hasBlock(preBody, 'ontologyTableRow') && ~hasBlock(preBody, 'ontology_table_row')
    error('did2:convert:missingBlock', ...
        'ontology_table_row body is missing the ontology_table_row property block.');
end

% carry-register: carry-026
did2.convert.reportNote('carried_as_v1', 'ontology_table_row', sourceIdOf(preBody), ...
    ['[carry-026] needs_mapping: assertion | observation | manipulation per column (its ' ...
     'entity, direction, value kind and unit); decided by the table''s column ' ...
     'map in its dataset ([table rows carried as v1])']);
bodies = {preBody};
end

function tf = hasBlock(preBody, name)
tf = isfield(preBody, name) && isstruct(preBody.(name));
end

function id = sourceIdOf(preBody)
%SOURCEIDOF The v1 document's base.id (or legacy identity), '' when none
%   (did2.convert.v1read.readBase).
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
end

function [names, rows] = noMigratorCarryRows(v1Name)
%NOMIGRATORCARRYROWS The v1 classes with no migrator, carried whole as v1, and each one's carry register row.
%
%   NAMES = did2.convert.noMigratorCarryRows() is a cellstr of v1 class names
%   (the v1 spelling, document_class.class_name exactly as v1 writes it).
%   did2.convert.v1_to_v2 carries a document of one of these classes whole as
%   v1: the untouched v1 source, stamped did_v1, with a `carried_as_v1` note
%   citing the class's row. It does not go through
%   did2.convert.universalRenames, a superclass migrator or the identity
%   fallback.
%
%   [NAMES, ROWS] = did2.convert.noMigratorCarryRows() also returns each
%   class's carry register row as the tag a carry note cites ('[carry-158]';
%   did-schema schemas/registry/did_v2_carry_register.json). The tags are
%   written out below so tools/check_carry_citations.py finds them (the
%   v1_to_v2 carry site names this file with `via`).
%
%   ROW = did2.convert.noMigratorCarryRows(V1NAME) is the tag for V1NAME, or
%   '' when V1NAME is not listed.
%
%   WHY. Decided by Jess Haley, 2026-10-31 [classes without a migrator carry
%   as v1] (did-schema docs/plans/did_v2_go_forward_class_audit.md), "Ok" to:
%   "the 9 v1 classes with no migrator are kept unchanged as v1 [...] Each
%   would get a carry row, and a migrator can replace that row later." A class
%   that gets a migrator leaves this table, and its row leaves the register.
%
%   THE LIST is the 7 of those 9 that have no conversion anywhere. The other
%   two are NOT listed, and stay on their conversions until the team answers
%   did-schema docs/V2_PLAN.md #143 Q4. `ensemble` is converted by NDI's second
%   pass (ndi.migrate.internal.ensembleMembership; did-schema
%   did_v2_ensemble_plan.md [ensemble retired]). `generic_file` is converted by
%   the batch pass did2.convert.foldGenericFiles.
%
%   See also did2.convert.v1_to_v2, did2.convert.rawV1Classes.

arguments
    v1Name {mustBeTextScalar} = ''
end

table = { ...
    'animalsubject',            '[carry-158]'; ...
    'demoNDISeries',            '[carry-159]'; ...
    'demoNDISeriesMixed',       '[carry-160]'; ...
    'imageCollection',          '[carry-161]'; ...
    'projectvar',               '[carry-162]'; ...
    'stimulus_parameter_table', '[carry-163]'; ...
    'valid_interval',           '[carry-164]'};

if nargin > 0
    i = find(strcmp(table(:, 1), char(v1Name)), 1);
    if isempty(i)
        names = '';
    else
        names = table{i, 2};
    end
    return;
end
names = table(:, 1)';
rows = table(:, 2)';
end

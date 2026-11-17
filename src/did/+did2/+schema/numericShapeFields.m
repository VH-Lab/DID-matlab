function [defs, kind] = numericShapeFields(defs, parentName)
%NUMERICSHAPEFIELDS A field list with the new numeric shape declared beside the old.
%
%   [DEFS, KIND] = did2.schema.numericShapeFields(DEFS, PARENTNAME) takes one level of a
%   schema `fields` list (a cell of field definitions, or a struct array) and
%   returns it, as a cell, with the fields of the new numeric shape added
%   where the list is one of the three shapes that decision changes. KIND
%   says which it was: 'item', 'fit', 'cell' or '' (none; DEFS unchanged).
%
%   WHY. Decided by Jess Haley, 2026-11-17, did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers].
%   Its section 9 orders the work: (1) DID-matlab's validator and did2.build
%   read BOTH shapes, (2) the writers write the new one, (3) did-schema's class
%   files change and the old shape is removed, (4) readers drop the old shape.
%   This is step 1. The schema JSON still describes only the old shape, so the
%   new one is declared here, from the old one, in one place that the builder
%   (private/fillField), the validator (did2.schema.cache) and the JSON writer
%   (cache.matrixFieldPaths) all read. A field the schema already declares is
%   never added again, so once step 3 puts the new fields in the class files
%   this function adds nothing and can be deleted.
%
%   THE THREE SHAPES (plan sections 2, 4 and 7):
%
%   'item'  a list item -- covariates, conditions, method parameters,
%           compression parameters: a list that declares `variable` and one
%           of `quantity`, `origin`, `matrix`. Added:
%             numeric         canonical number(s); type `matrix` (an array at
%                             each position adds dimensions; it replaces both
%                             `quantity` and `matrix`, so it is written with
%                             every dimension present, as `matrix` is)
%             source_numeric  the number(s) as the source wrote them; the type
%                             of the old `quantity.source_value` (`matrix` on a
%                             covariate, text on a condition or parameter, where
%                             a number is also accepted: see the PR's open
%                             question on the source's spelling)
%             tolerance       {minus, plus}, in `unit`
%           and, where the list declares `origin` (covariates):
%             origin, spacing either the old {value, source_value} block or a
%                             flat number (alt_leaf)
%             source_origin, source_spacing   flat numbers
%           `unit`, `source_unit` and `approximate` are already declared.
%
%   'fit'   a model_fit coefficient or constraint: a list of exactly
%           {variable, value}. Added (plan section 8, answer 5): numeric,
%           unit, source_numeric, source_unit.
%
%   'cell'  a numeric value class's value cell (voltage.value, mass.value,
%           concentration.value, dose's amount_per_body_mass, ...): declares a
%           numeric `source_value` and a `source_unit` and no `variable`.
%           Added: source_numeric (source_value renamed). When the list is a
%           statement's own value (PARENTNAME 'value': voltage.value, not
%           dose.value.amount_per_body_mass or a time reference's start), the
%           cell's canonical field(s) -- the run of numeric fields it declares
%           first (volts; concentration's seven; score's score) until a class
%           declares its `canonical` (plan section 2) -- and source_numeric
%           are marked `series`: in the new shape a statement's series is ONE
%           cell whose canonical field is an array (plan section 8, answer 4),
%           while the old shape is an array of cells of one number each.
%           Callers enforce that the two are not mixed (did2.schema.cache,
%           private/fillField). PARENTNAME is the name of the field whose
%           sub-fields DEFS are; omitted, no field is marked `series`.
%           Not a cell here: date and the absolute time references, whose
%           source_value is text (plan section 7, "Not changed").
%
%   A definition this function adds carries `numeric_shape: true`, so a
%   caller can tell it from one the schema declares.
%
%   See also did2.read.numeric, did2.read.canonical, did2.build.numericShape.

if nargin < 2
    parentName = '';
end
if isstruct(defs)
    defs = num2cell(reshape(defs, 1, []));
elseif isempty(defs)
    defs = {};
    kind = '';
    return;
else
    defs = reshape(defs, 1, []);
end
kind = '';
names = cell(1, numel(defs));
for k = 1:numel(defs)
    names{k} = '';
    if isstruct(defs{k}) && isfield(defs{k}, 'name')
        names{k} = char(defs{k}.name);
    end
end
has = @(n) any(strcmp(names, n));

if has('variable') && (has('quantity') || has('origin') || has('matrix'))
    kind = 'item';
    [defs, names] = itemFields(defs, names);
elseif numel(names) == 2 && has('variable') && has('value') ...
        && any(strcmp(typeOf(defs{strcmp(names, 'value')}), {'double', 'matrix'}))
    kind = 'fit';
    defs = fitFields(defs, names);
elseif ~has('variable') && has('source_unit') && has('source_value') ...
        && any(strcmp(typeOf(defs{strcmp(names, 'source_value')}), {'double', 'matrix'}))
    kind = 'cell';
    defs = cellFields(defs, names, strcmp(char(parentName), 'value'));
end
end

% -------------------------------------------------------------------------

function [defs, names] = itemFields(defs, names)
qsType = 'matrix';
q = find(strcmp(names, 'quantity'), 1);
if ~isempty(q) && isfield(defs{q}, 'fields') && ~isempty(defs{q}.fields)
    qsub = defs{q}.fields;
    if isstruct(qsub); qsub = num2cell(reshape(qsub, 1, [])); end
    for k = 1:numel(qsub)
        if strcmp(char(qsub{k}.name), 'source_value')
            qsType = typeOf(qsub{k});
        end
    end
end
numericDef = leafDef('numeric', 'matrix', false, ...
    'Canonical number(s), in `unit`; an array at each position adds dimensions.');
sourceDef = leafDef('source_numeric', qsType, false, ...
    'The number(s) as the source wrote them, in `source_unit`.');
if strcmp(qsType, 'char')
    % a number is also accepted (see the header)
    sourceDef.alt_leaf = leafDef('source_numeric', 'matrix', false, sourceDef.documentation);
end
added = {};
if ~any(strcmp(names, 'numeric'));        added{end+1} = numericDef; end
if ~any(strcmp(names, 'source_numeric')); added{end+1} = sourceDef; end
if ~any(strcmp(names, 'tolerance'));      added{end+1} = toleranceDef(); end
at = find(ismember(names, {'quantity', 'origin', 'matrix'}), 1);
[defs, names] = insertAt(defs, names, added, at);

o = find(strcmp(names, 'origin'), 1);
if isempty(o)
    return;
end
for n = {'origin', 'spacing'}
    j = find(strcmp(names, n{1}), 1);
    if ~isempty(j) && strcmp(typeOf(defs{j}), 'structure') && ~isfield(defs{j}, 'alt_leaf')
        defs{j}.alt_leaf = leafDef(n{1}, 'double', true, ...
            'Where regular positions start / the step between them, in `unit`.');
    end
end
added = {};
if ~any(strcmp(names, 'source_origin'))
    added{end+1} = leafDef('source_origin', 'double', true, ...
        '`origin` as the source wrote it, in `source_unit`.');
end
if ~any(strcmp(names, 'source_spacing'))
    added{end+1} = leafDef('source_spacing', 'double', true, ...
        '`spacing` as the source wrote it, in `source_unit`.');
end
s = find(strcmp(names, 'spacing'), 1);
if isempty(s); s = o; end
[defs, names] = insertAt(defs, names, added, s + 1);
end

function defs = fitFields(defs, names)
added = {};
if ~any(strcmp(names, 'numeric'))
    added{end+1} = leafDef('numeric', 'double', true, 'Its value.');
end
if ~any(strcmp(names, 'unit'))
    added{end+1} = termDef('unit', 'Canonical unit; empty when none is stated.');
end
if ~any(strcmp(names, 'source_numeric'))
    added{end+1} = leafDef('source_numeric', 'double', true, 'Its value as the source wrote it.');
end
if ~any(strcmp(names, 'source_unit'))
    added{end+1} = termDef('source_unit', 'The unit the source gave.');
end
defs = insertAt(defs, names, added, find(strcmp(names, 'value'), 1) + 1);
end

function defs = cellFields(defs, names, isSeries)
% the canonical field(s): the numeric fields the cell declares first
if isSeries
    for k = 1:numel(defs)
        if ~any(strcmp(typeOf(defs{k}), {'double', 'matrix'})) ...
                || any(strcmp(names{k}, {'source_value', 'source_numeric'}))
            break;
        end
        defs{k}.series = true;
        defs{k}.mustBeScalar = false;
    end
end
if any(strcmp(names, 'source_numeric'))
    j = find(strcmp(names, 'source_numeric'), 1);
    if isSeries
        defs{j}.series = true;
        defs{j}.mustBeScalar = false;
    end
    return;
end
sv = find(strcmp(names, 'source_value'), 1);
d = defs{sv};
d.name = 'source_numeric';
d.documentation = 'The number(s) as the source wrote them, in `source_unit` (source_value renamed).';
d.numeric_shape = true;
if isSeries
    d.series = true;
    d.mustBeScalar = false;
end
defs = insertAt(defs, names, {d}, sv + 1);
end

% -------------------------------------------------------------------------

function [defs, names] = insertAt(defs, names, added, at)
if isempty(added)
    return;
end
if isempty(at) || at > numel(defs) + 1
    at = numel(defs) + 1;
end
addedNames = cellfun(@(d) d.name, added, 'UniformOutput', false);
defs = [defs(1:at-1), added, defs(at:end)];
names = [names(1:at-1), addedNames, names(at:end)];
end

function d = leafDef(name, type, scalar, doc)
d = struct('name', name, 'type', type, 'blank_value', [], 'default_value', [], ...
    'mustBeNonEmpty', false, 'mustBeScalar', scalar, 'mustNotHaveNaN', false, ...
    'queryable', false, 'ontology', [], 'documentation', doc, ...
    'constraints', struct(), 'numeric_shape', true);
end

function d = termDef(name, doc)
d = leafDef(name, 'ontology_term', true, doc);
d.fields = {leafDef('node', 'char', true, 'The CURIE.'), ...
    leafDef('name', 'char', true, 'The human-readable label.')};
end

function d = toleranceDef()
d = leafDef('tolerance', 'structure', true, ...
    'The bound on the number(s): the true value lies between numeric - minus and numeric + plus, in `unit`.');
minus = leafDef('minus', 'double', true, 'How far below, in `unit`. Non-negative.');
minus.constraints = struct('minimum', 0);
plus = leafDef('plus', 'double', true, 'How far above, in `unit`. Non-negative.');
plus.constraints = struct('minimum', 0);
d.fields = {minus, plus};
end

function t = typeOf(d)
t = '';
if isstruct(d) && isfield(d, 'type')
    t = char(d.type);
end
end

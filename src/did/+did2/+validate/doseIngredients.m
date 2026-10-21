function report = doseIngredients(docs)
%DOSEINGREDIENTS Batch census of the did-schema dose rule `ingredient_in_formulation`.
%
%   REPORT = did2.validate.doseIngredients(DOCS) finds every dose statement
%   (a statement with a `formulation_id` edge and the `dose` value kind) in
%   DOCS, looks up the formulation its `formulation_id` names IN DOCS, and runs
%   did2.build.checkDoseIngredients(dose, formulation) on the pair (Jess Haley,
%   2026-10-21 [dose per ingredient]: every `ingredient_id` on a dose is one of
%   its formulation's). It COUNTS; it quarantines nothing. Denominator first:
%     docs_inspected, docs_unreadable
%     doses_inspected                 dose statements found
%     doses_with_ingredients          of those, carrying an ingredient_id edge
%     formulation_not_in_batch        the formulation_id names no document here
%                                     (not checked -- NOT a pass and NOT a fail)
%     doses_checked                   pairs actually run through the rule
%     violations                      of those, refused by the rule
%     violation_examples              first 20 {id, message}

report = struct('docs_inspected', 0, 'docs_unreadable', 0, ...
    'doses_inspected', 0, 'doses_with_ingredients', 0, ...
    'formulation_not_in_batch', 0, 'doses_checked', 0, 'violations', 0, ...
    'violation_examples', struct('id', {}, 'message', {}));
[bodies, unreadable] = vBodies(docs);
report.docs_inspected = numel(bodies) + unreadable;
report.docs_unreadable = unreadable;

byId = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    b = bodies{k};
    if isstruct(b) && isfield(b, 'base') && isfield(b.base, 'id')
        byId(char(b.base.id)) = k;
    end
end
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isDose(b); continue; end
    report.doses_inspected = report.doses_inspected + 1;
    if ~isempty(edgeValues(b, 'ingredient_id'))
        report.doses_with_ingredients = report.doses_with_ingredients + 1;
    end
    fid = edgeValues(b, 'formulation_id');
    if isempty(fid) || ~isKey(byId, fid{1})
        report.formulation_not_in_batch = report.formulation_not_in_batch + 1;
        continue;
    end
    report.doses_checked = report.doses_checked + 1;
    try
        did2.build.checkDoseIngredients(b, bodies{byId(fid{1})});
    catch err
        report.violations = report.violations + 1;
        if numel(report.violation_examples) < 20
            report.violation_examples(end+1) = struct('id', char(b.base.id), ...
                'message', err.message);
        end
    end
end
end

function tf = isDose(b)
tf = false;
if ~isstruct(b) || ~isfield(b, 'document_class'); return; end
if isfield(b, 'dose') && isstruct(b.dose)
    tf = true;     % the dose value-kind block
    return;
end
try
    sc = b.document_class.superclasses;
    if isstruct(sc); names = {sc.class_name}; else; names = cellfun(@(x) char(x.class_name), sc, 'UniformOutput', false); end
    tf = any(strcmp(names, 'dose'));
catch
end
end

function v = edgeValues(b, name)
v = {};
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps); items = deps(:)'; else; items = num2cell(deps(:)'); end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~strcmp(char(d.name), name); continue; end
    x = '';
    if isfield(d, 'value') && ~isempty(d.value); x = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); x = char(d.document_id); end
    if ~isempty(x); v{end+1} = x; end %#ok<AGROW>
end
end

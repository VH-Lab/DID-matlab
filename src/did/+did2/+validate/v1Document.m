function r = v1Document(body, templates)
%V1DOCUMENT Check a v1 document against NDI-matlab's v1 template for its class.
%
%   R = did2.validate.v1Document(BODY, TEMPLATES). BODY is a v1 document (a
%   struct, as jsondecode gives it); TEMPLATES is did2.schema.v1Templates()'s
%   index. R is a struct:
%     checked     false when TEMPLATES is not present (NOT CHECKED; never read
%                 as valid)
%     class_name  the document's class
%     ok          true when no problem was found
%     problems    cellstr, each one a fact:
%                   no NDI template for the class
%                   a top-level block that is neither document_class,
%                     depends_on, files nor a property block of the class or
%                     a superclass
%                   a field of such a block the template does not declare
%                   a depends_on name the template does not declare (a
%                     numbered `<name>_<n>` of a declared `<name>` is declared)
%                   a `files` block on a class whose template declares none
%   Values are not checked, only the shape: a template states fields and their
%   defaults, not types.
%
%   WHY. Decided by Jess Haley, 2026-10-27 [carried v1 validates against NDI
%   templates] (did-schema V_eta_go_forward_class_audit.md): "a document carried
%   whole as v1 is validated against NDI-matlab's v1 templates at the locked
%   NDI `main`, not against did-schema tombstones". did2.convert.v1_to_v2 runs
%   it on every carried source and reports (summary.carried_v1_template_check);
%   a carry the template refuses is counted, not quarantined: a document
%   carried because it holds a field outside its template (carry-100) is meant
%   to fail this check.
%
%   See also did2.schema.v1Templates.

arguments
    body (1,1) struct
    templates (1,1) struct
end

r = struct('checked', false, 'class_name', '', 'ok', false, 'problems', {{}});
stamp = did2.convert.v1read.readStamp(body);
r.class_name = char(stamp.class_name);
if ~isfield(templates, 'present') || ~templates.present
    return;
end
r.checked = true;
if isempty(r.class_name) || ~isKey(templates.byClass, r.class_name)
    r.problems{end+1} = sprintf('no NDI template for class "%s"', r.class_name);
    return;
end
t = templates.byClass(r.class_name);
blocks = fieldnames(t.blocks);
top = fieldnames(body);
for k = 1:numel(top)
    b = top{k};
    if any(strcmp(b, {'document_class', 'depends_on'}))
        continue;
    end
    if strcmp(b, 'files')
        if ~t.has_files
            r.problems{end+1} = 'files (the template declares no files)';
        end
        continue;
    end
    if ~any(strcmp(b, blocks))
        r.problems{end+1} = sprintf('block %s (not in the template)', b);
        continue;
    end
    v = body.(b);
    if isstruct(v) && isscalar(v)
        extra = setdiff(fieldnames(v), t.blocks.(b), 'stable');
        for j = 1:numel(extra)
            r.problems{end+1} = sprintf('%s.%s (not in the template)', b, extra{j}); %#ok<AGROW>
        end
    end
end
deps = did2.convert.v1read.readDependsOn(body);
for k = 1:numel(deps)
    nm = char(deps(k).name);
    base = regexprep(nm, '_\d+$', '');
    if ~any(strcmp(nm, t.edges)) && ~any(strcmp(base, t.edges)) ...
            && ~any(strcmp([base '_1'], t.edges))
        r.problems{end+1} = sprintf('depends_on(%s) (not in the template)', nm); %#ok<AGROW>
    end
end
r.ok = isempty(r.problems);
end

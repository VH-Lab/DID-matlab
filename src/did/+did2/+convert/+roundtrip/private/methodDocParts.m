function [v1, entries, spec] = methodDocParts(bodies, v1Class, edgeNames)
%METHODDOCPARTS The parts of a v1 settings document that
%   +migrators_j/private/jMethodParameters folded into one `method` document
%   and the `software` entity its `app` block names.
%
%   [V1, ENTRIES, SPEC] = methodDocParts(BODIES, V1CLASS, EDGENAMES). BODIES
%   is what the migration emitted: the `method` (base.id preserved), and, when
%   the v1 `app` block named the software, its `software` entity and the
%   entity's version assertion. V1 comes back with:
%     document_class.class_name  V1CLASS
%     base                       the method's id, session and timestamp; NAME
%                                the method's `name` (jMethodParameters keeps
%                                base.name there)
%     app                        name, version, url from the software entity
%                                (its name, its version assertion, its first
%                                global identifier), when there is one; the
%                                run's os and interpreter fields are empty (a
%                                document stating them is carried, carry-002
%                                to carry-005)
%     depends_on                 the method's edges, renamed back by EDGENAMES
%                                (a struct: V2 edge name -> v1 edge name, e.g.
%                                entity_id -> element_id)
%   ENTRIES is the cell of the method's parameter entries, for the caller to
%   map back (the bound variables, the bag, a parked epoch string). SPEC holds
%   what could not be placed.
%
%   See also did2.convert.roundtrip.sorting_parameters,
%            did2.convert.roundtrip.spike_extraction_parameters.

spec = emptySpec();
v1 = struct();
entries = {};
n = numel(bodies);
used = false(1, n);
m = [];
for k = 1:n
    if strcmp(classNameOf(bodies{k}), 'method')
        m = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(m)
    spec.unplaced{end+1} = 'no method was emitted';
    return;
end
base = rebuildBase(m);
swIds = edgeIds(m, 'software_id');
app = [];
for k = 1:n
    if used(k) || ~strcmp(classNameOf(bodies{k}), 'entity'); continue; end
    b = bodies{k};
    if isscalar(swIds) && strcmp(char(getIn(b, 'base', 'id')), swIds{1})
        app = struct('name', fieldText(getIn(b, 'entity'), 'name'), 'version', '', 'url', '', ...
            'os', '', 'os_version', '', 'interpreter', '', 'interpreter_version', '');
        g = getIn(b, 'entity', 'global_identifier');
        if iscell(g) && ~isempty(g); g = g{1}; end
        if ischar(g) || (isstring(g) && isscalar(g)); app.url = char(g); end
        used(k) = true;
    end
end
for k = 1:n
    if used(k) || ~strcmp(classNameOf(bodies{k}), 'assertion') || isempty(app); continue; end
    b = bodies{k};
    [~, variable] = termParts(getIn(b, 'statement', 'variable'));
    if strcmpi(variable, 'version number') && isequal(edgeIds(b, 'entity_id'), swIds)
        app.version = char(getIn(b, 'text', 'value', 'text'));
        used(k) = true;
    end
end
if ~isempty(swIds) && isempty(app)
    spec.unplaced{end+1} = 'the software the method names was not emitted';
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a %s', ...
        k, classNameOf(bodies{k}), v1Class);
end

v1.document_class = struct('class_name', v1Class);
deps = struct('name', {}, 'value', {});
v2Names = fieldnames(edgeNames);
for j = 1:numel(v2Names)
    ids = edgeIds(m, v2Names{j});
    for i = 1:numel(ids)
        deps(end+1) = struct('name', edgeNames.(v2Names{j}), 'value', ids{i}); %#ok<AGROW>
    end
end
known = [v2Names(:)', {'software_id', 'session_id'}];
d = did2.convert.v1read.readDependsOn(m);
for i = 1:numel(d)
    if ~any(strcmp(d(i).name, known)) && ~isempty(d(i).document_id)
        spec.unplaced{end+1} = sprintf('the method''s %s edge has no v1 place', d(i).name);
    end
end
if ~isempty(deps)
    v1.depends_on = deps;
end
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', fieldText(getIn(m, 'method'), 'name'), 'datestamp', base.datestamp);
if ~isempty(app)
    v1.app = app;
end
entries = asCell(getIn(m, 'method', 'parameters'));
end

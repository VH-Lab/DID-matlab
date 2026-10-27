function [v1, leaf, inputs, spec] = calcParts(bodies, leafClass, v1Class, methodName)
%CALCPARTS The parts every tuning calculation inverse shares: the converted
%   calculation, its v1 identity, its `app` block and its method parameters.
%
%   [V1, LEAF, INPUTS, SPEC] = calcParts(BODIES, LEAFCLASS, V1CLASS, METHODNAME)
%   reads what did2.convert.migrators_j.private.jCalculation emitted for one
%   v1 calculator document (BODIES): the named calculation LEAFCLASS, its
%   session anchor, and the `software` entities (with their version
%   assertions) for the calculator, the operating system and the interpreter.
%
%   V1 holds, in NDI's v1 shape (calculator.json + app.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8):
%     document_class.class_name   V1CLASS (the v1 spelling)
%     base.id, session_id, datestamp   the calculation (rebuildBase); base.name
%                                 is '' (V2 never writes it; #73 item 54)
%     app.name, version, url      the `software_id` entity: its name, its
%                                 version assertion, its global_identifier
%     app.os, os_version          the `operating_system_id` entity
%     app.interpreter, interpreter_version   the `interpreter_id` entity
%     <V1CLASS>.input_parameters  method.parameters, read back by
%                                 methodParameters
%   An `app` block is written only when the calculation names software; a
%   software entity named METHODNAME with no version and no url is the one
%   jCalculation mints when the v1 `app` block names none, and writes no app.
%
%   LEAF is the calculation (a struct; [] when none was emitted, and SPEC says
%   so). INPUTS are its `input_id` edges, in order; the caller names them (the
%   v1 edge names are not kept, only their order: jCalculation inputIds).
%   SPEC.equivalents states the calculator block's inner `depends_on` copy:
%   jCalculation leaves it unwritten only when every entry restates the
%   top-level edge of the same name ([restated values checked], Jess Haley,
%   2026-10-26), so each entry can only have been one of the top-level edges;
%   the caller adds those once it has named them (innerDependsOn).
%   SPEC.unplaced names every emitted document with no role here.

spec = emptySpec();
v1 = struct();
leaf = [];
inputs = {};
n = numel(bodies);
used = false(1, n);
for k = 1:n
    if strcmp(classNameOf(bodies{k}), leafClass)
        leaf = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(leaf)
    spec.unplaced{end+1} = sprintf('no %s was emitted', leafClass);
    return;
end
base = rebuildBase(leaf);
inputs = edgeIds(leaf, 'input_id');
anchors = edgeIds(leaf, 'time_reference_id');
roles = {'software_id', 'operating_system_id', 'interpreter_id'};
roleIds = cell(1, numel(roles));
for r = 1:numel(roles)
    roleIds{r} = edgeIds(leaf, roles{r});
end
ents = repmat(struct('name', '', 'version', '', 'url', '', 'found', false), 1, numel(roles));
for k = 1:n
    if used(k); continue; end
    b = bodies{k};
    id = char(getIn(b, 'base', 'id'));
    switch classNameOf(b)
        case 'relative_time_reference'
            if any(strcmp(id, anchors))
                used(k) = true;
            end
        case 'entity'
            for r = 1:numel(roles)
                if any(strcmp(id, roleIds{r})) && ~ents(r).found
                    ents(r).found = true;
                    ents(r).name = fieldText(getIn(b, 'entity'), 'name');
                    g = getIn(b, 'entity', 'global_identifier');
                    if iscell(g) && ~isempty(g); g = g{1}; end
                    if ischar(g) || (isstring(g) && isscalar(g))
                        ents(r).url = char(g);
                    end
                    used(k) = true;
                    break;
                end
            end
    end
end
for k = 1:n
    if used(k) || ~strcmp(classNameOf(bodies{k}), 'assertion'); continue; end
    b = bodies{k};
    [~, variable] = termParts(getIn(b, 'statement', 'variable'));
    if ~strcmpi(variable, 'version number'); continue; end
    owner = edgeIds(b, 'entity_id');
    for r = 1:numel(roles)
        if ents(r).found && isscalar(owner) && any(strcmp(owner{1}, roleIds{r})) ...
                && isempty(ents(r).version)
            ents(r).version = char(getIn(b, 'text', 'value', 'text'));
            used(k) = true;
            break;
        end
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a %s', ...
        k, classNameOf(bodies{k}), v1Class);
end

v1.document_class = struct('class_name', v1Class);
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
minted = ents(1).found && strcmp(ents(1).name, methodName) ...
    && isempty(ents(1).version) && isempty(ents(1).url);
if any([ents.found]) && ~(minted && ~ents(2).found && ~ents(3).found)
    app = struct('name', '', 'version', '', 'url', '', 'os', '', 'os_version', '', ...
        'interpreter', '', 'interpreter_version', '');
    if ents(1).found && ~minted
        app.name = ents(1).name;
        app.version = ents(1).version;
        app.url = ents(1).url;
    end
    app.os = ents(2).name;
    app.os_version = ents(2).version;
    app.interpreter = ents(3).name;
    app.interpreter_version = ents(3).version;
    v1.app = app;
end
[params, bad] = methodParameters(getIn(leaf, 'interaction', 'method', 'parameters'));
spec.unplaced = [spec.unplaced, bad];
blk = struct();
if ~isempty(fieldnames(params))
    blk.input_parameters = params;
end
v1.(v1Class) = blk;
end

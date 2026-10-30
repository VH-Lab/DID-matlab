function [v1, spec] = stimulus_response_scalar_parameters_basic(bodies)
%STIMULUS_RESPONSE_SCALAR_PARAMETERS_BASIC Rebuild a v1
%   `stimulus_response_scalar_parameters_basic` from what the migration made of
%   it.
%
%   [V1, SPEC] = did2.convert.roundtrip.stimulus_response_scalar_parameters_basic(BODIES).
%   V1 is the parameters document in NDI's v1 shape
%   (stimulus_response_scalar_parameters_basic.json +
%   stimulus_response_scalar_parameters.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as ndi.app.stimulus.tuning_response writes it:
%   the six knobs, by vlt.data.var2struct). BODIES is one of:
%
%   PASSED THROUGH (pass 1): one `stimulus_response_scalar_parameters_basic`
%   document, the migrator's passthrough as v1_to_v2 padded and stamped it:
%   the document itself, its session edge read back into base.session_id and
%   its creation_timestamp into base.datestamp.
%
%   CONVERTED (did2.convert.resolveResponseParameters): the `method` document
%   (id preserved), optionally with the harmonic_component calculations whose
%   `method_id` names it (the responses that use it):
%     base.id, session_id, datestamp     the method (rebuildBase)
%     base.name                          the method's `name`, when it has one
%                                        ([v1 name goes to the class's own
%                                        name field])
%     the knobs                          each `method.parameters` entry, its
%                                        variable named back to the v1 knob
%                                        through the name table
%                                        (did2.convert.tuningNames; Decided by
%                                        Jess Haley, 2026-10-27 [parameter
%                                        names map by table]): its quantity
%                                        value, or its text
%     prestimulus_time                   not written when v1 held [] (no
%                                        baseline period): rebuilt absent
%     prestimulus_normalization          written 0 when v1 held []
%                                        ([empty response settings] "c"):
%                                        rebuilt 0, and a v1 [] counts as
%                                        equal to it (SPEC.same; Decided by
%                                        Jess Haley, 2026-10-27 [empty
%                                        prestimulus normalization is zero]:
%                                        "count `[]` and `0` as the same value
%                                        for this one setting")
%     freq_response                      NOT a parameter: the batch pass checks
%                                        it against the harmonic of the
%                                        responses that use the method. Rebuilt
%                                        from those responses when BODIES holds
%                                        them and they agree; otherwise not
%                                        rebuilt (reported lost)
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.stimulus_response_scalar_parameters_basic,
%            did2.convert.resolveResponseParameters.

arguments
    bodies cell
end

CLASS = 'stimulus_response_scalar_parameters_basic';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = passedThrough(bodies{1});
    return;
end

used = false(1, numel(bodies));
m = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'method')
        m = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(m)
    spec.unplaced{end+1} = 'no method document was emitted';
    return;
end
[base, ~] = rebuildBase(m);

% the responses that use this method: their harmonic is the v1 freq_response
harmonics = [];
for k = 1:numel(bodies)
    if used(k); continue; end
    b = bodies{k};
    if strcmp(classNameOf(b), 'calculation') && isfield(b, 'harmonic_component') ...
            && isequal(edgeIds(b, 'method_id'), {base.id})
        h = numberOf(getIn(b, 'harmonic_component', 'value', 'harmonic'));
        if ~isempty(h)
            harmonics(end+1) = h; %#ok<AGROW>
        end
        used(k) = true;
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a parameters document', ...
        k, classNameOf(bodies{k}));
end

blk = struct();
entries = asCell(getIn(m, 'method', 'parameters'));
for k = 1:numel(entries)
    e = entries{k};
    [~, name] = termParts(getIn(e, 'variable'));
    if isempty(name)
        spec.unplaced{end+1} = sprintf('method parameter %d names no variable', k);
        continue;
    end
    [field, inTable] = did2.convert.tuningNames('v1', name);
    if ~inTable
        spec.unplaced{end+1} = sprintf('method parameter "%s" is not in the name table', name);
        continue;
    end
    [q, hasQ] = getIn(e, 'quantity', 'value');
    [t, hasT] = getIn(e, 'text');
    if hasT && ~isempty(t)
        blk.(field) = char(t);
    elseif hasQ && ~isempty(q)
        blk.(field) = q;
    else
        spec.unplaced{end+1} = sprintf('method parameter "%s" has no quantity or text', name);
    end
end
if ~isempty(harmonics)
    if all(harmonics == harmonics(1))
        blk.freq_response = harmonics(1);
    else
        spec.unplaced{end+1} = 'the responses using this method state different harmonics';
    end
end

v1.document_class = struct('class_name', CLASS);
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
% [v1 name goes to the class's own name field] (Jess Haley, 2026-10-27):
% resolveResponseParameters writes a non-empty v1 base.name to method.name
methodName = fieldText(getIn(m, 'method'), 'name');
if ~isempty(methodName)
    v1.base.name = methodName;
end
v1.(CLASS) = blk;
% [empty prestimulus normalization is zero] (Jess Haley, 2026-10-27): for this
% one setting a v1 [] and the V2 0 are the same value (the writer gives them
% one meaning: tuning_response.m, "[] or 0) No normalization")
spec.same(end+1) = struct('path', [CLASS '.prestimulus_normalization'], ...
    'fn', @(a, b) (isempty(a) && isnumeric(b) && isscalar(b) && b == 0) ...
        || (isnumeric(a) && isscalar(a) && a == 0 && isempty(b)), ...
    'why', '[empty prestimulus normalization is zero] (Jess Haley, 2026-10-27)');
end

% ===================== helpers =========================================

function v1 = passedThrough(body)
%PASSEDTHROUGH A passed-through v1 document as v1 stated it (v1_to_v2's
%   outbound renames undone: the session edge, creation_timestamp).
v1 = body;
sid = char(did2.schema.cache.sessionIdOf(body));
if isfield(v1, 'depends_on') && isstruct(v1.depends_on)
    if ~isempty(v1.depends_on)
        keep = true(1, numel(v1.depends_on));
        for k = 1:numel(v1.depends_on)
            keep(k) = ~strcmp(char(v1.depends_on(k).name), 'session_id');
        end
        v1.depends_on = v1.depends_on(keep);
    end
    if isempty(v1.depends_on)
        v1 = rmfield(v1, 'depends_on');   % v1 writes no depends_on here
    end
end
if isfield(v1, 'base') && isstruct(v1.base) && ~isfield(v1.base, 'session_id') && ~isempty(sid)
    v1.base.session_id = sid;
end
if isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'creation_timestamp') ...
        && ~isfield(v1.base, 'datestamp')
    v1.base.datestamp = v1.base.creation_timestamp;
    v1.base = rmfield(v1.base, 'creation_timestamp');
end
end

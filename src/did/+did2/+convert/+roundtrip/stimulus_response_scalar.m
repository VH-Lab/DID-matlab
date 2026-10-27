function [v1, spec] = stimulus_response_scalar(bodies)
%STIMULUS_RESPONSE_SCALAR Rebuild a v1 `stimulus_response_scalar` from what
%   did2.convert.migrators_j.stimulus_response_scalar emitted for it.
%
%   [V1, SPEC] = did2.convert.roundtrip.stimulus_response_scalar(BODIES). V1 is
%   the response in NDI's v1 shape (stimulus_response_scalar.json +
%   stimulus_response.json + base.json at the locked NDI-matlab `main`,
%   3cb19a8, as ndi.app.stimulus.tuning_response/compute_stimulus_response_scalar
%   writes it). BODIES is one of:
%
%   CONVERTED: the `calculation` with the `harmonic_component` value kind, its
%   time anchor, its software (and run) entities, and, when the caller passes
%   it, the epoch entity the anchor names (epochMint mints it; it is not a
%   pass-1 document):
%     base.id, session_id, datestamp     the calculation (rebuildBase)
%     depends_on, in the order NDI's template merge gives it (names sorted):
%       element_id                       entity_id
%       stimulator_id                    instrument_id
%       stimulus_control_id              '' (a converted response has none:
%                                        one that names a control is carried,
%                                        carry-050)
%       stimulus_presentation_id         the first input_id
%       stimulus_response_scalar_parameters_id  method_id
%     stimulus_response.element_epochid  the epoch entity's local_identifier
%                                        when the anchor names it; '' when the
%                                        anchor is the session; NOT REBUILT
%                                        when the anchor names an epoch that is
%                                        not in BODIES (the round trip reports
%                                        it lost)
%     stimulus_response.stimulator_epochid  '' (one that is set is carried,
%                                        carry-050)
%     stimulus_response_scalar.response_type   'mean' for harmonic 0, else
%                                        'F<harmonic>' (the writer's rule)
%     stimulus_response_scalar.responses       value.real / imaginary /
%                                        control.real / control.imaginary, and
%                                        stimid from the `stimulus` covariate
%                                        along the reading dimension; each as a
%                                        column, the shape jsondecode gives a
%                                        JSON list
%
%   PASSED THROUGH: one `stimulus_response_scalar` document (a guard of the
%   migrator handed it back; v1_to_v2 padded and stamped it): the document
%   itself, its session edge read back into base.session_id and its
%   creation_timestamp into base.datestamp (v1_to_v2's outbound renames).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.stimulus_response_scalar.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'stimulus_response_scalar')
    v1 = passedThrough(bodies{1});
    return;
end

used = false(1, numel(bodies));
calc = [];
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(classNameOf(b), 'calculation') && isfield(b, 'harmonic_component')
        calc = b;
        used(k) = true;
        break;
    end
end
if isempty(calc)
    spec.unplaced{end+1} = 'no harmonic_component calculation was emitted';
    return;
end
[base, ~] = rebuildBase(calc);

anchorIds = edgeIds(calc, 'time_reference_id');
roleIds = [edgeIds(calc, 'software_id'), edgeIds(calc, 'operating_system_id'), ...
    edgeIds(calc, 'interpreter_id')];
referent = '';
for k = 1:numel(bodies)
    if used(k); continue; end
    id = idOf(bodies{k});
    if any(strcmp(id, anchorIds)) && strcmp(classNameOf(bodies{k}), 'relative_time_reference')
        r = edgeIds(bodies{k}, 'referent_id');
        if ~isempty(r); referent = r{1}; end
        used(k) = true;
    elseif any(strcmp(id, roleIds)) && strcmp(classNameOf(bodies{k}), 'entity')
        used(k) = true;
    elseif strcmp(classNameOf(bodies{k}), 'assertion') ...
            && any(strcmp(firstId(edgeIds(bodies{k}, 'entity_id')), roleIds))
        used(k) = true;   % a software version (jSoftware), from an `app` block
    end
end
epochString = [];
if isempty(referent) || strcmp(referent, base.session_id)
    epochString = '';
else
    for k = 1:numel(bodies)
        if used(k) || ~strcmp(idOf(bodies{k}), referent)
            continue;
        end
        [lid, ok] = getIn(bodies{k}, 'entity', 'local_identifier');
        if strcmp(classNameOf(bodies{k}), 'entity') && ok
            epochString = char(lid);
            used(k) = true;
        end
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a stimulus response', ...
        k, classNameOf(bodies{k}));
end

inputs = edgeIds(calc, 'input_id');
names = {'element_id', 'stimulator_id', 'stimulus_control_id', ...
    'stimulus_presentation_id', 'stimulus_response_scalar_parameters_id'};
values = {firstId(edgeIds(calc, 'entity_id')), firstId(edgeIds(calc, 'instrument_id')), ...
    '', firstId(inputs), firstId(edgeIds(calc, 'method_id'))};
if numel(inputs) > 1
    spec.unplaced{end+1} = sprintf('%d inputs; a v1 response has one presentation', numel(inputs));
end

v1.document_class = struct('class_name', 'stimulus_response_scalar');
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
sr = struct('stimulator_epochid', '');
if ischar(epochString)
    sr.element_epochid = epochString;
end
v1.stimulus_response = sr;

value = getIn(calc, 'harmonic_component', 'value');
h = numberOf(getIn(value, 'harmonic'));
responseType = '';
if isequal(h, 0)
    responseType = 'mean';
elseif ~isempty(h)
    responseType = sprintf('F%d', h);
end
responses = struct();
responses.stimid = column(stimidOf(calc));
responses.response_real = column(getIn(value, 'real'));
responses.response_imaginary = column(getIn(value, 'imaginary'));
responses.control_response_real = column(getIn(value, 'control', 'real'));
responses.control_response_imaginary = column(getIn(value, 'control', 'imaginary'));
v1.stimulus_response_scalar = struct('response_type', responseType, ...
    'responses', responses);
end

% ===================== helpers =========================================

function v = stimidOf(calc)
%STIMIDOF The `stimulus` covariate along the reading dimension (0).
v = [];
covs = asCell(getIn(calc, 'data', 'covariates'));
if isempty(covs)
    covs = asCell(getIn(calc, 'statement', 'covariates'));
end
for k = 1:numel(covs)
    c = covs{k};
    [~, name] = termParts(getIn(c, 'variable'));
    along = getIn(c, 'along');
    if iscell(along); along = cell2mat(along); end
    if strcmp(name, 'stimulus') && isnumeric(along) && isequal(double(along), 0)
        v = getIn(c, 'quantity', 'value');
        return;
    end
end
end

function v = column(x)
%COLUMN A numeric list in the shape jsondecode gives it: N x 1 (a scalar
%   stays a scalar, an empty stays empty).
v = x;
if iscell(v) && all(cellfun(@(e) isnumeric(e) && isscalar(e), v))
    v = cell2mat(v);
end
if isnumeric(v) || islogical(v)
    v = double(v);
    if numel(v) > 1
        v = v(:);
    end
end
end

function id = firstId(ids)
id = '';
if ~isempty(ids)
    id = ids{1};
end
end

function id = idOf(body)
id = '';
[v, ok] = getIn(body, 'base', 'id');
if ok
    id = char(v);
end
end

function v1 = passedThrough(body)
%PASSEDTHROUGH A passed-through v1 document as v1 stated it: v1_to_v2 moved
%   base.session_id onto a `session_id` edge on the way out; read it back.
v1 = body;
sid = char(did2.schema.cache.sessionIdOf(body));
if isfield(v1, 'depends_on') && isstruct(v1.depends_on) && ~isempty(v1.depends_on)
    keep = true(1, numel(v1.depends_on));
    for k = 1:numel(v1.depends_on)
        keep(k) = ~strcmp(char(v1.depends_on(k).name), 'session_id');
    end
    v1.depends_on = v1.depends_on(keep);
end
if isfield(v1, 'base') && isstruct(v1.base) && ~isfield(v1.base, 'session_id') && ~isempty(sid)
    v1.base.session_id = sid;
end
% and renamed base.datestamp to creation_timestamp
if isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'creation_timestamp') ...
        && ~isfield(v1.base, 'datestamp')
    v1.base.datestamp = v1.base.creation_timestamp;
    v1.base = rmfield(v1.base, 'creation_timestamp');
end
end

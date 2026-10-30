function [v1, spec] = imageStack(bodies)
%IMAGESTACK Rebuild a v1 `imageStack` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.imageStack(BODIES). V1 is the stack in
%   NDI's v1 shape (imageStack.json + imageStack_parameters.json + base.json at
%   the locked NDI-matlab `main`, 3cb19a8, as +setup/+conv/+babu/import.m and
%   +haley/doImport.m write it). BODIES is one of:
%
%   PASSED THROUGH (pass 1): one `imageStack` document, the migrator's
%   passthrough of the raw v1 source (a stack with no subject) as v1_to_v2
%   padded and stamped it: the document itself, its session edge read back
%   into base.session_id and its creation_timestamp into base.datestamp.
%
%   CONVERTED (did2.convert.migrators_j.image_stack): the `observation` (value
%   kind intensity, id preserved), its `sampled_body` and its session anchor:
%     base.id, session_id, datestamp     the observation (rebuildBase)
%     depends_on                         document_id '' (a stack naming one is
%                                        carried, carry-052) and subject_id,
%                                        the observation's entity_id, in the
%                                        order NDI's template merge gives them
%                                        (sorted: document_id, subject_id)
%     files                              the body's files
%     imageStack.label                   the observation's notes
%     imageStack.formatOntology          the body's format node (else its
%                                        name); a CURIE's prefix case is
%                                        notation ([spelling is notation])
%     imageStack_parameters
%       dimension_size                   each dimension's n
%       dimension_labels                 each dimension's term name, joined
%                                        by ','; '' when every axis is a
%                                        coordinate axis named by its letter
%       dimension_order                  each dimension's letter, derived from
%                                        its term (node, then label) through
%                                        did2.convert.axisLetter's fixed table
%                                        ([axis letters derive from labels],
%                                        Jess Haley, 2026-10-27; 'height' -> Y)
%     base.name                          the sampled_body's description
%                                        ([image stack name goes to notes])
%       dimension_scale                  each covariate's spacing, by `along`
%                                        (0 for an axis with none)
%       dimension_scale_units            each covariate's source_unit name
%       data_type                        value.source_data_type, else
%                                        value.data_type
%       data_limits                      the body's "value range" condition
%                                        (EMPTY:0000402); without one, the data
%                                        type's range ([image file details
%                                        placed]: left unwritten when it is
%                                        that range), stated as an equivalent
%       timestamp, clocktype             [acquisition time on its clock]
%                                        (Jess Haley, 2026-10-30): on a UTC
%                                        clock, the anchor's start.source_value
%                                        and its clock (approx_ when its
%                                        clock_tolerance is 5 s); on any other,
%                                        the AFO:AFR_0001158 "acquisition
%                                        time" condition's source_value and the
%                                        anchor's clock, else the clock its
%                                        needs_info entry names. The former
%                                        "acquisition timestamp (<clock>)"
%                                        condition is still read.
%   The anchor is the stack's own (minted by the migration); anything else
%   emitted is unplaced.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.image_stack.

arguments
    bodies cell
end

CLASS = 'imageStack';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = passedThrough(bodies{1});
    return;
end

used = false(1, numel(bodies));
obs = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'observation')
        obs = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(obs)
    spec.unplaced{end+1} = 'no observation was emitted';
    return;
end
[base, ~] = rebuildBase(obs);
anchorIds = edgeIds(obs, 'time_reference_id');
body = [];
anchor = [];
for k = 1:numel(bodies)
    if used(k); continue; end
    b = bodies{k};
    cn = classNameOf(b);
    if strcmp(cn, 'sampled_body') && isempty(body) && any(strcmp(base.id, edgeIds(b, 'owner_id')))
        body = b;
        used(k) = true;
    elseif strcmp(cn, 'relative_time_reference') && any(strcmp(idOf(b), anchorIds))
        used(k) = true;
        if isempty(anchor)
            anchor = b;
        end
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in an imageStack', ...
        k, classNameOf(bodies{k}));
end
if isempty(body)
    spec.unplaced{end+1} = 'no sampled_body names the observation as its owner';
    return;
end

v1.document_class = struct('class_name', CLASS);
v1.depends_on = struct('name', {'document_id', 'subject_id'}, ...
    'value', {'', firstId(edgeIds(obs, 'entity_id'))});
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
% [image stack name goes to notes] (Jess Haley, 2026-10-27): a non-empty v1
% base.name is the data body's free text (`description` until [one free-text
% field: notes] is built)
stackName = fieldText(getIn(body, 'data_body'), 'description');
if ~isempty(stackName)
    v1.base.name = stackName;
end
if isfield(body, 'files')
    v1.files = body.files;
end

% ---- imageStack: label, formatOntology
stack = struct();
stack.label = fieldText(getIn(obs, 'statement'), 'notes');
[fnode, fname] = termParts(getIn(body, 'data_body', 'format'));
stack.formatOntology = fnode;
if isempty(fnode)
    stack.formatOntology = fname;
end
v1.imageStack = stack;
spec.same(end+1) = struct('path', 'imageStack.formatOntology', 'fn', @sameCurie, ...
    'why', ['a CURIE''s prefix case is notation ([spelling is notation], Jess ' ...
    'Haley, 2026-10-26); did2.build.formatTerm writes the registered spelling']);

% ---- imageStack_parameters
p = struct();
dims = asCell(getIn(body, 'data', 'dimensions'));
covs = asCell(getIn(body, 'data', 'covariates'));
n = numel(dims);
sizes = zeros(n, 1);
names = cell(1, n);
letters = blanks(n);
for k = 1:n
    sizes(k) = numberOf(getIn(dims{k}, 'n'));
    [node, names{k}] = termParts(getIn(dims{k}, 'term'));
    % [axis letters derive from labels] (Jess Haley, 2026-10-27): each letter
    % from the dimension's term, by node then by label, through ONE fixed
    % table (did2.convert.axisLetter); the migrator carries a stack whose
    % labels do not derive its letters
    L = did2.convert.axisLetter(struct('node', node, 'name', names{k}));
    if isempty(L); L = ' '; end
    letters(k) = L;
end
scales = zeros(n, 1);
units = repmat({''}, 1, n);
anyCov = false;
for c = 1:numel(covs)
    along = numberOf(getIn(covs{c}, 'along'));
    if isempty(along) || along < 0 || along >= n
        spec.unplaced{end+1} = sprintf('covariate %d names no dimension of the stack', c);
        continue;
    end
    k = along + 1;
    sp = numberOf(getIn(covs{c}, 'spacing', 'value'));
    if isempty(sp)
        spec.unplaced{end+1} = sprintf('covariate %d states no spacing', c);
        continue;
    end
    scales(k) = sp;
    [~, units{k}] = termParts(getIn(covs{c}, 'source_unit'));
    anyCov = true;
end
if all(letters ~= ' ')
    p.dimension_order = letters;
end
if all(letters ~= ' ') && all(cellfun(@(nm, L) isLetterName(nm, L), names, num2cell(letters)))
    p.dimension_labels = '';
else
    p.dimension_labels = strjoin(names, ',');
end
p.dimension_size = sizes;
if anyCov
    p.dimension_scale = scales;
    p.dimension_scale_units = strjoin(units, ',');
end
dataType = fieldText(getIn(obs, 'value'), 'source_data_type');
if isempty(dataType)
    dataType = fieldText(getIn(obs, 'value'), 'data_type');
end
p.data_type = dataType;
range = conditionMatrix(getIn(body, 'data_body', 'conditions'), 'EMPTY:0000402');
if ~isempty(range)
    p.data_limits = column(range);
    spec.same(end+1) = struct('path', 'imageStack_parameters.data_limits', ...
        'fn', @(a, b) isnumeric(a) && isnumeric(b) && isequal(double(a(:)), double(b(:))), ...
        'why', 'the value range condition holds the [minimum maximum] pair as one matrix');
else
    r = typeRange(dataType);
    if ~isempty(r)
        spec.equivalents(end+1) = struct('path', 'imageStack_parameters.data_limits', ...
            'values', {{r(:), r(:)'}}, 'why', ['the data type''s range, left ' ...
            'unwritten ([image file details placed], Jess Haley, 2026-10-26)']);
    end
end
[ts, clk, extra] = acquisitionTime(getIn(obs, 'statement', 'conditions'), anchor, obs);
spec.unplaced = [spec.unplaced, extra];
if ~isempty(ts)
    p.timestamp = ts;
    p.clocktype = clk;
end
v1.imageStack_parameters = p;
end

% ===================== helpers =========================================

function v1 = passedThrough(body)
%PASSEDTHROUGH A passed-through v1 document as v1 stated it (v1_to_v2's
%   outbound renames undone: the session edge, creation_timestamp).
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
if isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'creation_timestamp') ...
        && ~isfield(v1.base, 'datestamp')
    v1.base.datestamp = v1.base.creation_timestamp;
    v1.base = rmfield(v1.base, 'creation_timestamp');
end
end

function L = letterOf(node)
% the coordinate axes did2.convert.axisTerm writes by node
switch char(node)
    case 'NCIT:C44477', L = 'X';
    case 'NCIT:C44478', L = 'Y';
    case 'NCIT:C44479', L = 'Z';
    case 'om:Time',     L = 'T';
    otherwise,          L = ' ';
end
end

function tf = isLetterName(name, letter)
% a dimension named from its LETTER (no dimension_labels): axisTerm wrote the
% registry's label for the letter's node ('X-Coordinate', 'time')
switch letter
    case 'X', tf = strcmp(name, 'X-Coordinate');
    case 'Y', tf = strcmp(name, 'Y-Coordinate');
    case 'Z', tf = strcmp(name, 'Z-Coordinate');
    case 'T', tf = false;   % 't' and 'time' both write om:Time 'time'
    otherwise, tf = false;
end
end

function r = typeRange(dataType)
r = [];
cls = lower(strtrim(char(dataType)));
switch cls
    case {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}
        r = double([intmin(cls) intmax(cls)]);
    case {'logical', 'bool'}
        r = [0 1];
end
end

function m = conditionMatrix(conds, node)
m = [];
conds = asCell(conds);
for k = 1:numel(conds)
    [n, ~] = termParts(getIn(conds{k}, 'variable'));
    if strcmp(n, node)
        m = getIn(conds{k}, 'matrix');
        if iscell(m); m = cell2mat(m); end
        m = double(m);
        return;
    end
end
end

function [ts, clk, extra] = acquisitionTime(conds, anchor, obs)
% [acquisition time on its clock] (Jess Haley, 2026-10-30, did-schema
% V_eta_go_forward_class_audit.md): the v1 `timestamp` and `clocktype`.
%   A UTC clock: the anchor states the time (start.source_value, the datenum)
%   on clock utc; approx_utc when its clock_tolerance is 5 s.
%   Any other clock: the AFO:AFR_0001158 "acquisition time" condition holds
%   the datenum as its source_value; the clock is the anchor's, else the one
%   the observation's needs_info entry names ('' for "on no named clock").
%   The former "acquisition timestamp (<clock>)" condition (the label the
%   migrator wrote before) is read as before. Any other condition is unplaced.
ts = [];
clk = '';
extra = {};
[aclk, atol] = anchorClock(anchor);
start = numberOf(getIn(anchor, 'relative_time_reference', 'value', 'start', 'source_value'));
if ~isempty(start) && strcmp(aclk, 'utc')
    ts = start;
    clk = withApprox(aclk, atol);
end
conds = asCell(conds);
for k = 1:numel(conds)
    [node, name] = termParts(getIn(conds{k}, 'variable'));
    if sameCurie(node, 'AFO:AFR_0001158') && isempty(ts)
        ts = str2double(fieldText(getIn(conds{k}, 'quantity'), 'source_value'));
        if ~isfinite(ts)
            ts = [];
            extra{end+1} = 'the acquisition time condition holds no datenum'; %#ok<AGROW>
            continue;
        end
        if ~isempty(aclk)
            clk = withApprox(aclk, atol);
        else
            clk = needsInfoClock(obs);
        end
        continue;
    end
    tok = regexp(name, '^acquisition timestamp \((.*)\)$', 'tokens', 'once');
    if isempty(tok) || ~isempty(ts)
        extra{end+1} = sprintf('observation condition "%s" has no role in an imageStack', name); %#ok<AGROW>
        continue;
    end
    ts = numberOf(getIn(conds{k}, 'quantity', 'value'));
    clk = tok{1};
    if strcmp(clk, 'unspecified clock')
        clk = '';   % the migrator's words for a stack that names no clock
    end
end
end

function [clk, tol] = anchorClock(anchor)
% the anchor's clock name and clock_tolerance seconds ('' and 0 for none)
clk = '';
tol = 0;
if isempty(anchor)
    return;
end
clk = clockText(getIn(anchor, 'relative_time_reference', 'value', 'clock'));   % by node first [clock terms get nodes]
t = numberOf(getIn(anchor, 'time_reference', 'clock_tolerance', 'seconds'));
if ~isempty(t)
    tol = t;
end
end

function c = withApprox(clk, tol)
% NDI's approx_ clocks are the clock within 5 s (+ndi/+time/clocktype.m)
c = clk;
if tol == 5 && any(strcmp(clk, {'utc', 'dev_global_time', 'exp_global_time'}))
    c = ['approx_' clk];
end
end

function clk = needsInfoClock(obs)
% the clock the acquisition-time needs_info entry names, as v1 wrote it
clk = '';
entries = asCell(getIn(obs, 'base', 'needs_info'));
for k = 1:numel(entries)
    tok = regexp(fieldText(entries{k}, 'reason'), 'on clock ''([^'']*)''', 'tokens', 'once');
    if ~isempty(tok)
        clk = tok{1};
        return;
    end
end
end

function id = idOf(b)
id = '';
[v, ok] = getIn(b, 'base', 'id');
if ok
    id = char(v);
end
end

function id = firstId(ids)
id = '';
if ~isempty(ids)
    id = ids{1};
end
end

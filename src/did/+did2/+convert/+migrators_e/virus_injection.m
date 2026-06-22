function v2Body = virus_injection(preBody)
%VIRUS_INJECTION Brainstorm-E migrator: did_v1 virus_injection -> injection (virus).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion ==
%   'V_epsilon'. Per V_epsilon_SPEC.md, virus_injection is deprecated and
%   folds into injection (kind: "virus"): the virus identity becomes the
%   first pharmacological_manipulation.mixture chemical (serotype carried in
%   the ontology term), the dilution becomes its concentration amount, the
%   diluent (if named) a second mixture record, and the injection site
%   becomes the target_structure. 1 -> 2: the injection plus the shared
%   session_relative_reference anchor (subject_interaction needs a
%   time_reference).
%
%   The administration date / PND carry timing that could anchor a UTC or
%   developmental reference; for now the honest fallback is the ordinal
%   session anchor (refined in the temporal-anchoring follow-up).

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'virus_injection') || ~isstruct(preBody.virus_injection)
    error('did2:convert:missingBlock', ...
        'virus_injection body is missing the virus_injection property block.');
end
block = preBody.virus_injection;

% virus chemical + dilution amount
amount = blankConcentration();
dilution = numField(block, 'dilution');
if ~isempty(dilution)
    amount.source_value = dilution;
    amount.source_unit = 'dilution';
end
mixture = struct( ...
    'chemical', ontologyTerm(getCharField(block, 'virus_OntologyName'), ...
        getCharField(block, 'virus_name')), ...
    'amount', amount);
% optional diluent as a second record
diluentNode = getCharField(block, 'diluent_OntologyName');
diluentName = getCharField(block, 'diluent_name');
if ~isempty(diluentNode) || ~isempty(diluentName)
    mixture(end+1) = struct( ...
        'chemical', ontologyTerm(diluentNode, diluentName), ...
        'amount', blankConcentration());
end

targetStructure = ontologyArray( ...
    getCharField(block, 'virusLocation_OntologyName'), ...
    getCharField(block, 'virusLocation_name'));

inj = startManipulation(preBody, 'injection', {'pharmacological_manipulation'});
inj.pharmacological_manipulation = struct('mixture', mixture);
inj.injection = struct( ...
    'kind', 'virus', ...
    'volume', blankVolume(), ...
    'route', ontologyTerm('', ''), ...
    'target_structure', {targetStructure});

anchor = makeSessionAnchor(preBody, 'during');
inj.depends_on(end+1) = struct('name', 'time_reference_1', ...
    'value', anchor.base.id);
v2Body = {inj, anchor};
end

% ===================== shared helpers ==================================

function body = startManipulation(preBody, className, extraSupers)
chain = [{'manipulation'}, extraSupers];
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct( ...
    'class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_epsilon');
body.depends_on = carrySubject(preBody);
if isfield(preBody, 'base')
    body.base = preBody.base;
end
end

function deps = carrySubject(preBody)
deps = struct('name', {}, 'value', {});
subjectVal = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, 'subject_id')
            subjectVal = depValue(d);
        end
    end
end
deps(end+1) = struct('name', 'subject_id', 'value', subjectVal);
end

function anchor = makeSessionAnchor(preBody, relation)
sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
anchor = struct();
anchor.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_epsilon');
anchor.depends_on = struct('name', 'session_id', 'value', sessionId);
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
end

function arr = ontologyArray(node, name)
if isempty(node) && isempty(name)
    arr = struct('node', {}, 'name', {});
else
    arr = ontologyTerm(node, name);
end
end

function t = ontologyTerm(node, name)
t = struct('node', char(node), 'name', char(name));
end

function v = blankVolume()
v = struct('liters', 0.0, 'source_unit', '', 'source_value', 0.0, ...
    'approximate', false);
end

function c = blankConcentration()
c = struct('source_unit', '', 'source_value', 0.0, 'approximate', false);
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    end
end
end

function n = numField(block, name)
n = [];
if isfield(block, name)
    v = block.(name);
    if isnumeric(v) && isscalar(v) && isfinite(v)
        n = double(v);
    end
end
end

function v = depValue(d)
v = '';
if isfield(d, 'value')
    v = d.value;
elseif isfield(d, 'document_id')
    v = d.document_id;
end
end

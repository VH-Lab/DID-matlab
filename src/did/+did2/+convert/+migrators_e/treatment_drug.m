function v2Body = treatment_drug(preBody)
%TREATMENT_DRUG Brainstorm-E migrator: did_v1 treatment_drug -> injection (drug).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion ==
%   'V_epsilon'. Per V_epsilon_SPEC.md, treatment_drug is deprecated and
%   folds into injection (kind: "drug"): the administered substance becomes
%   the pharmacological_manipulation.mixture, the body location becomes the
%   injection target_structure. 1 -> 2: the injection plus the shared
%   session_relative_reference anchor every migrated interaction needs
%   (subject_interaction requires a time_reference).
%
%   Branch/field resolution here is a HEURISTIC seed (the legacy
%   mixture_table format varies); the authoritative mapping is finalised in
%   discovery mode against real corpora.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment_drug') || ~isstruct(preBody.treatment_drug)
    error('did2:convert:missingBlock', ...
        'treatment_drug body is missing the treatment_drug property block.');
end
block = preBody.treatment_drug;

targetStructure = ontologyArray( ...
    getCharField(block, 'location_ontologyNode'), ...
    getCharField(block, 'location_name'));
mixture = parseMixtureTable(block);

inj = startManipulation(preBody, 'injection', {'pharmacological_manipulation'});
inj.pharmacological_manipulation = struct('mixture', mixture);
inj.injection = struct( ...
    'kind', 'drug', ...
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

function mixture = parseMixtureTable(block)
%PARSEMIXTURETABLE Best-effort parse of the legacy CSV mixture_table into the
%   {chemical, amount} records pharmacological_manipulation.mixture wants.
%   mustBeNonEmpty: always return >= 1 record (a blank one if nothing
%   parses), so the document validates; the blank is the curator's signal.
mixture = struct('chemical', {}, 'amount', {});
raw = '';
if isfield(block, 'mixture_table')
    v = block.mixture_table;
    if ischar(v); raw = v; elseif isstring(v) && isscalar(v); raw = char(v); end
end
if ~isempty(raw)
    lines = strsplit(raw, newline);
    for i = 1:numel(lines)
        cols = strsplit(strtrim(lines{i}), ',');
        if numel(cols) < 2 || isempty(strtrim(cols{1}))
            continue;
        end
        chemical = ontologyTerm(strtrim(cols{1}), strtrim(cols{2}));
        amount = blankConcentration();
        if numel(cols) >= 3 && ~isempty(strtrim(cols{3}))
            amount.source_value = str2double(strtrim(cols{3}));
        end
        if numel(cols) >= 4
            amount.source_unit = strtrim(cols{4});
        end
        mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
    end
end
if isempty(mixture)
    mixture(1) = struct('chemical', ontologyTerm('', ''), ...
        'amount', blankConcentration());
end
end

function arr = ontologyArray(node, name)
if isempty(node) && isempty(name)
    arr = struct('node', {}, 'name', {});   % empty ontology_term array
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

function v = depValue(d)
v = '';
if isfield(d, 'value')
    v = d.value;
elseif isfield(d, 'document_id')
    v = d.document_id;
end
end

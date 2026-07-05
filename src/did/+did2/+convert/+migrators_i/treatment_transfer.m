function v2Body = treatment_transfer(preBody)
%TREATMENT_TRANSFER Brainstorm-I migrator: did_v1 treatment_transfer ->
%   biological_transfer.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_zeta'.
%   Per V_zeta_SPEC.md, treatment_transfer is deprecated and folds into
%   biological_transfer (a `manipulation` that earns its class via the
%   donor_id dependency): the transferred material becomes the spine
%   `variable`, the coarse material bucket becomes biological_transfer.kind,
%   the legacy recipient_id becomes the subject_id, and the donor_id is
%   carried as biological_transfer's donor dependency. (There is no
%   procedural_manipulation in V_zeta and no biological_transfer.entity --
%   the material identity is the spine `variable`.) 1 -> 2: the transfer plus
%   the shared session_relative_reference anchor.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment_transfer') || ~isstruct(preBody.treatment_transfer)
    error('did2:convert:missingBlock', ...
        'treatment_transfer body is missing the treatment_transfer property block.');
end
block = preBody.treatment_transfer;

recipientId = namedDep(preBody, 'recipient_id');
donorId     = namedDep(preBody, 'donor_id');

variable = ontologyTerm(getCharField(block, 'entity_ontologyNode'), ...
    getCharField(block, 'entity_name'));   % the transferred material -> spine
kind = getCharField(block, 'method_name');
if isempty(kind)
    kind = 'transfer';   % biological_transfer.kind is char, mustBeNonEmpty
end

body = struct();
body.document_class = struct( ...
    'class_name', 'biological_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'manipulation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_zeta');
% subject_id (the recipient) + donor_id; time_reference is appended below.
body.depends_on = [ ...
    struct('name', 'subject_id', 'value', recipientId), ...
    struct('name', 'donor_id',   'value', donorId)];
if isfield(preBody, 'base')
    body.base = preBody.base;
end
body.subject_interaction = struct( ...
    'method', struct('node', '', 'name', ''), ...
    'variable', variable, ...
    'target_structure', {struct('node', {}, 'name', {})});
body.manipulation = struct('notes', '');
body.biological_transfer = struct('kind', kind);

anchor = makeSessionAnchor(preBody, 'during');
body.depends_on(end+1) = struct('name', 'time_reference_1', ...
    'value', anchor.base.id);
v2Body = {body, anchor};
end

% ===================== shared helpers ==================================

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
    'schema_version', 'V_zeta');
% Session identity rides on base.session_id; no redundant session_id edge
% (it only produced discovery-mode orphans). See V_zeta
% session_relative_reference (depends_on now empty).
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
end

function val = namedDep(preBody, name)
val = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value'); val = d.value;
            elseif isfield(d, 'document_id'); val = d.document_id; end
        end
    end
end
end

function t = ontologyTerm(node, name)
t = struct('node', char(node), 'name', char(name));
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v2Body = ontology_label(preBody)
%ONTOLOGY_LABEL Brainstorm-J migrator: did_v1 ontology_label -> term_observation.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Per D5, an ontology label about an element/subject becomes a
%   `term_observation`: the labeled element IS the `subject`,
%   `subject_statement.variable` = the labeling relation, and the leaf `value` =
%   the label term. 1 -> 2 (the observation + the shared session anchor).
%
%   (A genuinely timeless annotation could instead be a `term_assertion`; the
%   located/observed form is emitted by default here and refined in discovery
%   mode.)
%
%   The label term is built from one of the two did_v1 idioms (mirroring the
%   default +migrators/ontology_label migrator):
%     1. three coordinated fields (ontology_name + label_id -> a CURIE node,
%        label -> name);
%     2. node-only (ontology_node -> node; name via ndi.ontology.lookup).

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_label') || ~isstruct(preBody.ontology_label)
    error('did2:convert:missingBlock', ...
        'ontology_label body is missing the ontology_label property block.');
end
block = preBody.ontology_label;

% --- resolve the label term (idiom 2 node-only wins if present) --------
if isfield(block, 'ontology_node') && ~isempty(block.ontology_node)
    node = char(block.ontology_node);
    labelName = lookupOntologyName(node);
else
    prefix = '';
    if isfield(block, 'ontology_name'); prefix = normaliseCURIEPrefix(block.ontology_name); end
    labelIdText = '';
    if isfield(block, 'label_id'); labelIdText = labelIdToText(block.label_id); end
    labelName = jGetChar(block, 'label');
    if isempty(prefix) && isempty(labelIdText)
        node = '';
    else
        node = sprintf('%s:%s', prefix, labelIdText);
    end
end
labelTerm = jOntologyTerm(node, labelName);

obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
    {}, jOntologyTerm('', 'ontology label'), {'element_id', 'subject_id', 'probe_id'});
obs.term_observation = struct('value', labelTerm);

anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

v2Body = {obs, anchor};
end

% ===================== local helpers ===================================

function name = lookupOntologyName(curie)
% Resolve a human-readable label for a CURIE via ndi.ontology; '' if
% unavailable (the ontology_term value tolerates an empty name).
try
    [~, name] = ndi.ontology.lookup(curie);
catch
    name = '';
end
if isstring(name) && isscalar(name)
    name = char(name);
elseif ~ischar(name)
    name = '';
end
end

function out = normaliseCURIEPrefix(raw)
out = lower(strtrim(char(raw)));
out = regexprep(out, '\s+', '_');
end

function out = labelIdToText(value)
if isnumeric(value) && isscalar(value)
    if isfinite(value) && value == floor(value)
        out = sprintf('%d', int64(value));
    else
        out = sprintf('%g', value);
    end
elseif ischar(value) || (isstring(value) && isscalar(value))
    out = char(value);
else
    out = '';
end
end

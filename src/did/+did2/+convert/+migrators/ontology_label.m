function v2Body = ontology_label(preBody)
%ONTOLOGY_LABEL Migrate a did_v1 ontologyLabel body to V_delta.
%
%   The class is renamed from ontologyLabel (camelCase, V_alpha) to
%   ontology_label (snake_case, V_delta) by
%   did2.convert.universalRenames; this migrator produces a single
%   `term` field of `ontology_term` composite type from one of two
%   did_v1 idioms it has to support:
%
%   1. Three coordinated fields (PRED-era, V_alpha-flavoured):
%        ontology_label.ontology_name + .label_id  -> term.node = '<prefix>:<id>'
%        ontology_label.label                       -> term.name
%      The CURIE is built by lowercasing the source-ontology name
%      (with spaces replaced by underscores) and appending ':<id>'.
%      Example: 'Allen CCF v3' + 12345 -> 'allen_ccf_v3:12345'.
%
%   2. Node-only (JH-era, ontology-driven):
%        ontology_label.ontologyNode (after universalRenames:
%                                     ontology_node)               -> term.node
%        term.name is resolved via ndi.ontology.lookup(term.node).
%      Example v1: `{"ontologyNode": "EMPTY:0000129"}`.
%
%   When idiom 2 fires and `ndi.ontology.lookup` is on the path,
%   the migrator dispatches to it to populate `term.name`. If the
%   lookup throws (curie not found, ontology data unavailable,
%   library not installed), the migrator falls back to leaving
%   `term.name` empty rather than quarantining -- the V_delta
%   `ontology_term` composite type only requires the value to be a
%   struct; the inner field shape is open.
%
%   See did-schema's
%   schemas/V_delta/conversions/from_did_v1/ontology_label.md.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'ontology_label') || ~isstruct(v2Body.ontology_label)
    error('did2:convert:missingBlock', ...
        'ontology_label body is missing the ontology_label property block.');
end

block = v2Body.ontology_label;

% Idiom 2 (node-only) wins if the v1 doc has ontology_node. Idiom 1
% supplies its own ontology_name + label_id and we build the CURIE.
if isfield(block, 'ontology_node') && ~isempty(block.ontology_node)
    node = char(block.ontology_node);
    labelName = lookupOntologyName(node);
else
    if isfield(block, 'ontology_name')
        prefix = normaliseCURIEPrefix(block.ontology_name);
    else
        prefix = '';
    end
    if isfield(block, 'label_id')
        labelIdText = labelIdToText(block.label_id);
    else
        labelIdText = '';
    end
    if isfield(block, 'label')
        labelName = char(block.label);
    else
        labelName = '';
    end
    if isempty(prefix) && isempty(labelIdText)
        node = '';
    else
        node = sprintf('%s:%s', prefix, labelIdText);
    end
end

newBlock = struct();
newBlock.term = struct('node', node, 'name', labelName);
v2Body.ontology_label = newBlock;
end

function name = lookupOntologyName(curie)
% Resolve the human-readable label for a CURIE via ndi.ontology.
% Returns '' if the lookup is unavailable or fails; the V_delta
% ontology_term composite type tolerates an empty name (the
% validator only requires the value to be a struct).
name = '';
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

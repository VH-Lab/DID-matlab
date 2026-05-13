function v2Body = ontology_label(preBody)
%ONTOLOGY_LABEL Migrate a did_v1 ontologyLabel body to V_delta.
%
%   The class is renamed from ontologyLabel (camelCase, V_alpha) to
%   ontology_label (snake_case, V_delta) by
%   did2.convert.universalRenames; this migrator collapses three
%   coordinated did_v1 fields (ontology_name, label_id, label) into a
%   single `term` field of `ontology_term` composite type. The CURIE
%   is built by lowercasing the source-ontology name (with spaces
%   replaced by underscores) and appending ':<label_id>':
%
%       ontology_label.ontology_name + ontology_label.label_id
%               -> ontology_label.term.node = '<prefix>:<label_id>'
%       ontology_label.label
%               -> ontology_label.term.name
%
%   Examples: 'Allen CCF v3' + 12345 -> 'allen_ccf_v3:12345'.
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

newBlock = struct();
newBlock.term = struct('node', node, 'name', labelName);
v2Body.ontology_label = newBlock;
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

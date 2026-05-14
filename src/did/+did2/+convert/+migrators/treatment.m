function v2Body = treatment(preBody)
%TREATMENT Migrate a did_v1 treatment body to V_delta.
%
%   Collapses the two coordinated did_v1 chars inside the treatment
%   property block into a single `treatment_name` field of
%   `ontology_term` composite type, and passes through `numeric_value`
%   and `string_value`:
%
%       treatment.{ontologyName | ontology_name} ->
%               treatment.treatment_name.node
%       treatment.name                           ->
%               treatment.treatment_name.name
%       treatment.numeric_value                  ->
%               treatment.numeric_value          (identity)
%       treatment.string_value                   ->
%               treatment.string_value           (identity)
%
%   The carrier field is renamed from did_v1's <class>.name to V_delta's
%   <class>.treatment_name so it does not collide with base.name. See
%   did-schema's
%   schemas/V_delta/conversions/from_did_v1/treatment.md.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'treatment') || ~isstruct(v2Body.treatment)
    error('did2:convert:missingBlock', ...
        'treatment body is missing the treatment property block.');
end

block = v2Body.treatment;
if isfield(block, 'ontologyName')
    node = char(block.ontologyName);
elseif isfield(block, 'ontology_name')
    node = char(block.ontology_name);
else
    node = '';
end
if isfield(block, 'name')
    labelName = char(block.name);
else
    labelName = '';
end

newBlock = struct();
newBlock.treatment_name = struct('node', node, 'name', labelName);
if isfield(block, 'numeric_value')
    newBlock.numeric_value = block.numeric_value;
else
    newBlock.numeric_value = '';
end
if isfield(block, 'string_value')
    newBlock.string_value = char(block.string_value);
else
    newBlock.string_value = '';
end
v2Body.treatment = newBlock;
end
